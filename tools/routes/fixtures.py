#!/usr/bin/env python3
"""Derive the C-readable route graph from pinned, real StageSetup placement exports."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(__doc__)
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
for seed in (1, 7, 42):
    source = root / f"tests/routes/seed{seed}.json"
    data = json.loads(source.read_text())
    points = data["route_places"]
    ids = [p["id"] for p in points]
    text = "terrain " + data["terrain_hash"] + "\n"
    text += f"places {len(points)}\n"
    text += "".join(f'{p["id"]} {p["x"]:.9g} {p["z"]:.9g}\n' for p in points)
    pairs = data["required_pairs"]
    text += f"pairs {len(pairs)}\n"
    text += "".join(f"{ids.index(a)} {ids.index(b)}\n" for a, b in pairs)
    target = source.with_suffix(".txt")
    if args.check:
        if target.read_text() != text:
            raise SystemExit(f"Stale fixture: {target}; run tools/routes/fixtures.py")
    else:
        target.write_text(text)
