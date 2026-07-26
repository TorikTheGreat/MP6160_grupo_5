#include <array>
#include <cstdint>
#include <iomanip>
#include <iostream>

#include "svdpi.h"

#include "../include/tlm_axi_adapter.h"

extern "C" void run_tlm_axi_dpi_test(int* resultado)
{
    if (resultado == nullptr) {
        return;
    }

    *resultado = 1;

    std::cout << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << " PRUEBA TLM ADAPTER -> DPI -> AXI RAM" << std::endl;
    std::cout << "========================================" << std::endl;

    /*
     * El scope coincide con la instancia axi_dpi_server
     * del lanzador SystemVerilog.
     */
    TlmAxiAdapter adapter(
        "adapter",
        "tb_tlm_axi_dpi_launcher.dut"
    );

    const std::uint32_t address = 0x00000100;

    std::array<unsigned char, 8> entrada = {
        0x11, 0x22, 0x33, 0x44,
        0x55, 0x66, 0x77, 0x88
    };

    std::array<unsigned char, 8> salida = {};

    try {
        adapter.clear_memory();

        adapter.load_memory(
            address,
            entrada.data(),
            entrada.size()
        );

        adapter.read_memory(
            address,
            salida.data(),
            salida.size()
        );
    }
    catch (const std::exception& error) {
        std::cerr
            << "[C++] ERROR: "
            << error.what()
            << std::endl;

        return;
    }

    std::cout << "[C++] Datos leidos:";

    for (unsigned char value : salida) {
        std::cout
            << " "
            << std::hex
            << std::setw(2)
            << std::setfill('0')
            << static_cast<unsigned int>(value);
    }

    std::cout << std::dec << std::endl;

    if (entrada == salida) {
        std::cout
            << "[C++] TLM_AXI_DPI_CPP_PASS"
            << std::endl;

        *resultado = 0;
    }
    else {
        std::cerr
            << "[C++] TLM_AXI_DPI_CPP_FAIL"
            << std::endl;
    }
}