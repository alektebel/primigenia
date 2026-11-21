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
    elif cmd == "flora": flora_main()
    else: sys.exit(__doc__)
