"""Exercise C-owned recipe discovery and resource nodes through world-2."""
import ctypes
from cpore.world import StageWorld

w = StageWorld(seed=42)
s = w._setup
s.terrain, s.n, s.n_obstacles = 1, 0, 0
assert w._lib.cp_stage_reset(w._world, ctypes.byref(s)) == 0
assert w.observe()["recipes"]["bone_spines"]["state"] == "unknown"

def visit(node):
    assert w.command(f'go {node["x"]} {node["z"]}') == 0
    for _ in range(1000):
        w.step()

for i, state in [(0, "hinted"), (1, "known")]:
    node = w.observe()["parts"]["nodes"][i]
    visit(node)
    assert w.command(f'inspect #{node["id"]}') == 0
    for _ in range(20):
        w.step()
    obs = w.observe()
    assert obs["recipes"]["bone_spines"]["state"] == state
    assert any(e["type"] == "recipe_state" for e in obs["events"])
    assert w.command(f'inspect #{node["id"]}') < 0

for _ in range(2):
    assert w.command("eat #3001") == 0
    for _ in range(5):
        w.step()
assert w.observe()["recipes"]["meters"]["calcium"]["value"] == 40
stone = w.observe()["recipes"]["stones"][0]
visit(stone)
assert w.command(f'eat #{stone["id"]}') == 0
for _ in range(5):
    w.step()
assert w.observe()["recipes"]["meters"]["mineral"]["value"] == 25
assert "curl_up" in w.observe()["known_moves"]
print("Python moves/recipes smoke: passed")
