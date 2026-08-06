#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
python3 -m py_compile "$SCRIPT_DIR"/tools/*.py
bash -n "$SCRIPT_DIR"/*.sh
make -C "$PROJECT_DIR" test
echo "Local validation passed. Vitis HLS/Vivado were not executed."
