#ifndef WHT_CORE_H
#define WHT_CORE_H

#include "ap_int.h"

/**
 * @def N
 * @brief Tamaño del bloque unidimensional a transformar.
 * 
 * Se define N=8 como el bloque estándar inicial para la Transformada
 * Walsh-Hadamard, alineado con las especificaciones del Avance 2.
 */
#define N 8

/**
 * @typedef pixel_t
 * @brief Tipo de dato de precisión arbitraria para los píxeles/coeficientes.
 * 
 * Se utiliza un entero de 16 bits (ap_int<16>) nativo de HLS. 
 * Esto evita el uso innecesario de enteros estándar de 32 bits, optimizando
 * el uso de registros (Flip-Flops) y LUTs en la FPGA, asegurando suficiente
 * rango dinámico para evitar desbordamientos durante las sumas.
 */
typedef ap_int<16> pixel_t; 

/**
 * @brief Núcleo de la Transformada Walsh-Hadamard Reversible (1D, N=8).
 * 
 * Esta función es el "Top-Level" del diseño hardware. Implementa una FWHT 
 * multiplier-free (sin multiplicadores) garantizando reconstrucción bit-exact 
 * (sin pérdida de información) mediante el esquema Lifting (S-Transform).
 * 
 * @param block_in  Arreglo de entrada que contiene los 8 píxeles originales.
 * @param block_out Arreglo de salida donde se almacenan los 8 coeficientes decorrelacionados.
 */
void wht_lossless_core(pixel_t block_in[N], pixel_t block_out[N]);

/**
 * @brief Núcleo de la Transformada Walsh-Hadamard Inversa Reversible (1D, N=8).
 * 
 * Esta función es el "Top-Level" del diseño hardware para la reconstrucción.
 * Implementa la transformada inversa exacta (sin multiplicadores) garantizando 
 * la recuperación bit-exact de los píxeles originales mediante el esquema de 
 * Lifting inverso, revirtiendo el proceso espacial de wht_lossless_core.
 * 
 * @param block_in  Arreglo de entrada que contiene los 8 coeficientes decorrelacionados.
 * @param block_out Arreglo de salida donde se almacenan los 8 píxeles originales recuperados.
 */
void wht_lossless_inverse(pixel_t block_in[N], pixel_t block_out[N]);

#endif // WHT_CORE_H
