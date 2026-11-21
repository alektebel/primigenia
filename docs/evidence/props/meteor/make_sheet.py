#!/usr/bin/env python3
"""Create a composite evidence sheet from the individual capture shots."""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
SHOTS_DIR = ROOT / "docs/evidence/props/meteor/shots"

# Load all individual shots
shot_names = ["lineup", "scene", "far", "core", "shard0", "shard1", "shard2", "shard3", "shard4"]
imgs = {}
for name in shot_names:
    p = SHOTS_DIR / f"{name}.png"
    if p.exists():
        from PIL import Image
        imgs[name] = Image.open(p)

if not imgs:
    print("No shots found — run capture_meteor.cjs first", file=sys.stderr)
    sys.exit(1)

from PIL import Image

# Layout: 3 rows x 3 columns
# Top row: shard close-ups (shard0..shard2)
# Middle: lineup, scene, far
# Bottom: shard3, shard4, core
layout = [
    ["shard0", "shard1", "shard2"],
    ["lineup", "scene", "far"],
    ["shard3", "shard4", "core"],
]

# Target cell size
W, H = 640, 400
cell_w, cell_h = W, H
canvas = Image.new("RGB", (W * 3, H * 3 + 30), (12, 14, 20))

for row, row_shots in enumerate(layout):
    for col, name in enumerate(row_shots):
        img = imgs.get(name)
        if img is None:
            continue
        # Resize to fit cell while keeping aspect ratio
        img = img.resize((W, H), Image.LANCZOS)
        canvas.paste(img, (col * W, row * H + 30))

out = SHOTS_DIR / "sheet.png"
canvas.save(out, "PNG")
print(f"wrote {out}")
print(f"  size: {canvas.size[0]}x{canvas.size[1]}, {len(imgs)} shots")