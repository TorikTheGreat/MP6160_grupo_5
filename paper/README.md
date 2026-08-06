# IEEE article

This directory contains the conference-format article, its figures, and the local build files.

## Files

```text
articulo.tex             LaTeX source
articulo.pdf             Compiled article
wht_architecture.png     Proposed architecture
wht_reconstruction.png   Original, coefficients, reconstruction, and difference
IEEEtran.cls             IEEE conference class
Makefile                 Local compilation commands
```

## Build

Install a standard TeX Live environment with `latexmk`, then run:

```bash
make
```

Useful commands:

```bash
make watch
make clean
```

The article body occupies six pages. References continue on the following page, consistent with the project requirement that excludes references from the page limit.

## Result traceability

The hardware values in the article are taken from `ProyectoFinal/HLS/reports/`. The controlled forward comparison uses `isolated_forward` and `baseline_forward`; the AXI forward and inverse figures are reported separately because they include interface logic.

## Use of generative tools

Generative tools were used for language review, reference formatting, and consistency checks. The authors verified the cited sources, code, reports, and final numerical values.
