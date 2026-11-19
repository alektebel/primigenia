#!/usr/bin/env python3
"""Convert the council's GoT output (got/graph.json + score files) into lore/creatures/<id>.json drafts.

  python3 tools/lore/import_got.py PATH/got/graph.json --world ID [--kind native|easter_egg|cameo|new] [--root DIR] [--run NAME] [--date YYYY-MM-DD] [--dry-run]

Score files (3_score_r<round>_<Creature>_<judge>.json, next to graph.json) give the plausibility block:
the astrobio score becomes the verdict (>=7 plausible, 5-6 fixable, <5 implausible), the other judges' scores go to `scores`.
Never overwrites a creature whose status is reviewed or canon; drafts are merged by chain trait.
"""
import argparse, datetime, glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lorelib import ROOT, load, dump, slug

ROLES = {"Basic", "Engage", "Poke", "Control", "Defence", "Signature", "Passive", "Social"}
KINDS = {"predation", "prey", "convergent", "opposite", "symbiosis", "mimicry", "rivalry", "counter", "cousin"}
KIND_MAP = {"teaching": "counter"}


def tnorm(t):
    return re.sub(r"[^a-z0-9]+", " ", t.lower()).strip()


def load_scores(gdir, name):
    """-> {judge: [items]} from the highest round available for this creature."""
    best = {}
    for p in glob.glob(os.path.join(gdir, f"3_score_r*_{name.replace(' ', '_')}_*.json")):
        m = re.match(r"3_score_r(\d+)_(.+)_([a-z]+)\.json$", os.path.basename(p))
        if not m: continue
        rnd, judge = int(m.group(1)), m.group(3)
        if judge not in best or rnd > best[judge][0]:
            try: items = json.load(open(p, encoding="utf-8"))
            except ValueError: continue
            if isinstance(items, list): best[judge] = (rnd, items)
    return {j: v[1] for j, v in best.items()}


def score_for(scores, judge, chain, idx, n):
    items = scores.get(judge) or []
    for it in items:
        if isinstance(it, dict) and tnorm(str(it.get("trait", ""))) == tnorm(chain["trait"]): return it
    if len(items) == n and isinstance(items[idx], dict): return items[idx]
    return None


def plausibility(scores, chain, idx, n, run, date):
    sc = {}
    for j in sorted(scores):
        it = score_for(scores, j, chain, idx, n)
        if it and isinstance(it.get("score"), (int, float)): sc[j] = max(1, min(10, int(it["score"])))
    a = score_for(scores, "astrobio", chain, idx, n)
    if not a or not isinstance(a.get("score"), (int, float)):
        p = {"verdict": "unreviewed", "judge": "none", "date": date}
        if sc: p["scores"] = sc
        return p
    s = int(a["score"])
    p = {"verdict": "plausible" if s >= 7 else "fixable" if s >= 5 else "implausible", "judge": f"astrobio/{run}", "date": date}
    if a.get("fix"): p["summary"] = str(a["fix"]); p["fixes"] = [str(a["fix"])]
    if a.get("analogue"): p["analogues"] = [{"organism": str(a["analogue"]), "mechanism": "as named by the judge; no mechanism or reference recorded"}]
    if sc: p["scores"] = sc
    return p


def ref_id(spec):
    """CSL id author_year_shortword from a model-written reference spec {author, year, title, venue}."""
    au = re.sub(r"[^a-z]", "", slug(str(spec.get("author", "anon")).split(",")[0].split(" and ")[0].split("&")[0]))[:20] or "anon"
    words = [w for w in re.findall(r"[a-z]+", slug(str(spec.get("title", ""))).replace("_", " ")) if len(w) > 3 and w not in ("with", "from", "their", "that", "this", "the")]
    return f"{au}_{spec.get('year', 'nd')}_{words[0] if words else 'work'}"


def csl_from_spec(spec):
    fam, _, giv = str(spec.get("author", "")).partition(",")
    r = {"id": ref_id(spec), "type": "book" if re.search(r"press|books|publisher|textbook|\bed\.", str(spec.get("venue", "")), re.I) else "article-journal",
         "title": str(spec.get("title", "")).strip(), "x-status": "unverified", "x-note": "cited by a council model from memory; not yet checked"}
    if fam.strip(): r["author"] = [{"family": fam.strip(), **({"given": giv.strip()} if giv.strip() else {})}]
    try: r["issued"] = {"date-parts": [[int(spec["year"])]]}
    except (KeyError, ValueError, TypeError): pass
    if spec.get("venue"): r["container-title"] = str(spec["venue"])
    return r


def chain_refs(ch, refs_out):
    """-> [csl ids] for the chain's 'references' (and a judge's 'reference' string is handled elsewhere); new CSL entries go to refs_out."""
    ids = []
    for spec in ch.get("references") or []:
        if isinstance(spec, dict) and spec.get("title") and spec.get("author"):
            r = csl_from_spec(spec)
            if r["title"]:
                refs_out.setdefault(r["id"], r); ids.append(r["id"])
    return ids


def convert_chain(cid, n, ch, scores, idx, total, run, date, refs_out=None):
    sk = ch.get("skill") or {}
    sname = str(sk.get("name") or f"skill {n}")
    role = sk.get("role") if sk.get("role") in ROLES else "Passive"
    j = ch.get("journal")
    jr = j if isinstance(j, dict) and "en" in j else {"en": str(j or "")}
    out = {"id": f"{cid}.c{n}", "trait": str(ch["trait"]),
           "links": [str(x) for x in (ch.get("links") or [])][:5] or ["(no links recorded)"],
           "roots": [r for r in (ch.get("roots") or []) if re.fullmatch(r"F[0-9]+", str(r))] or [],
           "skill": {"id": f"{cid}.{slug(sname) or 'skill_' + str(n)}", "name": {"en": sname}, "role": role, "effect": str(sk.get("effect", "")), "numbers": {}},
           "weakness": str(ch.get("weakness", "")),
           "observe": [str(x) for x in (ch.get("observe") or [])][:4] or ["(nothing recorded)"],
           "journal": jr,
           "plausibility": plausibility(scores, ch, idx, total, run, date)}
    rids = chain_refs(ch, refs_out if refs_out is not None else {})
    if rids:
        pl = out["plausibility"]
        pl.setdefault("analogues", []).append({"organism": "real biology behind this chain", "mechanism": "see the cited works; chain wording is the council's own", "refs": rids})
    if ch.get("from"): out["provenance"] = {"council_run": run, "by": [str(x) for x in ch["from"]]}
    return out


def convert_relations(name, edges, known):
    out = []
    for e in edges:
        a, b = e.get("a", ""), e.get("b", "")
        if name not in (a, b): continue
        other = b if a == name else a
        kind = KIND_MAP.get(e.get("kind"), e.get("kind"))
        note = str(e.get("note", ""))
        if kind not in KINDS: note = f"(council kind '{e.get('kind')}') {note}"; kind = "cousin"
        r = {"with": known.get(other, other), "kind": kind, "note": note}
        if e.get("via"): r["via"] = str(e["via"])
        out.append(r)
    return out


def merge(existing, new, date, run):
    """Merge an imported draft into an existing draft by chain trait. Returns (merged, summary)."""
    m = json.loads(json.dumps(existing))
    traits = {tnorm(c["trait"]): c for c in m["chains"]}
    nums = [int(c["id"].rsplit(".c", 1)[1]) for c in m["chains"]]
    skills = {c["skill"]["id"] for c in m["chains"]}
    added = updated = 0
    for c in new["chains"]:
        old = traits.get(tnorm(c["trait"]))
        if old:
            if old["plausibility"]["verdict"] == "unreviewed" and c["plausibility"]["verdict"] != "unreviewed":
                old["plausibility"] = c["plausibility"]; updated += 1
            by = sorted(set(old.get("provenance", {}).get("by", [])) | set(c.get("provenance", {}).get("by", [])))
            if by: old["provenance"] = {**old.get("provenance", {}), "by": by}
            continue
        k = max(nums, default=0) + 1; nums.append(k)
        c = json.loads(json.dumps(c)); c["id"] = f"{m['id']}.c{k}"
        base, i = c["skill"]["id"], 2
        while c["skill"]["id"] in skills: c["skill"]["id"] = f"{base}_{i}"; i += 1
        skills.add(c["skill"]["id"]); m["chains"].append(c); added += 1
    have = {(r["with"], r["kind"]) for r in m.get("relations", [])}
    rel_new = [r for r in new.get("relations", []) if (r["with"], r["kind"]) not in have]
    if rel_new: m.setdefault("relations", []).extend(rel_new)
    m["changelog"].append({"date": date, "who": "import_got", "what": f"merged run {run}: {added} chain(s) added, {updated} plausibility block(s) filled, {len(rel_new)} relation(s) added"})
    return m, (added, updated, len(rel_new))


def build(graph, gdir, run, date, world, kind="native", cmap=None, refs_out=None):
    """cmap: {council name: {id, name (str or i18n), aliases, lore_ref}} overrides ids and display names."""
    cmap = cmap or {}
    chains, g = graph.get("chains", {}), graph.get("graph")
    edges = [e for e in (g.get("edges", []) if isinstance(g, dict) else g if isinstance(g, list) else []) if isinstance(e, dict)]
    known = {n: (cmap.get(n) or {}).get("id") or slug(n) for n in chains}
    for n, m in cmap.items():
        known.setdefault(n, m.get("id") or slug(n))
    out = {}
    for name, chs in chains.items():
        cid = known[name]
        if not cid or not chs: continue
        scores = load_scores(gdir, name)
        cs = [convert_chain(cid, i + 1, ch, scores, i, len(chs), run, date, refs_out) for i, ch in enumerate(chs) if isinstance(ch, dict) and ch.get("trait")]
        seen = set()
        for c in cs:  # keep skill ids unique inside the creature
            base, i = c["skill"]["id"], 2
            while c["skill"]["id"] in seen: c["skill"]["id"] = f"{base}_{i}"; i += 1
            seen.add(c["skill"]["id"])
        by = sorted({b for ch in chs if isinstance(ch, dict) for b in (ch.get("from") or [])})
        m = cmap.get(name) or {}
        nm = m.get("name") or name
        doc = {"schema": "cpore.creature/1", "id": cid, "name": nm if isinstance(nm, dict) else {"en": nm}, "world": world, "kind": kind, "status": "draft", "stage": "creature",
               "niche": {"habitat": "to be written", "diet": "to be written", "active": "to be written", "predators": []},
               "body": "to be written", "chains": cs, "relations": convert_relations(name, edges, known),
               "provenance": {"council_run": run, **({"by": by} if by else {})},
               "changelog": [{"date": date, "who": "import_got", "what": f"imported from council run {run}"}]}
        if not doc["relations"]: del doc["relations"]
        if m.get("aliases"): doc["aliases"] = list(m["aliases"])
        if m.get("lore_ref"): doc["lore_ref"] = m["lore_ref"]
        out[cid] = doc
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("graph")
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--world", required=True, help="world id the creatures live in (lore/worlds/<id>.json)")
    ap.add_argument("--kind", default="native", choices=["native", "easter_egg", "cameo", "new"])
    ap.add_argument("--run", default=None)
    ap.add_argument("--map", default=None, help="json {council name: {id, name, aliases, lore_ref}} overriding ids/names")
    ap.add_argument("--refs", default=None, help="references.json to add the chains' cited works to (as unverified); default lore/references.json of --root")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    gdir = os.path.dirname(os.path.abspath(a.graph))
    run = a.run or f"got-{a.date}"
    new_refs = {}
    docs = build(load(a.graph), gdir, run, a.date, a.world, a.kind, load(a.map) if a.map else None, new_refs)
    cdir = os.path.join(a.root, "lore", "creatures")
    for cid, doc in sorted(docs.items()):
        p = os.path.join(cdir, f"{cid}.json")
        if os.path.exists(p):
            ex = load(p)
            if ex.get("world") != a.world:
                print(f"{cid}: skipped (exists in world '{ex.get('world')}', not '{a.world}')"); continue
            if ex.get("status") != "draft":
                print(f"{cid}: skipped (status {ex.get('status')} is never overwritten)"); continue
            doc, (ad, up, rl) = merge(ex, doc, a.date, run)
            msg = f"merged ({ad} chains added, {up} plausibility filled, {rl} relations added)"
        else:
            msg = f"created ({len(doc['chains'])} chains)"
        print(f"{cid}: {msg}")
        if not a.dry_run:
            os.makedirs(cdir, exist_ok=True); dump(doc, p)
    if new_refs and not a.dry_run:
        rp = a.refs or os.path.join(a.root, "lore", "references.json")
        cur = load(rp) if os.path.exists(rp) else []
        have = {r["id"] for r in cur}
        add = [r for i, r in sorted(new_refs.items()) if i not in have]
        if add: dump(cur + add, rp); print(f"references: {len(add)} unverified entr{'y' if len(add) == 1 else 'ies'} added")


if __name__ == "__main__":
    main()
