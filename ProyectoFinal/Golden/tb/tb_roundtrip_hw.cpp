// =====================================================================
//  E6: round-trip del HARDWARE.  inv_core(fwd_core(x)) == x
// ---------------------------------------------------------------------
//  Complementa a tb_roundtrip.cpp, que corre sobre el modelo de referencia:
//  aquel demuestra que la construccion de lifting es reversible, este
//  demuestra que los DOS NUCLEOS SINTETIZABLES se componen en la identidad.
//
//  Por que hace falta un test aparte, y no basta con componer E4 y E4b:
//    - E4  verifica el forward del nucleo sobre entradas de 8 bits.
//    - E4b verifica el inverso del nucleo sobre vectores de 16 bits uniformes.
//  Pero la imagen del forward con entrada de 8 bits vive en una caja diminuta
//  (|c| <= 1020 para N=8), y la probabilidad de que un vector uniforme de 16
//  bits caiga ahi es del orden de 1e-16: cero de los 100 000 vectores de E4b
//  toca el dominio que produce E4. Las dos verificaciones son disjuntas en la
//  practica, asi que la composicion no queda cubierta por ninguna.
//
//  Este test SI enlaza wht_core.cpp: si cualquiera de los dos nucleos se
//  rompe, falla. (Comprobado por mutacion: con d>>1 -> d>>2 en el inverso,
//  tb_roundtrip sigue en verde y este cae.)
// =====================================================================
#include <iostream>
#include <cstdlib>
#include "wht_core.h"     // wht_lossless_core, wht_lossless_inverse, pixel_t, N
#include "wht_golden.h"   // solo para pixel_t/N coherentes

int main() {
    long long total = 0, fails = 0;

    // Un round-trip completo a traves de los dos nucleos sintetizables.
    auto roundtrip = [&](const pixel_t blk[N]) {
        pixel_t in[N], coef[N], rec_in[N], rec[N];
        for (int i = 0; i < N; i++) in[i] = blk[i];
        wht_lossless_core(in, coef);              // forward, nucleo HLS
        for (int i = 0; i < N; i++) rec_in[i] = coef[i];
        wht_lossless_inverse(rec_in, rec);        // inverso, nucleo HLS
        total++;
        for (int i = 0; i < N; i++)
            if ((long long)rec[i] != (long long)blk[i]) {
                if (fails == 0) {                 // solo el primero, para no inundar
                    std::cout << "  MISMATCH en la muestra " << i
                              << ": entrada=" << (long long)blk[i]
                              << " reconstruido=" << (long long)rec[i] << "\n";
                }
                fails++; return;
            }
    };

    std::srand(99);

    // 1) Bloque fijo de referencia (el mismo de los otros testbenches).
    pixel_t b0[N] = {100, 150, 120, 110, 105, 95, 130, 125};
    roundtrip(b0);

    // 2) Rango 8-bit [0,255]: el dominio de operacion declarado.
    for (int t = 0; t < 200000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = std::rand() % 256;
        roundtrip(b);
    }

    // 3) Rango 16-bit pleno: estresa el inverso fuera del dominio nominal.
    //    Debe pasar igual: el lifting es biyectivo sobre todo ap_int<16>.
    for (int t = 0; t < 200000; t++) {
        pixel_t b[N];
        for (int i = 0; i < N; i++) b[i] = (std::rand() % 65536) - 32768;
        roundtrip(b);
    }

    std::cout << "E6 round-trip del hardware inv_core(fwd_core(x))==x : "
              << (total - fails) << "/" << total
              << (fails ? "  FALLA\n" : "  PASA\n");
    return fails ? 1 : 0;
}
