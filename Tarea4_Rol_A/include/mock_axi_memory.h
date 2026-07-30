#ifndef MOCK_AXI_MEMORY_H
#define MOCK_AXI_MEMORY_H

#include <systemc>

#include "ram_rtl_proxy.h"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

struct MockAxiMemory : sc_core::sc_module {
    RamRtlProxy& proxy;
    std::vector<std::uint8_t> memory;

    std::size_t serviced_requests = 0;

    SC_HAS_PROCESS(MockAxiMemory);

    MockAxiMemory(
        sc_core::sc_module_name name,
        RamRtlProxy& proxy_ref,
        std::size_t memory_size
    )
        : sc_core::sc_module(name),
          proxy(proxy_ref),
          memory(memory_size, 0) {

        SC_THREAD(service_requests);
    }

    void service_requests() {
        while (true) {
            std::uint64_t address = 0;
            std::uint32_t length = 0;
            bool is_write = false;

            if (!proxy.poll_request(
                    address,
                    length,
                    is_write)) {

                wait(1, sc_core::SC_NS);
                continue;
            }

            ++serviced_requests;

            std::array<std::uint8_t, 4096> buffer{};

            const bool out_of_range =
                address >= memory.size() ||
                length >
                    memory.size() -
                    static_cast<std::size_t>(address);

            if (out_of_range) {
                wait(10, sc_core::SC_NS);

                // Código equivalente a AXI SLVERR.
                proxy.complete_request(2);

                wait(sc_core::SC_ZERO_TIME);
                continue;
            }

            bool success = true;

            if (is_write) {
                // Datos desde SystemC hacia la memoria.
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
                // Datos desde la memoria hacia SystemC.
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

            // Simula el tiempo utilizado por una transferencia AXI.
            wait(10, sc_core::SC_NS);

            // 0 = OKAY, 2 = SLVERR.
            proxy.complete_request(success ? 0 : 2);

            wait(sc_core::SC_ZERO_TIME);
        }
    }
};

#endif