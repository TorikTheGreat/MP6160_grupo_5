#!/usr/bin/env python3
"""Create metrics.json and metrics.md from HLS and post-route reports."""

from __future__ import annotations

import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def first_xml_value(root: ET.Element, wanted: str) -> str | None:
    for node in root.iter():
        if local_name(node.tag) == wanted and node.text and node.text.strip():
            return node.text.strip()
    return None


def as_float(value: str | None) -> float | None:
    if value in (None, "", "N/A"):
        return None
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return None


def as_int_or_float(value: str | None) -> int | float | None:
    number = as_float(value)
    if number is None:
        return None
    return int(number) if number.is_integer() else number


def find_csynth_xml(report_dir: Path, top: str) -> Path | None:
    preferred = list(report_dir.glob(f"hls/{top}_csynth.xml"))
    candidates = preferred or list(report_dir.glob("hls/*_csynth.xml"))
    return candidates[0] if candidates else None


def parse_hls(report_dir: Path, top: str) -> dict[str, Any]:
    xml_path = find_csynth_xml(report_dir, top)
    if xml_path is None:
        return {"available": False}

    root = ET.parse(xml_path).getroot()
    values = {
        "estimated_clock_ns": as_float(first_xml_value(root, "EstimatedClockPeriod")),
        "latency_best_cycles": as_int_or_float(first_xml_value(root, "Best-caseLatency")),
        "latency_worst_cycles": as_int_or_float(first_xml_value(root, "Worst-caseLatency")),
        "pipeline_depth_cycles": as_int_or_float(first_xml_value(root, "PipelineDepth")),
        "ii_min_cycles": as_int_or_float(first_xml_value(root, "Interval-min")),
        "ii_max_cycles": as_int_or_float(first_xml_value(root, "Interval-max")),
        "lut": as_int_or_float(first_xml_value(root, "LUT")),
        "ff": as_int_or_float(first_xml_value(root, "FF")),
        "dsp": as_int_or_float(first_xml_value(root, "DSP")),
        "bram_18k": as_int_or_float(first_xml_value(root, "BRAM_18K")),
    }
    period = values["estimated_clock_ns"]
    ii = values["ii_min_cycles"]
    if isinstance(period, (int, float)) and period > 0:
        values["estimated_frequency_mhz"] = 1000.0 / period
        if isinstance(ii, (int, float)) and ii > 0:
            values["estimated_block_throughput_mblocks_s"] = (1000.0 / period) / ii
            values["estimated_sample_throughput_msamples_s"] = ((1000.0 / period) / ii) * 8.0
    values.update({"available": True, "source_xml": str(xml_path)})
    return values


def parse_key_value(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    if not path.exists():
        return result
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def report_table_value(text: str, labels: list[str]) -> float | int | None:
    for label in labels:
        pattern = rf"\|\s*{label}\s*\|\s*([0-9,]+(?:\.[0-9]+)?)\s*\|"
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return as_int_or_float(match.group(1))
    return None


def parse_power_value(path: Path, label: str) -> float | None:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8", errors="ignore")
    pattern = rf"\|\s*{re.escape(label)}\s*\|\s*([0-9,]+(?:\.[0-9]+)?)\s*\|"
    match = re.search(pattern, text, flags=re.IGNORECASE)
    if not match:
        return None
    return as_float(match.group(1))


def parse_vivado(report_dir: Path) -> dict[str, Any]:
    post = report_dir / "post_route"
    if not post.exists():
        # Compatibility with an older flat report layout.
        post = report_dir
    util = post / "utilization_post_route.rpt"
    summary = post / "impl_summary.txt"
    if not util.exists() and not summary.exists():
        return {"available": False}

    util_text = util.read_text(encoding="utf-8", errors="ignore") if util.exists() else ""
    power_report = post / "power_post_route.rpt"
    kv = parse_key_value(summary)
    timing_report = post / "timing_post_route.rpt"
    timing_text = timing_report.read_text(encoding="utf-8", errors="ignore") if timing_report.exists() else ""
    requested_period = as_float(kv.get("requested_period_ns"))
    if requested_period is None:
        match = re.search(r"Requirement:\s*([0-9.]+)ns", timing_text, flags=re.IGNORECASE)
        if not match:
            match = re.search(r"Period\(ns\):\s*([0-9.]+)", timing_text, flags=re.IGNORECASE)
        if match:
            requested_period = as_float(match.group(1))

    result: dict[str, Any] = {
        "available": True,
        "part": kv.get("part"),
        "top": kv.get("top"),
        "requested_period_ns": requested_period,
        "wns_ns": as_float(kv.get("wns_ns")),
        "datapath_delay_ns": as_float(kv.get("datapath_delay_ns")),
        "wns_extrapolated_period_ns": as_float(kv.get("wns_extrapolated_period_ns")),
        "wns_extrapolated_frequency_mhz": as_float(kv.get("wns_extrapolated_frequency_mhz")),
        "route_status": kv.get("route_status"),
        "lut": report_table_value(util_text, [r"CLB LUTs\*?", r"Slice LUTs"]),
        "ff": report_table_value(util_text, [r"CLB Registers", r"Slice Registers"]),
        "dsp": report_table_value(util_text, [r"DSP(?: Slices|s)?"]),
        "bram_tiles": report_table_value(util_text, [r"Block RAM Tile"]),
        "total_on_chip_power_w": parse_power_value(power_report, "Total On-Chip Power (W)"),
    }
    period = result["requested_period_ns"]
    wns = result["wns_ns"]
    if isinstance(period, (int, float)) and period > 0:
        result["requested_frequency_mhz"] = 1000.0 / period
        result["timing_closed"] = isinstance(wns, (int, float)) and wns >= 0.0
    return result


def fmt(value: Any, digits: int = 3) -> str:
    if value is None:
        return "N/A"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report-dir", required=True, type=Path)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--top", required=True)
    parser.add_argument("--part", required=True)
    args = parser.parse_args()

    report_dir = args.report_dir.resolve()
    report_dir.mkdir(parents=True, exist_ok=True)
    hls = parse_hls(report_dir, args.top)
    vivado = parse_vivado(report_dir)

    metrics = {
        "variant": args.variant,
        "top": args.top,
        "part": args.part,
        "hls": hls,
        "post_route": vivado,
        "notes": [
            "HLS timing is an estimate from csynth.",
            "A Vivado requested clock is validated only when WNS is non-negative.",
            "The WNS-extrapolated frequency is not a measured fmax; use the timing sweep for the smallest tested closing period.",
        ],
    }
    (report_dir / "metrics.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    rows = [
        ("Top", args.top),
        ("Part", args.part),
        ("HLS estimated period (ns)", hls.get("estimated_clock_ns")),
        ("HLS latency best (cycles)", hls.get("latency_best_cycles")),
        ("HLS latency worst (cycles)", hls.get("latency_worst_cycles")),
        ("HLS II min (cycles)", hls.get("ii_min_cycles")),
        ("HLS LUT", hls.get("lut")),
        ("HLS FF", hls.get("ff")),
        ("HLS DSP", hls.get("dsp")),
        ("HLS BRAM_18K", hls.get("bram_18k")),
        ("Post-route requested period (ns)", vivado.get("requested_period_ns")),
        ("Post-route WNS (ns)", vivado.get("wns_ns")),
        ("Post-route timing closed", vivado.get("timing_closed")),
        ("Post-route LUT", vivado.get("lut")),
        ("Post-route FF", vivado.get("ff")),
        ("Post-route DSP", vivado.get("dsp")),
        ("Post-route BRAM tiles", vivado.get("bram_tiles")),
        ("Post-route total on-chip power (W)", vivado.get("total_on_chip_power_w")),
    ]
    lines = [
        f"# Metrics — {args.variant}",
        "",
        "| Metric | Value |",
        "|---|---:|",
    ]
    lines.extend(f"| {name} | {fmt(value)} |" for name, value in rows)
    lines += [
        "",
        "## Interpretation",
        "",
        "- HLS values and post-route values are reported separately.",
        "- A requested Vivado period is considered demonstrated only when WNS is non-negative.",
        "- Do not label `1000 / datapath_delay` or the WNS extrapolation as the final fmax.",
        "- Use `run_timing_sweep` and report the smallest tested period that closes timing.",
        "",
    ]
    (report_dir / "metrics.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {report_dir / 'metrics.json'}")
    print(f"Wrote {report_dir / 'metrics.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
