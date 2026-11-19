#!/usr/bin/env python3
"""Writes plan_cases.json: the S1 parity table of the radial `plan` key (genome + expected error path or null).
One case per line so tests/test_plan.c can read it without a JSON parser. Run: python3 gen_plan_cases.py"""
import copy, json, os

def base():
    return {"schema": "cpore.creature/5", "name": "Plano",
            "nodes": [{"y": .03, "z": 0, "r": .12}, {"y": .09, "z": 0, "r": .3}, {"y": .15, "z": 0, "r": .26}, {"y": .21, "z": 0, "r": .08}],
            "parts": [{"type": "romo", "t": 0, "ang": 0, "size": .6, "level": 1, "tier": 0},
                      {"type": "pua", "t": .6, "ang": 0, "size": .5, "len": .3, "level": 1, "tier": 0}],
            "skin": {"pat": 2, "cA": "#8a5a32", "cB": "#d8b27a", "cC": "#cdb08a", "wet": .7, "scale": 7},
            "regions": [],
            "plan": {"sym": "radial", "fold": 5, "star": .3, "arm": {"len": 3, "w": .42, "taper": .85, "curl": .1, "tip": "point", "eye": 1, "act": "tubefeet"}}}

cases = []
def case(name, error, fn=None):
    g = base()
    if fn: fn(g)
    cases.append({"name": name, "error": error, "genome": g})

region = {"id": "r1", "schema": "cpore.growth/1", "family": "plates", "seed": 7, "count": 3, "length": 1, "curve": 0, "branches": 0, "surface": "torso", "position": .5, "coverage": .5, "angle": .3, "mirror": True}
case("radial ok", None)
case("no plan (bilateral) ok", None, lambda g: g.pop("plan"))
case("explicit bilateral ok", None, lambda g: g.update(plan={"sym": "bilateral"}))
case("fold 3 ok", None, lambda g: g["plan"].update(fold=3))
case("fold 8 ok", None, lambda g: g["plan"].update(fold=8))
case("no arm ok", None, lambda g: g["plan"].pop("arm"))
case("all arm keys ok", None, lambda g: g["plan"].update(gel=.7, star=1, arm={"len": 6, "w": 1, "taper": 0, "curl": -1, "droop": 1, "frill": 1, "tip": "bulb", "eye": 0, "act": "cilia"}))
case("single 1 ok", None, lambda g: g["parts"][1].update(single=1))
case("torso region ok", None, lambda g: g["regions"].append(region))
case("fold 2", "plan.fold", lambda g: g["plan"].update(fold=2))
case("fold 9", "plan.fold", lambda g: g["plan"].update(fold=9))
case("fold 2.5", "plan.fold", lambda g: g["plan"].update(fold=2.5))
case("fold missing", "plan.fold", lambda g: g["plan"].pop("fold"))
case("plan not an object", "plan", lambda g: g.update(plan=5))
case("sym biradial", "plan.sym", lambda g: g["plan"].update(sym="biradial"))
case("sym missing", "plan.sym", lambda g: g["plan"].pop("sym"))
case("unknown plan key", "plan.bogus", lambda g: g["plan"].update(bogus=1))
case("unknown arm key", "plan.arm.bogus", lambda g: g["plan"]["arm"].update(bogus=1))
case("star 1.5", "plan.star", lambda g: g["plan"].update(star=1.5))
case("gel -1", "plan.gel", lambda g: g["plan"].update(gel=-1))
case("arm len 7", "plan.arm.len", lambda g: g["plan"]["arm"].update(len=7))
case("arm w .05", "plan.arm.w", lambda g: g["plan"]["arm"].update(w=.05))
case("arm tip bad", "plan.arm.tip", lambda g: g["plan"]["arm"].update(tip="claw"))
case("arm eye 2", "plan.arm.eye", lambda g: g["plan"]["arm"].update(eye=2))
case("arm act muscle", "plan.arm.act", lambda g: g["plan"]["arm"].update(act="muscle"))
case("node z != 0", "plan.nodes", lambda g: g["nodes"][2].update(z=.2))
case("node y not increasing", "plan.nodes", lambda g: g["nodes"][2].update(y=.02))
case("leg part pata", "plan.legs", lambda g: g["parts"].append({"type": "pata", "t": .5, "ang": 2, "w": .2, "k": [.1, -.2, 0], "f": [.2, -.4, 0], "level": 1, "tier": 0}))
case("leg part leg_sucker", "plan.legs", lambda g: g["parts"].append({"type": "leg_sucker", "t": .5, "ang": 2, "size": 1, "level": 1, "tier": 0}))
case("single -1", "parts.single", lambda g: g["parts"][1].update(single=-1))
case("region surface neck", "regions.surface", lambda g: g["regions"].append(dict(region, surface="neck")))
case("bilateral keeps z free", None, lambda g: (g["plan"].update(sym="bilateral"), g["nodes"][2].update(z=.2)))

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "plan_cases.json"), "w") as f:
    f.write("[\n" + ",\n".join(json.dumps(c, separators=(",", ":")) for c in cases) + "\n]\n")
print(len(cases), "cases")
