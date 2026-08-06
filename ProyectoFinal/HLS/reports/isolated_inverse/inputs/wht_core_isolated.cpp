#include "wht_core_isolated.h"

static void lifting_butterfly_isolated(
    pixel_t a,
    pixel_t b,
    pixel_t &s,
    pixel_t &d
) {
#pragma HLS INLINE
    d = a - b;
    s = a - (d >> 1);
}

static void inverse_lifting_butterfly_isolated(
    pixel_t s,
    pixel_t d,
    pixel_t &a,
    pixel_t &b
) {
#pragma HLS INLINE
    a = s + (d >> 1);
    b = a - d;
}

void wht_lossless_forward_isolated(
    pixel_t block_in[N],
    pixel_t block_out[N]
) {
#pragma HLS INTERFACE ap_memory port=block_in
#pragma HLS INTERFACE ap_memory port=block_out
#pragma HLS PIPELINE II=1

    pixel_t stage[N];
    pixel_t tmp1[N];
    pixel_t tmp2[N];

#pragma HLS ARRAY_PARTITION variable=stage complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp1 complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp2 complete dim=1

    for (int i = 0; i < N; ++i) {
#pragma HLS UNROLL
        stage[i] = block_in[i];
    }

    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        lifting_butterfly_isolated(
            stage[2 * i], stage[2 * i + 1],
            tmp1[2 * i], tmp1[2 * i + 1]
        );
    }

    for (int i = 0; i < 2; ++i) {
#pragma HLS UNROLL
        lifting_butterfly_isolated(
            tmp1[4 * i], tmp1[4 * i + 2],
            tmp2[4 * i], tmp2[4 * i + 2]
        );
        lifting_butterfly_isolated(
            tmp1[4 * i + 1], tmp1[4 * i + 3],
            tmp2[4 * i + 1], tmp2[4 * i + 3]
        );
    }

    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        lifting_butterfly_isolated(
            tmp2[i], tmp2[i + 4],
            block_out[i], block_out[i + 4]
        );
    }
}

void wht_lossless_inverse_isolated(
    pixel_t block_in[N],
    pixel_t block_out[N]
) {
#pragma HLS INTERFACE ap_memory port=block_in
#pragma HLS INTERFACE ap_memory port=block_out
#pragma HLS PIPELINE II=1

    pixel_t stage[N];
    pixel_t tmp2[N];
    pixel_t tmp1[N];

#pragma HLS ARRAY_PARTITION variable=stage complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp2 complete dim=1
#pragma HLS ARRAY_PARTITION variable=tmp1 complete dim=1

    for (int i = 0; i < N; ++i) {
#pragma HLS UNROLL
        stage[i] = block_in[i];
    }

    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        inverse_lifting_butterfly_isolated(
            stage[i], stage[i + 4],
            tmp2[i], tmp2[i + 4]
        );
    }

    for (int i = 0; i < 2; ++i) {
#pragma HLS UNROLL
        inverse_lifting_butterfly_isolated(
            tmp2[4 * i], tmp2[4 * i + 2],
            tmp1[4 * i], tmp1[4 * i + 2]
        );
        inverse_lifting_butterfly_isolated(
            tmp2[4 * i + 1], tmp2[4 * i + 3],
            tmp1[4 * i + 1], tmp1[4 * i + 3]
        );
    }

    for (int i = 0; i < 4; ++i) {
#pragma HLS UNROLL
        inverse_lifting_butterfly_isolated(
            tmp1[2 * i], tmp1[2 * i + 1],
            block_out[2 * i], block_out[2 * i + 1]
        );
    }
}
