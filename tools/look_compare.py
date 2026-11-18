#!/usr/bin/env python3
"""Side-by-side sheet of the same look views in two evidence directories: look_compare.py A B OUT view,view,..."""
import sys
from PIL import Image
a, b, out, views = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split(",")
W = Image.new("RGB", (1280, 360 * len(views)))
for k, v in enumerate(views):
    for c, d in enumerate((a, b)):
        W.paste(Image.open(f"{d}/{v}.png").convert("RGB").resize((640, 360)), (c * 640, k * 360))
W.save(out)
