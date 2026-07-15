// =====================================================================
// Experimento de reducción de entropía 
// ---------------------------------------------------------------------
//  Para cada imagen PGM mide la entropía orden-0 (bits/símbolo) de los
//  PIXELES vs los COEFICIENTES de la WHT lifting (golden ya verificado).
//  Una reducción en entropía aquí representa un aumento en la 
//  compresibilidad del dato (mira Shannon). Hacer el compresor está fuera 
//  del alcance del proyecto, luego podríamos presentar como trabajo futuro un 
//  codificador de entropía.
//
//  Dos formas de medir la entropía de los coeficientes:
//   - POOLED : un histograma con TODOS los coeficientes juntos. Mezcla
//              bandas de distinta naturaleza (DC grande + detalles ~0),
//              lo que INFLA H. Es lo que vería un coder orden-0 ciego.
//   - POR-BANDA : una entropía por posición de frecuencia; el costo
//              efectivo es el PROMEDIO (cada banda con su propio modelo,
//              como haría un coder real). Más principled y más honesta.
//
//  Bloqueo:
//   - 1D N=8  = lo que hace el hardware (tiras de 8 por fila). 8 bandas.
//   - 2D separable (fila+columna) = extensión SOLO golden/software. 64 bandas.
//
//  Uso:  entropy_experiment  img1.pgm img2.pgm ...
// =====================================================================
#include <cstdio>
#include <cstring>
#include <cmath>
#include <map>
#include <vector>
#include <string>
#include "wht_golden.h"   // wht_forward, pixel_t, N

static bool read_pgm(const char *path, std::vector<int> &px, int &w, int &h) {
    FILE *f = std::fopen(path, "rb");
    if (!f) return false;
    char magic[3] = {0};
    if (std::fscanf(f, "%2s", magic) != 1 || std::string(magic) != "P5") { std::fclose(f); return false; }
    int maxv;
    if (std::fscanf(f, "%d %d %d", &w, &h, &maxv) != 3) { std::fclose(f); return false; }
    std::fgetc(f);                       // un whitespace tras el header
    px.resize((size_t)w * h);
    for (size_t i = 0; i < px.size(); i++) px[i] = std::fgetc(f);
    std::fclose(f);
    return true;
}

static double entropy(const std::map<int, long long> &hist, long long total) {
    double H = 0.0;
    for (auto &kv : hist) { double p = (double)kv.second / total; H -= p * std::log2(p); }
    return H;
}

// Promedio de las entropías por banda (todas las bandas tienen igual conteo).
static double mean_band_entropy(const std::vector<std::map<int, long long>> &bands, long long per_band) {
    double sum = 0.0;
    for (auto &b : bands) sum += entropy(b, per_band);
    return sum / bands.size();
}

int main(int argc, char **argv) {
    std::printf("Entropia orden-0 (bits/simbolo).  pool = todos juntos ; band = promedio por banda\n\n");
    std::printf("%-9s | %6s | %-15s | %-15s\n", "dataset", "H_pix", "  1D (HW)", "  2D separable");
    std::printf("%-9s | %6s | %6s %6s | %6s %6s\n", "", "", "pool", "band", "pool", "band");
    std::printf("----------+--------+---------------+---------------\n");

    std::vector<std::string> names;
    std::vector<std::vector<double>> band1d_dump;   // 8 entropías por banda 1D, por dataset

    for (int a = 1; a < argc; a++) {
        std::vector<int> px; int w, h;
        if (!read_pgm(argv[a], px, w, h)) { std::printf("%-9s | (no se pudo leer)\n", argv[a]); continue; }
        if (w % N != 0 || h % N != 0) { std::printf("%-9s | (w,h multiplos de %d)\n", argv[a], N); continue; }
        long long npix = (long long)px.size();

        // H de los pixeles
        std::map<int, long long> hpix;
        for (int v : px) hpix[v]++;
        double H_pix = entropy(hpix, npix);

        // 1D N=8 por filas: pooled + 8 bandas
        std::map<int, long long> h1d_pool;
        std::vector<std::map<int, long long>> band1d(N);
        for (int r = 0; r < h; r++)
            for (int c0 = 0; c0 < w; c0 += N) {
                pixel_t in[N], out[N];
                for (int j = 0; j < N; j++) in[j] = px[(size_t)r * w + c0 + j];
                wht_forward(in, out, N);
                for (int j = 0; j < N; j++) { int v = (int)(long long)out[j]; h1d_pool[v]++; band1d[j][v]++; }
            }
        double H1d_pool = entropy(h1d_pool, npix);
        double H1d_band = mean_band_entropy(band1d, npix / N);

        // 2D separable (fila luego columna): pooled + 64 bandas
        std::vector<pixel_t> buf(px.size());
        for (size_t i = 0; i < px.size(); i++) buf[i] = px[i];
        for (int r = 0; r < h; r++)
            for (int c0 = 0; c0 < w; c0 += N) {
                pixel_t in[N], out[N];
                for (int j = 0; j < N; j++) in[j] = buf[(size_t)r * w + c0 + j];
                wht_forward(in, out, N);
                for (int j = 0; j < N; j++) buf[(size_t)r * w + c0 + j] = out[j];
            }
        for (int c = 0; c < w; c++)
            for (int r0 = 0; r0 < h; r0 += N) {
                pixel_t in[N], out[N];
                for (int j = 0; j < N; j++) in[j] = buf[(size_t)(r0 + j) * w + c];
                wht_forward(in, out, N);
                for (int j = 0; j < N; j++) buf[(size_t)(r0 + j) * w + c] = out[j];
            }
        std::map<int, long long> h2d_pool;
        std::vector<std::map<int, long long>> band2d(N * N);
        for (int r = 0; r < h; r++)
            for (int c = 0; c < w; c++) {
                int v = (int)(long long)buf[(size_t)r * w + c];
                h2d_pool[v]++;
                band2d[(r % N) * N + (c % N)][v]++;
            }
        double H2d_pool = entropy(h2d_pool, npix);
        double H2d_band = mean_band_entropy(band2d, npix / (N * N));

        const char *name = argv[a];
        if (const char *slash = std::strrchr(name, '/')) name = slash + 1;
        std::printf("%-9s | %6.3f | %6.3f %6.3f | %6.3f %6.3f\n",
                    name, H_pix, H1d_pool, H1d_band, H2d_pool, H2d_band);

        std::vector<double> dump(N);
        for (int j = 0; j < N; j++) dump[j] = entropy(band1d[j], npix / N);
        names.push_back(name);
        band1d_dump.push_back(dump);
    }

    // Desglose de las 8 bandas 1D (banda 0 = DC / baja frec ... banda 7 = alta frec)
    std::printf("\nEntropia por banda 1D (banda0=DC ... banda7=alta frecuencia):\n");
    std::printf("%-9s | ", "dataset");
    for (int j = 0; j < N; j++) std::printf("  b%d  ", j);
    std::printf("\n");
    for (size_t i = 0; i < names.size(); i++) {
        std::printf("%-9s | ", names[i].c_str());
        for (int j = 0; j < N; j++) std::printf("%5.2f ", band1d_dump[i][j]);
        std::printf("\n");
    }
    return 0;
}
