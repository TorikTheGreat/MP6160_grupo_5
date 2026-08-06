#!/usr/bin/env python3
"""Summarize timing sweep runs and select the smallest tested closing period."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def parse_kv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def f(value: str | None) -> float | None:
    try:
        return float(value) if value is not None else None
    except ValueError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sweep-dir", required=True, type=Path)
    parser.add_argument("--variant", required=True)
    args = parser.parse_args()

    sweep_dir = args.sweep_dir.resolve()
    rows: list[dict[str, object]] = []
    for summary in sorted(sweep_dir.glob("*/impl_summary.txt")):
        kv = parse_kv(summary)
        period = f(kv.get("requested_period_ns"))
        wns = f(kv.get("wns_ns"))
        if period is None:
            continue
        rows.append({
            "period_ns": period,
            "requested_frequency_mhz": 1000.0 / period,
            "wns_ns": wns,
            "closed": wns is not None and wns >= 0.0,
            "report_dir": str(summary.parent),
        })

    rows.sort(key=lambda row: float(row["period_ns"]), reverse=True)
    passing = [row for row in rows if bool(row["closed"])]
    best = min(passing, key=lambda row: float(row["period_ns"])) if passing else None

    with (sweep_dir / "timing_sweep_summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["period_ns", "requested_frequency_mhz", "wns_ns", "closed", "report_dir"])
        writer.writeheader()
        writer.writerows(rows)

    payload = {
        "variant": args.variant,
        "runs": rows,
        "smallest_tested_closing_period": best,
        "warning": "This is the smallest tested closing period, not an exact mathematical fmax.",
    }
    (sweep_dir / "timing_sweep_summary.json").write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        f"# Timing sweep — {args.variant}",
        "",
        "| Requested period (ns) | Requested frequency (MHz) | WNS (ns) | Closed |",
        "|---:|---:|---:|:---:|",
    ]
    for row in rows:
        wns = "N/A" if row["wns_ns"] is None else f"{float(row['wns_ns']):.3f}"
        lines.append(
            f"| {float(row['period_ns']):.3f} | {float(row['requested_frequency_mhz']):.2f} | {wns} | {'yes' if row['closed'] else 'no'} |"
        )
    lines += [""]
    if best:
        lines += [
            f"Smallest tested period that closed timing: **{float(best['period_ns']):.3f} ns** ",
            f"(**{float(best['requested_frequency_mhz']):.2f} MHz**, WNS={float(best['wns_ns']):.3f} ns).",
        ]
    else:
        lines.append("No tested period closed timing.")
    lines += ["", "This is a tested bound, not an exact fmax.", ""]
    (sweep_dir / "timing_sweep_summary.md").write_text("\n".join(lines), encoding="utf-8")

    print(f"Summarized {len(rows)} timing runs in {sweep_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
