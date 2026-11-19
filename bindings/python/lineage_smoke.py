"""L0 public binding contract; no Godot or graphics needed."""
from cpore.world import StageWorld
w = StageWorld(42)
assert not w.lineage()["enabled"]
assert w.lineage_begin() == 0
assert w.lineage_begin() < 0
for deed, amount in [(0, 3), (1, 3), (5, 7)]:
    assert w.lineage_award(deed, amount, 1) == 0
l = w.lineage()
assert l["format"] == "cpore.lineage/1"
assert {"hunter", "social"} <= set(l["traits"])
assert l["deeds"]["observations"] == 7
assert w.observe()["lineage"]["generation"] == 1
assert w.lineage_award(21, 600) < 0  # swimming remains disabled
assert w.lineage_perk(3, 1, 100) == 100  # undetermined type: no perk yet
for deed in (1, 4, 9):  # social, gatherer, builder: all four axes decided (observations make it wary)
    assert w.lineage_award(deed, 20, 1) == 0
assert w.lineage_perk(3, 2, 100) == 80
assert w.lineage_perk(3, 2, 100) == 0
w.step()
assert w.lineage()["deeds"]["nest_ticks"] == 1
print("Python lineage smoke: passed")
