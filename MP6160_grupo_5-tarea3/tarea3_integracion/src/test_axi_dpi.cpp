#include <iomanip>
#include <iostream>

#include "svdpi.h"

// Tareas exportadas desde axi_dpi_server.sv.
// Las tareas DPI exportadas devuelven un código interno.
// Los argumentos output se reciben mediante punteros.
extern "C" {

int sv_axi_write_word(
    unsigned int addr,
    unsigned int data,
    int* status
);

int sv_axi_read_word(
    unsigned int addr,
    unsigned int* data,
    int* status
);

}

static bool seleccionar_scope_axi()
{
    // Nombre jerárquico habitual utilizado por XSim.
    svScope scope = svGetScopeFromName(
        "tb_axi_dpi_launcher.dut"
    );

    // Segunda variante, por compatibilidad.
    if (scope == nullptr) {
        scope = svGetScopeFromName(
            "/tb_axi_dpi_launcher/dut"
        );
    }

    if (scope == nullptr) {
        std::cerr
            << "[C++] ERROR: no se encontro el scope "
            << "tb_axi_dpi_launcher.dut"
            << std::endl;

        return false;
    }

    svSetScope(scope);

    std::cout
        << "[C++] Scope AXI seleccionado correctamente."
        << std::endl;

    return true;
}

extern "C" void run_axi_dpi_test(int* resultado)
{
    if (resultado == nullptr) {
        return;
    }

    *resultado = 1;

    std::cout << std::endl;
    std::cout << "======================================" << std::endl;
    std::cout << " C++ -> DPI -> AXI -> RAM" << std::endl;
    std::cout << "======================================" << std::endl;

    if (!seleccionar_scope_axi()) {
        return;
    }

    int status = 0;
    unsigned int dato = 0;

    const int task_write = sv_axi_write_word(
        0x00000100u,
        0xCAFEBABEu,
        &status
    );

    std::cout
        << "[C++] WRITE task_code="
        << task_write
        << " status="
        << status
        << std::endl;

    if (task_write != 0 || status != 0) {
        std::cerr
            << "[C++] ERROR en escritura AXI."
            << std::endl;

        return;
    }

    status = 0;

    const int task_read = sv_axi_read_word(
        0x00000100u,
        &dato,
        &status
    );

    std::cout
        << "[C++] READ task_code="
        << task_read
        << " status="
        << status
        << std::endl;

    std::cout
        << "[C++] dato=0x"
        << std::hex
        << std::setw(8)
        << std::setfill('0')
        << dato
        << std::dec
        << std::endl;

    if (
        task_read == 0 &&
        status == 0 &&
        dato == 0xCAFEBABEu
    ) {
        std::cout
            << "[C++] AXI_DPI_CPP_PASS"
            << std::endl;

        *resultado = 0;
    }
    else {
        std::cerr
            << "[C++] AXI_DPI_CPP_FAIL"
            << std::endl;
    }
}