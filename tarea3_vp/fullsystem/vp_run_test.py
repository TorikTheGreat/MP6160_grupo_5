# vp_run_test.py — END-TO-END del VP: ArmBoard (Ubuntu ARM64) + acelerador + programa en C.
#
# Prueba la cadena completa: un binario C corre en el guest, mapea los registros del
# acelerador por /dev/mem, pone la imagen RGB en memoria física reservada, dispara el DMA
# y verifica el gris bit-exact. Es la demostración de la frontera end-to-end (Hito C/D).
#
# Cómo:
#   1) compilar el binario:  aarch64-linux-gnu-gcc -O2 -static -s acctest.c -o acctest
#   2) correr:               build/ARM/gem5.opt vp_run_test.py
# Requiere gem5 compilado con EXTRAS=<...>/vp_accel.
import base64
import os

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
from gem5.resources.resource import (
    BootloaderResource,
    DiskImageResource,
    KernelResource,
)
from gem5.simulate.exit_handler import KernelBootedExitHandler
from gem5.simulate.simulator import Simulator
from gem5.utils.override import overrides

ACC_BASE = 0x10030000

# --- board (ATOMIC + 2 núcleos = boot más rápido; caches → iocache coherente) ---
# El cuello de botella es el boot de systemd; se ataca enmascarando servicios (abajo).
# ATOMIC medido en ~1330x vs TIMING ~1800x, así que ATOMIC + masks es la combinación más rápida.
cache_hierarchy = PrivateL1PrivateL2CacheHierarchy(
    l1d_size="16KiB", l1i_size="16KiB", l2_size="256KiB"
)
memory = DualChannelDDR4_2400(size="2GiB")
processor = SimpleProcessor(cpu_type=CPUTypes.ATOMIC, num_cores=2, isa=ISA.ARM)
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

# Usamos una COPIA del disco de gem5 provista con un drop-in NOPASSWD en /etc/sudoers.d/
# (para que after_boot, que corre como el usuario 'gem5', pueda sudo sin contraseña y así
# darle a acctest el root que /dev/mem exige). Kernel y bootloader vienen del cache original.
# El disco original del cache queda intacto; NO se toca (gem5 re-verifica su md5).
_CACHE = "/home/usuariomarcelo/.cache/gem5"
board.set_kernel_disk_workload(
    kernel=KernelResource(local_path=f"{_CACHE}/arm64-linux-kernel-6.8.12-1.0.0"),
    disk_image=DiskImageResource(
        local_path=f"{_CACHE}/arm-ubuntu-24.04-nopasswd.img", root_partition="2"
    ),
    bootloader=BootloaderResource(
        local_path=f"{_CACHE}/arm64-bootloader-foundation-2.0.0"
    ),
)

# Reservar la parte alta de la DRAM para los buffers del acelerador:
#   DRAM = [0x8000_0000, 0x1_0000_0000) (2 GiB). Con mem=1536M el kernel usa
#   [0x8000_0000, 0xE000_0000); [0xE000_0000, 0x1_0000_0000) (512 MB) queda libre y
#   fuera de System RAM -> el C la mapea por /dev/mem en física conocida (BUF_PHYS=0xE000_0000).
# iomem=relaxed permite /dev/mem por si el kernel no honra mem= del todo.
board.append_kernel_arg("mem=1536M")
board.append_kernel_arg("iomem=relaxed")

# Acelerar el boot: enmascarar servicios lentos/inútiles en gem5 (sin red real).
# cloud-init es el culpable clásico de boots lentísimos de Ubuntu en gem5. NO enmascarar
# systemd-networkd/resolved: after_boot.sh (que corre acctest) depende de que la red suba
# (network-online.target); enmascararlos deja el boot colgado en el login sin correr after_boot.
# wait-online sí se enmascara (solo bloquea esperando red que nunca llega en gem5).
for _svc in (
    "cloud-init-local.service",
    "cloud-init.service",
    "cloud-config.service",
    "cloud-final.service",
    "systemd-networkd-wait-online.service",
    "NetworkManager-wait-online.service",
    "snapd.service",
    "snapd.seeded.service",
    "ModemManager.service",
):
    board.append_kernel_arg(f"systemd.mask={_svc}")

# --- adjuntar el acelerador (topología #2: SystemC dentro de gem5) ---
board.accel = RgbToGrayAccel()  # dma_chunk = 64 (línea de caché) por default

# Cara de control (MMIO): device responder @ ACC_BASE en el iobus.
board.cfg_bridge = Gem5ToTlmBridge32()
board.cfg_bridge.addr_ranges = [AddrRange(ACC_BASE, size=0x1000)]
board.cfg_bridge.gem5 = board.iobus.mem_side_ports
board.cfg_bridge.tlm = board.accel.cfg

# Cara de memoria (DMA): master en el iobus -> iocache coherente -> membus -> DRAM compartida.
board.mem_bridge = TlmToGem5Bridge32()
board.accel.mem = board.mem_bridge.tlm
board.mem_bridge.gem5 = board.iobus.cpu_side_ports

board.sc_kernel = SystemC_Kernel()

# --- inyectar el binario C al guest vía readfile (base64) + salida limpia ---
_here = os.path.dirname(os.path.abspath(__file__))
_bin = os.environ.get("ACCTEST_BIN", "acctest")  # binario a inyectar (permite variar NPIX)
with open(os.path.join(_here, _bin), "rb") as _f:
    _b64 = base64.encodebytes(_f.read()).decode()  # envuelto a 76 col
_img_path = os.path.abspath(
    os.path.join(_here, "..", "..", "tarea_2", "sapo_perro.rgb")
)

with open(_img_path, "rb") as _img_file:
    _img_b64 = base64.encodebytes(_img_file.read()).decode()
# after_boot corre como usuario NO-root y /root no es escribible por él; además /dev/mem
# necesita root. Solución: el base64 va a /tmp (escribible por todos), y el binario se
# decodifica y ejecuta como ROOT vía sudo -n, en /root (exec-able, no noexec como /tmp).
run_script = (
    "#!/bin/sh\n"
    "echo ACCTEST_INJECT_START\n"
    "id\n"
    "command -v base64 >/dev/null || echo ACCTEST_NO_BASE64\n"
    "command -v sudo >/dev/null || echo ACCTEST_NO_SUDO\n"
    "cat > /tmp/acctest.b64 << 'B64EOF'\n"
    f"{_b64}"
    "B64EOF\n"
    "cat > /tmp/sapo_perro.rgb.b64 << 'RGBEOF'\n"
    f"{_img_b64}"
"RGBEOF\n"
"base64 -d /tmp/sapo_perro.rgb.b64 > /tmp/sapo_perro.rgb\n"
    "echo ACCTEST_RUN\n"
    'if [ "$(id -u)" = "0" ]; then\n'
    "  base64 -d /tmp/acctest.b64 > /root/acctest && chmod +x /root/acctest && /root/acctest\n"
    "else\n"
    "  sudo -n sh -c 'base64 -d /tmp/acctest.b64 > /root/acctest && chmod +x /root/acctest && /root/acctest'\n"
    "fi\n"
    "m5 writefile /tmp/sapo_perro_gray.raw sapo_perro_gray.raw\n"
    "echo ACCTEST_DONE rc=$?\n"
    "m5 exit\n"
)
board._set_readfile_contents(run_script)


# el boot debe CONTINUAR tras "kernel booted" para llegar a after_boot.sh (que corre el script)
class ContinueAfterKernelBoot(KernelBootedExitHandler):
    @overrides(KernelBootedExitHandler)
    def _process(self, simulator: "Simulator") -> None:
        print("kernel booted; ejecutando after_boot.sh (acctest)")

    @overrides(KernelBootedExitHandler)
    def _exit_simulation(self) -> bool:
        return False


simulator = Simulator(board=board)
simulator.run()
print("simulación terminada (m5 exit desde el guest)")
