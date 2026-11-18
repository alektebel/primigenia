#!/usr/bin/env python3
"""Validate lore/ against its schemas and the cross-checks of docs/LORE-FORMAT.md 4.6.

  python3 tools/lore/validate.py [--root DIR]

Exit 1 on errors; warnings (unresolved relation targets of draft creatures) do not fail.
"""
import argparse, os, sys
import jsonschema
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load, creature_files


def _path(err):
    return "$" + "".join(f"[{p}]" if isinstance(p, int) else f".{p}" for p in err.absolute_path)


def schema_errors(inst, schema, rel):
    v = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
    return [f"{rel}: {_path(e)}: {e.message[:200]}" for e in sorted(v.iter_errors(inst), key=lambda e: list(map(str, e.absolute_path)))]


def validate_all(root):
    errors, warnings = [], []
    sd = os.path.join(root, "lore", "schema")
    sch = {n: load(os.path.join(sd, f"{n}.schema.json")) for n in ("creature", "planet", "references")}
    rel = lambda p: os.path.relpath(p, root)

    planet_p = os.path.join(root, "lore", "planet.json")
    refs_p = os.path.join(root, "lore", "references.json")
    planet = load(planet_p) if os.path.exists(planet_p) else None
    refs = load(refs_p) if os.path.exists(refs_p) else None
    if planet is None: errors.append("lore/planet.json: missing")
    if refs is None: errors.append("lore/references.json: missing")

    active, all_facts = set(), set()
    if planet is not None:
        errors += schema_errors(planet, sch["planet"], rel(planet_p))
        seen = set()
        for i, f in enumerate(planet.get("facts", [])):
            fid = f.get("id")
            if fid in seen: errors.append(f"lore/planet.json: $.facts[{i}].id: duplicate fact id {fid}")
            seen.add(fid); all_facts.add(fid)
            if f.get("status") == "active": active.add(fid)
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

    if planet is not None:
        for i, f in enumerate(planet.get("facts", [])):
            check_refs("lore/planet.json", f"$.facts[{i}].refs", f.get("refs", []))

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

    chain_ids, skill_ids = {}, {}
    for fn, c in cres:
        cid = c.get("id", "")
        for i, ch in enumerate(c.get("chains", [])):
            base = f"$.chains[{i}]"
            chid = ch.get("id", "")
            if not chid.startswith(cid + "."): errors.append(f"{fn}: {base}.id: chain id '{chid}' is not prefixed by '{cid}.'")
            if chid in chain_ids: errors.append(f"{fn}: {base}.id: duplicate chain id '{chid}' (also in {chain_ids[chid]})")
            chain_ids.setdefault(chid, fn)
            for j, r in enumerate(ch.get("roots", [])):
                if r not in all_facts: errors.append(f"{fn}: {base}.roots[{j}]: planet fact '{r}' does not exist")
                elif r not in active: errors.append(f"{fn}: {base}.roots[{j}]: planet fact '{r}' is retired")
            sk = ch.get("skill", {}).get("id")
            if sk:
                if sk in skill_ids: errors.append(f"{fn}: {base}.skill.id: duplicate skill id '{sk}' (also in {skill_ids[sk]})")
                skill_ids.setdefault(sk, fn)
                if not sk.startswith(cid + "."): errors.append(f"{fn}: {base}.skill.id: skill id '{sk}' is not prefixed by '{cid}.'")
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
                errors.append(f"{fn}: $.relations[{i}].via: planet fact '{via}' does not exist")
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
