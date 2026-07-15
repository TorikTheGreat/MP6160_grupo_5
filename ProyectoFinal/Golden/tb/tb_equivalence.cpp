// =====================================================================
//  Equivalencia source-level: golden.forward  ==  wht_lossless_core
// 
//  Compila el núcleo REAL de W1 (con g++ + shim ap_int) y lo compara,
//  coeficiente por coeficiente, contra el golden. N=8 (el núcleo de W1
//  es solo N=8). Entrada en rango 8-bit [0,255] (suposición del grupo,
//  pero es configurable). Semilla fija -> reproducible.
//
//  esto prueba equivalencia a nivel de FUENTE C++, no
//  contra la RTL sintetizada (eso sería C/RTL co-sim en Vitis).
// =====================================================================
#include <iostream>
#include <cstdlib>
#include "wht_core.h"     // núcleo de W1
#include "wht_golden.h"   // golden de W3

static bool compare_block(const pixel_t in[N]) {
    pixel_t g[N];              // salida del golden
    pixel_t w_in[N], w[N];     // copia de entrada + salida del núcleo de W1
    for (int i = 0; i < N; i++) w_in[i] = in[i];

    wht_forward(in, g, N);
    wht_lossless_core(w_in, w);

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

    // 1) El bloque fijo del testbench de W1 (referencia ya validada a mano).
    pixel_t b0[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    total++; if (!compare_block(b0)) fails++;

    // 2) Barrido aleatorio de 8 bits, determinista.
    std::srand(12345);
    for (int t = 0; t < 100000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = std::rand() % 256;  // [0,255]
        total++; if (!compare_block(b)) fails++;
    }

    std::cout << "E4 equivalencia golden<->nucleo W1: "
              << (total - fails) << "/" << total
              << (fails ? "  FALLA\n" : "  PASA\n");
    return fails ? 1 : 0;
}
