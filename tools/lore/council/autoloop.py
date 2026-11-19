#!/usr/bin/env python3
"""The multi-world lore autoloop (A23): for every world of worlds_seed.json, unattended and resumable:
planet stage -> chair canon -> GoT creatures -> species for empty niches -> import_got -> validate -> render -> refcheck -> commit.

  export NAN_API_KEY=...; python3 tools/lore/council/autoloop.py [--only WORLD] [--max-worlds N] [--no-commit] [--no-wait-opus]

Per world: tools/lore/council/runs/<world>/ (gitignored): ctx.json, planet/, got/, chair_*.json, log.txt, state.json.
Summary table: docs/lore/AUTOLOOP.md. A failing world never stops the loop; a failing step is retried (the model calls retry
internally 8-40 times, each step up to 5 more times with backoff) and then marked failed.
"""
import argparse, datetime, glob, json, os, re, shutil, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
LORE = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(LORE))
sys.path.insert(0, LORE)
from lorelib import load, dump, slug
RUNS = os.path.abspath(os.environ.get("LORE_RUNS_DIR", os.path.join(HERE, "runs")))
DATE = datetime.date.today().isoformat()
PY = sys.executable
COAUTHOR = "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
GROUPS = {"star", "orbit", "planet", "atmosphere", "ocean", "geology", "chemistry", "biochemistry", "sky", "climate", "interior"}
FRAME = """# Lore council frame (world: {name}, kind: {kind})

Primigenia is a Spore-like evolution game with real depth: you play a lineage from a cell to space. Its lore is built from first
principles (A22): every trait of every creature is the end of a causal chain that starts in the physics of its world, and ends in
something the PLAYER can do (a skill, a weakness, a befriend preference, a secret). In the Space stage the player visits many worlds
and must be able to PREDICT what lives there from its physics. This council writes ORIGINAL lore for this world: {name}.

Rules: original wording and original creature names (no names, characters or text from existing books, films or games), EXCEPT
that entries filed from a third-party lore file (A19 All Tomorrows, A20 Project Hail Mary) keep their lore-file name and are
described in our own words. Facts stated in a LORE TEXT are given; the council only fills gaps. Honest science: say 'speculative'
where it is, never invent a citation. Tone: wonder first, a bit of humour, nature documentary meets myth; short, concrete, playable.
Moves by role: Basic/Engage/Poke/Control/Defence/Signature (+ Passive/Social).
"""
LOG = [None]


def log(msg):
    line = f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    if LOG[0]: open(LOG[0], "a").write(line + "\n")


def sh(cmd, env=None, cwd=ROOT, timeout=None):
    e = dict(os.environ); e.update(env or {})
    lf = open(LOG[0], "a") if LOG[0] else subprocess.DEVNULL
    r = subprocess.run(cmd, cwd=cwd, env=e, stdout=lf, stderr=subprocess.STDOUT, timeout=timeout)
    return r.returncode


def retry(name, fn, ok, tries=5):
    """Run fn() until ok() is true, with backoff (the model calls retry inside); returns True/False."""
    for a in range(tries):
        if ok(): return True
        log(f"step {name}: attempt {a + 1}/{tries}")
        try: fn()
        except Exception as e: log(f"step {name}: error {e!r}")
        if ok(): return True
        time.sleep(min(60 * (a + 1), 300))
    return ok()


def git(*args, check=False):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=check)


# ---------------- ctx ----------------
def lore_entries(w):
    p = os.path.join(ROOT, w.get("lore_file", "")) if w.get("lore_file") else None
    if p and os.path.exists(p):
        return {e["id"]: e for e in load(p)}
    return {}


def build_ctx(w, rd):
    ents = lore_entries(w)
    ctx = {k: w[k] for k in ("id", "name", "kind", "system", "habitat_word", "gen_voices", "batch", "chains_per", "rounds", "species", "stage") if k in w}
    ctx.setdefault("habitat_word", "world")
    if w.get("use_default_frame"):
        ctx["canon_text"] = open(os.path.join(HERE, "canon.md")).read()
    else:
        ctx["canon_text"] = FRAME.format(name=w["name"]["en"], kind=w["kind"])
    notes = w.get("notes", "")
    if w.get("lore_file"):
        if ents:
            txt = []
            for i in w.get("lore_ids", []):
                if i in ents: txt.append(f"[{i}] " + json.dumps({k: v for k, v in ents[i].items() if k not in ("sources", "source", "game_hook")}, ensure_ascii=False))
            if w["kind"] == "third_party": notes += "\n\nLORE TEXT (given facts; paraphrase, never copy):\n" + "\n".join(txt)
            elif txt: notes += "\n\nLORE TEXT for the filed third-party creature (paraphrase only):\n" + "\n".join(txt)
        else:
            notes += f"\n\n(The lore file {w['lore_file']} is not present in this checkout: use only the facts stated in the notes above and public first-principles science.)"
    ctx["notes"] = notes
    cres, cmap = [], {k: dict(v) for k, v in (w.get("cmap") or {}).items()}
    for c in w.get("creatures", []):
        c = dict(c)
        if c.get("lore_id"):  # All Tomorrows: name, brief and ids from the lore file
            e = ents.get(c["lore_id"])
            c["name"] = e["name"] if e else c["lore_id"]
            c["brief"] = ("Third-party easter egg, in our own words. Lore entry: " + json.dumps({k: e.get(k) for k in ("origin", "body_plan", "environment", "temperament_culture", "fate") if e.get(k)}, ensure_ascii=False)) if e else ""
            cmap[c["name"]] = {"id": "at_" + c["lore_id"].replace("-", "_"), "name": {"en": c["name"]}, "lore_ref": {"file": w["lore_file"], "id": c["lore_id"]}, "kind": "easter_egg"}
        cres.append({"name": c["name"], "brief": c.get("brief", "")})
    ctx["creatures"] = cres
    json.dump(ctx, open(os.path.join(rd, "ctx.json"), "w"), indent=1, ensure_ascii=False)
    json.dump(cmap, open(os.path.join(rd, "cmap.json"), "w"), indent=1, ensure_ascii=False)
    return ctx, cmap


# ---------------- world file from the chair ----------------
def add_refs(specs):
    """specs: CSL-ish dicts -> add as unverified to lore/references.json; returns ids."""
    rp = os.path.join(ROOT, "lore", "references.json")
    cur = load(rp); have = {r["id"] for r in cur}; ids = []
    for s in specs:
        if "id" not in s: s = dict(s, id=None)
        from import_got import csl_from_spec
        r = s if s.get("id") and s.get("title") and s.get("type") else csl_from_spec(s)
        r = {k: v for k, v in r.items() if k in ("id", "type", "title", "author", "issued", "container-title", "DOI", "ISBN", "URL", "x-status", "x-note")}
        if r.get("type") not in ("article-journal", "book", "chapter", "paper-conference", "thesis", "webpage", "report"): r["type"] = "article-journal"
        r["id"] = re.sub(r"[^a-z0-9_]", "", str(r["id"]).lower().replace("-", "_"))
        if not re.fullmatch(r"[a-z0-9_]+", r["id"] or "") or not r.get("title"): continue
        r["x-status"] = "unverified"; r["x-note"] = "cited by a council model from memory; not yet checked"
        if not isinstance(r.get("author", []), list): r.pop("author")
        if r["id"] not in have: cur.append(r); have.add(r["id"])
        ids.append(r["id"])
    dump(cur, rp)
    return ids


def write_world(w, rd):
    cf = os.path.join(rd, "chair_final.json")
    ch = load(cf)
    ref_ids = add_refs(ch.get("references") or [])
    known = {r["id"] for r in load(os.path.join(ROOT, "lore", "references.json"))}
    facts, seen = [], set()
    for i, f in enumerate(ch["facts"]):
        m = re.search(r"\d+", str(f.get("id", "")))
        fid = f"F{m.group()}" if m else f"F{i + 1}"
        if fid in seen: fid = f"F{max(int(x[1:]) for x in seen) + 1}"
        seen.add(fid)
        g = str(f.get("group", "planet")).lower()
        g = g if g in GROUPS else ("planet" if "body" not in g else "planet")
        nf = {"id": fid, "group": g, "claim": str(f.get("claim", "")).strip() or "(no claim)", "justification": str(f.get("justification", "")).strip() or "see the claim",
              "status": "retired" if f.get("status") == "retired" else "active", "provenance": {"council": "planet drafts + peer reviews + astrobio referee, merged by the chair (deepseek skeptic)"}}
        if isinstance(f.get("value"), (int, float, str)) and f.get("value") != "": nf["value"] = f["value"]
        if f.get("unit"): nf["unit"] = str(f["unit"])
        if f.get("consequences"): nf["consequences"] = [str(x) for x in f["consequences"] if x]
        rf = [r for r in (f.get("refs") or []) if isinstance(r, str) and r in known]
        if rf: nf["refs"] = rf
        facts.append(nf)
    sysd = ch.get("system") or {}
    ws = w["system"]
    system = {"star": str(sysd.get("star") or ws["star"]), "position": str(sysd.get("position") or ws["position"]), "distance_ly_from_sol": ws["distance_ly_from_sol"]}
    nm = ch.get("name") if isinstance(ch.get("name"), dict) and ch["name"].get("en") else w["name"]
    doc = {"schema": "cpore.world/1", "id": w["id"], "kind": w["kind"], "system": system, "name": nm, "status": "draft", "facts": facts,
           "changelog": [{"date": DATE, "who": "autoloop", "what": f"world canon drafted by the council chair from {len(facts)} facts (planet drafts, peer reviews, astrobio referee)"}]}
    if w.get("lore_source"): doc["lore_source"] = w["lore_source"]
    dump(doc, os.path.join(ROOT, "lore", "worlds", f"{w['id']}.json"))
    # planet_canon.md for the GoT prompts
    lines = [f"# {nm['en']}: world canon (council chair, {DATE})", ""]
    for f in facts:
        if f["status"] == "active":
            v = f" [{f['value']}{(' ' + f['unit']) if f.get('unit') else ''}]" if "value" in f else ""
            lines.append(f"- **{f['id']}** ({f['group']}) {f['claim']}{v}. {f['justification']}")
    open(os.path.join(rd, "planet_canon.md"), "w").write("\n".join(lines) + "\n")
    return len(facts)


# ---------------- import and repair ----------------
def import_graph(w, rd, graph, cmap, kind, run):
    mp = os.path.join(rd, f"cmap_{os.path.basename(os.path.dirname(graph))}.json")
    gk = set(load(graph).get("chains", {}))
    json.dump({k: v for k, v in cmap.items() if k in gk}, open(mp, "w"))
    rc = sh([PY, os.path.join(LORE, "import_got.py"), graph, "--world", w["id"], "--kind", kind, "--run", run, "--map", mp], env={})
    if rc: log(f"import_got FAILED (exit {rc}) for {graph}")
    return rc


def world_creature_files(wid):
    out = []
    for p in sorted(glob.glob(os.path.join(ROOT, "lore", "creatures", "*.json"))):
        c = load(p)
        if c.get("world") == wid: out.append((p, c))
    return out


def patch_profiles(w, rd, cmap):
    profs = {}
    for p in (os.path.join(rd, "got", "profiles.json"), os.path.join(rd, "got_extra", "profiles.json"), os.path.join(rd, "got", "species", "profiles.json")):
        if os.path.exists(p): profs.update(load(p))
    byid = {}
    for name, pr in profs.items():
        cid = (cmap.get(name) or {}).get("id") or slug(name)
        byid[cid] = pr
    n = 0
    for p, c in world_creature_files(w["id"]):
        pr = byid.get(c["id"])
        c["stage"] = w.get("stage", c.get("stage", "creature"))
        if not pr: dump(c, p); continue
        if pr.get("carcinised"): c["carcinised"] = True
        bp = pr.get("body_plan")
        if isinstance(bp, dict) and bp.get("symmetry") in ("bilateral", "radial", "biradial", "asymmetric", "spherical") and "body_plan" not in c:
            c["body_plan"] = {"symmetry": bp["symmetry"]}
            if isinstance(bp.get("arms"), int) and bp["arms"] >= 1: c["body_plan"]["arms"] = bp["arms"]
            if bp.get("origin"): c["body_plan"]["origin"] = str(bp["origin"])
        ni = c["niche"]
        if ni.get("habitat") == "to be written":
            ni["habitat"] = str(pr.get("habitat") or pr.get("niche_text") or "to be written"); ni["diet"] = str(pr.get("diet") or "to be written"); ni["active"] = str(pr.get("active") or "to be written")
            pre = [str(x) for x in (pr.get("predators") or []) if isinstance(x, str)]
            if pre: ni["predators"] = pre
            pry = [str(x) for x in (pr.get("prey") or []) if isinstance(x, str)]
            if pry: ni["prey"] = pry
        if c["body"] == "to be written" and pr.get("body"): c["body"] = str(pr["body"])
        if pr.get("temperament") and not c.get("temperament"): c["temperament"] = str(pr["temperament"])
        for k in ("secrets", "moments"):
            if isinstance(pr.get(k), list) and pr[k] and not c.get(k): c[k] = [str(x) for x in pr[k]]
        if pr.get("journal") and not c.get("journal") and isinstance(pr["journal"], list):
            c["journal"] = [{"en": str(x)} for x in pr["journal"]]
        n += 1; dump(c, p)
    return n


def link_carcinised():
    """Every carcinised creature gets a convergent relation (via 'carcinisation') to every other one, across worlds."""
    cs = [(p, load(p)) for p in sorted(glob.glob(os.path.join(ROOT, "lore", "creatures", "*.json")))]
    cs = [(p, c) for p, c in cs if c.get("carcinised")]
    for p, c in cs:
        have = {r["with"] for r in c.get("relations", []) if r.get("via") == "carcinisation"}
        add = [{"with": o["id"], "kind": "convergent", "via": "carcinisation", "note": "both converged on the crab body plan from unrelated lineages (Borradaile 1916; Keiler, Wirkner and Richter 2017; Wolfe, Luque and Bracken-Grissom 2021)"}
               for _, o in cs if o["id"] != c["id"] and o["id"] not in have]
        if add:
            c.setdefault("relations", []).extend(add)
            c["changelog"].append({"date": DATE, "who": "autoloop", "what": f"carcinisation links to {len(add)} creature(s)"}); dump(c, p)


def sanitize(w, log_=log):
    """Make the world's files pass validate.py: drop roots that do not exist, chains left without roots, bad relation vias."""
    wd = load(os.path.join(ROOT, "lore", "worlds", f"{w['id']}.json"))
    act = {f["id"] for f in wd["facts"] if f["status"] == "active"}
    fixed = 0
    for p, c in world_creature_files(w["id"]):
        keep = []
        for ch in c["chains"]:
            r = [x for x in ch.get("roots", []) if x in act]
            if len(r) != len(ch.get("roots", [])): fixed += 1
            if r:
                ch["roots"] = r; keep.append(ch)
            else:
                log_(f"sanitize: dropped chain {ch['id']} (no valid roots)")
        if not keep:
            log_(f"sanitize: removed creature {c['id']} (no chain with valid roots)"); os.remove(p); continue
        # renumber nothing: ids stay; but skill ids must stay unique (they do)
        c["chains"] = keep
        for rl in c.get("relations", []):
            v = rl.get("via", "")
            if v and re.fullmatch(r"F[0-9]+", v) and v not in act: del rl["via"]
        dump(c, p)
    return fixed


def repair_rejected(w=None, log_=log):
    """After refcheck: remove rejected refs everywhere; real-world facts left without refs are retired (and chains rooted only on them dropped)."""
    refs = {r["id"]: r for r in load(os.path.join(ROOT, "lore", "references.json"))}
    bad = {i for i, r in refs.items() if r.get("x-status") == "rejected"}
    if not bad: return 0
    n = 0
    # refcheck is global, so a reference cited by an EARLIER world can be rejected now: repair every world and every creature
    for wp in sorted(glob.glob(os.path.join(ROOT, "lore", "worlds", "*.json"))):
        wd = load(wp); ch = 0
        for f in wd["facts"]:
            if f.get("refs") and set(f["refs"]) & bad:
                f["refs"] = [r for r in f["refs"] if r not in bad]; ch += 1
                if not f["refs"]: del f["refs"]
            if wd["kind"] == "real" and f["status"] == "active" and not f.get("refs"):
                f["status"] = "retired"; ch += 1; log_(f"repair: retired {wd['id']}.{f['id']} (all references rejected)")
        if ch:
            wd["changelog"].append({"date": DATE, "who": "autoloop", "what": "removed rejected references; retired real facts left without references"}); dump(wd, wp); n += ch
    for p in sorted(glob.glob(os.path.join(ROOT, "lore", "creatures", "*.json"))):
        c = load(p); ch0 = False
        for ch in c["chains"]:
            for a in ch.get("plausibility", {}).get("analogues", []):
                if set(a.get("refs", [])) & bad:
                    a["refs"] = [r for r in a["refs"] if r not in bad]; ch0 = True
                    if not a["refs"]: del a["refs"]
        if ch0: n += 1; c["changelog"].append({"date": DATE, "who": "autoloop", "what": "removed rejected references from analogues"}); dump(c, p)
    for wp in glob.glob(os.path.join(ROOT, "lore", "worlds", "*.json")):
        sanitize({"id": os.path.basename(wp)[:-5]}, log_)
    return n


def validate():
    r = subprocess.run([PY, os.path.join(LORE, "validate.py")], cwd=ROOT, capture_output=True, text=True)
    return r.returncode, r.stdout


def stats(w):
    refs = {r["id"]: r.get("x-status") for r in load(os.path.join(ROOT, "lore", "references.json"))}
    cs = world_creature_files(w["id"])
    ver = {"plausible": 0, "fixable": 0, "implausible": 0, "unreviewed": 0}
    used, worst = set(), []
    for _, c in cs:
        for ch in c["chains"]:
            pl = ch.get("plausibility", {}); ver[pl.get("verdict", "unreviewed")] = ver.get(pl.get("verdict", "unreviewed"), 0) + 1
            for a in pl.get("analogues", []): used.update(a.get("refs", []))
            sc = pl.get("scores", {})
            if pl.get("verdict") in ("implausible", "fixable") or (sc and min(sc.values()) <= 4):
                worst.append((0 if pl.get("verdict") == "implausible" else 1 if pl.get("verdict") == "fixable" else 2, c["id"], ch["trait"], pl.get("verdict"), pl.get("summary", ""), sc))
    wp = os.path.join(ROOT, "lore", "worlds", f"{w['id']}.json")
    nf = 0
    if os.path.exists(wp):
        wd = load(wp)
        for f in wd["facts"]: used.update(f.get("refs", []))
        nf = len(wd["facts"])
    worst.sort(key=lambda x: (x[0], min(x[5].values()) if x[5] else 10))
    return {"facts": nf, "creatures": len(cs), "chains": sum(len(c["chains"]) for _, c in cs), "verdicts": ver,
            "refs_verified": sum(refs.get(i) == "verified" for i in used), "refs_rejected": sum(refs.get(i) == "rejected" for i in used),
            "refs_unverified": sum(refs.get(i) == "unverified" for i in used), "worst": worst[:5]}


# ---------------- one world ----------------
def process(w, args, opus_wait=False):
    wid = w["id"]; rd = os.path.join(RUNS, wid); os.makedirs(rd, exist_ok=True)
    LOG[0] = os.path.join(rd, "log.txt")
    sp = os.path.join(rd, "state.json"); st = load(sp) if os.path.exists(sp) else {"steps": {}}
    def mark(step, v): st["steps"][step] = v; json.dump(st, open(sp, "w"), indent=1)
    log(f"=== world {wid} ({w['kind']}) ===")
    ctx, cmap = build_ctx(w, rd)
    env = {"LORE_RUNS_DIR": rd, "LORE_CTX": os.path.join(rd, "ctx.json")}
    council = os.path.join(HERE, "council.py"); got = os.path.join(HERE, "got.py")
    cwd = HERE
    # 1 planet + chair
    wp = os.path.join(ROOT, "lore", "worlds", f"{wid}.json")
    if w.get("skip_planet"):
        shutil.copy(os.path.join(HERE, w["canon_file"]), os.path.join(rd, "planet_canon.md")); mark("planet", "skipped (approved canon)"); mark("chair", "skipped (approved canon)")
    else:
        if st["steps"].get("chair") != "ok":
            pd = os.path.join(rd, "planet")
            ok1 = retry("planet", lambda: sh([PY, council, "planet"], env, cwd), lambda: len(glob.glob(os.path.join(pd, "draft_*.md"))) >= 7 and all(not open(f).read().startswith("(failed)") for f in glob.glob(os.path.join(pd, "draft_*.md"))) and len(glob.glob(os.path.join(pd, "review_*.md"))) >= 7, tries=6)
            if not ok1:
                nd = len([f for f in glob.glob(os.path.join(pd, "draft_*.md")) if not open(f).read().startswith("(failed)")])
                if nd < 4: mark("planet", f"FAILED ({nd} drafts)"); return finish(w, st, mark, args, "planet failed")
            mark("planet", "ok" if ok1 else "partial")
            retry("planet-astrobio", lambda: sh([PY, council, "planet-astrobio"], env, cwd), lambda: os.path.exists(os.path.join(pd, "review_astrobio.md")), tries=5)
            okc = retry("chair", lambda: sh([PY, council, "chair"], env, cwd), lambda: os.path.exists(os.path.join(rd, "chair_final.json")), tries=5)
            if not okc: mark("chair", "FAILED"); return finish(w, st, mark, args, "chair failed")
            mark("chair", "ok")
        if not os.path.exists(wp) or st["steps"].get("world") != "ok":
            try:
                n = write_world(w, rd); mark("world", "ok"); log(f"world file written: {n} facts")
            except Exception as e:
                log(f"world file FAILED: {e!r}"); mark("world", f"FAILED {e!r}"); return finish(w, st, mark, args, "world file failed")
    if w.get("seed_refs"): add_refs(w["seed_refs"])
    # 2 GoT
    gdir = os.path.join(rd, "got")
    if ctx["creatures"]:
        if st["steps"].get("got") not in ("ok", "partial"):
            og = w.get("opus_got")
            if og and os.path.exists(os.path.join(og, "graph.json")):
                shutil.copytree(og, gdir, dirs_exist_ok=True); mark("got", "ok"); log("imported Opus's island GoT run")
            elif og and opus_running() and not args.no_wait_opus:
                mark("got", "deferred"); log("Opus's island GoT is still running: deferred")
                return finish(w, st, mark, args, "got deferred", commit=False)
            else:
                ok = retry("got", lambda: sh([PY, got], env, cwd), lambda: os.path.exists(os.path.join(gdir, "graph.json")), tries=5)
                mark("got", "ok" if ok else "FAILED")
        if st["steps"].get("got") in ("ok", "partial") and not os.path.exists(os.path.join(gdir, "profiles.json")):
            retry("profiles", lambda: sh([PY, got, "profiles"], env, cwd), lambda: os.path.exists(os.path.join(gdir, "profiles.json")), tries=3)
        if w.get("extra_creatures") and st["steps"].get("got_extra") != "ok":
            xctx = dict(ctx); xctx["creatures"] = w["extra_creatures"]; xctx["got_dir"] = "got_extra"; xctx["batch"] = 1
            json.dump(xctx, open(os.path.join(rd, "ctx_extra.json"), "w"))
            xenv = dict(env, LORE_CTX=os.path.join(rd, "ctx_extra.json"))
            ok = retry("got_extra", lambda: sh([PY, got], xenv, cwd), lambda: os.path.exists(os.path.join(rd, "got_extra", "graph.json")), tries=4)
            if ok: sh([PY, got, "profiles"], xenv, cwd)
            mark("got_extra", "ok" if ok else "FAILED")
    else:
        mark("got", "none (species-only world)")
    # 3 species
    if ctx.get("species") and st["steps"].get("species") != "ok":
        if st["steps"].get("species") == "redo":  # seeds were added: regenerate graph.json (finished seeds are cached)
            try: os.remove(os.path.join(gdir, "species", "graph.json"))
            except OSError: pass
        ok = retry("species", lambda: sh([PY, got, "species"], env, cwd), lambda: os.path.exists(os.path.join(gdir, "species", "graph.json")), tries=5)
        mark("species", "ok" if ok else "FAILED")
    # 4 import
    run = f"autoloop-{DATE}"
    if st["steps"].get("got") == "ok" or st["steps"].get("got") == "partial":
        import_graph(w, rd, os.path.join(gdir, "graph.json"), cmap, w.get("creature_kind", "native"), run)
    if os.path.exists(os.path.join(rd, "got_extra", "graph.json")):
        import_graph(w, rd, os.path.join(rd, "got_extra", "graph.json"), cmap, "native", run)
    if os.path.exists(os.path.join(gdir, "species", "graph.json")):
        import_graph(w, rd, os.path.join(gdir, "species", "graph.json"), cmap, "new", run)
    # profiles of extra creatures live in got_extra
    patch_profiles(w, rd, cmap)
    for p, c in world_creature_files(wid):  # per-creature kind overrides (easter eggs, cameos)
        for name, m in cmap.items():
            if (m.get("id") or slug(name)) == c["id"] and m.get("kind") and c.get("kind") != m["kind"]:
                c["kind"] = m["kind"]; dump(c, p)
    sanitize(w)
    link_carcinised()
    # 5 validate, render, refcheck
    code, out = validate()
    if code: log("validate errors:\n" + out[-2500:])
    for a in range(3):
        if sh([PY, os.path.join(LORE, "refcheck.py")]) == 0: break
        time.sleep(60)
    repair_rejected(w)
    code, out = validate()
    mark("validate", "ok" if code == 0 else "ERRORS: " + out.strip().splitlines()[-1] if out.strip() else "ERRORS")
    if code: log("validate errors after repair:\n" + out[-2500:])
    sh([PY, os.path.join(LORE, "render.py")])
    return finish(w, st, mark, args, "done")


def opus_running():
    r = subprocess.run(["pgrep", "-f", "got.py"], capture_output=True, text=True)
    mine = str(os.getpid())
    for pid in r.stdout.split():
        try:
            cwd = os.readlink(f"/proc/{pid}/cwd")
            if "lore-council" in cwd and "lore-run" not in cwd: return True
        except OSError: pass
    return False


RESULTS = {}


def finish(w, st, mark, args, why, commit=True):
    wid = w["id"]
    s = stats(w) if os.path.exists(os.path.join(ROOT, "lore", "worlds", f"{wid}.json")) else {"facts": 0, "creatures": 0, "chains": 0, "verdicts": {}, "refs_verified": 0, "refs_rejected": 0, "refs_unverified": 0, "worst": []}
    fails = {k: v for k, v in st["steps"].items() if str(v).startswith(("FAILED", "ERRORS", "deferred"))}
    s["failures"] = fails; s["why"] = why
    RESULTS[wid] = s
    json.dump(s, open(os.path.join(RUNS, wid, "summary.json"), "w"), indent=1)
    log(f"world {wid}: {why}; {s['creatures']} creatures, {s['chains']} chains, failures {fails or 'none'}")
    write_summary()
    if commit and not args.no_commit and not str(st["steps"].get("got")) == "deferred":
        git("add", "lore", "docs/creatures", "docs/lore", "tools/lore")
        r = git("commit", "-m", f"Lore: world {wid} ({s['creatures']} creatures)\n\n{COAUTHOR}")
        log("commit: " + (r.stdout.strip().splitlines()[0] if r.stdout.strip() else r.stderr.strip()[:200]))
    return s


def write_summary():
    seed = load(os.path.join(HERE, "worlds_seed.json"))
    rows, worst = [], []
    for w in seed:
        p = os.path.join(RUNS, w["id"], "summary.json")
        if not os.path.exists(p): rows.append(f"| {w['id']} | {w['kind']} | {'PAUSED (queued)' if w.get('paused') else 'pending'} | | | | | |"); continue
        s = load(p); v = s.get("verdicts", {})
        vs = f"{v.get('plausible', 0)}/{v.get('fixable', 0)}/{v.get('implausible', 0)}/{v.get('unreviewed', 0)}"
        f = "; ".join(f"{k}: {str(x)[:40]}" for k, x in (s.get("failures") or {}).items()) or "none"
        rows.append(f"| {w['id']} | {w['kind']} | {s['facts']} | {s['creatures']} | {s['chains']} | {vs} | {s['refs_verified']}/{s['refs_rejected']}/{s['refs_unverified']} | {f} |")
        for x in s.get("worst", [])[:3]:
            worst.append(f"- **{w['id']} / {x[1]}**: {x[2]} ({x[3]}) {x[4][:220]}")
    txt = ["# Lore autoloop: summary", "", f"Generated by `tools/lore/council/autoloop.py` ({DATE}). Worlds marked PAUSED are queued in worlds_seed.json (`paused: true`) by owner decision; run them later with `--include-paused`. Verdict counts are plausible/fixable/implausible/unreviewed chains (astrobio referee); references are verified/rejected/unverified among those cited by the world.", "",
           "| world | kind | facts | creatures | chains | verdicts p/f/i/u | refs v/r/u | failures |", "|---|---|---|---|---|---|---|---|"] + rows
    txt += ["", "## Worst problems the judges found", ""] + (worst or ["(none recorded)"]) + [""]
    open(os.path.join(ROOT, "docs", "lore", "AUTOLOOP.md"), "w").write("\n".join(txt))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only"); ap.add_argument("--max-worlds", type=int, default=0)
    ap.add_argument("--no-commit", action="store_true"); ap.add_argument("--no-wait-opus", action="store_true")
    ap.add_argument("--include-paused", action="store_true", help="also run worlds marked paused in worlds_seed.json")
    ap.add_argument("--retry-failed", action="store_true", help="also re-run worlds whose summary lists failed steps (resumes at the failed step)")
    args = ap.parse_args()
    os.makedirs(RUNS, exist_ok=True)
    seed = load(os.path.join(HERE, "worlds_seed.json"))
    if args.only: seed = [w for w in seed if w["id"] == args.only]
    elif not args.include_paused: seed = [w for w in seed if not w.get("paused")]  # owner pause: queued worlds stay in worlds_seed.json with "paused": true
    todo = []
    for w in seed:
        sp = os.path.join(RUNS, w["id"], "summary.json")
        if os.path.exists(sp) and not args.only:
            sm = load(sp)
            if not str(sm.get("why", "")).endswith("deferred") and not (args.retry_failed and (sm.get("failures") or sm.get("why") != "done")): continue
        todo.append(w)
    if args.max_worlds: todo = todo[:args.max_worlds]
    deferred = []
    for w in todo:
        try:
            s = process(w, args)
            if "deferred" in s.get("why", ""): deferred.append(w)
        except Exception as e:
            import traceback; LOG[0] and open(LOG[0], "a").write(traceback.format_exc()); log(f"world {w['id']} CRASHED: {e!r}")
    for w in deferred:  # the island: wait for Opus's run (up to 8 h), then run our own
        t0 = time.time()
        while opus_running() and time.time() - t0 < 8 * 3600 and not os.path.exists(os.path.join(w["opus_got"], "graph.json")): time.sleep(300)
        try: process(w, args)
        except Exception as e: log(f"world {w['id']} CRASHED: {e!r}")
    write_summary()
    if not args.no_commit:
        git("add", "docs/lore"); git("commit", "-m", f"Lore autoloop: summary table\n\n{COAUTHOR}")


if __name__ == "__main__":
    main()
