# Metrics — isolated_forward

| Metric | Value |
|---|---:|
| Top | wht_lossless_forward_isolated |
| Part | xck26-sfvc784-2LV-c |
| HLS estimated period (ns) | 2.904 |
| HLS latency best (cycles) | 17 |
| HLS latency worst (cycles) | 17 |
| HLS II min (cycles) | 9 |
| HLS LUT | 880 |
| HLS FF | 562 |
| HLS DSP | 0 |
| HLS BRAM_18K | 0 |
| Post-route requested period (ns) | 10.000 |
| Post-route WNS (ns) | 5.323 |
| Post-route timing closed | yes |
| Post-route LUT | 501 |
| Post-route FF | 424 |
| Post-route DSP | 0 |
| Post-route BRAM tiles | 1.500 |

## Interpretation

- HLS values and post-route values are reported separately.
- A requested Vivado period is considered demonstrated only when WNS is non-negative.
- Do not label `1000 / datapath_delay` or the WNS extrapolation as the final fmax.
- Use `run_timing_sweep` and report the smallest tested period that closes timing.
