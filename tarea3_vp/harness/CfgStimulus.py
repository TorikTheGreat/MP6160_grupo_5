# CfgStimulus.py — SimObject de PRUEBA (Hito A). Estimula la cara de control del acelerador.
# Ancho 32: coincide con accel.cfg (target de 32 bits). No forma parte del entregable.
from m5.objects.SystemC import SystemC_ScModule
from m5.objects.Tlm import TlmInitiatorSocket
from m5.params import *
from m5.proxy import *


class CfgStimulus(SystemC_ScModule):
    type = "CfgStimulus"
    cxx_class = "CfgStimulus"
    cxx_header = "cfg_stimulus.hh"

    # Socket initiator TLM -> se conecta a accel.cfg (TLM<->TLM, ambos SystemC)
    out = TlmInitiatorSocket(32, "hacia los registros de control del acelerador")

    # Direcciones (en el espacio físico de gem5) y numero de pixeles a procesar.
    input_addr = Param.UInt32(0x1000, "direccion de la imagen RGB de entrada")
    output_addr = Param.UInt32(0x08000000, "direccion de la imagen gris de salida")
    num_pixels = Param.UInt32(16, "numero de pixeles a convertir")

    system = Param.System(Parent.any, "system")
