#include "svdpi.h"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <vector>

namespace {

constexpr int kOkay = 0;
constexpr int kSlverr = 2;
constexpr int kMaxBytes = 4096;

struct Request {
    std::uint64_t address = 0;
    int length = 0;
    bool is_write = false;
    std::array<std::uint8_t, kMaxBytes> payload{};
};

std::vector<std::uint8_t> g_memory;
std::vector<Request> g_requests;
std::size_t g_req_idx = 0;
bool g_req_active = false;
bool g_created = false;
bool g_passed = true;
int g_services = 0;

bool copy_to_sv_array(const svOpenArrayHandle h, const std::uint8_t* src, int n) {
    if (h == nullptr || src == nullptr || n < 0) {
        return false;
    }
    const int low = svLow(h, 1);
    const int high = svHigh(h, 1);
    const int step = (high >= low) ? 1 : -1;
    const int size = (high >= low) ? (high - low + 1) : (low - high + 1);
    if (size < n) {
        return false;
    }
    for (int i = 0; i < n; ++i) {
        unsigned char* dst = static_cast<unsigned char*>(svGetArrElemPtr1(h, low + i * step));
        if (dst == nullptr) {
            return false;
        }
        *dst = src[i];
    }
    return true;
}

bool copy_from_sv_array(const svOpenArrayHandle h, std::uint8_t* dst, int n) {
    if (h == nullptr || dst == nullptr || n < 0) {
        return false;
    }
    const int low = svLow(h, 1);
    const int high = svHigh(h, 1);
    const int step = (high >= low) ? 1 : -1;
    const int size = (high >= low) ? (high - low + 1) : (low - high + 1);
    if (size < n) {
        return false;
    }
    for (int i = 0; i < n; ++i) {
        const unsigned char* src = static_cast<const unsigned char*>(svGetArrElemPtr1(h, low + i * step));
        if (src == nullptr) {
            return false;
        }
        dst[i] = *src;
    }
    return true;
}

void build_requests() {
    g_requests.clear();
    g_req_idx = 0;
    g_req_active = false;
    g_passed = true;
    g_services = 0;

    // Solicitud 1: escritura de 4096 B alineada a 4 KB.
    Request wr;
    wr.address = 0x00001000ull;
    wr.length = 4096;
    wr.is_write = true;
    for (int i = 0; i < wr.length; ++i) {
        wr.payload[static_cast<std::size_t>(i)] = static_cast<std::uint8_t>((i * 7 + 3) & 0xFF);
    }
    g_requests.push_back(wr);

    // Solicitud 2: lectura del mismo bloque (debe devolver exactamente lo escrito).
    Request rd;
    rd.address = wr.address;
    rd.length = wr.length;
    rd.is_write = false;
    rd.payload = wr.payload;
    g_requests.push_back(rd);
}

}  // namespace

extern "C" int systemc_create() {
    g_memory.assign(1u << 20, 0);
    build_requests();
    g_created = true;
    std::cout << "[VL-STUB] systemc_create OK" << std::endl;
    return 1;
}

extern "C" int systemc_service() {
    if (!g_created) {
        return 0;
    }
    ++g_services;
    return 1;
}

extern "C" int systemc_is_finished() {
    if (!g_created) {
        return 0;
    }
    return (g_req_idx >= g_requests.size()) ? 1 : 0;
}

extern "C" int systemc_passed() {
    return g_passed ? 1 : 0;
}

extern "C" void systemc_destroy() {
    std::cout << "[VL-STUB] systemc_destroy services=" << g_services
              << " requests=" << g_requests.size()
              << " result=" << (g_passed ? "PASS" : "FAIL")
              << std::endl;
    g_created = false;
}

extern "C" int dpi_poll_request(long long* address, int* length, int* is_write) {
    if (!g_created || address == nullptr || length == nullptr || is_write == nullptr) {
        return 0;
    }
    if (g_req_active || g_req_idx >= g_requests.size()) {
        return 0;
    }

    const Request& r = g_requests[g_req_idx];
    *address = static_cast<long long>(r.address);
    *length = r.length;
    *is_write = r.is_write ? 1 : 0;
    g_req_active = true;
    return 1;
}

extern "C" void dpi_fetch(long long address, int length, const svOpenArrayHandle data) {
    if (!g_req_active || g_req_idx >= g_requests.size()) {
        g_passed = false;
        return;
    }
    const Request& r = g_requests[g_req_idx];
    if (!r.is_write || static_cast<std::uint64_t>(address) != r.address || length != r.length) {
        g_passed = false;
        return;
    }
    if (!copy_to_sv_array(data, r.payload.data(), r.length)) {
        g_passed = false;
    }
}

extern "C" void dpi_store(long long address, int length, const svOpenArrayHandle data) {
    if (!g_req_active || g_req_idx >= g_requests.size()) {
        g_passed = false;
        return;
    }
    const Request& r = g_requests[g_req_idx];
    if (r.is_write || static_cast<std::uint64_t>(address) != r.address || length != r.length) {
        g_passed = false;
        return;
    }

    std::array<std::uint8_t, kMaxBytes> recv{};
    if (!copy_from_sv_array(data, recv.data(), length)) {
        g_passed = false;
        return;
    }
    if (!std::equal(recv.begin(), recv.begin() + length, r.payload.begin())) {
        g_passed = false;
    }
}

extern "C" void dpi_complete(int axi_response) {
    if (!g_req_active || g_req_idx >= g_requests.size()) {
        g_passed = false;
        return;
    }

    const Request& r = g_requests[g_req_idx];
    if (axi_response != kOkay) {
        g_passed = false;
    }

    if (r.is_write && g_passed) {
        if (r.address + static_cast<std::uint64_t>(r.length) > g_memory.size()) {
            g_passed = false;
        } else {
            std::memcpy(
                g_memory.data() + static_cast<std::size_t>(r.address),
                r.payload.data(),
                static_cast<std::size_t>(r.length)
            );
        }
    }

    g_req_active = false;
    ++g_req_idx;
}
