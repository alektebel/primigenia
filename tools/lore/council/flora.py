#!/usr/bin/env python3
"""Flora pass for the island (world primigenia): the council designs the plants from first principles, sol chairs.

  export NAN_API_KEY=...; python3 tools/lore/council/flora.py [--no-commit]

Stages (all resumable, outputs in runs/primigenia_flora/): 7 voices draft + peer review (qwen personas, DeepSeek, GLM) ->
botanical referee (Composer) -> sol (chair) writes a flora plan, then the full plant entries in batches -> referee checks the
assembled flora -> sol applies the fixes -> lore/flora/<id>.json (schema cpore.plant/1) + references (unverified) -> validate,
render, refcheck, repair, commit. Never run in parallel with another council process (shared qwen limit).
"""
import argparse, datetime, glob, json, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); LORE = os.path.dirname(HERE); ROOT = os.path.dirname(os.path.dirname(LORE))
RD = os.path.join(HERE, "runs", "primigenia_flora"); os.makedirs(RD, exist_ok=True)
os.environ["LORE_RUNS_DIR"] = RD
WORLD = "primigenia"; DATE = datetime.date.today().isoformat(); PLANET = open(os.path.join(HERE, "runs", WORLD, "planet_canon.md")).read()
sys.path.insert(0, LORE); sys.path.insert(0, HERE)
from lorelib import load, dump, slug
CREATURES = []
for p in sorted(glob.glob(os.path.join(ROOT, "lore", "creatures", "*.json"))):
    c = load(p)
    if c.get("world") == WORLD:
        n = c["niche"]
        CREATURES.append(f"- {c['id']} ({c['name']['en']}): diet {n['diet'][:110]}; habitat {n['habitat'][:110]}; traits: " + "; ".join(ch["trait"] for ch in c["chains"][:3]))
CREATURE_IDS = {os.path.basename(p)[:-5] for p in glob.glob(os.path.join(ROOT, "lore", "creatures", "*.json"))}
NOTES = ("# THE ISLAND'S CREATURES (use these ids in relations)\n" + "\n".join(CREATURES) +
         "\n\n# HABITATS the flora must cover\ncoast and salt-spray zone; tidal-shelf algae (F13); lava-field pioneers on young volcanic ground; wet western forest; fog-drip trees; the dry eastern meadow (the start valley); riverbanks; hot springs and fumaroles (extremophiles, poisons F23); cave mouths and lava-tube entrances; high slopes and snowline giant rosettes (UV 1.4x above 2000 m, snow above 1750 m); the giant tree at the spring (F21); the crater floor (F22).")
ctx = {"id": "primigenia_flora", "name": {"en": "Primigenia flora"}, "kind": "fictional", "habitat_word": "island", "canon_text": open(os.path.join(HERE, "canon.md")).read(),
       "notes": "FLORA PASS: design the island's plants.\n\n# THE PLANET (canon; cite facts by id)\n" + PLANET + "\n\n" + NOTES}
json.dump(ctx, open(os.path.join(RD, "ctx.json"), "w"))
os.environ["LORE_CTX"] = os.path.join(RD, "ctx.json")
import council  # noqa: E402  (reads LORE_RUNS_DIR / LORE_CTX)
from council import ask, persona, stage, best_json, ADV  # noqa: E402
import autoloop  # noqa: E402

TASK = """Design THE ISLAND'S FLORA from first principles, consistent with the planet canon facts F1-F27 and the creature lore above.
Give 14-16 plants or functional types covering EVERY habitat listed, in compact form. For EACH plant:
- name (Spanish-flavoured or invented, nothing from books or films), growth form (tree/shrub/rosette/herb/grass/fern/moss-lichen/vine/algae/fungus-like), habitats, one-line summary
- 2-3 causal chains: TRAIT <- why <- why <- ROOT (cite F-ids, e.g. what 1.6 bar air and 1.6x wind force do to tree height, buttressing and leaf size; fog-drip leaves (F8); pioneer succession on young lava (F7); island gigantism of tree-like rosettes (F27); carnivory on nutrient-poor soils; seed dispersal by the island's creatures; red-purple pigments as honest UV or alkaloid signals (F25))
- gameplay role: food for which diets, gift item, poison/alkaloid with the red-vein signal, healing, cover and stealth, climbing, nest material, relation to mineral licks (F23)
- relations with creatures (use their ids): who eats it, pollinates or disperses it, mimicry
- 3 observe steps, one terse journal line
- GENERATOR PARAMETERS for a procedural art agent: height range (m), trunk and branching pattern (branching angle, levels, apical dominance, buttress), leaf type/size/arrangement, colour (base green plus stress/alkaloid overlay rules), placement rules (slope, altitude, wetness, soil, distance to coast, fog), seasonal behaviour, wind response
Also: the zonation of the island from coast to summit (one short paragraph) and the primary succession on lava.
Be concise (max ~3000 words). Real botanical analogues where you know them (Hawaiian silverswords, giant tropical-alpine rosettes, fog-drip redwoods, primary succession on lava, wind and tree allometry)."""
REF_TASK = ("Referee these flora designs as a BOTANIST and plant ecologist: per plant, is the adaptation plausible on THIS planet (1.6 bar, 1.6x wind force, pO2 0.34, UV, fog, young volcanic soil), are the physics and allometry right, does selection favour it, "
            "the closest real analogue (name the plant and mechanism) and what the literature says (author/year; 'from memory, unverified' when unsure; never invent a citation; anchors you may use: Carlquist and Baldwin and Sanderson 1998 on silverswords and adaptive radiation, Smith and Young 1987 on tropical-alpine giant rosettes, Dawson 1998 on fog drip, Kilauea primary succession studies, tree allometry under wind). "
            "Verdict per plant: plausible / plausible with a fix (give it) / implausible. Then list gaps (habitats not covered, missing functional types). Concise Markdown.")
BOT = ("You are a botanist and plant ecologist acting as the council's plausibility referee for FLORA. " + REF_TASK[:0])


def ok(p): return os.path.exists(p) and not open(p).read().startswith("(failed)")


def read(p): return open(p).read() if os.path.exists(p) else ""


def jask(k, system, user, tries=3):
    for a in range(tries):
        t = ask(k, system, user, temp=0.3, max_tokens=16000)
        if t.startswith("(failed)"): continue
        try: return best_json(t)
        except Exception as e: print("json error", a, e, flush=True)
    return None


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--no-commit", action="store_true"); a = ap.parse_args()
    log = lambda m: print(f"[{datetime.datetime.now():%H:%M:%S}] {m}", flush=True)
    # 1 drafts + peer reviews
    pd = os.path.join(RD, "flora")
    if len(glob.glob(os.path.join(pd, "review_*.md"))) < 5:
        for i in range(4):
            council.stage("flora", TASK, "\n\n# THE WORLD CANON\n" + PLANET + "\n\n" + NOTES)
            if len([f for f in glob.glob(os.path.join(pd, "draft_*.md")) if ok(f)]) >= 5 and len(glob.glob(os.path.join(pd, "review_*.md"))) >= 5: break
    log("drafts: " + str(len(glob.glob(os.path.join(pd, "draft_*.md")))) + " reviews: " + str(len(glob.glob(os.path.join(pd, "review_*.md")))))
    drafts = "\n\n".join(f"=== DRAFT {k} ===\n{read(os.path.join(pd, f'draft_{k}.md'))}" for k in ADV if ok(os.path.join(pd, f"draft_{k}.md")))
    reviews = "\n\n".join(f"=== PEER REVIEW by {k} ===\n{read(os.path.join(pd, f'review_{k}.md'))}" for k in ADV if read(os.path.join(pd, f"review_{k}.md")))
    # 2 botanical referee
    rp = os.path.join(RD, "referee_flora.md")
    for i in range(4):
        if ok(rp): break
        t = ask("astrobio", BOT + "\n\n" + council.CANON, "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + "\n\n# FLORA DRAFTS\n" + drafts + "\n\n" + REF_TASK)
        if not t.startswith("(failed)"): open(rp, "w").write(t)
    ref = read(rp); log("referee " + ("ok" if ref else "FAILED"))
    base = "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + "\n\n# DRAFTS\n" + drafts + "\n\n# PEER REVIEWS\n" + reviews + "\n\n# BOTANICAL REFEREE (Composer)\n" + ref
    sysm = persona("chair")
    # 3 plan
    pp = os.path.join(RD, "plan.json"); plan = load(pp) if os.path.exists(pp) else None
    if not plan:
        plan = jask("chair", sysm, base + '\n\n# TASK\nWrite the FLORA PLAN: choose the 14-16 plants of the final canon (merge duplicates across drafts, drop what the referee rejected, make sure every habitat is covered, no contradictions with the planet canon or the creature lore). Output ONLY JSON: {"zonation": str (coast-to-summit paragraph), "succession": str (primary succession on lava), "plants": [{"id": lowercase_ascii, "name_en": str, "name_es": str, "growth_form": "tree|shrub|rosette|herb|grass|fern|moss_lichen|vine|algae|fungus_like", "habitats": [str], "core_idea": str, "from_drafts": [letters or voices]}]}')
        if not plan or not plan.get("plants"): log("plan FAILED"); return 1
        json.dump(plan, open(pp, "w"), indent=1, ensure_ascii=False)
    log(f"plan: {len(plan['plants'])} plants")
    # 4 full entries in batches
    SHAPE = '{"id": same as plan, "name": {"en","es"}, "growth_form": same, "habitats": [str], "summary": str, "chains": [{"trait": str, "links": [str, 2-4 short causal steps], "roots": ["F4", ...] (ONLY ids of the planet canon), "play": str (what the player can do or learn), "weakness": str, "observe": [3 strings], "verdict": "plausible|fixable|implausible", "judge_note": str (the referee\'s point, with fixes applied), "analogue": {"organism": str, "mechanism": str, "refs": [reference ids from references]}}] (2-3 chains), "gameplay": {"food_for": [diets], "gift_item": str or null, "poison": {"alkaloid": bool, "signal": str}, "healing": str or null, "cover": str or null, "climbing": bool, "nest_material": str or null, "mineral_lick": str or null, "notes": str}, "relations": [{"with": creature id or plant id, "kind": "eaten_by|pollinated_by|dispersed_by|mimics|shelters|competes|parasitised_by|symbiosis|grows_with|succeeds|other", "note": str}], "generator": {"growth_form": same, "height_m": {"min": n, "max": n}, "trunk": str, "branching": {"angle_deg": n, "levels": n, "apical_dominance": 0-1, "buttress": str}, "leaf": {"type": str, "size_cm": n, "arrangement": str}, "colour": {"base": str, "overlay_rules": [str]}, "placement": {"slope": str, "altitude_m": [min, max], "wetness": str, "soil": str, "coast_distance_m": [min, max], "fog": str, "density": str}, "seasonal": str, "wind_response": str}, "observe": [str], "journal": {"en": str, "es": str}, "secrets": [str]}'
    plants = {}
    bs = [plan["plants"][i:i + 4] for i in range(0, len(plan["plants"]), 4)]
    allrefs = []
    for bi, b in enumerate(bs):
        bp = os.path.join(RD, f"plants_b{bi}.json"); r = load(bp) if os.path.exists(bp) else None
        if not r:
            r = jask("chair", sysm, base + "\n\n# FLORA PLAN\n" + json.dumps(plan, ensure_ascii=False) + "\n\n# TASK\nWrite the FULL entries of these plants of the plan: " + json.dumps(b, ensure_ascii=False) +
                     f"\nOutput ONLY JSON {{\"plants\": [entries], \"references\": [CSL entries: id lowercase author_year_shortword, type article-journal|book|chapter|report, title, author [{{family, given}}], issued {{date-parts: [[year]]}}, container-title]}} where each entry is {SHAPE}. "
                     "Only cite works you are sure exist (they will be checked against Crossref/OpenLibrary and removed if not found); every chain needs an analogue with refs where a real reference exists. Relations may name the creature ids above or other plants of the plan. Original wording.")
            if not r or not r.get("plants"): log(f"batch {bi} FAILED"); continue
            json.dump(r, open(bp, "w"), indent=1, ensure_ascii=False)
        for p in r["plants"]: plants[p["id"]] = p
        allrefs += r.get("references") or []
    log(f"entries: {len(plants)}")
    # 5 referee on the assembled flora, then sol applies fixes
    fp = os.path.join(RD, "referee_final.md")
    for i in range(3):
        if ok(fp): break
        t = ask("astrobio", BOT + "\n\n" + council.CANON, "# PLANET CANON\n" + PLANET + "\n\n# ASSEMBLED FLORA (JSON)\n" + json.dumps(list(plants.values()), ensure_ascii=False) + "\n\n" + REF_TASK + "\nEnd with a numbered list of concrete FIXES by plant id.")
        if not t.startswith("(failed)"): open(fp, "w").write(t)
    fx = os.path.join(RD, "fixes.json"); fixed = load(fx) if os.path.exists(fx) else None
    if fixed is None and ok(fp):
        fixed = jask("chair", sysm, "# PLANET CANON\n" + PLANET + "\n\n# CURRENT FLORA\n" + json.dumps(list(plants.values()), ensure_ascii=False) + "\n\n# REFEREE REPORT\n" + read(fp) +
                     f"\n\n# TASK\nApply the referee's fixes. Output ONLY JSON {{\"plants\": [FULL replacement entries, only for plants that change, same shape as before: {SHAPE}], \"references\": [new CSL entries if any], \"notes\": [str: what you changed and what you refused and why]}}.")
        if fixed is not None: json.dump(fixed, open(fx, "w"), indent=1, ensure_ascii=False)
    if fixed:
        for p in fixed.get("plants") or []:
            if isinstance(p, dict) and p.get("id") in plants: plants[p["id"]] = p
        allrefs += fixed.get("references") or []
    log(f"after fixes: {len(plants)} plants")
    # 6 write files
    write_plants(plants, allrefs, plan, load(os.path.join(ROOT, "lore", "worlds", WORLD + ".json")))
    # 7 validate, render, refcheck, repair
    sh = lambda c: subprocess.run(c, cwd=ROOT, capture_output=True, text=True)
    print(sh([sys.executable, os.path.join(LORE, "validate.py")]).stdout[-1500:])
    for _ in range(3):
        if subprocess.run([sys.executable, os.path.join(LORE, "refcheck.py")], cwd=ROOT).returncode == 0: break
    autoloop.repair_rejected(); repair_flora()
    r = sh([sys.executable, os.path.join(LORE, "validate.py")]); print(r.stdout[-1500:])
    sh([sys.executable, os.path.join(LORE, "render.py")])
    if not a.no_commit:
        sh(["git", "add", "lore", "docs/lore", "docs/creatures", "tools/lore"])
        print(sh(["git", "commit", "-m", f"Lore: island flora ({len(plants)} plants, draft)\n\nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"]).stdout[:200])
    return 0


KINDS = {"eaten_by", "pollinated_by", "dispersed_by", "mimics", "shelters", "competes", "parasitised_by", "symbiosis", "grows_with", "succeeds", "other"}
FORMS = {"tree", "shrub", "rosette", "herb", "grass", "fern", "moss_lichen", "vine", "algae", "fungus_like"}


def write_plants(plants, allrefs, plan, world):
    ids = autoloop.add_refs([r for r in allrefs if isinstance(r, dict)])
    known = {r["id"] for r in load(os.path.join(ROOT, "lore", "references.json"))}
    act = {f["id"] for f in world["facts"] if f["status"] == "active"}
    pids = {slug(p.get("id", "")) for p in plants.values()}
    os.makedirs(os.path.join(ROOT, "lore", "flora"), exist_ok=True)
    n = 0
    for p in plants.values():
        pid = slug(p.get("id", "")) or None
        if not pid: continue
        form = p.get("growth_form") if p.get("growth_form") in FORMS else "herb"
        chains = []
        for ch in p.get("chains") or []:
            roots = [r for r in (ch.get("roots") or []) if r in act]
            if not roots or not ch.get("trait"): continue
            an = ch.get("analogue") or {}
            pl = {"verdict": ch.get("verdict") if ch.get("verdict") in ("plausible", "fixable", "implausible") else "unreviewed",
                  "judge": "botanist/composer-2.5; chair sol", "date": DATE, "summary": str(ch.get("judge_note", ""))}
            if an.get("organism"): pl["analogues"] = [{"organism": str(an["organism"]), "mechanism": str(an.get("mechanism", "see the chain")), **({"refs": [r for r in an.get("refs", []) if r in known]} if [r for r in an.get("refs", []) if r in known] else {})}]
            chains.append({"id": f"{pid}.c{len(chains) + 1}", "trait": str(ch["trait"]), "links": [str(x) for x in (ch.get("links") or ["(none)"])][:5], "roots": roots,
                           "play": str(ch.get("play", "")), **({"weakness": str(ch["weakness"])} if ch.get("weakness") else {}),
                           "observe": [str(x) for x in (ch.get("observe") or ["(nothing recorded)"])][:4], "plausibility": pl})
        if not chains: print("skipped (no chain with valid roots):", pid); continue
        g = p.get("generator") or {}
        h = g.get("height_m") if isinstance(g.get("height_m"), dict) else {}
        try: hh = {"min": float(h.get("min", 0.1)), "max": float(h.get("max", 1))}
        except (TypeError, ValueError): hh = {"min": 0.1, "max": 1.0}
        g = dict(g, growth_form=form, height_m=hh)
        nm = p.get("name") if isinstance(p.get("name"), dict) and p["name"].get("en") else {"en": str(p.get("name") or pid)}
        j = p.get("journal")
        doc = {"schema": "cpore.plant/1", "id": pid, "name": {k: str(v) for k, v in nm.items() if k in ("en", "es")}, "world": WORLD, "status": "draft", "growth_form": form,
               "habitats": [str(x) for x in (p.get("habitats") or ["island"])], "summary": str(p.get("summary", "")), "chains": chains,
               "gameplay": p.get("gameplay") if isinstance(p.get("gameplay"), dict) else {},
               "relations": [{"with": str(r.get("with", "")), "kind": r.get("kind") if r.get("kind") in KINDS else "other", "note": str(r.get("note", ""))} for r in (p.get("relations") or []) if isinstance(r, dict) and r.get("with")],
               "generator": g, "journal": [({"en": str(j.get("en", "")), **({"es": str(j["es"])} if j.get("es") else {})} if isinstance(j, dict) else {"en": str(j)})] if j else [{"en": "(none)"}],
               "provenance": {"council_run": f"flora-{DATE}", "by": sorted(ADV), "edited_by": "sol"},
               "changelog": [{"date": DATE, "who": "flora.py", "what": "flora pass: 7 voices drafted and peer-reviewed, Composer botanical referee, sol chaired and applied the fixes"}]}
        if p.get("observe"): doc["observe"] = [str(x) for x in p["observe"]]
        if p.get("secrets"): doc["secrets"] = [str(x) for x in p["secrets"]]
        dump(doc, os.path.join(ROOT, "lore", "flora", f"{pid}.json")); n += 1
    z = os.path.join(ROOT, "lore", "flora", "zonation.md")
    open(z, "w").write("## Zonation, coast to summit\n\n" + str(plan.get("zonation", "")) + "\n\n## Primary succession on young lava\n\n" + str(plan.get("succession", "")) + "\n")
    print("plants written:", n)


def repair_flora():
    refs = {r["id"]: r.get("x-status") for r in load(os.path.join(ROOT, "lore", "references.json"))}
    bad = {i for i, s in refs.items() if s == "rejected"}
    for p in glob.glob(os.path.join(ROOT, "lore", "flora", "*.json")):
        c = load(p); ch0 = False
        for ch in c["chains"]:
            for an in ch["plausibility"].get("analogues", []):
                if set(an.get("refs", [])) & bad:
                    an["refs"] = [r for r in an["refs"] if r not in bad]; ch0 = True
                    if not an["refs"]: del an["refs"]
        if ch0: c["changelog"].append({"date": DATE, "who": "flora.py", "what": "removed rejected references"}); dump(c, p)


if __name__ == "__main__":
    sys.exit(main())
