// =====================================================================
// Wrapper del sistema SystemC para integración mediante DPI.
//
// SystemVerilog utilizará:
//   systemc_create()
//   systemc_service()
//   systemc_is_finished()
//   systemc_passed()
//   systemc_destroy()
//
// Las transferencias de RAM se atienden mediante:
//   dpi_poll_request()
//   dpi_fetch()
//   dpi_store()
//   dpi_complete()
// =====================================================================

#include <systemc.h>
#include <tlm.h>

#include "accelerator.h"
#include "cpu.h"
#include "persistent_storage.h"
#include "ram_rtl_proxy.h"
#include "rgb_to_gray.h"
#include "systemc_dpi_bridge.h"

#include <cstdint>
#include <cstdlib>
#include <exception>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// =====================================================================
// Mapa de memoria
// =====================================================================

namespace {

constexpr std::uint64_t SRC_TEST =
    0x00000000ull;

constexpr std::uint64_t DST_TEST =
    0x02000000ull;

constexpr std::uint64_t SRC_REAL =
    0x00010000ull;

constexpr std::uint64_t DST_REAL =
    0x01000000ull;

constexpr std::uint32_t TEST_WIDTH = 8;
constexpr std::uint32_t TEST_HEIGHT = 8;
constexpr std::uint32_t TEST_PIXELS =
    TEST_WIDTH * TEST_HEIGHT;

constexpr std::uint32_t REAL_WIDTH = 1920;
constexpr std::uint32_t REAL_HEIGHT = 1080;
constexpr std::uint32_t REAL_PIXELS =
    REAL_WIDTH * REAL_HEIGHT;

constexpr std::size_t REAL_RGB_BYTES =
    static_cast<std::size_t>(REAL_PIXELS) * 3u;

constexpr std::size_t REAL_GRAY_BYTES =
    static_cast<std::size_t>(REAL_PIXELS);

constexpr std::uint64_t RAM_BYTES =
    64ull * 1024ull * 1024ull;

const sc_core::sc_time SERVICE_STEP(
    10,
    sc_core::SC_NS
);

// =====================================================================
// Obtiene una ruta desde una variable de entorno.
//
// Si la variable no existe, se utiliza el valor predeterminado.
// =====================================================================

std::string get_environment_path(
    const char* variable,
    const char* default_path
) {
    const char* value = std::getenv(variable);

    if (value == nullptr || value[0] == '\0') {
        return default_path;
    }

    return value;
}

// =====================================================================
// Verifica el tamaño de un archivo.
// =====================================================================

bool check_file_size(
    const std::string& path,
    std::size_t expected_size
) {
    std::ifstream file(
        path,
        std::ios::binary | std::ios::ate
    );

    if (!file.is_open()) {
        std::cerr
            << "ERROR: no se pudo abrir "
            << path
            << "\n";

        return false;
    }

    const std::streampos end_position =
        file.tellg();

    if (end_position < 0) {
        std::cerr
            << "ERROR: no se pudo obtener el tamaño de "
            << path
            << "\n";

        return false;
    }

    const auto actual_size =
        static_cast<std::size_t>(end_position);

    if (actual_size != expected_size) {
        std::cerr
            << "ERROR: tamaño incorrecto para "
            << path
            << "\n"
            << "  Esperado: "
            << expected_size
            << " bytes\n"
            << "  Obtenido: "
            << actual_size
            << " bytes\n";

        return false;
    }

    return true;
}

// =====================================================================
// Escribe un vector como archivo RAW.
// =====================================================================

bool write_raw_file(
    const std::string& path,
    const std::vector<std::uint8_t>& data
) {
    std::ofstream file(
        path,
        std::ios::binary
    );

    if (!file.is_open()) {
        std::cerr
            << "ERROR: no se pudo crear "
            << path
            << "\n";

        return false;
    }

    file.write(
        reinterpret_cast<const char*>(data.data()),
        static_cast<std::streamsize>(data.size())
    );

    if (!file) {
        std::cerr
            << "ERROR: escritura incompleta en "
            << path
            << "\n";

        return false;
    }

    return true;
}

// =====================================================================
// Lee un archivo RAW completo.
// =====================================================================

bool read_raw_file(
    const std::string& path,
    std::vector<std::uint8_t>& data
) {
    std::ifstream file(
        path,
        std::ios::binary
    );

    if (!file.is_open()) {
        std::cerr
            << "ERROR: no se pudo abrir "
            << path
            << "\n";

        return false;
    }

    file.read(
        reinterpret_cast<char*>(data.data()),
        static_cast<std::streamsize>(data.size())
    );

    if (file.gcount() !=
        static_cast<std::streamsize>(data.size())) {

        std::cerr
            << "ERROR: lectura incompleta de "
            << path
            << "\n";

        return false;
    }

    return true;
}

// =====================================================================
// Descripción de un trabajo del acelerador.
// =====================================================================

struct Job {
    std::uint32_t source;
    std::uint32_t destination;
    std::uint32_t pixels;
    std::string name;
};

// =====================================================================
// Sistema SystemC completo.
//
// No contiene una RAM SystemC ni una memoria mock.
// RamRtlProxy publica las solicitudes para el lado SystemVerilog.
// =====================================================================

SC_MODULE(SystemcCosimTop) {
    PersistentStorage* storage = nullptr;
    CPU* cpu = nullptr;
    Accelerator* accelerator = nullptr;
    RamRtlProxy* ram_proxy = nullptr;

    bool finished_ = false;
    bool passed_ = false;

    std::string input_rgb_path;
    std::string output_gray_path;

    SC_CTOR(SystemcCosimTop) {
        input_rgb_path = get_environment_path(
            "SYSTEMC_INPUT_RGB",
            "sapo_perro.rgb"
        );

        output_gray_path = get_environment_path(
            "SYSTEMC_OUTPUT_GRAY",
            "sapo_perro_gray.raw"
        );

        storage = new PersistentStorage(
            "storage"
        );

        cpu = new CPU(
            "cpu",
            storage
        );

        accelerator = new Accelerator(
            "accelerator"
        );

        ram_proxy = new RamRtlProxy(
            "ram_rtl_proxy"
        );

        // CPU accede a la RAM mediante el proxy.
        cpu->socket_ram.bind(
            ram_proxy->socket_cpu
        );

        // CPU configura los registros del acelerador.
        cpu->socket_acc.bind(
            accelerator->cfg_socket
        );

        // El acelerador accede a la RAM mediante el proxy.
        accelerator->mem_socket.bind(
            ram_proxy->socket_acc
        );

        SC_THREAD(run_end_to_end);
    }

    ~SystemcCosimTop() override {
        delete cpu;
        delete accelerator;
        delete ram_proxy;
        delete storage;
    }

    bool is_finished() const {
        return finished_;
    }

    bool passed() const {
        return passed_;
    }

    RamRtlProxy* proxy() const {
        return ram_proxy;
    }

    void finish(bool success) {
        passed_ = success;
        finished_ = true;

        std::cout
            << "\n========================================\n"
            << "RESULTADO SYSTEMC COSIM: "
            << (success ? "PASS" : "FAIL")
            << "\n"
            << "========================================\n";

        sc_core::sc_stop();
    }

    bool process_job(const Job& job) {
        std::cout
            << "CPU: procesando job '"
            << job.name
            << "'"
            << " src=0x"
            << std::hex
            << job.source
            << " dst=0x"
            << job.destination
            << std::dec
            << " píxeles="
            << job.pixels
            << "\n";

        if (!cpu->run_accelerator_job(
                ACC_BASE,
                job.source,
                job.destination,
                job.pixels)) {

            std::cerr
                << "ERROR: no se pudo iniciar el trabajo "
                << job.name
                << "\n";

            return false;
        }

        wait(10, sc_core::SC_NS);

        if (!cpu->wait_for_accelerator_done(
                ACC_BASE,
                500000)) {

            std::cerr
                << "ERROR: timeout esperando el trabajo "
                << job.name
                << "\n";

            return false;
        }

        std::cout
            << "CPU: trabajo '"
            << job.name
            << "' completado\n";

        return true;
    }

    bool run_synthetic_test() {
        std::vector<std::uint8_t> rgb(
            static_cast<std::size_t>(TEST_PIXELS) * 3u,
            0
        );

        auto set_pixel =
            [&](std::uint32_t index,
                std::uint8_t red,
                std::uint8_t green,
                std::uint8_t blue) {

                rgb[3u * index] = red;
                rgb[3u * index + 1u] = green;
                rgb[3u * index + 2u] = blue;
            };

        set_pixel(0, 0, 0, 0);
        set_pixel(1, 255, 255, 255);
        set_pixel(2, 255, 0, 0);
        set_pixel(3, 0, 255, 0);
        set_pixel(4, 0, 0, 255);

        for (std::uint32_t index = 5;
             index < TEST_PIXELS;
             ++index) {

            set_pixel(
                index,
                static_cast<std::uint8_t>(
                    index % 256u
                ),
                static_cast<std::uint8_t>(
                    (2u * index) % 256u
                ),
                static_cast<std::uint8_t>(
                    (3u * index) % 256u
                )
            );
        }

        if (!write_raw_file(
                "input.rgb",
                rgb)) {

            return false;
        }

        if (!cpu->load_image_to_ram(
                "input.rgb",
                SRC_TEST)) {

            std::cerr
                << "ERROR: no se pudo cargar input.rgb\n";

            return false;
        }

        if (!process_job(Job{
                static_cast<std::uint32_t>(SRC_TEST),
                static_cast<std::uint32_t>(DST_TEST),
                TEST_PIXELS,
                "sintetica"
            })) {

            return false;
        }

        wait(100, sc_core::SC_NS);

        if (!cpu->save_image_from_ram(
                "output.gray",
                DST_TEST,
                TEST_PIXELS)) {

            std::cerr
                << "ERROR: no se pudo guardar output.gray\n";

            return false;
        }

        std::vector<std::uint8_t> gray(
            TEST_PIXELS,
            0
        );

        if (!read_raw_file(
                "output.gray",
                gray)) {

            return false;
        }

        std::uint32_t failures = 0;

        for (std::uint32_t index = 0;
             index < TEST_PIXELS;
             ++index) {

            const std::uint8_t expected =
                rgb_to_gray(
                    rgb[3u * index],
                    rgb[3u * index + 1u],
                    rgb[3u * index + 2u]
                );

            if (gray[index] != expected) {
                ++failures;

                if (failures <= 3) {
                    std::cerr
                        << "ERROR píxel "
                        << index
                        << ": esperado "
                        << static_cast<int>(expected)
                        << ", obtenido "
                        << static_cast<int>(gray[index])
                        << "\n";
                }
            }
        }

        const bool success =
            failures == 0;

        std::cout
            << "Prueba sintética: "
            << (success ? "PASS" : "FAIL")
            << " ("
            << (TEST_PIXELS - failures)
            << "/"
            << TEST_PIXELS
            << " píxeles correctos)\n";

        return success;
    }

    bool run_real_image() {
        if (!check_file_size(
                input_rgb_path,
                REAL_RGB_BYTES)) {

            return false;
        }

        if (!cpu->load_image_to_ram(
                input_rgb_path,
                SRC_REAL)) {

            std::cerr
                << "ERROR: no se pudo cargar "
                << input_rgb_path
                << "\n";

            return false;
        }

        if (!process_job(Job{
                static_cast<std::uint32_t>(SRC_REAL),
                static_cast<std::uint32_t>(DST_REAL),
                REAL_PIXELS,
                "sapo_perro"
            })) {

            return false;
        }

        wait(100, sc_core::SC_NS);

        if (!cpu->save_image_from_ram(
                output_gray_path,
                DST_REAL,
                REAL_PIXELS)) {

            std::cerr
                << "ERROR: no se pudo guardar "
                << output_gray_path
                << "\n";

            return false;
        }

        if (!check_file_size(
                output_gray_path,
                REAL_GRAY_BYTES)) {

            return false;
        }

        std::cout
            << "Imagen 1080p procesada correctamente\n"
            << "Entrada: "
            << input_rgb_path
            << "\n"
            << "Salida: "
            << output_gray_path
            << "\n"
            << "Bytes de salida: "
            << REAL_GRAY_BYTES
            << "\n";

        return true;
    }

    void run_end_to_end() {
        wait(1, sc_core::SC_NS);

        std::cout
            << "\n========================================\n"
            << " Sistema SystemC + RAM RTL mediante DPI\n"
            << "========================================\n"
            << "RAM declarada: "
            << RAM_BYTES
            << " bytes\n"
            << "Entrada 1080p: "
            << input_rgb_path
            << "\n"
            << "Salida 1080p: "
            << output_gray_path
            << "\n\n";

        if (!run_synthetic_test()) {
            std::cerr
                << "ERROR: se cancela la prueba 1080p porque "
                << "falló la prueba sintética\n";

            finish(false);
            return;
        }

        if (!run_real_image()) {
            finish(false);
            return;
        }

        finish(true);
    }
};

// =====================================================================
// Estado global del wrapper.
// =====================================================================

SystemcCosimTop* g_system = nullptr;
bool g_wrapper_error = false;

}  // namespace

// =====================================================================
// Crea el sistema SystemC.
//
// Retorno:
//   1 = creado correctamente.
//   0 = error.
// =====================================================================

extern "C" int systemc_create() {
    if (g_system != nullptr) {
        std::cout
            << "systemc_create: el sistema ya existe\n";

        return 1;
    }

    try {
        g_wrapper_error = false;

        g_system = new SystemcCosimTop(
            "systemc_cosim_top"
        );

        systemc_dpi_bind_proxy(
            g_system->proxy()
        );

        // Inicializa la elaboración y los procesos de SystemC,
        // pero no avanza el tiempo.
        sc_core::sc_start(
            sc_core::SC_ZERO_TIME
        );

        std::cout
            << "systemc_create: sistema creado correctamente\n";

        return 1;
    }
    catch (const std::exception& error) {
        std::cerr
            << "systemc_create ERROR: "
            << error.what()
            << "\n";
    }
    catch (...) {
        std::cerr
            << "systemc_create ERROR: excepción desconocida\n";
    }

    systemc_dpi_unbind_proxy();

    delete g_system;
    g_system = nullptr;
    g_wrapper_error = true;

    return 0;
}

// =====================================================================
// Avanza el kernel SystemC 10 ns.
//
// Debe ser llamada periódicamente desde SystemVerilog.
//
// Retorno:
//   1 = llamada procesada.
//   0 = error o sistema no creado.
// =====================================================================

extern "C" int systemc_service() {
    if (g_system == nullptr) {
        std::cerr
            << "systemc_service: sistema no creado\n";

        return 0;
    }

    if (g_wrapper_error) {
        return 0;
    }

    if (g_system->is_finished()) {
        return 1;
    }

    try {
        sc_core::sc_start(
            SERVICE_STEP
        );

        return 1;
    }
    catch (const std::exception& error) {
        std::cerr
            << "systemc_service ERROR: "
            << error.what()
            << "\n";
    }
    catch (...) {
        std::cerr
            << "systemc_service ERROR: excepción desconocida\n";
    }

    g_wrapper_error = true;

    return 0;
}

// =====================================================================
// Consulta si la ejecución SystemC terminó.
// =====================================================================

extern "C" int systemc_is_finished() {
    if (g_system == nullptr) {
        return 0;
    }

    return
        (g_wrapper_error || g_system->is_finished())
        ? 1
        : 0;
}

// =====================================================================
// Consulta el resultado final.
//
// Retorno:
//   1 = PASS.
//   0 = FAIL o ejecución todavía incompleta.
// =====================================================================

extern "C" int systemc_passed() {
    if (g_system == nullptr ||
        g_wrapper_error ||
        !g_system->is_finished()) {

        return 0;
    }

    return g_system->passed() ? 1 : 0;
}

// =====================================================================
// Libera el sistema.
//
// Debe llamarse solamente después de systemc_is_finished().
// =====================================================================

extern "C" void systemc_destroy() {
    if (g_system == nullptr) {
        return;
    }

    systemc_dpi_unbind_proxy();

    delete g_system;
    g_system = nullptr;
    g_wrapper_error = false;

    std::cout
        << "systemc_destroy: sistema liberado\n";
}