# dma_timing_test.py — Mide el costo del DMA del acelerador SIN bootear Linux.
#
# Usa el ArmBoard real (caches + iocache coherente + DRAM), pero dispara el DMA desde un
# CfgStimulus SystemC en t≈0 (como el harness). Sirve para estimar cuánto tarda la conversión
# de una imagen (N píxeles → N*3 bytes leídos + N escritos, troceado a 64 B) en tiempo de reloj,
# sin pagar el ~1.5 h de boot.  Uso:  NPIX=2073600 build/ARM/gem5.opt dma_timing_test.py
import os
import time

from m5.objects import (
    ArmDefaultRelease,
    CfgStimulus,
    RgbToGrayAccel,
    SystemC_Kernel,
    TlmToGem5Bridge32,
    VExpress_GEM5_Foundation,
)

from gem5.components.boards.arm_board import ArmBoard
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory import DualChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.isas import ISA
from gem5.resources.resource import (
    BootloaderResource,
    DiskImageResource,
    KernelResource,
)
from gem5.simulate.simulator import Simulator

NPIX = int(os.environ.get("NPIX", "256"))
IN_ADDR = 0xA0000000   # en la DRAM del board; datos sin precargar (solo medimos el path/costo)
OUT_ADDR = 0xB0000000

board = ArmBoard(
    clk_freq="3GHz",
    processor=SimpleProcessor(cpu_type=CPUTypes.ATOMIC, num_cores=1, isa=ISA.ARM),
    memory=DualChannelDDR4_2400(size="2GiB"),
    cache_hierarchy=PrivateL1PrivateL2CacheHierarchy(
        l1d_size="16KiB", l1i_size="16KiB", l2_size="256KiB"
    ),
    release=ArmDefaultRelease(),
    platform=VExpress_GEM5_Foundation(),
)
_CACHE = "/home/marco/.cache/gem5"
board.set_kernel_disk_workload(
    kernel=KernelResource(local_path=f"{_CACHE}/arm64-linux-kernel-6.8.12-1.0.0"),
    disk_image=DiskImageResource(
        local_path=f"{_CACHE}/arm-ubuntu-24.04-img-3.0.0", root_partition="2"
    ),
    bootloader=BootloaderResource(
        local_path=f"{_CACHE}/arm64-bootloader-foundation-2.0.0"
    ),
)

board.accel = RgbToGrayAccel()  # dma_chunk = 64
board.stim = CfgStimulus(input_addr=IN_ADDR, output_addr=OUT_ADDR, num_pixels=NPIX)
board.stim.out = board.accel.cfg
board.mem_bridge = TlmToGem5Bridge32()
board.accel.mem = board.mem_bridge.tlm
board.mem_bridge.gem5 = board.iobus.cpu_side_ports  # ruta coherente real (iocache, 64 B)
board.sc_kernel = SystemC_Kernel()

print(f"[dma_timing] NPIX={NPIX}  (lee {NPIX*3} B + escribe {NPIX} B, troceado a 64 B "
      f"≈ {(NPIX*3)//64 + NPIX//64} transacciones)")
sim = Simulator(board=board)
_t0 = time.time()
sim.run(max_ticks=10_000_000_000)  # 10 ms sim: suficiente para que el DMA SystemC complete
print(f"[dma_timing] tiempo de RELOJ de la corrida: {time.time() - _t0:.1f} s")
