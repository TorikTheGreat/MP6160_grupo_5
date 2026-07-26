#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build_cosim_final"
SNAPSHOT="systemc_dpi_cosim_sim"

for tool in xsc xvlog xelab xsim; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: no se encontro $tool."
        echo "Ejecuta: source /tools/Xilinx/Vivado/2024.1/settings64.sh"
        exit 1
    fi
done

rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"

echo "============================================"
echo " Integracion cooperativa C++/DPI + AXI/XSim"
echo "============================================"

echo "[1/4] Compilando biblioteca DPI..."
xsc \
    "$ROOT/src/tlm_axi_adapter.cpp" \
    "$ROOT/src/systemc_dpi_wrapper.cpp"

echo "[2/4] Compilando SystemVerilog y RTL..."
xvlog -sv \
    "$ROOT/../tarea3_rtl/rtl/axi4_ram.sv" \
    "$ROOT/sv/dpi_axi_master.sv" \
    "$ROOT/sv/axi_dpi_server.sv" \
    "$ROOT/sv/tb_systemc_dpi_step_launcher.sv"

echo "[3/4] Elaborando..."
xelab \
    work.tb_systemc_dpi_step_launcher \
    --sv_lib xsim.dir/work/xsc/dpi \
    --debug typical \
    --timescale 1ns/1ps \
    --snapshot "$SNAPSHOT"

echo "[4/4] Ejecutando..."
xsim "$SNAPSHOT" -runall
