#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VITIS_HLS_EXE="${1:-${VITIS_HLS_EXE:-vitis_hls}}"

if ! command -v "$VITIS_HLS_EXE" >/dev/null 2>&1 && [[ ! -x "$VITIS_HLS_EXE" ]]; then
  echo "ERROR: Vitis HLS executable not found: $VITIS_HLS_EXE" >&2
  exit 1
fi

pushd "$SCRIPT_DIR" >/dev/null
echo "[HLS] Running Vitis HLS synthesis..."
"$VITIS_HLS_EXE" -f "$SCRIPT_DIR/run_w2_hls.tcl"

echo "[HLS] Extracting preliminary metrics..."
"$SCRIPT_DIR/extract_metrics.sh"

echo "[HLS] Done"
popd >/dev/null
