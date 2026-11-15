#!/usr/bin/env python3
"""Compose docs/evidence/terrain/shape-v2.png from the capture script's pictures.

Rows: phase A seed 42 (before), then version 2 seeds 42, 1 and 7 (after).
Columns: fixed oblique camera, valley-floor camera, hillshade + drainage.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/evidence/terrain")
rows = [("before-42", "Before: phase A, seed 42 (2 km square)"),
        ("after-42", "After: version 2, seed 42 (3.6 km square)"),
        ("after-1", "After: version 2, seed 1"),
        ("after-7", "After: version 2, seed 7")]
H, PAD, LABEL = 520, 10, 34
font = None
for path in ("/usr/share/fonts/TTF/DejaVuSans.ttf", "/usr/share/fonts/noto/NotoSans-Regular.ttf"):
    if Path(path).exists():
        font = ImageFont.truetype(path, 20)
        break
strips = []
for name, title in rows:
    cells = []
    for view in ("oblique", "valley", "top"):
        im = Image.open(root / f"{name}-{view}.png").convert("RGB")
        if view != "top":                       # trim the lab's hint label
            im = im.crop((0, 0, im.width, im.height - 60))
        cells.append(im.resize((round(im.width * H / im.height), H), Image.LANCZOS))
    strips.append((title, cells))
width = max(sum(c.width for c in cells) + PAD * (len(cells) + 1) for _, cells in strips)
sheet = Image.new("RGB", (width, len(strips) * (H + LABEL + PAD) + PAD), "#f5f2e9")
draw = ImageDraw.Draw(sheet)
y = PAD
for title, cells in strips:
    draw.text((PAD, y + 4), title + "  ·  from above  ·  from the valley floor  ·  hillshade + drainage",
              fill="#263d35", font=font)
    x = PAD
    for cell in cells:
        sheet.paste(cell, (x, y + LABEL))
        x += cell.width + PAD
    y += H + LABEL + PAD
sheet.save(root / "shape-v2.png", optimize=True)
print(root / "shape-v2.png", sheet.size)
