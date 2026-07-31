#ifndef RGB_TO_GRAY_H
#define RGB_TO_GRAY_H

#include <cstdint>

// Conversión RGB -> escala de grises: luma BT.709 (ITU-R BT.709-6, ítem 3.2).
//   Y' = 0.2126 R' + 0.7152 G' + 0.0722 B'   (sobre R'G'B' ya codificados con gamma)
//
// Esta MISMA función la usan el acelerador (DUT) y el "golden" del testbench. Tenerla en un
// solo header evita que se desincronicen. Si el grupo cambia a BT.601 (0.299/0.587/0.114),
// se cambia aquí una sola vez.
//
// Para experimentar: cambia los tres pesos y observa cómo cambia el gris de cada color.
static inline uint8_t rgb_to_gray(uint8_t r, uint8_t g, uint8_t b) {
    double y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    return static_cast<uint8_t>(y + 0.5);   // redondeo al entero más cercano (0..255)
}

#endif // RGB_TO_GRAY_H