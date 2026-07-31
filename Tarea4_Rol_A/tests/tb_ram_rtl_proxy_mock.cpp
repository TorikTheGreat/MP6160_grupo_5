#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>

#include "ram_rtl_proxy.h"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

using namespace sc_core;

// Memoria simulada que atiende las solicitudes publicadas por RamRtlProxy.
struct MockAxiMemory : sc_module {
    RamRtlProxy& proxy;
    std::vector<std::uint8_t> memory;

    std::size_t serviced_requests = 0;

    SC_HAS_PROCESS(MockAxiMemory);

    MockAxiMemory(
        sc_module_name name,
        RamRtlProxy& proxy_ref,
        std::size_t memory_size
    )
        : sc_module(name),
          proxy(proxy_ref),
          memory(memory_size, 0) {

        SC_THREAD(service_requests);
    }

    void service_requests() {
        while (true) {
            std::uint64_t address = 0;
            std::uint32_t length = 0;
            bool is_write = false;

            // Revisa si el proxy tiene una solicitud pendiente.
            if (!proxy.poll_request(
                    address,
                    length,
                    is_write)) {

                wait(1, SC_NS);
                continue;
            }

            ++serviced_requests;

            std::array<std::uint8_t, 4096> buffer{};

            const bool out_of_range =
                address >= memory.size() ||
                length > memory.size() - address;

            if (out_of_range) {
                // Simula una respuesta AXI SLVERR.
                wait(10, SC_NS);
                proxy.complete_request(2);
                wait(SC_ZERO_TIME);
                continue;
            }

            bool success = true;

            if (is_write) {
                // SystemC desea escribir en la RAM.
                success = proxy.fetch_data(
                    buffer.data(),
                    buffer.size()
                );

                if (success) {
                    std::copy_n(
                        buffer.begin(),
                        length,
                        memory.begin() +
                            static_cast<std::ptrdiff_t>(address)
                    );
                }
            } else {
                // SystemC desea leer desde la RAM.
                std::copy_n(
                    memory.begin() +
                        static_cast<std::ptrdiff_t>(address),
                    length,
                    buffer.begin()
                );

                success = proxy.store_data(
                    buffer.data(),
                    length
                );
            }

            // Retardo simulado de la transferencia AXI.
            wait(10, SC_NS);

            // 0 representa OKAY y 2 representa SLVERR.
            proxy.complete_request(success ? 0 : 2);

            wait(SC_ZERO_TIME);
        }
    }
};

// Módulo que genera las transacciones TLM para probar el proxy.
struct ProxyTester : sc_module {
    // Se conectan ambos sockets del proxy para completar la topología.
    tlm_utils::simple_initiator_socket<ProxyTester> socket_cpu;
    tlm_utils::simple_initiator_socket<ProxyTester> socket_acc;

    MockAxiMemory& mock_memory;

    bool passed = true;

    SC_HAS_PROCESS(ProxyTester);

    ProxyTester(
        sc_module_name name,
        MockAxiMemory& memory_ref
    )
        : sc_module(name),
          socket_cpu("socket_cpu"),
          socket_acc("socket_acc"),
          mock_memory(memory_ref) {

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

        // Las pruebas se envían por el socket correspondiente al CPU.
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

        for (std::size_t i = 0; i < length; ++i) {
            written[i] = static_cast<std::uint8_t>(
                (i * 37u + length) & 0xFFu
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

        const bool equal = written == read;

        const bool test_ok =
            write_ok &&
            read_ok &&
            equal;

        std::cout
            << name << ": "
            << (test_ok ? "PASS" : "FAIL")
            << " | dirección=0x"
            << std::hex << address
            << std::dec
            << " | bytes=" << length
            << std::endl;

        if (!test_ok) {
            passed = false;
        }
    }

    void check_out_of_range() {
        std::vector<std::uint8_t> data(8, 0xA5);

        const bool accepted = transfer(
            tlm::TLM_WRITE_COMMAND,
            0x00010000,
            data
        );

        // La memoria mock tiene solamente 64 KiB.
        // La dirección 0x00010000 está justo fuera de rango.
        const bool test_ok = !accepted;

        std::cout
            << "Acceso fuera de rango: "
            << (test_ok ? "PASS" : "FAIL")
            << std::endl;

        if (!test_ok) {
            passed = false;
        }
    }

    void run_tests() {
        wait(5, SC_NS);

        std::cout
            << "\n====================================\n"
            << " Prueba local de RamRtlProxy\n"
            << "====================================\n";

        check_roundtrip(
            "Transferencia de 8 bytes",
            0x00000100,
            8
        );

        check_roundtrip(
            "Transferencia de 4096 bytes",
            0x00002000,
            4096
        );

        // Debe dividirse en dos solicitudes:
        // 4096 bytes y 8 bytes.
        check_roundtrip(
            "Transferencia de 4104 bytes",
            0x00004000,
            4104
        );

        // Debe dividirse en dos solicitudes:
        // 8 bytes antes del límite de 4 KB
        // y 8 bytes después del límite.
        check_roundtrip(
            "Cruce controlado de límite de 4 KB",
            0x00000FF8,
            16
        );

        check_out_of_range();

        /*
         * Cantidad esperada:
         *
         * 8 bytes:
         *   1 escritura + 1 lectura = 2
         *
         * 4096 bytes:
         *   1 escritura + 1 lectura = 2
         *
         * 4104 bytes:
         *   2 escrituras + 2 lecturas = 4
         *
         * Cruce de 4 KB:
         *   2 escrituras + 2 lecturas = 4
         *
         * Fuera de rango:
         *   1 escritura = 1
         *
         * Total = 13 solicitudes.
         */
        const std::size_t expected_requests = 13;

        std::cout
            << "Solicitudes atendidas: "
            << mock_memory.serviced_requests
            << " / esperadas: "
            << expected_requests
            << std::endl;

        if (mock_memory.serviced_requests !=
            expected_requests) {

            passed = false;
        }

        std::cout
            << "====================================\n"
            << "RESULTADO PROXY MOCK: "
            << (passed ? "PASS" : "FAIL")
            << "\n====================================\n";

        sc_stop();
    }
};

int sc_main(int, char**) {
    RamRtlProxy proxy("ram_rtl_proxy");

    // Memoria simulada de 64 KiB.
    MockAxiMemory memory(
        "mock_axi_memory",
        proxy,
        64 * 1024
    );

    ProxyTester tester(
        "proxy_tester",
        memory
    );

    // Ambos target sockets del proxy deben estar conectados.
    tester.socket_cpu.bind(proxy.socket_cpu);
    tester.socket_acc.bind(proxy.socket_acc);

    sc_start();

    return tester.passed ? 0 : 1;
}