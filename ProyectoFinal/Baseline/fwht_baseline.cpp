#include "fwht_baseline.h"

void fwht_baseline(
    pixel_t input[N],
    pixel_t output[N]
)
{
#pragma HLS INTERFACE ap_memory port=input
#pragma HLS INTERFACE ap_memory port=output
#pragma HLS PIPELINE II=1

    pixel_t stage1[N];
    pixel_t stage2[N];
    pixel_t stage3[N];

    // Stage 1
    stage1[0] = input[0] + input[1];
    stage1[1] = input[0] - input[1];

    stage1[2] = input[2] + input[3];
    stage1[3] = input[2] - input[3];

    stage1[4] = input[4] + input[5];
    stage1[5] = input[4] - input[5];

    stage1[6] = input[6] + input[7];
    stage1[7] = input[6] - input[7];

    // Stage 2
    stage2[0] = stage1[0] + stage1[2];
    stage2[1] = stage1[1] + stage1[3];
    stage2[2] = stage1[0] - stage1[2];
    stage2[3] = stage1[1] - stage1[3];

    stage2[4] = stage1[4] + stage1[6];
    stage2[5] = stage1[5] + stage1[7];
    stage2[6] = stage1[4] - stage1[6];
    stage2[7] = stage1[5] - stage1[7];

    // Stage 3
    stage3[0] = stage2[0] + stage2[4];
    stage3[1] = stage2[1] + stage2[5];
    stage3[2] = stage2[2] + stage2[6];
    stage3[3] = stage2[3] + stage2[7];

    stage3[4] = stage2[0] - stage2[4];
    stage3[5] = stage2[1] - stage2[5];
    stage3[6] = stage2[2] - stage2[6];
    stage3[7] = stage2[3] - stage2[7];

    for (int i = 0; i < N; i++) {
#pragma HLS UNROLL
        output[i] = stage3[i];
    }
}