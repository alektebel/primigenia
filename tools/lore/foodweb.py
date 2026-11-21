#!/usr/bin/env python3
"""Primigenia food web (brief docs/briefs/trophic-web.md): data lore/foodweb/<world>.json, checks, pyramid spawn weights, report.

  python3 tools/lore/foodweb.py check            consistency (also run by tools/lore/validate.py)
  python3 tools/lore/foodweb.py apply            write niche.trophic/role, prey/predators, food_for and weights from the web file into the lore JSON
  python3 tools/lore/foodweb.py weights          recompute the pyramid spawn weights in the web file

The web file lists members {id: {kind, level, role, habitats, eats, defended, new, slot, spawn}}. `eats` holds ids of other members or resources
(carrion, detritus, dung). The check enforces: no dangling ids, every consumer has a food source in its habitat, no species is a dead end
(unless apex or listed in no_predator), pyramid weights sum to 100 per habitat and kind, and the batch quotas.
"""
import argparse, glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "council"))
from lorelib import ROOT, load, dump
from foodweb_classify import H, LEVELS, RESOURCES

MAIN = ["meadow", "forest", "shore", "shallows", "caves", "spring", "highlands"]
ROLES = ["photosynthetic", "chemosynthetic", "mixotroph", "grazer", "browser", "frugivore", "granivore", "nectarivore", "filter_feeder", "algae_scraper", "insectivore", "small_predator", "egg_thief", "mid_predator",
         "apex_predator", "scavenger", "detritivore", "fungal_decomposer", "parasite", "parasitoid", "omnivore", "cleaner", "seed_disperser", "pollinator"]
MUTUALIST = {"cleaner", "seed_disperser", "pollinator"}
RANK = {"producer": 1, "decomposer": 1.5, "primary_consumer": 2, "parasite": 2.5, "secondary_consumer": 3, "scavenger": 3, "omnivore": 3, "tertiary_consumer": 4, "apex_predator": 5}
# Starting values (tracker test L-TROPHIC): about 10% transfer per level (Lindeman 1942), derivation sheet D25. Scavenger, decomposer, parasite, omnivore are placed on the level whose flux feeds them.
LEVEL_W = {"primary_consumer": 100.0, "decomposer": 100.0, "omnivore": 30.0, "secondary_consumer": 10.0, "parasite": 10.0, "scavenger": 3.0, "tertiary_consumer": 1.0, "apex_predator": 0.1}
PLANT_W = {"photosynthetic": 10.0, "chemosynthetic": 3.0, "mixotroph": 2.0, "fungal_decomposer": 5.0, "parasite": 1.0}


def web_path(root, world="primigenia"): return os.path.join(root, "lore", "foodweb", world + ".json")


def spawn_weights(members):
    """-> {id: {habitat: weight}}; creatures and plants are normalised separately, each habitat sums to 100."""
    out = {m: {} for m in members}
    for h in H:
        for kind in ("creature", "plant"):
            ids = [i for i, m in members.items() if m["kind"] == kind and h in m["habitats"]]
            if not ids: continue
            if kind == "creature":
                cnt = {}
                for i in ids: cnt[members[i]["level"]] = cnt.get(members[i]["level"], 0) + 1
                raw = {i: LEVEL_W[members[i]["level"]] / cnt[members[i]["level"]] for i in ids}
            else:
                raw = {i: PLANT_W[members[i]["role"]] * (0.2 if members[i].get("defended") else 1.0) for i in ids}
            tot = sum(raw.values())
            for i in ids: out[i][h] = round(100 * raw[i] / tot, 3)
            drift = round(100 - sum(out[i][h] for i in ids), 3)
            if drift: out[max(ids, key=lambda i: out[i][h])][h] = round(out[max(ids, key=lambda i: out[i][h])][h] + drift, 3)
    return out


def check_web(root, world="primigenia"):
    errors, warnings = [], []
    p = web_path(root, world)
    if not os.path.exists(p): return errors, warnings
    fn = os.path.relpath(p, root); web = load(p); M = web["members"]
    cdir, fdir = os.path.join(root, "lore", "creatures"), os.path.join(root, "lore", "flora")
    for i, m in M.items():
        f = os.path.join(cdir if m["kind"] == "creature" else fdir, i + ".json")
        if not os.path.exists(f): errors.append(f"{fn}: {i}: no lore file {os.path.relpath(f, root)}"); continue
        d = load(f)
        if d.get("world") != world: errors.append(f"{fn}: {i}: world is {d.get('world')}")
        ni = d.get("niche", {}) if m["kind"] == "plant" or "niche" in d else {}
        if ni.get("trophic") != m["level"] or ni.get("role") != m["role"]:
            errors.append(f"{fn}: {i}: niche.trophic/role in the lore file ({ni.get('trophic')}/{ni.get('role')}) differ from the web ({m['level']}/{m['role']}); run foodweb.py apply")
        if m["level"] not in LEVELS: errors.append(f"{fn}: {i}: bad level {m['level']}")
        if m["role"] not in ROLES: errors.append(f"{fn}: {i}: bad role {m['role']}")
        for h in m["habitats"]:
            if h not in H: errors.append(f"{fn}: {i}: unknown habitat {h}")
        for e in m.get("eats", []):
            if e not in M and e not in RESOURCES: errors.append(f"{fn}: {i}: eats '{e}', which is neither a member nor a resource (dangling id)")
            if e == i: errors.append(f"{fn}: {i}: eats itself")
    # all lore files of the world are classified
    for pth in sorted(glob.glob(os.path.join(cdir, "*.json"))):
        c = load(pth)
        if c.get("world") == world and c["id"] not in M: errors.append(f"{fn}: creature {c['id']} of {world} is not in the web")
    for pth in sorted(glob.glob(os.path.join(fdir, "*.json"))):
        c = load(pth)
        if c.get("world") == world and c["id"] not in M: errors.append(f"{fn}: plant {c['id']} of {world} is not in the web")
    eaten_by = {i: [] for i in M}
    for i, m in M.items():
        for e in m.get("eats", []):
            if e in M: eaten_by[e].append(i)
    share = lambda a, b: bool(set(M[a]["habitats"]) & set(M[b]["habitats"]))
    for i, m in M.items():
        if m["kind"] == "creature" or m["level"] in ("parasite", "decomposer"):
            if not m.get("eats"): errors.append(f"{fn}: {i}: a consumer with nothing to eat")
        for e in m.get("eats", []):
            ok = False
            if e == "carrion": ok = any(M[j]["kind"] == "creature" and j != i and share(i, j) for j in M)
            elif e == "detritus": ok = any(M[j]["kind"] == "plant" and share(i, j) for j in M)
            elif e == "dung": ok = any(M[j]["kind"] == "creature" and M[j]["level"] in ("primary_consumer", "omnivore") and share(i, j) for j in M)
            else:
                ok = share(i, e)
                if ok and RANK[m["level"]] <= RANK[M[e]["level"]] and m["level"] not in ("decomposer", "scavenger", "omnivore", "parasite") and not (m["level"] == "producer" and m["role"] == "mixotroph") and M[e]["level"] not in ("parasite",):
                    errors.append(f"{fn}: {i} ({m['level']}) eats {e} ({M[e]['level']}): a consumer must sit above its food")
                if not ok: errors.append(f"{fn}: {i} eats {e} but they share no habitat")
            if e in RESOURCES and not ok: errors.append(f"{fn}: {i} eats {e} but the habitat has none")
        # nobody-eats-it check
        nb = [j for j in eaten_by[i] if share(i, j)]
        if m["level"] == "apex_predator":
            if not any(M[j]["level"] == "scavenger" and "carrion" in M[j].get("eats", []) and share(i, j) for j in M):
                errors.append(f"{fn}: {i}: apex without a scavenger of carrion in its habitat")
        elif not nb and i not in web.get("no_predator", {}):
            if m["kind"] == "plant" and m.get("defended"): warnings.append(f"{fn}: {i}: defended plant, only decomposers use it")
            else: errors.append(f"{fn}: {i} ({m['level']}) is a dead end: nothing eats it in its habitat")
    # decomposer coverage of detritus in each habitat that has any plant
    for h in H:
        if any(m["kind"] == "plant" and h in m["habitats"] for m in M.values()) and not any(m["level"] == "decomposer" and h in m["habitats"] for m in M.values()):
            warnings.append(f"{fn}: habitat {h} has plants but no decomposer")
    # weights
    sp = spawn_weights(M)
    for i, m in M.items():
        if m.get("spawn") != sp[i]: errors.append(f"{fn}: {i}: spawn weights are stale; run foodweb.py weights")
    for h in H:
        for kind in ("creature", "plant"):
            ids = [i for i, m in M.items() if m["kind"] == kind and h in m["habitats"]]
            if ids and abs(sum(M[i]["spawn"].get(h, 0) for i in ids) - 100) > 0.01: errors.append(f"{fn}: {h}/{kind}: spawn weights sum to {sum(M[i]['spawn'].get(h, 0) for i in ids):.3f}, not 100")
        lv = {}
        for i, m in M.items():
            if m["kind"] == "creature" and h in m["habitats"] and m["level"] in ("primary_consumer", "secondary_consumer", "tertiary_consumer", "apex_predator"): lv.setdefault(m["level"], []).append(M[i]["spawn"][h])
        order = [max(lv[l]) for l in ("primary_consumer", "secondary_consumer", "tertiary_consumer", "apex_predator") if l in lv]
        if order != sorted(order, reverse=True): errors.append(f"{fn}: {h}: pyramid not monotonic {order}")
    # quotas
    cnt = lambda lv, new=None: sum(1 for m in M.values() if m["level"] == lv and (new is None or m.get("new", False) == new))
    q = [("apex_predator", 2), ("scavenger", 3), ("decomposer", 3)]
    for lv, n in q:
        if cnt(lv, True) < n: errors.append(f"{fn}: needs at least {n} new {lv}, has {cnt(lv, True)}")
    if not any(m["role"] == "chemosynthetic" and m.get("new") for m in M.values()): errors.append(f"{fn}: no new chemosynthetic producer")
    if cnt("parasite", True) < 1: errors.append(f"{fn}: no new parasite")
    if not any(m["role"] in MUTUALIST for m in M.values() if m.get("new")): errors.append(f"{fn}: no new mutualist")
    for h in MAIN:
        for lv in ("producer", "primary_consumer", "secondary_consumer"):
            if not any(m["level"] == lv and h in m["habitats"] for m in M.values()): errors.append(f"{fn}: habitat {h} has no {lv}")
        if not any(m["level"] in ("tertiary_consumer", "apex_predator") and h in m["habitats"] for m in M.values()): errors.append(f"{fn}: habitat {h} has no top predator")
    return errors, warnings


def apply_web(root, world="primigenia"):
    web = load(web_path(root, world)); M = web["members"]
    sp = spawn_weights(M)
    for i in M: M[i]["spawn"] = sp[i]
    dump(web, web_path(root, world))
    eaten_by = {i: [] for i in M}
    for i, m in M.items():
        for e in m.get("eats", []):
            if e in M: eaten_by[e].append(i)
    for i, m in M.items():
        f = os.path.join(root, "lore", "creatures" if m["kind"] == "creature" else "flora", i + ".json"); d = load(f); ch = False
        if m["kind"] == "creature":
            ni = d["niche"]
            want = {"trophic": m["level"], "role": m["role"]}
            if any(ni.get(k) != v for k, v in want.items()): ni.update(want); ch = True
            if m.get("new"):  # new species: prey and predators from the web (existing species keep their written text)
                pre = [e for e in m.get("eats", []) if e in M and M[e]["kind"] == "creature"]
                prd = eaten_by[i]
                if ni.get("prey") != pre and pre: ni["prey"] = pre; ch = True
                if ni.get("predators") != prd: ni["predators"] = prd; ch = True
        else:
            want = {"trophic": m["level"], "role": m["role"]}
            if d.get("niche") != want: d["niche"] = want; ch = True
            fo = sorted(eaten_by[i])
            if m.get("new") or not d["gameplay"].get("food_for"):
                if fo and d["gameplay"].get("food_for") != fo and m.get("new"): d["gameplay"]["food_for"] = fo; ch = True
        if ch: dump(d, f)
    print("applied", len(M), "members")


def main():
    ap = argparse.ArgumentParser(description=__doc__); ap.add_argument("cmd", choices=["check", "apply", "weights"]); ap.add_argument("--root", default=ROOT); a = ap.parse_args()
    if a.cmd == "weights":
        web = load(web_path(a.root)); sp = spawn_weights(web["members"])
        for i in web["members"]: web["members"][i]["spawn"] = sp[i]
        dump(web, web_path(a.root)); print("weights written")
    elif a.cmd == "apply": apply_web(a.root)
    else:
        e, w = check_web(a.root)
        for x in w: print("warning:", x)
        for x in e: print("error:", x)
        print(f"lore foodweb: {len(e)} error(s), {len(w)} warning(s)"); return 1 if e else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
