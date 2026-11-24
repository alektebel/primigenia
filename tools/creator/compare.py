#!/usr/bin/env python3
"""Compare two creator scorecard runs: compare.py <baseline> <label> [--root docs/evidence/godot/creator-score]
B (label) against A (baseline), per check: improved / regressed / unchanged, plus the gates and the editor frame time.
A check that flips pass->fail regressed, fail->pass improved; otherwise a numeric value is judged by its distance to the target
(unchanged inside 3 percent / 0.01 absolute). Gates regress when pass becomes anything else. Exit 1 when a gate regressed or
the run has more regressions than improvements (the keep-or-revert rule of LOOP.md)."""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "godot", "creator-score")
REL = 0.03


def load(label):
    d = label if os.path.isdir(label) else os.path.join(ROOT, label)
    return d, json.load(open(os.path.join(d, "summary.json")))


def num(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def dist(c):
    t = c["target"]
    if isinstance(t, str):      # "<=0.15 (ref 0.13)" / ">=3 (ref 4)": distance past the bound, 0 inside it
        try:
            op, rest = t[:2], float(t[2:].split()[0])
        except ValueError:
            return None
        v = num(c["value"])
        if v is None:
            return None
        return max(0.0, v - rest) if op == "<=" else max(0.0, rest - v)
    v, t = num(c["value"]), num(t)
    return None if v is None or t is None else abs(v - t)


def verdict(a, b):
    if a["pass"] != b["pass"]:
        return "improved" if b["pass"] else "regressed"
    da, db = dist(a), dist(b)
    if da is None or db is None:
        return "unchanged"
    if abs(db - da) <= max(0.01, REL * abs(da)):
        return "unchanged"
    return "improved" if db < da else "regressed"


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    da, A = load(args[0])
    db, B = load(args[1])
    ca = {c["id"]: c for c in A["checks"]}
    counts = {"improved": 0, "regressed": 0, "unchanged": 0}
    rows = ["| check | A | B | target | verdict |", "|---|---|---|---|---|"]
    gate_regress = []
    for c in B["checks"]:
        a = ca.get(c["id"])
        if a is None:
            continue
        if c["group"] == "gates":
            if a["value"] == "pass" and c["value"] != "pass":
                gate_regress.append(c["id"])
            if a["value"] != c["value"]:
                rows.append("| %s | %s | %s | pass | GATE %s |" % (c["id"], a["value"], c["value"], "REGRESSED" if c["id"] in gate_regress else "changed"))
            continue
        v = verdict(a, c)
        counts[v] += 1
        if v != "unchanged":
            rows.append("| %s | %s | %s | %s | %s |" % (c["id"], a["value"], c["value"], c["target"], v))
    print("# creator compare %s -> %s" % (A["label"], B["label"]))
    print("score %d/%d -> %d/%d" % (A["passed"], A["total"], B["passed"], B["total"]))
    print("improved %(improved)d, regressed %(regressed)d, unchanged %(unchanged)d (checks)" % counts)
    x, y = A["frame_ms_median"], B["frame_ms_median"]
    slow = y > 1.3 * x
    print("editor frame ms median %s -> %s (%s; software GL on a shared CPU, only a change over 30%% means anything)" % (x, y, "SLOWER" if slow else "unchanged" if abs(y - x) <= 0.3 * x else "faster"))
    print("gates: " + ", ".join("%s %s -> %s" % (k, A["gates"].get(k), B["gates"].get(k)) for k in B["gates"]))
    print("\n".join(rows))
    bad = bool(gate_regress) or counts["regressed"] > counts["improved"]
    print("KEEP" if not bad else "REVERT (%s)" % ("gate " + ",".join(gate_regress) if gate_regress else "more regressions than improvements"))
    sys.exit(1 if bad else 0)


main()
