"""Smoke test of the C2 social verbs through the Python binding (text and struct paths)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpore.world import StageWorld  # noqa: E402


def main() -> None:
    w = StageWorld(seed=7)
    o = w.observe()
    assert "social" in o and o["social"]["dna_total"] >= 0
    gar = o["nearby"][0]
    assert gar["species"] == "Garfio" and gar["temper"] == "aggressive" and gar["relationship"] == "stranger"
    # last_error codes stay consistent through the text path
    assert w.command("befriend #1 sing") == -15            # aggressive and not calmed
    assert w.command("befriend #1 yodel") == -17
    assert w.command("befriend #9 sing") == -2
    assert w.command("gift #1 meat") == -16                # no meat carried yet
    assert w.command("gift #1 fruit") == 0                 # struct path next: same result
    w.step({"verb": "gift", "target": 1, "item": "plant"})
    for _ in range(80):
        w.step(None)
    o = w.observe()
    assert o["social"]["inventory"]["plant"] in (0, 1)
    assert any(e["type"] in ("gift", "social_cancelled") for e in o["events"]) or o["social"]["action"] is None
    # observe a creature from afar, deterministically
    w.reset(7)
    assert w.command("observe #1") == 0
    h1 = [w.step(None) for _ in range(30)]
    w.reset(7)
    w.command("observe #1")
    assert h1 == [w.step(None) for _ in range(30)]
    print("python social smoke: ok")


if __name__ == "__main__":
    main()
