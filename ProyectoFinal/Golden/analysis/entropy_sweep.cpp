// =====================================================================
//  Barrido de tamaño de bloque para la reducción de entropía
// ---------------------------------------------------------------------
//  Extiende el experimento de entropy_experiment.cpp (que es N=8 fijo,
//  el tamaño del hardware) a N = 8, 16 y 32, para responder si el
//  beneficio de la transformada depende del tamaño de bloque.
//
//  Es SOLO software: el núcleo sintetizado es N=8. Este barrido usa el
//  golden, cuyas wht_forward/wht_inverse reciben n en tiempo de
//  ejecución, así que no hace falta recompilar nada del hardware.
//
//  --- POR QUÉ EL BARRIDO ES 1D Y NO 2D -----------------------------
//  La entropía empírica de un histograma con M muestras está acotada
//  por log2(M): con pocas muestras el estimador plug-in SUBESTIMA, y esa
//  subestimación se confunde con "compresión". Las muestras por banda son
//
//      1D:  npix / N          2D:  npix / N^2
//
//  Para una imagen de 256x256 (65536 px) eso da:
//
//      N      1D          2D
//      8      8192        1024
//      16     4096         256
//      32     2048          64   <- techo log2(64) = 6 bits
//
//  A N=32 en 2D el techo (6 bits) está POR DEBAJO de la entropía real de
//  una fuente sin correlación (~8 bits), así que el número que saldría no
//  mide compresión: mide falta de muestras. El control 'noise' lo delata
//  (ruido blanco no se puede comprimir y aun así "mejoraría").
//  Por eso: el barrido es 1D, donde M va de 8192 a 2048 y el sesgo es de
//  centésimas; el 2D se reporta solo en N=8, que es además lo que ya
//  estaba publicado.
//
//  --- QUÉ IMPRIME ---------------------------------------------------
//   - H de los píxeles (referencia, no depende de N)
//   - 1D pooled y por-banda para cada N, con M y su techo log2(M)
//   - 2D pooled y por-banda solo en N=8
//   - overflow: nº de bloques donde la aritmética de 16 bits difiere de
//     la de precisión amplia, y el |coeficiente| máximo observado.
//     Sirve para justificar que ap_int<16> sigue bastando al subir N.
//
//  Uso:  entropy_sweep  img1.pgm img2.pgm ...
// =====================================================================
#include <cstdio>
#include <cstring>
#include <cmath>
#include <map>
#include <vector>
#include <string>
#include "wht_golden.h"   // wht_forward, wht_forward_t, pixel_t

static const int NMAX   = 32;
static const int SWEEP[] = {8, 16, 32};
static const int NSWEEP  = 3;

// Lee un PGM binario (P5). Salta comentarios '#' en la cabecera y valida
// maxval, que es lo que rompe con cualquier fichero de GIMP/ImageMagick.
static int next_header_int(FILE *f, bool &ok) {
    int c;
    for (;;) {
        do { c = std::fgetc(f); } while (c == ' ' || c == '\t' || c == '\n' || c == '\r');
        if (c == '#') { do { c = std::fgetc(f); } while (c != '\n' && c != EOF); continue; }
        break;
    }
    if (c == EOF || c < '0' || c > '9') { ok = false; return 0; }
    int v = 0;
    while (c >= '0' && c <= '9') { v = v * 10 + (c - '0'); c = std::fgetc(f); }
    return v;
}

static bool read_pgm(const char *path, std::vector<int> &px, int &w, int &h) {
    FILE *f = std::fopen(path, "rb");
    if (!f) return false;
    char magic[3] = {0};
    if (std::fscanf(f, "%2s", magic) != 1 || std::string(magic) != "P5") { std::fclose(f); return false; }
    bool ok = true;
    w        = next_header_int(f, ok);
    h        = next_header_int(f, ok);
    int maxv = next_header_int(f, ok);
    if (!ok || w <= 0 || h <= 0) { std::fclose(f); return false; }
    if (maxv != 255) {   // solo 8 bits binario: con maxv>255 cada muestra son 2 bytes
        std::fprintf(stderr, "%s: maxval=%d no soportado (solo 255)\n", path, maxv);
        std::fclose(f); return false;
    }
    px.resize((size_t)w * h);
    for (size_t i = 0; i < px.size(); i++) {
        int v = std::fgetc(f);
        if (v == EOF) { std::fclose(f); return false; }
        px[i] = v;
    }
    std::fclose(f);
    return true;
}

static double entropy(const std::map<int, long long> &hist, long long total) {
    double H = 0.0;
    for (auto &kv : hist) { double p = (double)kv.second / total; H -= p * std::log2(p); }
    return H;
}

static double mean_band_entropy(const std::vector<std::map<int, long long>> &bands, long long per_band) {
    double sum = 0.0;
    for (auto &b : bands) sum += entropy(b, per_band);
    return sum / bands.size();
}

struct Row1D {
    int    n;
    double pool, band;
    long long m;          // muestras por banda
    long long ovf;        // bloques con discrepancia 16 bits vs amplia
    long long maxabs;     // |coeficiente| máximo observado
};

// Control de sesgo: misma transformada, mismo N, pero usando solo 1 de cada
// 'stride' bloques. Los datos NO cambian; lo único que cambia es cuántas
// muestras ve el estimador. La caída que se observe aquí es sesgo puro, y es
// la vara con la que hay que medir la caída del barrido.
static double band_entropy_subsampled(const std::vector<int> &px, int w, int h,
                                      int n, int stride, long long &m_out) {
    std::vector<std::map<int, long long>> band(n);
    long long used = 0;
    long long blk  = 0;
    for (int row = 0; row < h; row++)
        for (int c0 = 0; c0 + n <= w; c0 += n, blk++) {
            if (blk % stride) continue;
            pixel_t in[NMAX], out[NMAX];
            for (int j = 0; j < n; j++) in[j] = px[(size_t)row * w + c0 + j];
            wht_forward(in, out, n);
            for (int j = 0; j < n; j++) band[j][(int)(long long)out[j]]++;
            used++;
        }
    m_out = used;
    return mean_band_entropy(band, used);
}

// 1D por filas con bloque n. Además compara contra precisión amplia.
static Row1D run1d(const std::vector<int> &px, int w, int h, int n) {
    Row1D r{}; r.n = n;
    long long npix = (long long)px.size();
    std::map<int, long long> pool;
    std::vector<std::map<int, long long>> band(n);
    for (int row = 0; row < h; row++)
        for (int c0 = 0; c0 + n <= w; c0 += n) {
            pixel_t in[NMAX], out[NMAX];
            long long win[NMAX], wout[NMAX];
            for (int j = 0; j < n; j++) {
                in[j]  = px[(size_t)row * w + c0 + j];
                win[j] = px[(size_t)row * w + c0 + j];
            }
            wht_forward(in, out, n);
            wht_forward_t<long long>(win, wout, n);
            bool dif = false;
            for (int j = 0; j < n; j++) {
                long long v = (long long)out[j];
                if (v != wout[j]) dif = true;
                long long a = v < 0 ? -v : v;
                if (a > r.maxabs) r.maxabs = a;
                pool[(int)v]++; band[j][(int)v]++;
            }
            if (dif) r.ovf++;
        }
    r.m    = npix / n;
    r.pool = entropy(pool, npix);
    r.band = mean_band_entropy(band, r.m);
    return r;
}

// 2D separable (filas y luego columnas), solo se usa con n=8.
static void run2d(const std::vector<int> &px, int w, int h, int n,
                  double &pool_out, double &band_out, long long &m_out) {
    long long npix = (long long)px.size();
    std::vector<pixel_t> buf(px.size());
    for (size_t i = 0; i < px.size(); i++) buf[i] = px[i];
    for (int row = 0; row < h; row++)
        for (int c0 = 0; c0 + n <= w; c0 += n) {
            pixel_t in[NMAX], out[NMAX];
            for (int j = 0; j < n; j++) in[j] = buf[(size_t)row * w + c0 + j];
            wht_forward(in, out, n);
            for (int j = 0; j < n; j++) buf[(size_t)row * w + c0 + j] = out[j];
        }
    for (int c = 0; c < w; c++)
        for (int r0 = 0; r0 + n <= h; r0 += n) {
            pixel_t in[NMAX], out[NMAX];
            for (int j = 0; j < n; j++) in[j] = buf[(size_t)(r0 + j) * w + c];
            wht_forward(in, out, n);
            for (int j = 0; j < n; j++) buf[(size_t)(r0 + j) * w + c] = out[j];
        }
    std::map<int, long long> pool;
    std::vector<std::map<int, long long>> band((size_t)n * n);
    for (int row = 0; row < h; row++)
        for (int c = 0; c < w; c++) {
            int v = (int)(long long)buf[(size_t)row * w + c];
            pool[v]++;
            band[(size_t)(row % n) * n + (c % n)][v]++;
        }
    m_out    = npix / ((long long)n * n);
    pool_out = entropy(pool, npix);
    band_out = mean_band_entropy(band, m_out);
}

int main(int argc, char **argv) {
    if (argc < 2) { std::printf("uso: entropy_sweep img1.pgm [img2.pgm ...]\n"); return 1; }

    std::printf("Barrido de tamano de bloque. Entropia orden-0 en bits/simbolo.\n");
    std::printf("M = muestras por banda ; techo = log2(M), cota superior del estimador.\n");
    std::printf("El barrido es 1D; el 2D solo se reporta en N=8 (ver cabecera del fuente).\n\n");
    std::printf("%-11s | %6s | %2s | %6s %6s | %6s %6s | %5s %5s\n",
                "dataset", "H_pix", "N", "1Dpool", "1Dband", "M", "techo", "ovf", "|c|max");
    std::printf("------------+--------+----+---------------+---------------+------------\n");

    struct Extra { std::string name; double p2, b2; long long m2; };
    std::vector<Extra> extras;

    for (int a = 1; a < argc; a++) {
        std::vector<int> px; int w, h;
        if (!read_pgm(argv[a], px, w, h)) { std::printf("%-11s | (no se pudo leer)\n", argv[a]); continue; }

        const char *name = argv[a];
        if (const char *slash = std::strrchr(name, '/')) name = slash + 1;

        std::map<int, long long> hpix;
        for (int v : px) hpix[v]++;
        double H_pix = entropy(hpix, (long long)px.size());

        for (int k = 0; k < NSWEEP; k++) {
            int n = SWEEP[k];
            if (w % n != 0 || h % n != 0) {
                std::printf("%-11s | %6.3f | %2d | (w,h no multiplos de %d)\n", name, H_pix, n, n);
                continue;
            }
            Row1D r = run1d(px, w, h, n);
            std::printf("%-11s | %6.3f | %2d | %6.3f %6.3f | %6lld %6.2f | %5lld %5lld\n",
                        k == 0 ? name : "", H_pix, n, r.pool, r.band,
                        r.m, std::log2((double)r.m), r.ovf, r.maxabs);
        }

        if (w % 8 == 0 && h % 8 == 0) {
            Extra e; e.name = name;
            run2d(px, w, h, 8, e.p2, e.b2, e.m2);
            extras.push_back(e);
        }
    }

    std::printf("\n2D separable, solo N=8 (extension software; el hardware es 1D):\n");
    std::printf("%-11s | %6s %6s | %6s %6s\n", "dataset", "2Dpool", "2Dband", "M", "techo");
    std::printf("------------+---------------+---------------\n");
    for (auto &e : extras)
        std::printf("%-11s | %6.3f %6.3f | %6lld %6.2f\n",
                    e.name.c_str(), e.p2, e.b2, e.m2, std::log2((double)e.m2));

    // --- Control de sesgo del estimador --------------------------------
    // Fija N=8 y reduce las muestras a 1/2, 1/4 (= las M de N=16 y N=32).
    // Los datos son los mismos, asi que TODA caida aqui es sesgo. Comparar
    // esta caida con la del barrido dice cuanta senal hay de verdad.
    std::printf("\nControl de sesgo (N=8 fijo, submuestreando bloques):\n");
    std::printf("%-11s | %6s %6s %6s | %s\n", "dataset",
                "M=8192", "M=4096", "M=2048", "caida por sesgo puro");
    std::printf("------------+----------------------+---------------------\n");
    for (int a = 1; a < argc; a++) {
        std::vector<int> px; int w, h;
        if (!read_pgm(argv[a], px, w, h)) continue;
        if (w % 8 || h % 8) continue;
        const char *name = argv[a];
        if (const char *slash = std::strrchr(name, '/')) name = slash + 1;
        long long m1, m2, m4;
        double e1 = band_entropy_subsampled(px, w, h, 8, 1, m1);
        double e2 = band_entropy_subsampled(px, w, h, 8, 2, m2);
        double e4 = band_entropy_subsampled(px, w, h, 8, 4, m4);
        std::printf("%-11s | %6.3f %6.3f %6.3f | %.3f bits\n",
                    name, e1, e2, e4, e1 - e4);
    }

    std::printf("\nLectura:\n");
    std::printf(" - 'ovf' cuenta bloques donde ap_int<16> difiere de la aritmetica amplia.\n");
    std::printf("   Con 0 en toda la tabla, el datapath de 16 bits basta tambien en N=16 y 32.\n");
    std::printf(" - Comparar 1Dband ENTRE N solo vale si la caida del barrido supera a la\n");
    std::printf("   caida del control de sesgo del MISMO dataset (el sesgo depende de la\n");
    std::printf("   distribucion: es mucho mayor en 'noise', casi uniforme, que en 'natural').\n");
    return 0;
}
