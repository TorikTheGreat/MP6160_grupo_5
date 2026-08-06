// =====================================================================
//  Visual para el video: original -> coeficientes -> reconstruccion
// ---------------------------------------------------------------------
//  Usa el golden ya verificado (wht_forward / wht_inverse).
//
//  MODO POR DEFECTO: 1D, bloques de N por filas. Es EXACTAMENTE lo que hace el
//  nucleo sintetizado, asi que la figura ilustra el producto y no una extension.
//  El modo 2D separable (filas y luego columnas) sigue disponible con el tercer
//  argumento "2d", pero es solo software: el hardware no lo hace.
//  Emite 3 PGM 8-bit: <base>_orig.pgm, <base>_coef.pgm (remosaico por
//  subbandas, escala sqrt de la magnitud),
//  <base>_recon.pgm. Verifica que la reconstruccion == original (lossless).
//  El render final (figura con etiquetas + panel de diferencia) lo hace
//  make_visual.py.
//
//  Uso:  make_visual  img.pgm  <base_salida>  [1d|2d]   (por defecto 1d)
// =====================================================================
#include <cstdio>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>
#include "wht_golden.h"   // wht_forward, wht_inverse, pixel_t, N

// Lee un entero de la cabecera PGM saltando espacios y comentarios '#'.
// Sin esto, cualquier PGM exportado por GIMP o ImageMagick —que insertan una
// linea "# Created by ..."— no se puede leer.
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
    if (maxv != 255) {   // con maxval>255 cada muestra son 2 bytes: no soportado
        std::fprintf(stderr, "%s: maxval=%d no soportado (solo 255)\n", path, maxv);
        std::fclose(f); return false;
    }
    px.resize((size_t)w * h);
    for (size_t i = 0; i < px.size(); i++) {
        int v = std::fgetc(f);
        if (v == EOF) { std::fclose(f); return false; }   // fichero truncado
        px[i] = v;
    }
    std::fclose(f);
    return true;
}

static void write_pgm(const std::string &path, const std::vector<unsigned char> &d, int w, int h) {
    FILE *f = std::fopen(path.c_str(), "wb");
    std::fprintf(f, "P5\n%d %d\n255\n", w, h);
    std::fwrite(d.data(), 1, d.size(), f);
    std::fclose(f);
}

// WHT 1D sobre 'buf' (in-place): bloques de N por filas. Es lo que hace el HW.
static void wht1d(std::vector<pixel_t> &buf, int w, int h, bool fwd) {
    pixel_t in[N], out[N];
    for (int r = 0; r < h; r++)
        for (int c0 = 0; c0 < w; c0 += N) {
            for (int j = 0; j < N; j++) in[j] = buf[(size_t)r * w + c0 + j];
            if (fwd) wht_forward(in, out, N); else wht_inverse(in, out, N);
            for (int j = 0; j < N; j++) buf[(size_t)r * w + c0 + j] = out[j];
        }
}

// WHT 2D separable sobre 'buf' (in-place). fwd=true forward, fwd=false inverse.
static void wht2d(std::vector<pixel_t> &buf, int w, int h, bool fwd) {
    pixel_t in[N], out[N];
    auto pass_rows = [&](bool forward) {
        for (int r = 0; r < h; r++)
            for (int c0 = 0; c0 < w; c0 += N) {
                for (int j = 0; j < N; j++) in[j] = buf[(size_t)r * w + c0 + j];
                if (forward) wht_forward(in, out, N); else wht_inverse(in, out, N);
                for (int j = 0; j < N; j++) buf[(size_t)r * w + c0 + j] = out[j];
            }
    };
    auto pass_cols = [&](bool forward) {
        for (int c = 0; c < w; c++)
            for (int r0 = 0; r0 < h; r0 += N) {
                for (int j = 0; j < N; j++) in[j] = buf[(size_t)(r0 + j) * w + c];
                if (forward) wht_forward(in, out, N); else wht_inverse(in, out, N);
                for (int j = 0; j < N; j++) buf[(size_t)(r0 + j) * w + c] = out[j];
            }
    };
    if (fwd) { pass_rows(true);  pass_cols(true); }     // forward: filas, luego columnas
    else     { pass_cols(false); pass_rows(false); }    // inverse: columnas, luego filas (orden inverso)
}

int main(int argc, char **argv) {
    if (argc < 3) { std::fprintf(stderr, "uso: make_visual img.pgm base_salida [1d|2d]\n"); return 2; }
    bool two_d = (argc > 3 && std::string(argv[3]) == "2d");
    std::vector<int> px; int w, h;
    if (!read_pgm(argv[1], px, w, h)) { std::fprintf(stderr, "no se pudo leer %s\n", argv[1]); return 1; }
    if (w % N != 0 || h % N != 0) { std::fprintf(stderr, "w,h deben ser multiplos de %d\n", N); return 1; }
    std::string base = argv[2];

    // forward -> coeficientes
    std::vector<pixel_t> coef(px.size());
    for (size_t i = 0; i < px.size(); i++) coef[i] = px[i];
    if (two_d) wht2d(coef, w, h, true); else wht1d(coef, w, h, true);

    // inverse -> reconstruccion
    std::vector<pixel_t> recon = coef;
    if (two_d) wht2d(recon, w, h, false); else wht1d(recon, w, h, false);

    // verificar lossless
    long long diff = 0;
    for (size_t i = 0; i < px.size(); i++) if ((long long)recon[i] != px[i]) diff++;
    std::printf("reconstruccion vs original: %s (%lld pixeles distintos)\n",
                diff ? "FALLA" : "EXACTA", diff);

    // Coeficientes -> vista por SUBBANDAS.
    //  1D: la banda j de todos los bloques forma una franja vertical de ancho
    //      w/N. La franja 0 es el DC y queda como un thumbnail comprimido
    //      horizontalmente; las otras 7 (detalles) quedan casi en negro.
    //  2D: mosaico de N x N subbandas, la (0,0) es el DC.
    // Escala sqrt-magnitud global => se ve la concentracion de energia.
    std::vector<double> sub(px.size(), 0.0);
    double maxm = 1.0;
    if (two_d) {
        int bh = h / N, bw = w / N;
        for (int br = 0; br < N; br++)
            for (int bc = 0; bc < N; bc++)
                for (int R = 0; R < bh; R++)
                    for (int C = 0; C < bw; C++) {
                        double m = std::fabs((double)(long long)coef[(size_t)(R * N + br) * w + (C * N + bc)]);
                        sub[(size_t)(br * bh + R) * w + (bc * bw + C)] = m;
                        if (m > maxm) maxm = m;
                    }
    } else {
        int bw = w / N;                       // bloques por fila = ancho de cada franja
        for (int r = 0; r < h; r++)
            for (int B = 0; B < bw; B++)
                for (int j = 0; j < N; j++) {
                    double m = std::fabs((double)(long long)coef[(size_t)r * w + B * N + j]);
                    sub[(size_t)r * w + j * bw + B] = m;
                    if (m > maxm) maxm = m;
                }
    }
    std::vector<unsigned char> orig8(px.size()), coef8(px.size()), rec8(px.size());
    for (size_t i = 0; i < px.size(); i++) {
        orig8[i] = (unsigned char)px[i];
        rec8[i]  = (unsigned char)(long long)recon[i];
        coef8[i] = (unsigned char)std::lround(255.0 * std::sqrt(sub[i] / maxm));
    }
    write_pgm(base + "_orig.pgm",  orig8, w, h);
    write_pgm(base + "_coef.pgm",  coef8, w, h);
    write_pgm(base + "_recon.pgm", rec8,  w, h);
    std::printf("escritos: %s_{orig,coef,recon}.pgm  (modo %s)\n",
                base.c_str(), two_d ? "2D separable, SOLO SOFTWARE" : "1D N=8, el del hardware");
    return diff ? 1 : 0;
}
