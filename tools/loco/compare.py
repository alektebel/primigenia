#!/usr/bin/env python3
"""Compare two scorecard runs: tools/loco/compare.py <labelA> <labelB> [--root docs/evidence/loco/score]
Prints a markdown table of the metrics that improved / regressed / stayed the same (B against A), per body x scenario.
A metric is 'better' in the direction given by DIRECTION; checked metrics with a target use distance to the target."""
import glob, json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "evidence", "loco", "score")
# metric path -> (kind, target): 'min' lower is better, 'max' higher is better, 'near' closer to target is better
DIRECTION = {
    "limp_index": ("near", 1.0),
    "head_pitch_deg.mean": ("near", 0), "head_yaw_vs_body_deg.p95": ("min", 0), "shoulder_hip_ratio": ("near", 1.35), "back_slope_deg": ("near", 22),
    "torso_roll_deg": ("near", 7), "roll_plant_lag": ("near", 0), "torso_bob_frac": ("near", 0.04), "foot_slip_cm.p95": ("min", 0),
    "foot_slip_cm.mean": ("min", 0), "leg_extension": ("near", 0.95), "foot_spacing_ratio": ("max", 0), "pivot_frac": ("min", 0),
    "pivot_frac_of_turns": ("min", 0), "stall_frac": ("min", 0), "pitch_follow": ("near", 1.0), "knee_flip_frac": ("min", 0), "foot_penetration_cm.p95": ("min", 0), "gait_symmetry": ("near", 1.0),
}
EPS = 1e-6


def get(m, path):
    for k in path.split("."):
        if not isinstance(m, dict) or k not in m:
            return None
        m = m[k]
    return m if isinstance(m, (int, float)) else None


def load(label):
    d = label if os.path.isdir(label) else os.path.join(ROOT, label)
    out = {}
    for f in glob.glob(os.path.join(d, "*_*.json")):
        b = os.path.basename(f)[:-5]
        if b in ("summary", "reference_footfall"):
            continue
        out[b] = json.load(open(f))["metrics"]
    return out


def score(kind, t, v):
    return abs(v - t) if kind == "near" else (v if kind == "min" else -v)


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    better, worse, same = [], [], 0
    for case in sorted(set(a) & set(b)):
        for path, (kind, t) in DIRECTION.items():
            va, vb = get(a[case], path), get(b[case], path)
            if va is None or vb is None:
                continue
            sa, sb = score(kind, t, va), score(kind, t, vb)
            if abs(sa - sb) <= EPS + 0.005 * max(abs(sa), 1e-9):
                same += 1
            else:
                (better if sb < sa else worse).append((case, path, va, vb))
    print("# Compare %s -> %s\n" % (sys.argv[1], sys.argv[2]))
    print("improved %d, regressed %d, unchanged %d (cases in both: %d)\n" % (len(better), len(worse), same, len(set(a) & set(b))))
    for title, rows in (("Improved", better), ("Regressed", worse)):
        print("## %s\n" % title)
        print("| case | metric | %s | %s |\n|---|---|---|---|" % (sys.argv[1], sys.argv[2]))
        for case, path, va, vb in rows:
            print("| %s | %s | %.3f | %.3f |" % (case, path, va, vb))
        print()


main()
