# W2 Implemented Hardware Metrics (Post-Route)

Source: Vivado 2024.1 post-route reports.

| Metric | Value |
|---|---|
| Critical data path delay (ns) | 2.948 |
| Implemented fmax (MHz) | 339.21 |
| WNS (ns) | 6.604 |
| LUT | 2404 |
| FF | 2599 |
| DSP | 0 |
| BRAM tile | 4 |

## Critical path decomposition

- Logic delay (ns): 0.293
- Routing delay (ns): 2.655

## Notes

- fmax is computed as 1000 / critical_data_path_delay.
- This post-route value is more representative than csynth timing estimates.
