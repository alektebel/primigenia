#!/usr/bin/env python3
"""Builds tests/golden/world-debug-42.log (CPORE_WORLD_LOG 3) from world-42.log plus a fixed list of debug ops.
The hashes come from `world_cli --replay` and are cross-checked by tests/test_world.c through
cp_stage_replay_ex (an independent code path). Usage: make_world_debug.py <repo> <world_cli>."""
import subprocess
import sys

repo, cli = sys.argv[1], sys.argv[2]
lines = open(f"{repo}/tests/golden/world-42.log").read().split("\n")
assert lines[0] == "CPORE_WORLD_LOG 2"
# tick, op, id, a, x, z, v   (ops: 1 teleport, 2 spawn, 3 kill, 4 heal, 5 clock, 6 flags, 7 param)
OPS = [
    (50, 5, 0, 3000, 0, 0, 0),         # clock to 3000
    (100, 7, 0, 0, 0, 0, 1.6),         # jog_k 1.6
    (150, 1, 0, 0, 20, -30, 0),        # teleport the player
    (200, 2, 0, 3, 40, 40, 0),         # spawn a Garfio
    (300, 4, 0, 0, -1, -1, 0),         # heal to max
    (400, 6, 0, 1, 0, 0, 0),           # god
    (800, 6, 0, 3, 0, 0, 0),           # god + ai off
    (1000, 3, 2, 0, 0, 0, 0),          # kill wild #2
    (1200, 6, 0, 0, 0, 0, 0),          # flags off
    (1300, 7, 0, 13, 0, 0, 0.2),       # turn_slow 0.2
]
out = ["CPORE_WORLD_LOG 3"] + lines[1:]
while out and out[-1] == "":
    out.pop()
out.append(str(len(OPS)))
for t, op, i, a, x, z, v in OPS:
    out.append(f"{t} {op} {i} {a} {x:.9g} {z:.9g} {v:.9g}")
path = f"{repo}/tests/golden/world-debug-42.log"
open(path, "w").write("\n".join(out) + "\n")
res = subprocess.run([cli, "--replay", path], capture_output=True, text=True)
if res.returncode:
    sys.exit(res.stderr)
open(f"{repo}/tests/golden/world-debug-42.hashes", "w").write(res.stdout)
print("ok", len(res.stdout.split()), "ticks")
