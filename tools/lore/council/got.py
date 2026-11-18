"""Graph-of-Thoughts lore council for the creature stage (A22).

Unit of thought = one causal chain:  trait <- why ... <- planet fact(s) -> skill (+ weakness).
Operations (each step is resumable; outputs in got/):
  1 GENERATE   all 7 advisors write chains for every creature (JSON)
  2 AGGREGATE  per creature, merge the ~25 chains into the 4-5 best distinct ones (combining links, keeping provenance)
  3 SCORE      physicist (causality), skeptic (honesty / no arbitrary traits), designer (playability): 1-10 + fix notes
  4 REFINE     chains with any score < 7 are rewritten by a different advisor, then rescored (max 2 rounds)
  5 CROSSLINK  edges between creatures: shared roots (convergent / opposite), predation, symbiosis, mimicry; contradictions
Output: got/graph.json  (facts, chains, edges) -> merged by Opus into docs/LORE-CREATURES.md and lore/creatures.graph.json.
Output dir: $LORE_RUNS_DIR (default council/runs/). Needs planet_canon.md in it with fact ids F1..Fn.
"""
import json, os, re, sys, threading, random
from council import ADV, CANON, FP, D, ask, persona

PLANET = open(os.path.join(D, "planet_canon.md")).read()
OUT = os.path.join(D, "got"); os.makedirs(OUT, exist_ok=True)
CREATURES = ["Rondo", "Zanco", "Espinodo", "Garfio", "Coloso", "Merodeador", "Zancuda", "Babosa",
             "player lineage and cousins", "nocturnal creature", "albinos"]
BASE = CANON + "\n\n# THE PLANET (canon; cite facts by id)\n" + PLANET + "\n\n" + FP

CHAIN_SCHEMA = """{"creature": str, "trait": str (the observable trait, 3-8 words),
 "links": [str, ...] (the 'why' steps from the trait down to the root, 2-4 steps, each one short and causal),
 "roots": ["F3", ...] (planet fact ids from the canon),
 "skill": {"name": str, "role": "Basic|Engage|Poke|Control|Defence|Signature|Passive|Social", "effect": str (what it does in play, with a number)},
 "weakness": str (how the player can exploit it), "observe": [str, str, str] (three things the player must SEE to reveal the chain),
 "journal": str (one terse, curious line)}"""


def jparse(text):
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    t = m.group(1) if m else text
    i = min([x for x in (t.find("["), t.find("{")) if x >= 0], default=-1)
    if i < 0: raise ValueError("no json")
    for j in range(len(t), i, -1):
        try: return json.loads(t[i:j])
        except Exception: continue
    raise ValueError("bad json")


def cached(name, fn):
    p = os.path.join(OUT, name)
    if os.path.exists(p): return json.load(open(p))
    for a in range(3):
        try:
            v = fn(); json.dump(v, open(p, "w"), indent=1, ensure_ascii=False); print("ok", name, flush=True); return v
        except Exception as e:
            print("retry", name, a, e, file=sys.stderr, flush=True)
    return None


def par(items, f):
    res = {}
    def w(x): res[x] = f(x)
    ts = [threading.Thread(target=w, args=(x,)) for x in items]; [t.start() for t in ts]; [t.join() for t in ts]
    return res


def generate():
    def g(k):
        return cached(f"1_gen_{k}.json", lambda: jparse(ask(k, ADV[k] + "\n\n" + BASE,
            f"Write 3-4 first-principles chains for EACH of these: {', '.join(CREATURES)}. "
            f"Output ONLY a JSON array of chains, each: {CHAIN_SCHEMA}. Use only planet facts from the canon (cite ids). "
            "Different creatures facing the same pressure should show convergent or opposite solutions.", temp=0.9, max_tokens=12000)))
    return par(list(ADV), g)


def aggregate(gen):
    keys = list(ADV)
    def a(c):
        pool = [dict(ch, by=k) for k, chs in gen.items() if chs for ch in chs if isinstance(ch, dict)
                and c.split()[0].lower() in str(ch.get("creature", "")).lower()]
        agg = keys[CREATURES.index(c) % len(keys)]
        return cached(f"2_agg_{c.replace(' ', '_')}.json", lambda: jparse(ask(agg, ADV[agg] + "\n\n" + BASE,
            f"Candidate chains for {c} from several advisors (field 'by'):\n{json.dumps(pool, ensure_ascii=False)}\n\n"
            "AGGREGATE them into the 4-5 best DISTINCT chains for this creature: merge chains that describe the same trait (keep the "
            "strongest links from each), drop arbitrary or weak ones, keep the skills varied across roles. Add field \"from\": [advisor "
            f"names merged]. Output ONLY a JSON array, each item: {CHAIN_SCHEMA} plus \"from\".", temp=0.4, max_tokens=8000)))
    return par(CREATURES, a)


JUDGES = {"physicist": "causality and physics: does every link follow from the previous one and from the cited planet facts?",
          "skeptic": "honesty: is anything arbitrary ('because it looks cool'), are numbers plausible, is there a better contrarian cause?",
          "astrobio": "biological plausibility for THIS creature on THIS planet: does selection favour it, is the physiology/energy budget possible, what is the closest real Earth analogue (name it, cite author/year if known, else say unverified)?",
          "designer": "play: is the skill fun, readable and balanced in its role, is the weakness exploitable, are the 3 observe steps visible in a 3D game?"}


def score(c, chains, rnd):
    def s(j):
        return cached(f"3_score_r{rnd}_{c.replace(' ', '_')}_{j}.json", lambda: jparse(ask(j, persona(j) + "\n\n" + BASE,
            f"Score each chain for {c} on {JUDGES[j]}\n{json.dumps(chains, ensure_ascii=False)}\n\n"
            'Output ONLY a JSON array, one item per chain in order: {"trait": str, "score": 1-10, "fix": str (concrete fix, or ""), "analogue": str (real organism/mechanism, or "")}',
            temp=0.2, max_tokens=4000)))
    return par(list(JUDGES), s)


def refine(c, chains, scores, rnd):
    bad = []
    for i, ch in enumerate(chains):
        notes = [(j, sc[i]) for j, sc in scores.items() if sc and i < len(sc)]
        lo = min([n[1].get("score", 10) for n in notes] or [10])
        if lo < 7: bad.append((i, notes))
    if not bad: return chains, False
    ref = ["senses", "naturalist", "wildcard", "mythmaker"][rnd % 4]
    fixes = {str(i): [{"judge": j, **n} for j, n in notes] for i, notes in bad}
    new = cached(f"4_refine_r{rnd}_{c.replace(' ', '_')}.json", lambda: jparse(ask(ref, ADV[ref] + "\n\n" + BASE,
        f"These chains for {c} were judged weak (index -> judges' notes): {json.dumps(fixes, ensure_ascii=False)}\n"
        f"All chains: {json.dumps(chains, ensure_ascii=False)}\n\nRewrite ONLY the weak chains so they pass every judge (fix the causal "
        "links, cite the right planet facts, make the skill and weakness playable). Output ONLY the full JSON array (all chains, "
        f"fixed ones replaced, same order), each: {CHAIN_SCHEMA} plus \"from\".", temp=0.5, max_tokens=8000)))
    return (new or chains), True


def crosslink(final):
    return cached("5_crosslink.json", lambda: jparse(ask("naturalist", ADV["naturalist"] + "\n\n" + BASE,
        f"Final chains per creature:\n{json.dumps(final, ensure_ascii=False)}\n\nBuild the EDGES of the island's lore graph: "
        "pairs of creatures that share a planet root (convergent or opposite solutions), predation, symbiosis, mimicry, rivalry, "
        "teaching (one creature's move counters another's). Also list contradictions between chains. Output ONLY JSON: "
        '{"edges": [{"a": creature, "b": creature, "kind": "convergent|opposite|predation|symbiosis|mimicry|rivalry|counter", '
        '"via": "F-id or trait", "note": str}], "contradictions": [str]}', temp=0.3, max_tokens=6000)))


def run_all():
    gen = generate()
    agg = aggregate(gen)
    final = {}
    for c in CREATURES:
        chains = agg.get(c) or []
        for rnd in range(2):
            sc = score(c, chains, rnd)
            chains, changed = refine(c, chains, sc, rnd)
            if not changed: break
        final[c] = chains
    json.dump(final, open(os.path.join(OUT, "final_chains.json"), "w"), indent=1, ensure_ascii=False)
    edges = crosslink(final)
    json.dump({"chains": final, "graph": edges}, open(os.path.join(OUT, "graph.json"), "w"), indent=1, ensure_ascii=False)
    print("got done", flush=True)


if __name__ == "__main__" and sys.argv[1:2] != ["species"]:
    pass


# ---- extra operation: SPECIATE (new creatures from physics) -------------------------------------
# python3 got.py species "sees sound and talks with light"   -> derive a species around a seed concept
# python3 got.py species                                      -> find empty niches on the island and fill 3 of them
def speciate(seed):
    tag = re.sub(r"\W+", "_", seed or "niches")[:40]
    gen = cached(f"6_species_{tag}.json", lambda: jparse(ask("naturalist", ADV["naturalist"] + "\n\n" + BASE,
        (f"Derive a NEW creature species for this island around the concept: '{seed}'. First ask: on THIS planet, where and why "
         "would such a trait evolve? Find the habitat and pressures that force it, then derive the rest of the body and behaviour "
         "from the same causes (every trait is a consequence, nothing decorative)." if seed else
         "List the island's EMPTY niches (habitat x food x time of day not taken by the existing creatures) and derive 3 new species "
         "to fill them, each forced by the planet's physics.") +
        ' Output ONLY JSON: [{"name": Spanish-flavoured, "niche": str, "body": str, "chains": [4 chains, each ' + CHAIN_SCHEMA +
        '], "relations": [{"with": existing creature, "kind": str, "note": str}], "haunting_moment": str, "journal": [str, str]}]',
        temp=0.9, max_tokens=8000)))
    sc = cached(f"6_species_{tag}_review.json", lambda: jparse(ask("skeptic", ADV["skeptic"] + "\n\n" + BASE,
        f"Check these new species against the planet canon and the existing creatures:\n{json.dumps(gen, ensure_ascii=False)}\n"
        'Output ONLY JSON: [{"name": str, "score": 1-10, "broken_links": [str], "fix": str}]', temp=0.2, max_tokens=3000)))
    bio = cached(f"6_species_{tag}_astrobio.json", lambda: jparse(ask("astrobio", persona("astrobio") + "\n\n" + BASE,
        f"Referee these new species for biological plausibility:\n{json.dumps(gen, ensure_ascii=False)}\n"
        'Output ONLY JSON: [{"name": str, "chains": [{"trait": str, "verdict": "plausible|fixable|implausible", "why": str, '
        '"analogue": str, "reference": str (author/year or textbook, or "from memory, unverified"), "fix": str}]}]')))
    print(json.dumps({"species": gen, "review": sc, "astrobio": bio}, indent=1, ensure_ascii=False))


if __name__ == "__main__" and sys.argv[1:2] == ["species"]:
    pass  # handled below

if __name__ == "__main__":
    if sys.argv[1:2] == ["species"]:
        speciate(" ".join(sys.argv[2:]))
    else:
        run_all()
