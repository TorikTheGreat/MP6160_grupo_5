# vp_run.py — Config full-system del VP: ArmBoard (Ubuntu 24.04 ARM64) + acelerador RGB→gris.
#
# Extiende el arm-ubuntu-run.py stock de gem5 adjuntando el periférico por DOS puentes
# (topología #2, ver README/TRASPASO):
#   - cfg  -> Gem5ToTlmBridge32 @ ACC_BASE, como device en el iobus del board.
#   - mem  -> TlmToGem5Bridge32, como DMA master en el iobus -> iocache -> membus (COHERENTE).
#   - SystemC_Kernel() suelto en el árbol (patrón DRAMSys) para co-ejecutar el módulo.
#
# Requiere gem5 compilado con EXTRAS=<...>/vp_accel (registra RgbToGrayAccel).
# Uso:  build/ARM/gem5.opt vp_run.py
from m5.objects import (
    AddrRange,
    ArmDefaultRelease,
    Gem5ToTlmBridge32,
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
from gem5.resources.resource import obtain_resource
from gem5.simulate.exit_handler import (
    ExitHandler,
    KernelBootedExitHandler,
)
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides

# Dirección base de los registros del acelerador (igual que accelerator.h).
# 0x1003_0000: región gem5-specific peripherals (CS5), libre en VExpress_GEM5_Foundation.
# (0x4000_0000 chocaba con la ventana PCI del board.)
ACC_BASE = 0x10030000

# --- board estándar (con caches: nos dan el iocache = ruta coherente para el DMA) ---
cache_hierarchy = PrivateL1PrivateL2CacheHierarchy(
    l1d_size="16KiB", l1i_size="16KiB", l2_size="256KiB"
)
memory = DualChannelDDR4_2400(size="2GiB")
processor = SimpleProcessor(cpu_type=CPUTypes.TIMING, num_cores=2, isa=ISA.ARM)
release = ArmDefaultRelease()
platform = VExpress_GEM5_Foundation()

board = ArmBoard(
    clk_freq="3GHz",
    processor=processor,
    memory=memory,
    cache_hierarchy=cache_hierarchy,
    release=release,
    platform=platform,
)

workload = obtain_resource(
    "arm-ubuntu-24.04-boot-with-systemd", resource_version="3.0.0"
)
board.set_workload(workload)

# --- adjuntar el acelerador como periférico del VP (antes de instanciar) ---
board.accel = RgbToGrayAccel()

# cara de control: la CPU escribe registros por MMIO -> puente -> accel.cfg
board.cfg_bridge = Gem5ToTlmBridge32()
board.cfg_bridge.addr_ranges = [AddrRange(ACC_BASE, size=0x1000)]
board.cfg_bridge.gem5 = board.iobus.mem_side_ports  # device (responder) en el iobus
board.cfg_bridge.tlm = board.accel.cfg

# cara de memoria: accel hace DMA -> puente -> iobus -> iocache -> membus (coherente)
board.mem_bridge = TlmToGem5Bridge32()
board.accel.mem = board.mem_bridge.tlm
board.mem_bridge.gem5 = board.iobus.cpu_side_ports  # DMA master (requestor) en el iobus

# kernel SystemC co-ejecutando dentro de gem5
board.sc_kernel = SystemC_Kernel()


# --- manejadores de salida (igual que el stock: terminar tras el boot) ---
class CustomKernelBootedExitHandler(KernelBootedExitHandler):
    @overrides(KernelBootedExitHandler)
    def _process(self, simulator: "Simulator") -> None:
        print("First exit: kernel booted (periférico adjunto OK)")

    @overrides(KernelBootedExitHandler)
    def _exit_simulation(self) -> bool:
        return False


class AfterBootScriptExitHandler(ExitHandler, hypercall_num=3):
    @overrides(ExitHandler)
    def _process(self, simulator: "Simulator") -> None:
        print(f"Third exit: {self.get_handler_description()}")

    @overrides(ExitHandler)
    def _exit_simulation(self) -> bool:
        return True


simulator = Simulator(board=board)
simulator.run()
