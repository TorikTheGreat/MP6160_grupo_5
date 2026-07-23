#ifndef FWHT_BASELINE_H
#define FWHT_BASELINE_H

#include <ap_int.h>

constexpr int N = 8;

typedef ap_int<16> pixel_t;

void fwht_baseline(
    pixel_t input[N],
    pixel_t output[N]
);

#endif