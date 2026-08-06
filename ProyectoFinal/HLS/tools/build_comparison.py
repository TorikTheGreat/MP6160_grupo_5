#!/usr/bin/env python3
"""Build consolidated CSV/Markdown tables from reports/*/metrics.json."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def get(data: dict[str, Any], *keys: str) -> Any:
    value: Any = data
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reports-dir", required=True, type=Path)
    args = parser.parse_args()
    reports = args.reports_dir.resolve()

    rows: list[dict[str, Any]] = []
    for path in sorted(reports.glob("*/metrics.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        rows.append({
            "variant": data.get("variant"),
            "top": data.get("top"),
            "hls_latency_best": get(data, "hls", "latency_best_cycles"),
            "hls_ii": get(data, "hls", "ii_min_cycles"),
            "hls_lut": get(data, "hls", "lut"),
            "hls_ff": get(data, "hls", "ff"),
            "hls_dsp": get(data, "hls", "dsp"),
            "hls_bram18k": get(data, "hls", "bram_18k"),
            "route_period_ns": get(data, "post_route", "requested_period_ns"),
            "route_wns_ns": get(data, "post_route", "wns_ns"),
            "route_closed": get(data, "post_route", "timing_closed"),
            "route_lut": get(data, "post_route", "lut"),
            "route_ff": get(data, "post_route", "ff"),
            "route_dsp": get(data, "post_route", "dsp"),
            "route_bram_tiles": get(data, "post_route", "bram_tiles"),
            "route_power_w": get(data, "post_route", "total_on_chip_power_w"),
        })

    fields = list(rows[0].keys()) if rows else ["variant"]
    with (reports / "comparison.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    lines = [
        "# Hardware comparison",
        "",
        "HLS and post-route values are kept in separate columns. Compare designs only when interfaces, part, clock constraints, and report stages match.",
        "",
        "| Variant | HLS lat. | HLS II | HLS LUT | HLS FF | HLS DSP | Route LUT | Route FF | Route DSP | Route BRAM | Route power W | Period ns | WNS ns | Closed |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|",
    ]
    for row in rows:
        def v(name: str) -> str:
            value = row.get(name)
            if value is None:
                return "—"
            if isinstance(value, bool):
                return "yes" if value else "no"
            return str(value)
        lines.append(
            f"| {v('variant')} | {v('hls_latency_best')} | {v('hls_ii')} | {v('hls_lut')} | {v('hls_ff')} | {v('hls_dsp')} | {v('route_lut')} | {v('route_ff')} | {v('route_dsp')} | {v('route_bram_tiles')} | {v('route_power_w')} | {v('route_period_ns')} | {v('route_wns_ns')} | {v('route_closed')} |"
        )
    lines += [
        "",
        "The controlled forward comparison uses `isolated_forward` and `baseline_forward`, which share the same target, interface style, and implementation flow.",
        "Forward and inverse results are reported separately because they are synthesized as independent top functions.",
        "",
    ]
    (reports / "comparison.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {reports / 'comparison.csv'} and {reports / 'comparison.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
