#ifndef WHT_MULTIPLIER_BASELINE_H
#define WHT_MULTIPLIER_BASELINE_H

#include <ap_int.h>

constexpr int MULT_N = 8;
constexpr int MULT_FRAC_BITS = 15;

typedef ap_int<16> mult_pixel_t;
typedef ap_int<16> mult_coef_t;
typedef ap_int<32> mult_product_t;

void wht_multiplier_forward(
    mult_pixel_t input[MULT_N],
    mult_pixel_t output[MULT_N],
    mult_coef_t half_q15
);

void wht_multiplier_inverse(
    mult_pixel_t input[MULT_N],
    mult_pixel_t output[MULT_N],
    mult_coef_t half_q15
);

#endif
