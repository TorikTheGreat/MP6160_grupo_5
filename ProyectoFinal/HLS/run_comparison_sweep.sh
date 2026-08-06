#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERIODS=("$@")
if [[ ${#PERIODS[@]} -eq 0 ]]; then
  PERIODS=(6.0 5.0 4.5 4.0 3.5 3.0)
fi

# Same periods for the controlled forward comparison.
"$SCRIPT_DIR/run_timing_sweep.sh" isolated_forward "${PERIODS[@]}"
"$SCRIPT_DIR/run_timing_sweep.sh" baseline_forward "${PERIODS[@]}"
