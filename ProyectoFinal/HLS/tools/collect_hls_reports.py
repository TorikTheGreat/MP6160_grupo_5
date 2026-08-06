#!/usr/bin/env python3
"""Collect traceable Vitis HLS reports into reports/<variant>.

The script searches the generated HLS work tree because exact log paths can
change slightly between Vitis HLS releases and patch levels.
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


PATTERNS = {
    "hls": ["*_csynth.rpt", "*_csynth.xml", "csynth.rpt"],
    "simulation": ["*_csim.log", "*_cosim.rpt", "*_cosim.log"],
}


def unique_files(root: Path, patterns: list[str]) -> list[Path]:
    found: dict[str, Path] = {}
    for pattern in patterns:
        for path in root.rglob(pattern):
            if path.is_file():
                found[str(path.resolve())] = path
    return sorted(found.values(), key=lambda p: str(p))


def copy_group(work_root: Path, report_dir: Path, group: str, patterns: list[str]) -> list[str]:
    destination = report_dir / group
    destination.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for source in unique_files(work_root, patterns):
        target = destination / source.name
        # Avoid silent overwrites when two tools emit the same generic name.
        if target.exists() and target.read_bytes() != source.read_bytes():
            target = destination / f"{source.parent.name}_{source.name}"
        shutil.copy2(source, target)
        copied.append(str(target.relative_to(report_dir)))
    return copied


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-root", required=True, type=Path)
    parser.add_argument("--report-dir", required=True, type=Path)
    parser.add_argument("--variant", required=True)
    parser.add_argument("--top", required=True)
    parser.add_argument("--part", required=True)
    parser.add_argument("--hls-clock-ns", required=True, type=float)
    parser.add_argument("--source", required=True)
    parser.add_argument("--testbench", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--solution", required=True)
    args = parser.parse_args()

    work_root = args.work_root.resolve()
    report_dir = args.report_dir.resolve()
    if not work_root.exists():
        raise SystemExit(f"HLS work directory does not exist: {work_root}")

    report_dir.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for group, patterns in PATTERNS.items():
        copied.extend(copy_group(work_root, report_dir, group, patterns))

    manifest = {
        "variant": args.variant,
        "top": args.top,
        "part": args.part,
        "hls_clock_ns": args.hls_clock_ns,
        "source": args.source,
        "testbench": args.testbench,
        "project": args.project,
        "solution": args.solution,
        "work_root": str(work_root),
        "collected_at_utc": datetime.now(timezone.utc).isoformat(),
        "files": copied,
    }
    (report_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    if not any(name.endswith("_csynth.xml") for name in copied):
        print("WARNING: no *_csynth.xml file was found.")
    if not any(name.endswith("_cosim.rpt") for name in copied):
        print("WARNING: no *_cosim.rpt file was found (cosim may have been disabled).")

    print(f"Collected {len(copied)} HLS evidence files in {report_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
