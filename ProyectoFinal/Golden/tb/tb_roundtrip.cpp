// =====================================================================
//  Round-trip lossless: inverse(forward(x)) == x
//  Anti-overflow: forward_16bit == forward_precisión_amplia
// 
//  prueba que el inverse es el inverso estructural EXACTO del forward
//  (es biyectivo por construcción, así que pasa incluso con overflow:
//  por eso NO alcanza para validar que 16 bits bastan).
//  
//  compara el forward en ap_int<16> (con wrap) contra el mismo forward
//  en long long (sin wrap). Si difieren, hubo overflow -> 16 bits no
//  alcanzan para ese rango de entrada.
//
//  Entrada asumida por el grupo: 8-bit [0,255] (configurable).
// =====================================================================
#include <iostream>
#include <cstdlib>
#include "wht_golden.h"

int main() {
    long long total = 0, rt_fail = 0, ovf = 0;
    std::srand(2025);

    // Corre round-trip (E5) siempre; overflow (E5b) solo si count_ovf.
    auto test = [&](const pixel_t blk[N], bool count_ovf) {
        pixel_t fwd[N], rec[N];
        wht_forward(blk, fwd, N);
        wht_inverse(fwd, rec, N);
        total++;
        for (int i = 0; i < N; i++)
            if ((long long)rec[i] != (long long)blk[i]) { rt_fail++; break; }

        if (count_ovf) {                       // E5b: 16-bit vs precisión amplia
            long long win[N], wout[N];
            for (int i = 0; i < N; i++) win[i] = (long long)blk[i];
            wht_forward_t<long long>(win, wout, N);
            for (int i = 0; i < N; i++)
                if (wout[i] != (long long)fwd[i]) { ovf++; break; }
        }
    };

    // 1) Bloque fijo de referencia.
    pixel_t b0[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    test(b0, true);

    // 2) Rango 8-bit [0,255] (la asunción): E5b debe dar 0 overflow.
    for (int t = 0; t < 200000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = std::rand() % 256;
        test(b, true);
    }

    // 3) Rango 16-bit pleno [-32768,32767]: estresa el inverse. Round-trip
    //    debe pasar SIEMPRE (no contamos overflow: aquí sí esperamos que haya).
    for (int t = 0; t < 200000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = (std::rand() % 65536) - 32768;
        test(b, false);
    }

    std::cout << "E5  round-trip inverse(forward(x))==x : " << (total - rt_fail)
              << "/" << total << (rt_fail ? "  FALLA\n" : "  PASA\n");
    std::cout << "E5b overflow con entrada 8-bit        : " << ovf
              << (ovf ? "  HAY OVERFLOW (16 bits NO alcanzan)\n"
                      : "  0  (16 bits ALCANZAN para 8-bit)\n");
    return (rt_fail || ovf) ? 1 : 0;
}
