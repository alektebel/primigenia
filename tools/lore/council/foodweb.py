#!/usr/bin/env python3
"""Council side of the Primigenia food-web batch (brief docs/briefs/trophic-web.md).

  python3 tools/lore/council/foodweb.py ctx        build runs/primigenia_foodweb/{ctx.json,planet_canon.md} from the draw
  (then)  LORE_RUNS_DIR=<rd> LORE_CTX=<rd>/ctx.json python3 tools/lore/council/got.py species   -> creatures (qwen draft, DeepSeek skeptic, Composer referee)
  python3 tools/lore/council/foodweb.py flora      producers / decomposers / parasitic plant slots -> plants JSON (qwen + referee)
  python3 tools/lore/council/foodweb.py edges      who eats whom (ecologist seat), validated against the roster
Resumable; outputs in tools/lore/council/runs/primigenia_foodweb/ (gitignored).
"""
import glob, json, os, re, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__)); LORE = os.path.dirname(HERE); ROOT = os.path.dirname(os.path.dirname(LORE))
sys.path.insert(0, LORE); sys.path.insert(0, HERE)
from lorelib import load
from foodweb_classify import CREATURES as EXC, FLORA as EXF, H
from foodweb_draw import SIZE_TXT, PLAN_TXT
RD = os.environ.get("FOODWEB_RD") or os.path.join(HERE, "runs", "primigenia_foodweb"); os.makedirs(RD, exist_ok=True)
DRAW = load(os.path.join(ROOT, "lore", "foodweb", "primigenia.draw.json"))
ACT_TXT = {"day": "active by day", "night": "active at night", "dawn_dusk": "active at dawn and dusk", "tidal": "active with the tide (feeds at low or high water)"}


def roster_text():
    out = []
    for cid, (lv, role, hb) in EXC.items():
        c = load(os.path.join(ROOT, "lore", "creatures", cid + ".json"))
        out.append(f"- {cid} ({c['name']['en']}): {lv}/{role}; habitats {', '.join(hb)}; eats: {c['niche']['diet'][:100]}")
    pl = []
    for pid, (lv, role, hb, _) in EXF.items():
        p = load(os.path.join(ROOT, "lore", "flora", pid + ".json"))
        pl.append(f"- {pid} ({p['name']['en']}): {lv}/{role}; habitats {', '.join(hb)}")
    return "\n".join(out), "\n".join(pl)


def deriv_text():
    d = load(os.path.join(ROOT, "lore", "worlds", "primigenia.derivation.json"))
    return "\n".join(f"- {i['id']} {i['key']}: {i['claim']}" + (f" Consequence: {i['consequence']}" if i.get("consequence") else "") for i in d["items"])


def seed_text(s):
    return (f"{s['slot']} FOOD-WEB SLOT. Trophic level: {s['level']}; role: {s['role']}. Habitat(s): {', '.join(s['habitats'])}. "
            f"Drawn body plan: {PLAN_TXT[s['plan']]}. Drawn size: {SIZE_TXT[s['size']]}. {ACT_TXT[s['activity']].capitalize()}. Niche hint: {s['hint']}. "
            "Derive the animal FROM this slot (the draw is fixed; everything else follows from the physics). Put the adult size (length and mass) in 'body'. "
            "Its 'diet' names what it eats (existing creature or plant ids from the roster, or carrion, detritus, plankton). In 'relations' list at least one existing creature it eats or is eaten by "
            "(kind 'prey' = it eats that creature, 'predation' = that creature eats it) using ids from the roster. Chains must cite derivation sheet items (D1..D30) in their links and F-ids as roots. "
            "The name must be new, Spanish-flavoured or invented.")


def build_ctx():
    cr, pl = roster_text()
    notes = ("FOOD-WEB PASS for Primigenia (docs/briefs/trophic-web.md). Rule lore/rules/derivation.md: derive forward, biosphere before creatures; every trait cites a derivation item.\n\n"
             "# DERIVATION SHEET (lore/worlds/primigenia.derivation.json)\n" + deriv_text() +
             "\n\n# EXISTING CREATURES (use these ids)\n" + cr + "\n\n# EXISTING PLANTS (use these ids)\n" + pl +
             "\n\n# RULES\nEvery consumer needs a food source in its habitat; apex animals are rare; their bodies feed scavengers then decomposers. Habitats: " + ", ".join(H) +
             ". Oxygen 21% and wet fuels: creature fire is rare (lore/rules/technosphere.md). Do not copy Earth animal names; invent bodies from the physics.")
    ctx = {"id": "primigenia_foodweb", "name": {"en": "Primigenia food web"}, "kind": "fictional", "habitat_word": "island", "notes": notes,
           "creatures": [{"name": c, "brief": f"{EXC[c][0]}/{EXC[c][1]}"} for c in EXC],
           "species": [{"seed": seed_text(s), "n": 1} for s in DRAW["creature_slots"]], "got_dir": "got"}
    json.dump(ctx, open(os.path.join(RD, "ctx.json"), "w"), indent=1, ensure_ascii=False)
    shutil.copy(os.path.join(HERE, "primigenia_canon.md"), os.path.join(RD, "planet_canon.md"))
    print("ctx written", RD, len(ctx["species"]), "seeds")


PLANT_SCHEMA = """{"name": str (Spanish-flavoured or invented, new), "name_es": str, "growth_form": "tree|shrub|rosette|herb|grass|fern|moss_lichen|vine|algae|fungus_like",
 "habitats": [str], "summary": str (2-3 sentences, cites F-ids and D-items), "height_min_m": number, "height_max_m": number, "colour": str (base colour and why, D23/D24),
 "chains": [2 chains: {"trait": str, "links": [2-4 causal steps], "roots": ["F5", ...], "play": str (what the player can do), "weakness": str, "observe": [str, str, str]}],
 "eaten_by_hint": [str] (existing creature ids or resource words that could eat it, or [] if only decomposers), "gift_item": str or null, "poison": str or null,
 "journal": str (one terse line), "journal_es": str, "secrets": [str]}"""


def flora_main():
    os.environ["LORE_RUNS_DIR"] = RD; os.environ["LORE_CTX"] = os.path.join(RD, "ctx.json")
    if not os.path.exists(os.path.join(RD, "ctx.json")): build_ctx()
    shutil.copy(os.path.join(HERE, "primigenia_canon.md"), os.path.join(RD, "planet_canon.md"))
    import council
    from council import ask, persona, best_json, ADV, CANON
    cr, pl = roster_text(); fd = os.path.join(RD, "flora"); os.makedirs(fd, exist_ok=True)
    base = ADV["naturalist"] + "\n\n" + CANON + "\n\n# NOTES\n" + json.load(open(os.path.join(RD, "ctx.json")))["notes"] + "\n\n# THE WORLD CANON (cite facts by id)\n" + open(os.path.join(RD, "planet_canon.md")).read() + "\n\n" + council.FP
    import threading
    def one(sl):
        p = os.path.join(fd, sl["slot"] + ".json")
        if os.path.exists(p): return
        task = (f"Derive ONE NEW plant, fungus or microbial producer for Primigenia in this slot: {sl['slot']} trophic level {sl['level']}, role {sl['role']}, habitat {', '.join(sl['habitats'])}. Hint: {sl['hint']}. "
                "Derive it FROM the derivation items and canon facts (nothing decorative); colour follows D23/D24; chemosynthesis follows D22; state what it gives the food web (who eats it, or that only decomposers do). "
                f"Output ONLY one JSON object: {PLANT_SCHEMA}")
        for a in range(3):
            t = ask("naturalist", base, task, temp=0.8, max_tokens=7000)
            if t.startswith("(failed)"): continue
            try:
                v = best_json(t)
                if isinstance(v, list): v = v[0]
                assert isinstance(v, dict) and v.get("chains")
                json.dump(v, open(p, "w"), indent=1, ensure_ascii=False); print("flora", sl["slot"], v.get("name"), flush=True); return
            except Exception as e: print("flora retry", sl["slot"], e, flush=True)
    ts = [threading.Thread(target=one, args=(sl,)) for sl in DRAW["plant_slots"]]; [t.start() for t in ts]; [t.join() for t in ts]
    # botanist referee, one batch
    rp = os.path.join(fd, "referee.json")
    if not os.path.exists(rp):
        plants = {sl["slot"]: json.load(open(os.path.join(fd, sl["slot"] + ".json"))) for sl in DRAW["plant_slots"] if os.path.exists(os.path.join(fd, sl["slot"] + ".json"))}
        t = ask("astrobio", persona("astrobio") + "\n\n" + base, "Referee these new producers and decomposers as a BOTANIST and microbiologist for THIS planet. Say 'highly speculative' where true; cite author/year or 'from memory, unverified'; never invent. "
                "Output ONLY JSON {slot: {\"verdict\": \"plausible|fixable|implausible\", \"summary\": str, \"fix\": str, \"analogue\": str, \"analogue_mechanism\": str}}\n\n" + json.dumps(plants, ensure_ascii=False))
        try: json.dump(best_json(t), open(rp, "w"), indent=1, ensure_ascii=False)
        except Exception as e: print("referee unparsable; plausibility stays unreviewed", e); json.dump({}, open(rp, "w"))
    print("flora done")


def slug(t):
    from lorelib import slug as _s
    return _s(t)


def plant_doc(slot, v, ver, date, run):
    """council plant JSON (PLANT_SCHEMA) + botanist verdict -> cpore.plant/1 draft"""
    name = str(v.get("name", slot["slot"])).strip(); pid = slug(name)
    gf = v.get("growth_form") if v.get("growth_form") in ("tree", "shrub", "rosette", "herb", "grass", "fern", "moss_lichen", "vine", "algae", "fungus_like") else "moss_lichen"
    hmin, hmax = float(v.get("height_min_m") or 0.001), float(v.get("height_max_m") or 0.05)
    chains = []
    for n, ch in enumerate(v["chains"][:4], 1):
        pl = {"verdict": "unreviewed", "judge": "none", "date": date}
        if ver and ver.get("verdict") in ("plausible", "fixable", "implausible"):
            pl = {"verdict": ver["verdict"], "judge": f"astrobio/{run}", "date": date}
            if ver.get("summary"): pl["summary"] = str(ver["summary"])
            if ver.get("fix"): pl["fixes"] = [str(ver["fix"])]
            if ver.get("analogue"): pl["analogues"] = [{"organism": str(ver["analogue"]), "mechanism": str(ver.get("analogue_mechanism") or "as named by the referee; no reference recorded")}]
        chains.append({"id": f"{pid}.c{n}", "trait": str(ch.get("trait", "")), "links": [str(x) for x in ch.get("links", [])][:5] or ["(none)"],
                       "roots": [r for r in ch.get("roots", []) if re.fullmatch(r"F[0-9]+", str(r))] or ["F24"], "play": str(ch.get("play", "")), "weakness": str(ch.get("weakness", "")),
                       "observe": [str(x) for x in ch.get("observe", [])][:4] or ["(nothing recorded)"], "plausibility": pl})
    jr = {"en": str(v.get("journal", ""))}; 
    if v.get("journal_es"): jr["es"] = str(v["journal_es"])
    doc = {"schema": "cpore.plant/1", "id": pid, "name": {"en": name, **({"es": str(v["name_es"])} if v.get("name_es") else {})}, "world": "primigenia", "status": "draft", "growth_form": gf,
           "habitats": [str(x) for x in v.get("habitats", slot["habitats"])] or slot["habitats"], "summary": str(v.get("summary", "")), "chains": chains,
           "gameplay": {"food_for": [], "gift_item": v.get("gift_item"), "poison": v.get("poison"), "healing": None, "cover": None, "climbing": False, "nest_material": None, "mineral_lick": None, "notes": "Food-web batch 2026-11-21; eaters are listed in lore/foodweb/primigenia.json."},
           "relations": [], "generator": {"growth_form": gf, "height_m": {"min": hmin, "max": max(hmax, hmin)}, "colour": {"base": str(v.get("colour", ""))}},
           "journal": [jr], "observe": [str(x) for c in v["chains"][:2] for x in c.get("observe", [])][:4], "secrets": [str(x) for x in v.get("secrets", [])],
           "provenance": {"council_run": run, "by": ["naturalist"]}, "changelog": [{"date": date, "who": "foodweb.py", "what": f"food-web batch slot {slot['slot']} ({slot['level']}/{slot['role']}, {', '.join(slot['habitats'])}); qwen draft, Composer botanist referee"}]}
    return doc


def merge_main():
    """Import the council's species and plants as lore drafts and add them to the web (level/role/habitats from the slot, eats from the model's own relations and diet)."""
    import subprocess, datetime
    from lorelib import dump
    date = datetime.date.today().isoformat(); run = f"foodweb-{date}"
    gdir = os.path.join(RD, "got", "species")
    subprocess.run([sys.executable, os.path.join(LORE, "import_got.py"), os.path.join(gdir, "graph.json"), "--world", "primigenia", "--kind", "new", "--run", run], check=True)
    sys.path.insert(0, HERE)
    os.environ["LORE_RUNS_DIR"] = RD
    import autoloop
    autoloop.patch_profiles({"id": "primigenia", "stage": "creature"}, RD, {})
    p = os.path.join(ROOT, "lore", "foodweb", "primigenia.json"); web = load(p); M = web["members"]
    # slot -> species names
    slot_names = {}
    for f in glob.glob(os.path.join(gdir, "6_species_S*_FOOD_WEB_SLOT_*.json")):
        if f.endswith("_review.json") or f.endswith("_astrobio.json"): continue
        sid = os.path.basename(f).split("_")[2]; d = load(f)
        d = d if isinstance(d, list) else next((x for x in d.values() if isinstance(x, list)), [d]) if isinstance(d, dict) else []
        slot_names[sid] = [x.get("name") for x in d if isinstance(x, dict) and x.get("name")]
    by_slot = {s["slot"]: s for s in DRAW["creature_slots"]}
    names = {}
    for sid, ns in slot_names.items():
        sl = by_slot.get(sid)
        if not sl: continue
        for n in ns[:1]:
            cid = slug(n); f = os.path.join(ROOT, "lore", "creatures", cid + ".json")
            if not os.path.exists(f): print("missing creature file", cid); continue
            c = load(f); names[n.lower()] = cid; names[c["name"]["en"].lower()] = cid
            M[cid] = {"kind": "creature", "level": sl["level"], "role": sl["role"], "habitats": sl["habitats"], "eats": M.get(cid, {}).get("eats", []), "new": True, "slot": sl["slot"],
                      "size": sl["size"], "plan": sl["plan"], "activity": sl["activity"]}
    # plants
    fd = os.path.join(RD, "flora"); ver = load(os.path.join(fd, "referee.json")) if os.path.exists(os.path.join(fd, "referee.json")) else {}
    for sl in DRAW["plant_slots"]:
        f = os.path.join(fd, sl["slot"] + ".json")
        if not os.path.exists(f): print("no plant for", sl["slot"]); continue
        doc = plant_doc(sl, load(f), ver.get(sl["slot"]), date, run); pf = os.path.join(ROOT, "lore", "flora", doc["id"] + ".json")
        if not os.path.exists(pf): dump(doc, pf)
        M[doc["id"]] = {"kind": "plant", "level": sl["level"], "role": sl["role"], "habitats": sl["habitats"], "eats": M.get(doc["id"], {}).get("eats", ["detritus"] if sl["level"] == "decomposer" else []), "new": True, "slot": sl["slot"],
                        **({"defended": True} if sl["role"] == "parasite" else {})}
        names[doc["name"]["en"].lower()] = doc["id"]
    # initial eats from each new creature's relations (kind prey) and diet words
    for cid, m in M.items():
        if m["kind"] != "creature" or not m.get("new"): continue
        c = load(os.path.join(ROOT, "lore", "creatures", cid + ".json")); eats = set(m.get("eats", []))
        for r in c.get("relations", []):
            w = str(r.get("with", "")); t = M.get(w) and w or names.get(w.lower()) or (slug(w) if slug(w) in M else None)
            if t and r.get("kind") == "prey": eats.add(t)
            if t and r.get("kind") == "predation": M[t].setdefault("eats", []); 
            if t and r.get("kind") == "predation" and cid not in M[t]["eats"] and M[t]["kind"] == "creature": M[t]["eats"].append(cid)
        d = c["niche"]["diet"].lower()
        for tok in ("carrion", "detritus", "dung"):
            if tok in d: eats.add(tok)
        for k in M:
            if k != cid and len(k) > 4 and re.search(r"\b" + re.escape(k) + r"\b", d): eats.add(k)
        m["eats"] = sorted(e for e in eats if e in M or e in ("carrion", "detritus", "dung"))
    dump(web, p); print("web now has", len(M), "members")


def roster_table(M):
    lines = []
    for i, m in M.items():
        extra = ""
        if m.get("new") and m["kind"] == "creature":
            c = load(os.path.join(ROOT, "lore", "creatures", i + ".json")); extra = f" | size {m.get('size')}, diet: {c['niche']['diet'][:90]}"
        lines.append(f"{i} | {m['kind']} | {m['level']}/{m['role']} | {','.join(m['habitats'])} | eats now: {','.join(m.get('eats', [])) or '-'}{extra}")
    return "\n".join(lines)


def edges_main():
    """Ecologist seat: complete the web. Loops: foodweb.check -> errors -> qwen proposes edges -> merge -> check (max 4 rounds)."""
    os.environ["LORE_RUNS_DIR"] = RD; os.environ["LORE_CTX"] = os.path.join(RD, "ctx.json")
    import council
    from council import ask, best_json, ADV, CANON
    import importlib.util
    spec = importlib.util.spec_from_file_location('lore_foodweb', os.path.join(LORE, 'foodweb.py')); fw = importlib.util.module_from_spec(spec); spec.loader.exec_module(fw)
    from lorelib import dump
    p = os.path.join(ROOT, "lore", "foodweb", "primigenia.json")
    for rnd in range(4):
        web = load(p); M = web["members"]
        sp = fw.spawn_weights(M)
        for i in M: M[i]["spawn"] = sp[i]
        dump(web, p); fw.apply_web(ROOT)
        errs, _ = fw.check_web(ROOT)
        errs = [e for e in errs if "niche.trophic" not in e and "needs at least" not in e and "no new" not in e]
        if not errs: print("web consistent after", rnd, "rounds"); return
        print("round", rnd, len(errs), "problems", flush=True)
        task = ("You are the ecologist of the council. Complete Primigenia's food web. ROSTER (id | kind | level/role | habitats | what it eats now):\n" + roster_table(M) +
                "\n\nPROBLEMS found by the checker:\n" + "\n".join(errs[:60]) +
                "\n\nRules: a consumer eats only species that share one of its habitats and sit at a lower trophic level (producer < decomposer < primary < secondary/scavenger < tertiary < apex); resources are carrion, detritus, dung. "
                "Every species except apex animals (and coloso, player_lineage) must be eaten by at least one species in its habitat. Every new consumer eats 1-5 foods. Do not make cycles. Apex animals eat tertiary, secondary and primary consumers. "
                "Do not widen a species' habitats. Output ONLY JSON: {\"set_eats\": {id: [full list of what it eats]}} for every species whose list must change; only new species (new in the roster comment) and the species named in the problems may change.")
        t = ask("naturalist", ADV["naturalist"] + "\n\n" + CANON, task, temp=0.3, max_tokens=9000)
        try: v = best_json(t)["set_eats"]
        except Exception as e: print("edges unparsable", e); continue
        for i, lst in v.items():
            if i in M and isinstance(lst, list): M[i]["eats"] = sorted({x for x in lst if x in M or x in ("carrion", "detritus", "dung")})
        dump(web, p)
    print("web still has problems after 4 rounds; patch by hand")


def base_web():
    """Existing 19 creatures + 20 plants -> members of lore/foodweb/primigenia.json (new members are added by foodweb.py merge)."""
    from foodweb_classify import EATS, NO_PREDATOR
    p = os.path.join(ROOT, "lore", "foodweb", "primigenia.json")
    web = load(p) if os.path.exists(p) else {"schema": "cpore.foodweb/1", "world": "primigenia", "members": {}}
    web.update({"date": "2026-11-21", "habitats": H, "main_habitats": ["meadow", "forest", "shore", "shallows", "caves", "spring", "highlands"], "resources": ["carrion", "detritus", "dung"],
                "seed": DRAW["seed"], "no_predator": NO_PREDATOR})
    for i, (lv, role, hb) in EXC.items():
        web["members"].setdefault(i, {}).update({"kind": "creature", "level": lv, "role": role, "habitats": hb, "eats": EATS.get(i, []), "new": False})
    for i, (lv, role, hb, df) in EXF.items():
        m = web["members"].setdefault(i, {}); m.update({"kind": "plant", "level": lv, "role": role, "habitats": hb, "eats": EATS.get(i, []), "new": False})
        if df: m["defended"] = True
    from lorelib import dump
    dump(web, p); print("base web:", len(web["members"]), "members")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "ctx": build_ctx()
    elif cmd == "base": base_web()
    elif cmd == "merge": merge_main()
    elif cmd == "edges": edges_main()
    elif cmd == "flora": flora_main()
    else: sys.exit(__doc__)
