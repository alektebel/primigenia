#!/usr/bin/env python3
"""A83 island layouts: in-engine shots (Godot game scene, software GL) of the four candidates.

  python3 tools/island/shots.py --out web/gaitlab/island [--only star-massif] [--godot godot]

Reads web/gaitlab/island/stats.json (written by maps.py: generator params and the walkable route paths), writes the
params and shots JSON the Godot script wants, runs ONE Godot at a time under xvfb with software GL (AGENTS.md machine
rules) and puts <id>-<shot>.jpg next to the maps. Ground shots stand on a real walkable route (slope under 51.6 deg)
looking along it, so they cannot end up inside a hillside.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile

# per layout: fixed aerial shots, then ground shots as (name, route, fraction of the route, look-ahead samples)
PLAN = {
    "star-massif": {
        "aerial": [("flyover", [1150, 800, 1800], [-100, 100, -100], 62), ("nest", [60, None, 70], [-300, 330, -240], 70)],
        "ground": [("canyon", "Exit 3: south pass", 0.72, 7), ("forest", "Exit 2: north pass", 0.55, 7)]},
    "great-rift": {
        "aerial": [("flyover", [1900, 450, 350], [0, 60, 0], 62), ("nest", [-60, None, 10], [700, None, -10], 70)],
        "ground": [("gorge", "River corridor", 0.50, 7), ("forest", "River corridor", 0.2, 7)]},
    "stepped-plateau": {
        "aerial": [("flyover", [-1500, 750, 1300], [200, 100, -200], 62), ("nest", [0, None, 10], [-20, None, -420], 70)],
        "ground": [("terraces", "Exit 2: west ramp", 0.95, 6), ("canyon", "Exit 1: SE ramp", 0.97, 6)]},
    "windward-crescent": {
        "aerial": [("flyover", [1850, 800, 500], [-600, 150, -100], 62), ("nest", [0, None, 0], [-1100, 330, -100], 70)],
        "ground": [("canyon", "Exit S: red canyon", 0.70, 7), ("arc", "Exit W: bench pass", 0.95, 5)]},
}


def build(lid, stats):
    plan = PLAN[lid]
    shots = []
    for name, pos, look, fov in plan["aerial"]:
        s = {"name": name, "pos": [pos[0], pos[1] or 0, pos[2]], "look": [look[0], look[1] or 0, look[2]], "fov": fov}
        if pos[1] is None:
            s["agl"] = 25
        if look[1] is None:
            s["look_agl"] = 30
        shots.append(s)
    for name, route, frac, ahead in plan["ground"]:
        pts = stats[lid]["route_paths"][route]
        i = min(len(pts) - 1, max(1, int(frac * (len(pts) - 1))))
        a = pts[i]
        j = i + ahead
        if j < len(pts):
            b = pts[j]
        else:
            p0 = pts[max(0, i - ahead)]
            b = [a[0] + (a[0] - p0[0]), a[1] + (a[1] - p0[1])]
        shots.append({"name": name, "pos": [a[0], 0, a[1]], "agl": 2.4, "look": [b[0], 0, b[1]], "look_agl": 14, "fov": 72})
    return shots


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="web/gaitlab/island")
    ap.add_argument("--only", default="")
    ap.add_argument("--godot", default="godot")
    a = ap.parse_args()
    stats = json.load(open(os.path.join(a.out, "stats.json")))
    root = os.path.abspath(a.out)
    for lid in PLAN:
        if a.only and lid != a.only:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            pj, sj, od = os.path.join(tmp, "params.json"), os.path.join(tmp, "shots.json"), os.path.join(tmp, "out")
            json.dump(stats[lid]["params"], open(pj, "w"))
            json.dump(build(lid, stats), open(sj, "w"))
            env = dict(os.environ, LIBGL_ALWAYS_SOFTWARE="1")
            cmd = ["nice", "-n", "10", "timeout", "900", "xvfb-run", "-a", a.godot, "--rendering-driver", "opengl3", "--resolution", "1280x720",
                   "--path", "godot", "--script", "res://game/tests/island_layout_shots.gd", "--", pj, sj, od]
            proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            print(lid, "godot pid", proc.pid, flush=True)
            log = proc.communicate()[0]
            if proc.returncode:
                sys.exit("godot failed for %s:\n%s" % (lid, log[-2000:]))
            for f in os.listdir(od):
                shutil.copy(os.path.join(od, f), os.path.join(root, "%s-%s" % (lid, f)))
            print(lid, "ok", sorted(os.listdir(od)), flush=True)


if __name__ == "__main__":
    main()
