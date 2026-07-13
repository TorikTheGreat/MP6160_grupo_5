# RgbToGrayAccel.py — SimObject que expone el sc_module como un objeto de gem5.
# Declara los dos puertos TLM (cfg/mem). Ancho = 32: debe coincidir con los sockets
# del acelerador (simple_target/initiator_socket = 32 por default) y con sus wrappers.
from m5.objects.SystemC import SystemC_ScModule
from m5.objects.Tlm import (
    TlmInitiatorSocket,
    TlmTargetSocket,
)
from m5.params import *
from m5.proxy import *


class RgbToGrayAccel(SystemC_ScModule):
    type = "RgbToGrayAccel"
    cxx_class = "RgbToGrayAccel"          # clase C++ (global namespace), igual que el ejemplo
    cxx_header = "sc_rgb2gray.hh"
    # cfg = control por MMIO (la CPU escribe START/direcciones/#pixeles) -> se conecta a Gem5ToTlmBridge32
    cfg = TlmTargetSocket(32, "registros de control (MMIO desde el ARM64)")
    # mem = DMA del acelerador hacia la RAM de gem5 -> se conecta a TlmToGem5Bridge32
    mem = TlmInitiatorSocket(32, "DMA a la memoria de gem5")
    # Tamaño máximo por transacción TLM del DMA. 64 = línea de caché (si el DMA va por el iocache
    # coherente, que no acepta transacciones que la crucen). 0 = una sola transacción (válido solo
    # si el DMA NO pasa por una caché, p.ej. conectado directo al membus — mucho más eficiente).
    dma_chunk = Param.Unsigned(64, "bytes máx por transacción DMA (0 = sin trocear)")
    system = Param.System(Parent.any, "system")
