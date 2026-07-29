// golden_generate.cpp
// Rol C - EC4 (Verificacion, MP6160)
//
// Genera un "golden" de referencia de forma INDEPENDIENTE del sistema
// SystemC/RTL bajo prueba, aplicando la misma conversion RGB->gris que usa
// el acelerador (rgb_to_gray.h), sobre la imagen RAW RGB 1080p de entrada.
//
// La formula de abajo fue CONFIRMADA contra el archivo real del repo
// (MP6160_grupo_5-tarea3/tarea3_vp/vp_accel/rgb_to_gray.h, rama tarea_3_final):
// luma BT.709, con `double` y redondeo +0.5. Coincide exactamente.
//
// Uso:
//   g++ -O2 -o golden_generate golden_generate.cpp
//   ./golden_generate <input_rgb_1080p> <output_gray_raw>
//
// Formato de entrada esperado: RAW RGB intercalado, 8 bits por canal, sin
// cabecera, 1920x1080 (6,220,800 bytes = 1920*1080*3).
//
// Formato de salida: escala de grises RAW, 8 bits por pixel, sin cabecera
// (2,073,600 bytes = 1920*1080). Si el sistema bajo prueba genera un .pgm
// con cabecera (como se vio en tarea3), usar compare_bitexact con la opcion
// --skip-pgm-header para saltarla en la comparacion.

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <string>

static const int WIDTH  = 1920;
static const int HEIGHT = 1080;
static const size_t RGB_BYTES  = static_cast<size_t>(WIDTH) * HEIGHT * 3;
static const size_t GRAY_BYTES = static_cast<size_t>(WIDTH) * HEIGHT;

// ---------------------------------------------------------------------
// Formula CONFIRMADA contra tarea3_vp/vp_accel/rgb_to_gray.h del repo:
// luma BT.709 (ITU-R BT.709-6, item 3.2), double, redondeo +0.5.
// Identica, campo a campo, a la del acelerador -> garantiza bit-exact.
// ---------------------------------------------------------------------
static inline uint8_t rgb_to_gray(uint8_t r, uint8_t g, uint8_t b) {
    double y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    return static_cast<uint8_t>(y + 0.5);
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::fprintf(stderr, "Uso: %s <input_rgb_1080p> <output_gray_raw>\n", argv[0]);
        return 2;
    }

    const std::string input_path  = argv[1];
    const std::string output_path = argv[2];

    FILE* fin = std::fopen(input_path.c_str(), "rb");
    if (!fin) {
        std::fprintf(stderr, "[ERROR] No se pudo abrir '%s'\n", input_path.c_str());
        return 1;
    }

    std::fseek(fin, 0, SEEK_END);
    long file_size = std::ftell(fin);
    std::fseek(fin, 0, SEEK_SET);

    if (file_size < 0 || static_cast<size_t>(file_size) != RGB_BYTES) {
        std::fprintf(stderr,
            "[ERROR] Tamano inesperado de '%s': %ld bytes (se esperaban %zu = %d x %d x 3)\n",
            input_path.c_str(), file_size, RGB_BYTES, WIDTH, HEIGHT);
        std::fclose(fin);
        return 1;
    }

    std::vector<uint8_t> rgb(RGB_BYTES);
    size_t read_bytes = std::fread(rgb.data(), 1, RGB_BYTES, fin);
    std::fclose(fin);

    if (read_bytes != RGB_BYTES) {
        std::fprintf(stderr, "[ERROR] Lectura incompleta: %zu/%zu bytes\n", read_bytes, RGB_BYTES);
        return 1;
    }

    std::vector<uint8_t> gray(GRAY_BYTES);
    for (size_t px = 0; px < GRAY_BYTES; ++px) {
        uint8_t r = rgb[px * 3 + 0];
        uint8_t g = rgb[px * 3 + 1];
        uint8_t b = rgb[px * 3 + 2];
        gray[px] = rgb_to_gray(r, g, b);
    }

    FILE* fout = std::fopen(output_path.c_str(), "wb");
    if (!fout) {
        std::fprintf(stderr, "[ERROR] No se pudo crear '%s'\n", output_path.c_str());
        return 1;
    }
    size_t written = std::fwrite(gray.data(), 1, GRAY_BYTES, fout);
    std::fclose(fout);

    if (written != GRAY_BYTES) {
        std::fprintf(stderr, "[ERROR] Escritura incompleta: %zu/%zu bytes\n", written, GRAY_BYTES);
        return 1;
    }

    std::printf("[GOLDEN] Resolucion: %dx%d\n", WIDTH, HEIGHT);
    std::printf("[GOLDEN] Bytes RGB leidos: %zu\n", RGB_BYTES);
    std::printf("[GOLDEN] Bytes gris generados: %zu\n", GRAY_BYTES);
    std::printf("[GOLDEN] Salida: %s\n", output_path.c_str());
    std::printf("[GOLDEN] GOLDEN_GENERATION_PASS\n");

    return 0;
}
