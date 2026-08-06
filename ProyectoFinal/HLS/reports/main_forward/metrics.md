# Metrics — main_forward

| Metric | Value |
|---|---:|
| Top | wht_lossless_core |
| Part | xck26-sfvc784-2LV-c |
| HLS estimated period (ns) | 2.920 |
| HLS latency best (cycles) | 143 |
| HLS latency worst (cycles) | 143 |
| HLS II min (cycles) | 1 |
| HLS LUT | 1773 |
| HLS FF | 1847 |
| HLS DSP | 0 |
| HLS BRAM_18K | 16 |
| Post-route requested period (ns) | 10.000 |
| Post-route WNS (ns) | 4.292 |
| Post-route timing closed | yes |
| Post-route LUT | 2340 |
| Post-route FF | 2716 |
| Post-route DSP | 0 |
| Post-route BRAM tiles | 4 |

## Interpretation

- HLS values and post-route values are reported separately.
- A requested Vivado period is considered demonstrated only when WNS is non-negative.
- Do not label `1000 / datapath_delay` or the WNS extrapolation as the final fmax.
- Use `run_timing_sweep` and report the smallest tested period that closes timing.
