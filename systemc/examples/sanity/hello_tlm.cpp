// hello_tlm.cpp — verificación del entorno: SystemC + TLM 2.0 (LT, b_transport).
// Una CPU (initiator) escribe un dato en una memoria (target) y lo lee de vuelta.
// Si imprime "[OK]", el entorno (SystemC y TLM) está bien instalado.

#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <cstring>
#include <iostream>

struct Memory : sc_module {
    tlm_utils::simple_target_socket<Memory> socket;
    unsigned char mem[16] = {0};

    SC_CTOR(Memory) : socket("socket") {
        socket.register_b_transport(this, &Memory::b_transport);
    }

    void b_transport(tlm::tlm_generic_payload& trans, sc_time& delay) {
        const tlm::tlm_command cmd = trans.get_command();
        const sc_dt::uint64   addr = trans.get_address();
        unsigned char*        ptr  = trans.get_data_ptr();
        const unsigned int    len  = trans.get_data_length();

        if (cmd == tlm::TLM_WRITE_COMMAND)      std::memcpy(&mem[addr], ptr, len);
        else if (cmd == tlm::TLM_READ_COMMAND)  std::memcpy(ptr, &mem[addr], len);

        delay += sc_time(10, SC_NS);
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
    }
};

struct Cpu : sc_module {
    tlm_utils::simple_initiator_socket<Cpu> socket;

    SC_CTOR(Cpu) : socket("socket") { SC_THREAD(run); }

    void run() {
        tlm::tlm_generic_payload trans;
        sc_time delay = SC_ZERO_TIME;
        unsigned int data = 0xDEADBEEF, readback = 0;

        trans.set_command(tlm::TLM_WRITE_COMMAND);
        trans.set_address(0);
        trans.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
        trans.set_data_length(4);
        trans.set_streaming_width(4);
        trans.set_byte_enable_ptr(nullptr);
        trans.set_dmi_allowed(false);
        trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        socket->b_transport(trans, delay);

        trans.set_command(tlm::TLM_READ_COMMAND);
        trans.set_data_ptr(reinterpret_cast<unsigned char*>(&readback));
        trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        socket->b_transport(trans, delay);

        std::cout << std::hex
                  << "TLM round-trip: escrito 0x" << data
                  << ", leido 0x" << readback
                  << (data == readback ? "   [OK]" : "   [FAIL]") << std::dec << "\n"
                  << "Tiempo de simulacion tras 2 transacciones: " << delay << std::endl;
        sc_stop();
    }
};

int sc_main(int, char*[]) {
    Cpu cpu("cpu");
    Memory mem("mem");
    cpu.socket.bind(mem.socket);
    sc_start();
    return 0;
}
