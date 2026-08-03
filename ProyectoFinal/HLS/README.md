# Vitis HLS synthesis flow for WHT core

This folder contains the reproducible flow for HLS synthesis of:
- Top function: wht_lossless_core / wht_lossless_inverse
- Source: ../Source/wht_core.cpp
- Testbench: ../TB/wht_core_tb.cpp
- Target part: xcvc1902-vsva2197-2MP-e-S (Kria KV260 flow reference)

## Prerequisites

- Windows + PowerShell 5+
- Linux: bash + coreutils + awk + sed + grep
- Vitis HLS 2024.1 (or compatible) available as `vitis_hls` or via explicit path
- Vivado 2024.1 installed (default expected by `run_vivado_impl.ps1`)
- Valid Vivado synthesis/implementation license for `xcvc1902`

## Windows vs Linux scripts

- Windows-native flow:
  - `run_w2.ps1`
  - `run_vivado_impl.ps1`
- Linux-native flow:
  - `run_w2.sh`
  - `run_vivado_impl.sh`

Notes:

- `.ps1` scripts can also run on Linux if PowerShell 7 (`pwsh`) is installed.
- `.sh` scripts are the recommended Linux path and produce the same output files.

## Reproducibility conditions

To obtain the same results reported in this folder, keep these conditions:

- Use the same target part: `xcvc1902-vsva2197-2MP-e-S`
- Run HLS first, then Vivado implementation (in that order)
- Use a clean output directory before reruns
- Do not modify source (`../Source/wht_core.cpp`) or scripts in this folder
- Keep tool major version aligned (recommended: 2024.1 for both Vitis HLS and Vivado)

## Quick start (exact sequence)

From this folder (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File .\run_w2.ps1 -VitisHlsExe "C:\Xilinx\Vitis_HLS\2024.1\bin\vitis_hls.bat"
```

If vitis_hls is not in PATH:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_w2.ps1 -VitisHlsExe "C:\ruta\a\vitis_hls.bat"
```

Then run post-route implementation:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_vivado_impl.ps1
```

Linux equivalent (from this same folder):

```bash
chmod +x ./run_w2.sh ./run_vivado_impl.sh ./extract_metrics.sh ./extract_impl_metrics.sh
./run_w2.sh
./run_vivado_impl.sh
```

If tools are not in PATH, pass explicit executables:

```bash
./run_w2.sh /tools/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls
./run_vivado_impl.sh /tools/Xilinx/Vivado/2024.1/bin/vivado
```

## Clean rerun (recommended)

If you want to reproduce from scratch and avoid stale artifacts:

```powershell
Remove-Item .\wht_hls_work -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\vivado_work -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item .\metrics_prelim.md -Force -ErrorAction SilentlyContinue
Remove-Item .\metrics_impl.md -Force -ErrorAction SilentlyContinue
```

Then execute the two commands from Quick start in order.

Linux clean rerun equivalent:

```bash
cd ..
make clean
cd HLS
```

## Outputs

- HLS work directory:
  - wht_hls_work/wht_hls/solution_kv260
- Main reports:
  - wht_hls_work/wht_hls/solution_kv260/syn/report/wht_lossless_core_csynth.rpt
  - wht_hls_work/wht_hls/solution_kv260/syn/report/wht_lossless_core_csynth.xml
- Preliminary metrics summary (generated):
  - metrics_prelim.md

## Post-HLS Vivado implementation

This repository includes a scripted post-route flow to generate implemented metrics:

- run_vivado_impl.tcl (Vivado batch, non-project mode)
- run_vivado_impl.ps1 (launcher)
- extract_impl_metrics.ps1 (report parser)

Run from this folder (after `run_w2.ps1`):

```powershell
powershell -ExecutionPolicy Bypass -File .\run_vivado_impl.ps1
```

Expected outputs:

- vivado_work/utilization_post_route.rpt
- vivado_work/timing_post_route.rpt
- vivado_work/timing_critical_path.rpt
- metrics_impl.md

Important:

- Vivado must have a valid synthesis/implementation license for device xcvc1902.
- If license is missing, implementation stops before generating post-route metrics.

## Notes

- metrics_prelim.md is intended for section drafting (LUT, FF, DSP, latency, fmax).
- DSP should remain 0 for the multiplier-free lifting architecture.

## Expected results (reference)

If the environment and tool versions match, generated metrics should be close to:

- `metrics_prelim.md` (HLS csynth):
  - Estimated clock: ~2.920 ns
  - Estimated fmax: ~342.47 MHz
  - Latency: 150 cycles
  - II: 1
  - DSP: 0
- `metrics_impl.md` (Vivado post-route):
  - Critical data path delay: ~2.948 ns
  - Implemented fmax: ~339.21 MHz
  - WNS: ~6.604 ns
  - DSP: 0

Small variations can appear with different tool patch levels or machine setup.
