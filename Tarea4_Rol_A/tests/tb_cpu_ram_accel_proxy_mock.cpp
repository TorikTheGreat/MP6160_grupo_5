// =====================================================================
// Testbench del acelerador RGB -> escala de grises
//
// Conecta:
// PersistentStorage -> CPU -> RamRtlProxy -> MockAxiMemory
//                             |
//                             +-> Accelerator
//
// Ejecuta:
// 1. Prueba sintética de 8x8.
// 2. Procesamiento de imagen RAW RGB 1920x1080.
// =====================================================================

#include <systemc.h>
#include <tlm.h>

#include "accelerator.h"
#include "cpu.h"
#include "mock_axi_memory.h"
#include "persistent_storage.h"
#include "ram_rtl_proxy.h"
#include "rgb_to_gray.h"

#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// =====================================================================
// Mapa de memoria
// =====================================================================


static constexpr std::uint64_t SRC_TEST =
    0x00000000ull;

static constexpr std::uint64_t DST_TEST =
    0x02000000ull;

static constexpr std::uint64_t SRC_REAL =
    0x00010000ull;

static constexpr std::uint64_t DST_REAL =
    0x01000000ull;

// =====================================================================
// Estructura que describe un trabajo del acelerador
// =====================================================================

struct Job {
    std::uint32_t src;
    std::uint32_t dst;
    std::uint32_t num;
    std::string name;
};

// =====================================================================
// Escribe un vector como archivo binario RAW
// =====================================================================

static bool write_raw(
    const std::string& path,
    const std::vector<std::uint8_t>& data
) {
    std::ofstream file(path, std::ios::binary);

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
            << "ERROR: no se pudo escribir completamente "
            << path
            << "\n";

        return false;
    }

    return true;
}

// =====================================================================
// Testbench
// =====================================================================

SC_MODULE(Testbench) {
    CPU* cpu = nullptr;
    RamRtlProxy* ram = nullptr;
    MockAxiMemory* mock_memory = nullptr;
    Accelerator* acc = nullptr;
    PersistentStorage* storage = nullptr;

    SC_CTOR(Testbench) {
        // -------------------------------------------------------------
        // Crear los módulos
        // -------------------------------------------------------------

        ram = new RamRtlProxy(
            "ram_rtl_proxy"
        );

        mock_memory = new MockAxiMemory(
            "mock_axi_memory",
            *ram,
            64ull * 1024ull * 1024ull
        );

        storage = new PersistentStorage(
            "storage"
        );

        cpu = new CPU(
            "cpu",
            storage
        );

        acc = new Accelerator(
            "acc"
        );

        // -------------------------------------------------------------
        // Conectar los sockets
        // -------------------------------------------------------------

        cpu->socket_ram.bind(
            ram->socket_cpu
        );

        cpu->socket_acc.bind(
            acc->cfg_socket
        );

        acc->mem_socket.bind(
            ram->socket_acc
        );

        // -------------------------------------------------------------
        // Registrar el proceso principal
        // -------------------------------------------------------------

        SC_THREAD(run_test);
    }

    ~Testbench() {
        // Los módulos que utilizan el proxy se eliminan antes que este.
        delete cpu;
        delete acc;
        delete mock_memory;
        delete ram;
        delete storage;
    }

    // =================================================================
    // Configura el acelerador y espera su finalización
    // =================================================================

    bool process_job(const Job& job) {
        std::cout
            << "CPU: procesando job '"
            << job.name
            << "' (src=0x"
            << std::hex
            << job.src
            << " dst=0x"
            << job.dst
            << std::dec
            << " num="
            << job.num
            << ")\n";

        if (!cpu->run_accelerator_job(
                ACC_BASE,
                job.src,
                job.dst,
                job.num)) {

            std::cout
                << "ERROR: no se pudo iniciar "
                << "el acelerador\n";

            return false;
        }

        wait(10, SC_NS);

        if (!cpu->wait_for_accelerator_done(
                ACC_BASE,
                500000)) {

            std::cout
                << "ERROR: el acelerador no respondió "
                << "a tiempo\n";

            return false;
        }

        std::cout
            << "CPU: job '"
            << job.name
            << "' completado\n";

        return true;
    }

    // =================================================================
    // Proceso principal del testbench
    // =================================================================

    void run_test() {
        wait(1, SC_NS);

        std::cout
            << "\n========================================\n"
            << " SystemC Accelerator Proxy Testbench\n"
            << "========================================\n\n";

        // =============================================================
        // Job 1: imagen sintética de 8x8
        // =============================================================

        const std::uint32_t W1 = 8;
        const std::uint32_t H1 = 8;
        const std::uint32_t N1 = W1 * H1;

        std::vector<std::uint8_t> synthetic_rgb(
            static_cast<std::size_t>(N1) * 3u
        );

        auto set_pixel =
            [&](std::uint32_t index,
                std::uint8_t red,
                std::uint8_t green,
                std::uint8_t blue) {

                synthetic_rgb[3u * index] = red;
                synthetic_rgb[3u * index + 1u] = green;
                synthetic_rgb[3u * index + 2u] = blue;
            };

        // Primeros cinco píxeles con colores conocidos.
        set_pixel(0, 0, 0, 0);
        set_pixel(1, 255, 255, 255);
        set_pixel(2, 255, 0, 0);
        set_pixel(3, 0, 255, 0);
        set_pixel(4, 0, 0, 255);

        for (std::uint32_t index = 5;
             index < N1;
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

        if (!write_raw(
                "input.rgb",
                synthetic_rgb)) {

            sc_stop();
            return;
        }

        if (!cpu->load_image_to_ram(
                "input.rgb",
                SRC_TEST)) {

            std::cout
                << "ERROR: no se pudo cargar input.rgb\n";

            sc_stop();
            return;
        }

        std::cout
            << "--- Job 1: Imagen sintética 8x8 ---\n";

        if (!process_job(Job{
                static_cast<std::uint32_t>(SRC_TEST),
                static_cast<std::uint32_t>(DST_TEST),
                N1,
                "sintetica"
            })) {

            std::cout
                << "ERROR: falló el trabajo sintético\n";

            sc_stop();
            return;
        }

        wait(100, SC_NS);

        if (!cpu->save_image_from_ram(
                "output.gray",
                DST_TEST,
                N1)) {

            std::cout
                << "ERROR: no se pudo guardar output.gray\n";

            sc_stop();
            return;
        }

        std::vector<std::uint8_t> obtained_gray(
            N1,
            0
        );

        {
            std::ifstream file(
                "output.gray",
                std::ios::binary
            );

            if (!file.is_open()) {
                std::cout
                    << "ERROR: no se pudo abrir output.gray\n";

                sc_stop();
                return;
            }

            file.read(
                reinterpret_cast<char*>(
                    obtained_gray.data()
                ),
                static_cast<std::streamsize>(
                    obtained_gray.size()
                )
            );

            if (file.gcount() !=
                static_cast<std::streamsize>(
                    obtained_gray.size()
                )) {

                std::cout
                    << "ERROR: lectura incompleta de "
                    << "output.gray\n";

                sc_stop();
                return;
            }
        }

        // =============================================================
        // Verificación de la imagen sintética
        // =============================================================

        std::cout
            << "\n--- Verificación de resultado ---\n";

        const char* pixel_names[5] = {
            "negro ",
            "blanco",
            "rojo  ",
            "verde ",
            "azul  "
        };

        for (std::uint32_t index = 0;
             index < N1 && index < 5;
             ++index) {

            std::cout
                << "px"
                << index
                << " "
                << pixel_names[index]
                << " RGB("
                << static_cast<int>(
                    synthetic_rgb[3u * index]
                )
                << ","
                << static_cast<int>(
                    synthetic_rgb[3u * index + 1u]
                )
                << ","
                << static_cast<int>(
                    synthetic_rgb[3u * index + 2u]
                )
                << ") -> gris "
                << static_cast<int>(
                    obtained_gray[index]
                )
                << "\n";
        }

        bool synthetic_ok = true;
        std::uint32_t failures = 0;

        for (std::uint32_t index = 0;
             index < N1;
             ++index) {

            const std::uint8_t expected =
                rgb_to_gray(
                    synthetic_rgb[3u * index],
                    synthetic_rgb[3u * index + 1u],
                    synthetic_rgb[3u * index + 2u]
                );

            if (obtained_gray[index] != expected) {
                synthetic_ok = false;
                ++failures;

                if (failures <= 3) {
                    std::cout
                        << "ERROR px"
                        << index
                        << ": esperado "
                        << static_cast<int>(expected)
                        << ", obtenido "
                        << static_cast<int>(
                            obtained_gray[index]
                        )
                        << "\n";
                }
            }
        }

        std::cout
            << "\n========================================\n"
            << "RESULTADO: "
            << (synthetic_ok ? "PASA" : "FALLA")
            << " ("
            << (N1 - failures)
            << "/"
            << N1
            << " píxeles correctos)\n"
            << "========================================\n\n";

        if (!synthetic_ok) {
            std::cout
                << "ERROR: se cancela la imagen real porque "
                << "la prueba sintética falló\n";

            sc_stop();
            return;
        }

        // =============================================================
        // Job 2: imagen real de 1920x1080
        // =============================================================

        const std::uint32_t W2 = 1920;
        const std::uint32_t H2 = 1080;
        const std::uint32_t N2 = W2 * H2;

        std::cout
            << "--- Job 2: Imagen real sapo perro "
            << W2
            << "x"
            << H2
            << " ---\n";

        if (!cpu->load_image_to_ram(
                "sapo_perro.rgb",
                SRC_REAL)) {

            std::cout
                << "ERROR: no se pudo cargar "
                << "sapo_perro.rgb\n";

            sc_stop();
            return;
        }

        if (!process_job(Job{
                static_cast<std::uint32_t>(SRC_REAL),
                static_cast<std::uint32_t>(DST_REAL),
                N2,
                "sapo_perro"
            })) {

            std::cout
                << "ERROR: no se guardará la imagen porque "
                << "el acelerador no terminó\n";

            sc_stop();
            return;
        }

        wait(100, SC_NS);

        if (!cpu->save_image_from_ram(
                "sapo_perro_gray.raw",
                DST_REAL,
                N2)) {

            std::cout
                << "ERROR: no se pudo guardar "
                << "sapo_perro_gray.raw\n";

            sc_stop();
            return;
        }

        std::cout
            << "Imagen sapo perro procesada correctamente\n"
            << "Salida: sapo_perro_gray.raw\n"
            << "Solicitudes atendidas por la memoria mock: "
            << mock_memory->serviced_requests
            << "\n";

        sc_stop();
    }
};

// =====================================================================
// Punto de entrada de SystemC
// =====================================================================

int sc_main(int, char**) {
    Testbench testbench("testbench");

    sc_start();

    return 0;
}