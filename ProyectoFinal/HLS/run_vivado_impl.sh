#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIVADO_EXE="${1:-${VIVADO_EXE:-vivado}}"

if ! command -v "$VIVADO_EXE" >/dev/null 2>&1 && [[ ! -x "$VIVADO_EXE" ]]; then
  echo "ERROR: Vivado executable not found: $VIVADO_EXE" >&2
  exit 1
fi

pushd "$SCRIPT_DIR" >/dev/null
echo "[W2/Vivado] Running post-HLS implementation..."
"$VIVADO_EXE" -mode batch -source "$SCRIPT_DIR/run_vivado_impl.tcl" -notrace

echo "[W2/Vivado] Extracting implemented metrics..."
"$SCRIPT_DIR/extract_impl_metrics.sh"

echo "[W2/Vivado] Done"
popd >/dev/null
