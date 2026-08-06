# Hardware reports

This directory contains the HLS and Vivado evidence used in the article. The original synthesis, cosimulation, utilization, timing, power, and methodology reports are stored beside the generated summaries.

## Available results

- `main_forward/`: forward kernel with AXI interfaces.
- `main_inverse/`: inverse kernel with AXI interfaces.
- `isolated_forward/`: multiplier-free forward datapath.
- `isolated_inverse/`: multiplier-free inverse datapath.
- `baseline_forward/`: multiplier-based forward comparison.

## Files kept for each variant

```text
inputs/
hls/*_csynth.rpt
hls/*_csynth.xml
simulation/*_cosim.rpt
post_route/utilization_post_route.rpt
post_route/timing_post_route.rpt
post_route/timing_critical_path.rpt
post_route/power_post_route.rpt
post_route/methodology_post_route.rpt
post_route/impl_summary.txt
manifest.json
metrics.json
metrics.md
```

The timing sweeps for `isolated_forward` and `baseline_forward` are stored inside their corresponding folders.

Regenerate the combined tables with:

```bash
python3 ../tools/build_comparison.py --reports-dir .
```

HLS and post-route values represent different stages of the flow and are kept in separate columns. Only designs with matching interfaces and constraints should be compared directly.
