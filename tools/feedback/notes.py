#!/usr/bin/env python3
"""Read and close the in-game notes the owner leaves in flag mode (docs/godot/DEVTOOLS.md, primigenia.note/1).

    notes.py list [--all]            open notes, newest first (--all: with done ones)
    notes.py show <id>               the full note.json
    notes.py done <id> "<fix>"       mark a note done and record the fixing commit
    notes.py export-md [--all]       a Markdown table for STATUS.md and the tracker

Notes live in <repo>/feedback/notes (git-ignored), else ~/.local/share/godot/app_userdata/Primigenia/feedback/notes;
--dir overrides. Each note is <stamp>-<id>/note.json next to screenshot.jpg, crop.jpg and scenario.json.
Same file format as godot/devtools/notes/note_store.gd (keep them in sync).
"""
import argparse
import json
import os
import sys

FORMAT = "primigenia.note/1"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def notes_dir(arg):
    if arg:
        return arg
    repo = os.path.join(REPO, "feedback", "notes")
    if os.path.isdir(repo):
        return repo
    return os.path.expanduser("~/.local/share/godot/app_userdata/Primigenia/feedback/notes")


def load(base):
    out = []
    if not os.path.isdir(base):
        return out
    for sub in sorted(os.listdir(base)):
        p = os.path.join(base, sub, "note.json")
        if os.path.isfile(p):
            with open(p, encoding="utf-8") as f:
                n = json.load(f)
            if n.get("format") == FORMAT:
                n["_dir"] = os.path.join(base, sub)
                out.append(n)
    out.sort(key=lambda n: (n["stamp"], n["id"]), reverse=True)
    return out


def line(n):
    tags = ",".join(n["tags"]) or "-"
    t = n["target"]
    return "#%s [%s %d] %s (%s %s)" % (n["id"], tags, n["severity"], n["text"], t["kind"], t["name"])


def find(base, ident):
    hits = [n for n in load(base) if n["id"] == ident or (len(ident) >= 3 and n["id"].startswith(ident))]
    return hits[0] if hits else None


def rewrite_index(base):
    rows = []
    for n in reversed(load(base)):
        rows.append(json.dumps({"id": n["id"], "stamp": n["stamp"], "text": n["text"], "tags": n["tags"], "severity": n["severity"],
                                "kind": n["target"]["kind"], "target": n["target"]["name"], "status": n["status"]}))
    with open(os.path.join(base, "index.jsonl"), "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + ("\n" if rows else ""))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", help="notes folder")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("list", "export-md"):
        p = sub.add_parser(name)
        p.add_argument("--all", action="store_true")
    sub.add_parser("show").add_argument("id")
    d = sub.add_parser("done")
    d.add_argument("id")
    d.add_argument("fix", nargs="?", default="")
    a = ap.parse_args(argv)
    base = notes_dir(a.dir)
    if a.cmd == "list":
        ns = [n for n in load(base) if a.all or n["status"] == "open"]
        print("\n".join(line(n) + ("  [done: %s]" % n["fix"] if n["status"] == "done" else "") for n in ns) if ns else "no notes")
    elif a.cmd == "show":
        n = find(base, a.id)
        if not n:
            print("no note '%s'" % a.id, file=sys.stderr)
            return 1
        n = {k: v for k, v in n.items() if k != "_dir"}
        print(json.dumps(n, indent=2))
    elif a.cmd == "done":
        n = find(base, a.id)
        if not n:
            print("no note '%s'" % a.id, file=sys.stderr)
            return 1
        n["status"] = "done"
        n["fix"] = a.fix
        path = os.path.join(n.pop("_dir"), "note.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(n, f, indent="\t")
        rewrite_index(base)
        print("note %s done" % a.id)
    elif a.cmd == "export-md":
        ns = [n for n in load(base) if a.all or n["status"] == "open"]
        print("| id | sev | tags | target | note | status |")
        print("|---|---|---|---|---|---|")
        for n in ns:
            text = n["text"].replace("|", "\\|")
            status = "done (%s)" % n["fix"] if n["status"] == "done" and n["fix"] else n["status"]
            print("| %s | %d | %s | %s %s | %s | %s |" % (n["id"], n["severity"], ",".join(n["tags"]) or "-", n["target"]["kind"],
                                                         n["target"]["name"], text, status))
    return 0


if __name__ == "__main__":
    sys.exit(main())
