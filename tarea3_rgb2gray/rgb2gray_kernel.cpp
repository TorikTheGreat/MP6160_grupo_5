#include "rgb2gray_kernel.h"
#include <ap_fixed.h>

// Definir los tipos de punto fijo para los coeficientes y el cálculo
// ap_ufixed<16, 1> significa: sin signo, 16 bits en total, 1 bit para la parte entera (0 o 1) y 15 para decimales.
typedef ap_ufixed<16, 1> coef_t;
typedef ap_ufixed<24, 9> calc_t; // 24 bits totales, 9 enteros (para albergar hasta el valor 255)

// 1. Etapa de Lectura (Load)
void load_rgb(const uint8_t* in_ram, hls::stream<rgb_t>& out_stream, uint32_t num_pixels) {
    load_loop: for (uint32_t i = 0; i < num_pixels; i++) {
        #pragma HLS PIPELINE II=1
        rgb_t pixel;
        // Asumiendo que in_ram tiene formato RGB entrelazado (R, G, B, R, G, B...)
        uint32_t offset = i * 3;
        pixel.r = in_ram[offset];
        pixel.g = in_ram[offset + 1];
        pixel.b = in_ram[offset + 2];
        out_stream.write(pixel);
    }
}

// 2. Etapa de Procesamiento (Compute)
void process_gray(hls::stream<rgb_t>& in_stream, hls::stream<uint8_t>& out_stream, uint32_t num_pixels) {
    
    // Declaración de coeficientes en hardware (se sintetizan como constantes)
    const coef_t W_R = 0.2126;
    const coef_t W_G = 0.7152;
    const coef_t W_B = 0.0722;

    process_loop: for (uint32_t i = 0; i < num_pixels; i++) {
        #pragma HLS PIPELINE II=1
        rgb_t pixel = in_stream.read();
        
        // Uso de ap_fixed para un timing veloz y bajo consumo de DSPs
        calc_t y = (W_R * pixel.r) + (W_G * pixel.g) + (W_B * pixel.b);
        
        // Cast automático de ap_fixed a uint8_t truncando los decimales (con redondeo manual +0.5)
        uint8_t gray = static_cast<uint8_t>(y + (calc_t)0.5);
        
        out_stream.write(gray);
    }
}

// 3. Etapa de Escritura (Store)
void store_gray(hls::stream<uint8_t>& in_stream, uint8_t* out_ram, uint32_t num_pixels) {
    store_loop: for (uint32_t i = 0; i < num_pixels; i++) {
        #pragma HLS PIPELINE II=1
        out_ram[i] = in_stream.read();
    }
}

// Top-level de HLS
void rgb2gray_top(const uint8_t* image_in, uint8_t* image_out, uint32_t num_pixels) {
    // P3 se encargará de los pragmas AXI (m_axi, s_axilite), 
    #pragma HLS DATAFLOW
    
    // Streams internos
    hls::stream<rgb_t> stream_rgb("stream_rgb");
    hls::stream<uint8_t> stream_gray("stream_gray");
    
    // Profundidad de los FIFOs entre etapas (para evitar deadlocks)
    #pragma HLS STREAM variable=stream_rgb depth=16
    #pragma HLS STREAM variable=stream_gray depth=16
    
    // Instanciar etapas
    load_rgb(image_in, stream_rgb, num_pixels);
    process_gray(stream_rgb, stream_gray, num_pixels);
    store_gray(stream_gray, image_out, num_pixels);
}
