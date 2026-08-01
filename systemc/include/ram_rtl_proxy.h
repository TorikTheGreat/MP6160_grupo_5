#ifndef RAM_RTL_PROXY_H
#define RAM_RTL_PROXY_H

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>

struct RamRtlProxy : sc_core::sc_module {
    static constexpr std::size_t MAX_DPI_BYTES = 4096;

    // Se conservan los mismos sockets de la RAM SystemC original.
    tlm_utils::simple_target_socket<RamRtlProxy> socket_cpu;
    tlm_utils::simple_target_socket<RamRtlProxy> socket_acc;

    enum class RequestState {
        IDLE,
        PENDING,
        ACTIVE,
        COMPLETED
    };

    struct Request {
        std::uint64_t address = 0;
        std::uint32_t length = 0;
        bool is_write = false;

        std::array<std::uint8_t, MAX_DPI_BYTES> data{};

        int axi_response = 0;
        RequestState state = RequestState::IDLE;
    };

    SC_HAS_PROCESS(RamRtlProxy);

    explicit RamRtlProxy(sc_core::sc_module_name name);

    void b_transport(
        tlm::tlm_generic_payload& trans,
        sc_core::sc_time& delay
    );

    // Métodos utilizados posteriormente por las funciones DPI.
    bool poll_request(
        std::uint64_t& address,
        std::uint32_t& length,
        bool& is_write
    );

    bool fetch_data(
        std::uint8_t* destination,
        std::size_t capacity
    );

    bool store_data(
        const std::uint8_t* source,
        std::size_t length
    );

    void complete_request(int axi_response);

    bool has_pending_request() const;

private:
    Request request_;

    sc_core::sc_event request_completed_event_;

    mutable std::mutex request_mutex_;

    bool process_chunk(
        tlm::tlm_command command,
        std::uint64_t address,
        std::uint8_t* data,
        std::uint32_t length
    );

    void set_tlm_error(
        tlm::tlm_generic_payload& trans,
        const char* message
    );
};

#endif