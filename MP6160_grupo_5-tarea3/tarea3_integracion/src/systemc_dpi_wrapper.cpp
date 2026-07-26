#include <iostream>
#include <memory>

#include "../include/test_platform.h"
#include "../include/tlm_axi_adapter.h"

namespace {
std::unique_ptr<TlmAxiAdapter> g_adapter;
std::unique_ptr<TestPlatform> g_test;
bool g_initialized = false;
}

extern "C" int systemc_create()
{
    if (g_initialized) {
        return 1;
    }

    try {
        g_adapter.reset(new TlmAxiAdapter(
            "tb_systemc_dpi_step_launcher.dut"
        ));
        g_test.reset(new TestPlatform(*g_adapter));
        g_initialized = true;

        std::cout << "[SYSTEMC DPI] Controlador de imagen creado."
                  << std::endl;
        return 0;
    }
    catch (const std::exception& error) {
        g_test.reset();
        g_adapter.reset();
        g_initialized = false;
        std::cerr << "[SYSTEMC DPI] ERROR al crear el controlador: "
                  << error.what() << std::endl;
        return 1;
    }
    catch (...) {
        g_test.reset();
        g_adapter.reset();
        g_initialized = false;
        std::cerr << "[SYSTEMC DPI] ERROR desconocido al crear controlador."
                  << std::endl;
        return 1;
    }
}

extern "C" int systemc_service()
{
    if (!g_initialized || !g_test) {
        return 1;
    }

    try {
        g_test->service();
        return 0;
    }
    catch (const std::exception& error) {
        std::cerr << "[SYSTEMC DPI] ERROR durante service: "
                  << error.what() << std::endl;
        return 1;
    }
    catch (...) {
        std::cerr << "[SYSTEMC DPI] ERROR desconocido durante service."
                  << std::endl;
        return 1;
    }
}

extern "C" int systemc_is_finished()
{
    if (!g_initialized || !g_test) {
        return 1;
    }
    return g_test->finished() ? 1 : 0;
}

extern "C" int systemc_passed()
{
    if (!g_initialized || !g_test) {
        return 0;
    }
    return g_test->passed() ? 1 : 0;
}

extern "C" void systemc_destroy()
{
    g_test.reset();
    g_adapter.reset();
    g_initialized = false;
    std::cout << "[SYSTEMC DPI] Controlador de imagen destruido."
              << std::endl;
}
