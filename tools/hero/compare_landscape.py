#!/usr/bin/env python3
"""Assemble the v7/v8/v9 comparison from committed baselines and the final grid.

Run with nice -n 10, after capture_grid.cjs. No browser renders are performed.
The v7 vista cell is explicitly empty because that camera did not exist.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/evidence/hero"
GRID = EVIDENCE / "grid"
BASELINES = {"v7": "3a07527^", "v8": "0f23d02"}


def committed(revision, path):
    return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=ROOT)


def main():
    metrics = json.loads((GRID / "metrics.json").read_text())
    assert len(metrics["frames"]) == 16, "capture the full 16-frame grid first"
    assert all(f["pass"]["all"] for f in metrics["frames"]), "grid must pass"
    baseline = json.loads(committed(BASELINES["v8"], "docs/evidence/hero/grid/metrics.json"))
    before = {f["name"]: f for f in baseline["frames"]}
    hashes = {}
    with tempfile.TemporaryDirectory(prefix="p0-land-v9-comparison-") as work:
        cells = []
        for camera in ["mid", "far", "vista"]:
            for version in ["v7", "v8", "v9"]:
                label = f"{version} / golden-{camera}"
                cell = Path(work) / f"{version}-{camera}.png"
                if version == "v7" and camera == "vista":
                    subprocess.run(["convert", "-size", "640x400", "xc:#202020",
                                    "-fill", "#cccccc", "-pointsize", "22", "-gravity", "center",
                                    "-annotate", "0", "Vista camera added in v8", str(cell)], check=True)
                else:
                    relative = f"docs/evidence/hero/grid/golden-{camera}.png"
                    data = (ROOT / relative).read_bytes() if version == "v9" else committed(BASELINES[version], relative)
                    cell.write_bytes(data)
                    hashes[f"{version}-golden-{camera}"] = hashlib.sha256(data).hexdigest()
                cells.extend(["-label", label, str(cell)])
        subprocess.run(["montage", "-background", "#151515", "-fill", "#f3f0e5",
                        "-pointsize", "18", *cells, "-tile", "3x3", "-geometry", "640x400+4+4",
                        str(EVIDENCE / "comparison-v9.png")], check=True)

    measurement = {
        "baseline_revisions": BASELINES,
        "comparison_sha256": hashes,
        "settings": metrics["settings"],
        "frames": len(metrics["frames"]),
        "all_frames_pass": True,
        "console_errors": sum(len(f["console_errors"]) for f in metrics["frames"]),
        "grass_hue": next(f["grass_hsv"] for f in metrics["frames"] if f["name"] == "golden-mid"),
        "mountain_contrast": {f["name"]: f["mountain_contrast"] for f in metrics["frames"] if "mountain_contrast" in f},
        "framing": {f["name"]: f["framing"] for f in metrics["frames"] if "framing" in f},
        "timing_scope": "Archived v8 full grid vs v9 full grid. Wall-clock capture cost, not FPS. V9 adds one debug render to golden-far and golden-vista, so those costs are not identical procedures. Machine load was not controlled.",
        "capture_seconds": [
            {"name": f["name"], "v8": before[f["name"]]["seconds"], "v9": f["seconds"],
             "ratio": f["seconds"] / before[f["name"]]["seconds"]}
            for f in metrics["frames"]
        ],
    }
    (EVIDENCE / "v9-measurements.json").write_text(json.dumps(measurement, indent=2) + "\n")
    print("Wrote comparison-v9.png and v9-measurements.json from the passing final grid")


if __name__ == "__main__":
    main()
