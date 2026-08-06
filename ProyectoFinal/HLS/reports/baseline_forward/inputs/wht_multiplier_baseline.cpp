#include "wht_multiplier_baseline.h"

/*
 * Multiplicación por 0.5 usando representación Q1.15.
 * El valor 16384 equivale a 0.5 (16384 / 2^15).
 */
static mult_pixel_t multiply_half(
    mult_pixel_t value,
    mult_coef_t half_q15
) {
#pragma HLS INLINE

    mult_product_t product = value * half_q15;

    return (mult_pixel_t)(product >> MULT_FRAC_BITS);
}

static void multiplier_butterfly(
    mult_pixel_t a,
    mult_pixel_t b,
    mult_pixel_t &s,
    mult_pixel_t &d,
    mult_coef_t half_q15
) {
#pragma HLS INLINE

    d = a - b;
    s = a - multiply_half(d, half_q15);
}

static void inverse_multiplier_butterfly(
    mult_pixel_t s,
    mult_pixel_t d,
    mult_pixel_t &a,
    mult_pixel_t &b,
    mult_coef_t half_q15
) {
#pragma HLS INLINE

    a = s + multiply_half(d, half_q15);
    b = a - d;
}

void wht_multiplier_forward(
    mult_pixel_t input[MULT_N],
    mult_pixel_t output[MULT_N],
    mult_coef_t half_q15
) {
#pragma HLS INTERFACE ap_memory port=input
#pragma HLS INTERFACE ap_memory port=output
#pragma HLS INTERFACE ap_none port=half_q15
#pragma HLS PIPELINE II=1

    mult_pixel_t stage[MULT_N];
    mult_pixel_t tmp1[MULT_N];
    mult_pixel_t tmp2[MULT_N];

#pragma HLS ARRAY_PARTITION variable=stage complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp1 complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp2 complete dim=1

    for (int i = 0; i < MULT_N; ++i) {
#pragma HLS UNROLL
        stage[i] = input[i];
    }

    // Etapa 1
    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        multiplier_butterfly(
            stage[2 * i],
            stage[2 * i + 1],
            tmp1[2 * i],
            tmp1[2 * i + 1],
            half_q15
        );
    }

    // Etapa 2
    for (int i = 0; i < 2; ++i) {
#pragma HLS UNROLL
        multiplier_butterfly(
            tmp1[4 * i],
            tmp1[4 * i + 2],
            tmp2[4 * i],
            tmp2[4 * i + 2],
            half_q15
        );

        multiplier_butterfly(
            tmp1[4 * i + 1],
            tmp1[4 * i + 3],
            tmp2[4 * i + 1],
            tmp2[4 * i + 3],
            half_q15
        );
    }

    // Etapa 3
    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        multiplier_butterfly(
            tmp2[i],
            tmp2[i + 4],
            output[i],
            output[i + 4],
            half_q15
        );
    }
}

void wht_multiplier_inverse(
    mult_pixel_t input[MULT_N],
    mult_pixel_t output[MULT_N],
    mult_coef_t half_q15
) {
#pragma HLS INTERFACE ap_memory port=input
#pragma HLS INTERFACE ap_memory port=output
#pragma HLS INTERFACE ap_none port=half_q15
#pragma HLS PIPELINE II=1

    mult_pixel_t stage[MULT_N];
    mult_pixel_t tmp2[MULT_N];
    mult_pixel_t tmp1[MULT_N];

#pragma HLS ARRAY_PARTITION variable=stage complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp2 complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp1 complete dim=1

    for (int i = 0; i < MULT_N; ++i) {
#pragma HLS UNROLL
        stage[i] = input[i];
    }

    // Inversa de la etapa 3
    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        inverse_multiplier_butterfly(
            stage[i],
            stage[i + 4],
            tmp2[i],
            tmp2[i + 4],
            half_q15
        );
    }

    // Inversa de la etapa 2
    for (int i = 0; i < 2; ++i) {
#pragma HLS UNROLL
        inverse_multiplier_butterfly(
            tmp2[4 * i],
            tmp2[4 * i + 2],
            tmp1[4 * i],
            tmp1[4 * i + 2],
            half_q15
        );

        inverse_multiplier_butterfly(
            tmp2[4 * i + 1],
            tmp2[4 * i + 3],
            tmp1[4 * i + 1],
            tmp1[4 * i + 3],
            half_q15
        );
    }

    // Inversa de la etapa 1
    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        inverse_multiplier_butterfly(
            tmp1[2 * i],
            tmp1[2 * i + 1],
            output[2 * i],
            output[2 * i + 1],
            half_q15
        );
    }
}
