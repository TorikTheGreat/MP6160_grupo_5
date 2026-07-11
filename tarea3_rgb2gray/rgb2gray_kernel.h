#ifndef RGB2GRAY_KERNEL_H
#define RGB2GRAY_KERNEL_H

#include <stdint.h>
#include <hls_stream.h>

struct rgb_t {
    uint8_t r;
    uint8_t g;
    uint8_t b;
};

// Declaración del top
void rgb2gray_top(const uint8_t* image_in, uint8_t* image_out, uint32_t num_pixels);

#endif
