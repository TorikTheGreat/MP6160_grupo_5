# Hardware comparison

HLS and post-route values are kept in separate columns. Compare designs only when interfaces, part, clock constraints, and report stages match.

| Variant | HLS lat. | HLS II | HLS LUT | HLS FF | HLS DSP | Route LUT | Route FF | Route DSP | Route BRAM | Period ns | WNS ns | Closed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| baseline_forward | 17 | 9 | 926 | 823 | 12 | 500 | 377 | 11 | 1.5 | 10.0 | 5.513 | yes |
| isolated_forward | 17 | 9 | 880 | 562 | 0 | 501 | 424 | 0 | 1.5 | 10.0 | 5.323 | yes |
| isolated_inverse | 17 | 9 | 903 | 607 | 0 | 565 | 409 | 0 | 1.5 | 10.0 | 5.427 | yes |
| main_forward | 143 | 1 | 1773 | 1847 | 0 | 2340 | 2716 | 0 | 4 | 10.0 | 4.292 | yes |
| main_inverse | 143 | 1 | 1773 | 1907 | 0 | 2366 | 2716 | 0 | 4 | 10.0 | 5.98 | yes |

The controlled forward comparison uses `isolated_forward` and `baseline_forward`, which share the same target, interface style, and implementation flow.
Forward and inverse results are reported separately because they are synthesized as independent top functions.
