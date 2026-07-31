#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMC_DIR="$REPO_ROOT/systemc"

if [[ ! -f "$SYSTEMC_DIR/Makefile" ]]; then
    echo "ERROR: no se encontró systemc/Makefile" >&2
    exit 1
fi

cd "$SYSTEMC_DIR"

if [[ ! -f tools/systemc/include/systemc.h ]]; then
    echo "SystemC local no está instalado; ejecutando setup.sh..."
    chmod +x setup.sh
    ./setup.sh
fi

# shellcheck disable=SC1091
source ./activate.sh
make test-all

cmp -s sapo_perro_gray.raw reference/sapo_perro_gray_tarea2.raw
printf '\nROL A: TODAS LAS PRUEBAS PORTABLES Y BIT-EXACT PASS\n'
