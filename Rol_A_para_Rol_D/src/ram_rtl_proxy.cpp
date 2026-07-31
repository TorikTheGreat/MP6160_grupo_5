#include "ram_rtl_proxy.h"

#include <algorithm>
#include <cstring>
#include <iostream>

using namespace sc_core;

RamRtlProxy::RamRtlProxy(sc_module_name name)
    : sc_module(name),
      socket_cpu("socket_cpu"),
      socket_acc("socket_acc") {

    socket_cpu.register_b_transport(
        this,
        &RamRtlProxy::b_transport
    );

    socket_acc.register_b_transport(
        this,
        &RamRtlProxy::b_transport
    );

    std::cout
        << "RamRtlProxy: " << this->name()
        << " creado"
        << std::endl;
}

void RamRtlProxy::set_tlm_error(
    tlm::tlm_generic_payload& trans,
    const char* message
) {
    SC_REPORT_ERROR("RAM_RTL_PROXY", message);
    trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
}

void RamRtlProxy::b_transport(
    tlm::tlm_generic_payload& trans,
    sc_time& delay
) {
    const tlm::tlm_command command = trans.get_command();
    std::uint64_t address = trans.get_address();
    std::uint8_t* data = trans.get_data_ptr();
    std::size_t remaining = trans.get_data_length();

    if (command != tlm::TLM_READ_COMMAND &&
        command != tlm::TLM_WRITE_COMMAND) {

        set_tlm_error(trans, "Comando TLM no soportado");
        return;
    }

    if (data == nullptr) {
        set_tlm_error(trans, "Puntero de datos nulo");
        return;
    }

    if (remaining == 0) {
        set_tlm_error(trans, "Transferencia de longitud cero");
        return;
    }

    if (trans.get_byte_enable_ptr() != nullptr) {
        set_tlm_error(trans, "Byte enables TLM no soportados");
        return;
    }

    if (trans.get_streaming_width() < remaining) {
        set_tlm_error(trans, "Streaming width no soportado");
        return;
    }

    while (remaining > 0) {
        const std::size_t bytes_to_boundary =
            MAX_DPI_BYTES -
            static_cast<std::size_t>(
                address & (MAX_DPI_BYTES - 1)
            );

        const std::size_t chunk_size = std::min(
            remaining,
            bytes_to_boundary
        );

        if (!process_chunk(
                command,
                address,
                data,
                static_cast<std::uint32_t>(chunk_size))) {

            trans.set_response_status(
                tlm::TLM_GENERIC_ERROR_RESPONSE
            );

            delay = SC_ZERO_TIME;
            return;
        }

        address += chunk_size;
        data += chunk_size;
        remaining -= chunk_size;
    }

    trans.set_response_status(tlm::TLM_OK_RESPONSE);

    // El tiempo de AXI se consume mientras el proxy espera la respuesta.
    delay = SC_ZERO_TIME;
}

bool RamRtlProxy::process_chunk(
    tlm::tlm_command command,
    std::uint64_t address,
    std::uint8_t* data,
    std::uint32_t length
) {
    {
        std::lock_guard<std::mutex> lock(request_mutex_);

        if (request_.state != RequestState::IDLE) {
            SC_REPORT_ERROR(
                "RAM_RTL_PROXY",
                "Se intentó publicar una solicitud mientras otra estaba activa"
            );
            return false;
        }

        request_.address = address;
        request_.length = length;
        request_.is_write =
            command == tlm::TLM_WRITE_COMMAND;

        request_.axi_response = 0;

        if (request_.is_write) {
            std::copy_n(
                data,
                length,
                request_.data.begin()
            );
        } else {
            std::fill(
                request_.data.begin(),
                request_.data.end(),
                0
            );
        }

        request_.state = RequestState::PENDING;
    }

    // Será despertado por complete_request().
    wait(request_completed_event_);

    int response = 0;

    {
        std::lock_guard<std::mutex> lock(request_mutex_);

        response = request_.axi_response;

        if (!request_.is_write && response == 0) {
            std::copy_n(
                request_.data.begin(),
                request_.length,
                data
            );
        }

        request_.state = RequestState::IDLE;
    }

    return response == 0;
}

bool RamRtlProxy::poll_request(
    std::uint64_t& address,
    std::uint32_t& length,
    bool& is_write
) {
    std::lock_guard<std::mutex> lock(request_mutex_);

    if (request_.state != RequestState::PENDING) {
        return false;
    }

    address = request_.address;
    length = request_.length;
    is_write = request_.is_write;

    request_.state = RequestState::ACTIVE;

    return true;
}

bool RamRtlProxy::fetch_data(
    std::uint8_t* destination,
    std::size_t capacity
) {
    std::lock_guard<std::mutex> lock(request_mutex_);

    if (destination == nullptr ||
        request_.state != RequestState::ACTIVE ||
        !request_.is_write ||
        capacity < request_.length) {

        return false;
    }

    std::copy_n(
        request_.data.begin(),
        request_.length,
        destination
    );

    return true;
}

bool RamRtlProxy::store_data(
    const std::uint8_t* source,
    std::size_t length
) {
    std::lock_guard<std::mutex> lock(request_mutex_);

    if (source == nullptr ||
        request_.state != RequestState::ACTIVE ||
        request_.is_write ||
        length != request_.length) {

        return false;
    }

    std::copy_n(
        source,
        length,
        request_.data.begin()
    );

    return true;
}

void RamRtlProxy::complete_request(int axi_response) {
    {
        std::lock_guard<std::mutex> lock(request_mutex_);

        if (request_.state != RequestState::ACTIVE) {
            SC_REPORT_ERROR(
                "RAM_RTL_PROXY",
                "Se recibió complete_request sin una solicitud activa"
            );
            return;
        }

        request_.axi_response = axi_response;
        request_.state = RequestState::COMPLETED;
    }

    request_completed_event_.notify(SC_ZERO_TIME);
}

bool RamRtlProxy::has_pending_request() const {
    std::lock_guard<std::mutex> lock(request_mutex_);

    return request_.state == RequestState::PENDING;
}