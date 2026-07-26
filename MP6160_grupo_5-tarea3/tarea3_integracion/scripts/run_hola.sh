#!/bin/bash

set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)

mkdir -p "$ROOT/build"

cd "$ROOT/build"

echo "========== COMPILANDO =========="

xvlog -sv ../sv/tb_hola.sv

echo "========== ELABORANDO =========="

xelab tb_hola -s tb_hola_sim

echo "========== EJECUTANDO =========="

xsim tb_hola_sim -runall