// compare_bitexact.cpp
// Rol C - EC4 (Verificacion, MP6160)
//
// Compara bit-exact la salida real del sistema (imagen en escala de grises
// generada por el flujo completo SystemC+RTL+DPI) contra el golden generado
// de forma independiente por golden_generate.cpp.
//
// Uso:
//   g++ -O2 -o compare_bitexact compare_bitexact.cpp
//   ./compare_bitexact <golden_gray_raw> <system_output> [--skip-pgm-header]
//
// --skip-pgm-header: usar si el archivo de salida del sistema es un .pgm
// con cabecera de texto tipo P5 (como sapo_perro.pgm en tarea3).

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <vector>
#include <string>

static const int WIDTH  = 1920;
static const int HEIGHT = 1080;
static const size_t GRAY_BYTES = static_cast<size_t>(WIDTH) * HEIGHT;
static const int MAX_DIFFS_TO_SHOW = 20;

static bool read_file(const std::string& path, std::vector<uint8_t>& out, bool skip_pgm_header) {
    FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) {
        std::fprintf(stderr, "[ERROR] No se pudo abrir '%s'\n", path.c_str());
        return false;
    }
    std::fseek(f, 0, SEEK_END);
    long size = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    if (size < 0) { std::fclose(f); return false; }

    std::vector<uint8_t> buf(static_cast<size_t>(size));
    size_t rd = std::fread(buf.data(), 1, buf.size(), f);
    std::fclose(f);
    if (rd != buf.size()) {
        std::fprintf(stderr, "[ERROR] Lectura incompleta de '%s'\n", path.c_str());
        return false;
    }

    if (skip_pgm_header && buf.size() >= 2 && buf[0] == 'P' && buf[1] == '5') {
        size_t pos = 2;
        int tokens_found = 0;
        while (pos < buf.size() && tokens_found < 3) {
            while (pos < buf.size() && std::isspace(buf[pos])) ++pos;
            size_t tok_start = pos;
            while (pos < buf.size() && !std::isspace(buf[pos])) ++pos;
            if (pos > tok_start) ++tokens_found;
        }
        if (pos < buf.size()) ++pos;
        out.assign(buf.begin() + static_cast<long>(pos), buf.end());
    } else {
        out = std::move(buf);
    }
    return true;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        std::fprintf(stderr, "Uso: %s <golden_gray_raw> <system_output> [--skip-pgm-header]\n", argv[0]);
        return 2;
    }

    std::string golden_path = argv[1];
    std::string system_path = argv[2];
    bool skip_pgm_header = (argc >= 4 && std::string(argv[3]) == "--skip-pgm-header");

    std::vector<uint8_t> golden, system_out;

    if (!read_file(golden_path, golden, false)) return 1;
    if (!read_file(system_path, system_out, skip_pgm_header)) return 1;

    if (golden.size() != GRAY_BYTES) {
        std::fprintf(stderr,
            "[ERROR] Golden tiene %zu bytes, se esperaban %zu (%dx%d)\n",
            golden.size(), GRAY_BYTES, WIDTH, HEIGHT);
        return 1;
    }
    if (system_out.size() != GRAY_BYTES) {
        std::fprintf(stderr,
            "[ERROR] Salida del sistema tiene %zu bytes (tras remover cabecera si aplica), se esperaban %zu (%dx%d)\n",
            system_out.size(), GRAY_BYTES, WIDTH, HEIGHT);
        std::fprintf(stderr, "        Si el archivo es .pgm, probar con --skip-pgm-header\n");
        return 1;
    }

    size_t diffs = 0;
    std::printf("[COMPARE] Resolucion: %dx%d\n", WIDTH, HEIGHT);
    std::printf("[COMPARE] Pixeles a verificar: %zu\n", GRAY_BYTES);

    for (size_t px = 0; px < GRAY_BYTES; ++px) {
        if (golden[px] != system_out[px]) {
            if (diffs < static_cast<size_t>(MAX_DIFFS_TO_SHOW)) {
                int x = static_cast<int>(px % WIDTH);
                int y = static_cast<int>(px / WIDTH);
                std::printf("[DIFF] (x=%d, y=%d) golden=%u sistema=%u\n",
                            x, y, golden[px], system_out[px]);
            }
            ++diffs;
        }
    }

    std::printf("[COMPARE] Pixeles verificados: %zu/%zu\n", GRAY_BYTES - diffs, GRAY_BYTES);
    std::printf("[COMPARE] Diferencias encontradas: %zu\n", diffs);

    if (diffs == 0) {
        std::printf("[COMPARE] GOLDEN_COMPARE_PASS\n");
        return 0;
    } else {
        std::printf("[COMPARE] GOLDEN_COMPARE_FAIL\n");
        return 1;
    }
}
