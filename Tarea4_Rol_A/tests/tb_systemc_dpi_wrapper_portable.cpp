#include <systemc.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

// Funciones de control del wrapper.
extern "C" int systemc_create();
extern "C" int systemc_service();
extern "C" int systemc_is_finished();
extern "C" int systemc_passed();
extern "C" void systemc_destroy();

// Funciones DPI portables del puente.
extern "C" int dpi_poll_request(
    long long* address,
    int* length,
    int* is_write
);

extern "C" void dpi_fetch(
    long long address,
    int length,
    unsigned char* data
);

extern "C" void dpi_store(
    long long address,
    int length,
    const unsigned char* data
);

extern "C" void dpi_complete(int axi_response);

namespace {

constexpr std::size_t RAM_BYTES =
    64ull * 1024ull * 1024ull;

constexpr std::size_t DPI_BUFFER_BYTES =
    4096;

bool service_memory_request(
    std::vector<std::uint8_t>& memory,
    std::size_t& request_count
) {
    long long address = 0;
    int length = 0;
    int is_write = 0;

    if (!dpi_poll_request(
            &address,
            &length,
            &is_write)) {

        return true;
    }

    ++request_count;

    std::array<unsigned char, DPI_BUFFER_BYTES> buffer{};

    const bool invalid_length =
        length <= 0 ||
        length > static_cast<int>(buffer.size());

    const bool invalid_address =
        address < 0 ||
        static_cast<std::uint64_t>(address) >=
            memory.size();

    bool out_of_range =
        invalid_length ||
        invalid_address;

    std::size_t memory_address = 0;

    if (!out_of_range) {
        memory_address =
            static_cast<std::size_t>(address);

        out_of_range =
            static_cast<std::size_t>(length) >
            memory.size() - memory_address;
    }

    if (out_of_range) {
        // Simula AXI SLVERR.
        dpi_complete(2);
        return true;
    }

    if (is_write != 0) {
        // SystemC desea escribir en la RAM.
        dpi_fetch(
            address,
            length,
            buffer.data()
        );

        for (int index = 0; index < length; ++index) {
            memory[
                memory_address +
                static_cast<std::size_t>(index)
            ] = buffer[static_cast<std::size_t>(index)];
        }
    } else {
        // SystemC desea leer desde la RAM.
        for (int index = 0; index < length; ++index) {
            buffer[static_cast<std::size_t>(index)] =
                memory[
                    memory_address +
                    static_cast<std::size_t>(index)
                ];
        }

        dpi_store(
            address,
            length,
            buffer.data()
        );
    }

    // Simula AXI OKAY.
    dpi_complete(0);

    return true;
}

}  // namespace

int sc_main(int, char**) {
    std::cout
        << "\n========================================\n"
        << " Prueba portable de systemc_dpi_wrapper\n"
        << "========================================\n";

    std::vector<std::uint8_t> memory(
        RAM_BYTES,
        0
    );

    if (!systemc_create()) {
        std::cerr
            << "ERROR: systemc_create falló\n";

        return 1;
    }

    std::size_t service_iterations = 0;
    std::size_t request_count = 0;

    constexpr std::size_t MAX_SERVICE_ITERATIONS =
        600000;

    while (!systemc_is_finished() &&
           service_iterations <
               MAX_SERVICE_ITERATIONS) {

        if (!systemc_service()) {
            std::cerr
                << "ERROR: systemc_service falló\n";

            systemc_destroy();
            return 1;
        }

        ++service_iterations;

        if (!service_memory_request(
                memory,
                request_count)) {

            std::cerr
                << "ERROR: fallo atendiendo la RAM\n";

            systemc_destroy();
            return 1;
        }
    }

    const bool finished =
        systemc_is_finished() != 0;

    const bool passed =
        systemc_passed() != 0;

    std::cout
        << "\nIteraciones de servicio: "
        << service_iterations
        << "\nSolicitudes DPI atendidas: "
        << request_count
        << "\nEjecución terminada: "
        << (finished ? "SI" : "NO")
        << "\nResultado reportado: "
        << (passed ? "PASS" : "FAIL")
        << "\n";

    systemc_destroy();

    const bool test_ok =
        finished &&
        passed;

    std::cout
        << "========================================\n"
        << "RESULTADO WRAPPER PORTABLE: "
        << (test_ok ? "PASS" : "FAIL")
        << "\n"
        << "========================================\n";

    return test_ok ? 0 : 1;
}