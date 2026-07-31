// =====================================================================
//  Testbench del acelerador RGB -> escala de grises
//
//  Conecta:  CPU (configura via registros) --> Accelerator --> RAM
//  Procesa trabajos (jobs) en secuencia.
// =====================================================================
#include <systemc.h>
#include <tlm.h>
#include <fstream>
#include <vector>
#include <string>
#include <iostream>

#include "accelerator.h"
#include "ram.h"
#include "cpu.h"
#include "rgb_to_gray.h"

#include "persistent_storage.h"

// Mapa de memoria
// static constexpr uint64_t ACC_BASE = 0x40000000ull;
static constexpr uint64_t SRC_TEST = 0x00000000ull;   // Imagen sintética entrada (RGB)
static constexpr uint64_t DST_TEST = 0x02000000ull;   // Imagen sintética salida (gris)

static constexpr uint64_t SRC_REAL = 0x00010000ull;
static constexpr uint64_t DST_REAL = 0x01000000ull;

// Vuelca bytes crudos a un archivo
static void write_raw(const std::string& path, const std::vector<uint8_t>& data) {
    std::ofstream f(path, std::ios::binary);
    f.write(reinterpret_cast<const char*>(data.data()), data.size());
}

// =====================================================================
//  Testbench
// =====================================================================
struct Job { 
    uint32_t src, dst, num; 
    std::string name; 
};

SC_MODULE(Testbench) {
    CPU* cpu;
    RAM* ram;
    Accelerator* acc;
    PersistentStorage* storage;
    std::vector<Job> jobs;

    SC_CTOR(Testbench) {
    ram = new RAM("ram", 64 * 1024 * 1024);
    storage = new PersistentStorage("storage");
    cpu = new CPU("cpu", storage);
    acc = new Accelerator("acc");

    // Conectar sockets
    cpu->socket_ram.bind(ram->socket_cpu);
    cpu->socket_acc.bind(acc->cfg_socket);
    acc->mem_socket.bind(ram->socket_acc);

    // Registrar proceso
    SC_THREAD(run_test);
     }
    
    ~Testbench() {
        delete cpu;
        delete ram;
        delete acc;
        delete storage;
    }


    uint32_t read_reg(uint64_t off) {
        return cpu->read_accelerator_register(ACC_BASE + off);
    }

    
    // Metodo para procesar una imagen: 
    // configura el acelerador y espera a que termine
bool process_job(const Job& job) {
    std::cout << "CPU: procesando job '" << job.name << "' "
              << "(src=0x" << std::hex << job.src
              << " dst=0x" << job.dst
              << std::dec << " num=" << job.num << ")\n";

    if (!cpu->run_accelerator_job(
            ACC_BASE,
            job.src,
            job.dst,
            job.num)) {

        std::cout << "ERROR: no se pudo iniciar el acelerador\n";
        return false;
    }

    wait(10, SC_NS);

    if (!cpu->wait_for_accelerator_done(ACC_BASE, 500000)) {
        std::cout << "ERROR: El acelerador no respondio a tiempo\n";
        return false;
    }

    std::cout << "CPU: job '" << job.name << "' completado\n";
    return true;
}


void run_test() {
    wait(1, SC_NS);

    std::cout << "\n========================================\n";
    std::cout << "  SystemC Accelerator Testbench\n";
    std::cout << "========================================\n\n";

    // =========================================================
    // Job 1: Imagen sintética 8x8
    // =========================================================
    const uint32_t W1 = 8;
    const uint32_t H1 = 8;
    const uint32_t N1 = W1 * H1;

    std::vector<uint8_t> syn(static_cast<size_t>(N1) * 3);

    auto set_px = [&](uint32_t i, uint8_t r, uint8_t g, uint8_t b) {
        syn[3 * i]     = r;
        syn[3 * i + 1] = g;
        syn[3 * i + 2] = b;
    };

    // Primeros cinco píxeles con colores conocidos
    if (N1 > 0) set_px(0,   0,   0,   0); // negro
    if (N1 > 1) set_px(1, 255, 255, 255); // blanco
    if (N1 > 2) set_px(2, 255,   0,   0); // rojo
    if (N1 > 3) set_px(3,   0, 255,   0); // verde
    if (N1 > 4) set_px(4,   0,   0, 255); // azul

    for (uint32_t i = 5; i < N1; ++i) {
        set_px(
            i,
            static_cast<uint8_t>(i % 256),
            static_cast<uint8_t>((2 * i) % 256),
            static_cast<uint8_t>((3 * i) % 256)
        );
    }

    write_raw("input.rgb", syn);

    if (!cpu->load_image_to_ram("input.rgb", SRC_TEST)) {
        std::cout << "ERROR: no se pudo cargar input.rgb\n";
        sc_stop();
        return;
    }

    std::cout << "--- Job 1: Imagen sintetica 8x8 ---\n";
    if (!process_job(Job{
        static_cast<uint32_t>(SRC_TEST),
        static_cast<uint32_t>(DST_TEST),
        N1,
        "sintetica"
    })) {

    std::cout << "ERROR: fallo el trabajo sintetico\n";
    sc_stop();
    return;
}

wait(100, SC_NS);

    if (!cpu->save_image_from_ram("output.gray", DST_TEST, N1)) {
        std::cout << "ERROR: no se pudo guardar output.gray\n";
        sc_stop();
        return;
    }

    std::vector<uint8_t> got(N1);

    {
        std::ifstream file("output.gray", std::ios::binary);

        if (!file.is_open()) {
            std::cout << "ERROR: no se pudo abrir output.gray\n";
            sc_stop();
            return;
        }

        file.read(
            reinterpret_cast<char*>(got.data()),
            static_cast<std::streamsize>(got.size())
        );

        if (!file) {
            std::cout << "ERROR: no se pudo leer completamente output.gray\n";
            sc_stop();
            return;
        }
    }

    std::cout << "\n--- Verificacion de Resultado ---\n";

    const char* nombres[5] = {
        "negro ",
        "blanco",
        "rojo  ",
        "verde ",
        "azul  "
    };

    for (uint32_t i = 0; i < N1 && i < 5; ++i) {
        std::cout
            << "  px" << i << " " << nombres[i]
            << " RGB("
            << static_cast<int>(syn[3 * i]) << ","
            << static_cast<int>(syn[3 * i + 1]) << ","
            << static_cast<int>(syn[3 * i + 2])
            << ") -> gris "
            << static_cast<int>(got[i])
            << "\n";
    }

    bool ok = true;
    uint32_t fallos = 0;

    for (uint32_t i = 0; i < N1; ++i) {
        const uint8_t expected = rgb_to_gray(
            syn[3 * i],
            syn[3 * i + 1],
            syn[3 * i + 2]
        );

        if (got[i] != expected) {
            ok = false;
            ++fallos;

            if (fallos <= 3) {
                std::cout
                    << "  ERROR px" << i
                    << ": esperado " << static_cast<int>(expected)
                    << ", obtenido " << static_cast<int>(got[i])
                    << "\n";
            }
        }
    }

    std::cout << "\n========================================\n";
    std::cout
        << "RESULTADO: " << (ok ? "PASA" : "FALLA")
        << "  (" << (N1 - fallos) << "/" << N1
        << " pixeles correctos)\n";
    std::cout << "========================================\n\n";

    if (!ok) {
        std::cout
            << "ERROR: se cancela la imagen real porque "
            << "la prueba sintetica fallo\n";
        sc_stop();
        return;
    }

    // =========================================================
    // Job 2: Imagen real 1920x1080
    // =========================================================
    const uint32_t W2 = 1920;
    const uint32_t H2 = 1080;
    const uint32_t N2 = W2 * H2;

    std::cout
        << "--- Job 2: Imagen real sapo perro "
        << W2 << "x" << H2 << " ---\n";

    if (!cpu->load_image_to_ram("sapo_perro.rgb", SRC_REAL)) {
        std::cout << "ERROR: no se pudo cargar sapo_perro.rgb\n";
        sc_stop();
        return;
    }

if (!process_job(Job{
        static_cast<uint32_t>(SRC_REAL),
        static_cast<uint32_t>(DST_REAL),
        N2,
        "sapo_perro"
    })) {

    std::cout
        << "ERROR: no se guardara la imagen porque "
        << "el acelerador no termino\n";

    sc_stop();
    return;
}

wait(100, SC_NS);

    if (!cpu->save_image_from_ram(
            "sapo_perro_gray.raw",
            DST_REAL,
            N2)) {

        std::cout
            << "ERROR: no se pudo guardar sapo_perro_gray.raw\n";
        sc_stop();
        return;
    }

    std::cout << "Imagen sapo perro procesada correctamente\n";
    std::cout << "Salida: sapo_perro_gray.raw\n";

    sc_stop();
}
};

int sc_main(int argc, char* argv[]) {
    Testbench* tb = new Testbench("testbench");
    sc_start();
    delete tb;
    
    return 0;
}
