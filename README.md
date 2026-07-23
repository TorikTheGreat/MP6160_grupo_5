# Reversible WHT Accelerator for Lossless Compression

Final project for the **MP-6160 High-Level Design** course, developed by Group 5.

This repository contains the design, verification, and preliminary results of a hardware accelerator for an **integer reversible Walsh-Hadamard Transform (WHT)**. The proposed design uses a lifting-based architecture composed only of additions, subtractions, and shifts, with the objective of avoiding multipliers and achieving an implementation with **0 DSP usage**.

## Project Objective

Implement and evaluate a one-dimensional WHT core for blocks of eight samples (`N=8`), intended for data decorrelation in lossless compression applications. The project includes:

- A synthesizable C++ core for Vitis HLS.
- A reference golden model in C++ and SystemC.
- Bit-exact verification and lossless reconstruction tests.
- A reproducible synthesis and implementation flow.
- Preliminary entropy-reduction experiments.
- A functional conventional FWHT baseline.
- An IEEE-format technical paper.

## Proposed Architecture

The core processes one-dimensional blocks of eight samples through three stages of reversible butterflies. Each butterfly uses a lifting-based construction:

- The high-frequency component is obtained through subtraction.
- The low-frequency component is obtained through subtraction and an arithmetic shift.
- No multipliers are used.

The implementation uses `ap_int<16>` data types and the HLS directives `PIPELINE` and `UNROLL`. The core interfaces use AXI4 Memory-Mapped for data transfer and AXI4-Lite for control.

## Repository Structure

```text
MP6160_grupo_5/
├── README.md
├── ProyectoFinal/
│   ├── Source/                 # Synthesizable WHT core
│   │   ├── wht_core.cpp
│   │   └── wht_core.h
│   ├── TB/                     # Basic core testbench
│   │   └── wht_core_tb.cpp
│   ├── Golden/                 # Reference model and verification
│   │   ├── src/
│   │   ├── tb/
│   │   ├── systemc/
│   │   ├── data/
│   │   ├── analysis/
│   │   ├── Makefile
│   │   └── README.md
│   ├── HLS/                    # Reproducible synthesis and implementation flow
│   │   ├── run_w2_hls.tcl
│   │   ├── run_w2.ps1
│   │   ├── run_w2.sh
│   │   ├── run_vivado_impl.tcl
│   │   ├── metrics_prelim.md
│   │   ├── metrics_impl.md
│   │   └── README.md
│   └── Baseline/               # Conventional FWHT for comparison
│       ├── fwht_baseline.cpp
│       ├── fwht_baseline.h
│       ├── fwht_baseline_tb.cpp
│       └── baseline_result.txt
└── paper/                       # IEEE-format paper
│   ├── articulo.tex
│   ├── articulo.pdf
│   ├── wht_architecture.png
│   └── Makefile
└── video.mp4
```


## Tools Used

- C++17.
- SystemC.
- Python 3 and NumPy.
- Vitis HLS 2024.1.
- Vivado 2024.1.
- LaTeX with the `IEEEtran` class.
- Target implementation platform: Kria KV260.

## Verification Requirements

The following tools are required to run the reference-model tests:

- `g++` with C++17 support.
- `make`.
- Python 3.
- NumPy.
- SystemC, only for the demonstration executed with `make systemc`.

On Debian or Ubuntu, the basic tools can be installed with:

```bash
sudo apt update
sudo apt install -y build-essential make python3 python3-numpy libsystemc-dev
```

## Functional Verification

From the repository root, run:

```bash
make -C ProyectoFinal/Golden verify
```

This test performs:

- Bit-exact comparison between the golden model and the W1 core.
- Evaluation using one fixed vector and 100,000 random blocks.
- Lossless reconstruction verification using `inverse(forward(x)) == x`.
- Evaluation of 400,000 blocks.
- Verification that the 16-bit format is sufficient for 8-bit input samples.

To run all tests, including the entropy analysis:

```bash
make -C ProyectoFinal/Golden test
```

Additional available commands:

```bash
make -C ProyectoFinal/Golden systemc
make -C ProyectoFinal/Golden entropy
make -C ProyectoFinal/Golden datasets
make -C ProyectoFinal/Golden clean
```

## Verification Results

| Test | Result |
|---|---:|
| Golden model vs. core equivalence | 100,001 / 100,001 correct cases |
| Lossless reconstruction | 400,001 / 400,001 correct cases |
| Overflow errors for 8-bit inputs | 0 |

Equivalence was verified at the C++ source level against the HLS core. The inverse transform is used in the golden model to demonstrate exact reconstruction, while the implemented hardware core performs the forward transform.

## Entropy-Reduction Experiment

Zero-order entropy was evaluated using five deterministic datasets of 256 × 256 pixels. The primary metric corresponds to the one-dimensional WHT applied to blocks of eight samples, matching the architecture implemented in hardware.

| Dataset | Original entropy | 1D band entropy | Change |
|---|---:|---:|---:|
| Flat | 0.000 | 0.000 | Degenerate case |
| Ramp | 8.000 | 0.625 | 92% reduction |
| Edges | 2.000 | 0.250 | 87% reduction |
| Natural | 7.304 | 5.808 | 20% reduction |
| Noise | 7.997 | 8.200 | −2.5% |

The results show that entropy reduction depends on the spatial correlation of the data. Smooth signals and regions with constant values achieve a significant reduction, while white noise is used as a control case and does not show an improvement.

The 2D extension was evaluated only in software as possible future work and is not part of the current hardware core.

## Synthesis and Implementation

The functional simulation and synthesis of the accelerator were carried out using the Vitis HLS and Vivado flow, with the Kria KV260 considered as the target implementation platform. This process produced preliminary metrics for resource utilization, latency, maximum frequency, and throughput.

Complete instructions are available in:

```text
ProyectoFinal/HLS/README.md
```

### Linux Flow

From `ProyectoFinal/HLS`:

```bash
chmod +x ./run_w2.sh ./run_vivado_impl.sh \
  ./extract_metrics.sh ./extract_impl_metrics.sh

./run_w2.sh
./run_vivado_impl.sh
```

When Vitis HLS or Vivado are not available in the `PATH`, their executable paths can be provided explicitly:

```bash
./run_w2.sh /tools/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls
./run_vivado_impl.sh /tools/Xilinx/Vivado/2024.1/bin/vivado
```

### Windows Flow

From PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_w2.ps1 \
  -VitisHlsExe "C:\Xilinx\Vitis_HLS\2024.1\bin\vitis_hls.bat"

powershell -ExecutionPolicy Bypass -File .\run_vivado_impl.ps1
```

## Hardware Results

### HLS Synthesis

| Metric | Result |
|---|---:|
| Estimated frequency | 342.47 MHz |
| Latency | 150 cycles |
| Initiation interval | 1 cycle |
| LUT | 3609 |
| FF | 3386 |
| DSP | 0 |
| BRAM_18K | 8 |
| Estimated throughput | 342.47 M blocks/s |
| Throughput for N=8 | 2739.76 M samples/s |

### Post-Route Implementation

| Metric | Result |
|---|---:|
| Implemented frequency | 339.21 MHz |
| Critical-path delay | 2.948 ns |
| WNS | 6.604 ns |
| LUT | 2404 |
| FF | 2599 |
| DSP | 0 |
| BRAM tiles | 4 |

The most relevant result is that the core maintains a multiplier-free architecture and reports **0 DSP usage** in both HLS synthesis and post-route implementation.

## Baseline

The `ProyectoFinal/Baseline` directory contains a functional implementation of a conventional FWHT. The included testbench compares its output against an expected vector and reports `PASS`.

This baseline is used as a functional reference. A complete quantitative comparison of resources and performance against the proposed architecture remains as future work.

## Paper

The project paper is located in the `paper/` directory and follows the IEEE conference format.

To compile it on Linux:

```bash
cd paper
make
```

The generated file is:

```text
paper/articulo.pdf
```

## Reproducibility

The included scripts, datasets, and results make it possible to reproduce:

- Functional verification of the core.
- Exact reconstruction tests.
- The entropy experiment.
- HLS synthesis.
- Post-route implementation.

Small timing variations may occur when different versions or patch levels of Vitis HLS and Vivado are used.

## Demonstration Video

A short demonstration video of the reversible WHT accelerator is included in
this repository:

[Watch the demonstration video](video.mp4)

The video presents:

- Functional verification of the WHT core.
- Bit-exact comparison against the SystemC reference model.
- Lossless reconstruction and overflow verification.
- Preliminary entropy-reduction experiments.
- Synthesis and implementation metrics, including zero DSP utilization.

## Repository

Source code and project materials:

https://github.com/MP6160-Grupo-5/MP6160_grupo_5

## Use of Artificial Intelligence

Artificial intelligence assistants were used during development to support:

- Consultation and clarification of concepts related to the reversible WHT.
- Search and review of the state of the art.
- Support in the design of the reference model, testbenches, and experiments.
- Review of scripts, documentation, and preliminary writing.
- Repository organization and paper review.

The group members reviewed the results, verified the tests, and assumed responsibility for the design, implementation, interpretation of the data, and final version of the deliverables. The detailed declaration and representative prompts are included in the paper.

## Authors

Group 5 — MP-6160 High-Level Design.

The complete names and institutional email addresses are included in the final paper.
