#!/usr/bin/env python3
"""Contact sheet of the review camera path (make godot-island-path): rows = times of day, columns = OG0..OG9.
python3 tools/island/path_sheet.py <dir> <tier> [out.jpg] [tile width]"""
import os, sys
from PIL import Image, ImageDraw

TODS = ["dawn", "midday", "dusk", "night"]
SHOTS = ["OG%d" % i for i in range(10)]

def main() -> int:
    folder, tier = sys.argv[1], sys.argv[2]
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(folder, "sheet_%s.jpg" % tier)
    tw = int(sys.argv[4]) if len(sys.argv) > 4 else 384
    th, lab = tw * 9 // 16, 18
    tiles = {(t, s): os.path.join(folder, "%s_%s_%s.jpg" % (tier, t, s)) for t in TODS for s in SHOTS}
    cols = [s for s in SHOTS if any(os.path.exists(tiles[(t, s)]) for t in TODS)]
    rows = [t for t in TODS if any(os.path.exists(tiles[(t, s)]) for s in SHOTS)]
    if not cols:
        print("no frames in", folder)
        return 1
    sheet = Image.new("RGB", (len(cols) * tw, len(rows) * (th + lab)), (24, 34, 31))
    d = ImageDraw.Draw(sheet)
    for r, t in enumerate(rows):
        for c, s in enumerate(cols):
            x, y = c * tw, r * (th + lab)
            d.text((x + 6, y + 4), "%s %s %s" % (tier, t, s), fill=(233, 223, 198))
            p = tiles[(t, s)]
            if os.path.exists(p):
                sheet.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y + lab))
    sheet.save(out, quality=88)
    print("wrote", out)
    return 0

if __name__ == "__main__":
    sys.exit(main())
