#ifndef DPI_MEMORY_BRIDGE_H
#define DPI_MEMORY_BRIDGE_H

#include <stdint.h>

extern "C" {

void dpi_write(uint32_t addr, uint32_t data);

uint32_t dpi_read(uint32_t addr);

}

#endif