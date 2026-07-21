#ifndef RGB2GRAY_KERNEL_H
#define RGB2GRAY_KERNEL_H

// ============================================================================
// P2: Kernel HLS - Conversión RGB → Escala de Grises
// Integrado en P3 con pragmas AXI
// ============================================================================

#include <stdint.h>
#include <hls_stream.h>
#include <ap_int.h>

// Tipo de píxel RGB (P2)
struct rgb_t {
    ap_uint<8> r;
    ap_uint<8> g;
    ap_uint<8> b;
};

// ============================================================================
// ETAPA 1: Load - Lee píxeles RGB desde memoria
// ============================================================================
void load_rgb(
    volatile ap_uint<32> *m_axi_in,
    ap_uint<32> addr_in,
    ap_uint<32> num_pixels,
    hls::stream<rgb_t> &out_stream);

// ============================================================================
// ETAPA 2: Process - Convierte RGB a escala de grises (BT.709)
// ============================================================================
void process_gray(
    hls::stream<rgb_t> &in_stream,
    hls::stream<ap_uint<8>> &out_stream,
    ap_uint<32> num_pixels);

// ============================================================================
// ETAPA 3: Store - Escribe píxeles grises a memoria
// ============================================================================
void store_gray(
    hls::stream<ap_uint<8>> &in_stream,
    volatile ap_uint<32> *m_axi_out,
    ap_uint<32> addr_out,
    ap_uint<32> num_pixels);

// ============================================================================
// FUNCIÓN TOP-LEVEL: Interfaz AXI4-Lite + AXI4-Master (P3)
// Control via scalar s_axilite ports (Vitis kernel convention)
// ============================================================================
extern "C" void rgb2gray_top(
    volatile ap_uint<32> *m_axi_in,
    volatile ap_uint<32> *m_axi_out,
    ap_uint<32> addr_in,
    ap_uint<32> addr_out,
    ap_uint<32> num_pixels);

#endif // RGB2GRAY_KERNEL_H
