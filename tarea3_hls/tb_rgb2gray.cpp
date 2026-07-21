// ============================================================================
// Testbench: RGB → Escala de Grises (Vitis HLS csim)
// Llama directamente a rgb2gray_top() como requiere csim_design
// ============================================================================

#include <iostream>
#include <iomanip>
#include <cstdlib>
#include "rgb2gray_kernel.h"

// ============================================================================
// Golden Reference (BT.709)
// ============================================================================
static inline uint8_t golden_rgb_to_gray(uint8_t r, uint8_t g, uint8_t b) {
    // Mirror exact integer arithmetic used in rgb2gray_kernel.cpp
    uint32_t y = (uint32_t)r * 2126 + (uint32_t)g * 7152 + (uint32_t)b * 722;
    return (uint8_t)((y + 5000) / 10000);
}

// ============================================================================
// Helpers: pack RGB into flat AXI buffer (one byte per ap_uint<32> word)
// ============================================================================
static void pack_rgb(ap_uint<32> *buf, const uint8_t *r, const uint8_t *g,
                     const uint8_t *b, int num_pixels) {
    for (int i = 0; i < num_pixels; ++i) {
        buf[i * 3 + 0] = r[i];
        buf[i * 3 + 1] = g[i];
        buf[i * 3 + 2] = b[i];
    }
}

// ============================================================================
// Run top-level DUT and return error count
// ============================================================================
static int run_dut(const uint8_t *r, const uint8_t *g, const uint8_t *b,
                   const uint8_t *expected, int num_pixels,
                   ap_uint<32> *m_axi_in, ap_uint<32> *m_axi_out) {
    pack_rgb(m_axi_in, r, g, b, num_pixels);

    // addr_in=0, addr_out=0 (base of each buffer)
    rgb2gray_top(m_axi_in, m_axi_out, 0, 0, num_pixels);

    int errors = 0;
    for (int i = 0; i < num_pixels; ++i) {
        uint8_t actual = (uint8_t)(ap_uint<8>)m_axi_out[i];
        if (actual != expected[i]) {
            ++errors;
            if (errors <= 5) {
                std::cerr << "  [FAIL] pixel " << i
                          << ": expected=" << (int)expected[i]
                          << " got=" << (int)actual << std::endl;
            }
        }
    }
    return errors;
}

// ============================================================================
// Main
// ============================================================================
int main() {
    std::cout << "\n========================================\n"
              << " C Simulation: RGB -> Escala de Grises\n"
              << " P2 (kernel) + P3 (pragmas AXI)\n"
              << "========================================\n";

    int total_errors = 0;

    // ------------------------------------------------------------------
    // TEST 1: 12 píxeles conocidos
    // ------------------------------------------------------------------
    {
        const int N = 12;
        uint8_t r[N]   = {  0, 255, 255,   0,   0, 128, 255,   0, 255, 100, 200,  10};
        uint8_t g[N]   = {  0, 255,   0, 255,   0, 128, 255, 255,   0, 150,  50, 200};
        uint8_t b[N]   = {  0, 255,   0,   0, 255, 128,   0, 255, 255, 200,  75, 100};
        uint8_t expected[N];
        for (int i = 0; i < N; ++i)
            expected[i] = golden_rgb_to_gray(r[i], g[i], b[i]);

        ap_uint<32> in_buf[N * 3];
        ap_uint<32> out_buf[N];

        int e = run_dut(r, g, b, expected, N, in_buf, out_buf);
        total_errors += e;
        std::cout << "TEST 1 (Pixeles):  " << (e == 0 ? "PASS" : "FAIL")
                  << "  (" << e << " errores)\n";
    }

    // ------------------------------------------------------------------
    // TEST 2: Imagen 16x16 con gradiente
    // ------------------------------------------------------------------
    {
        const int W = 16, H = 16, N = W * H;
        uint8_t r[N], g[N], b[N], expected[N];
        for (int i = 0; i < N; ++i) {
            int x = i % W, y = i / W;
            r[i] = (uint8_t)((255 * x) / (W - 1));
            g[i] = (uint8_t)((255 * y) / (H - 1));
            b[i] = 128;
            expected[i] = golden_rgb_to_gray(r[i], g[i], b[i]);
        }

        ap_uint<32> in_buf[N * 3];
        ap_uint<32> out_buf[N];

        int e = run_dut(r, g, b, expected, N, in_buf, out_buf);
        total_errors += e;
        std::cout << "TEST 2 (16x16):    " << (e == 0 ? "PASS" : "FAIL")
                  << "  (" << e << " errores)\n";
    }

    // ------------------------------------------------------------------
    // TEST 3: Imagen 1920x1080 aleatoria (2,073,600 píxeles - 1080p HD)
    // ------------------------------------------------------------------
    {
        const int N = 2073600;  // 1920 * 1080
        static uint8_t r[N], g[N], b[N], expected[N];
        static ap_uint<32> in_buf[N * 3];
        static ap_uint<32> out_buf[N];

        srand(42);
        for (int i = 0; i < N; ++i) {
            r[i] = (uint8_t)(rand() % 256);
            g[i] = (uint8_t)(rand() % 256);
            b[i] = (uint8_t)(rand() % 256);
            expected[i] = golden_rgb_to_gray(r[i], g[i], b[i]);
        }

        int e = run_dut(r, g, b, expected, N, in_buf, out_buf);
        total_errors += e;
        std::cout << "TEST 3 (1920x1080): " << (e == 0 ? "PASS" : "FAIL")
                  << "  (" << e << " errores)\n";
    }

    // ------------------------------------------------------------------
    // Resumen
    // ------------------------------------------------------------------
    std::cout << "\n========================================\n"
              << " RESUMEN DE PRUEBAS\n"
              << "========================================\n"
              << "Errores totales: " << total_errors << "\n"
              << "Resultado global: " << (total_errors == 0 ? "PASS" : "FAIL") << "\n"
              << "========================================\n\n";

    return (total_errors == 0) ? 0 : 1;
}
