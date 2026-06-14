// =====================================================================
//  Testbench del acelerador RGB -> escala de grises
//
//  Conecta:  ConfigDriver (hace de CPU) --cfg--> Accelerator --mem--> RAM
//  El "CPU" procesa dos trabajos en una sola simulación:
//    1) Imagen sintética 8x8 -> verifica la conversión contra un "golden".
//    2) Imagen real (PPM) -> la convierte y guarda el gris (PGM) para verla.
//       Sirve para ver cómo cambia la salida al tocar la fórmula (rgb_to_gray.h).
//  La E/S de archivos modela el almacenamiento persistente y la orquesta el CPU
//  (igual que en el sistema real); el acelerador solo toca la RAM.
// =====================================================================
#include <systemc.h>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <fstream>
#include <vector>
#include <string>
#include <cctype>
#include <iostream>
#include <filesystem>

// Directorio para la imagen de entrada (images/input.ppm) y el resultado (images/output.pgm).
static const std::string IMG_DIR = "images";
static const std::string IMG_IN  = IMG_DIR + "/input.ppm";
static const std::string IMG_OUT = IMG_DIR + "/output.pgm";
#include "accelerator.h"
#include "ram.h"
#include "rgb_to_gray.h"

// Mapa de memoria (RAM = 0x0..0x03FF_FFFF, 64 MB; regs del acelerador en ACC_BASE).
// Cuatro buffers que no se solapan, uno por trabajo:
static constexpr uint64_t SRC_SYN = 0x00000000ull;   // 1) entrada sintética (RGB)
static constexpr uint64_t DST_SYN = 0x02000000ull;   // 1) salida sintética  (gris)
static constexpr uint64_t SRC_IMG = 0x00400000ull;   // 2) entrada imagen    (RGB)
static constexpr uint64_t DST_IMG = 0x03000000ull;   // 2) salida imagen     (gris)

// =====================================================================
//  E/S de imágenes Netpbm (sin librerías): P6 = PPM color, P5 = PGM gris.
//  Las usa el "CPU" para leer/escribir el disco; el acelerador no las conoce.
// =====================================================================

// Lee el siguiente entero de un encabezado PNM, saltando espacios y comentarios (#...).
static int pnm_int(std::istream& f) {
    int c = f.get();
    for (;;) {
        if (c == '#') { while (c != '\n' && c != EOF) c = f.get(); }
        else if (std::isspace(c)) c = f.get();
        else break;
    }
    int v = 0;
    while (std::isdigit(c)) { v = v * 10 + (c - '0'); c = f.get(); }
    return v;   // 'c' ya consumió un separador tras el número
}

// Lee un PPM binario (P6) y devuelve sus píxeles RGB intercalados. false si no abre.
static bool read_ppm(const std::string& path, uint32_t& w, uint32_t& h,
                     std::vector<uint8_t>& rgb) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return false;
    std::string magic; f >> magic;
    if (magic != "P6") { std::cerr << "  (solo se soporta PPM binario P6)\n"; return false; }
    w = pnm_int(f); h = pnm_int(f); int maxval = pnm_int(f);   // tras maxval queda el dato binario
    if (maxval != 255) { std::cerr << "  (se espera maxval 255 / 8 bits)\n"; return false; }
    rgb.resize(static_cast<size_t>(w) * h * 3);
    f.read(reinterpret_cast<char*>(rgb.data()), rgb.size());
    return static_cast<bool>(f);
}

// Escribe un PGM binario (P5) de 8 bits a partir de un buffer de grises.
static void write_pgm(const std::string& path, uint32_t w, uint32_t h,
                      const std::vector<uint8_t>& gray) {
    std::ofstream f(path, std::ios::binary);
    f << "P5\n" << w << " " << h << "\n255\n";
    f.write(reinterpret_cast<const char*>(gray.data()), gray.size());
}

// Genera un PPM de barras de color (para que el ejemplo corra sin imagen propia).
// Con barras puras el efecto de los pesos de la fórmula se ve clarísimo.
static void make_sample_ppm(const std::string& path, uint32_t w, uint32_t h) {
    const uint8_t bars[8][3] = {
        {255,0,0},{0,255,0},{0,0,255},{255,255,0},
        {0,255,255},{255,0,255},{255,255,255},{0,0,0}
    };
    std::vector<uint8_t> rgb(static_cast<size_t>(w) * h * 3);
    for (uint32_t y = 0; y < h; ++y)
        for (uint32_t x = 0; x < w; ++x) {
            const uint8_t* c = bars[(x * 8) / w];
            size_t k = (static_cast<size_t>(y) * w + x) * 3;
            rgb[k] = c[0]; rgb[k+1] = c[1]; rgb[k+2] = c[2];
        }
    std::ofstream f(path, std::ios::binary);
    f << "P6\n" << w << " " << h << "\n255\n";
    f.write(reinterpret_cast<char*>(rgb.data()), rgb.size());
}

// Vuelca bytes crudos a un archivo (para precargar la RAM con load_from_file).
static void write_raw(const std::string& path, const std::vector<uint8_t>& data) {
    std::ofstream f(path, std::ios::binary);
    f.write(reinterpret_cast<const char*>(data.data()), data.size());
}

// =====================================================================
//  "CPU" de prueba: configura el acelerador por TLM y espera DONE.
//  Procesa una lista de trabajos en orden, reutilizando el acelerador.
// =====================================================================
struct Job { uint32_t src, dst, num; std::string name; };

struct ConfigDriver : sc_module {
    tlm_utils::simple_initiator_socket<ConfigDriver> sock;   // -> Accelerator.cfg_socket
    std::vector<Job> jobs;

    SC_HAS_PROCESS(ConfigDriver);
    ConfigDriver(sc_module_name n, std::vector<Job> j)
        : sc_module(n), sock("sock"), jobs(std::move(j)) { SC_THREAD(run); }

    void write_reg(uint64_t off, uint32_t v) {
        tlm::tlm_generic_payload t; sc_time d = SC_ZERO_TIME;
        t.set_command(tlm::TLM_WRITE_COMMAND); t.set_address(ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<unsigned char*>(&v)); t.set_data_length(4);
        t.set_streaming_width(4); t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        sock->b_transport(t, d); sc_assert(t.is_response_ok());
    }
    uint32_t read_reg(uint64_t off) {
        uint32_t v = 0; tlm::tlm_generic_payload t; sc_time d = SC_ZERO_TIME;
        t.set_command(tlm::TLM_READ_COMMAND); t.set_address(ACC_BASE + off);
        t.set_data_ptr(reinterpret_cast<unsigned char*>(&v)); t.set_data_length(4);
        t.set_streaming_width(4); t.set_byte_enable_ptr(nullptr);
        t.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        sock->b_transport(t, d); sc_assert(t.is_response_ok());
        return v;
    }

    void process(const Job& j) {
        std::cout << "CPU: job '" << j.name << "' (src=0x" << std::hex << j.src
                  << " dst=0x" << j.dst << std::dec << " num=" << j.num << ")\n";
        write_reg(0x04, j.src);   // ADDR_INPUT
        write_reg(0x08, j.dst);   // ADDR_OUTPUT
        write_reg(0x0C, j.num);   // NUM_PIXELS
        write_reg(0x00, 1);       // CONTROL: bit0 = START
        while ((read_reg(0x00) & 1u) == 0)   // polling de DONE (CONTROL bit0)
            wait(1, SC_NS);
        std::cout << "CPU: '" << j.name << "' DONE en t=" << sc_time_stamp() << "\n";
    }

    void run() {
        for (const auto& j : jobs) process(j);
        sc_stop();
    }
};

int sc_main(int, char*[]) {
    // ============ Trabajo 1: imagen sintética 8x8 (verifica la fórmula) ============
    const uint32_t W1 = 8, H1 = 8, N1 = W1 * H1;
    // Primeros 5 píxeles: colores conocidos. Esperados con BT.709: 0,255,54,182,18.
    std::vector<uint8_t> syn(static_cast<size_t>(N1) * 3);
    auto set_px = [&](uint32_t i, uint8_t r, uint8_t g, uint8_t b) {
        syn[3*i] = r; syn[3*i+1] = g; syn[3*i+2] = b; };
    if (N1 > 0) set_px(0, 0, 0, 0);         // negro  -> 0
    if (N1 > 1) set_px(1, 255, 255, 255);   // blanco -> 255
    if (N1 > 2) set_px(2, 255, 0, 0);       // rojo   -> 54
    if (N1 > 3) set_px(3, 0, 255, 0);       // verde  -> 182
    if (N1 > 4) set_px(4, 0, 0, 255);       // azul   -> 18
    for (uint32_t i = 5; i < N1; ++i)       // degradado
        set_px(i, i % 256, (2*i) % 256, (3*i) % 256);
    write_raw("input.rgb", syn);

    // ============ Trabajo 2: imagen real PPM -> gris PGM ============
    // Usa tu propia imagen:  convert foto.jpg images/input.ppm   (ImageMagick)
    // Si no existe, generamos unas barras de color de muestra en ese directorio.
    std::filesystem::create_directories(IMG_DIR);
    uint32_t W2, H2; std::vector<uint8_t> rgb;
    if (!read_ppm(IMG_IN, W2, H2, rgb)) {
        std::cout << "No hay " << IMG_IN << ": genero barras de color de muestra.\n";
        W2 = 256; H2 = 128;
        make_sample_ppm(IMG_IN, W2, H2);
        read_ppm(IMG_IN, W2, H2, rgb);
    }
    const uint32_t N2 = W2 * H2;
    write_raw("input_img.rgb", rgb);   // píxeles crudos (sin encabezado) para la RAM

    // ============ Instanciar, conectar y precargar la RAM ============
    RAM          ram("ram");
    Accelerator  acc("acc");
    ConfigDriver cpu("cpu", {
        {SRC_SYN, DST_SYN, N1, "sintetica"},
        {SRC_IMG, DST_IMG, N2, "imagen"   },
    });
    acc.mem_socket.bind(ram.socket);     // acelerador -> RAM
    cpu.sock.bind(acc.cfg_socket);       // CPU -> registros del acelerador

    ram.load_from_file("input.rgb",     SRC_SYN);   // backdoor (modela cargar de disco)
    ram.load_from_file("input_img.rgb", SRC_IMG);

    // ============ Correr la simulación (ambos trabajos) ============
    sc_start();

    // ============ Trabajo 1: volcar y verificar contra el golden ============
    ram.save_to_file("output.gray", DST_SYN, N1);
    std::vector<uint8_t> got(N1);
    { std::ifstream f("output.gray", std::ios::binary);
      f.read(reinterpret_cast<char*>(got.data()), N1); }

    std::cout << "\n--- Trabajo 1: verificacion ---\n";
    const char* nombres[5] = {"negro ", "blanco", "rojo  ", "verde ", "azul  "};
    for (uint32_t i = 0; i < N1 && i < 5; ++i)
        std::cout << "  px" << i << " " << nombres[i] << " RGB("
                  << (int)syn[3*i] << "," << (int)syn[3*i+1] << "," << (int)syn[3*i+2]
                  << ") -> gris " << (int)got[i] << "\n";
    bool ok = true; uint32_t fallos = 0;
    for (uint32_t i = 0; i < N1; ++i)
        if (got[i] != rgb_to_gray(syn[3*i], syn[3*i+1], syn[3*i+2])) { ok = false; ++fallos; }
    std::cout << (ok ? "RESULTADO: PASA" : "RESULTADO: FALLA")
              << "  (" << (N1 - fallos) << "/" << N1 << " pixeles correctos)\n";

    // ============ Trabajo 2: volcar el gris y guardarlo como PGM visible ============
    ram.save_to_file("output_img.gray", DST_IMG, N2);
    std::vector<uint8_t> gris(N2);
    { std::ifstream f("output_img.gray", std::ios::binary);
      f.read(reinterpret_cast<char*>(gris.data()), N2); }
    write_pgm(IMG_OUT, W2, H2, gris);

    uint8_t gmin = 255, gmax = 0; uint64_t suma = 0;          // métrica sensible a la fórmula
    for (uint8_t v : gris) { gmin = std::min(gmin, v); gmax = std::max(gmax, v); suma += v; }
    std::cout << "\n--- Trabajo 2: imagen ---\n"
              << "  " << W2 << "x" << H2 << " -> " << IMG_OUT << "  (abrela para ver el gris)\n"
              << "  gris min/prom/max = " << (int)gmin << "/" << (suma / N2)
              << "/" << (int)gmax << "   (cambia los pesos en rgb_to_gray.h y compara)\n";

    return ok ? 0 : 1;
}
