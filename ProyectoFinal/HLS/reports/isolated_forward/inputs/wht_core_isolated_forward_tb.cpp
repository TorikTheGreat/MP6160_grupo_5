#include <iostream>
#include "wht_core_isolated.h"

int main() {
    pixel_t input[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    pixel_t output[N] = {};
    const int expected[N] = {117, -6, -9, -27, 6, -28, 38, -65};

    wht_lossless_forward_isolated(input, output);

    bool pass = true;
    for (int i = 0; i < N; ++i) {
        if (output[i] != expected[i]) {
            pass = false;
            std::cerr << "Mismatch at " << i << ": got "
                      << output[i] << ", expected " << expected[i] << "\n";
        }
    }

    std::cout << "Isolated forward: " << (pass ? "PASS" : "FAIL") << "\n";
    return pass ? 0 : 1;
}
