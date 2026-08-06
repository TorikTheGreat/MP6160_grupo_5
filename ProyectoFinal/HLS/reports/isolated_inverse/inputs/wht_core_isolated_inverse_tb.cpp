#include <iostream>
#include "wht_core_isolated.h"

int main() {
    pixel_t transformed[N] = {117, -6, -9, -27, 6, -28, 38, -65};
    pixel_t reconstructed[N] = {};
    const int expected[N] = {100, 150, 120, 110, 105, 95, 130, 125};

    wht_lossless_inverse_isolated(transformed, reconstructed);

    bool pass = true;
    for (int i = 0; i < N; ++i) {
        if (reconstructed[i] != expected[i]) {
            pass = false;
            std::cerr << "Mismatch at " << i << ": got "
                      << reconstructed[i] << ", expected " << expected[i] << "\n";
        }
    }

    std::cout << "Isolated inverse: " << (pass ? "PASS" : "FAIL") << "\n";
    return pass ? 0 : 1;
}
