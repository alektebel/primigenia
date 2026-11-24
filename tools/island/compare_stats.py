#!/usr/bin/env python3
"""Compare a `maps.py --desc` stats file with the layout stats (F1 gate): land area within 2% (relative), every percentage within
2 points, region pixel counts within 2% (relative). Route names are not compared: a desc blob does not store them.

  python3 tools/island/compare_stats.py build/island/maps-desc/stats-desc.json web/gaitlab/island/stats.json [--id star-massif] [--tol 2]
"""
import argparse, json, sys

ap = argparse.ArgumentParser()
ap.add_argument("desc_stats"); ap.add_argument("layout_stats")
ap.add_argument("--id", default="star-massif"); ap.add_argument("--tol", type=float, default=2.0)
a = ap.parse_args()
d = next(iter(json.load(open(a.desc_stats)).values()))
l = json.load(open(a.layout_stats))[a.id]
rows, worst = [], 0.0

def rel(name, x, y):
    global worst
    e = 0.0 if x == y else 100.0 * abs(x - y) / max(abs(y), 1e-9)
    rows.append((name, x, y, e, "%")); worst = max(worst, e)

def pp(name, x, y):
    global worst
    e = abs(x - y)
    rows.append((name, x, y, e, "pt")); worst = max(worst, e)

rel("land_km2", d["land_km2"], l["land_km2"])
pp("plain_reach_pct", d["plain_reach_pct"], l["plain_reach_pct"]); pp("climb_reach_pct", d["climb_reach_pct"], l["climb_reach_pct"])
assert [r["name"] for r in d["regions"]] == [r["name"] for r in l["regions"]], "region lists differ"
for rd, rl in zip(d["regions"], l["regions"]):
    rel(rd["name"] + " land_px", rd["land_px"], rl["land_px"])
    for k in ("core_plain_pct", "core_climb_only_pct", "plain_pct", "climb_only_pct"): pp(rd["name"] + " " + k, rd[k], rl[k])
for n, x, y, e, u in rows: print("%-44s desc %10.2f  layout %10.2f  delta %6.2f %s" % (n, x, y, e, u))
print("worst delta %.2f (limit %.1f)" % (worst, a.tol))
sys.exit(0 if worst <= a.tol else 1)
