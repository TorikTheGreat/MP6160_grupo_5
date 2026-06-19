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

// Mapa de memoria
// static constexpr uint64_t ACC_BASE = 0x40000000ull;
static constexpr uint64_t SRC_TEST = 0x00000000ull;   // Imagen sintética entrada (RGB)
static constexpr uint64_t DST_TEST = 0x02000000ull;   // Imagen sintética salida (gris)

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
    
    std::vector<Job> jobs;

    SC_CTOR(Testbench) {
        ram = new RAM("ram", 64 * 1024 * 1024);
        cpu = new CPU("cpu", ram);
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
    }


    uint32_t read_reg(uint64_t off) {
        return cpu->read_accelerator_register(ACC_BASE + off);
    }

    
    // Metodo para procesar una imagen: 
    // configura el acelerador y espera a que termine
    void process_job(const Job& job) {
        std::cout << "CPU: procesando job '" << job.name << "' "
                  << "(src=0x" << std::hex << job.src << " dst=0x" << job.dst 
                  << std::dec << " num=" << job.num << ")\n";
        
        // Configurar y lanzar job usando método del CPU
        cpu->run_accelerator_job(ACC_BASE, job.src, job.dst, job.num);
        wait(10, SC_NS);
        
        // Esperar a que termine (polling). El watchdog se escala con el tamaño:
        // el acelerador modela ~1 ns/pixel, y cada sondeo espera 10 ns.
        if( !cpu->wait_for_accelerator_done(ACC_BASE, job.num + 100000) ) {
            std::cout << "ERROR: El acelerador no respondió a tiempo\n";
        } else {
            std::cout << "CPU: job '" << job.name << "' completado\n";
        }
    }


    void run_test() {
        wait(1, SC_NS);
        
        std::cout << "\n========================================\n";
        std::cout << "  SystemC Accelerator Testbench\n";
        std::cout << "========================================\n\n";

        // ============ Job 1: Imagen sintética 8x8 ============
        const uint32_t W1 = 8, H1 = 8, N1 = W1 * H1;
        std::vector<uint8_t> syn(static_cast<size_t>(N1) * 3);
        
        auto set_px = [&](uint32_t i, uint8_t r, uint8_t g, uint8_t b) {
            syn[3*i]     = r;
            syn[3*i + 1] = g;
            syn[3*i + 2] = b;
        };
        
        // Primeros 5 píxeles con colores conocidos
        if (N1 > 0) set_px(0, 0,     0,   0);       // negro  -> 0
        if (N1 > 1) set_px(1, 255, 255, 255);       // blanco -> 255
        if (N1 > 2) set_px(2, 255,   0,   0);       // rojo   -> 54
        if (N1 > 3) set_px(3,   0, 255,   0);       // verde  -> 182
        if (N1 > 4) set_px(4,   0,   0, 255);       // azul   -> 18
        
        // Degradados para los píxeles restantes
        for (uint32_t i = 5; i < N1; ++i) {
            set_px(i, i % 256, (2*i) % 256, (3*i) % 256);
        }
        
        // Precargar imagen sintética en RAM
        write_raw("input.rgb", syn);
        cpu->load_image_to_ram("input.rgb", SRC_TEST);
        
        // Procesar job 1
        std::cout << "--- Job 1: Imagen Sintética 8x8 ---\n";
        process_job(Job{SRC_TEST, DST_TEST, N1, "sintetica"});
        wait(100, SC_NS);
        
        // Volcar y verificar resultado
        cpu->save_image_from_ram("output.gray", DST_TEST, N1);
        std::vector<uint8_t> got(N1);
        {
            std::ifstream f("output.gray", std::ios::binary);
            f.read(reinterpret_cast<char*>(got.data()), N1);
        }
        
        std::cout << "\n--- Verificacion de Resultado ---\n";
        const char* nombres[5] = {"negro ", "blanco", "rojo  ", "verde ", "azul  "};
        for (uint32_t i = 0; i < N1 && i < 5; ++i) {
            std::cout << "  px" << i << " " << nombres[i] 
                      << " RGB(" << (int)syn[3*i] << "," 
                      << (int)syn[3*i+1] << "," << (int)syn[3*i+2]
                      << ") -> gris " << (int)got[i] << "\n";
        }
        
        bool ok = true;
        uint32_t fallos = 0;
        for (uint32_t i = 0; i < N1; ++i) {
            uint8_t expected = rgb_to_gray(syn[3*i], syn[3*i+1], syn[3*i+2]);
            if (got[i] != expected) {
                ok = false;
                ++fallos;
                if (fallos <= 3) {  // Mostrar solo los primeros 3 errores
                    std::cout << "  ERROR px" << i << ": esperado " << (int)expected 
                              << ", obtenido " << (int)got[i] << "\n";
                }
            }
        }
        
        std::cout << "\n========================================\n";
        std::cout << "RESULTADO 8x8 (sanity): " << (ok ? "PASA" : "FALLA")
                  << "  (" << (N1 - fallos) << "/" << N1 << " pixeles correctos)\n";
        std::cout << "========================================\n\n";

        // ============ Job 2: Imagen real 1080p (1920x1080) ============
        // Flujo completo del enunciado: disco -> RAM -> acelerador -> RAM -> disco,
        // y verificacion bit-exact contra un golden (misma conversion BT.709).
        const uint32_t W2 = 1920, H2 = 1080, N2 = W2 * H2;
        const uint64_t SRC2 = 0x00000000ull;   // buffer de entrada (RGB)  -> mapa de memoria
        const uint64_t DST2 = 0x02000000ull;   // buffer de salida  (gris)

        std::cout << "--- Job 2: Imagen 1080p (1920x1080) ---\n";
        if (!cpu->load_image_to_ram("images/input.rgb", SRC2)) {
            std::cout << "ERROR: no se pudo cargar images/input.rgb "
                      << "(genera la imagen primero)\n";
        } else {
            process_job(Job{(uint32_t)SRC2, (uint32_t)DST2, N2, "1080p"});
            wait(100, SC_NS);
            cpu->save_image_from_ram("images/output.gray", DST2, N2);

            // Golden: recalcular el gris desde la entrada y comparar byte a byte
            std::vector<uint8_t> rgb(static_cast<size_t>(N2) * 3), gray(N2);
            { std::ifstream f("images/input.rgb",  std::ios::binary);
              f.read(reinterpret_cast<char*>(rgb.data()),  rgb.size()); }
            { std::ifstream f("images/output.gray", std::ios::binary);
              f.read(reinterpret_cast<char*>(gray.data()), N2); }

            uint32_t fallos2 = 0;
            for (uint32_t i = 0; i < N2; ++i)
                if (gray[i] != rgb_to_gray(rgb[3*i], rgb[3*i+1], rgb[3*i+2])) ++fallos2;

            std::cout << "  entrada: " << N2 << " px (" << rgb.size() << " bytes)"
                      << " -> salida: " << N2 << " bytes (images/output.gray)\n";
            std::cout << "\n========================================\n";
            std::cout << "RESULTADO 1080p: " << (fallos2 == 0 ? "PASA" : "FALLA")
                      << "  (" << (N2 - fallos2) << "/" << N2 << " pixeles correctos)\n";
            std::cout << "========================================\n\n";
        }

        sc_stop();
    }
};

int sc_main(int argc, char* argv[]) {
    Testbench* tb = new Testbench("testbench");
    sc_start();
    delete tb;
    
    return 0;
}
