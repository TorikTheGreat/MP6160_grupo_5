#ifndef ACCELERATOR_H
#define ACCELERATOR_H

#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <vector>
#include <cstring>
#include <cstdint>
#include "rgb_to_gray.h"

// Registros del acelerador en 0x4000_0000 (mapa de memoria del grupo). La RAM va en 0x0.
static constexpr uint64_t ACC_BASE = 0x40000000ull;

// Acelerador RGB -> escala de grises.
//  - TARGET (cfg_socket): el CPU escribe/lee sus registros de control.
//  - INITIATOR (mem_socket): lee la imagen RGB de la RAM y escribe el gris.
struct Accelerator : sc_module {
    tlm_utils::simple_target_socket<Accelerator>    cfg_socket;  // config (target)
    tlm_utils::simple_initiator_socket<Accelerator> mem_socket;  // RAM    (initiator)

    // Registros (mapa del grupo): CONTROL=0x00, ADDR_INPUT=0x04, ADDR_OUTPUT=0x08, NUM_PIXELS=0x0C
    uint32_t reg_src = 0, reg_dst = 0, reg_num = 0;
    bool      done   = false;
    sc_event  start_event;

    SC_CTOR(Accelerator) : cfg_socket("cfg"), mem_socket("mem") {
        cfg_socket.register_b_transport(this, &Accelerator::cfg_b_transport);
        SC_THREAD(do_process);
    }

    // ---------- Cara TARGET: el CPU escribe/lee registros ----------
    void cfg_b_transport(tlm::tlm_generic_payload& trans, sc_time& delay) {
        auto     cmd = trans.get_command();
        uint64_t off = trans.get_address() - ACC_BASE;   // address del mapa de sistema -> offset
        uint8_t* ptr = trans.get_data_ptr();

        if (trans.get_byte_enable_ptr() != nullptr) {
            trans.set_response_status(tlm::TLM_BYTE_ENABLE_ERROR_RESPONSE); return;
        }
        if (trans.get_data_length() != 4) {
            trans.set_response_status(tlm::TLM_BURST_ERROR_RESPONSE); return;
        }

        if (cmd == tlm::TLM_WRITE_COMMAND) {
            uint32_t val; std::memcpy(&val, ptr, 4);
            switch (off) {
                case 0x00: if (val & 1u) { done = false; start_event.notify(SC_ZERO_TIME); }
                           break;                          // CONTROL: bit0 = START
                case 0x04: reg_src = val; break;           // ADDR_INPUT
                case 0x08: reg_dst = val; break;           // ADDR_OUTPUT
                case 0x0C: reg_num = val; break;           // NUM_PIXELS
                default: trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE); return;
            }
        } else if (cmd == tlm::TLM_READ_COMMAND) {
            uint32_t out = 0;
            switch (off) {
                case 0x00: out = done ? 1u : 0u; break;    // CONTROL: bit0 = DONE
                case 0x04: out = reg_src; break;
                case 0x08: out = reg_dst; break;
                case 0x0C: out = reg_num; break;
                default: trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE); return;
            }
            std::memcpy(ptr, &out, 4);
        } else {
            trans.set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE); return;
        }
        delay += sc_time(5, SC_NS);
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
    }

    // ---------- Cara INITIATOR: acceso a la RAM ----------
    bool ram_access(tlm::tlm_command cmd, uint64_t addr, uint8_t* buf, unsigned len,
                    sc_time& delay) {
        tlm::tlm_generic_payload trans;
        trans.set_command(cmd);
        trans.set_address(addr);
        trans.set_data_ptr(buf);
        trans.set_data_length(len);
        trans.set_streaming_width(len);
        trans.set_byte_enable_ptr(nullptr);
        trans.set_dmi_allowed(false);
        trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        mem_socket->b_transport(trans, delay);

        if (trans.is_response_error()) {
            SC_REPORT_ERROR(
                "ACCELERATOR",
                trans.get_response_string().c_str()
            );
            return false;
}

return true;
    }

    // ---------- Cómputo: esperar START -> leer -> convertir -> escribir -> DONE ----------
    void do_process() {
        while (true) {
            wait(start_event);
            if (reg_num == 0) { done = true; continue; }

            std::vector<uint8_t> in (static_cast<size_t>(reg_num) * 3); // RGB interleaved, 8bpp
            std::vector<uint8_t> out(reg_num);                          // gris, 1 byte/px

            sc_time delay = SC_ZERO_TIME;
            if (!ram_access(
                    tlm::TLM_READ_COMMAND,
                    reg_src,
                    in.data(),
                    static_cast<unsigned>(in.size()),
                    delay)) {

                done = false;
                sc_stop();
                continue;
            }

            for (uint32_t i = 0; i < reg_num; ++i)
                out[i] = rgb_to_gray(in[3*i], in[3*i+1], in[3*i+2]);
            delay += sc_time(reg_num, SC_NS);   // retardo aprox. del cómputo

            if (!ram_access(
                tlm::TLM_WRITE_COMMAND,
                reg_dst,
                out.data(),
                static_cast<unsigned>(out.size()),
                delay)) {

            done = false;
            sc_stop();
            continue;
}

            wait(delay);        // consumir el tiempo (modelo loosely-timed)
            done = true;        // el CPU lo lee en CONTROL bit0
        }
    }
};

#endif // ACCELERATOR_H