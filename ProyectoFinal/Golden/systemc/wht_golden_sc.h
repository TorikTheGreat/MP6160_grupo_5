#ifndef WHT_GOLDEN_SC_H
#define WHT_GOLDEN_SC_H
// =====================================================================
//  Golden WHT como módulo SystemC
// 
//  Presenta el golden como un componente hardware-like: reloj + handshake
//  start/done. La aritmética no vive aquí: el proceso llama a las
//  funciones puras ya verificadas (wht_forward/wht_inverse de wht_golden.h).
//  SystemC es solo la cáscara/interfaz; así el modelo encaja en el marco
//  del curso sin reescribir (ni ensuciar) la matemática con sc_int.
//
//  Protocolo: el driver carga in_block[], pulsa start=1; en el flanco de
//  reloj el proceso computa forward hacia out_block[] y levanta done=1.
// =====================================================================
#include <systemc.h>
#include "wht_golden.h"   // funciones puras + pixel_t, N

SC_MODULE(WhtGoldenSC) {
    sc_in<bool> clk;
    sc_in<bool> start;
    sc_out<bool> done;

    // Datos por miembros (no es RTL: es un modelo funcional). El driver los
    // lee/escribe directamente; el control va por señales.
    pixel_t in_block[N];
    pixel_t out_block[N];

    void proc() {
        done.write(false);
        while (true) {
            wait();                          // flanco de reloj
            if (start.read()) {
                wht_forward(in_block, out_block, N);   // <-- matemática pura
                done.write(true);
                wait();                      // mantener done un ciclo
                done.write(false);
            }
        }
    }

    SC_CTOR(WhtGoldenSC) {
        SC_THREAD(proc);
        sensitive << clk.pos();
    }
};

#endif  // WHT_GOLDEN_SC_H
