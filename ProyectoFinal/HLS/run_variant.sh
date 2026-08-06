#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_EXE="${PYTHON_EXE:-python3}"
VITIS_HLS_EXE="${VITIS_HLS_EXE:-vitis_hls}"
VIVADO_EXE="${VIVADO_EXE:-vivado}"
PART="${WHT_PART:-xck26-sfvc784-2LV-c}"
HLS_CLOCK_NS="${WHT_HLS_CLOCK_NS:-4.0}"
VIVADO_CLOCK_NS="${WHT_VIVADO_CLOCK_NS:-10.0}"
RUN_HLS=1
RUN_VIVADO=1
RUN_COSIM=1

usage() {
  cat <<USAGE
Usage: $0 <variant> [options]

Variants:
  main_forward main_inverse isolated_forward isolated_inverse
  baseline_forward baseline_inverse

Options:
  --hls-only             Run CSim, CSynth, optional C/RTL cosim and export RTL only
  --vivado-only          Run Vivado using RTL already generated for the variant
  --no-cosim             Skip C/RTL cosimulation
  --hls-clock <ns>       HLS target period (default: $HLS_CLOCK_NS)
  --vivado-clock <ns>    Vivado requested period (default: $VIVADO_CLOCK_NS)
  --part <part>           FPGA part (default: $PART)
  --vitis <path>         Vitis HLS executable
  --vivado <path>        Vivado executable
  --python <path>        Python 3 executable
USAGE
}

[[ $# -ge 1 ]] || { usage; exit 2; }
VARIANT="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hls-only) RUN_VIVADO=0; shift ;;
    --vivado-only) RUN_HLS=0; shift ;;
    --no-cosim) RUN_COSIM=0; shift ;;
    --hls-clock) HLS_CLOCK_NS="$2"; shift 2 ;;
    --vivado-clock) VIVADO_CLOCK_NS="$2"; shift 2 ;;
    --part) PART="$2"; shift 2 ;;
    --vitis) VITIS_HLS_EXE="$2"; shift 2 ;;
    --vivado) VIVADO_EXE="$2"; shift 2 ;;
    --python) PYTHON_EXE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

case "$VARIANT" in
  main_forward)
    TOP="wht_lossless_core"
    SOURCE="../Source/wht_core.cpp"
    TB="../TB/wht_core_tb.cpp"
    PROJECT="wht_main_forward"
    SOLUTION="solution_main_forward"
    ;;
  main_inverse)
    TOP="wht_lossless_inverse"
    SOURCE="../Source/wht_core.cpp"
    TB="../TB/wht_core_inv_tb.cpp"
    PROJECT="wht_main_inverse"
    SOLUTION="solution_main_inverse"
    ;;
  isolated_forward)
    TOP="wht_lossless_forward_isolated"
    SOURCE="../Source/wht_core_isolated.cpp"
    TB="../TB/wht_core_isolated_forward_tb.cpp"
    PROJECT="wht_isolated_forward"
    SOLUTION="solution_isolated_forward"
    ;;
  isolated_inverse)
    TOP="wht_lossless_inverse_isolated"
    SOURCE="../Source/wht_core_isolated.cpp"
    TB="../TB/wht_core_isolated_inverse_tb.cpp"
    PROJECT="wht_isolated_inverse"
    SOLUTION="solution_isolated_inverse"
    ;;
  baseline_forward)
    TOP="wht_multiplier_forward"
    SOURCE="../Baseline/wht_multiplier_baseline.cpp"
    TB="../Baseline/wht_multiplier_baseline_tb.cpp"
    PROJECT="wht_baseline_forward"
    SOLUTION="solution_baseline_forward"
    ;;
  baseline_inverse)
    TOP="wht_multiplier_inverse"
    SOURCE="../Baseline/wht_multiplier_baseline.cpp"
    TB="../Baseline/wht_multiplier_inverse_tb.cpp"
    PROJECT="wht_baseline_inverse"
    SOLUTION="solution_baseline_inverse"
    ;;
  *) echo "ERROR: unsupported variant: $VARIANT" >&2; usage; exit 2 ;;
esac

WORK_ROOT="$SCRIPT_DIR/work/$VARIANT/hls"
REPORT_DIR="$SCRIPT_DIR/reports/$VARIANT"
RTL_DIR="$WORK_ROOT/$PROJECT/$SOLUTION/syn/verilog"
mkdir -p "$REPORT_DIR/logs" "$REPORT_DIR/inputs"

check_exe() {
  local exe="$1"
  local label="$2"
  if ! command -v "$exe" >/dev/null 2>&1 && [[ ! -x "$exe" ]]; then
    echo "ERROR: $label executable not found: $exe" >&2
    exit 3
  fi
}

check_exe "$PYTHON_EXE" "Python"

export WHT_TOP="$TOP"
export WHT_SOURCE="$SOURCE"
export WHT_TB="$TB"
export WHT_PROJECT="$PROJECT"
export WHT_SOLUTION="$SOLUTION"
export WHT_WORK_DIR="$WORK_ROOT"
export WHT_PART="$PART"
export WHT_HLS_CLOCK_NS="$HLS_CLOCK_NS"
export WHT_RUN_COSIM="$RUN_COSIM"

if [[ "$RUN_HLS" -eq 1 ]]; then
  check_exe "$VITIS_HLS_EXE" "Vitis HLS"
  rm -rf "$WORK_ROOT" "$REPORT_DIR/hls" "$REPORT_DIR/simulation" "$REPORT_DIR/post_route"
  rm -f "$REPORT_DIR/manifest.json" "$REPORT_DIR/metrics.json" "$REPORT_DIR/metrics.md"
  mkdir -p "$WORK_ROOT" "$REPORT_DIR/logs" "$REPORT_DIR/inputs"

  cp -f "$SCRIPT_DIR/$SOURCE" "$REPORT_DIR/inputs/"
  cp -f "$SCRIPT_DIR/$TB" "$REPORT_DIR/inputs/"
  cp -f "$SCRIPT_DIR/run_configurable_hls.tcl" "$REPORT_DIR/inputs/"
  cp -f "$SCRIPT_DIR/run_configurable_vivado.tcl" "$REPORT_DIR/inputs/"
  cp -f "$SCRIPT_DIR/variants.json" "$REPORT_DIR/inputs/"

  echo "[HLS] Running $VARIANT ($TOP)"
  "$VITIS_HLS_EXE" -f "$SCRIPT_DIR/run_configurable_hls.tcl" \
    2>&1 | tee "$REPORT_DIR/logs/vitis_hls.log"

  "$PYTHON_EXE" "$SCRIPT_DIR/tools/collect_hls_reports.py" \
    --work-root "$WORK_ROOT" \
    --report-dir "$REPORT_DIR" \
    --variant "$VARIANT" \
    --top "$TOP" \
    --part "$PART" \
    --hls-clock-ns "$HLS_CLOCK_NS" \
    --source "$SOURCE" \
    --testbench "$TB" \
    --project "$PROJECT" \
    --solution "$SOLUTION"
fi

if [[ "$RUN_VIVADO" -eq 1 ]]; then
  check_exe "$VIVADO_EXE" "Vivado"
  [[ -d "$RTL_DIR" ]] || {
    echo "ERROR: RTL directory not found: $RTL_DIR" >&2
    echo "Run the HLS step first for variant $VARIANT." >&2
    exit 4
  }
  rm -rf "$REPORT_DIR/post_route"
  mkdir -p "$REPORT_DIR/post_route" "$REPORT_DIR/logs"

  export WHT_RTL_DIR="$RTL_DIR"
  export WHT_REPORT_DIR="$REPORT_DIR/post_route"
  export WHT_VIVADO_CLOCK_NS="$VIVADO_CLOCK_NS"

  echo "[Vivado] Implementing $VARIANT at ${VIVADO_CLOCK_NS} ns"
  "$VIVADO_EXE" -mode batch -source "$SCRIPT_DIR/run_configurable_vivado.tcl" -notrace \
    2>&1 | tee "$REPORT_DIR/logs/vivado.log"
fi

"$PYTHON_EXE" "$SCRIPT_DIR/tools/summarize_variant.py" \
  --report-dir "$REPORT_DIR" \
  --variant "$VARIANT" \
  --top "$TOP" \
  --part "$PART"

"$PYTHON_EXE" "$SCRIPT_DIR/tools/build_comparison.py" \
  --reports-dir "$SCRIPT_DIR/reports"

echo "DONE: $VARIANT"
echo "Reports: $REPORT_DIR"
