// sc_rgb2gray.cc — La "cola" que une el config Python con el sc_module C++.
#include "sc_rgb2gray.hh"

#include "params/RgbToGrayAccel.hh"   // header auto-generado por gem5 desde RgbToGrayAccel.py

// Fábrica del SimObject: gem5 llama esto para instanciar nuestro sc_module desde el config Python.
RgbToGrayAccel *
gem5::RgbToGrayAccelParams::create() const
{
    return new RgbToGrayAccel(name.c_str(), dma_chunk);
}

// gem5 pide un puerto por nombre al conectar; devolvemos el wrapper correspondiente.
// Los nombres deben coincidir con los sockets declarados en RgbToGrayAccel.py ("cfg", "mem").
gem5::Port &
RgbToGrayAccel::gem5_getPort(const std::string &if_name, int idx)
{
    if (if_name == "cfg")
        return cfgWrapper;
    if (if_name == "mem")
        return memWrapper;
    return sc_core::sc_module::gem5_getPort(if_name, idx);
}
