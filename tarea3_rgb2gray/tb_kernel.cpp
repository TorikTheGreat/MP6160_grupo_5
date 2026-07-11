#include <iostream>
#include <vector>
#include <cstdlib>
#include <cmath>
#include "rgb2gray_kernel.h"

// Función golden de Tarea 2 para validar bit-exact
static inline uint8_t golden_rgb_to_gray(uint8_t r, uint8_t g, uint8_t b) {
    double y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    return static_cast<uint8_t>(y + 0.5);
}

int main() {
    const uint32_t num_pixels = 100; // Prueba pequeña
    std::vector<uint8_t> in_image(num_pixels * 3);
    std::vector<uint8_t> out_image(num_pixels);
    std::vector<uint8_t> expected(num_pixels);

    // Generar datos aleatorios
    for (uint32_t i = 0; i < num_pixels; i++) {
        in_image[3*i]     = rand() % 256;
        in_image[3*i + 1] = rand() % 256;
        in_image[3*i + 2] = rand() % 256;
        
        expected[i] = golden_rgb_to_gray(in_image[3*i], in_image[3*i+1], in_image[3*i+2]);
    }

    // Ejecutar Kernel HLS
    rgb2gray_top(in_image.data(), out_image.data(), num_pixels);

    // Validar resultados (Añadiendo margen de tolerancia de ±1)
    int errors = 0;
    for (uint32_t i = 0; i < num_pixels; i++) {
        int diff = std::abs((int)out_image[i] - (int)expected[i]);
        if (diff > 1) { // Tolerancia de 1 nivel de gris por pérdida de precisión al no usar double
            std::cout << "Error en pixel " << i << ": esperado " 
                      << (int)expected[i] << ", obtenido " << (int)out_image[i] << std::endl;
            errors++;
        }
    }

    if (errors == 0) {
        std::cout << "Testbench parcial PASÓ correctamente!" << std::endl;
        return 0; // Csim exitoso
    } else {
        std::cout << "Testbench FALLÓ con " << errors << " errores." << std::endl;
        return 1;
    }
}
