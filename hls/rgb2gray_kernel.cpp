// ============================================================================
// P2/P3: Kernel HLS Síntesis - RGB → Escala de Grises
// ============================================================================
// P2: Arquitectura load-process-store (3 etapas pipelined)
// P3: Pragmas AXI optimizados (AXI4-Lite control, AXI4-Master DMA)
// ============================================================================

#include "rgb2gray_kernel.h"

// ============================================================================
// Función auxiliar: Conversión pixel RGB → Gris (BT.709)
// ============================================================================
static inline ap_uint<8> rgb_to_gray_pixel(ap_uint<8> r, ap_uint<8> g, ap_uint<8> b) {
    // Coeficientes BT.709 escalados por 10000 para que el redondeo coincida
    // con la referencia del testbench: Y' = 0.2126R + 0.7152G + 0.0722B
    ap_uint<32> y = 0;
    y += (ap_uint<32>)r * 2126;  // 0.2126 * 10000
    y += (ap_uint<32>)g * 7152;  // 0.7152 * 10000
    y += (ap_uint<32>)b * 722;   // 0.0722 * 10000
    y = (y + 5000) / 10000;      // Redondeo al entero más cercano
    return (ap_uint<8>)y;
}

// ============================================================================
// ETAPA 1: Load - Lee píxeles RGB desde memoria con DMA pipelined
// ============================================================================
// Entrada: m_axi_in (AXI4-Master, interfaz de lectura)
// Salida: stream de píxeles RGB
// Pragma: PIPELINE II=1 para máximo throughput de lectura
void load_rgb(
    volatile ap_uint<32> *m_axi_in,
    ap_uint<32> addr_in,
    ap_uint<32> num_pixels,
    hls::stream<rgb_t> &out_stream) {
#pragma HLS INLINE off

    load_loop: for (ap_uint<32> i = 0; i < num_pixels; ++i) {
#pragma HLS PIPELINE II=1 rewind
        
        ap_uint<32> in_addr_base = addr_in + i * 3;
        
        // Lectura de 3 bytes (R, G, B) desde direcciones consecutivas
        ap_uint<8> r = (ap_uint<8>)m_axi_in[in_addr_base + 0];
        ap_uint<8> g = (ap_uint<8>)m_axi_in[in_addr_base + 1];
        ap_uint<8> b = (ap_uint<8>)m_axi_in[in_addr_base + 2];
        
        rgb_t pixel;
        pixel.r = r;
        pixel.g = g;
        pixel.b = b;
        
        out_stream.write(pixel);
    }
}

// ============================================================================
// ETAPA 2: Process - Convierte RGB a escala de grises
// ============================================================================
// Entrada: stream de píxeles RGB
// Salida: stream de píxeles grises
// Pragma: PIPELINE II=1 para máximo throughput de procesamiento
void process_gray(
    hls::stream<rgb_t> &in_stream,
    hls::stream<ap_uint<8>> &out_stream,
    ap_uint<32> num_pixels) {
#pragma HLS INLINE off

    process_loop: for (ap_uint<32> i = 0; i < num_pixels; ++i) {
#pragma HLS PIPELINE II=1
        
        rgb_t pixel = in_stream.read();
        ap_uint<8> gray = rgb_to_gray_pixel(pixel.r, pixel.g, pixel.b);
        out_stream.write(gray);
    }
}

// ============================================================================
// ETAPA 3: Store - Escribe píxeles grises a memoria con DMA pipelined
// ============================================================================
// Entrada: stream de píxeles grises
// Salida: m_axi_out (AXI4-Master, interfaz de escritura)
// Pragma: PIPELINE II=1 para máximo throughput de escritura
void store_gray(
    hls::stream<ap_uint<8>> &in_stream,
    volatile ap_uint<32> *m_axi_out,
    ap_uint<32> addr_out,
    ap_uint<32> num_pixels) {
#pragma HLS INLINE off

    store_loop: for (ap_uint<32> i = 0; i < num_pixels; ++i) {
#pragma HLS PIPELINE II=1 rewind
        
        ap_uint<8> gray = in_stream.read();
        ap_uint<32> out_addr = addr_out + i;
        m_axi_out[out_addr] = gray;
    }
}

// ============================================================================
// TOP-LEVEL (P3): Interfaz AXI4-Lite + AXI4-Master con dataflow
// ============================================================================
// Función top-level que implementa la interfaz AXI y coordina las 3 etapas
//
// Entrada:
//   - s_axi_ctrl[4]: Registros de control (CONTROL, ADDR_IN, ADDR_OUT, NUM_PIXELS)
//   - m_axi_in: Interfaz de lectura DMA (entrada RGB)
//   - m_axi_out: Interfaz de escritura DMA (salida gris)
//   - m_axi_status: Registro de estado (DONE flag)
//
// Pragmas AXI:
//   - s_axilite: Registros de control mapeados en memoria (MMIO)
//   - m_axi: Interfaces de DMA con soporte a bursteo
//   - DATAFLOW: Etapas en paralelo para máximo throughput
extern "C" void rgb2gray_top(
    volatile ap_uint<32> *m_axi_in,
    volatile ap_uint<32> *m_axi_out,
    ap_uint<32> addr_in,
    ap_uint<32> addr_out,
    ap_uint<32> num_pixels) {

    // ========== INTERFACES AXI (Vitis kernel convention) ==========
    // AXI4-Master para entrada RGB (DMA)
    #pragma HLS INTERFACE m_axi port=m_axi_in  offset=slave bundle=gmem_in  depth=512
    // AXI4-Master para salida gris (DMA)
    #pragma HLS INTERFACE m_axi port=m_axi_out offset=slave bundle=gmem_out depth=512
    // AXI4-Lite scalar control ports (un bundle automatico)
    #pragma HLS INTERFACE s_axilite port=addr_in
    #pragma HLS INTERFACE s_axilite port=addr_out
    #pragma HLS INTERFACE s_axilite port=num_pixels
    #pragma HLS INTERFACE s_axilite port=return

    // ========== DATAFLOW: 3 etapas pipelined ==========
    #pragma HLS DATAFLOW
    hls::stream<rgb_t>    stream_rgb("stream_rgb");
    hls::stream<ap_uint<8>> stream_gray("stream_gray");
    #pragma HLS STREAM variable=stream_rgb  depth=16
    #pragma HLS STREAM variable=stream_gray depth=16

    load_rgb  (m_axi_in,    addr_in,  num_pixels, stream_rgb);
    process_gray(stream_rgb, stream_gray, num_pixels);
    store_gray(stream_gray, m_axi_out, addr_out, num_pixels);
}
