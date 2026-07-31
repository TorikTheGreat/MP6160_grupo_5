#include "wht_golden.h"

// Instancias de conveniencia con el tipo del núcleo (pixel_t = ap_int<16>).
// Toda la lógica vive en las plantillas del header; esto solo la fija a pixel_t.
void wht_forward(const pixel_t *in, pixel_t *out, int n) { wht_forward_t<pixel_t>(in, out, n); }
void wht_inverse(const pixel_t *in, pixel_t *out, int n) { wht_inverse_t<pixel_t>(in, out, n); }
