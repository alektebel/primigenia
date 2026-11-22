#!/usr/bin/env python3
"""Owner questions that pop up inside the game (docs/godot/DEVTOOLS.md, primigenia.questions/1).

    questions.py add --json <file|-|'{...}'>                  add questions from JSON (one object, a list, or a queue file)
    questions.py add --id ID --text T [--context C] [--option "label|desc"]... [--recommend N] [--free-text]
                     [--when now|on_event:X|after_minutes:N] [--scenario S] [--opts k=v ...] [--pos X Z]
    questions.py list [--all]                                   pending (and with --all the answered)
    questions.py export-md [--all]                              a Markdown table
    questions.py pull-answers [--json]                          the answers, for the tracker and DESIGN.md
    questions.py seed-from-tracker <export.json>                open tracker decisions and tests become questions

Queue: <repo>/feedback/questions/pending.json ({"schema": "primigenia.questions/1", "questions": [...]}), answers appended to
answers.jsonl next to it (git-ignored); fallback ~/.local/share/godot/app_userdata/Primigenia/feedback/questions; --dir overrides.
Same files as godot/devtools/questions/question_store.gd (keep them in sync).

Tracker export for seed-from-tracker: {"tests": [{"id", "title", "status", "detail"?}], "decisions": [{"id", "title", "status",
"context"?, "options"?: [{"label", "desc"?, "recommended"?}]}]}. Only open tests (status Open/Pending/Failed) and open decisions are used.
"""
import argparse
import json
import os
import sys

SCHEMA = "primigenia.questions/1"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OPEN = {"open", "pending", "failed", "new", ""}


def qdir(arg=None):
    if arg:
        return arg
    repo = os.path.join(REPO, "feedback", "questions")
    if os.path.isdir(repo) or os.path.isdir(os.path.dirname(repo)):
        return repo
    return os.path.expanduser("~/.local/share/godot/app_userdata/Primigenia/feedback/questions")


def normalize(q):
    if not isinstance(q, dict) or not str(q.get("id", "")) or not str(q.get("text", "")):
        return None
    opts = []
    for o in q.get("options", []):
        if isinstance(o, str) and o:
            o = {"label": o}
        if isinstance(o, dict) and o.get("label"):
            opts.append({"label": str(o["label"]), "desc": str(o.get("desc", o.get("description", ""))), "recommended": bool(o.get("recommended", False))})
    opts = opts[:4]
    free = bool(q.get("allow_free_text", False))
    if len(opts) < 2 and not free:
        return None
    out = {"id": str(q["id"]), "text": str(q["text"]), "context": str(q.get("context", "")), "options": opts,
           "allow_free_text": free}
    if q.get("when"):
        out["when"] = str(q["when"])
    if isinstance(q.get("where"), dict) and q["where"]:
        out["where"] = q["where"]
    return out


def load_pending(base):
    p = os.path.join(base, "pending.json")
    if not os.path.isfile(p):
        return []
    with open(p, encoding="utf-8") as f:
        v = json.load(f)
    if v.get("schema", v.get("format")) != SCHEMA:
        return []
    return [n for n in (normalize(q) for q in v.get("questions", [])) if n]


def save_pending(base, qs):
    os.makedirs(base, exist_ok=True)
    with open(os.path.join(base, "pending.json"), "w", encoding="utf-8") as f:
        json.dump({"schema": SCHEMA, "questions": qs}, f, indent=1, ensure_ascii=False)
        f.write("\n")


def load_answers(base):
    p = os.path.join(base, "answers.jsonl")
    out = []
    if os.path.isfile(p):
        with open(p, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if ln:
                    try:
                        v = json.loads(ln)
                    except ValueError:
                        continue
                    if isinstance(v, dict) and v.get("id"):
                        out.append(v)
    return out


def add_questions(base, new):
    """Adds or replaces (by id) the usable questions; returns (added ids, skipped count)."""
    cur = load_pending(base)
    ids = []
    skipped = 0
    for q in new:
        n = normalize(q)
        if not n:
            skipped += 1
            continue
        cur = [c for c in cur if c["id"] != n["id"]]
        cur.append(n)
        ids.append(n["id"])
    save_pending(base, cur)
    return ids, skipped


def from_json_arg(arg):
    if arg == "-":
        text = sys.stdin.read()
    elif os.path.isfile(arg):
        with open(arg, encoding="utf-8") as f:
            text = f.read()
    else:
        text = arg
    v = json.loads(text)
    if isinstance(v, dict) and "questions" in v:
        return v["questions"]
    return v if isinstance(v, list) else [v]


def seed_from_tracker(data):
    qs = []
    for t in data.get("tests", []):
        if str(t.get("status", "")).lower() not in OPEN:
            continue
        qs.append({"id": "q-%s" % t["id"], "text": "Did \"%s\" pass?" % t.get("title", t["id"]), "context": t.get("detail", "") or "Tracker test %s" % t["id"],
                   "options": [{"label": "Yes", "desc": "it passed", "recommended": False}, {"label": "No", "desc": "it failed: add a note"},
                               {"label": "Partly", "desc": "some of it: add a note"}], "allow_free_text": True})
    for d in data.get("decisions", []):
        if str(d.get("status", "")).lower() not in OPEN:
            continue
        opts = d.get("options") or [{"label": "Yes"}, {"label": "No"}]
        qs.append({"id": "q-%s" % d["id"], "text": d.get("title", d["id"]), "context": d.get("context", "") or "Tracker decision %s" % d["id"],
                   "options": opts, "allow_free_text": True})
    return qs


def answer_text(a):
    s = a.get("label") or ""
    if a.get("text"):
        s = (s + ": " if s else "") + a["text"]
    return s or "(no answer)"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", help="questions folder")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("add")
    p.add_argument("--json")
    p.add_argument("--id")
    p.add_argument("--text")
    p.add_argument("--context", default="")
    p.add_argument("--option", action="append", default=[])
    p.add_argument("--recommend", type=int, default=0)
    p.add_argument("--free-text", action="store_true")
    p.add_argument("--when", default="")
    p.add_argument("--scenario")
    p.add_argument("--opts", nargs="*", default=[])
    p.add_argument("--pos", nargs=2)
    for name in ("list", "export-md"):
        sub.add_parser(name).add_argument("--all", action="store_true")
    sub.add_parser("pull-answers").add_argument("--json", action="store_true")
    sub.add_parser("seed-from-tracker").add_argument("file")
    a = ap.parse_args(argv)
    base = qdir(a.dir)
    answers = load_answers(base)
    answered = {x["id"] for x in answers}
    if a.cmd == "add":
        if a.json:
            new = from_json_arg(a.json)
        else:
            if not a.id or not a.text:
                ap.error("add needs --json or --id and --text")
            opts = []
            for i, o in enumerate(a.option):
                label, _, desc = o.partition("|")
                opts.append({"label": label, "desc": desc, "recommended": a.recommend == i + 1})
            where = {}
            if a.scenario:
                where["scenario"] = a.scenario
            if a.opts:
                where["opts"] = dict(kv.split("=", 1) for kv in a.opts)
            if a.pos:
                where["pos"] = [float(x) for x in a.pos]
            new = [{"id": a.id, "text": a.text, "context": a.context, "options": opts, "allow_free_text": a.free_text, "when": a.when, "where": where}]
        ids, skipped = add_questions(base, new)
        print("added %d question(s): %s%s" % (len(ids), " ".join(ids), " (skipped %d unusable)" % skipped if skipped else ""))
        return 0 if ids else 1
    if a.cmd == "seed-from-tracker":
        with open(a.file, encoding="utf-8") as f:
            qs = seed_from_tracker(json.load(f))
        qs = [q for q in qs if q["id"] not in answered]
        ids, skipped = add_questions(base, qs)
        print("seeded %d question(s) from the tracker: %s" % (len(ids), " ".join(ids)))
        return 0
    pend = [q for q in load_pending(base) if q["id"] not in answered]
    if a.cmd == "list":
        for q in pend:
            print("#%s  %s%s" % (q["id"], q["text"], "  [%s]" % q["when"] if q.get("when") else ""))
        if a.all:
            for x in answers:
                print("answered #%s: %s" % (x["id"], answer_text(x)))
        if not pend and not (a.all and answers):
            print("no pending questions")
        return 0
    if a.cmd == "export-md":
        print("| id | question | answer |\n|---|---|---|")
        for q in pend:
            print("| %s | %s | pending |" % (q["id"], q["text"].replace("|", "/")))
        if a.all:
            texts = {q["id"]: q["text"] for q in load_pending(base)}
            for x in answers:
                print("| %s | %s | %s |" % (x["id"], texts.get(x["id"], "").replace("|", "/"), answer_text(x).replace("|", "/")))
        return 0
    if a.cmd == "pull-answers":
        latest = {}
        for x in answers:
            latest[x["id"]] = x
        if a.json:
            print(json.dumps(list(latest.values()), indent=1, ensure_ascii=False))
            return 0
        texts = {q["id"]: q["text"] for q in load_pending(base)}
        if not latest:
            print("no answers yet")
        for i, x in latest.items():
            extra = []
            if x.get("note"):
                extra.append("note %s" % x["note"])
            if x.get("options"):
                extra.append("opts " + " ".join("%s=%s" % kv for kv in x["options"].items()))
            if x.get("screenshot"):
                extra.append("shot " + x["screenshot"])
            print("%s  %s -> %s  (tick %s%s)" % (i, texts.get(i, ""), answer_text(x), x.get("tick", 0), "; " + "; ".join(extra) if extra else ""))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
