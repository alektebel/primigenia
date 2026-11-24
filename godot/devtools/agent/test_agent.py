#!/usr/bin/env python3
"""End-to-end test of the agent socket: python -> Godot (headless) -> C world. See PROTOCOL.md."""
import argparse
import os
import shutil
import tempfile
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from client import GodotAgent  # noqa: E402

os.environ["CPORE_TEST"] = "1"  # the stores resolve to an isolated dir (godot/devtools/test_isolation.gd)
failures = 0


def check(ok, what):
    global failures
    print(("  ok  " if ok else "FAIL  ") + what)
    if not ok:
        failures += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--port", type=int, default=47110)
    a = ap.parse_args()
    notes_tmp = tempfile.mkdtemp(prefix="agent-notes-")
    with GodotAgent(a.godot, scenario="creature/garfio_close", port=a.port, extra=["--notes-dir=" + notes_tmp]) as g:
        check(g.ready["protocol"] == 1, "AGENT_READY protocol 1 (build %s)" % g.ready["build"])
        o = g.send("observe")
        check(o["ok"] and o["obs"]["schema"] == "world-2" and o["tick"] == 0 and not o["obs"]["fighting"], "observe at the scenario's tick 0, not fighting")
        near = [n for n in o["obs"]["nearby"] if n.get("type") == "creature"]
        check(len(near) == 1 and 6 < near[0]["distance"] < 10, "Garfio is about 8 m away (%s)" % (near[0]["distance"] if near else None))
        r = g.send("console", text="god on")
        check(r["ok"], "console god on")
        check(not g.send("console", text="frobnicate")["ok"], "an unknown console command fails with a sentence")
        check(g.send("act", order="go 1 2")["ok"] and not g.send("act", order="nonsense")["ok"], "act validates orders")
        s = g.send("step", ticks=50)
        check(s["ok"] and s["tick"] == 50 and len(s["hash"]) == 16, "step 50 -> tick 50")
        fought = False
        for i in range(60):
            o = g.send("observe")
            if o["obs"]["fighting"]:
                fought = True
                g.send("act", order="attack #1 bite")
            s = g.send("step", ticks=10)
            if fought and not s["obs"]["fighting"]:
                break
            if s["tick"] >= 650:
                break
        check(fought, "the fight started and was played (ticks %d)" % s["tick"])
        v = g.send("verify")
        check(v["ok"] and v["match"] and v["ticks"] == s["tick"], "verify replays the session log: match over %s ticks" % v.get("ticks"))
        sc = g.send("scenario_save", name="agent-test")
        check(sc["ok"], "scenario_save %s" % sc.get("error", ""))
        ld = g.send("scenario_load", name="user://scenarios/agent-test")
        check(ld["ok"], "scenario_load %s" % ld.get("error", ""))
        o1 = g.send("opt", set={"light": "dusk", "skin": "pre-v1"})
        check(o1["ok"] and o1["options"] == {"light": "dusk", "skin": "pre-v1"} and "light dusk" in o1["line"], "opt set variants: %s" % o1)
        check(not g.send("opt", set={"light": "noon"})["ok"], "opt refuses an unknown value")
        check(g.send("opt", reset=True)["options"] == {}, "opt reset")
        check(g.send("console", text="opt light=day")["ok"], "the console command works over the socket too")
        g.send("opt", reset=True)
        na = g.send("note_add", text="agent note", tags=["bug"], severity=3)
        check(na["ok"] and na["note_id"], "note_add %s" % na.get("error", ""))
        ln = g.send("notes")
        check(any(n["id"] == na["note_id"] and n["status"] == "open" for n in ln["notes"]), "notes lists it")
        check(g.send("note_done", note=na["note_id"], fix="abc")["ok"], "note_done")
        check(not any(n["id"] == na["note_id"] for n in g.send("notes")["notes"]), "done notes leave the open list")
        shot = g.send("screenshot")
        check(not shot["ok"] and "no renderer" in shot["error"], "headless screenshot says why not")
        errs = [e for e in g.events if e["event"] == "error"]
        check(not errs, "no error events (%s)" % errs[:2])
    for ext in (".json", ".cpstate", ".log"):
        p = os.path.expanduser("~/.local/share/primigenia/scenarios/agent-test" + ext)
        if os.path.exists(p):
            os.remove(p)
    shutil.rmtree(notes_tmp, ignore_errors=True)
    print("agent test: %d failure(s)" % failures)
    sys.exit(1 if failures else 0)


main()
