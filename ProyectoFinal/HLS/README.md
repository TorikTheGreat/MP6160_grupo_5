# HLS and Vivado workflow

This directory contains the automated flow used to synthesize, cosimulate, implement, and compare the WHT hardware variants on the AMD Kria KV260 (`xck26-sfvc784-2LV-c`). Vitis HLS and Vivado 2024.1 were used for the archived results.

## Implemented variants

| Name | Top function | Interface | Purpose |
|---|---|---|---|
| `main_forward` | `wht_lossless_core` | AXI memory + AXI-Lite | Forward kernel with integration interfaces |
| `main_inverse` | `wht_lossless_inverse` | AXI memory + AXI-Lite | Inverse kernel with integration interfaces |
| `isolated_forward` | `wht_lossless_forward_isolated` | `ap_memory` | Forward datapath used in the controlled comparison |
| `isolated_inverse` | `wht_lossless_inverse_isolated` | `ap_memory` | Isolated inverse datapath |
| `baseline_forward` | `wht_multiplier_forward` | `ap_memory` + scalar coefficient | Multiplier-based forward comparison |

Forward and inverse are synthesized as independent top functions. The controlled multiplier comparison is limited to the forward path.

## Before running the tools

Load the AMD tool environment, for example:

```bash
source /tools/Xilinx/Vivado/2024.1/settings64.sh
```

Then check the installation and run the portable tests:

```bash
./check_environment.sh
./validate_local.sh
```

## Run one variant

```bash
./run_variant.sh isolated_forward
```

The launcher performs C simulation, HLS synthesis, C/RTL cosimulation, RTL export, out-of-context Vivado implementation, and report collection. Results are written to:

```text
reports/<variant>/
```

## Run the complete set

```bash
./run_all_variants.sh
```

Equivalent PowerShell scripts are included for Windows hosts.

## Timing sweep

The timing sweep routes the exported RTL under a list of requested clock periods and records the WNS for each run.

```bash
./run_timing_sweep.sh isolated_forward 6.0 5.0 4.5 4.0 3.5 3.0
./run_timing_sweep.sh baseline_forward 6.0 5.0 4.5 4.0 3.5 3.0
```

The convenience command runs both:

```bash
./run_comparison_sweep.sh 6.0 5.0 4.5 4.0 3.5 3.0
```

The reported frequency is the fastest tested constraint that completed routing with WNS greater than or equal to zero. It should be described as a demonstrated bound, not an exact `fmax`.

## Report contents

Each completed variant contains:

```text
inputs/                       Source and configuration snapshot
hls/                          C synthesis reports and XML metrics
simulation/                   C/RTL cosimulation report
post_route/                   Utilization, timing, power, and methodology reports
manifest.json                 Run configuration and file inventory
metrics.json                  Machine-readable summary
metrics.md                    Readable summary
```

The two timing sweeps also include one report folder per tested period and a summary table.

## Current comparison

| Metric | Isolated multiplier-free | Multiplier-based baseline |
|---|---:|---:|
| HLS latency | 17 cycles | 17 cycles |
| HLS II | 9 | 9 |
| HLS LUT | 880 | 926 |
| HLS FF | 562 | 823 |
| HLS DSP | 0 | 12 |
| Post-route LUT | 501 | 500 |
| Post-route FF | 424 | 377 |
| Post-route DSP | 0 | 11 |
| Post-route BRAM | 1.5 tiles | 1.5 tiles |
| Fastest closing period in the tested sweep | 4.0 ns | 3.5 ns |
| Demonstrated frequency | 250.00 MHz | 285.71 MHz |

The designs use the same target part, interface style, HLS clock target, and implementation procedure. The result isolates the cost of replacing multiplication with arithmetic shifts.

## AXI-integrated kernels

| Metric | Forward | Inverse |
|---|---:|---:|
| HLS latency | 143 cycles | 143 cycles |
| HLS II | 1 | 1 |
| Post-route LUT | 2340 | 2366 |
| Post-route FF | 2716 | 2716 |
| Post-route DSP | 0 | 0 |
| Post-route BRAM | 4 tiles | 4 tiles |
| WNS at 10 ns | 4.292 ns | 5.980 ns |

These figures include the AXI interface logic and must not be compared directly with the isolated baseline.

## Power report

Vivado uses vectorless activity propagation because no switching-activity file is provided. The resulting power values are estimates and are not physical measurements.

## Regenerating the comparison table

```bash
python3 tools/build_comparison.py --reports-dir reports
```

The command updates `reports/comparison.csv` and `reports/comparison.md` from the stored `metrics.json` files.
