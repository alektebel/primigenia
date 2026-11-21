#!/usr/bin/env python3
"""Footfall diagrams: one SVG per body x scenario from the `footfall` arrays of the scorecard JSON.
Usage: footfall_svg.py <label dir> [out dir]   (default out dir: <label dir>/footfall)
One row per foot, a bar where the foot is in contact, two strides wide; an optional reference row set can be given as
<label dir>/reference_footfall.json: {"name": ..., "labels": [...], "contact": ["0011..", ...]} and is drawn under every diagram."""
import glob, json, os, sys

ROW, LEFT, W, PAD = 22, 46, 640, 10


def rows_of(ff):
    return list(zip(ff["labels"], ff["contact"]))


def draw(title, ff, ref):
    sets = [("ours", rows_of(ff))] + ([("reference: " + ref.get("name", "ref"), rows_of(ref))] if ref else [])
    n = max(len(s) for _, s in sets[0:1])
    frames = max(len(c) for _, s in sets for _, c in s)
    h = PAD * 2 + 18 + sum(len(s) * ROW + 16 for _, s in sets)
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="monospace" font-size="11">' % (LEFT + W + PAD, h),
           '<rect width="100%" height="100%" fill="#ffffff"/>', '<text x="%d" y="%d" font-weight="bold">%s</text>' % (PAD, PAD + 8, title)]
    y = PAD + 22
    for name, rows in sets:
        out.append('<text x="%d" y="%d" fill="#555">%s</text>' % (PAD, y, name))
        y += 6
        for lab, seq in rows:
            out.append('<text x="%d" y="%d">%s</text>' % (PAD, y + 14, lab))
            out.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#f2f2f2"/>' % (LEFT, y + 2, W, ROW - 6))
            fw = W / max(1, frames)
            i = 0
            while i < len(seq):
                if seq[i] == "1":
                    j = i
                    while j < len(seq) and seq[j] == "1":
                        j += 1
                    out.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="#2b6cb0"/>' % (LEFT + i * fw, y + 2, (j - i) * fw, ROW - 6))
                    i = j
                else:
                    i += 1
            y += ROW
        y += 10
    # stride boundary
    sf = ff.get("stride_frames", 0)
    if sf and sf < frames:
        out.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#c53030" stroke-dasharray="3,3"/>' % (LEFT + sf * W / frames, PAD + 24, LEFT + sf * W / frames, h - PAD))
    out.append("</svg>")
    return "\n".join(out)


def main():
    d = sys.argv[1]
    od = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "footfall")
    os.makedirs(od, exist_ok=True)
    rp = os.path.join(d, "reference_footfall.json")
    ref = json.load(open(rp)) if os.path.exists(rp) else None
    n = 0
    for f in sorted(glob.glob(os.path.join(d, "*_*.json"))):
        if os.path.basename(f) in ("summary.json", "reference_footfall.json"):
            continue
        c = json.load(open(f))
        ff = c.get("metrics", {}).get("footfall")
        if not ff:
            continue
        open(os.path.join(od, "%s_%s.svg" % (c["body"], c["scenario"])), "w").write(draw("%s %s (dashed = one stride)" % (c["body"], c["scenario"]), ff, ref))
        n += 1
    print("footfall_svg: %d diagrams in %s" % (n, od))


main()
