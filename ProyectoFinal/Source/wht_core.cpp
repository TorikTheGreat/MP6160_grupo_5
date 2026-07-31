#include "wht_core.h"

/**
 * @brief Mariposa reversible basada en Lifting (S-Transform).
 * 
 * Operación fundamental (datapath espacial) que reemplaza la mariposa tradicional 
 * de la FWHT. Utiliza la aproximación entera (Lifting) descrita en la literatura
 * para evitar el uso de multiplicadores (0 DSPs) y divisiones que causarían ruido
 * de cuantización, logrando una transformación completamente reversible (lossless).
 * 
 * El pragma HLS INLINE asegura que esta función no genere overhead de llamadas 
 * a funciones, sino que se expanda directamente como hardware combinacional.
 * 
 * @param a Píxel/coeficiente de entrada superior.
 * @param b Píxel/coeficiente de entrada inferior.
 * @param s Salida que almacena el promedio (baja frecuencia) mediante un shift aritmético.
 * @param d Salida que almacena la diferencia (alta frecuencia).
 */
inline void lifting_butterfly(pixel_t a, pixel_t b, pixel_t &s, pixel_t &d) {
    #pragma HLS INLINE
    
    // Paso 1: Diferencia (Alta frecuencia)
    d = a - b;
    
    // Paso 2: Promedio aproximado mediante shift aritmético (>> 1)
    // Equivale a s = a - (a - b)/2
    s = a - (d >> 1); 
}

void wht_lossless_core(pixel_t block_in[N], pixel_t block_out[N]) {
    // -------------------------------------------------------------------------
    // DIRECTIVAS (PRAGMAS) DE OPTIMIZACIÓN HARDWARE
    // -------------------------------------------------------------------------
    // Mantener interfaces compactas para el kernel exportado.
    #pragma HLS INTERFACE m_axi port=block_in offset=slave bundle=gmem
    #pragma HLS INTERFACE m_axi port=block_out offset=slave bundle=gmem
    #pragma HLS INTERFACE s_axilite port=block_in bundle=control
    #pragma HLS INTERFACE s_axilite port=block_out bundle=control
    #pragma HLS INTERFACE s_axilite port=return bundle=control

    // Obliga al sintetizador a pipelinar el bloque completo.
    // II=1 (Initiation Interval) permite procesar un nuevo bloque N=8 en cada ciclo de reloj.
    #pragma HLS PIPELINE II=1

    // -------------------------------------------------------------------------
    // REGISTRO DE ENTRADA
    // -------------------------------------------------------------------------
    // Copiar entrada a un arreglo interno para aislar los puertos físicos.
    pixel_t stage[N];
    #pragma HLS ARRAY_PARTITION variable=stage complete dim=1
    for(int i = 0; i < N; i++) {
        // UNROLL clona el hardware; este for no toma múltiples ciclos, es cableado directo.
        #pragma HLS UNROLL
        stage[i] = block_in[i];
    }

    // -------------------------------------------------------------------------
    // DATAPATH: FWHT N=8 (3 etapas de mariposas espaciales)
    // -------------------------------------------------------------------------
    
    // -- Etapa 1 --
    pixel_t tmp1[N]; // Registros intermedios para la salida de la etapa 1
    #pragma HLS ARRAY_PARTITION variable=tmp1 complete dim=1
    for(int i = 0; i < 4; i++) {
        #pragma HLS UNROLL
        lifting_butterfly(stage[i*2], stage[i*2+1], tmp1[i*2], tmp1[i*2+1]);
    }

    // -- Etapa 2 --
    pixel_t tmp2[N]; // Registros intermedios para la salida de la etapa 2
    #pragma HLS ARRAY_PARTITION variable=tmp2 complete dim=1
    for(int i = 0; i < 2; i++) {
        #pragma HLS UNROLL
        lifting_butterfly(tmp1[i*4], tmp1[i*4+2], tmp2[i*4], tmp2[i*4+2]);
        lifting_butterfly(tmp1[i*4+1], tmp1[i*4+3], tmp2[i*4+1], tmp2[i*4+3]);
    }

    // -- Etapa 3 --
    // Las salidas de la última etapa van directamente a los puertos de salida (block_out).
    for(int i = 0; i < 4; i++) {
        #pragma HLS UNROLL
        lifting_butterfly(tmp2[i], tmp2[i+4], block_out[i], block_out[i+4]);
    }
}
