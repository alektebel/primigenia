#!/usr/bin/env python3
"""Self-test of tools/loop/score.py and compare.py on a synthetic session (no Godot)."""
import json, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import score, compare  # noqa: E402


def ev(tick, n, d=None):
    return {"n": n, "tick": tick, "ms": tick * 10, "ts": 0, "d": d or {}}


def session(slow=1.0):
    t = lambda s: int(s * 10 * slow)
    out = [ev(0, "session_start"), ev(0, "island_ready", {"ms": 9000, "phases": {"creatures": 1000, "stage_setup": 200}}), ev(1, "spawn"), ev(t(3), "first_move"), ev(t(20), "select"),
           ev(t(40), "species_seen", {"count": 1}), ev(t(100), "fight_start", {"name": "Rondo"}), ev(t(130), "fight_end", {"name": "Rondo", "result": "kill"}), ev(t(130), "kill"),
           ev(t(130), "quest_done:hunt"), ev(t(200), "befriend_start"), ev(t(220), "first_bond"), ev(t(221), "quest_done:friend"), ev(t(300), "quest_done:dig"),
           ev(t(400), "quest_done:wings"), ev(t(410), "editor_open", {"dna": 60}), ev(t(420), "evolve"), ev(t(500), "quest_done:fire"), ev(t(520), "cousin_seen")]
    out += [ev(i * 100, "sample", {"dist": i * 3.0, "dna_total": 50}) for i in range(0, int(t(520) / 100) + 1)]
    return out


def main():
    m = score.compute(session(), "bot")
    assert m["t_hunt_s"] == 130.0 and m["t_fire_s"] == 500.0, m
    assert m["fights_per_kill"] == 1.0 and m["befriend_tries"] == 1 and m["deaths_before_evolve"] == 0
    assert m["dna_at_editor"] == 60 and m["load_cold_s"] == 9.0 and m["load_creatures_s"] == 1.0
    assert m["bot_task_hunt"] == 1300 and m["bot_total"] == 5000, m
    rows = score.evaluate({"s": m}, "bot")
    _, failing = score.table(rows, ["s"])
    assert "time to hunt" not in failing and "species seen by 30 min" in failing, failing
    ms = score.compute(session(slow=40.0), "bot")
    assert ms["t_hunt_s"] > 360 and ms["max_gap_s"] > 90
    assert score.judge("in", (0.35, 0.8), None) == "n/a" and score.judge("in", (0.35, 0.8), 0.5) == "pass"
    # a half-written last line is ignored; two runs in one file score the bigger one
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "s.jsonl")
        with open(p, "w") as f:
            for e in session():
                f.write(json.dumps(e) + "\n")
            f.write('{"n": "sel')
        assert score.compute(score.read(p), "owner")["t_fire_s"] == 500.0
        for lbl, sl in (("a", 1.0), ("b", 2.0)):
            os.makedirs(os.path.join(d, lbl))
            json.dump({"kind": "bot", "metrics": score.compute(session(sl), "bot")}, open(os.path.join(d, lbl, "metrics_seed1.json"), "w"))
        assert compare.main([os.path.join(d, "a"), os.path.join(d, "b")]) == 1      # twice as slow: a regression
        assert compare.main([os.path.join(d, "a"), os.path.join(d, "a")]) == 0
    print("loop score self-test: ok")


main()
