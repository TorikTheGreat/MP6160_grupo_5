#include "systemc_dpi_bridge.h"
#include "ram_rtl_proxy.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <mutex>

#ifdef SYSTEMC_DPI_XSIM
#include <svdpi.h>
#endif

namespace {

constexpr std::size_t DPI_BUFFER_SIZE =
    RamRtlProxy::MAX_DPI_BYTES;

RamRtlProxy* g_proxy = nullptr;

std::mutex g_bridge_mutex;

// Información de la solicitud tomada mediante dpi_poll_request().
bool g_request_active = false;
std::uint64_t g_active_address = 0;
std::uint32_t g_active_length = 0;
bool g_active_is_write = false;

RamRtlProxy* get_proxy() {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);
    return g_proxy;
}

void report_bridge_error(const char* message) {
    std::cerr
        << "SYSTEMC_DPI_BRIDGE ERROR: "
        << message
        << std::endl;
}

bool validate_active_request(
    long long address,
    int length,
    bool expected_write
) {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);

    if (!g_request_active) {
        report_bridge_error(
            "No existe una solicitud DPI activa"
        );
        return false;
    }

    if (length <= 0 ||
        length > static_cast<int>(DPI_BUFFER_SIZE)) {

        report_bridge_error(
            "Longitud DPI fuera del rango permitido"
        );
        return false;
    }

    if (static_cast<std::uint64_t>(address) !=
        g_active_address) {

        report_bridge_error(
            "La dirección no coincide con la solicitud activa"
        );
        return false;
    }

    if (static_cast<std::uint32_t>(length) !=
        g_active_length) {

        report_bridge_error(
            "La longitud no coincide con la solicitud activa"
        );
        return false;
    }

    if (g_active_is_write != expected_write) {
        report_bridge_error(
            "El tipo de transferencia DPI no coincide"
        );
        return false;
    }

    return true;
}

void clear_active_request() {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);

    g_request_active = false;
    g_active_address = 0;
    g_active_length = 0;
    g_active_is_write = false;
}

#ifdef SYSTEMC_DPI_XSIM

bool copy_to_systemverilog_array(
    const svOpenArrayHandle handle,
    const std::uint8_t* source,
    std::size_t length
) {
    if (handle == nullptr || source == nullptr) {
        return false;
    }

    const int low = svLow(handle, 1);
    const int high = svHigh(handle, 1);
    const int increment = high >= low ? 1 : -1;

    const std::size_t array_size =
        static_cast<std::size_t>(
            high >= low
                ? high - low + 1
                : low - high + 1
        );

    if (array_size < length) {
        return false;
    }

    for (std::size_t index = 0;
         index < length;
         ++index) {

        const int sv_index =
            low + static_cast<int>(index) * increment;

        auto* destination =
            static_cast<unsigned char*>(
                svGetArrElemPtr1(handle, sv_index)
            );

        if (destination == nullptr) {
            return false;
        }

        *destination = source[index];
    }

    return true;
}

bool copy_from_systemverilog_array(
    const svOpenArrayHandle handle,
    std::uint8_t* destination,
    std::size_t length
) {
    if (handle == nullptr || destination == nullptr) {
        return false;
    }

    const int low = svLow(handle, 1);
    const int high = svHigh(handle, 1);
    const int increment = high >= low ? 1 : -1;

    const std::size_t array_size =
        static_cast<std::size_t>(
            high >= low
                ? high - low + 1
                : low - high + 1
        );

    if (array_size < length) {
        return false;
    }

    for (std::size_t index = 0;
         index < length;
         ++index) {

        const int sv_index =
            low + static_cast<int>(index) * increment;

        const auto* source =
            static_cast<const unsigned char*>(
                svGetArrElemPtr1(handle, sv_index)
            );

        if (source == nullptr) {
            return false;
        }

        destination[index] = *source;
    }

    return true;
}

#endif

}  // namespace

void systemc_dpi_bind_proxy(RamRtlProxy* proxy) {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);

    g_proxy = proxy;

    g_request_active = false;
    g_active_address = 0;
    g_active_length = 0;
    g_active_is_write = false;

    std::cout
        << "SystemC DPI bridge: proxy registrado"
        << std::endl;
}

void systemc_dpi_unbind_proxy() {
    std::lock_guard<std::mutex> lock(g_bridge_mutex);

    g_proxy = nullptr;

    g_request_active = false;
    g_active_address = 0;
    g_active_length = 0;
    g_active_is_write = false;

    std::cout
        << "SystemC DPI bridge: proxy liberado"
        << std::endl;
}

// =====================================================================
// Consulta si SystemC tiene una transferencia pendiente.
//
// Retorno:
//   1 = existe una solicitud.
//   0 = no existe una solicitud o el proxy no está registrado.
// =====================================================================

extern "C" int dpi_poll_request(
    long long* address,
    int* length,
    int* is_write
) {
    if (address == nullptr ||
        length == nullptr ||
        is_write == nullptr) {

        report_bridge_error(
            "dpi_poll_request recibió un puntero nulo"
        );
        return 0;
    }

    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr) {
        return 0;
    }

    {
        std::lock_guard<std::mutex> lock(g_bridge_mutex);

        // No se publica otra solicitud hasta completar la actual.
        if (g_request_active) {
            return 0;
        }
    }

    std::uint64_t request_address = 0;
    std::uint32_t request_length = 0;
    bool request_is_write = false;

    if (!proxy->poll_request(
            request_address,
            request_length,
            request_is_write)) {

        return 0;
    }

    {
        std::lock_guard<std::mutex> lock(g_bridge_mutex);

        g_request_active = true;
        g_active_address = request_address;
        g_active_length = request_length;
        g_active_is_write = request_is_write;
    }

    *address =
        static_cast<long long>(request_address);

    *length =
        static_cast<int>(request_length);

    *is_write =
        request_is_write ? 1 : 0;

    return 1;
}

#ifdef SYSTEMC_DPI_XSIM

// =====================================================================
// SystemC desea escribir en la RAM RTL.
// SystemVerilog obtiene desde el proxy los bytes que enviará por AXI.
// =====================================================================

extern "C" void dpi_fetch(
    long long address,
    int length,
    const svOpenArrayHandle data
) {
    if (!validate_active_request(
            address,
            length,
            true)) {

        return;
    }

    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr) {
        report_bridge_error(
            "dpi_fetch: proxy no registrado"
        );
        return;
    }

    std::array<std::uint8_t, DPI_BUFFER_SIZE> buffer{};

    if (!proxy->fetch_data(
            buffer.data(),
            buffer.size())) {

        report_bridge_error(
            "dpi_fetch no pudo obtener los datos del proxy"
        );
        return;
    }

    if (!copy_to_systemverilog_array(
            data,
            buffer.data(),
            static_cast<std::size_t>(length))) {

        report_bridge_error(
            "dpi_fetch no pudo copiar el arreglo hacia SystemVerilog"
        );
    }
}

// =====================================================================
// SystemC desea leer desde la RAM RTL.
// SystemVerilog entrega al proxy los bytes recibidos por AXI.
// =====================================================================

extern "C" void dpi_store(
    long long address,
    int length,
    const svOpenArrayHandle data
) {
    if (!validate_active_request(
            address,
            length,
            false)) {

        return;
    }

    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr) {
        report_bridge_error(
            "dpi_store: proxy no registrado"
        );
        return;
    }

    std::array<std::uint8_t, DPI_BUFFER_SIZE> buffer{};

    if (!copy_from_systemverilog_array(
            data,
            buffer.data(),
            static_cast<std::size_t>(length))) {

        report_bridge_error(
            "dpi_store no pudo copiar el arreglo desde SystemVerilog"
        );
        return;
    }

    if (!proxy->store_data(
            buffer.data(),
            static_cast<std::size_t>(length))) {

        report_bridge_error(
            "dpi_store no pudo almacenar los datos en el proxy"
        );
    }
}

#else

// Versiones portables para las pruebas realizadas solamente en C++.
// Durante la compilación con XSim se utiliza SYSTEMC_DPI_XSIM.

extern "C" void dpi_fetch(
    long long address,
    int length,
    unsigned char* data
) {
    if (data == nullptr ||
        !validate_active_request(
            address,
            length,
            true)) {

        return;
    }

    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr ||
        !proxy->fetch_data(
            data,
            static_cast<std::size_t>(length))) {

        report_bridge_error(
            "dpi_fetch portable falló"
        );
    }
}

extern "C" void dpi_store(
    long long address,
    int length,
    const unsigned char* data
) {
    if (data == nullptr ||
        !validate_active_request(
            address,
            length,
            false)) {

        return;
    }

    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr ||
        !proxy->store_data(
            data,
            static_cast<std::size_t>(length))) {

        report_bridge_error(
            "dpi_store portable falló"
        );
    }
}

#endif

// =====================================================================
// Finaliza la transferencia y propaga la respuesta AXI hacia SystemC.
//
// axi_response:
//   0 = OKAY.
//   2 = SLVERR.
// =====================================================================

extern "C" void dpi_complete(int axi_response) {
    RamRtlProxy* proxy = get_proxy();

    if (proxy == nullptr) {
        report_bridge_error(
            "dpi_complete: proxy no registrado"
        );
        return;
    }

    {
        std::lock_guard<std::mutex> lock(g_bridge_mutex);

        if (!g_request_active) {
            report_bridge_error(
                "dpi_complete sin una solicitud activa"
            );
            return;
        }
    }

    proxy->complete_request(axi_response);

    clear_active_request();
}