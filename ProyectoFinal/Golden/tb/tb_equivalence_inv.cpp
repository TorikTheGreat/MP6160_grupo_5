// =====================================================================
//  Equivalencia source-level: golden.inverse  ==  wht_lossless_inverse
// =====================================================================
#include <iostream>
#include <cstdlib>
#include "wht_core.h"     // núcleo HLS
#include "wht_golden.h"   // golden de referencia

static bool compare_block(const pixel_t in[N]) {
    pixel_t g[N];              // salida del golden
    pixel_t w_in[N], w[N];     // copia de entrada + salida del núcleo HLS
    for (int i = 0; i < N; i++) w_in[i] = in[i];

    wht_inverse(in, g, N);
    wht_lossless_inverse(w_in, w);

    for (int i = 0; i < N; i++) {
        if ((long long)g[i] != (long long)w[i]) {
            std::cout << "  MISMATCH en coef " << i
                      << ": golden=" << (long long)g[i]
                      << " nucleo=" << (long long)w[i] << "\n";
            return false;
        }
    }
    return true;
}

int main() {
    long long total = 0, fails = 0;

    // 1) El bloque fijo
    pixel_t b0[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    total++; if (!compare_block(b0)) fails++;

    // 2) Barrido aleatorio de 16 bits.
    std::srand(12345);
    for (int t = 0; t < 100000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = (std::rand() % 65536) - 32768;
        total++; if (!compare_block(b)) fails++;
    }

    std::cout << "E4b equivalencia golden_inv<->nucleo HLS_inv: "
              << (total - fails) << "/" << total
              << (fails ? "  FALLA\n" : "  PASA\n");
    return fails ? 1 : 0;
}
