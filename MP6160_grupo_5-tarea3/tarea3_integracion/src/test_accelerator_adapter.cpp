#include <iostream>
#include <systemc>

#include "../include/test_platform.h"
#include "../include/tlm_axi_adapter.h"

#include "../../tarea3_vp/vp_accel/accelerator.h"

int sc_main(
    int argc,
    char* argv[]
)
{
    TlmAxiAdapter adapter(
        "adapter",
        "tb_accelerator_axi_cosim.dut"
    );

    TestPlatform test(
        "test",
        adapter
    );

    Accelerator accelerator(
        "accelerator",
        64
    );

    // TestPlatform configura los registros del acelerador.
    test.cfg_socket.bind(
        accelerator.cfg_socket
    );

    // El DMA del acelerador accede al adaptador TLM.
    accelerator.mem_socket.bind(
        adapter.target_socket
    );

    std::cout
        << "[SYSTEMC] Iniciando simulacion..."
        << std::endl;

    sc_core::sc_start();

    std::cout
        << "[SYSTEMC] Simulacion terminada."
        << std::endl;

    return 0;
}