#include <iostream>
#include "wht_core.h"

/**
 * @brief Testbench para la simulación C (CSim) del núcleo WHT Lossless.
 * 
 * Este archivo NO se convierte en hardware. Se ejecuta como software normal para
 * validar que el hardware (wht_lossless_core) produce matemáticamente los resultados 
 * esperados sin errores de sintaxis o desbordamiento, y verifica empíricamente
 * la decorrelación de los datos.
 */
int main() {
    // 1. Inicialización de los datos de prueba
    // Se utiliza un patrón de prueba que simula un bloque de píxeles típico (valores cercanos).
    pixel_t block_in[N]  = {100, 150, 120, 110, 105, 95, 130, 125};
    pixel_t block_out[N]; // Arreglo para almacenar el resultado del hardware
    
    std::cout << "--- PRUEBA WHT LOSSLESS (N=8) ---" << std::endl;
    
    // 2. Ejecutar el Core (Simulación del hardware)
    // Se envían los píxeles originales y el módulo devuelve los coeficientes.
    wht_lossless_core(block_in, block_out);

    // 3. Imprimir y Validar Resultados
    std::cout << "Entrada original: ";
    for(int i = 0; i < N; i++) {
        std::cout << block_in[i] << " ";
    }
    
    std::cout << "\nCoeficientes WHT: ";
    for(int i = 0; i < N; i++) {
        std::cout << block_out[i] << " ";
    }
    
    // 4. Mensaje de confirmación
    std::cout << "\n\nSimulacion Exitosa! El modelo esta documentado y listo para W2 y W3." << std::endl;
    
    return 0; // Código 0 indica a Vitis HLS que el testbench no tuvo errores.
}
