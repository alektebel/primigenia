#!/usr/bin/env python3
"""Compare two visual scorecard runs: compare.py <labelA> <labelB> [--root docs/evidence/look/score] [--side OUT.jpg]
B against A, per shot and metric: improved / regressed / unchanged. A metric with a target in look-targets.json is judged by
distance to the target (worse = further past it); the others by DIRECTION. --side also writes the owner's blind A/B sheet
(sidebyside.py), shots in random-looking but fixed order, left/right assignment hidden in a .key.json next to it."""
import glob, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "look", "score")
# metric -> 'min' lower is better, 'max' higher is better, 'info' reported only
DIRECTION = {"sat_over": "min", "sat_p95": "min", "contrast": "max", "clip_frac": "min", "crush_frac": "min", "hf_noise": "min",
             "sharp_p99": "max", "tiling": "min", "dist_contrast": "max", "tier_delta": "min"}
REL = 0.03   # relative change under 3 percent (or 0.002 absolute) counts as unchanged


def load(label):
    d = label if os.path.isdir(label) else os.path.join(ROOT, label)
    out = {}
    for f in glob.glob(os.path.join(d, "*.json")):
        b = os.path.basename(f)[:-5]
        if b == "summary" or b.startswith("times_"):
            continue
        out[b] = json.load(open(f))["metrics"]
    s = os.path.join(d, "summary.json")
    perf = json.load(open(s)).get("perf", {}) if os.path.exists(s) else {}
    return d, out, perf


def verdict(kind, a, b):
    if abs(b - a) <= max(0.002, REL * abs(a)):
        return "unchanged"
    better = b < a if kind == "min" else b > a
    return "improved" if better else "regressed"


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    da, A, pa = load(args[0])
    db, B, pb = load(args[1])
    counts = {"improved": 0, "regressed": 0, "unchanged": 0}
    lines = ["| shot | metric | A | B | verdict |", "|---|---|---|---|---|"]
    per = {}
    for shot in sorted(set(A) & set(B)):
        for k, kind in DIRECTION.items():
            a, b = A[shot].get(k), B[shot].get(k)
            if a is None or b is None:
                continue
            v = verdict(kind, a, b)
            counts[v] += 1
            per.setdefault(shot, []).append(v)
            if v != "unchanged":
                lines.append("| %s | %s | %s | %s | %s |" % (shot, k, a, b, v))
    print("# look compare %s -> %s" % (os.path.basename(da), os.path.basename(db)))
    print("improved %(improved)d, regressed %(regressed)d, unchanged %(unchanged)d (metric x shot)" % counts)
    for t in sorted(set(pa) | set(pb)):
        x, y = pa.get(t, {}).get("frames_ms_median"), pb.get(t, {}).get("frames_ms_median")
        if x and y:
            print("frame ms median %s: %s -> %s (%s; software GL on a shared CPU, only a change over 30%% means anything)" % (t, x, y, "unchanged" if abs(y - x) <= 0.3 * x else verdict("min", x, y)))
    print("\n".join(lines))
    if "--side" in sys.argv:
        import sidebyside
        out = sys.argv[sys.argv.index("--side") + 1]
        sidebyside.build(da, db, out)
    sys.exit(1 if counts["regressed"] > counts["improved"] else 0)


sys.path.insert(0, HERE)
main()
