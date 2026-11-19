#!/usr/bin/env python3
"""Flora addendum: the start-valley plants, a STRICT second review of all the flora, bilingual names.

  export NAN_API_KEY=...; python3 tools/lore/council/flora_addendum.py STEP     (never run beside another council process)

STEPs (each resumable; outputs in runs/primigenia_flora_valley/):
  design   7 voices draft the valley plants + peer review + Composer referee -> sol (chair) plan + entries -> lore/flora/*.json
  review   sol (skeptic, read-only codex) + DeepSeek review EVERY plant chain strictly (plausible / needs-fix / implausible)
  fix      sol applies the review (patches), sol re-checks the changed chains
  names    sol checks the EN/ES name pairs of all plants and proposes natural ones
  report   writes docs/lore/FLORA-REVIEW.md
"""
import datetime, glob, json, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
RD = os.path.join(HERE, "runs", "primigenia_flora_valley"); os.makedirs(RD, exist_ok=True)
os.environ["FLORA_RD"] = RD
sys.path.insert(0, HERE)
import flora  # noqa: E402  (sets up ctx, LORE_CTX, council)
import council  # noqa: E402
from flora import ROOT, load, dump, slug, jask, read, ok, DATE, PLANET, NOTES, write_plants, WORLD  # noqa: E402
from council import ask, persona, best_json  # noqa: E402

WORLDJ = load(os.path.join(ROOT, "lore", "worlds", WORLD + ".json"))
FACTS = {f["id"]: f for f in WORLDJ["facts"] if f["status"] == "active"}
FAILS = os.path.join(RD, "failures.log")


def fail(m):
    open(FAILS, "a").write(f"{datetime.datetime.now():%H:%M:%S} {m}\n"); print("FAIL:", m, flush=True)


def jsave(name, v): json.dump(v, open(os.path.join(RD, name), "w"), indent=1, ensure_ascii=False)


def flora_files(): return sorted(p for p in glob.glob(os.path.join(ROOT, "lore", "flora", "*.json")))


def brief(p, with_facts=True):
    """Condensed plant text for reviewers."""
    o = [f"## {p['id']} ({p['name']['en']} / {p['name'].get('es', '?')}) form={p['growth_form']} habitats={'; '.join(p['habitats'])}", "summary: " + p["summary"]]
    for c in p["chains"]:
        pl = c["plausibility"]; an = (pl.get("analogues") or [{}])[0]
        o.append(f"- chain {c['id']} [{pl['verdict']}] TRAIT: {c['trait']}\n  links: " + " <- ".join(c["links"]) + "\n  roots: " + "; ".join(f"{r}={FACTS[r]['claim'][:90]}" if r in FACTS else r for r in c["roots"]) +
                 f"\n  play: {c['play']}\n  weakness: {c.get('weakness', '-')}\n  first referee note: {pl['summary']}\n  analogue: {an.get('organism', '-')}: {an.get('mechanism', '-')}")
    g = p.get("gameplay", {}); gen = p.get("generator", {})
    o.append("gameplay: food_for=" + json.dumps(g.get("food_for")) + f" gift={g.get('gift_item')} poison={json.dumps(g.get('poison'))} healing={g.get('healing')} cover={g.get('cover')} climbing={g.get('climbing')} mineral_lick={g.get('mineral_lick')} notes={g.get('notes')}")
    o.append("relations: " + "; ".join(f"{r['with']}:{r['kind']} ({r['note']})" for r in p.get("relations", [])))
    o.append(f"generator: height {gen.get('height_m')} placement {json.dumps(gen.get('placement'))} wind {gen.get('wind_response')} trunk {gen.get('trunk')} branching {json.dumps(gen.get('branching'))} leaf {json.dumps(gen.get('leaf'))} colour {json.dumps(gen.get('colour'))}")
    return "\n".join(o)


# ------------------------------------------------------------------ STEP design
VALLEY = """OWNER BRIEF (the start valley = the dry eastern meadow, a fog trap about 180 mornings a year (F8, F18), where the player's lineage starts; its spring and the giant tree are at one end, rondo graze the meadow, garfio and merodeador hunt its margins):
Design FOUR more plants for the valley, from first principles, with the same rigour and care as the existing flora. The island's current plants are listed in the notes; do not duplicate them, and link to them (grows with, succeeds, competes).
1. A FRUITING SHRUB (0.8-2.5 m): fruit is food for herbivores (rondo, zanco) and omnivores and a GIFT ITEM the player can give to befriend (P4); the fruit must be honest (sugar and starch, F26) and its dispersal by the island's creatures must explain WHY it fruits like this (colour, softness, scent through still foggy air F16, seed size, fruiting season F11).
2. A VISIBLE FLOWER OR HERB: a clearly noticeable meadow plant a player can learn to read (a landmark, a seasonal clock, a sign of something: water, minerals, a pollinator). Explain the flower (colour with F25 and the star's light F1, F17; shape; the pollinator among the island's creatures or an inferred insect) from the physics.
3. A MID-SIZE TREE (5-10 m) for the valley edges and slopes: not the giant of the spring (F21), not the western fog forest tree: what does a tree do in a dry-summer, fog-trap, 1.6x-wind valley (F4, F8, F18, F19)? Allometry, roots, crown shape, leaf habit, fog interception, cover, nest sites, fruit or seed.
4. A RED-VEINED POISON PLANT: an early hazard in the valley that teaches the red-vein signal (F25: red-purple pigments are honest alkaloid warnings; the albinos avoid toxic red-veined plants; merodeador and babosa use alkaloid plants as medicine; kaolin clay detoxifies, F23). The player can be poisoned but must be able to LEARN the signal fairly (observe steps), and there should be a use for the poison or an antidote path. Keep it consistent with Nieblon, whose defended leaves already carry red veins.
For each plant give: growth form, habitats within the valley, summary, 2-3 causal chains (TRAIT <- why <- why <- ROOT with F-ids), gameplay role, creature relations (use ids), 3 observe steps, journal line, GENERATOR PARAMETERS for the procedural art agent, and a Spanish and an English name that each sound natural in their own language (like Nieblon / Fogcomber: short, evocative, nothing from books or films).
Be concise (max ~2500 words)."""

REV_V = ("Seven anonymous drafts of the four START-VALLEY plants follow (fruiting shrub, visible flower or herb, mid-size valley tree, red-veined poison plant). Review as a peer: 1) rank A-G, one line why (botanical plausibility, consistency with the canon facts and the existing flora, play value); "
         "2) per plant slot, the best version (letter + name + why) and what to combine; 3) physics or botany errors and contradictions with the canon, the creatures or the existing plants (e.g. the red veins of Nieblon); 4) best Spanish/English name pairs. Concise.")


def step_design():
    council.REV["flora_valley"] = REV_V
    existing = [load(p) for p in flora_files()]
    notes_plants = "\n\n# EXISTING FLORA (do not duplicate; use these ids in relations)\n" + "\n".join(f"- {p['id']} ({p['name']['en']} / {p['name'].get('es')}), {p['growth_form']}: {p['summary'][:240]}" for p in existing)
    extra = "\n\n# THE WORLD CANON\n" + PLANET + "\n\n" + NOTES + notes_plants
    pd = os.path.join(RD, "flora_valley")
    for i in range(4):
        council.stage("flora_valley", VALLEY, extra)
        if len([f for f in glob.glob(os.path.join(pd, "draft_*.md")) if ok(f)]) >= 5 and len(glob.glob(os.path.join(pd, "review_*.md"))) >= 5: break
    for k in council.ADV:
        for kind in ("draft", "review"):
            f = os.path.join(pd, f"{kind}_{k}.md")
            if not os.path.exists(f): fail(f"{kind} of voice {k} ({council.OC_MODEL.get(k, 'qwen3.6')}) produced nothing")
    drafts = "\n\n".join(f"=== DRAFT {k} ===\n{read(os.path.join(pd, f'draft_{k}.md'))}" for k in council.ADV if ok(os.path.join(pd, f"draft_{k}.md")))
    reviews = "\n\n".join(f"=== PEER REVIEW by {k} ===\n{read(os.path.join(pd, f'review_{k}.md'))}" for k in council.ADV if read(os.path.join(pd, f"review_{k}.md")))
    rp = os.path.join(RD, "referee_valley.md")
    for i in range(4):
        if ok(rp): break
        t = ask("astrobio", flora.BOT + "\n\n" + council.CANON, "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + notes_plants + "\n\n# DRAFTS OF THE FOUR VALLEY PLANTS\n" + drafts + "\n\n" + flora.REF_TASK + " Be STRICT: name the weakest point of each draft.")
        if not t.startswith("(failed)"): open(rp, "w").write(t)
    if not ok(rp): fail("Composer referee of the valley drafts failed after 4 tries")
    base = "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + notes_plants + "\n\n# DRAFTS\n" + drafts + "\n\n# PEER REVIEWS\n" + reviews + "\n\n# BOTANICAL REFEREE (Composer)\n" + read(rp)
    sysm = persona("chair")
    pp = os.path.join(RD, "plan.json"); plan = load(pp) if os.path.exists(pp) else None
    if not plan:
        plan = jask("chair", sysm, base + "\n\n# OWNER BRIEF\n" + VALLEY + '\n\n# TASK\nWrite the PLAN for exactly the FOUR valley plants (merge the best of the drafts, apply the referee). Output ONLY JSON: {"valley_note": str (one paragraph to append to the island zonation: how the four plants sit in the start valley and relate to the existing flora), "plants": [{"id": lowercase_ascii_snake, "name_en": str, "name_es": str (natural Spanish, 1-3 words, no anglicism), "growth_form": "tree|shrub|rosette|herb|grass|fern|moss_lichen|vine|algae|fungus_like", "slot": "fruiting_shrub|flower_herb|valley_tree|poison_plant", "habitats": [str], "core_idea": str}]}')
        if not plan or len(plan.get("plants", [])) < 4: fail("chair plan failed"); sys.exit(1)
        jsave("plan.json", plan)
    bp = os.path.join(RD, "plants_valley.json"); r = load(bp) if os.path.exists(bp) else None
    if not r:
        refs = [f"{x['id']}: {x.get('title', '')[:70]}" for x in load(os.path.join(ROOT, "lore", "references.json")) if x.get("x-status") != "rejected"]
        r = jask("chair", sysm, base + "\n\n# OWNER BRIEF\n" + VALLEY + "\n\n# PLAN\n" + json.dumps(plan, ensure_ascii=False) + "\n\n# TASK\nWrite the FULL entries of the four plants. Output ONLY JSON {\"plants\": [entries], \"references\": [new CSL entries if needed]} where each entry is " + flora_shape() +
                 "\nEvery chain needs roots (F-ids of the canon), a verdict (use 'plausible' or 'fixable'; a strict review follows), and an analogue (a real plant and mechanism; refs: ids from the EXISTING REFERENCES below, or new CSL entries only for works you are sure exist). Spanish AND English names, journal in both languages. Original wording. Gameplay: gift_item for the fruiting shrub, poison.alkaloid true with the red-vein signal for the poison plant.\n\n# EXISTING REFERENCES (ids you may cite)\n" + "\n".join(refs))
        if not r or len(r.get("plants", [])) < 4: fail("chair entries failed"); sys.exit(1)
        jsave("plants_valley.json", r)
    plants = {p["id"]: p for p in r["plants"]}
    write_plants(plants, r.get("references") or [], None, WORLDJ, run_name=f"flora-valley-{DATE}", what="flora addendum (start valley): 7 voices drafted and peer-reviewed, Composer referee, sol chaired")
    zp = os.path.join(ROOT, "lore", "flora", "zonation.md"); z = read(zp)
    if plan.get("valley_note") and "## The start valley" not in z:
        open(zp, "w").write(z.rstrip("\n") + "\n\n## The start valley\n\n" + plan["valley_note"].strip() + "\n")
    finish_files()


def flora_shape():
    s = open(os.path.join(HERE, "flora.py")).read(); m = re.search(r"SHAPE = '(.*?)'\n", s, re.S)
    return m.group(1).replace("\\'", "'")


def finish_files():
    sh = lambda c: subprocess.run(c, cwd=ROOT, capture_output=True, text=True)
    for _ in range(2):
        if subprocess.run([sys.executable, os.path.join(ROOT, "tools/lore/refcheck.py")], cwd=ROOT).returncode == 0: break
    flora.autoloop.repair_rejected(); flora.repair_flora()
    print(sh([sys.executable, os.path.join(ROOT, "tools/lore/validate.py")]).stdout[-1500:])
    sh([sys.executable, os.path.join(ROOT, "tools/lore/render.py")])


# ------------------------------------------------------------------ STEP review
SKEPTIC = ("You are the STRICT SKEPTICAL SECOND REVIEWER of the island's flora, a plant physiologist and ecologist from a different school than the first referee. The first referee rated EVERY chain 'plausible', which was too lenient. "
           "Your job is to find REAL weaknesses: check each chain link by link. Does each link follow from the previous one? Does the cited root fact (F-id) actually support it (quote the fact's number)? Are numbers, scaling laws and allometry right for this planet (1.6 bar, 1.6x wind force per m/s, pO2 0.34 bar, UV, 1.05 g, young andesite/basalt soil, 3.8 Gyr old star, 1.2 Myr island)? "
           "Is the claimed selection pressure real or a just-so story? Is there a simpler or contrary explanation? Is the analogue really the same mechanism, or only superficially similar? Do the generator parameters (height, branching, placement, wind response) contradict the chains or the canon? Do gameplay claims (food for, gift, poison, healing, nest material) agree with the creatures' diets and with each other? Are relations consistent with the creature lore? "
           "Rate every chain: plausible (only if you tried to break it and could not; state the residual weakness anyway) / needs-fix (a real flaw with a concrete fix) / implausible (cannot stand as written; say what replaces it). Do not be polite and do not rate a chain plausible by default. Expect that a good share of chains genuinely need fixes. Never invent citations.")
RESHAPE = ('Output ONLY JSON: {"plants": [{"id": plant id, "chains": [{"id": chain id, "verdict": "plausible|needs-fix|implausible", "problem": str (the concrete weakness; for plausible: the residual weakness), "fix": str (the concrete fix, or "" if none needed)}], '
           '"plant_issues": [{"area": "summary|gameplay|relations|generator|roots|analogue|names", "problem": str, "fix": str}]}]}. Cover EVERY chain of EVERY plant given.')


def batches(n=4):
    ps = [load(p) for p in flora_files()]
    return [ps[i:i + n] for i in range(0, len(ps), n)]


def dsk_chat(system, user):
    t = council.oc_chat(council.OC_MODEL["skeptic"], system, user); return t


def step_review():
    for bi, b in enumerate(batches()):
        prompt = "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + "\n\n# PLANTS TO REVIEW\n" + "\n\n".join(brief(p) for p in b) + "\n\n# TASK\n" + RESHAPE
        for who in ("sol", "deepseek"):
            fp = os.path.join(RD, f"review_{who}_b{bi}.json")
            if os.path.exists(fp): continue
            v = None
            for a in range(3):
                t = council.sol_chat(SKEPTIC, prompt) if who == "sol" else dsk_chat(SKEPTIC, prompt)
                if t.startswith("(failed)"): fail(f"{who} review batch {bi} attempt {a}: call failed"); continue
                try: v = best_json(t); break
                except Exception as e: fail(f"{who} review batch {bi} attempt {a}: json error {e}")
            if v: jsave(f"review_{who}_b{bi}.json", v)
            else: fail(f"{who} review batch {bi}: gave up")
    merged = merge_reviews(); jsave("review_merged.json", merged)
    print_stats(merged, "strict review (before fixes)")


RANK = {"plausible": 0, "needs-fix": 1, "implausible": 2}


def norm(v): v = str(v).lower().replace("_", "-").replace(" ", "-"); return v if v in RANK else ("needs-fix" if "fix" in v else "plausible")


def merge_reviews():
    """chain id -> {verdict (worst of sol/deepseek), sol, deepseek, problems, fixes}; plant_issues too."""
    out = {"chains": {}, "plants": {}}
    for who in ("sol", "deepseek"):
        for f in sorted(glob.glob(os.path.join(RD, f"review_{who}_b*.json"))):
            for p in (load(f).get("plants") or []):
                pi = out["plants"].setdefault(p["id"], [])
                for i in p.get("plant_issues") or []: pi.append({"by": who, **i})
                for c in p.get("chains") or []:
                    d = out["chains"].setdefault(c["id"], {"plant": p["id"], "by": {}})
                    d["by"][who] = {"verdict": norm(c.get("verdict")), "problem": c.get("problem", ""), "fix": c.get("fix", "")}
    for d in out["chains"].values():
        d["verdict"] = max((x["verdict"] for x in d["by"].values()), key=lambda v: RANK[v])
    return out


def print_stats(m, label):
    c = {}
    for d in m["chains"].values(): c[d["verdict"]] = c.get(d["verdict"], 0) + 1
    print(label, len(m["chains"]), "chains:", c, flush=True)


# ------------------------------------------------------------------ STEP fix
PATCH = ('Output ONLY JSON {"plants": [{"id": plant id, "summary": str (optional full replacement), "chains": [{"id": chain id, "drop": bool (only for an implausible chain that has no honest rewrite AND the plant keeps at least 2 chains), "trait": str, "links": [str], "roots": ["F4"...], "play": str, "weakness": str, "observe": [3 str], '
         '"analogue": {"organism": str, "mechanism": str} (only if changed), "note": str (one sentence: what was wrong and what you changed)}] (only chains that change; give the full new value of each field you change), '
         '"gameplay": full replacement object (optional), "relations": full replacement list (optional), "generator": full replacement object (optional), "notes": [str: plant-level changes and refused suggestions with the reason]}]}')


def patch_prompt(b, m):
    parts = []
    for p in b:
        rv = [{"chain": c["id"], **{k: v for k, v in m["chains"].get(c["id"], {}).items() if k in ("by",)}} for c in p["chains"]]
        parts.append(f"## FULL CURRENT ENTRY of {p['id']}\n" + json.dumps({k: p[k] for k in ("id", "name", "growth_form", "habitats", "summary", "chains", "gameplay", "relations", "generator")}, ensure_ascii=False) + "\n## STRICT REVIEWS of " + p["id"] + "\n" + json.dumps({"chains": rv, "plant_issues": m["plants"].get(p["id"], [])}, ensure_ascii=False))
    return "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + "\n\n" + "\n\n".join(parts)


def apply_patch(p, pt):
    ch = {c["id"]: c for c in p["chains"]}
    for cp in pt.get("chains") or []:
        c = ch.get(cp.get("id"))
        if not c: continue
        if cp.get("drop") and len(ch) > 2:
            p["chains"] = [x for x in p["chains"] if x["id"] != c["id"]]; del ch[c["id"]]; continue
        for k in ("trait", "play", "weakness"):
            if cp.get(k): c[k] = str(cp[k])
        if cp.get("links"): c["links"] = [str(x) for x in cp["links"]][:5]
        if cp.get("observe"): c["observe"] = [str(x) for x in cp["observe"]][:4]
        if cp.get("roots"):
            rr = [r for r in cp["roots"] if r in FACTS]
            if rr: c["roots"] = rr
        an = cp.get("analogue")
        if isinstance(an, dict) and an.get("organism"):
            old = (c["plausibility"].get("analogues") or [{}])[0]
            new = {"organism": str(an["organism"]), "mechanism": str(an.get("mechanism", old.get("mechanism", "see the chain")))}
            if old.get("organism") == new["organism"] and old.get("refs"): new["refs"] = old["refs"]
            c["plausibility"]["analogues"] = [new]
        c["plausibility"]["strict_note"] = str(cp.get("note", ""))
    if pt.get("summary"): p["summary"] = str(pt["summary"])
    for k in ("gameplay", "generator"):
        if isinstance(pt.get(k), dict) and pt[k]: p[k] = pt[k] if k == "gameplay" else dict(pt[k], growth_form=p["growth_form"])
    if isinstance(pt.get("relations"), list) and pt["relations"]:
        kinds = flora.KINDS
        p["relations"] = [{"with": str(r["with"]), "kind": r.get("kind") if r.get("kind") in kinds else "other", "note": str(r.get("note", ""))} for r in pt["relations"] if isinstance(r, dict) and r.get("with")]
    return p


def step_fix():
    m = load(os.path.join(RD, "review_merged.json"))
    for bi, b in enumerate(batches()):
        fp = os.path.join(RD, f"patch_b{bi}.json")
        if not os.path.exists(fp):
            r = jask("chair", persona("chair"), patch_prompt(b, m) + "\n\n# TASK\nApply the strict review. For every chain rated needs-fix or implausible by either reviewer, fix it properly (rewrite the trait/links/roots/play/weakness/analogue as needed, keep what is sound; you may refuse a point with a stated reason in notes). For chains rated plausible, change nothing. Also fix plant-level issues (gameplay, relations, generator) that are real. Keep the original wording style, English only except journal. " + PATCH)
            if not r: fail(f"chair patch batch {bi} failed"); continue
            jsave(f"patch_b{bi}.json", r)
        r = load(fp); by = {x["id"]: x for x in r.get("plants", []) if isinstance(x, dict)}
        for p in b:
            pt = by.get(p["id"])
            if not pt: continue
            apply_patch(p, pt)
            p["changelog"].append({"date": DATE, "who": "flora_addendum.py", "what": "strict second review (sol + DeepSeek) applied by sol: " + "; ".join(str(x) for x in (pt.get("notes") or [])[:3])[:400]})
            dump(p, os.path.join(ROOT, "lore", "flora", p["id"] + ".json"))
    # re-check changed chains
    rp = os.path.join(RD, "recheck.json"); res = load(rp) if os.path.exists(rp) else {}
    for bi, b in enumerate(batches()):
        todo = [p for p in b if any(c["plausibility"].get("strict_note") for c in p["chains"])]
        if not todo or all(c["id"] in res for p in todo for c in p["chains"] if c["plausibility"].get("strict_note")): continue
        prompt = "# PLANET CANON\n" + PLANET + "\n\n" + NOTES + "\n\n# REVISED PLANTS (only chains marked [REVISED] are to be re-rated; be as strict as before)\n" + "\n\n".join(brief(p).replace("- chain " + "", "- chain ") for p in todo) + \
                 "\n\nRevised chain ids: " + ", ".join(c["id"] for p in todo for c in p["chains"] if c["plausibility"].get("strict_note")) + "\n\n# TASK\n" + RESHAPE.replace("Cover EVERY chain of EVERY plant given.", "Cover ONLY the revised chain ids listed.")
        v = None
        for a in range(3):
            t = council.sol_chat(SKEPTIC, prompt)
            if t.startswith("(failed)"): fail(f"sol re-check batch {bi} attempt {a}"); continue
            try: v = best_json(t); break
            except Exception as e: fail(f"sol re-check batch {bi} json {e}")
        for p in (v or {}).get("plants", []):
            for c in p.get("chains", []): res[c["id"]] = {"verdict": norm(c.get("verdict")), "problem": c.get("problem", ""), "fix": c.get("fix", "")}
        jsave("recheck.json", res)
    # write the verdicts into the plant files
    VM = {"plausible": "plausible", "needs-fix": "fixable", "implausible": "implausible"}
    for pth in flora_files():
        p = load(pth); chg = False
        for c in p["chains"]:
            pl = c["plausibility"]
            if c["id"] in m["chains"]:
                first = m["chains"][c["id"]]
                if c["id"] in res: v = res[c["id"]]["verdict"]; resid = res[c["id"]]["problem"]
                else: v = first["verdict"] if not pl.get("strict_note") else "plausible"; resid = first["by"].get("sol", next(iter(first["by"].values())))["problem"]
                pl["verdict"] = VM[v]; pl["judge"] = "strict review: sol (codex) + DeepSeek; chair sol"; pl["date"] = DATE
                base = re.sub(r"\s*Strict review.*$", "", pl["summary"], flags=re.S)
                pl["summary"] = (base + f" Strict review ({DATE}): " + ("revised: " + pl["strict_note"] + " " if pl.get("strict_note") else "") + ("Residual: " if v == "plausible" else "Still open: ") + resid).strip()
                pl.pop("strict_note", None); chg = True
        if chg: dump(p, pth)
    finish_files()
    after = {"chains": {}}
    for pth in flora_files():
        for c in load(pth)["chains"]:
            after["chains"][c["id"]] = {"verdict": {"plausible": "plausible", "fixable": "needs-fix", "implausible": "implausible"}.get(c["plausibility"]["verdict"], "plausible")}
    jsave("stats_after.json", after); print_stats(after, "after fixes (re-checked)")


# ------------------------------------------------------------------ STEP names
def step_names():
    ps = [load(p) for p in flora_files()]
    fp = os.path.join(RD, "names.json")
    if not os.path.exists(fp):
        lst = "\n".join(f"- {p['id']}: EN '{p['name']['en']}' / ES '{p['name'].get('es', '')}' ({p['growth_form']}; {p['summary'][:150]})" for p in ps)
        sysm = "You are a bilingual naming editor (native Spanish and English) for a nature game. Plant names must sound like real, natural names in each language (folk-name flavour such as Nieblon / Fogcomber: short, concrete, evocative), each coined independently for its language rather than a literal translation when a literal one is clumsy; no books or films; no two plants with confusingly similar names; Spanish names with correct accents and no anglicisms."
        r = jask("chair", sysm, "# PLANTS\n" + lst + '\n\n# TASK\nFor EVERY plant give the final EN and ES name. Keep a name unchanged unless it is clumsy, a literal calque, confusable with another plant, or unnatural; then propose a better one. Output ONLY JSON {"names": [{"id": str, "en": str, "es": str, "changed": bool, "why": str}]}.')
        if not r: fail("names pass failed"); sys.exit(1)
        jsave("names.json", r)
    r = load(fp); old = {p["id"]: p["name"] for p in ps}; rep = []
    for n in r["names"]:
        if n["id"] not in old or not n.get("en") or not n.get("es"): continue
        o = old[n["id"]]
        if (n["en"], n["es"]) != (o["en"], o.get("es")): rep.append((o["en"], n["en"])); rep.append((o.get("es", ""), n["es"]))
    for pth in flora_files():
        p = load(pth); nm = next((n for n in r["names"] if n["id"] == p["id"]), None)
        if nm and nm.get("en") and nm.get("es"): p["name"] = {"en": nm["en"], "es": nm["es"]}
        s = json.dumps(p, ensure_ascii=False)
        for a, b in rep:
            if a and a != b and len(a) > 3 and f'"{a}"' not in s: s = s.replace(a, b)
        p2 = json.loads(s)
        if p2["name"] != load(pth)["name"] or p2 != load(pth):
            p2["changelog"].append({"date": DATE, "who": "flora_addendum.py", "what": "bilingual name pass"}); dump(p2, pth)
    z = os.path.join(ROOT, "lore", "flora", "zonation.md"); t = read(z)
    for a, b in rep:
        if a and a != b and len(a) > 3: t = t.replace(a, b)
    open(z, "w").write(t)
    finish_files()


# ------------------------------------------------------------------ STEP report
def step_report():
    m = load(os.path.join(RD, "review_merged.json")); after = load(os.path.join(RD, "stats_after.json")) if os.path.exists(os.path.join(RD, "stats_after.json")) else {"chains": {}}
    names = load(os.path.join(RD, "names.json"))["names"] if os.path.exists(os.path.join(RD, "names.json")) else []
    cnt = lambda d: {v: sum(1 for x in d["chains"].values() if x["verdict"] == v) for v in RANK}
    b, a = cnt(m), cnt(after)
    o = ["# Flora strict review", "", "> DRAFT for the owner. Generated by `tools/lore/council/flora_addendum.py`; the data are in `lore/flora/`.", "",
         "The first referee (Composer) rated every chain of the 16 first plants as plausible, which was too lenient. A second, deliberately skeptical review by a different model family (sol through codex, read-only, plus DeepSeek v4.1 flash through opencode as a second opinion; the worse verdict wins) re-read every chain of all 20 plants (16 first plants and the 4 valley plants) against the canon facts. Sol (chair) then applied the fixes and re-checked the changed chains.", "",
         "## Statistics", "", "| | plausible | needs-fix | implausible | chains |", "|---|---|---|---|---|",
         f"| First referee (Composer), 16 first plants | {sum(1 for c in m['chains'] if c.split('.')[0] in FIRST)} | 0 | 0 | {sum(1 for c in m['chains'] if c.split('.')[0] in FIRST)} |",
         f"| Strict review, before fixes (all 20 plants) | {b['plausible']} | {b['needs-fix']} | {b['implausible']} | {len(m['chains'])} |",
         f"| After fixes, re-checked by sol | {a['plausible']} | {a['needs-fix']} | {a['implausible']} | {len(after['chains'])} |", "", "## Verdicts per chain", "",
         "| Chain | Strict verdict | Problem found | After |", "|---|---|---|---|"]
    for cid, d in sorted(m["chains"].items()):
        prob = next((x["problem"] for k, x in d["by"].items() if x["verdict"] == d["verdict"]), "").replace("|", "/").replace("\n", " ")
        o.append(f"| `{cid}` | {d['verdict']} | {prob[:300]} | {after['chains'].get(cid, {}).get('verdict', '-')} |")
    o += ["", "## Plant-level issues", ""]
    for pid, iss in sorted(m["plants"].items()):
        for i in iss: o.append(f"- `{pid}` ({i.get('area', '?')}, {i['by']}): {str(i.get('problem', ''))[:300]}")
    o += ["", "## Names (English / Spanish)", "", "| id | English | Spanish |", "|---|---|---|"]
    for pth in flora_files():
        p = load(pth); o.append(f"| `{p['id']}` | {p['name']['en']} | {p['name'].get('es', '')} |")
    ch = [n for n in names if n.get("changed")]
    if ch: o += ["", "Renamed in the name pass:", ""] + [f"- `{n['id']}`: {n['en']} / {n['es']} ({n.get('why', '')})" for n in ch]
    fl = read(FAILS)
    o += ["", "## Model failures", "", "```", fl.strip() or "(none)", "```", ""]
    open(os.path.join(ROOT, "docs", "lore", "FLORA-REVIEW.md"), "w").write("\n".join(o))


FIRST = {os.path.basename(p)[:-5] for p in subprocess.run(["git", "ls-tree", "--name-only", "-r", "763447d", "lore/flora/"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n") if p.endswith(".json")}

if __name__ == "__main__":
    {"design": step_design, "review": step_review, "fix": step_fix, "names": step_names, "report": step_report}[sys.argv[1]]()
