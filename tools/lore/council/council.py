"""qwen3.6 lore council, first principles.
  python3 council.py planet     -> planet/draft_*.md + planet/review_*.md   (then Opus writes planet_canon.md)
  python3 council.py creatures  -> creatures/draft_*.md + creatures/review_*.md (uses planet_canon.md)
  python3 council.py planet-astrobio -> planet/review_astrobio.md (referee on the 7 planet drafts)
  python3 council.py chair       -> chair_0.json, referee_chair.json, chair_final.json (world canon as JSON, see autoloop.py)
World-parametric: set LORE_CTX=/path/ctx.json (written by autoloop.py: id, name, kind, system, notes, canon_text, habitat_word, ...).
Without LORE_CTX the original Primigenia behaviour is unchanged. Resumable: existing files are skipped."""
import json, os, sys, threading, urllib.request, random, re, time, subprocess, tempfile

URL = "https://api.nan.builders/v1/chat/completions"; KEY = os.environ["NAN_API_KEY"]; M = "qwen3.6"
HERE = os.path.dirname(os.path.abspath(__file__))
# output dir: $LORE_RUNS_DIR, default tools/lore/council/runs/ (gitignored)
D = os.path.abspath(os.environ.get("LORE_RUNS_DIR", os.path.join(HERE, "runs")))
os.makedirs(os.path.join(D, "tmp"), exist_ok=True)
CTX = json.load(open(os.environ["LORE_CTX"])) if os.environ.get("LORE_CTX") else {}
CANON = CTX.get("canon_text") or open(os.path.join(HERE, "canon.md")).read()
HABITAT = CTX.get("habitat_word", "island")
PC = os.path.join(D, "planet_canon.md")
PLANET = open(PC).read() if os.path.exists(PC) else ""
sem = threading.Semaphore(int(os.environ.get("QWEN_CONC", "5")))  # NAN qwen allows 5 concurrent; set QWEN_CONC lower while an agentplay batch shares the key


# advisors served by opencode free-tier models instead of qwen (model diversity)
from voices import OC_MODEL, REFEREE_FALLBACK, down_file
ocsem = threading.Semaphore(2)
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def oc_chat(model, system, user):
    """One-shot call through `opencode run`; the prompt goes through a file (too big for argv)."""
    wd = tempfile.mkdtemp(prefix="oc_", dir=os.path.join(D, "tmp"))
    open(os.path.join(wd, "prompt.md"), "w").write("# SYSTEM\n" + system + "\n\n# TASK\n" + user)
    pf = os.path.join(wd, "prompt.md")
    msg = (f"Read the file {pf} (that exact absolute path; ignore any other prompt.md). Act as described under SYSTEM and do the TASK. "
           "Do not edit or create any files and do not run commands other than reading that one file. "
           "Your final message must be ONLY the requested Markdown answer.")
    down = down_file(os.path.dirname(D), model)  # shared cooldown when opencode's free quota is exhausted
    for a in range(8):
        if os.path.exists(down) and time.time() < float(open(down).read() or 0):
            print("oc cooldown: skipping", model, file=sys.stderr, flush=True); return "(failed)"
        with ocsem:
            r = subprocess.run(["opencode", "run", "-m", model, msg], cwd=wd, stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, timeout=1800)
        out = ANSI.sub("", r.stdout)
        out = "\n".join(l for l in out.splitlines() if not re.match(r"^\s*(> build|\S\s+(Read|Glob|Grep|List|Bash)\b)", l)).strip()
        if r.returncode == 0 and len(out) > 800:
            return re.sub(r"<think>.*?</think>", "", out, flags=re.S).strip()
        if "usage limit" in (r.stdout + r.stderr).lower() or "model unavailable" in (r.stdout + r.stderr).lower():
            open(down, "w").write(str(time.time() + 1800)); print("oc free usage limit reached: cooling this model down for 30 min", file=sys.stderr, flush=True); return "(failed)"
        print("oc retry", model, a, r.returncode, len(out), r.stderr[-300:], file=sys.stderr, flush=True); time.sleep(30)
    return "(failed)"


# judges served by Cursor's own models (owner rule: only Cursor's models on the Cursor subscription)
CUR_MODEL = {"astrobio": "composer-2.5"}
JUDGE_PERSONA = {"chair": ("You are the CHAIR and editor of the council: you consolidate drafts and reviews, enforce consistency with the planet canon (cite fact ids) and with the creature lore, resolve contradictions, and write the final canon in exactly the requested format. You never invent references."),
                 "astrobio": (
    "You are an astrobiologist and evolutionary biologist acting as the council's plausibility referee. For every claim you check "
    "whether the adaptation is plausible FOR THAT CREATURE on THAT planet: is the physics right (acoustics, optics, gas exchange, "
    "scaling laws, metabolism, energy budgets), does selection actually favour it, are there real analogues on Earth (name the "
    "organism and mechanism, e.g. bat and oilbird echolocation, firefly and Photinus femme-fatale mimicry, Hawaiian bobtail squid "
    "counter-illumination, electric fish jamming avoidance response) and what the literature says (cite author/year or a textbook "
    "when you know it; say 'from memory, unverified' when unsure; never invent a citation). Verdict per claim: plausible / "
    "plausible with a fix (give the fix) / implausible (why), and what to change so the game keeps the fun but stays honest.")}
cursem = threading.Semaphore(2)


def cur_chat(model, system, user):
    wd = tempfile.mkdtemp(prefix="cur_", dir=os.path.join(D, "tmp"))
    open(os.path.join(wd, "prompt.md"), "w").write("# SYSTEM\n" + system + "\n\n# TASK\n" + user)
    pf = os.path.join(wd, "prompt.md")
    msg = (f"Read the file {pf} (that exact absolute path; ignore any other prompt.md). Act as described under SYSTEM and do the TASK. You may search the web for references. "
           "Do not create or edit files. Your final message must be ONLY the requested answer.")
    down = os.path.join(os.path.dirname(D), "cursor_down_until_" + re.sub(r"\W+", "_", model))  # plan rejected the model: do not retry 8 times per call
    for a in range(8):
        if os.path.exists(down) and time.time() < float(open(down).read() or 0):
            print("cursor cooldown: skipping", model, file=sys.stderr, flush=True); return "(failed)"
        with cursem:
            r = subprocess.run(["agent", "-p", "--trust", "--mode", "ask", "--model", model, "--workspace", wd, msg], cwd=wd,
                               stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=2400)
        out = ANSI.sub("", r.stdout).strip()
        if r.returncode == 0 and len(out) > 300:
            return out
        if "Model unavailable" in (r.stdout + r.stderr) or "usage limit" in (r.stdout + r.stderr).lower():
            open(down, "w").write(str(time.time() + 1800)); print("cursor model unavailable on this plan: cooling down 30 min", file=sys.stderr, flush=True); return "(failed)"
        print("cursor retry", model, a, r.returncode, len(out), r.stderr[-300:], file=sys.stderr, flush=True); time.sleep(30)
    return "(failed)"


# Codex GPT sol: the CHAIR/editor of the flora pass (and any step that asks for k == "chair"); one call at a time
SOL_MODEL = {"chair": "gpt-6.1-sol"}
solsem = threading.Semaphore(1)


def sol_chat(system, user):
    wd = tempfile.mkdtemp(prefix="sol_", dir=os.path.join(D, "tmp"))
    pf = os.path.join(wd, "prompt.md")
    open(pf, "w").write("# SYSTEM\n" + system + "\n\n# TASK\n" + user)
    down = os.path.join(os.path.dirname(D), "sol_down_until")
    msg = f"Read the file {pf} and do the TASK. Output ONLY the requested answer."
    for a in range(5):
        if os.path.exists(down) and time.time() < float(open(down).read() or 0): return "(failed)"
        with solsem:
            try:
                r = subprocess.run(["codex", "exec", "--skip-git-repo-check", "-m", SOL_MODEL["chair"], "-s", "read-only", msg], cwd=wd,
                                   stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=1800)
            except subprocess.TimeoutExpired:
                print("sol timeout", a, file=sys.stderr, flush=True); continue
        out = ANSI.sub("", r.stdout)
        if "\ncodex\n" in out: out = out.rsplit("\ncodex\n", 1)[1]
        out = "\n".join(l for l in out.splitlines() if not l.startswith(("hook:", "tokens used"))).strip()
        if r.returncode == 0 and len(out) > 200: return out
        if "usage limit" in (r.stdout + r.stderr).lower():
            open(down, "w").write(str(time.time() + 3600)); print("sol usage limit: cooling down 60 min", file=sys.stderr, flush=True); return "(failed)"
        print("sol retry", a, r.returncode, len(out), r.stderr[-300:], file=sys.stderr, flush=True); time.sleep(60)
    return "(failed)"


def persona(k):
    return JUDGE_PERSONA.get(k) or ADV[k]


def ask(k, system, user, **kw):
    if k in SOL_MODEL:  # chair: sol, falling back to the DeepSeek skeptic via opencode, then qwen
        t = sol_chat(system, user)
        if not t.startswith("(failed)"): return t
        t = oc_chat(OC_MODEL["skeptic"], system, user)
        return t if not t.startswith("(failed)") else chat(system, user, **kw)
    if k in CUR_MODEL:
        t = cur_chat(CUR_MODEL[k], system, user)
        if t.startswith("(failed)"):
            print("referee fallback: cursor unavailable; trying", REFEREE_FALLBACK, file=sys.stderr, flush=True)
            t = oc_chat(REFEREE_FALLBACK, system, user)
        return t
    return oc_chat(OC_MODEL[k], system, user) if k in OC_MODEL else chat(system, user, **kw)


def chat(system, user, temp=0.9, max_tokens=7000):
    for a in range(40):
        body = json.dumps({"model": M, "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
                           "temperature": temp, "max_tokens": min(32000, int(max_tokens * (1 + 0.5 * min(a, 4))))}).encode()  # empty content = reasoning ate the budget: grow it
        try:
            with sem:
                r = urllib.request.Request(URL, body, {"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                                       "User-Agent": "opencode"})
                out = json.load(urllib.request.urlopen(r, timeout=900))["choices"][0]["message"]["content"]
                if not out: raise ValueError("empty content (max_tokens eaten by reasoning?)")
            return re.sub(r"<think>.*?</think>", "", out, flags=re.S).strip()
        except Exception as e:
            print("retry", a, e, file=sys.stderr, flush=True); time.sleep(30)
    return "(failed)"


ADV = {
    "naturalist": "You are a field naturalist and evolutionary ecologist. You explain WHY each creature is shaped and behaves as it does: food web, niches, predator-prey, migrations, courtship, how the biomes shaped them. Plausible alien biology.",
    "physicist": "You are a planetary scientist and biophysicist. You derive everything from numbers: stellar spectrum, gravity, pressure, temperature, radiation, acoustics, optics, chemistry. You catch physics errors and you love when one physical fact explains five traits.",
    "mythmaker": "You are a mythmaker. You find the legends hidden in the physics: how the creatures themselves would 'remember' the falling star, the giant on the islet, the cousins; rituals and taboos that are really adaptations.",
    "designer": "You are a game designer. Every causal chain must end in PLAY: a skill, a move (roles Basic/Engage/Poke/Control/Defence/Signature), a befriend preference, a weakness to exploit, a secret, a reason to explore, with a discovery every 10-15 minutes.",
    "skeptic": "You are the council's skeptic, an evolutionary biologist who hates arbitrary traits. You hunt for 'because it looks cool' and replace it with a real cause, propose contrarian alternatives (the opposite solution to the same pressure), and keep the numbers honest.",
    "senses": "You are a xenobiologist of senses and communication: what each creature perceives (light spectrum, sound, smell, vibration, electric or magnetic fields, pressure) and how it signals, all derived from the planet's physics, and how the player can read, imitate or jam those signals.",
    "wildcard": "You are a wildcard storyteller with humour and wonder. You find the surprising consequences of the physics: odd friendships, memorable quirks, one or two haunting moments, the creature players fall in love with.",
}

FP = """FIRST PRINCIPLES (mandatory). Nothing is arbitrary. Every trait is the end of a causal chain that starts in physics:
star (type, light, UV, flares) -> planet (gravity, day length, tilt, atmosphere density and composition, magnetic field and surface
radiation, oceans, chemistry, moons, tides) -> habitat on the {HABITAT} (biome, food, light, temperature, terrain) -> selection pressure
-> trait (body part, sense, behaviour) -> what the PLAYER can do with it (a skill or move, a befriend preference, a weakness, a secret).
Style example: "They talk in low hums. Why? Sound carries far in the dense air, and valley fog blinds eyes most mornings. Why fog? Cold
sea against warm volcanic ground. Root: 1.6 bar atmosphere + active volcanism. -> Skill 'Long hum' (Control): a low call that carries
through the fog, gathers the herd and calms its members. Weakness: deaf to high pitches, so a whistle startles them."
GAME NUMBERS ARE NOT YOURS: the game is real time and moves are designed in our labs. A skill is only a name, a role and a plain
description of the behaviour. Never write damage, durations, turns, percentages, cooldowns, ranges or any stat for a skill or move.
(Planet and physics numbers, with units, are still required in the world facts and links.)"
Write each chain as:  TRAIT  <- why  <- why  <- PHYSICAL ROOT   ->  SKILL/MECHANIC (+ weakness).
Reuse the same planet facts across creatures; where two creatures face the same pressure, show convergent or opposite solutions."""
FP = FP.replace("{HABITAT}", HABITAT)

TASK_PLANET_FICTIONAL = """Design THE WORLD of this council from first principles, consistent with the canon frame and the notes above.
## Star and orbit (or the equivalent energy source and environment: type, luminosity, UV, year length, flares)
## Body (gravity, radius, day length, tilt and seasons, moons and tides, magnetic field, surface radiation)
## Atmosphere or medium (pressure, composition, how sound, light and smell travel, weather, layers)
## Oceans or solvents, geology and chemistry (what is liquid, volcanism, minerals, energy sources for life)
## Life's chemistry (biochemistry, solvent, why it works HERE, what is food, what is poison)
## 12 consequences for life (each one a full chain: physical fact -> pressure -> favoured trait -> playable skill or system)
## 3 ways this world differs from Earth that a player would FEEL in play
Every number with a one-line justification. Max ~2000 words."""
TASK_PLANET_REAL = """Write THE WORLD FACT SHEET of this REAL place from first principles and the real literature, consistent with the notes above.
Same sections as a planet design: ## Star and orbit  ## Body  ## Atmosphere or medium  ## Oceans, geology and chemistry  ## Life's chemistry
## 12 consequences for life (physical fact -> pressure -> favoured trait -> playable skill or system).
Every number must be the REAL measured value with units, and EVERY fact must name 1-2 real published references (author, year, title, journal or publisher): cite only works you are sure exist, and write 'from memory, unverified' when unsure. Never invent a citation. Max ~2000 words."""
TASK_PLANET_THIRD = """Write THE WORLD FACT SHEET of this world, which comes from a published work of fiction. Facts stated in the LORE TEXT in the notes are GIVEN: keep them and mark them (given). Where the lore is silent, FILL THE GAPS with the most plausible first-principles science, marked (inferred), and give real science references where physics or chemistry is involved (author, year, title; never invent a citation, say 'from memory, unverified' when unsure).
Sections: ## Star and orbit  ## Body  ## Atmosphere or medium  ## Oceans, geology and chemistry  ## Life's chemistry
## 12 consequences for life (physical fact -> pressure -> favoured trait -> playable skill or system)
Original wording only (never copy text from the work). Max ~2000 words."""
TASK_PLANET = {"fictional": TASK_PLANET_FICTIONAL, "real": TASK_PLANET_REAL, "third_party": TASK_PLANET_THIRD}.get(CTX.get("kind", "fictional"))
EXTRA_PLANET = ("\n\n# NOTES FOR THIS WORLD\n" + CTX["notes"]) if CTX.get("notes") else ""

TASK_CREATURES = """Using the canon and THE PLANET above, write the creature stage's lore from first principles. Markdown:
## Island history (6-10 steps from the meteor to now, each step caused by the planet's physics)
## The 5 meteor shards (one line each, in order; together they tell a story)
## Creatures. For EACH of: Rondo, Zanco, Espinodo, Garfio, Coloso, Merodeador, Zancuda, Babosa, the player's lineage and its cousins,
the nocturnal creature, the albinos:
- niche (1 line: where, what it eats, what eats it)
- 3-4 FIRST-PRINCIPLES CHAINS for its defining traits (TRAIT <- why <- why <- PHYSICAL ROOT -> SKILL/MECHANIC + weakness)
- behaviour with other species (2 lines, explained by the chains)
- 2 field-journal lines (terse, curious; the second one hints at a 'why')
- 1 secret or discovery hook, 1 move it can teach by Observe (name + role)
## Places: 5 places with a story, each explained physically (why the cave is there, why the tree is giant...) + the discovery.
## Your single best idea (one paragraph): the thing that would make a player care.
Original, concrete, consistent. Max ~2600 words."""

REV = {
    "flora": "Seven anonymous flora designs for the island follow. Review as a peer: 1) rank A-G, one line why (botanical plausibility, consistency with the planet canon facts, coverage of habitats, play value); 2) per habitat, the best plant (letter + name + why) and what to combine; 3) physics or botany errors and contradictions with the canon or between drafts; 4) the 8 strongest plants overall and 3 to cut. Concise.",
    "planet": "Seven anonymous planet designs follow. Review as a peer: 1) rank A-G, one line why (physical consistency, fit with the fixed art, what it gives to play); 2) per section, the best choice (letter + value + why); 3) physics errors or contradictions; 4) the 6 most playable consequences overall. Concise.",
    "creatures": "Seven anonymous lore drafts follow. Review as a peer: 1) rank A-G, one line why; 2) per creature and for the shards, the best chain or idea (letter + one line) and what to combine; 3) chains that break physics or the planet canon, and contradictions between drafts; 4) the 6 strongest chains overall (they become skills) and 3 ideas to cut. Concise.",
}


def stage(name, task, extra):
    od = os.path.join(D, name); os.makedirs(od, exist_ok=True); drafts = {}

    def run(k):
        p = os.path.join(od, f"draft_{k}.md")
        if os.path.exists(p): drafts[k] = open(p).read(); return
        t = ask(k, ADV[k] + "\n\n" + CANON + extra + "\n\n" + FP, task)
        drafts[k] = t
        if t.startswith("(failed)"): print(name, "draft FAILED", k, flush=True); return
        open(p, "w").write(t)
        print(name, "draft", k, len(t), flush=True)
    ts = [threading.Thread(target=run, args=(k,)) for k in ADV]; [t.start() for t in ts]; [t.join() for t in ts]
    keys = list(ADV); random.Random(7).shuffle(keys); lab = {k: chr(65 + i) for i, k in enumerate(keys)}
    json.dump(lab, open(os.path.join(od, "labels.json"), "w"))
    anon = "\n\n".join(f"=== RESPONSE {lab[k]} ===\n{drafts[k]}" for k in keys if not drafts[k].startswith("(failed)"))

    def rev(k):
        p = os.path.join(od, f"review_{k}.md")
        if os.path.exists(p): return
        t = ask(k, ADV[k] + "\n\n" + CANON + extra, anon + "\n\n" + REV[name], temp=0.3, max_tokens=4000)
        if t.startswith("(failed)"): print(name, "review FAILED", k, flush=True); return
        open(p, "w").write(t)
        print(name, "review", k, flush=True)
    ts = [threading.Thread(target=rev, args=(k,)) for k in ADV]; [t.start() for t in ts]; [t.join() for t in ts]
    print(name, "done", flush=True)



# ---- CHAIR: merge the world's drafts + reviews + referee into numbered facts (JSON for lore/worlds/<id>.json) ----
FACT_GROUPS = "star, orbit, planet, atmosphere, ocean, geology, chemistry, biochemistry, sky, climate, interior"
CHAIR_SCHEMA = """{"name": {"en": str, "es": str},
 "system": {"star": str, "position": str (real galactic/stellar position, or "fictional"), "distance_ly_from_sol": number or null},
 "facts": [{"id": "F1", "group": one of [%s], "claim": str (one clear statement, with the key number), "value": number or short string (optional),
            "unit": str (optional), "justification": str (why, one or two sentences), "consequences": [str] (2-3 short consequences for life), "refs": [CSL ids from "references"],
            "status": "active"}],
 "references": [{"id": "lowercase_author_year_shortword", "type": "article-journal|book|chapter|report|webpage", "title": str, "author": [{"family": str, "given": str}],
                 "issued": {"date-parts": [[year]]}, "container-title": str (journal, optional), "DOI": str (only if sure), "ISBN": str (only if sure)}]}""" % FACT_GROUPS
CHAIR_RULES = """Rules: 14 to 28 numbered facts F1..Fn, ordered star/energy -> body -> atmosphere or medium -> geology/chemistry -> life's chemistry; facts must be consistent with each other and must not duplicate. Each fact states ONE thing creatures can be derived from. Keep the numbers the referee accepted; apply the referee's fixes; drop what it called implausible unless a fix exists. Where real science supports a fact (physics, chemistry, biology), cite 1-3 references from the 'references' list (author, year, title, journal/publisher; ONLY works you are sure exist; they will be checked against Crossref/OpenLibrary and removed if not found; never invent). For kind 'real' EVERY fact MUST have at least one ref. For kind 'third_party', facts stated in the LORE TEXT are given: keep them, mark in justification '(given by the lore)', and fill gaps with '(inferred)'. Do not copy third-party text; original wording. Output ONLY the JSON object, no commentary."""


def _read(p):
    return open(p).read() if os.path.exists(p) else ""


def best_json(t):
    """Largest JSON value that decodes anywhere in t (models often echo the answer twice or add prose around it)."""
    dec = json.JSONDecoder(strict=False); best = None; i = 0
    while True:
        j = min([x for x in (t.find("{", i), t.find("[", i)) if x >= 0], default=-1)
        if j < 0: break
        try:
            v, end = dec.raw_decode(t, j)
            if isinstance(v, (dict, list)) and (best is None or end - j > best[1]): best = (v, end - j)
            i = end
        except ValueError:
            i = j + 1
    # a truncated top-level array: keep its complete elements when that covers more than any inner value did
    k = t.find("[")
    if k >= 0 and (t.find("{") < 0 or k < t.find("{")):
        items, p = [], k + 1
        while True:
            q = t.find("{", p)
            if q < 0: break
            try: o, p = dec.raw_decode(t, q); items.append(o)
            except ValueError: break
        if items and (best is None or p - k > best[1]): best = (items, p - k)
    if best is None: raise ValueError("no json")
    return best[0]


def _jload(text):
    v = best_json(text)
    if isinstance(v, dict): return v
    # truncated reply (the model ran out of tokens inside the references): rebuild {name, system, facts, references} from the complete parts
    i = text.find("{"); dec = json.JSONDecoder(strict=False); doc = {}
    for key in ("name", "system", "facts"):
        k = text.find(f'"{key}"', i)
        if k < 0: continue
        try: doc[key], _ = dec.raw_decode(text, text.index(":", k) + 1 + len(text[text.index(":", k) + 1:]) - len(text[text.index(":", k) + 1:].lstrip()))
        except ValueError: pass
    k = text.find('"references"')
    if k >= 0:
        refs, p = [], text.find("[", k) + 1
        while p > 0:
            q = text.find("{", p)
            if q < 0: break
            try: o, p = dec.raw_decode(text, q); refs.append(o)
            except ValueError: break
        doc["references"] = refs
    if "facts" not in doc: return v
    return doc


def _chair_ask(system, user):
    """Chair = DeepSeek skeptic via opencode, fallback qwen."""
    for attempt in range(3):
        t = ask("skeptic", system, user, temp=0.3, max_tokens=12000) if attempt < 2 else chat(system, user, temp=0.3, max_tokens=20000)
        if t.startswith("(failed)"): continue
        open(os.path.join(D, f"chair_raw_{int(time.time())}.txt"), "w").write(t)
        try: return _jload(t)
        except Exception as e: print("chair json error", attempt, e, file=sys.stderr, flush=True)
    return None


def _check_chair(doc):
    if not isinstance(doc, dict) or not isinstance(doc.get("facts"), list) or len(doc["facts"]) < 8: raise ValueError("chair output has too few facts")


def chair_main():
    pd = os.path.join(D, "planet"); kind = CTX.get("kind", "fictional")
    drafts = "\n\n".join(f"=== DRAFT {k} ===\n{_read(os.path.join(pd, f'draft_{k}.md'))}" for k in ADV if _read(os.path.join(pd, f"draft_{k}.md")) and not _read(os.path.join(pd, f"draft_{k}.md")).startswith("(failed)"))
    reviews = "\n\n".join(f"=== PEER REVIEW by {k} ===\n{_read(os.path.join(pd, f'review_{k}.md'))}" for k in ADV if _read(os.path.join(pd, f"review_{k}.md")))
    ref = _read(os.path.join(pd, "review_astrobio.md"))
    head = f"WORLD: {CTX.get('name', '?')} (id {CTX.get('id', '?')}, kind {kind}).\nNOTES:\n{CTX.get('notes', '')}\n\n"
    base = head + "# PLANET DRAFTS\n" + drafts + "\n\n# PEER REVIEWS\n" + reviews + "\n\n# ASTROBIOLOGY REFEREE\n" + ref
    sysmsg = ADV["skeptic"] + "\n\nYou are now the CHAIR of the council: merge the drafts into the world's canon facts."
    p0 = os.path.join(D, "chair_0.json"); pr = os.path.join(D, "referee_chair.json"); pf = os.path.join(D, "chair_final.json")
    if not os.path.exists(p0):
        doc = None
        for a in range(3):
            doc = _chair_ask(sysmsg, base + f"\n\n# TASK\nWrite the merged world canon for lore/worlds/{CTX.get('id')}.json as ONE JSON object with this shape:\n{CHAIR_SCHEMA}\n\n{CHAIR_RULES}")
            try: _check_chair(doc); break
            except Exception as e: print("chair 0 invalid", e, file=sys.stderr, flush=True); doc = None
        if doc is None: print("chair FAILED at step 0"); return 1
        json.dump(doc, open(p0, "w"), indent=1, ensure_ascii=False); print("chair 0 ok", len(doc["facts"]), "facts", flush=True)
    doc0 = json.load(open(p0))
    if not os.path.exists(pr):
        rt = ask("astrobio", persona("astrobio") + "\n\n" + CANON + EXTRA_PLANET,
                 "Referee this merged world canon (JSON) once more. For EACH fact: is the number and physics right, is the claim honest for its grade of speculation (say 'highly speculative' where true), are the references real (name any you doubt), what is missing or contradictory? Where silicon, exotic or stellar chemistry is involved, say under which conditions it works and cite the literature you know (author/year; 'from memory, unverified' if unsure; never invent). End with a numbered list of concrete FIXES (by fact id, plus any new fact to add). Concise Markdown.\n\n" + json.dumps(doc0, ensure_ascii=False))
        if rt.startswith("(failed)"): print("referee FAILED; keeping chair_0 as final"); json.dump(doc0, open(pf, "w"), indent=1, ensure_ascii=False); return 0
        open(pr, "w").write(rt); print("referee ok", flush=True)
    if not os.path.exists(pf):
        doc = None
        for a in range(3):
            doc = _chair_ask(sysmsg, "# CURRENT CANON JSON\n" + json.dumps(doc0, ensure_ascii=False) + "\n\n# REFEREE REPORT\n" + _read(pr) + f"\n\n# TASK\nApply every fix of the referee's report (keep ids F1..Fn stable; new facts get the next numbers; if a fact is dropped keep its id with \"status\": \"retired\"). Output the complete corrected JSON object, same shape:\n{CHAIR_SCHEMA}\n\n{CHAIR_RULES}")
            try: _check_chair(doc); break
            except Exception as e: print("chair final invalid", e, file=sys.stderr, flush=True); doc = None
        if doc is None: print("chair final FAILED; keeping chair_0"); doc = doc0
        json.dump(doc, open(pf, "w"), indent=1, ensure_ascii=False); print("chair final ok", len(doc["facts"]), "facts", flush=True)
    return 0

if __name__ != "__main__":
    pass
elif sys.argv[1:] == ["planet-astrobio"]:
    od = os.path.join(D, "planet"); keys = list(ADV); lab = json.load(open(os.path.join(od, "labels.json")))
    anon = "\n\n".join(f"=== RESPONSE {lab[k]} ===\n{open(os.path.join(od, f'draft_{k}.md')).read()}" for k in sorted(keys, key=lambda k: lab[k])
                        if os.path.exists(os.path.join(od, f"draft_{k}.md")) and not open(os.path.join(od, f"draft_{k}.md")).read().startswith("(failed)"))
    if os.path.exists(os.path.join(od, "review_astrobio.md")): sys.exit(0)
    t = ask("astrobio", persona("astrobio") + "\n\n" + CANON + EXTRA_PLANET, anon + "\n\nReferee these planet designs for plausibility: per section, which numbers and consequences for life hold up (with Earth analogues and references) and which need fixing; then the 10 consequences for life you would keep, each with its best real-world analogue. Concise Markdown.")
    if t.startswith("(failed)"): sys.exit("astrobio review failed")
    open(os.path.join(od, "review_astrobio.md"), "w").write(t); print("astrobio review done", flush=True)
elif sys.argv[1:] == ["planet"]:
    stage("planet", TASK_PLANET, EXTRA_PLANET)
elif sys.argv[1:] == ["creatures"]:
    assert PLANET, "write planet_canon.md first"
    stage("creatures", TASK_CREATURES, "\n\n# THE PLANET (canon)\n" + PLANET)
elif sys.argv[1:] == ["chair"]:
    sys.exit(chair_main())
else:
    sys.exit(__doc__)
