# Reversible Walsh–Hadamard Transform Accelerator for Lossless Compression

This repository contains the final implementation and evaluation of a reversible Walsh–Hadamard Transform (WHT) accelerator developed for the MP-6160 High-Level Design course. The design targets lossless image-compression pipelines in which the transform is used as a decorrelation stage before entropy coding.

The project includes separate forward and inverse hardware kernels, source-level and C/RTL verification, an automated Vitis HLS and Vivado flow, post-route reports, a controlled comparison against a multiplier-based implementation, entropy experiments, an IEEE-format article, and a short demonstration video.

The current hardware processes one-dimensional blocks of eight samples. Software experiments also evaluate block sizes of 8, 16, and 32 samples, but only the length-8 architecture is synthesized.

## Project objective

The main objective is to implement an integer and reversible WHT architecture that:

- reconstructs the original samples exactly;
- avoids multiplier and DSP use in the proposed datapath;
- can be synthesized through Vitis HLS;
- provides forward and inverse hardware paths;
- can be integrated through AXI memory and control interfaces;
- produces reproducible HLS, C/RTL cosimulation, timing, utilization, and power reports;
- can be compared fairly against an equivalent multiplier-based design.

The project evaluates the transform core rather than a complete codec. Entropy coding, packetization, camera acquisition, and board-level validation remain outside the implemented scope.

## Design overview

The transform operates on blocks of eight signed samples using three fully unrolled butterfly stages. Each reversible butterfly separates the signal into low- and high-frequency components through additions, subtractions, and arithmetic shifts.

For one sample pair \(a,b\), the forward lifting step is equivalent to:

```text
d = a - b
s = a - (d >> 1)
```

The inverse step reconstructs the original pair with:

```text
a = s + (d >> 1)
b = a - d
```

This lifting construction avoids the normalization division used by the conventional inverse WHT and allows exact reconstruction with integer arithmetic.

The repository contains four proposed-kernel variants:

| Variant | Top function | Interface | Purpose |
|---|---|---|---|
| `main_forward` | `wht_lossless_core` | `m_axi` + `s_axilite` | Forward kernel with integration interfaces |
| `main_inverse` | `wht_lossless_inverse` | `m_axi` + `s_axilite` | Inverse kernel with integration interfaces |
| `isolated_forward` | `wht_lossless_forward_isolated` | `ap_memory` | Forward datapath without the AXI wrapper |
| `isolated_inverse` | `wht_lossless_inverse_isolated` | `ap_memory` | Inverse datapath without the AXI wrapper |

The isolated variants are used to measure the arithmetic datapath without attributing the AXI interface cost to the transform itself.

## Controlled comparison

The principal hardware comparison uses:

- `isolated_forward`, which implements the proposed multiplier-free lifting datapath;
- `baseline_forward`, which implements the same reversible operation using fixed-point multiplications.

Both designs were synthesized and implemented with:

- AMD Kria KV260 part `xck26-sfvc784-2LV-c`;
- Vitis HLS 2024.1;
- Vivado 2024.1;
- memory-style interfaces;
- the same HLS target period;
- the same post-route reporting flow;
- the same timing-sweep constraints.

This prevents the AXI wrapper from distorting the comparison.

## Main results

### Functional verification

| Verification test | Result |
|---|---:|
| Forward kernel against the reference model | 100,001 / 100,001 correct cases |
| Inverse kernel against the reference model | 100,001 / 100,001 correct cases |
| Exact reconstruction with `inverse(forward(x))` | 400,001 / 400,001 correct cases |
| Overflow errors for 8-bit input samples | 0 |

The forward and inverse functions were also verified through C/RTL cosimulation. The reports are stored with each hardware variant under `ProyectoFinal/HLS/reports/`.

### Forward datapath comparison

| Metric | Multiplier-free forward | Multiplier-based forward |
|---|---:|---:|
| HLS latency | 17 cycles | 17 cycles |
| HLS initiation interval | 9 | 9 |
| HLS LUT | 880 | 926 |
| HLS flip-flops | 562 | 823 |
| HLS DSP | 0 | 12 |
| Post-route LUT | 501 | 500 |
| Post-route registers | 424 | 377 |
| Post-route DSP | 0 | 11 |
| Post-route BRAM | 1.5 tiles | 1.5 tiles |
| Post-route total on-chip power | 0.292 W | 0.294 W |
| Smallest tested period that closed timing | 4.0 ns | 3.5 ns |
| Maximum demonstrated frequency in the sweep | 250.00 MHz | 285.71 MHz |

The proposed datapath eliminates all DSP use while keeping post-route LUT utilization practically unchanged. The cost is 47 additional registers and a lower maximum demonstrated frequency in the tested sweep.

The frequency values are not presented as exact device limits. They correspond to the fastest clock constraints tested that completed routing with non-negative worst negative slack (WNS).

### Inverse datapath

| Metric | Isolated inverse |
|---|---:|
| HLS latency | 17 cycles |
| HLS initiation interval | 9 |
| HLS LUT | 903 |
| HLS flip-flops | 607 |
| HLS DSP | 0 |
| Post-route LUT | 565 |
| Post-route registers | 409 |
| Post-route DSP | 0 |
| Post-route BRAM | 1.5 tiles |
| Post-route total on-chip power | 0.292 W |

The inverse datapath therefore provides a synthesizable multiplier-free reconstruction path rather than leaving reconstruction exclusively to software.

### AXI-integrated kernels

| Metric | Forward AXI | Inverse AXI |
|---|---:|---:|
| HLS latency | 143 cycles | 143 cycles |
| HLS initiation interval | 1 | 1 |
| Post-route LUT | 2,340 | 2,366 |
| Post-route registers | 2,716 | 2,716 |
| Post-route DSP | 0 | 0 |
| Post-route BRAM | 4 tiles | 4 tiles |
| Post-route total on-chip power | 0.327 W | 0.327 W |
| WNS at a 10 ns constraint | 4.292 ns | 5.980 ns |

These values include the memory and control interfaces and are therefore reported separately from the datapath comparison.

## Entropy experiment

Five deterministic 256 × 256 datasets were used to evaluate zero-order entropy before and after the one-dimensional transform.

| Dataset | Original entropy | Per-band entropy after WHT | Change |
|---|---:|---:|---:|
| Flat | 0.000 | 0.000 | Degenerate constant case |
| Ramp | 8.000 | 0.625 | 92% reduction |
| Edges | 2.000 | 0.250 | 87% reduction |
| Natural-like | 7.304 | 5.808 | 20% reduction |
| Noise | 7.997 | 8.200 | 2.5% increase |

The results show that the transform is useful when neighboring samples are correlated. White noise is included as a control case and does not benefit from the transform.

A software-only experiment also evaluates a separable two-dimensional extension and a block-size sweep for `N = 8, 16, 32`. These results are useful for analysis but do not represent synthesized hardware beyond `N=8`.

## Repository structure

```text
MP6160_grupo_5/
├── README.md
├── ProyectoFinal/
│   ├── Makefile
│   ├── Source/
│   │   ├── wht_core.cpp
│   │   ├── wht_core.h
│   │   ├── wht_core_isolated.cpp
│   │   └── wht_core_isolated.h
│   ├── TB/
│   │   ├── wht_core_tb.cpp
│   │   ├── wht_core_inv_tb.cpp
│   │   ├── wht_core_isolated_forward_tb.cpp
│   │   └── wht_core_isolated_inverse_tb.cpp
│   ├── Golden/
│   │   ├── src/                 Reference implementation
│   │   ├── tb/                  Equivalence and round-trip tests
│   │   ├── systemc/             SystemC demonstration wrapper
│   │   ├── data/                Deterministic test datasets
│   │   ├── analysis/            Entropy, sweep, and visual experiments
│   │   ├── compat/              Local `ap_int` compatibility header
│   │   ├── Makefile
│   │   └── README.md
│   ├── Baseline/
│   │   ├── fwht_baseline.cpp
│   │   ├── wht_multiplier_baseline.cpp
│   │   ├── testbenches
│   │   └── Makefile
│   └── HLS/
│       ├── variants.json
│       ├── run_variant.sh / run_variant.ps1
│       ├── run_all_variants.sh / run_all_variants.ps1
│       ├── run_timing_sweep.sh / run_timing_sweep.ps1
│       ├── run_comparison_sweep.sh / run_comparison_sweep.ps1
│       ├── run_configurable_hls.tcl
│       ├── run_configurable_vivado.tcl
│       ├── tools/
│       ├── reports/             Versioned evidence and summaries
│       ├── work/                Generated tool projects; ignored by Git
│       └── README.md
├── paper/
│   ├── articulo.tex
│   ├── articulo.pdf
│   ├── wht_architecture.png
│   ├── wht_reconstruction.png
│   ├── Makefile
│   └── README.md
└── video.mp4
```

## Requirements

### Local C++ verification

The software tests require:

- a C++17 compiler;
- GNU Make;
- Python 3;
- NumPy;
- SystemC only for the optional SystemC demonstration;
- Pillow and Matplotlib only for the visual reconstruction figure.

On Debian or Ubuntu:

```bash
sudo apt update
sudo apt install -y build-essential make python3 python3-numpy \
    python3-pil python3-matplotlib libsystemc-dev
```

### Hardware flow

The hardware flow requires:

- Vitis HLS 2024.1;
- Vivado 2024.1;
- support for part `xck26-sfvc784-2LV-c`;
- a valid license for synthesis and implementation;
- Bash on Linux or PowerShell on Windows.

## Quick verification

From the repository root, run the complete local test suite:

```bash
make -C ProyectoFinal test
```

This command executes:

- forward and inverse equivalence tests;
- source-kernel round-trip verification;
- isolated forward and inverse tests;
- conventional FWHT baseline test;
- multiplier-based forward and inverse baseline tests.

The HLS directives are ignored by the host compiler during these local tests. Warnings such as `ignoring '#pragma HLS ...'` are expected when compiling with `g++`.

## Reference-model experiments

Run only the main reference-model verification:

```bash
make -C ProyectoFinal/Golden verify
```

Run the verification and entropy experiment:

```bash
make -C ProyectoFinal/Golden test
```

Run individual analyses:

```bash
make -C ProyectoFinal/Golden entropy
make -C ProyectoFinal/Golden sweep
make -C ProyectoFinal/Golden visual
make -C ProyectoFinal/Golden systemc
```

The visual target generates a four-panel figure containing the original image, transform coefficients, reconstructed image, and pixel-wise difference.

## Reproducing the hardware flow

Enter the hardware directory:

```bash
cd ProyectoFinal/HLS
```

Check the tool environment:

```bash
./check_environment.sh
```

Run the local code checks before invoking Vitis or Vivado:

```bash
./validate_local.sh
```

Run one variant:

```bash
./run_variant.sh isolated_forward
```

The accepted names are:

```text
main_forward
main_inverse
isolated_forward
isolated_inverse
baseline_forward
baseline_inverse
```

Run the five variants used in the final evaluation:

```bash
./run_variant.sh main_forward
./run_variant.sh main_inverse
./run_variant.sh isolated_forward
./run_variant.sh isolated_inverse
./run_variant.sh baseline_forward
```

Or run the complete prepared set:

```bash
./run_all_variants.sh
```

PowerShell equivalents are included for Windows environments.

## Timing sweep

The controlled forward sweep can be reproduced with:

```bash
./run_comparison_sweep.sh 6.0 5.0 4.5 4.0 3.5 3.0
```

For each period, the script implements the RTL and records the WNS. The smallest tested period with `WNS >= 0` is reported as the maximum demonstrated frequency within the sweep.

The final results were:

| Variant | Fastest tested period that closed | Demonstrated frequency | WNS |
|---|---:|---:|---:|
| `isolated_forward` | 4.0 ns | 250.00 MHz | 0.157 ns |
| `baseline_forward` | 3.5 ns | 285.71 MHz | 0.089 ns |

## Report organization

Every completed hardware variant has a directory under:

```text
ProyectoFinal/HLS/reports/<variant>/
```

The archived evidence includes, where applicable:

```text
hls/                    HLS synthesis reports and XML
simulation/             CSim and C/RTL cosimulation results
post_route/             Utilization, timing, critical path, power, and methodology
inputs/                 Snapshot of source and configuration files
metrics.json            Machine-readable summary
metrics.md              Human-readable summary
manifest.json           Variant and run metadata
```

The consolidated comparison is stored in:

```text
ProyectoFinal/HLS/reports/comparison.md
ProyectoFinal/HLS/reports/comparison.csv
```

Temporary Vitis and Vivado project trees are generated in `ProyectoFinal/HLS/work/` and are intentionally excluded from version control.

## How the reported values should be interpreted

- HLS estimates and post-route values are kept in separate columns.
- AXI-integrated kernels are not compared directly against isolated datapaths.
- The timing-sweep frequency is a demonstrated bound, not an exact physical limit.
- The power reports are vectorless Vivado estimates, not board measurements.
- Resource counts may vary slightly between implementation runs because placement and routing are heuristic.

## Article

The IEEE-format article is stored in `paper/`.

Compile it with:

```bash
cd paper
make
```

The generated file is:

```text
paper/articulo.pdf
```

The article body occupies six pages; references continue on the following page.

## Demonstration video

The repository includes `video.mp4`, with a duration below one minute. It shows the verification flow, exact reconstruction, entropy experiment, and the principal hardware results.

## Scope and limitations

The following limitations should be considered when interpreting the results:

- The synthesized hardware uses `N=8`; larger block sizes were evaluated only in software.
- The hardware transform is one-dimensional; the separable 2D experiment is software-only.
- Forward and inverse are independent synthesizable top functions rather than one runtime-selectable top.
- The project evaluates the transform stage and does not include entropy coding.
- No measurements were taken on a physical KV260 board.
- Vivado power results use vectorless activity estimation.
- The source-level tests use the local compatibility implementation of `ap_int`; RTL behavior is supported separately by C/RTL cosimulation reports.

## Repository

Project source and public history:

[https://github.com/TorikTheGreat/MP6160_grupo_5/tree/proyecto_final_rev2](https://github.com/TorikTheGreat/MP6160_grupo_5/tree/wht_accelerator_project)

## Use of generative tools

Generative tools were used for language review, reference formatting, and consistency checks. The authors reviewed the implementation, executed the experiments, checked the generated reports, and remain responsible for the technical content and conclusions.

## Authors

The complete author names and institutional email addresses are listed in `paper/articulo.pdf`.
