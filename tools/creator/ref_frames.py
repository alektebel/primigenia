#!/usr/bin/env python3
"""Extract the reference moments (docs/evidence/godot/creator-score/reference.json) from the owner's video into a git-ignored dir,
draw the annotated boxes on them, and write the reference contact row. The video and its frames are never committed.
Usage: ref_frames.py [out_dir]   (default docs/evidence/godot/creator-score/ref_frames; needs ffmpeg + Pillow)"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "godot", "creator-score")
VIDEO = os.path.expanduser("~/Desarrollo/cpore-refs/videos/creator-flow-2026-11-22.mp4")


def extract(ref, out):
    os.makedirs(out, exist_ok=True)
    v = ref["view"]
    moms = dict(ref["moments"]); moms.update(ref.get("extra_moments", {}))
    for name, m in moms.items():
        dst = os.path.join(out, name + ".png")
        # frame numbers in the json are 1-based (ffmpeg image2 numbering); select is 0-based
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", VIDEO, "-vf", "select=eq(n\\,%d),crop=%d:%d:%d:%d" % (m["frame"] - 1, v["w"], v["h"], v["x"], v["y"]),
                        "-frames:v", "1", dst], check=True)
        im = Image.open(dst).convert("RGB")
        ImageDraw.Draw(im).rectangle(m["bbox_px"], outline=(255, 0, 255), width=2)
        im.save(os.path.join(out, name + "_boxed.jpg"), quality=88)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "ref_frames")
    extract(json.load(open(os.path.join(ROOT, "reference.json"))), out)
    print("reference frames in", out)
