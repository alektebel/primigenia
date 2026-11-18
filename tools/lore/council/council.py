"""qwen3.6 lore council, first principles.
  python3 council.py planet     -> planet/draft_*.md + planet/review_*.md   (then Opus writes planet_canon.md)
  python3 council.py creatures  -> creatures/draft_*.md + creatures/review_*.md (uses planet_canon.md)
Resumable: existing files are skipped."""
import json, os, sys, threading, urllib.request, random, re, time, subprocess, tempfile

URL = "https://api.nan.builders/v1/chat/completions"; KEY = os.environ["NAN_API_KEY"]; M = "qwen3.6"
HERE = os.path.dirname(os.path.abspath(__file__))
# output dir: $LORE_RUNS_DIR, default tools/lore/council/runs/ (gitignored)
D = os.path.abspath(os.environ.get("LORE_RUNS_DIR", os.path.join(HERE, "runs")))
os.makedirs(os.path.join(D, "tmp"), exist_ok=True)
CANON = open(os.path.join(HERE, "canon.md")).read()
PC = os.path.join(D, "planet_canon.md")
PLANET = open(PC).read() if os.path.exists(PC) else ""
sem = threading.Semaphore(2)  # qwen allows 5 concurrent; leave room for the agentplay batch


# advisors served by opencode free-tier models instead of qwen (model diversity)
OC_MODEL = {"skeptic": "opencode/deepseek-v4.1-flash-free", "senses": "opencode/glm-5.3-flash-free"}
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
    for a in range(6):
        with ocsem:
            r = subprocess.run(["opencode", "run", "-m", model, msg], cwd=wd, stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, timeout=1800)
        out = ANSI.sub("", r.stdout)
        out = "\n".join(l for l in out.splitlines() if not re.match(r"^\s*(> build|\S\s+(Read|Glob|Grep|List|Bash)\b)", l)).strip()
        if r.returncode == 0 and len(out) > 800:
            return re.sub(r"<think>.*?</think>", "", out, flags=re.S).strip()
        print("oc retry", model, a, r.returncode, len(out), r.stderr[-300:], file=sys.stderr, flush=True); time.sleep(30)
    return "(failed)"


# judges served by Cursor's own models (owner rule: only Cursor's models on the Cursor subscription)
CUR_MODEL = {"astrobio": "composer-2.5"}
JUDGE_PERSONA = {"astrobio": (
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
    for a in range(4):
        with cursem:
            r = subprocess.run(["agent", "-p", "--trust", "--mode", "ask", "--model", model, "--workspace", wd, msg], cwd=wd,
                               stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=2400)
        out = ANSI.sub("", r.stdout).strip()
        if r.returncode == 0 and len(out) > 300:
            return out
        print("cursor retry", model, a, r.returncode, len(out), r.stderr[-300:], file=sys.stderr, flush=True); time.sleep(30)
    return "(failed)"


def persona(k):
    return JUDGE_PERSONA.get(k) or ADV[k]


def ask(k, system, user, **kw):
    if k in CUR_MODEL: return cur_chat(CUR_MODEL[k], system, user)
    return oc_chat(OC_MODEL[k], system, user) if k in OC_MODEL else chat(system, user, **kw)


def chat(system, user, temp=0.9, max_tokens=7000):
    body = json.dumps({"model": M, "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
                       "temperature": temp, "max_tokens": max_tokens}).encode()
    for a in range(40):
        try:
            with sem:
                r = urllib.request.Request(URL, body, {"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                                       "User-Agent": "opencode"})
                out = json.load(urllib.request.urlopen(r, timeout=900))["choices"][0]["message"]["content"]
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
radiation, oceans, chemistry, moons, tides) -> habitat on the island (biome, food, light, temperature, terrain) -> selection pressure
-> trait (body part, sense, behaviour) -> what the PLAYER can do with it (a skill or move, a befriend preference, a weakness, a secret).
Style example: "They talk in low hums. Why? Sound carries far in the dense air, and valley fog blinds eyes most mornings. Why fog? Cold
sea against warm volcanic ground. Root: 1.6 bar atmosphere + active volcanism. -> Skill 'Long hum' (Control): calls the herd from 120 m
and calms allies. Weakness: deaf to high pitches, so a whistle startles them."
Write each chain as:  TRAIT  <- why  <- why  <- PHYSICAL ROOT   ->  SKILL/MECHANIC (+ weakness).
Reuse the same planet facts across creatures; where two creatures face the same pressure, show convergent or opposite solutions."""

TASK_PLANET = """Design THE PLANET of the creature stage from first principles, consistent with the canon and the fixed art.
## Star and orbit (type, luminosity, UV, year length, flares)
## Planet (gravity, radius, day length, axial tilt and seasons, moon(s) and tides, magnetic field, surface radiation)
## Atmosphere (pressure in bar, composition, oxygen, how sound and smell travel, sky colour, weather, fog, storms)
## Oceans, geology and chemistry (salinity, volcanism, minerals creatures can eat, why the island exists)
## Life's chemistry (what the panspermia seed brought: biochemistry, why plants are green, what is food, what is poison)
## 12 consequences for life (each one a full chain: physical fact -> pressure -> favoured trait -> playable skill or system)
## 3 ways this planet differs from Earth that a player would FEEL in play
Every number with a one-line justification. Max ~2000 words."""

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
    "planet": "Seven anonymous planet designs follow. Review as a peer: 1) rank A-G, one line why (physical consistency, fit with the fixed art, what it gives to play); 2) per section, the best choice (letter + value + why); 3) physics errors or contradictions; 4) the 6 most playable consequences overall. Concise.",
    "creatures": "Seven anonymous lore drafts follow. Review as a peer: 1) rank A-G, one line why; 2) per creature and for the shards, the best chain or idea (letter + one line) and what to combine; 3) chains that break physics or the planet canon, and contradictions between drafts; 4) the 6 strongest chains overall (they become skills) and 3 ideas to cut. Concise.",
}


def stage(name, task, extra):
    od = os.path.join(D, name); os.makedirs(od, exist_ok=True); drafts = {}

    def run(k):
        p = os.path.join(od, f"draft_{k}.md")
        if os.path.exists(p): drafts[k] = open(p).read(); return
        t = ask(k, ADV[k] + "\n\n" + CANON + extra + "\n\n" + FP, task); drafts[k] = t; open(p, "w").write(t)
        print(name, "draft", k, len(t), flush=True)
    ts = [threading.Thread(target=run, args=(k,)) for k in ADV]; [t.start() for t in ts]; [t.join() for t in ts]
    keys = list(ADV); random.Random(7).shuffle(keys); lab = {k: chr(65 + i) for i, k in enumerate(keys)}
    json.dump(lab, open(os.path.join(od, "labels.json"), "w"))
    anon = "\n\n".join(f"=== RESPONSE {lab[k]} ===\n{drafts[k]}" for k in keys)

    def rev(k):
        p = os.path.join(od, f"review_{k}.md")
        if os.path.exists(p): return
        t = ask(k, ADV[k] + "\n\n" + CANON + extra, anon + "\n\n" + REV[name], temp=0.3, max_tokens=4000); open(p, "w").write(t)
        print(name, "review", k, flush=True)
    ts = [threading.Thread(target=rev, args=(k,)) for k in ADV]; [t.start() for t in ts]; [t.join() for t in ts]
    print(name, "done", flush=True)


if __name__ != "__main__":
    pass
elif sys.argv[1:] == ["planet-astrobio"]:
    od = os.path.join(D, "planet"); keys = list(ADV); lab = json.load(open(os.path.join(od, "labels.json")))
    anon = "\n\n".join(f"=== RESPONSE {lab[k]} ===\n{open(os.path.join(od, f'draft_{k}.md')).read()}" for k in sorted(keys, key=lambda k: lab[k]))
    t = ask("astrobio", persona("astrobio") + "\n\n" + CANON, anon + "\n\nReferee these planet designs for plausibility: per section, which numbers and consequences for life hold up (with Earth analogues and references) and which need fixing; then the 10 consequences for life you would keep, each with its best real-world analogue. Concise Markdown.")
    open(os.path.join(od, "review_astrobio.md"), "w").write(t); print("astrobio review done", flush=True)
elif sys.argv[1:] == ["planet"]:
    stage("planet", TASK_PLANET, "")
elif sys.argv[1:] == ["creatures"]:
    assert PLANET, "write planet_canon.md first"
    stage("creatures", TASK_CREATURES, "\n\n# THE PLANET (canon)\n" + PLANET)
else:
    sys.exit(__doc__)
