// sc_rgb2gray.hh — Periférico del prototipo virtual (P4).
// Compone el acelerador SystemC de la Tarea 2 y expone sus DOS sockets como puertos de gem5,
// para que el config Python los conecte a los puentes (topología #2: SystemC dentro de gem5).
// Molde: gem5/util/systemc/systemc_within_gem5/systemc_gem5_tlm/sc_tlm_target.hh
#ifndef __TAREA3_VP_SC_RGB2GRAY_HH__
#define __TAREA3_VP_SC_RGB2GRAY_HH__

#include <string>

#include "accelerator.h"               // Accelerator: cfg_socket (target) + mem_socket (initiator), BT.709
#include "systemc/tlm_port_wrapper.hh" // sc_gem5::TlmTargetWrapper / TlmInitiatorWrapper (el adaptador)

#include "systemc/ext/systemc"
#include "systemc/ext/tlm"

// Nuestro periférico = un sc_module que CONTIENE el Accelerator (composición, sin tocar su lógica)
// y envuelve sus sockets. Cada wrapper convierte un socket TLM en un puerto conectable de gem5.
class RgbToGrayAccel : public sc_core::sc_module
{
  public:
    Accelerator accel;                              // el acelerador de la T2 (mismo modelo)

    // cfg_socket es TARGET (recibe el control por MMIO)  -> puerto gem5 "cfg"
    // Ancho 32: debe coincidir con el del socket del acelerador (simple_target_socket = 32 por default).
    sc_gem5::TlmTargetWrapper<32>    cfgWrapper;
    // mem_socket es INITIATOR (hace DMA a la RAM)        -> puerto gem5 "mem"
    sc_gem5::TlmInitiatorWrapper<32> memWrapper;

    RgbToGrayAccel(sc_core::sc_module_name name, unsigned dma_chunk = 64) :
        sc_core::sc_module(name),
        accel("accel", dma_chunk),
        cfgWrapper(accel.cfg_socket, std::string(name) + ".cfg", gem5::InvalidPortID),
        memWrapper(accel.mem_socket, std::string(name) + ".mem", gem5::InvalidPortID)
    {}

    // gem5 pide los puertos por nombre al cablear el config Python.
    gem5::Port &gem5_getPort(const std::string &if_name, int idx = -1) override;
};

#endif // __TAREA3_VP_SC_RGB2GRAY_HH__
