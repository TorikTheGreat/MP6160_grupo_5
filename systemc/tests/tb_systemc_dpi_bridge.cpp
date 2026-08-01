#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>

#include "ram_rtl_proxy.h"
#include "systemc_dpi_bridge.h"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

using namespace sc_core;

// Funciones portables implementadas en systemc_dpi_bridge.cpp.
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

// =====================================================================
// Simula el lado SystemVerilog + BFM + RAM RTL.
// =====================================================================

struct PortableDpiMemory : sc_module {
    std::vector<std::uint8_t> memory;
    std::size_t serviced_requests = 0;

    SC_HAS_PROCESS(PortableDpiMemory);

    PortableDpiMemory(
        sc_module_name name,
        std::size_t memory_size
    )
        : sc_module(name),
          memory(memory_size, 0) {

        SC_THREAD(service_requests);
    }

    void service_requests() {
        while (true) {
            long long address = 0;
            int length = 0;
            int is_write = 0;

            if (!dpi_poll_request(
                    &address,
                    &length,
                    &is_write)) {

                wait(1, SC_NS);
                continue;
            }

            ++serviced_requests;

            std::array<unsigned char, 4096> buffer{};

            const bool invalid_length =
                length <= 0 ||
                length >
                    static_cast<int>(buffer.size());

            const bool invalid_address =
                address < 0 ||
                static_cast<std::uint64_t>(address) >=
                    memory.size();

            bool out_of_range =
                invalid_length ||
                invalid_address;

            if (!out_of_range) {
                const auto unsigned_address =
                    static_cast<std::size_t>(address);

                out_of_range =
                    static_cast<std::size_t>(length) >
                    memory.size() - unsigned_address;
            }

            if (out_of_range) {
                wait(10, SC_NS);

                // AXI SLVERR.
                dpi_complete(2);

                wait(SC_ZERO_TIME);
                continue;
            }

            const auto memory_address =
                static_cast<std::size_t>(address);

            if (is_write != 0) {
                // SystemC escribe hacia la RAM.
                dpi_fetch(
                    address,
                    length,
                    buffer.data()
                );

                std::copy_n(
                    buffer.begin(),
                    static_cast<std::size_t>(length),
                    memory.begin() +
                        static_cast<std::ptrdiff_t>(
                            memory_address
                        )
                );
            } else {
                // SystemC lee desde la RAM.
                std::copy_n(
                    memory.begin() +
                        static_cast<std::ptrdiff_t>(
                            memory_address
                        ),
                    static_cast<std::size_t>(length),
                    buffer.begin()
                );

                dpi_store(
                    address,
                    length,
                    buffer.data()
                );
            }

            // Simula el tiempo consumido por AXI.
            wait(10, SC_NS);

            // AXI OKAY.
            dpi_complete(0);

            wait(SC_ZERO_TIME);
        }
    }
};

// =====================================================================
// Generador de transacciones TLM.
// =====================================================================

struct DpiBridgeTester : sc_module {
    tlm_utils::simple_initiator_socket<DpiBridgeTester>
        socket_cpu;

    tlm_utils::simple_initiator_socket<DpiBridgeTester>
        socket_acc;

    PortableDpiMemory& dpi_memory;

    bool passed = true;

    SC_HAS_PROCESS(DpiBridgeTester);

    DpiBridgeTester(
        sc_module_name name,
        PortableDpiMemory& memory_ref
    )
        : sc_module(name),
          socket_cpu("socket_cpu"),
          socket_acc("socket_acc"),
          dpi_memory(memory_ref) {

        SC_THREAD(run_tests);
    }

    bool transfer(
        tlm::tlm_command command,
        std::uint64_t address,
        std::vector<std::uint8_t>& data
    ) {
        tlm::tlm_generic_payload trans;
        sc_time delay = SC_ZERO_TIME;

        trans.set_command(command);
        trans.set_address(address);
        trans.set_data_ptr(data.data());

        trans.set_data_length(
            static_cast<unsigned int>(data.size())
        );

        trans.set_streaming_width(
            static_cast<unsigned int>(data.size())
        );

        trans.set_byte_enable_ptr(nullptr);
        trans.set_dmi_allowed(false);

        trans.set_response_status(
            tlm::TLM_INCOMPLETE_RESPONSE
        );

        socket_cpu->b_transport(trans, delay);

        if (delay != SC_ZERO_TIME) {
            wait(delay);
        }

        return trans.is_response_ok();
    }

    void check_roundtrip(
        const std::string& name,
        std::uint64_t address,
        std::size_t length
    ) {
        std::vector<std::uint8_t> written(length);
        std::vector<std::uint8_t> read(length, 0);

        for (std::size_t index = 0;
             index < length;
             ++index) {

            written[index] =
                static_cast<std::uint8_t>(
                    (index * 29u + length) & 0xFFu
                );
        }

        const bool write_ok = transfer(
            tlm::TLM_WRITE_COMMAND,
            address,
            written
        );

        const bool read_ok = transfer(
            tlm::TLM_READ_COMMAND,
            address,
            read
        );

        const bool test_ok =
            write_ok &&
            read_ok &&
            written == read;

        std::cout
            << name
            << ": "
            << (test_ok ? "PASS" : "FAIL")
            << " | dirección=0x"
            << std::hex
            << address
            << std::dec
            << " | bytes="
            << length
            << "\n";

        if (!test_ok) {
            passed = false;
        }
    }

    void check_out_of_range() {
        std::vector<std::uint8_t> data(
            8,
            0x5A
        );

        const bool accepted = transfer(
            tlm::TLM_WRITE_COMMAND,
            0x00010000,
            data
        );

        const bool test_ok = !accepted;

        std::cout
            << "Propagación de SLVERR: "
            << (test_ok ? "PASS" : "FAIL")
            << "\n";

        if (!test_ok) {
            passed = false;
        }
    }

    void run_tests() {
        wait(5, SC_NS);

        std::cout
            << "\n========================================\n"
            << " Prueba portable del puente DPI\n"
            << "========================================\n";

        check_roundtrip(
            "Transferencia DPI de 8 bytes",
            0x00000100,
            8
        );

        check_roundtrip(
            "Transferencia DPI de 4096 bytes",
            0x00002000,
            4096
        );

        check_roundtrip(
            "Troceo DPI de 4104 bytes",
            0x00004000,
            4104
        );

        check_roundtrip(
            "Límite DPI de 4 KB",
            0x00000FF8,
            16
        );

        check_out_of_range();

        const std::size_t expected_requests = 13;

        std::cout
            << "Solicitudes atendidas: "
            << dpi_memory.serviced_requests
            << " / esperadas: "
            << expected_requests
            << "\n";

        if (dpi_memory.serviced_requests !=
            expected_requests) {

            passed = false;
        }

        std::cout
            << "========================================\n"
            << "RESULTADO PUENTE DPI: "
            << (passed ? "PASS" : "FAIL")
            << "\n"
            << "========================================\n";

        sc_stop();
    }
};

int sc_main(int, char**) {
    RamRtlProxy proxy("ram_rtl_proxy");

    PortableDpiMemory memory(
        "portable_dpi_memory",
        64 * 1024
    );

    DpiBridgeTester tester(
        "dpi_bridge_tester",
        memory
    );

    tester.socket_cpu.bind(
        proxy.socket_cpu
    );

    tester.socket_acc.bind(
        proxy.socket_acc
    );

    systemc_dpi_bind_proxy(&proxy);

    sc_start();

    systemc_dpi_unbind_proxy();

    return tester.passed ? 0 : 1;
}