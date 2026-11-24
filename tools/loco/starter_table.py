#!/usr/bin/env python3
"""Compact scorecard table for the starter candidates: python3 tools/loco/starter_table.py <score dir>"""
import json, sys, os
d = sys.argv[1]
bodies = ["hero", "start0", "startA", "startB", "startC", "startD"]
print("| body | scen | head pitch mean | slip p95 cm | leg ext | foot spacing | airborne | knee flip | pivot | stall | speed m/s |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
def f(v, n=2):
    return "-" if v is None else ("%.*f" % (n, v))
for b in bodies:
    for s in ["walk", "gallop", "turn", "climb", "steps"]:
        p = os.path.join(d, "%s_%s.json" % (b, s))
        if not os.path.exists(p): continue
        m = json.load(open(p))["metrics"]
        sl = m.get("foot_slip_cm")
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (b, s, f(m["head_pitch_deg"]["mean"], 1), f(sl["p95"] if sl else None, 1), f(m["leg_extension"]), f(m["foot_spacing_ratio"]), f(m["airborne_frac"]), f(m["knee_flip_frac"]), f(m["pivot_frac"]), f(m["stall_frac"]), f(m["speed_mean_mps"], 1)))
