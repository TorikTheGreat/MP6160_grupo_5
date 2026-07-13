// cfg_stimulus.hh — Estímulo de control SOLO para pruebas (Hito A). NO es entregable.
// Emula lo que hará el programa en C sobre el ARM64: escribe los registros del acelerador
// (ADDR_INPUT/ADDR_OUTPUT/NUM_PIXELS) y dispara START, todo por b_transport TLM normal
// (igual que el smoke test → sí notifica start_event y arranca do_process). Se conecta a
// accel.cfg como TLM↔TLM (ambos módulos SystemC, sin puente).
#ifndef __TAREA3_HARNESS_CFG_STIMULUS_HH__
#define __TAREA3_HARNESS_CFG_STIMULUS_HH__

#include <string>
#include <cstdint>

#include "systemc/tlm_port_wrapper.hh"   // sc_gem5::TlmInitiatorWrapper
#include "systemc/ext/systemc"
#include "systemc/ext/tlm"
#include "tlm_utils/simple_initiator_socket.h"

// DEBE coincidir con ACC_BASE y el mapa de registros de accelerator.h (entregable):
//   CONTROL=0x00 (bit0 START/DONE), ADDR_INPUT=0x04, ADDR_OUTPUT=0x08, NUM_PIXELS=0x0C
static constexpr uint64_t STIM_ACC_BASE = 0x10030000ull;

class CfgStimulus : public sc_core::sc_module
{
  public:
    tlm_utils::simple_initiator_socket<CfgStimulus> out;   // hacia accel.cfg (target TLM)
    sc_gem5::TlmInitiatorWrapper<32> outWrapper;           // expone `out` como puerto gem5

    uint32_t inputAddr, outputAddr, numPixels;

    CfgStimulus(sc_core::sc_module_name name,
                uint32_t input_addr, uint32_t output_addr, uint32_t num_pixels) :
        sc_core::sc_module(name),
        out("out"),
        outWrapper(out, std::string(name) + ".out", gem5::InvalidPortID),
        inputAddr(input_addr), outputAddr(output_addr), numPixels(num_pixels)
    {
        SC_HAS_PROCESS(CfgStimulus);
        SC_THREAD(run);
    }

    gem5::Port &gem5_getPort(const std::string &if_name, int idx = -1) override;

  private:
    void regWrite(uint32_t off, uint32_t val)
    {
        tlm::tlm_generic_payload t;
        sc_core::sc_time d = sc_core::SC_ZERO_TIME;
        t.set_command(tlm::TLM_WRITE_COMMAND);
        t.set_address(STIM_ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<uint8_t *>(&val));
        t.set_data_length(4);
        t.set_streaming_width(4);
        t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        out->b_transport(t, d);
        sc_assert(t.is_response_ok());
    }

    uint32_t regRead(uint32_t off)
    {
        uint32_t val = 0;
        tlm::tlm_generic_payload t;
        sc_core::sc_time d = sc_core::SC_ZERO_TIME;
        t.set_command(tlm::TLM_READ_COMMAND);
        t.set_address(STIM_ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<uint8_t *>(&val));
        t.set_data_length(4);
        t.set_streaming_width(4);
        t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        out->b_transport(t, d);
        sc_assert(t.is_response_ok());
        return val;
    }

    void run()
    {
        wait(sc_core::SC_ZERO_TIME);             // dejar asentar la elaboración
        regWrite(0x04, inputAddr);               // ADDR_INPUT
        regWrite(0x08, outputAddr);              // ADDR_OUTPUT
        regWrite(0x0C, numPixels);               // NUM_PIXELS
        regWrite(0x00, 1);                       // CONTROL: START (bit0)

        int guard = 0;                           // esperar DONE (acotado)
        while (!(regRead(0x00) & 1u) && guard++ < 1000000)
            wait(10, sc_core::SC_NS);

        SC_REPORT_INFO("CfgStimulus",
                       (regRead(0x00) & 1u) ? "DONE observado" : "TIMEOUT sin DONE");
    }
};

#endif // __TAREA3_HARNESS_CFG_STIMULUS_HH__
