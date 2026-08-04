# Implemented Hardware Metrics (Post-Route)

Source: Vivado 2024.1 post-route reports.

| Metric | Value |
|---|---|
| Critical data path delay (ns) | 4.116 |
| Implemented fmax (MHz) | 242.95 |
| WNS (ns) | 5.817 |
| LUT | 2339 |
| FF | 2716 |
| DSP | 0 |
| BRAM tile | 4 |

## Critical path decomposition

- Logic delay (ns): 1.991
- Routing delay (ns): 2.125

## Notes

- fmax is computed as 1000 / critical_data_path_delay.
- This post-route value is more representative than csynth timing estimates.
