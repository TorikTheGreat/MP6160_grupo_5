#!/usr/bin/env bash
set -euo pipefail
VITIS_HLS_EXE="${VITIS_HLS_EXE:-vitis_hls}"
VIVADO_EXE="${VIVADO_EXE:-vivado}"
PYTHON_EXE="${PYTHON_EXE:-python3}"

for item in "$PYTHON_EXE:Python 3" "$VITIS_HLS_EXE:Vitis HLS" "$VIVADO_EXE:Vivado"; do
  exe="${item%%:*}"
  label="${item#*:}"
  if command -v "$exe" >/dev/null 2>&1 || [[ -x "$exe" ]]; then
    echo "[OK] $label: $exe"
  else
    echo "[MISSING] $label: $exe"
  fi
done

echo
echo "Target part configured: ${WHT_PART:-xck26-sfvc784-2LV-c}"
echo "A successful synthesis run is still required to confirm device support and licensing."
