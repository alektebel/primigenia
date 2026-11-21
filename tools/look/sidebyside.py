#!/usr/bin/env python3
"""Blind A/B sheets for the owner: sidebyside.py <dirA> <dirB> <out.jpg>
One row per shot present in both runs, A|B at 640x360 each. Which build is on the left is shuffled per shot with a fixed seed and
written to <out>.key.json (open it only after choosing). Rows are cut into sheets of 6: out.jpg, out_2.jpg, ..."""
import glob, json, os, random, sys
from PIL import Image, ImageDraw


def build(a, b, out, per_sheet=6):
    names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(a, "*.jpg")) if not os.path.basename(p).startswith("contact_"))
    names = [n for n in names if os.path.exists(os.path.join(b, n + ".jpg"))]
    rng = random.Random(7)
    key = {}
    base = out[:-4]
    for s in range(0, len(names), per_sheet):
        chunk = names[s:s + per_sheet]
        sheet = Image.new("RGB", (1280 + 8, 360 * len(chunk)), (0, 0, 0))
        for k, n in enumerate(chunk):
            swap = rng.random() < 0.5
            left, right = (b, a) if swap else (a, b)
            key[n] = {"left": os.path.basename(os.path.normpath(left)), "right": os.path.basename(os.path.normpath(right))}
            sheet.paste(Image.open(os.path.join(left, n + ".jpg")).convert("RGB").resize((640, 360), Image.LANCZOS), (0, k * 360))
            sheet.paste(Image.open(os.path.join(right, n + ".jpg")).convert("RGB").resize((640, 360), Image.LANCZOS), (648, k * 360))
            ImageDraw.Draw(sheet).text((6, k * 360 + 4), n, fill=(255, 255, 255))
        sheet.save(out if s == 0 else "%s_%d.jpg" % (base, s // per_sheet + 1), quality=85)
    json.dump(key, open(out + ".key.json", "w"), indent=1)
    print("wrote %d rows to %s*.jpg, key in %s.key.json" % (len(names), base, out))


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2], sys.argv[3])
