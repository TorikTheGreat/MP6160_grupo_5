#include <iostream>
#include "wht_core.h"

/**
 * @brief Testbench para la simulación C (CSim) del núcleo WHT Inverso.
 * 
 * Valida la propiedad de reversibilidad ejecutando primero el núcleo
 * forward y luego el núcleo inverso, y comparando el resultado final
 * con la entrada original.
 */
int main() {
    // 1. Inicialización de los datos de prueba
    pixel_t block_in[N]  = {100, 150, 120, 110, 105, 95, 130, 125};
    pixel_t block_coefs[N];
    pixel_t block_out[N];
    
    std::cout << "--- PRUEBA WHT INVERSA (N=8) ---" << std::endl;
    
    // 2. Ejecutar el núcleo Forward
    wht_lossless_core(block_in, block_coefs);

    // 3. Ejecutar el núcleo Inverso
    wht_lossless_inverse(block_coefs, block_out);

    // 4. Validar Resultados
    bool pass = true;
    std::cout << "Original  | Reconstruido | Diferencia" << std::endl;
    for(int i = 0; i < N; i++) {
        pixel_t diff = block_in[i] - block_out[i];
        std::cout << block_in[i] << "        | " 
                  << block_out[i] << "           | " 
                  << diff << std::endl;
        if(diff != 0) {
            pass = false;
        }
    }
    
    if (pass) {
        std::cout << "\nSimulacion Exitosa! La transformada es reversible." << std::endl;
        return 0; 
    } else {
        std::cout << "\nFallo en la Simulacion! Los datos reconstruidos no coinciden." << std::endl;
        return 1;
    }
}
