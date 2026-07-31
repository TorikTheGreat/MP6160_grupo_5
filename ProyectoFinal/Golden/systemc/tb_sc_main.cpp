// =====================================================================
//  Testbench en SystemC reproducible (demo del golden WHT)
// 
//  Maneja el módulo WhtGoldenSC por su handshake de reloj y verifica cada
//  bloque de dos formas:
//    - Equivalencia con el núcleo real de hardware  (wht_lossless_core)
//    - Round-trip lossless  inverse(forward(x)) == x               
//  Imprime un bloque de ejemplo (entrada / coeficientes / reconstrucción)
//  para la demostración en video. La verificación exhaustiva (100k+)
//  vive en los TB de C++ plano; aquí se demuestra el modelo EN SystemC.
// =====================================================================
#include <systemc.h>
#include <cstdlib>
#include "wht_golden_sc.h"   // DUT
#include "wht_core.h"        // núcleo de W1 para comparar
#include "wht_golden.h"      // funciones puras (inverse para el round-trip)

SC_MODULE(Driver) {
    sc_in<bool> clk;
    sc_out<bool> start;
    sc_in<bool> done;
    WhtGoldenSC *dut;        // acceso directo a los buffers (modelo funcional)

    long long total = 0, fail_eq = 0, fail_rt = 0;

    // Empuja un bloque por el DUT y devuelve los coeficientes por out[].
    void run_block(const pixel_t in[N], pixel_t out[N]) {
        for (int i = 0; i < N; i++) dut->in_block[i] = in[i];
        start.write(true);
        wait();                                  // el DUT ve start en este flanco
        start.write(false);
        while (!done.read()) wait();             // esperar done
        for (int i = 0; i < N; i++) out[i] = dut->out_block[i];
        wait();                                  // dejar que done baje
    }

    void check(const pixel_t in[N]) {
        pixel_t coef[N];
        run_block(in, coef);
        total++;

        // mismo resultado que el núcleo de W1
        pixel_t w_in[N], w[N];
        for (int i = 0; i < N; i++) w_in[i] = in[i];
        wht_lossless_core(w_in, w);
        for (int i = 0; i < N; i++)
            if ((long long)coef[i] != (long long)w[i]) { fail_eq++; break; }

        // round-trip lossless
        pixel_t rec[N];
        wht_inverse(coef, rec, N);
        for (int i = 0; i < N; i++)
            if ((long long)rec[i] != (long long)in[i]) { fail_rt++; break; }
    }

    void print_block(const char *label, const pixel_t b[N]) {
        std::cout << label;
        for (int i = 0; i < N; i++) std::cout << " " << (long long)b[i];
        std::cout << "\n";
    }

    void run() {
        wait();  // arrancar sincronizados con el reloj

        // --- Bloque de demostración (para el video) ---
        pixel_t demo[N] = {100, 150, 120, 110, 105, 95, 130, 125};
        pixel_t coef[N], rec[N];
        run_block(demo, coef);
        wht_inverse(coef, rec, N);
        std::cout << "--- Demo golden WHT en SystemC (N=8) ---\n";
        print_block("Entrada       :", demo);
        print_block("Coeficientes  :", coef);
        print_block("Reconstruccion:", rec);
        std::cout << (/*ok?*/ [&] { for (int i=0;i<N;i++) if((long long)rec[i]!=(long long)demo[i]) return false; return true; }()
                      ? ">> Reconstruccion EXACTA (lossless)\n\n" : ">> FALLO\n\n");

        // --- Verificación sobre un lote reproducible ---
        check(demo);
        std::srand(7);
        for (int t = 0; t < 2000; t++) {
            pixel_t b[N];
            for (int i = 0; i < N; i++) b[i] = std::rand() % 256;   // 8-bit
            check(b);
        }

        std::cout << "E4 equivalencia vs nucleo W1 : " << (total - fail_eq) << "/" << total
                  << (fail_eq ? "  FALLA\n" : "  PASA\n");
        std::cout << "E5 round-trip lossless       : " << (total - fail_rt) << "/" << total
                  << (fail_rt ? "  FALLA\n" : "  PASA\n");

        sc_stop();
    }

    SC_CTOR(Driver) {
        SC_THREAD(run);
        sensitive << clk.pos();
    }
};

int sc_main(int, char *[]) {
    sc_clock        clk("clk", 10, SC_NS);
    sc_signal<bool> start, done;

    WhtGoldenSC dut("dut");
    dut.clk(clk); dut.start(start); dut.done(done);

    Driver drv("drv");
    drv.clk(clk); drv.start(start); drv.done(done);
    drv.dut = &dut;

    sc_start();
    return 0;
}
