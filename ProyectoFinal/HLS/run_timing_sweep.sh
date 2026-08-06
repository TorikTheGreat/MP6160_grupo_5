#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_EXE="${PYTHON_EXE:-python3}"
VIVADO_EXE="${VIVADO_EXE:-vivado}"
PART="${WHT_PART:-xck26-sfvc784-2LV-c}"

usage() {
  echo "Usage: $0 <variant> [period_ns ...]"
  echo "Example: $0 isolated_forward 6.0 5.0 4.5 4.0 3.5 3.0"
}

[[ $# -ge 1 ]] || { usage; exit 2; }
VARIANT="$1"
shift
PERIODS=("$@")
if [[ ${#PERIODS[@]} -eq 0 ]]; then
  PERIODS=(6.0 5.0 4.5 4.0 3.5 3.0)
fi

case "$VARIANT" in
  main_forward) TOP="wht_lossless_core"; PROJECT="wht_main_forward"; SOLUTION="solution_main_forward" ;;
  main_inverse) TOP="wht_lossless_inverse"; PROJECT="wht_main_inverse"; SOLUTION="solution_main_inverse" ;;
  isolated_forward) TOP="wht_lossless_forward_isolated"; PROJECT="wht_isolated_forward"; SOLUTION="solution_isolated_forward" ;;
  isolated_inverse) TOP="wht_lossless_inverse_isolated"; PROJECT="wht_isolated_inverse"; SOLUTION="solution_isolated_inverse" ;;
  baseline_forward) TOP="wht_multiplier_forward"; PROJECT="wht_baseline_forward"; SOLUTION="solution_baseline_forward" ;;
  baseline_inverse) TOP="wht_multiplier_inverse"; PROJECT="wht_baseline_inverse"; SOLUTION="solution_baseline_inverse" ;;
  *) echo "ERROR: unsupported variant: $VARIANT" >&2; usage; exit 2 ;;
esac

RTL_DIR="$SCRIPT_DIR/work/$VARIANT/hls/$PROJECT/$SOLUTION/syn/verilog"
SWEEP_DIR="$SCRIPT_DIR/reports/$VARIANT/timing_sweep"
[[ -d "$RTL_DIR" ]] || {
  echo "ERROR: RTL not found at $RTL_DIR" >&2
  echo "First run: ./run_variant.sh $VARIANT --hls-only" >&2
  exit 3
}

mkdir -p "$SWEEP_DIR"
export WHT_TOP="$TOP"
export WHT_RTL_DIR="$RTL_DIR"
export WHT_PART="$PART"

for period in "${PERIODS[@]}"; do
  tag="${period//./p}ns"
  out="$SWEEP_DIR/$tag"
  rm -rf "$out"
  mkdir -p "$out"
  export WHT_REPORT_DIR="$out"
  export WHT_VIVADO_CLOCK_NS="$period"
  echo "[Sweep] $VARIANT at ${period} ns"
  "$VIVADO_EXE" -mode batch -source "$SCRIPT_DIR/run_configurable_vivado.tcl" -notrace \
    2>&1 | tee "$out/vivado.log"
done

"$PYTHON_EXE" "$SCRIPT_DIR/tools/summarize_sweep.py" \
  --sweep-dir "$SWEEP_DIR" \
  --variant "$VARIANT"

echo "Sweep summary: $SWEEP_DIR/timing_sweep_summary.md"
