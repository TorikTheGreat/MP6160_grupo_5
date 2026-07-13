# hito_a.py — Harness de-risk de la CARA DE MEMORIA (riesgo #1 del plan P4).
#
# Topología #2 (SystemC dentro de gem5), SIN Linux ni CPU:
#   CfgStimulus (SystemC) --TLM--> accel.cfg      (dispara START, escribe registros)
#   accel.mem  --TLM--> TlmToGem5Bridge32 --gem5--> membus --> SimpleMemory (real de gem5)
#
# Oráculo: precargamos la RGB en memoria de gem5 (PortProxy funcional), corremos, leemos
# el gris de salida y comparamos bit-exact contra el golden BT.709. Verifica que el
# b_transport de DMA del acelerador atraviesa el puente y llega a la memoria de gem5.
#
# Uso:
#   build/ARM/gem5.opt hito_a.py [NUM_PIXELS]
import sys

import m5
from m5.objects import (
    AddrRange,
    CfgStimulus,
    RgbToGrayAccel,
    Root,
    SimpleMemory,
    SrcClockDomain,
    System,
    SystemC_Kernel,
    SystemXBar,
    TlmToGem5Bridge32,
    VoltageDomain,
)

# ---- parámetros del test ----
NUM_PIXELS = int(sys.argv[1]) if len(sys.argv) > 1 else 16
INPUT_ADDR = 0x1000
OUTPUT_ADDR = 0x08000000  # 128 MiB, dentro del rango de memoria (256 MiB)


# ---- imagen de entrada determinista + golden (oráculo) ----
def gen_rgb(n):
    ba = bytearray(3 * n)
    for i in range(n):
        ba[3 * i + 0] = (i * 7) & 0xFF
        ba[3 * i + 1] = (i * 13) & 0xFF
        ba[3 * i + 2] = (i * 29) & 0xFF
    return bytes(ba)


def golden_gray(rgb, n):
    # Debe replicar rgb_to_gray.h: int(0.2126 R + 0.7152 G + 0.0722 B + 0.5)
    out = bytearray(n)
    for i in range(n):
        r, g, b = rgb[3 * i], rgb[3 * i + 1], rgb[3 * i + 2]
        out[i] = int(0.2126 * r + 0.7152 * g + 0.0722 * b + 0.5)
    return bytes(out)


rgb = gen_rgb(NUM_PIXELS)
gold = golden_gray(rgb, NUM_PIXELS)

# ---- sistema gem5 mínimo ----
system = System(
    physmem=SimpleMemory(range=AddrRange("256MiB")),
    membus=SystemXBar(),
    clk_domain=SrcClockDomain(clock="1GHz", voltage_domain=VoltageDomain()),
)
system.mem_mode = "atomic"
system.system_port = system.membus.cpu_side_ports  # habilita physProxy
system.physmem.port = system.membus.mem_side_ports

# acelerador (entregable) + estímulo de control (prueba)
system.accel = RgbToGrayAccel()
system.stim = CfgStimulus(
    input_addr=INPUT_ADDR, output_addr=OUTPUT_ADDR, num_pixels=NUM_PIXELS
)
system.stim.out = system.accel.cfg  # cfg: TLM<->TLM (ambos SystemC)

# cara de memoria: accel.mem -> puente -> membus -> SimpleMemory
system.mem_bridge = TlmToGem5Bridge32()
system.accel.mem = system.mem_bridge.tlm
system.mem_bridge.gem5 = system.membus.cpu_side_ports

# kernel SystemC co-ejecutando dentro de gem5
kernel = SystemC_Kernel(system=system)
root = Root(full_system=False, systemc_kernel=kernel)

m5.instantiate()

# precargar la imagen RGB en la memoria de gem5
port = system.physProxy
port.write(INPUT_ADDR, rgb)

print(f"[hito_a] corriendo con NUM_PIXELS={NUM_PIXELS} "
      f"(RGB={3*NUM_PIXELS} B, gris={NUM_PIXELS} B)")
exit_event = m5.simulate()
print("[hito_a] fin de simulación:", exit_event.getCause())

# leer el resultado del DMA y comparar contra el golden
result = port.read(OUTPUT_ADDR, NUM_PIXELS)
if result == gold:
    print(f"HITO_A_PASS: {NUM_PIXELS} pixeles bit-exact via DMA a memoria de gem5")
    sys.exit(0)
else:
    for i in range(NUM_PIXELS):
        if result[i] != gold[i]:
            print(f"HITO_A_FAIL en pixel {i}: got={result[i]} exp={gold[i]}")
            break
    sys.exit(1)
