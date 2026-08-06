#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Complete reproducible set. baseline_inverse is included so the total reversible
# cost can be reported, although the controlled primary comparison is forward-only.
VARIANTS=(
  main_forward
  main_inverse
  isolated_forward
  isolated_inverse
  baseline_forward
  baseline_inverse
)

for variant in "${VARIANTS[@]}"; do
  echo
  echo "################################################################"
  echo "Running $variant"
  echo "################################################################"
  "$SCRIPT_DIR/run_variant.sh" "$variant" "$@"
done

echo "All variants completed."
echo "Consolidated table: $SCRIPT_DIR/reports/comparison.md"
