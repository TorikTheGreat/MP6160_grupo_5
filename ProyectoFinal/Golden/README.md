# Golden WHT model, verification, and entropy analysis

This directory contains the C++ reference implementation, a SystemC wrapper for the forward-path demonstration, the forward and inverse equivalence tests, deterministic image datasets, and the entropy experiments.

## Requirements

- `g++` with C++17 support.
- SystemC (`libsystemc`) for `make systemc`.
- Python 3 and NumPy for dataset generation.
- Pillow and Matplotlib for the optional visual panel.

## Directory structure

```text
compat/    Portable ap_int compatibility layer used outside Vitis
src/       Forward and inverse reference functions
systemc/   SystemC wrapper and demonstration testbench
tb/        Equivalence, reconstruction, and overflow tests
data/      Deterministic PGM dataset generator
analysis/  Entropy experiment, block-size sweep, and visual generator
```

## Commands

```bash
make test      # equivalence, reconstruction, and entropy analysis
make verify    # forward/inverse equivalence and both round-trip tests
make systemc   # forward-path SystemC demonstration
make entropy   # entropy experiment on the five datasets
make sweep     # software sweep for N=8, 16, and 32
make visual    # original/coefficient/reconstruction/difference panel
make datasets  # regenerate the PGM datasets
make clean
```

## Verification coverage

- The forward kernel is compared with the reference model using one fixed block and 100,000 random 8-bit blocks.
- The inverse kernel is compared independently over signed 16-bit coefficient blocks.
- `tb_roundtrip_hw.cpp` links the two synthesizable source functions and verifies 400,001 exact reconstructions.
- A wider arithmetic reference confirms that 16 bits are sufficient for 8-bit inputs in the implemented length-8 transform.
- The software-only block-size sweep evaluates N=8, 16, and 32. Hardware synthesis is limited to N=8.

The portable tests run at C++ source level. RTL equivalence is covered separately by the C/RTL cosimulation reports under `ProyectoFinal/HLS/reports/`.

Detailed entropy results are documented in `analysis/RESULTS.md`.

## Use of generative tools

Generative tools supported code review and language revision. The test programs, datasets, outputs, and numerical claims were executed and checked by the authors.
