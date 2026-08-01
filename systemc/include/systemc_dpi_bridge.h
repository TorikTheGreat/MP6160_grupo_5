#ifndef SYSTEMC_DPI_BRIDGE_H
#define SYSTEMC_DPI_BRIDGE_H

struct RamRtlProxy;

// Registra la instancia del proxy que será utilizada por las funciones DPI.
void systemc_dpi_bind_proxy(RamRtlProxy* proxy);

// Elimina la referencia antes de destruir el sistema SystemC.
void systemc_dpi_unbind_proxy();

#endif