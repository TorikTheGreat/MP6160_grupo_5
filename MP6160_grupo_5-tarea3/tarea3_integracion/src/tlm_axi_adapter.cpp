#include "../include/tlm_axi_adapter.h"

#include <algorithm>
#include <iostream>

#include "svdpi.h"

extern "C" {
int sv_axi_request_write(unsigned int address, unsigned int data);
int sv_axi_request_read(unsigned int address);
int sv_axi_get_state();
int sv_axi_get_status();
unsigned int sv_axi_get_read_data();
int sv_axi_acknowledge();
}

namespace {
constexpr int AXI_SERVER_IDLE = 0;
constexpr int AXI_SERVER_BUSY = 1;
constexpr int AXI_SERVER_DONE = 2;
}

TlmAxiAdapter::TlmAxiAdapter(const std::string& dpi_scope)
    : dpi_scope_(dpi_scope),
      operation_type_(OperationType::None),
      pending_(false),
      completed_(false),
      success_(false),
      read_data_(0)
{
}

bool TlmAxiAdapter::select_dpi_scope() const
{
    svScope scope = svGetScopeFromName(dpi_scope_.c_str());

    if (scope == nullptr) {
        std::string alternative = "/" + dpi_scope_;
        std::replace(alternative.begin(), alternative.end(), '.', '/');
        scope = svGetScopeFromName(alternative.c_str());
    }

    if (scope == nullptr) {
        std::cerr << "[TLM ADAPTER] ERROR: no se encontro el scope DPI: "
                  << dpi_scope_ << std::endl;
        return false;
    }

    svSetScope(scope);
    return true;
}

bool TlmAxiAdapter::begin_write_word(
    std::uint32_t address,
    std::uint32_t data
)
{
    if (pending_ || completed_) {
        return false;
    }

    if (!select_dpi_scope()) {
        return false;
    }

    if (sv_axi_request_write(address, data) != 0) {
        return false;
    }

    operation_type_ = OperationType::Write;
    pending_ = true;
    completed_ = false;
    success_ = false;
    read_data_ = 0;
    return true;
}

bool TlmAxiAdapter::begin_read_word(std::uint32_t address)
{
    if (pending_ || completed_) {
        return false;
    }

    if (!select_dpi_scope()) {
        return false;
    }

    if (sv_axi_request_read(address) != 0) {
        return false;
    }

    operation_type_ = OperationType::Read;
    pending_ = true;
    completed_ = false;
    success_ = false;
    read_data_ = 0;
    return true;
}

void TlmAxiAdapter::service()
{
    if (!pending_) {
        return;
    }

    if (!select_dpi_scope()) {
        pending_ = false;
        completed_ = true;
        success_ = false;
        return;
    }

    const int state = sv_axi_get_state();

    if (state == AXI_SERVER_BUSY) {
        return;
    }

    if (state != AXI_SERVER_DONE) {
        std::cerr << "[TLM ADAPTER] ERROR: estado AXI inesperado: "
                  << state << std::endl;
        pending_ = false;
        completed_ = true;
        success_ = false;
        return;
    }

    const int status = sv_axi_get_status();

    if (operation_type_ == OperationType::Read) {
        read_data_ = static_cast<std::uint32_t>(sv_axi_get_read_data());
    }

    const int acknowledge = sv_axi_acknowledge();

    success_ = (status == 0 && acknowledge == 0);
    pending_ = false;
    completed_ = true;
}

bool TlmAxiAdapter::busy() const
{
    return pending_;
}

bool TlmAxiAdapter::completed() const
{
    return completed_;
}

bool TlmAxiAdapter::succeeded() const
{
    return completed_ && success_;
}

bool TlmAxiAdapter::is_read_result() const
{
    return operation_type_ == OperationType::Read;
}

std::uint32_t TlmAxiAdapter::read_data() const
{
    return read_data_;
}

void TlmAxiAdapter::clear_completion()
{
    if (pending_) {
        return;
    }

    operation_type_ = OperationType::None;
    completed_ = false;
    success_ = false;
    read_data_ = 0;
}
