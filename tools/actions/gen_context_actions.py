#!/usr/bin/env python3
"""Writes the A72/A74/A75 context attack action files into godot/actions/data/ (schema cpore.action/1).

The files are plain data; this script only exists so that the 24 variants stay consistent with their base actions
(bite, charge, spit) and can be re-derived after a tweak. Run from the repository root:
    python3 tools/actions/gen_context_actions.py
Naming (the layer picks by C context): <move>[_walk|_gallop|_far][_b]; spit also _glob (held) and _far_charged.
Set B (A75, F10 option "attack set") adds a _b suffix to the cells the owner liked in their second option.
"""
import copy, json, os

D = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "actions", "data")


def load(n):
    return json.load(open(os.path.join(D, n + ".json")))


def save(a):
    with open(os.path.join(D, a["id"] + ".json"), "w") as f:
        json.dump(a, f, indent=1)
        f.write("\n")


def scale(a, ch, k):
    for t in a["tracks"] + [t for v in a.get("variants", []) for t in v.get("set", [])]:
        if t["ch"] == ch:
            for key in t.get("keys", []):
                key[2] = round(key[2] * k, 4)
    return a


def add(a, track):
    a["tracks"].append(track)
    return a


def derive(base, id, note, legs="free", ticks=None, move=None):
    a = copy.deepcopy(base)
    a["id"] = id
    a["note"] = note
    a["legs"] = legs
    a.pop("rooted", None)
    if ticks:
        a["ticks"] = ticks
    if move is not None:
        a["driver"] = {"kind": "c_move", "move": move}
    return a


def keys(*k):
    return [list(x) for x in k]


# ---------------------------------------------------------------- bite
bite, charge, spit, roar = load("bite"), load("charge"), load("spit"), load("roar")

# walking: the lab's on-the-move bite: lunge 0.12-0.20 m (0.4 of the standing one), dip 0.3, the legs keep the gait
w = derive(bite, "bite_walk", "A74 bite on the move: the standing lunge+peck at 0.4 of the body lunge and 0.3 of the dip; legs keep the gait, the head does the reach (attack_context.md).")
scale(w, "root.lunge", 0.4); scale(w, "root.lift", 0.3); scale(w, "root.pitch", 0.5)
save(w)
# galloping: snap at the neck in passing, 0.06 m body lunge, the head sweeps across (signed by the side of the target)
g = derive(bite, "bite_gallop", "A74 galloping bite: snap in passing. Body lunge 0.15, dip 0.3, the head swings across the target and the neck whips back (overshoot is C's).")
scale(g, "root.lunge", 0.15); scale(g, "root.lift", 0.3); scale(g, "root.pitch", 0.4)
add(g, {"ch": "head.yaw", "signed": True, "keys": keys(["w", 0, 0], ["w", 0.5, -0.3, "out"], ["a", 0, 0.35, "snap"], ["r", 0.5, 0.1], ["r", 1, 0, "inout"])})
add(g, {"ch": "root.roll", "signed": True, "keys": keys(["w", 0, 0], ["a", 0, -0.08, "snap"], ["r", 1, 0, "inout"])})
save(g)
# far: the charge (embestida): burst start, low head, dash-tackle at C's bite timing 3/1/2
f = derive(charge, "bite_far", "A74 charge (embestida) on the bite key from 5-20 m: the A67 dash-tackle look in C's 3/1/2 bite ticks. The run-in is the loco's burst; this layer lowers the head, stretches and slams, then rebounds (both recoil is C's knockback).",
           ticks={"w": 3, "a": 1, "r": 2}, move=0)
f["events"] = [{"at": ["w", 0.05], "emit": "drive"}, {"at": ["a", 0], "emit": "impact"}]
save(f)
# B: slow-step (walking) and run-up snap (far)
b = derive(bite, "bite_walk_b", "A75 set B, bite walking 'slow-step': the body eases off the stride while the lunge+peck lands (same C timing). Lunge 0.55, a sink in the stance.")
scale(b, "root.lunge", 0.55); scale(b, "root.lift", 1.2); scale(b, "root.pitch", 0.7)
save(b)
rs = derive(bite, "bite_far_b", "A75 set B, bite far 'run-up snap': no tackle, the body keeps running and only the head and neck snap at the end of the run-in (C is still the charge timing 3/1/2).",
            ticks={"w": 3, "a": 1, "r": 2})
scale(rs, "root.lunge", 0.2); scale(rs, "root.lift", 0.3)
add(rs, {"ch": "head.pitch", "keys": keys(["w", 0, 0], ["w", 0.6, 0.25, "out"], ["a", 0, -0.2, "snap"], ["r", 1, 0, "inout"])})
save(rs)

# ---------------------------------------------------------------- pounce (move 8)
def pounce(id, w, gather, arc, free, note, spring=False):
    a = {
        "schema": "cpore.action/1", "id": id, "class": "combat", "driver": {"kind": "c_move", "move": 8},
        "ticks": {"w": w, "a": 4, "r": 4}, "settle": 0.5, "priority": 60, "fade": {"in": 0.05, "out": 0.15, "cancel": 0.08},
        "legs": "free" if free else "plant", "side": "target", "note": note,
        "events": [{"at": ["w", 0.9], "emit": "drive"}, {"at": ["a", 0.5], "emit": "impact"}],
        "tracks": [
            # crouch-stalk freeze, then the spring (quick spring compresses the gather into the last third)
            {"ch": "root.lift", "keys": keys(["w", 0, 0], ["w", 0.35 if not spring else 0.8, -gather, "out"], ["w", 0.88, -gather], ["w", 1, -gather * 0.4, "in"],
                                          ["a", 0, 0.1, "out"], ["a", 0.45, arc, "out"], ["a", 1, -0.05, "in"], ["r", 0.3, -0.12, "out"], ["r", 1, 0, "inout"])},
            {"ch": "root.lunge", "keys": keys(["w", 0, 0], ["w", 0.4 if not spring else 0.8, -0.35, "out"], ["w", 0.88, -0.35], ["a", 0, 0.2, "snap"], ["a", 1, 0.45], ["r", 0.4, 0.2], ["r", 1, 0, "inout"])},
            {"ch": "root.pitch", "keys": keys(["w", 0, 0], ["w", 0.4, 0.14, "out"], ["w", 0.88, 0.14], ["a", 0, -0.12, "out"], ["a", 1, -0.3, "in"], ["r", 0.4, -0.1], ["r", 1, 0, "inout"])},
            {"ch": "head.aim", "goal": "target_head", "keys": keys(["w", 0.1, 0], ["w", 0.35, 1.0, "out"], ["a", 1, 1.0], ["r", 0.5, 0.3], ["r", 1, 0])},
            {"ch": "tail.pitch", "kin": 0, "keys": keys(["w", 0, 0], ["w", 0.4, 0.25, "out"], ["a", 0, 0.5, "snap"], ["a", 1, 0.2], ["r", 1, 0, "inout"])},
            {"ch": "tail.yaw", "osc": {"clock": "time", "hz": 5.0, "amp": 0.25, "shape": "sin"}, "env": keys(["w", 0.3, 0], ["w", 0.45, 1], ["w", 0.88, 1], ["a", 0, 0])},
            {"ch": "tail.stiff", "keys": keys(["w", 0.3, 0], ["a", 0, 2.0], ["a", 1, 2.0], ["r", 0, 0])},
            {"ch": "jaw.open", "keys": keys(["a", 0, 0], ["a", 0.6, 0.8, "out"], ["r", 0.2, 0.2], ["r", 1, 0])},
            {"ch": "lids", "keys": keys(["w", 0.2, 0], ["w", 0.4, 0.4, "out"], ["a", 1, 0.3], ["r", 1, 0])},
            # the pin: on a hit the front sits on the prey a moment, the head drops on it
            {"ch": "head.reach", "goal": "target_surface", "if": "hit", "keys": keys(["a", 0, 0], ["a", 1, 0.5], ["r", 0.3, 0.8, "out"], ["r", 1, 0.6], ["s", 0.6, 0, "inout"])},
            {"ch": "root.lift", "if": "hit", "keys": keys(["a", 1, 0], ["r", 0.2, -0.08], ["r", 1, -0.1], ["s", 0.6, 0, "inout"])},
        ],
        "variants": [{"when": {"has": ["legless"]}, "set": [{"ch": "root.lift", "keys": keys(["w", 0, 0], ["w", 0.8, -0.05], ["a", 0, 0.2, "out"], ["a", 0.5, arc * 0.6], ["a", 1, 0], ["r", 1, 0])}]}],
    }
    return a

save(pounce("pounce", 8, 0.22, 0.45, False, "A67/A74 cat pounce standing: crouch-stalk freeze, arcing leap, pin. C 8/4/4, the dash is C's 4.8 m."))
save(pounce("pounce_walk", 6, 0.12, 0.4, True, "A74 walking pounce: gather-leap. The gait slows into a low crouch (6 ticks), then the leap. C windup 6 with a walking body."))
save(pounce("pounce_gallop", 3, 0.06, 0.38, True, "A74 leap from the gallop: three ticks of gather over the stride, the leap carries the gallop (C windup 3)."))
save(pounce("pounce_far", 3, 0.08, 0.5, True, "A74 far pounce: run-in, leap at about 4 m (C windup 3 at the end of the run-in); a higher arc than the other leaps."))
save(pounce("pounce_b", 8, 0.22, 0.5, False, "A75 set B, pounce standing 'quick spring': the same C 8/4/4, but the gather is held low and sprung in the last 20 %.", spring=True))
save(pounce("pounce_walk_b", 6, 0.1, 0.42, True, "A75 set B, pounce walking 'leap off the stride': no gather, the leap springs straight off the stride (C windup 6, the gather is shallow and late).", spring=True))

# ---------------------------------------------------------------- spit (move 3)
sw = derive(spit, "spit_walk", "A74 jet on the move: the standing jet at 0.3 of the lunge, legs keep the gait.")
scale(sw, "root.lunge", 0.3)
save(sw)
sg = derive(spit, "spit_gallop", "A74 sideways parting shot at the gallop: the head swings across to the side while the body keeps running; the jet leaves at the fire frame.")
scale(sg, "root.lunge", 0.1)
for t in sg["tracks"]:
    if t["ch"] == "head.aim":
        t["keys"] = keys(["w", 0.4, 0], ["w", 0.6, 0.7, "out"], ["w", 0.85, 0.7], ["a", 0, 0], ["r", 0, 0])
add(sg, {"ch": "head.yaw", "signed": True, "keys": keys(["w", 0, 0], ["w", 0.6, 0.5, "out"], ["a", 0, 0.5], ["r", 1, 0, "inout"])})
add(sg, {"ch": "root.roll", "signed": True, "keys": keys(["w", 0, 0], ["w", 0.8, 0.06], ["r", 1, 0, "inout"])})
save(sg)
sf = derive(spit, "spit_far", "A74 llama lob, far: the head rears back and up and throws the glob high; the body stays planted. C 6/1/4, flight 11 ticks.", legs="plant")
for t in sf["tracks"]:
    if t["ch"] == "head.pitch":
        t["keys"] = keys(["w", 0, 0], ["w", 0.5, -0.1, "out"], ["w", 0.8, -0.1], ["w", 0.85, 0.7, "snap"], ["a", 0, 0.7], ["r", 0.6, 0.3], ["r", 1, 0])
    if t["ch"] == "head.aim":
        t["keys"] = keys(["w", 0.4, 0], ["w", 0.8, 0.3], ["a", 0, 0], ["r", 0, 0])
add(sf, {"ch": "root.pitch", "keys": keys(["w", 0, 0], ["w", 0.5, 0.1, "out"], ["w", 0.82, 0.1], ["a", 0, -0.08, "snap"], ["r", 1, 0, "inout"])})
save(sf)
sgl = derive(spit, "spit_glob", "A74 held spit, the charged glob: a longer visible charge in the sacs, a bigger throw, the body sinks into it. C 6/1/4 with hold (damage x1.8, flight 8).", legs="plant")
for t in sgl["tracks"]:
    if t["ch"] in ("sacs",):
        t["keys"] = keys(["w", 0, 0], ["w", 0.5, 1.4, "out"], ["w", 0.8, 1.4], ["w", 0.85, 0, "snap"], ["r", 1, 0])
    if t["ch"] == "body.inflate":
        t["keys"] = keys(["w", 0, 0], ["w", 0.5, 0.12, "out"], ["w", 0.8, 0.12], ["w", 0.85, -0.04, "snap"], ["r", 0.3, 0], ["r", 1, 0])
scale(sgl, "root.lunge", 1.6)
add(sgl, {"ch": "root.lift", "keys": keys(["w", 0, 0], ["w", 0.7, -0.05, "out"], ["a", 0, 0.03], ["r", 1, 0, "inout"])})
save(sgl)
sgw = derive(sgl, "spit_glob_walk", "A74/A75 glob on the move (hold or set B): the charged glob thrown without stopping; lunge 0.5.", legs="free")
scale(sgw, "root.lunge", 0.3)
save(sgw)
sfc = derive(sf, "spit_far_charged", "A74 held spit from far, the charged lob: the llama lob with the glob's heavy charge. C flight 13 ticks.", legs="plant")
for t in sfc["tracks"]:
    if t["ch"] == "sacs":
        t["keys"] = keys(["w", 0, 0], ["w", 0.5, 1.4, "out"], ["w", 0.8, 1.4], ["w", 0.85, 0, "snap"], ["r", 1, 0])
    if t["ch"] == "body.inflate":
        t["keys"] = keys(["w", 0, 0], ["w", 0.5, 0.12, "out"], ["w", 0.8, 0.12], ["w", 0.85, -0.04, "snap"], ["r", 0.3, 0], ["r", 1, 0])
save(sfc)

# ---------------------------------------------------------------- roar (move 10, C 6/1/6)
def roar_move(id, mode, note, legs):
    rear = mode in ("stand", "far")
    k = {"stand": 1.0, "far": 1.0, "walk": 0.5, "gallop": 0.35}[mode]
    pitch = 0.4 if rear else 0.14
    a = {
        "schema": "cpore.action/1", "id": id, "class": "combat", "driver": {"kind": "c_move", "move": 10},
        "ticks": {"w": 6, "a": 1, "r": 6}, "settle": 0.4, "priority": 60, "fade": {"in": 0.05, "out": 0.12, "cancel": 0.08},
        "legs": legs, "side": 1, "note": note,
        "events": [{"at": ["a", 0], "emit": "cry"}, {"at": ["a", 0], "emit": "shake"}] + ([{"at": ["w", 0.05], "emit": "drive"}] if mode == "far" else []),
        "tracks": [
            # rear-up: a short crouch, then the front rises; the bellow keeps the front low and pushes the head out
            {"ch": "root.pitch", "keys": keys(["w", 0, 0], ["w", 0.35, -0.05 * k, "out"], ["w", 0.9, pitch * (1.0 if rear else 0.5), "out"], ["a", 0, pitch], ["r", 0.55, pitch], ["r", 1, 0, "inout"])},
            {"ch": "root.lift", "keys": keys(["w", 0, 0], ["w", 0.35, -0.08 * k, "out"], ["w", 0.9, 0.06 * k, "out"], ["a", 0, 0.06 * k], ["r", 0.55, 0.05 * k], ["r", 1, 0, "inout"])},
            {"ch": "head.pitch", "keys": keys(["w", 0, 0], ["w", 0.9, 0.55 if rear else -0.12, "out"], ["a", 0, 0.6 if rear else -0.1], ["r", 0.55, 0.5 if rear else -0.1], ["r", 1, 0, "inout"])},
            {"ch": "head.reach", "keys": keys(["w", 0, 0], ["w", 0.9, -0.35 if rear else 0.25, "out"], ["a", 0, -0.3 if rear else 0.3], ["r", 0.55, -0.3 if rear else 0.2], ["r", 1, 0, "inout"])},
            {"ch": "body.inflate", "keys": keys(["w", 0, 0], ["w", 0.9, 0.12, "out"], ["a", 0, 0.14], ["r", 0.55, 0.12], ["r", 1, 0, "inout"])},
            {"ch": "jaw.open", "keys": keys(["w", 0.6, 0], ["a", 0, 1.0, "snap"], ["r", 0.55, 1.0], ["r", 0.7, 0, "snap"], ["r", 1, 0])},
            {"ch": "jaw.tremble", "osc": {"clock": "time", "hz": 18, "amp": 0.06, "shape": "sin"}, "env": keys(["a", 0, 0], ["a", 1, 1], ["r", 0.55, 1], ["r", 0.7, 0])},
            {"ch": "root.side", "osc": {"clock": "time", "hz": 18, "amp": 0.02 * k, "shape": "sin"}, "env": keys(["a", 0, 0], ["a", 1, 1], ["r", 0.55, 1], ["r", 0.7, 0])},
            {"ch": "tail.yaw", "osc": {"clock": "time", "hz": 2.5, "amp": 0.6, "shape": "sin"}, "env": keys(["a", 0, 0], ["a", 1, 1], ["r", 0.6, 1], ["r", 0.9, 0])},
            {"ch": "tail.stiff", "keys": keys(["a", 0, 2.0], ["r", 0.6, 2.0], ["r", 1, 0])},
            {"ch": "display", "keys": keys(["w", 0.5, 0], ["a", 0, 0.9, "snap"], ["r", 0.55, 0.9], ["r", 1, 0])},
            {"ch": "lids", "keys": keys(["a", 0, -0.3], ["r", 0.5, -0.3], ["r", 1, 0])},
            {"ch": "head.aim", "goal": "target_head", "keys": keys(["r", 0.5, 0], ["r", 0.8, 1.0], ["r", 1, 1.0])},
        ],
        "variants": [{"when": {"lacks": ["jaw", "pinch"]}, "drop": ["jaw.open", "jaw.tremble"], "set": [
            {"ch": "sacs", "osc": {"clock": "time", "hz": 4.0, "amp": 0.5, "shape": "sin"}, "env": keys(["a", 0, 0], ["a", 1, 1], ["r", 0.55, 1], ["r", 0.7, 0]), "keys": keys(["a", 0, 0.5], ["r", 0.55, 0.5], ["r", 0.7, 0])}]}],
    }
    return a

save(roar_move("roar_move", "stand", "A68/A74 rear-up roar, the roar move: crouch (3 ticks), the front rises and the cry on the fire tick, held, then the drop. C 6/1/6.", "plant"))
save(roar_move("roar_move_walk", "walk", "A74 bellow on the move: the head pushed out low, the chest swelling, the gait does not stop. C 6/1/6 layered.", "free"))
save(roar_move("roar_move_gallop", "gallop", "A74 bellow on the run: as the walking bellow with a smaller body motion; the run carries on and the overshoot is C's.", "free"))
save(roar_move("roar_move_far", "far", "A74 far roar: run in, plant (dust at the plant), rear up. The run-in is the loco's burst; C's roar plants at 3.2 m.", "plant"))
# A75 starting visual value: 1.15x the gallop chest swell; context action tests check the free gait and swell.
rfb = roar_move("roar_move_far_b", "gallop", "A75 far B: bellow in stride. The run carries on with a slightly bigger chest swell than the gallop bellow; no plant or rear-up.", "free")
scale(rfb, "body.inflate", 1.15)
save(rfb)
# ---------------------------------------------------------------- fear (the roar's victim)
save({
    "schema": "cpore.action/1", "id": "fear_cower", "class": "reaction", "driver": {"kind": "c_event", "event": "fear"},
    "ticks": {"w": 0, "a": 9, "r": 0}, "settle": 0.0, "priority": 25, "fade": {"in": 0.04, "out": 0.12, "cancel": 0.06}, "legs": "free", "side": 1,
    "note": "A74: a creature a roar frightens flinches low for about a second (the C fear status makes it run away; this is the pose).",
    "tracks": [
        {"ch": "root.lift", "keys": keys(["a", 0, 0], ["a", 0.12, -0.14, "out"], ["a", 0.7, -0.1], ["a", 1, 0, "inout"])},
        {"ch": "root.pitch", "keys": keys(["a", 0, 0], ["a", 0.15, 0.12, "out"], ["a", 1, 0, "inout"])},
        {"ch": "head.pitch", "keys": keys(["a", 0, 0], ["a", 0.15, 0.45, "out"], ["a", 0.7, 0.4], ["a", 1, 0, "inout"])},
        {"ch": "tail.pitch", "kin": 0, "keys": keys(["a", 0, 0], ["a", 0.15, -0.5, "out"], ["a", 0.7, -0.45], ["a", 1, 0, "inout"])},
        {"ch": "lids", "keys": keys(["a", 0, 0], ["a", 0.15, 0.5, "out"], ["a", 1, 0])},
    ],
})
print("wrote context actions into", os.path.abspath(D))
