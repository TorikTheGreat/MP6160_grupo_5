#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build_image_cosim"
SNAPSHOT="image_dpi_axi_sim"

for tool in xsc xvlog xelab xsim; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: no se encontro $tool."
        echo "Ejecuta: source /tools/Xilinx/Vivado/2024.1/settings64.sh"
        exit 1
    fi
done

INPUT="$ROOT/input/sapo_perro.rgb"
EXPECTED_BYTES=6220800

if [[ ! -f "$INPUT" ]]; then
    echo "ERROR: no existe $INPUT"
    exit 1
fi

ACTUAL_BYTES="$(stat -c%s "$INPUT")"
if [[ "$ACTUAL_BYTES" -ne "$EXPECTED_BYTES" ]]; then
    echo "ERROR: sapo_perro.rgb debe tener $EXPECTED_BYTES bytes."
    echo "Tamano encontrado: $ACTUAL_BYTES bytes."
    exit 1
fi

mkdir -p "$ROOT/output"
rm -f "$ROOT/output/sapo_perro.pgm"
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"

export TAREA3_ROOT="$ROOT"

echo "============================================"
echo " Carga de imagen RGB por DPI + AXI/XSim"
echo "============================================"
echo "Entrada: $INPUT"
echo "Salida : $ROOT/output/sapo_perro.pgm"
echo

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
echo "AVISO: la imagen completa requiere millones de transacciones AXI."
echo "La ejecucion puede tardar varios minutos."
xsim "$SNAPSHOT" -runall

if [[ ! -f "$ROOT/output/sapo_perro.pgm" ]]; then
    echo "ERROR: la simulacion termino sin generar sapo_perro.pgm"
    exit 1
fi

echo
echo "Archivo generado:"
ls -lh "$ROOT/output/sapo_perro.pgm"
