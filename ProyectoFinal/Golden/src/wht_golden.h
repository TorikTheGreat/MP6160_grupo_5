#ifndef WHT_GOLDEN_H
#define WHT_GOLDEN_H
// =====================================================================
//  Golden de referencia: FWHT lossless multiplier-free
// 
//  Reutiliza pixel_t (ap_int<16>) del núcleo HLS para que la
//  comparación sea bit-exacta. El núcleo del algoritmo está templado por
//  el tipo numérico T:
//    - T = pixel_t (ap_int<16>) : replica bit-exacto al HW (wrap 16-bit).
//    - T = long long            : precisión "amplia" sin wrap, usada como
//                                 referencia anti-overflow.
//
//  Mariposa lifting (reversible, solo +,-,>>):
//    Forward:  d = a - b ;  s = a - (d>>1)     out[bajo]=s, out[alto]=d
//    Inverse:  a = s + (d>>1) ;  b = a - d      (deshace lo anterior)
//  Convención (igual que HW): s (baja frec.) al índice bajo, d al alto.
//
//  Etapas: el tamaño de bloque m recorre 2,4,...,n en forward y n,...,4,2
//  en inverse. En N=8 son las 3 etapas del HW con strides 1,2,4.
// =====================================================================
#include "wht_core.h"   // pixel_t, N

template <class T>
inline void butterfly_fwd(T a, T b, T &s, T &d) {
    d = a - b;
    s = a - (d >> 1);
}

template <class T>
inline void butterfly_inv(T s, T d, T &a, T &b) {
    a = s + (d >> 1);
    b = a - d;
}

// n debe ser potencia de 2; in/out son buffers separados de longitud n.
template <class T>
void wht_forward_t(const T *in, T *out, int n) {
    for (int i = 0; i < n; i++) out[i] = in[i];
    for (int m = 2; m <= n; m <<= 1) {              // etapas: bloque crece
        int half = m >> 1;
        for (int base = 0; base < n; base += m)
            for (int j = 0; j < half; j++) {
                T s, d;
                butterfly_fwd<T>(out[base + j], out[base + j + half], s, d);
                out[base + j]        = s;
                out[base + j + half] = d;
            }
    }
}

template <class T>
void wht_inverse_t(const T *in, T *out, int n) {
    for (int i = 0; i < n; i++) out[i] = in[i];
    for (int m = n; m >= 2; m >>= 1) {              // etapas en orden INVERSO
        int half = m >> 1;
        for (int base = 0; base < n; base += m)
            for (int j = 0; j < half; j++) {
                T a, b;
                butterfly_inv<T>(out[base + j], out[base + j + half], a, b);
                out[base + j]        = a;
                out[base + j + half] = b;
            }
    }
}

// API de conveniencia con el tipo del núcleo (pixel_t = ap_int<16>).
void wht_forward(const pixel_t *in, pixel_t *out, int n);
void wht_inverse(const pixel_t *in, pixel_t *out, int n);

#endif  // WHT_GOLDEN_H
