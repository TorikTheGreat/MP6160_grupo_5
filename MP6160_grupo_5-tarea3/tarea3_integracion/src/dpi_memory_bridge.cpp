#include "../include/dpi_memory_bridge.h"

#include <cstdint>
#include <iomanip>
#include <iostream>
#include <unordered_map>

static std::unordered_map<uint32_t, uint32_t> memory;

extern "C" void dpi_write(uint32_t addr, uint32_t data)
{
    memory[addr] = data;

    std::cout
        << "[C++ MEMORY] WRITE direccion=0x"
        << std::hex << std::setw(8) << std::setfill('0') << addr
        << " dato=0x"
        << std::setw(8) << data
        << std::dec
        << std::endl;
}

extern "C" uint32_t dpi_read(uint32_t addr)
{
    const auto posicion = memory.find(addr);

    uint32_t valor = 0;

    if (posicion != memory.end()) {
        valor = posicion->second;
    }

    std::cout
        << "[C++ MEMORY] READ  direccion=0x"
        << std::hex << std::setw(8) << std::setfill('0') << addr
        << " dato=0x"
        << std::setw(8) << valor
        << std::dec
        << std::endl;

    return valor;
}