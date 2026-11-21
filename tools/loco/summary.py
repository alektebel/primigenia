#!/usr/bin/env python3
"""L0 scorecard summary: reads <dir>/<body>_<scenario>.json, applies docs/research/loco-reference.json, writes summary.json and summary.md.
Usage: summary.py <label dir> [targets.json]"""
import json, os, sys

SCEN = ["walk", "gallop", "turn", "climb", "steps"]
BODIES = ["mite", "trotter", "hero", "giant", "longneck", "centipede", "hexapod", "start0", "startA", "startB", "startC", "startD"]
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TARGETS = os.path.join(HERE, "..", "..", "docs", "research", "loco-reference.json")


def get(metrics, path):
    cur = metrics
    for k in path.split("."):
        if not isinstance(cur, dict) or k not in cur:
            return None
        cur = cur[k]
    return cur


def judge(op, v, target, tol):
    if op == "<": return v < target
    if op == "<=": return v <= target
    if op == ">": return v > target
    if op == ">=": return v >= target
    if op == "==": return abs(v - target) < 1e-9
    if op == "within": return abs(v - target) <= tol
    raise ValueError(op)


def load_cases(d):
    cases = {}
    for b in BODIES:
        for s in SCEN:
            p = os.path.join(d, "%s_%s.json" % (b, s))
            if os.path.exists(p):
                cases[(b, s)] = json.load(open(p))
    return cases


def derive(cases):
    # climb_posture_shift_deg: the back slope on the climb vs the same body's walk
    for (b, s), c in cases.items():
        if s != "climb":
            continue
        w = cases.get((b, "walk"))
        a = c["metrics"].get("back_slope_deg")
        z = w["metrics"].get("back_slope_deg") if w else None
        if a is None or z is None:
            c["metrics"]["climb_posture_shift_deg"] = None
            c.setdefault("reasons", {})["climb_posture_shift_deg"] = "no back slope (one leg pair only) or no walk case"
        else:
            c["metrics"]["climb_posture_shift_deg"] = round(abs(a - z), 2)


def checks_for(body, scen, targets):
    out = []
    legs = targets["bodies"][body]["legs"]
    for u in targets["universal"]:
        if u["scenarios"] != "all" and scen not in u["scenarios"]:
            continue
        if u["bodies"] != "all" and body not in u["bodies"]:
            continue
        if legs > u.get("max_legs", 99) or legs < u.get("min_legs", 0):
            continue
        out.append({"id": u["id"], "metric": u["metric"], "op": u["op"], "value": u["value"], "tolerance": u.get("tolerance"), "source": u["source"]})
    ref = targets["mapping"].get(body)
    if ref and scen in targets["references"][ref]["scenarios"]:
        for path, t in targets["references"][ref]["metrics"].items():
            out.append({"id": "%s:%s" % (ref.split("_")[0], path.split(".")[0]), "metric": path, "op": "within", "value": t["value"], "tolerance": t["tolerance"], "source": t["source"]})
    return out


def fmt(v, nd=2):
    if v is None: return "-"
    if isinstance(v, float): return ("%." + str(nd) + "f") % v
    return str(v)


def main():
    d = sys.argv[1]
    targets = json.load(open(sys.argv[2] if len(sys.argv) > 2 else DEFAULT_TARGETS))
    cases = load_cases(d)
    derive(cases)
    rows = []
    for (b, s), c in cases.items():
        res = []
        for ck in checks_for(b, s, targets):
            v = get(c["metrics"], ck["metric"])
            if v is None:
                res.append(dict(ck, actual=None, verdict="N/A", reason=c.get("reasons", {}).get(ck["metric"].split(".")[0], "not measured")))
            else:
                res.append(dict(ck, actual=v, verdict="PASS" if judge(ck["op"], v, ck["value"], ck["tolerance"]) else "FAIL"))
        rows.append({"body": b, "scenario": s, "checks": res, "metrics": c["metrics"]})
    json.dump({"label": os.path.basename(os.path.normpath(d)), "rows": rows}, open(os.path.join(d, "summary.json"), "w"), indent=1, sort_keys=True)
    L = ["# Locomotion scorecard `%s`" % os.path.basename(os.path.normpath(d)), "",
         "Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.", "",
         "| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | limp index | verdict |",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        m = r["metrics"]
        hp = m.get("head_pitch_deg")
        bob = m.get("torso_bob_frac")
        nf = sum(1 for x in r["checks"] if x["verdict"] == "FAIL")
        nc = sum(1 for x in r["checks"] if x["verdict"] != "N/A")
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["body"], r["scenario"], "%s / %s" % (fmt(hp["mean"], 1), fmt(hp["p95"], 1)) if hp else "-", fmt(m.get("shoulder_hip_ratio")), fmt(m.get("back_slope_deg"), 1),
            fmt(m.get("torso_roll_deg"), 1), fmt(m.get("roll_plant_lag")), fmt(bob * 100 if bob is not None else None, 1),
            fmt((m.get("foot_slip_cm") or {}).get("p95"), 1) if m.get("foot_slip_cm") else "-", fmt((m.get("duty_factor") or {}).get("mean")) if m.get("duty_factor") else "-",
            fmt(m.get("airborne_frac")), fmt(m.get("leg_extension")), fmt(m.get("foot_spacing_ratio")), fmt(m.get("pivot_frac")), fmt(m.get("stall_frac")),
            fmt(m.get("min_turn_radius_m"), 1), fmt(m.get("knee_flip_frac")), fmt((m.get("foot_penetration_cm") or {}).get("p95")), fmt(m.get("gait_symmetry")), fmt(m.get("limp_index")), ("**FAIL** %d/%d" % (nf, nc)) if nf else ("PASS 0/%d" % nc)))
    L += ["", "## Known problems and the checks that catch them", "", "| known problem | checks | failing rows / checked rows |", "|---|---|---|"]
    for prob, ids in targets["known_problems"].items():
        f = c_ = 0
        for r in rows:
            for x in r["checks"]:
                if x["id"] in ids or any(i.startswith("gorilla:") and x["id"].startswith("gorilla:") and x["id"].split(":")[1] == i.split(":")[1] for i in ids):
                    if x["verdict"] != "N/A":
                        c_ += 1
                        f += x["verdict"] == "FAIL"
        L.append("| %s | %s | %d / %d |" % (prob, ", ".join(ids), f, c_))
    L += ["", "## Failing checks", ""]
    for r in rows:
        bad = ["%s %s%s (%s)" % (x["id"], fmt(x["actual"], 3), {"within": " vs %s+-%s" % (x["value"], x["tolerance"])}.get(x["op"], " vs %s%s" % (x["op"], x["value"])), x["metric"]) for x in r["checks"] if x["verdict"] == "FAIL"]
        if bad:
            L.append("- **%s %s**: %s" % (r["body"], r["scenario"], "; ".join(bad)))
    open(os.path.join(d, "summary.md"), "w").write("\n".join(L) + "\n")
    print("\n".join(L[:3 + len(rows) + 4]))


main()
