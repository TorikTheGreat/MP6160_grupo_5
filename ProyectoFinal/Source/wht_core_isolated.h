#ifndef WHT_CORE_ISOLATED_H
#define WHT_CORE_ISOLATED_H

#include "wht_core.h"

/**
 * Núcleo forward multiplier-free con interfaz de memoria simple.
 * Se usa exclusivamente para comparar el datapath contra el baseline
 * con multiplicadores sin incluir el costo del envoltorio AXI.
 */
void wht_lossless_forward_isolated(
    pixel_t block_in[N],
    pixel_t block_out[N]
);

/**
 * Núcleo inverse multiplier-free con interfaz de memoria simple.
 * Mantiene el mismo datapath del núcleo AXI, pero sin m_axi/s_axilite.
 */
void wht_lossless_inverse_isolated(
    pixel_t block_in[N],
    pixel_t block_out[N]
);

#endif // WHT_CORE_ISOLATED_H
