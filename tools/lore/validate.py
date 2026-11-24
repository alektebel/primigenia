#!/usr/bin/env python3
"""Validate lore/ against its schemas and the cross-checks of docs/LORE-FORMAT.md 4.6.

  python3 tools/lore/validate.py [--root DIR]

Exit 1 on errors; warnings (unresolved relation targets of draft creatures) do not fail.
"""
import argparse, os, sys
import jsonschema
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load, creature_files, flora_files, has_game_numbers


def _path(err):
    return "$" + "".join(f"[{p}]" if isinstance(p, int) else f".{p}" for p in err.absolute_path)


def schema_errors(inst, schema, rel):
    v = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
    return [f"{rel}: {_path(e)}: {e.message[:200]}" for e in sorted(v.iter_errors(inst), key=lambda e: list(map(str, e.absolute_path)))]


def validate_all(root):
    errors, warnings = [], []
    sd = os.path.join(root, "lore", "schema")
    sch = {n: load(os.path.join(sd, f"{n}.schema.json")) for n in ("creature", "world", "references")}
    rel = lambda p: os.path.relpath(p, root)

    refs_p = os.path.join(root, "lore", "references.json")
    refs = load(refs_p) if os.path.exists(refs_p) else None
    if refs is None: errors.append("lore/references.json: missing")
    wdir = os.path.join(root, "lore", "worlds")
    worlds = {}  # id -> (all fact ids, active fact ids)
    wfiles = sorted(os.path.join(wdir, n) for n in os.listdir(wdir) if n.endswith(".json") and not n.endswith(".derivation.json")) if os.path.isdir(wdir) else []
    if not wfiles: errors.append("lore/worlds: no world files")
    status = {}
    if refs is not None:
        errors += schema_errors(refs, sch["references"], rel(refs_p))
        for i, r in enumerate(refs):
            if r.get("id") in status: errors.append(f"lore/references.json: $[{i}].id: duplicate reference id {r.get('id')}")
            status[r.get("id")] = r.get("x-status")

    def check_refs(file, path, ids):
        for rid in ids:
            if rid not in status: errors.append(f"{file}: {path}: reference '{rid}' not in references.json")
            elif status[rid] == "rejected": errors.append(f"{file}: {path}: reference '{rid}' is rejected and must not be cited")

    for wp in wfiles:
        w = load(wp)
        fn = rel(wp)
        errors += schema_errors(w, sch["world"], fn)
        if w.get("id") != os.path.basename(wp)[:-5]:
            errors.append(f"{fn}: $.id: id '{w.get('id')}' does not match the file name")
        allf, act, seen = set(), set(), set()
        for i, f in enumerate(w.get("facts", [])):
            fid = f.get("id")
            if fid in seen: errors.append(f"{fn}: $.facts[{i}].id: duplicate fact id {fid}")
            seen.add(fid); allf.add(fid)
            if f.get("status") == "active": act.add(fid)
            if w.get("kind") == "real" and f.get("status") == "active" and not f.get("refs"):
                errors.append(f"{fn}: $.facts[{i}].refs: fact {fid} of a real world must cite references")
            check_refs(fn, f"$.facts[{i}].refs", f.get("refs", []))
        worlds[w.get("id")] = (allf, act)

    cres = []
    for p in creature_files(root):
        c = load(p)
        errors += schema_errors(c, sch["creature"], rel(p))
        cres.append((rel(p), c))

    ids = {}
    for fn, c in cres:
        cid = c.get("id")
        if cid != os.path.basename(fn)[:-5]:
            errors.append(f"{fn}: $.id: id '{cid}' does not match the file name")
        ids[cid] = fn
    targets = set(ids)
    for _, c in cres:
        targets.update(a.lower() for a in c.get("aliases", []))
    targets = {t.lower() for t in targets if t}
    targets |= {str(load(p).get('id', '')).lower() for p in flora_files(root)} - {''}  # creatures may relate to plants (food, shelter)

    chain_ids, skill_ids = {}, {}
    for fn, c in cres:
        cid = c.get("id", "")
        wid = c.get("world")
        if wid not in worlds:
            errors.append(f"{fn}: $.world: world '{wid}' has no file lore/worlds/{wid}.json")
        all_facts, active = worlds.get(wid, (set(), set()))
        for i, ch in enumerate(c.get("chains", [])):
            base = f"$.chains[{i}]"
            chid = ch.get("id", "")
            if not chid.startswith(cid + "."): errors.append(f"{fn}: {base}.id: chain id '{chid}' is not prefixed by '{cid}.'")
            if chid in chain_ids: errors.append(f"{fn}: {base}.id: duplicate chain id '{chid}' (also in {chain_ids[chid]})")
            chain_ids.setdefault(chid, fn)
            for j, r in enumerate(ch.get("roots", [])):
                if r not in all_facts: errors.append(f"{fn}: {base}.roots[{j}]: fact '{r}' does not exist in world '{wid}'")
                elif r not in active: errors.append(f"{fn}: {base}.roots[{j}]: fact '{r}' is retired in world '{wid}'")
            sk = ch.get("skill", {}).get("id")
            if sk:
                if sk in skill_ids: errors.append(f"{fn}: {base}.skill.id: duplicate skill id '{sk}' (also in {skill_ids[sk]})")
                skill_ids.setdefault(sk, fn)
                if not sk.startswith(cid + "."): errors.append(f"{fn}: {base}.skill.id: skill id '{sk}' is not prefixed by '{cid}.'")
            skx = ch.get("skill", {})
            if has_game_numbers(skx.get("effect", "")):
                warnings.append(f"{fn}: {base}.skill: game numbers in skill text (digits with %/turns/s/m) ; skills are name + role + plain behaviour (A102.3)")
            pl = ch.get("plausibility", {})
            for k, a in enumerate(pl.get("analogues", [])):
                check_refs(fn, f"{base}.plausibility.analogues[{k}].refs", a.get("refs", []))
        for i, r in enumerate(c.get("relations", [])):
            w = r.get("with", "")
            if w.lower() not in targets:
                msg = f"{fn}: $.relations[{i}].with: '{w}' is not a known creature id or alias"
                (warnings if c.get("status") == "draft" else errors).append(msg)
            via = r.get("via", "")
            if via and via.startswith("F") and via[1:].isdigit() and via not in all_facts:
                errors.append(f"{fn}: $.relations[{i}].via: fact '{via}' does not exist in world '{wid}'")
    # flora (cpore.plant/1): schema, world + roots, references, relations to known creatures/plants
    plants = [(rel(p), load(p)) for p in flora_files(root)]
    if plants:
        psch = load(os.path.join(sd, "plant.schema.json"))
        pids = {c.get("id") for _, c in plants}
        for fn, c in plants:
            errors += schema_errors(c, psch, fn)
            pid = c.get("id", "")
            if pid != os.path.basename(fn)[:-5]: errors.append(f"{fn}: $.id: id '{pid}' does not match the file name")
            wid = c.get("world")
            if wid not in worlds: errors.append(f"{fn}: $.world: world '{wid}' has no file lore/worlds/{wid}.json")
            all_facts, active = worlds.get(wid, (set(), set()))
            for i, ch in enumerate(c.get("chains", [])):
                base = f"$.chains[{i}]"
                if not ch.get("id", "").startswith(pid + "."): errors.append(f"{fn}: {base}.id: chain id '{ch.get('id')}' is not prefixed by '{pid}.'")
                if ch.get("id") in chain_ids: errors.append(f"{fn}: {base}.id: duplicate chain id '{ch.get('id')}' (also in {chain_ids[ch.get('id')]})")
                chain_ids.setdefault(ch.get("id"), fn)
                for j, r in enumerate(ch.get("roots", [])):
                    if r not in all_facts: errors.append(f"{fn}: {base}.roots[{j}]: fact '{r}' does not exist in world '{wid}'")
                    elif r not in active: errors.append(f"{fn}: {base}.roots[{j}]: fact '{r}' is retired in world '{wid}'")
                for k, a in enumerate(ch.get("plausibility", {}).get("analogues", [])):
                    check_refs(fn, f"{base}.plausibility.analogues[{k}].refs", a.get("refs", []))
            for i, r in enumerate(c.get("relations", [])):
                if r.get("with", "").lower() not in targets and r.get("with") not in pids:
                    (warnings if c.get("status") == "draft" else errors).append(f"{fn}: $.relations[{i}].with: '{r.get('with')}' is not a known creature, alias or plant")
    # derivation sheets (lore/rules/derivation.md) and the food web (docs/briefs/trophic-web.md)
    from derivation import validate_derivations
    from foodweb import check_web
    e, w = validate_derivations(root); errors += e; warnings += w
    e, w = check_web(root); errors += e; warnings += w
    return errors, warnings


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=ROOT)
    a = ap.parse_args()
    errors, warnings = validate_all(a.root)
    for w in warnings: print("warning:", w)
    for e in errors: print("error:", e)
    print(f"lore validate: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
