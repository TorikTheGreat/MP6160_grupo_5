#include <iostream>
#include "wht_multiplier_baseline.h"

static const mult_coef_t HALF_Q15 = 16384;

int main() {
    mult_pixel_t input[MULT_N] = {
        100, 150, 120, 110, 105, 95, 130, 125
    };

    mult_pixel_t transformed[MULT_N];
    mult_pixel_t reconstructed[MULT_N];

    // Resultados esperados del núcleo lifting multiplier-free.
    const int expected[MULT_N] = {
        117, -6, -9, -27, 6, -28, 38, -65
    };

    wht_multiplier_forward(input, transformed, HALF_Q15);

    bool forward_pass = true;

    std::cout << "Entrada: ";
    for (int i = 0; i < MULT_N; ++i) {
        std::cout << input[i] << " ";
    }

    std::cout << "\nSalida baseline con multiplicadores: ";
    for (int i = 0; i < MULT_N; ++i) {
        std::cout << transformed[i] << " ";

        if (transformed[i] != expected[i]) {
            forward_pass = false;
        }
    }

    std::cout << "\nEsperado: ";
    for (int i = 0; i < MULT_N; ++i) {
        std::cout << expected[i] << " ";
    }

    wht_multiplier_inverse(
        transformed,
        reconstructed,
        HALF_Q15
    );

    bool roundtrip_pass = true;

    std::cout << "\nReconstruido: ";
    for (int i = 0; i < MULT_N; ++i) {
        std::cout << reconstructed[i] << " ";

        if (reconstructed[i] != input[i]) {
            roundtrip_pass = false;
        }
    }

    std::cout << "\n\nForward: "
              << (forward_pass ? "PASS" : "FAIL");

    std::cout << "\nRound-trip: "
              << (roundtrip_pass ? "PASS" : "FAIL")
              << std::endl;

    return (forward_pass && roundtrip_pass) ? 0 : 1;
}
