#include <iostream>
#include "fwht_baseline.h"

int main() {
    pixel_t input[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    pixel_t output[N];

    fwht_baseline(input, output);

   const int expected[N] = {
    935, -25, -35, -55, 25, -55, 75, -65
};

    bool pass = true;

    std::cout << "Entrada: ";
    for (int i = 0; i < N; ++i) {
        std::cout << input[i] << " ";
    }

    std::cout << "\nSalida FWHT: ";
    for (int i = 0; i < N; ++i) {
        std::cout << output[i] << " ";

        if (output[i] != expected[i]) {
            pass = false;
        }
    }

    std::cout << "\nEsperado: ";
    for (int i = 0; i < N; ++i) {
        std::cout << expected[i] << " ";
    }

    std::cout << "\n\nResultado: "
              << (pass ? "PASS" : "FAIL")
              << std::endl;

    return pass ? 0 : 1;
}