#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPL_DIR="${1:-${IMPL_DIR:-$SCRIPT_DIR/vivado_work}}"

UTIL_RPT="$IMPL_DIR/utilization_post_route.rpt"
TIMING_RPT="$IMPL_DIR/timing_post_route.rpt"
CRITICAL_RPT="$IMPL_DIR/timing_critical_path.rpt"
SUMMARY_FILE="$IMPL_DIR/impl_summary.txt"
OUT_MD="$SCRIPT_DIR/metrics_impl.md"

[[ -f "$UTIL_RPT" ]] || { echo "ERROR: Missing file: $UTIL_RPT" >&2; exit 1; }
[[ -f "$TIMING_RPT" ]] || { echo "ERROR: Missing file: $TIMING_RPT" >&2; exit 1; }
[[ -f "$CRITICAL_RPT" ]] || { echo "ERROR: Missing file: $CRITICAL_RPT" >&2; exit 1; }

trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<< "$1"
}

parse_table_value() {
  local file="$1"
  local regex="$2"
  local line value
  line="$(grep -m1 -E "$regex" "$file" || true)"
  if [[ -z "$line" ]]; then
    echo "N/A"
    return
  fi
  value="$(awk -F'|' '{print $3}' <<< "$line")"
  value="$(trim "$value")"
  if [[ -z "$value" ]]; then
    echo "N/A"
  else
    echo "$value"
  fi
}

parse_from_text() {
  local text="$1"
  local sed_expr="$2"
  local value
  value="$(sed -nE "$sed_expr" <<< "$text" | head -n1)"
  if [[ -z "$value" ]]; then
    echo "N/A"
  else
    echo "$value"
  fi
}

util_text="$(cat "$UTIL_RPT")"
timing_text="$(cat "$TIMING_RPT")"
critical_text="$(cat "$CRITICAL_RPT")"
summary_text=""
if [[ -f "$SUMMARY_FILE" ]]; then
  summary_text="$(cat "$SUMMARY_FILE")"
fi

lut="$(parse_table_value "$UTIL_RPT" '\|[[:space:]]*CLB LUTs\*?[[:space:]]*\|')"
ff="$(parse_table_value "$UTIL_RPT" '\|[[:space:]]*CLB Registers[[:space:]]*\|')"
dsp="$(parse_table_value "$UTIL_RPT" '\|[[:space:]]*DSP([[:space:]]+Slices|s)?[[:space:]]*\|')"
bram="$(parse_table_value "$UTIL_RPT" '\|[[:space:]]*Block RAM Tile[[:space:]]*\|')"

datapath_ns="$(parse_from_text "$critical_text" 's/.*Data Path Delay:[[:space:]]*([0-9.]+)ns.*/\1/p')"
logic_ns="$(parse_from_text "$critical_text" 's/.*logic[[:space:]]*([0-9.]+)ns.*/\1/p')"
route_ns="$(parse_from_text "$critical_text" 's/.*route[[:space:]]*([0-9.]+)ns.*/\1/p')"

wns_ns="$(parse_from_text "$summary_text" 's/.*wns_ns[[:space:]]*=[[:space:]]*(-?[0-9.]+).*/\1/p')"
if [[ "$datapath_ns" == "N/A" ]]; then
  datapath_ns="$(parse_from_text "$summary_text" 's/.*datapath_delay_ns[[:space:]]*=[[:space:]]*([0-9.]+).*/\1/p')"
fi
if [[ "$wns_ns" == "N/A" ]]; then
  wns_ns="$(parse_from_text "$timing_text" 's/.*Slack[[:space:]]*\((MET|VIOLATED)\)[[:space:]]*:[[:space:]]*(-?[0-9.]+)ns.*/\2/p')"
fi

fmax_mhz="N/A"
if [[ "$datapath_ns" != "N/A" ]]; then
  fmax_mhz="$(awk -v d="$datapath_ns" 'BEGIN{if (d+0 > 0) printf "%.2f", 1000.0/d; else print "N/A"}')"
fi

cat > "$OUT_MD" <<EOF
# W2 Implemented Hardware Metrics (Post-Route)

Source: Vivado 2024.1 post-route reports.

| Metric | Value |
|---|---|
| Critical data path delay (ns) | $datapath_ns |
| Implemented fmax (MHz) | $fmax_mhz |
| WNS (ns) | $wns_ns |
| LUT | $lut |
| FF | $ff |
| DSP | $dsp |
| BRAM tile | $bram |

## Critical path decomposition

- Logic delay (ns): $logic_ns
- Routing delay (ns): $route_ns

## Notes

- fmax is computed as 1000 / critical_data_path_delay.
- This post-route value is more representative than csynth timing estimates.
EOF

echo "Implemented metrics written to: $OUT_MD"
