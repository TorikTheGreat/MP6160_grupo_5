// cfg_stimulus.cc — glue del SimObject de prueba CfgStimulus.
#include "cfg_stimulus.hh"

#include "params/CfgStimulus.hh"   // auto-generado por gem5 desde CfgStimulus.py

// Fábrica: gem5 la llama para instanciar el estímulo desde el config Python.
CfgStimulus *
gem5::CfgStimulusParams::create() const
{
    return new CfgStimulus(name.c_str(), input_addr, output_addr, num_pixels);
}

// gem5 pide el puerto por nombre al conectar (debe coincidir con CfgStimulus.py: "out").
gem5::Port &
CfgStimulus::gem5_getPort(const std::string &if_name, int idx)
{
    if (if_name == "out")
        return outWrapper;
    return sc_core::sc_module::gem5_getPort(if_name, idx);
}
