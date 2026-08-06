# Metrics — baseline_forward

| Metric | Value |
|---|---:|
| Top | wht_multiplier_forward |
| Part | xck26-sfvc784-2LV-c |
| HLS estimated period (ns) | 2.383 |
| HLS latency best (cycles) | 17 |
| HLS latency worst (cycles) | 17 |
| HLS II min (cycles) | 9 |
| HLS LUT | 926 |
| HLS FF | 823 |
| HLS DSP | 12 |
| HLS BRAM_18K | 0 |
| Post-route requested period (ns) | 10.000 |
| Post-route WNS (ns) | 5.513 |
| Post-route timing closed | yes |
| Post-route LUT | 500 |
| Post-route FF | 377 |
| Post-route DSP | 11 |
| Post-route BRAM tiles | 1.500 |

## Interpretation

- HLS values and post-route values are reported separately.
- A requested Vivado period is considered demonstrated only when WNS is non-negative.
- Do not label `1000 / datapath_delay` or the WNS extrapolation as the final fmax.
- Use `run_timing_sweep` and report the smallest tested period that closes timing.
