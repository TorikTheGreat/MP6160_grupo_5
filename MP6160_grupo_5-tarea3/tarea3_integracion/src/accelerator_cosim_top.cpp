#include <systemc>

#include "../include/test_platform.h"
#include "../include/tlm_axi_adapter.h"
#include "../../tarea3_vp/vp_accel/accelerator.h"

class AcceleratorCosimTop : public sc_core::sc_module
{
public:
    explicit AcceleratorCosimTop(
        sc_core::sc_module_name name
    )
        : sc_core::sc_module(name),
          adapter(
              "adapter",
              "tb_accelerator_axi_cosim.dut"
          ),
          test(
              "test",
              adapter
          ),
          accelerator(
              "accelerator",
              64
          )
    {
        test.cfg_socket.bind(
            accelerator.cfg_socket
        );

        accelerator.mem_socket.bind(
            adapter.target_socket
        );
    }

private:
    TlmAxiAdapter adapter;
    TestPlatform test;
    Accelerator accelerator;
};