"""C-owned discovery -> DNA -> nest edit, exposed through Python."""
import ctypes
from cpore.world import StageWorld
w = StageWorld(seed=7)
s = w._setup
s.terrain = 1
s.n = 0
s.n_obstacles = 0
assert w._lib.cp_stage_reset(w._world, ctypes.byref(s)) == 0
body = {"schema": "cpore.creature/4", "name": "Starter", "nodes": [
    {"y": 1, "z": z, "r": .5} for z in [-2, -1, 0, 1]],
    "parts": [{"type": "pico", "t": 1, "ang": 0, "size": 1}],
    "skin": {"pat": 0, "wet": .3, "scale": 7, "cA": "#aabbcc", "cB": "#112233", "cC": "#ffffff"}, "regions": []}
assert w.start_genome(body) == 0
assert w.observe()["parts"]["eggs"] == 3
assert w.command("buy_part pua") < 0
for node in w.observe()["parts"]["nodes"]:
    assert w.command(f'go {node["x"]} {node["z"]}') == 0
    for _ in range(400):
        w.step()
    assert w.command(f'inspect #{node["id"]}') == 0
    for _ in range(20):
        w.step()
    obs = w.observe()
    assert any(e["type"] == "part_found" for e in obs["events"])
assert w.command("go_nest") == 0
for _ in range(400):
    w.step()
obs = w.observe()
assert obs["parts"]["can_edit"]
part = next(p for p in obs["parts"]["discovered"] if not p["owned"] and p["cost"] <= obs["social"]["dna_balance"])
total = obs["social"]["dna_total"]
assert w.command(f'buy_part {part["id"]}') == 0
assert w.observe()["social"]["dna_total"] == total
assert w.edit(body) == 0
assert len(w.lineage()["generations"]) == 2
assert w.apply(body) == 0 and len(w.lineage()["generations"]) == 2  # cosmetic apply is free
print("Python parts/nest smoke: passed")
