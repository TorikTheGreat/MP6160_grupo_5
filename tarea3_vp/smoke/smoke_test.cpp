// Fase B — smoke test STANDALONE (SystemC puro, sin gem5).
// Verifica que el acelerador de la T2 convierte RGB->gris bit-exact contra el golden BT.709,
// en la nueva estructura del VP. Es el baseline: si esto no pasa, no tiene sentido meterlo a gem5.
// (Reusa el patrón de la Tarea 2: driver escribe registros por TLM + ram.h por backdoor.)
#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <fstream>
#include <vector>
#include <iostream>
#include "accelerator.h"
#include "ram.h"
#include "rgb_to_gray.h"

static constexpr uint64_t SRC = 0x00000000ull;   // buffer de entrada (RGB) en RAM
static constexpr uint64_t DST = 0x02000000ull;   // buffer de salida (gris)

// "CPU" mínima: escribe los registros del acelerador por TLM y espera DONE.
struct Driver : sc_module {
    tlm_utils::simple_initiator_socket<Driver> sock;       // -> acc.cfg_socket
    tlm_utils::simple_initiator_socket<Driver> sock_ram;   // -> ram.socket_cpu (sin uso; solo binding)
    uint32_t src, dst, num;
    SC_HAS_PROCESS(Driver);
    Driver(sc_module_name n, uint32_t s, uint32_t d, uint32_t p)
        : sc_module(n), sock("sock"), sock_ram("sock_ram"), src(s), dst(d), num(p) { SC_THREAD(run); }

    void wr(uint64_t off, uint32_t v) {
        tlm::tlm_generic_payload t; sc_time delay = SC_ZERO_TIME;
        t.set_command(tlm::TLM_WRITE_COMMAND); t.set_address(ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<unsigned char*>(&v)); t.set_data_length(4);
        t.set_streaming_width(4); t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        sock->b_transport(t, delay); sc_assert(t.is_response_ok());
    }
    uint32_t rd(uint64_t off) {
        uint32_t v = 0; tlm::tlm_generic_payload t; sc_time delay = SC_ZERO_TIME;
        t.set_command(tlm::TLM_READ_COMMAND); t.set_address(ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<unsigned char*>(&v)); t.set_data_length(4);
        t.set_streaming_width(4); t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        sock->b_transport(t, delay); sc_assert(t.is_response_ok());
        return v;
    }
    void run() {
        wr(0x04, src); wr(0x08, dst); wr(0x0C, num);   // ADDR_INPUT / ADDR_OUTPUT / NUM_PIXELS
        wr(0x00, 1);                                    // CONTROL: START
        while ((rd(0x00) & 1u) == 0) wait(1, SC_NS);    // poll DONE
        std::cout << "Driver: DONE en t=" << sc_time_stamp() << "\n";
        sc_stop();
    }
};

int sc_main(int, char*[]) {
    const uint32_t W = 8, H = 8, N = W * H;
    // Imagen de prueba: 5 colores conocidos (esperados BT.709: 0,255,54,182,18) + degradado.
    std::vector<uint8_t> img(N * 3);
    auto px = [&](uint32_t i, uint8_t r, uint8_t g, uint8_t b){ img[3*i]=r; img[3*i+1]=g; img[3*i+2]=b; };
    px(0, 0,0,0); px(1, 255,255,255); px(2, 255,0,0); px(3, 0,255,0); px(4, 0,0,255);
    for (uint32_t i = 5; i < N; ++i) px(i, i % 256, (2*i) % 256, (3*i) % 256);
    { std::ofstream f("in.rgb", std::ios::binary); f.write(reinterpret_cast<char*>(img.data()), img.size()); }

    RAM ram("ram");
    Accelerator acc("acc");
    Driver drv("drv", SRC, DST, N);
    acc.mem_socket.bind(ram.socket_acc);   // acelerador -> RAM (DMA)
    drv.sock.bind(acc.cfg_socket);         // driver -> registros de control
    drv.sock_ram.bind(ram.socket_cpu);     // driver -> RAM (sin uso; satisface el binding de SystemC)
    ram.load_from_file("in.rgb", SRC);     // backdoor: precargar la imagen (setup del test)

    sc_start();

    ram.save_to_file("out.gray", DST, N);
    std::vector<uint8_t> got(N);
    { std::ifstream f("out.gray", std::ios::binary); f.read(reinterpret_cast<char*>(got.data()), N); }

    uint32_t fallos = 0;
    for (uint32_t i = 0; i < N; ++i)
        if (got[i] != rgb_to_gray(img[3*i], img[3*i+1], img[3*i+2])) ++fallos;
    std::cout << "SMOKE: " << (fallos == 0 ? "PASA" : "FALLA")
              << "  (" << (N - fallos) << "/" << N << " pixeles bit-exact)\n";
    return fallos == 0 ? 0 : 1;
}
