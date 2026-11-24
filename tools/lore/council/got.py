"""Graph-of-Thoughts lore council (A22), world-parametric.

Unit of thought = one causal chain:  trait <- why ... <- world fact(s) -> skill NAME and ROLE with a plain-language behaviour (+ weakness).
Operations (each step is resumable; outputs in <runs>/got/):
  1 GENERATE   advisors write chains for every creature (JSON)
  2 AGGREGATE  per creature, merge the candidate chains into the best distinct ones (combining links, keeping provenance)
  3 SCORE      physicist (causality), skeptic (honesty), astrobio (plausibility referee), designer (playability): 1-10 + fix notes
  4 REFINE     chains with any score < 7 are rewritten by a different advisor, then rescored (max `rounds` rounds)
  5 CROSSLINK  edges between creatures: shared roots, predation, symbiosis, mimicry; contradictions
  python3 got.py                 run all of 1-5 -> got/graph.json
  python3 got.py species         fill empty niches and ctx species seeds -> got/species/graph.json (+ score files, profiles)
  python3 got.py species "<concept>"   one species around a concept (printed, as before)
  python3 got.py profiles        niche/body/temperament per creature -> got/profiles.json
Output dir: $LORE_RUNS_DIR (default council/runs/). Needs planet_canon.md in it with fact ids F1..Fn.
World parameters come from $LORE_CTX (json): creatures [{name, brief}], gen_voices, batch, chains_per, rounds, species, notes, got_dir.
Without LORE_CTX: the original Primigenia island creature list."""
import json, os, re, sys, threading, random
from council import ADV, CANON, FP, D, ask, persona, CTX, best_json

PLANET = open(os.path.join(D, "planet_canon.md")).read()
OUT = os.path.join(D, CTX.get("got_dir", "got")); os.makedirs(OUT, exist_ok=True)
DEFAULT = ["Rondo", "Zanco", "Espinodo", "Garfio", "Coloso", "Merodeador", "Zancuda", "Babosa",
           "player lineage and cousins", "nocturnal creature", "albinos"]
CRE = CTX["creatures"] if "creatures" in CTX else [{"name": n, "brief": ""} for n in DEFAULT]
CREATURES = [c["name"] for c in CRE]
BRIEF = {c["name"]: c.get("brief", "") for c in CRE}
VOICES = [k for k in CTX.get("gen_voices", list(ADV)) if k in ADV]
BATCH = int(CTX.get("batch", len(CREATURES) or 1))
CHAINS_PER = CTX.get("chains_per", "3-4")
ROUNDS = int(CTX.get("rounds", 2))
JUDGE_SET = CTX.get("judges")
NOTES = ("\n\n# NOTES FOR THIS WORLD\n" + CTX["notes"]) if CTX.get("notes") else ""
BASE = CANON + NOTES + "\n\n# THE WORLD CANON (cite facts by id)\n" + PLANET + "\n\n" + FP

CHAIN_SCHEMA = """{"creature": str, "trait": str (the observable trait, 3-8 words),
 "links": [str, ...] (the 'why' steps from the trait down to the root, 2-4 steps, each one short and causal),
 "roots": ["F3", ...] (world fact ids from the canon),
 "skill": {"name": str, "role": "Basic|Engage|Poke|Control|Defence|Signature|Passive|Social", "effect": str (what the creature does, in plain words: a behaviour the player can see and answer; NEVER numbers, turns, percentages, seconds, metres or any game stats: moves and numbers are designed later in the game labs)},
 "weakness": str (how the player can exploit it), "observe": [str, str, str] (three things the player must SEE to reveal the chain),
 "journal": str (one terse, curious line),
 "references": [{"author": "Family, G.", "year": int, "title": str, "venue": str}] (OPTIONAL, 0-2 real published works behind the biology; only if you are sure they exist)}"""
if CTX.get("kind") == "real":
    CHAIN_SCHEMA = CHAIN_SCHEMA.replace("(OPTIONAL, 0-2", "(REQUIRED for this real world, 1-2")


def jparse(text):
    return best_json(text)


def cached(name, fn, base=None):
    p = os.path.join(base or OUT, name)
    if os.path.exists(p): return json.load(open(p))
    for a in range(3):
        try:
            v = fn(); os.makedirs(os.path.dirname(p), exist_ok=True)
            json.dump(v, open(p, "w"), indent=1, ensure_ascii=False); print("ok", name, flush=True); return v
        except Exception as e:
            print("retry", name, a, e, file=sys.stderr, flush=True)
    print("FAILED", name, flush=True)
    return None


def par(items, f):
    res = {}
    def w(x):
        try: res[x] = f(x)
        except Exception as e: print("task error", x, e, file=sys.stderr, flush=True); res[x] = None
    ts = [threading.Thread(target=w, args=(x,)) for x in items]; [t.start() for t in ts]; [t.join() for t in ts]
    return res


def sname(c): return c.replace(" ", "_").replace("/", "_")


def chunks(xs, n): return [xs[i:i + n] for i in range(0, len(xs), n)]


def normalize(res, names):
    """Model output -> {creature: [items]}: accepts an object keyed by name, a flat list of chains with a 'creature' field, or a list for a single creature."""
    if isinstance(res, dict):
        low = {k.lower(): v for k, v in res.items()}
        return {c: low.get(c.lower()) for c in names}
    if isinstance(res, list):
        if len(names) == 1: return {names[0]: res}
        out = {c: [] for c in names}
        for ch in res:
            if isinstance(ch, dict):
                for c in names:
                    if belongs(ch, c): out[c].append(ch); break
        return out
    return {c: None for c in names}


def listing(names):
    return "\n".join(f"- {n}" + (f": {BRIEF[n]}" if BRIEF.get(n) else "") for n in names)


def belongs(ch, c):
    f = str(ch.get("creature", "")).lower(); c = c.lower()
    return f == c or c in f or f in c or (len(c.split()[0]) > 3 and c.split()[0] in f)


def generate():
    bs = chunks(CREATURES, BATCH)
    def g(job):
        k, bi = job; names = bs[bi]
        return cached(f"1_gen_{k}.json" if len(bs) == 1 else f"1_gen_{k}_b{bi}.json", lambda: jparse(ask(k, ADV[k] + "\n\n" + BASE,
            f"Write {CHAINS_PER} first-principles chains for EACH of these creatures of this world (the notes describe each):\n{listing(names)}\n\n"
            f"Output ONLY a JSON array of chains, each: {CHAIN_SCHEMA}. Use only world facts from the canon (cite ids). "
            "Different creatures facing the same pressure should show convergent or opposite solutions.", temp=0.9, max_tokens=12000)))
    res = par([(k, bi) for k in VOICES for bi in range(len(bs))], g)
    gen = {}
    for (k, bi), v in res.items():
        if v: gen.setdefault(k, []).extend(v)
    return gen


def aggregate(gen):
    keys = VOICES
    bs = chunks(CREATURES, BATCH)
    def a(bi):
        names = bs[bi]
        pool = {c: [dict(ch, by=k) for k, chs in gen.items() if chs for ch in chs if isinstance(ch, dict) and belongs(ch, c)] for c in names}
        agg = keys[bi % len(keys)]
        want = "4-5 best DISTINCT chains" if CHAINS_PER.startswith("3") else "the 2-3 best DISTINCT chains"
        res = cached(f"2_agg_b{bi}.json", lambda: jparse(ask(agg, ADV[agg] + "\n\n" + BASE,
            f"Candidate chains per creature from several advisors (field 'by'):\n{json.dumps(pool, ensure_ascii=False)}\n\n"
            f"AGGREGATE them into {want} for EACH creature: merge chains that describe the same trait (keep the strongest links from each), "
            "drop arbitrary or weak ones, keep the skills varied across roles; keep each chain's 'references' (merge, dedupe). Add field \"from\": [advisor names merged]. "
            f"Output ONLY a JSON object {{creature name: [chains]}} using exactly these names: {names}. Each chain: {CHAIN_SCHEMA} plus \"from\".", temp=0.4, max_tokens=12000)))
        return res or {}
    out = {}
    for bi, r in par(list(range(len(bs))), a).items():
        nr = normalize(r, bs[bi])
        for c in bs[bi]:
            v = nr.get(c)
            if not isinstance(v, list) or not v:  # the model dropped this creature: ask for it alone, else fall back to the raw candidates
                pool_c = [dict(ch, by=k) for k, chs in gen.items() if chs for ch in chs if isinstance(ch, dict) and belongs(ch, c)]
                if pool_c:
                    single = cached(f"2_agg_one_{sname(c)}.json", lambda: normalize(jparse(ask(agg, ADV[agg] + "\n\n" + BASE,
                        f"Candidate chains for {c} from several advisors (field 'by'):\n{json.dumps(pool_c, ensure_ascii=False)}\n\n"
                        f"AGGREGATE them into the 2-4 best DISTINCT chains for {c} (merge duplicates, drop weak ones, keep references). Add \"from\": [advisor names]. "
                        f"Output ONLY a JSON array, each: {CHAIN_SCHEMA} plus \"from\".", temp=0.4, max_tokens=8000)), [c]))
                    v = (single or {}).get(c) if isinstance(single, dict) else None
                    if not v: v = pool_c[:3]; print("aggregate fallback to raw candidates:", c, flush=True)
            out[c] = v if isinstance(v, list) else []
    return out


JUDGES = {"physicist": "causality and physics: does every link follow from the previous one and from the cited world facts?",
          "skeptic": "honesty: is anything arbitrary ('because it looks cool'), are the PLANET numbers plausible, is there a better contrarian cause? (game numbers on skills are forbidden)",
          "astrobio": "biological plausibility for THIS creature in THIS world: does selection favour it, is the physiology/energy budget possible, what is the closest real Earth analogue (name it, cite author/year if known, else say unverified)? Where the chemistry or physics is speculative say 'highly speculative' and grade honestly.",
          "designer": "play: is the skill behaviour fun and readable (judge only the behaviour: numbers, turns and percentages are NOT the council's job, flag them as an error if present), is the weakness exploitable, are the 3 observe steps visible in a 3D game?"}
if JUDGE_SET: JUDGES = {k: v for k, v in JUDGES.items() if k in JUDGE_SET}


def score(cs, chains_by, rnd):
    """cs: creatures of one batch -> {creature: {judge: items}}; one call per judge and batch, saved per creature."""
    def s(j):
        miss = [c for c in cs if not os.path.exists(os.path.join(OUT, f"3_score_r{rnd}_{sname(c)}_{j}.json")) and chains_by.get(c)]
        if miss:
            tmpn = f"3_batch_r{rnd}_{sname(miss[0])}_{j}.json"
            res = cached(tmpn, lambda: jparse(ask(j, persona(j) + "\n\n" + BASE,
                f"Score each chain of each creature on {JUDGES[j]}\n{json.dumps({c: chains_by[c] for c in miss}, ensure_ascii=False)}\n\n"
                'Output ONLY a JSON object {creature name: [one item per chain in order: {"trait": str, "score": 1-10, "fix": str (concrete fix, or ""), "analogue": str (real organism/mechanism, or ""), "reference": str (author year title if known, else "")}]}',
                temp=0.2, max_tokens=8000)))
            nr = normalize(res, miss)
            for c in miss:
                items = nr.get(c)
                if isinstance(items, list):
                    json.dump(items, open(os.path.join(OUT, f"3_score_r{rnd}_{sname(c)}_{j}.json"), "w"), indent=1, ensure_ascii=False)
        return {c: (json.load(open(os.path.join(OUT, f"3_score_r{rnd}_{sname(c)}_{j}.json"))) if os.path.exists(os.path.join(OUT, f"3_score_r{rnd}_{sname(c)}_{j}.json")) else None) for c in cs}
    r = par(list(JUDGES), s)
    return {c: {j: (r.get(j) or {}).get(c) for j in JUDGES} for c in cs}


def weak(chains, scores):
    bad = []
    for i, ch in enumerate(chains):
        notes = [(j, sc[i]) for j, sc in scores.items() if sc and i < len(sc) and isinstance(sc[i], dict)]
        lo = min([n[1].get("score", 10) for n in notes if isinstance(n[1].get("score", 10), (int, float))] or [10])
        if lo < 7: bad.append((i, notes))
    return bad


def refine(c, chains, scores, rnd):
    bad = weak(chains, scores)
    if not bad: return chains, False
    ref = ["senses", "naturalist", "wildcard", "mythmaker"][rnd % 4]
    fixes = {str(i): [{"judge": j, **n} for j, n in notes] for i, notes in bad}
    new = cached(f"4_refine_r{rnd}_{sname(c)}.json", lambda: jparse(ask(ref, ADV[ref] + "\n\n" + BASE,
        f"These chains for {c} were judged weak (index -> judges' notes): {json.dumps(fixes, ensure_ascii=False)}\n"
        f"All chains: {json.dumps(chains, ensure_ascii=False)}\n\nRewrite ONLY the weak chains so they pass every judge (fix the causal "
        "links, cite the right world facts, make the skill and weakness playable). Output ONLY the full JSON array (all chains, "
        f"fixed ones replaced, same order), each: {CHAIN_SCHEMA} plus \"from\".", temp=0.5, max_tokens=8000)))
    return (new if isinstance(new, list) and len(new) == len(chains) else chains), True


def crosslink(final):
    return cached("5_crosslink.json", lambda: jparse(ask("naturalist", ADV["naturalist"] + "\n\n" + BASE,
        f"Final chains per creature:\n{json.dumps(final, ensure_ascii=False)}\n\nBuild the EDGES of this world's lore graph: "
        "pairs of creatures that share a world root (convergent or opposite solutions), predation, symbiosis, mimicry, rivalry, "
        "teaching (one creature's move counters another's). Also list contradictions between chains. Output ONLY JSON: "
        '{"edges": [{"a": creature, "b": creature, "kind": "convergent|opposite|predation|symbiosis|mimicry|rivalry|counter", '
        '"via": "F-id or trait", "note": str}], "contradictions": [str]}', temp=0.3, max_tokens=6000))) or {"edges": [], "contradictions": []}


def run_all():
    if not CREATURES: print("no creatures in ctx; nothing to do"); return
    gen = generate()
    agg = aggregate(gen)
    final = {c: agg.get(c) or [] for c in CREATURES}
    bs = chunks(CREATURES, BATCH)
    for rnd in range(ROUNDS):
        changed_any = False
        for names in bs:
            sc = score(names, final, rnd)
            for c in names:
                if not final[c]: continue
                final[c], ch = refine(c, final[c], sc[c], rnd); changed_any = changed_any or ch
        if not changed_any: break
    # final score of the last refined round so every creature has scores for its final chains
    last = max([int(m.group(1)) for f in os.listdir(OUT) for m in [re.match(r"3_score_r(\d+)_", f)] if m] or [0])
    json.dump(final, open(os.path.join(OUT, "final_chains.json"), "w"), indent=1, ensure_ascii=False)
    edges = crosslink({c: [{k: v for k, v in ch.items() if k in ("trait", "roots")} for ch in chs] for c, chs in final.items()})
    json.dump({"chains": final, "graph": edges}, open(os.path.join(OUT, "graph.json"), "w"), indent=1, ensure_ascii=False)
    print("got done", flush=True)


# ---- PROFILES: niche, body, temperament, secrets for each creature (fills the importer's placeholders) -----------
def profiles(names=None, final=None):
    names = names or CREATURES
    if final is None:
        p = os.path.join(OUT, "final_chains.json"); final = json.load(open(p)) if os.path.exists(p) else {}
    def one(bi):
        bn = chunks(names, 6)[bi]
        return cached(f"7_profiles_b{bi}.json", lambda: jparse(ask("naturalist", ADV["naturalist"] + "\n\n" + BASE,
            "For each creature write its profile from its chains and the world canon:\n" +
            json.dumps({c: {"brief": BRIEF.get(c, ""), "traits": [ch.get("trait") for ch in final.get(c, []) if isinstance(ch, dict)]} for c in bn}, ensure_ascii=False) +
            '\nOutput ONLY JSON {creature name: {"habitat": str, "diet": str, "active": str (when), "predators": [str], "prey": [str], "body": str (2 sentences), '
            '"temperament": str (1 sentence), "secrets": [str], "moments": [str]}}', temp=0.5, max_tokens=6000)))
    res = par(list(range(len(chunks(names, 6)))), one)
    out = {}
    for r in res.values(): out.update(r or {})
    json.dump(out, open(os.path.join(OUT, "profiles.json"), "w"), indent=1, ensure_ascii=False)
    print("profiles done", len(out), flush=True)


# ---- SPECIATE (new creatures from physics) --------------------------------------------------------------------
def speciate(seed, n=3, base=None):
    tag = re.sub(r"\W+", "_", seed or "niches")[:40]
    sdir = os.path.join(OUT, "species")
    existing = ", ".join(CREATURES) or "(none yet)"
    gen = cached(f"6_species_{tag}.json", lambda: jparse(ask("naturalist", ADV["naturalist"] + "\n\n" + BASE,
        (f"Derive {n} NEW creature species of this world around the concept: '{seed}'. First ask: in THIS world, where and why "
         "would such a trait evolve? Find the habitat and pressures that force it, then derive the rest of the body and behaviour "
         "from the same causes (every trait is a consequence, nothing decorative)." if seed else
         f"List this world's EMPTY niches (habitat x food x energy source x time not taken by the existing creatures: {existing}) and derive {n} new species "
         "to fill them, each forced by the world's physics.") +
        ' Output ONLY JSON: [{"name": Spanish-flavoured or invented, no names from books or films, "niche": str, "habitat": str, "diet": str, "active": str, "body": str, "temperament": str, "body_plan": {"symmetry": "bilateral|radial|biradial|asymmetric|spherical", "arms": int or null, "origin": str (optional)}, "chains": [4 chains, each ' + CHAIN_SCHEMA +
        '], "relations": [{"with": existing creature, "kind": str, "note": str}], "haunting_moment": str, "journal": [str, str], "secrets": [str]}]',
        temp=0.9, max_tokens=12000)), base=sdir)
    if not gen: return None
    sc = cached(f"6_species_{tag}_review.json", lambda: jparse(ask("skeptic", ADV["skeptic"] + "\n\n" + BASE,
        f"Check these new species against the world canon and the existing creatures:\n{json.dumps(gen, ensure_ascii=False)}\n"
        'Output ONLY JSON: [{"name": str, "chains": [{"trait": str, "score": 1-10, "fix": str}]}]', temp=0.2, max_tokens=6000)), base=sdir)
    bio = cached(f"6_species_{tag}_astrobio.json", lambda: jparse(ask("astrobio", persona("astrobio") + "\n\n" + BASE,
        f"Referee these new species for biological plausibility in THIS world (say 'highly speculative' where true):\n{json.dumps(gen, ensure_ascii=False)}\n"
        'Output ONLY JSON: [{"name": str, "chains": [{"trait": str, "verdict": "plausible|fixable|implausible", "why": str, '
        '"analogue": str, "reference": str (author/year or textbook, or "from memory, unverified"), "fix": str}]}]')), base=sdir)
    return {"species": gen, "review": sc, "astrobio": bio}


VERD = {"plausible": 8, "fixable": 6, "implausible": 3}


def species_all():
    sdir = os.path.join(OUT, "species"); os.makedirs(sdir, exist_ok=True)
    specs = CTX.get("species") or []
    results = par(list(range(len(specs))), lambda i: speciate(specs[i].get("seed"), int(specs[i].get("n", 3))))
    chains, edges, profs = {}, [], {}
    for i in range(len(specs)):
        r = results.get(i)
        if not r: continue
        sps = r["species"]
        if isinstance(sps, dict): sps = [sps] if "chains" in sps else next((v for v in sps.values() if isinstance(v, list)), [])
        r["species"] = [x for x in (sps if isinstance(sps, list) else []) if isinstance(x, dict)]
        rev = {str(x.get("name", "")).lower(): x for x in (r["review"] or []) if isinstance(x, dict)}
        bio = {str(x.get("name", "")).lower(): x for x in (r["astrobio"] or []) if isinstance(x, dict)}
        for sp in r["species"]:
            name = str(sp.get("name", "")).strip()
            if not name or not isinstance(sp.get("chains"), list): continue
            chs = [ch for ch in sp["chains"] if isinstance(ch, dict) and ch.get("trait")]
            if not chs: continue
            for ch in chs: ch.setdefault("from", ["naturalist/qwen"])
            chains[name] = chs
            profs[name] = {k: sp.get(k) for k in ("habitat", "diet", "active", "body", "temperament", "secrets") if sp.get(k)}
            profs[name]["niche_text"] = sp.get("niche", "")
            if specs[i].get("carcinised"): profs[name]["carcinised"] = True
            if isinstance(sp.get("body_plan"), dict): profs[name]["body_plan"] = sp["body_plan"]
            if sp.get("haunting_moment"): profs[name]["moments"] = [sp["haunting_moment"]]
            if sp.get("journal"): profs[name]["journal"] = list(sp["journal"]) if isinstance(sp["journal"], list) else [str(sp["journal"])]
            if specs[i].get("carcinised"): profs[name]["journal"] = profs[name].get("journal", [])[:2] + ["Again."]
            for rl in sp.get("relations") or []:
                if isinstance(rl, dict) and rl.get("with"): edges.append({"a": name, "b": rl["with"], "kind": rl.get("kind", "cousin"), "note": rl.get("note", "")})
            b = bio.get(name.lower()) or {}
            v = rev.get(name.lower()) or {}
            def match(items, trait, idx):
                for it in items or []:
                    if isinstance(it, dict) and re.sub(r"\W+", "", str(it.get("trait", "")).lower()) == re.sub(r"\W+", "", trait.lower()): return it
                return (items or [None] * 9)[idx] if idx < len(items or []) else None
            bio_items, sk_items = [], []
            for idx, ch in enumerate(chs):
                bi = match(b.get("chains"), ch["trait"], idx) or {}
                si = match(v.get("chains"), ch["trait"], idx) or {}
                # no referee answer = no score (verdict "unreviewed"); never default to 6/"fixable" (A102.2)
                bio_items.append({"trait": ch["trait"], "score": VERD.get(bi.get("verdict")), "fix": bi.get("fix") or bi.get("why", ""),
                                  "analogue": bi.get("analogue", ""), "reference": bi.get("reference", "")})
                sk_items.append({"trait": ch["trait"], "score": si.get("score") if isinstance(si.get("score"), (int, float)) else None, "fix": si.get("fix", "")})
            json.dump(bio_items, open(os.path.join(sdir, f"3_score_r0_{sname(name)}_astrobio.json"), "w"), indent=1, ensure_ascii=False)
            json.dump(sk_items, open(os.path.join(sdir, f"3_score_r0_{sname(name)}_skeptic.json"), "w"), indent=1, ensure_ascii=False)
    json.dump({"chains": chains, "graph": {"edges": edges}}, open(os.path.join(sdir, "graph.json"), "w"), indent=1, ensure_ascii=False)
    json.dump(profs, open(os.path.join(sdir, "profiles.json"), "w"), indent=1, ensure_ascii=False)
    print("species done", len(chains), flush=True)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["species"] and len(a) > 1:
        print(json.dumps(speciate(" ".join(a[1:])), indent=1, ensure_ascii=False))
    elif a == ["species"]:
        species_all()
    elif a == ["profiles"]:
        profiles()
    else:
        run_all()
