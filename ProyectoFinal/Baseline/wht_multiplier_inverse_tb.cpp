#include <iostream>
#include "wht_multiplier_baseline.h"

static const mult_coef_t HALF_Q15 = 16384;

int main() {
    mult_pixel_t transformed[MULT_N] = {
        117, -6, -9, -27, 6, -28, 38, -65
    };
    mult_pixel_t reconstructed[MULT_N] = {};
    const int expected[MULT_N] = {
        100, 150, 120, 110, 105, 95, 130, 125
    };

    wht_multiplier_inverse(transformed, reconstructed, HALF_Q15);

    bool pass = true;
    for (int i = 0; i < MULT_N; ++i) {
        if (reconstructed[i] != expected[i]) {
            pass = false;
            std::cerr << "Mismatch at " << i << ": got "
                      << reconstructed[i] << ", expected " << expected[i] << "\n";
        }
    }

    std::cout << "Multiplier inverse: " << (pass ? "PASS" : "FAIL") << "\n";
    return pass ? 0 : 1;
}
