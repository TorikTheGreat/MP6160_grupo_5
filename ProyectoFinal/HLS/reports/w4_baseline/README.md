# W4 Multiplier-Based WHT Baseline

## Objective

This work implements a multiplier-based baseline for the reversible Walsh–Hadamard Transform (WHT). The objective is to provide a hardware reference for comparison with the multiplier-free architecture developed in this project while preserving the same reversible and lossless behavior.

---

## Design Overview

The baseline uses the same three-stage butterfly architecture as the main WHT implementation. The only architectural difference is the scaling operation used to calculate one half:

- **Multiplier-free implementation:** arithmetic shift (`>>1`)
- **Baseline implementation:** fixed-point Q1.15 multiplication

Since the remaining architecture is identical, both implementations can be compared under the same verification flow and hardware conditions.

---

## Verification

The baseline successfully completed all verification stages.

| Verification Step | Result |
|-------------------|:------:|
| C Simulation | PASS |
| HLS Synthesis | PASS |
| C/RTL Co-simulation | PASS |
| Vivado Post-route | PASS |

The forward and inverse transforms correctly reconstructed the original input samples, confirming the reversible and lossless behavior of the design.

---

## Hardware Results

Target device: **AMD Kria KV260** (`xck26-sfvc784-2LV-c`)

| Metric | Value |
|--------------------------|------:|
| CLB LUTs | 500 |
| CLB Registers | 377 |
| DSPs | 11 |
| Block RAM Tiles | 1.5 |
| Worst Negative Slack (WNS) | 5.263 ns |
| Critical Path Delay | 4.143 ns |

The multiplier-based implementation uses DSP resources because the scaling stage is implemented using fixed-point multiplication. These reports provide the hardware reference for comparison with the multiplier-free implementation.

---

## Files

| File | Description |
|------|-------------|
| `impl_summary.txt` | Post-route timing summary |
| `timing_post_route.rpt` | Vivado timing report |
| `utilization_post_route.rpt` | Vivado utilization report |
| `README.md` | Documentation for the W4 baseline |

---

## AI Declaration

Durante el desarrollo de este trabajo utilicé herramientas de inteligencia artificial como apoyo para mejorar la redacción en inglés, revisar aspectos de gramática y resolver dudas puntuales relacionadas con HLS y FPGA.

La implementación del código, las decisiones de diseño, la ejecución de las pruebas y la validación de los resultados fueron realizadas y verificadas por el autor antes de incorporarlas al proyecto.
