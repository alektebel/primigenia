#!/usr/bin/env python3
"""Contact sheet of the numbered frames in a folder: python3 tools/contact_sheet.py <dir> [out.png] [columns] [width].
Used by `make godot-first-quest-evidence`: one frame per task completion, labelled with its file name."""
import sys, os, glob
from PIL import Image, ImageDraw

def main() -> int:
    folder = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(folder, "contact_sheet.png")
    cols = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    tile_w = int(sys.argv[4]) if len(sys.argv) > 4 else 640
    files = sorted(f for f in glob.glob(os.path.join(folder, "[0-9][0-9]_*.png")))
    if not files:
        print("no frames in", folder)
        return 1
    imgs = [Image.open(f).convert("RGB") for f in files]
    tile_h = int(tile_w * imgs[0].height / imgs[0].width)
    rows = (len(imgs) + cols - 1) // cols
    label_h = 22
    sheet = Image.new("RGB", (cols * tile_w, rows * (tile_h + label_h)), (24, 34, 31))
    d = ImageDraw.Draw(sheet)
    for i, (f, im) in enumerate(zip(files, imgs)):
        x, y = (i % cols) * tile_w, (i // cols) * (tile_h + label_h)
        sheet.paste(im.resize((tile_w, tile_h), Image.LANCZOS), (x, y + label_h))
        d.text((x + 8, y + 5), os.path.basename(f), fill=(233, 223, 198))
    sheet.save(out)
    print("wrote", out, len(imgs), "frames")
    return 0

if __name__ == "__main__":
    sys.exit(main())
