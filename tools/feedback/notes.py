#!/usr/bin/env python3
"""Read and close the in-game notes the owner leaves in flag mode (docs/godot/DEVTOOLS.md, primigenia.note/1).

    notes.py list [--all]            open notes, newest first (--all: with done ones)
    notes.py show <id> [--json]      the note with its metadata laid out (--json: the raw note.json)
    notes.py done <id> "<fix>"       mark a note done and record the fixing commit
    notes.py export-md [--all]       a Markdown table for STATUS.md and the tracker

Notes live in <repo>/feedback/notes (git-ignored), else ~/.local/share/godot/app_userdata/Primigenia/feedback/notes;
--dir overrides. Each note is <stamp>-<id>/note.json next to screenshot.jpg, crop.jpg and scenario.json.
Same file format as godot/devtools/notes/note_store.gd (keep them in sync). Notes made with N (or Ctrl+N) and Shift+F8 carry a "meta" object
(primigenia.note.meta/1, godot/devtools/notes/note_meta.gd): build, mode, tick, seed, player, creature, quest, nearby, camera, perf, render.
A note without "meta" (older) or without text (Ctrl+N) is still listed.
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
    out.sort(key=lambda n: (n["stamp"], int(n.get("unix_ms", 0)), n["id"]), reverse=True)
    return out


def line(n):
    tags = ",".join(n["tags"]) or "-"
    t = n["target"]
    return "#%s [%s %d] %s (%s %s)" % (n["id"], tags, n["severity"], n["text"] or "(no text)", t["kind"], t["name"])


def _f(v, digits=1):
    return ("%." + str(digits) + "f") % float(v)


def meta_lines(m):
    """The same compact lines the game shows (note_meta.gd lines())."""
    out = []
    if not m:
        return out
    b = m.get("build", {})
    out.append("%s  tick %s  seed %s  %s" % (m.get("mode", "?"), m.get("tick", "-"), m.get("seed", "-"),
                                             ("%s%s" % (b.get("commit", "?"), "+dirty" if b.get("dirty") else "")) if b else ""))
    p = m.get("player")
    if p:
        out.append("pos %s, %s, %s  head %s deg  %s m/s" % (_f(p["pos"][0]), _f(p["pos"][1]), _f(p["pos"][2]), _f(p["heading_deg"], 0), _f(p["speed"], 2)))
        out.append("gait %s  style %s  %s" % (p.get("gait") or "-", p.get("style") or "-", "running" if p.get("running") else "walking"))
        out.append("hp %s/%s  stamina %s/%s" % (_f(p["hp"], 0), _f(p["hp_max"], 0), _f(p["stamina"], 0), _f(p["stamina_max"], 0)))
    c = m.get("creature")
    if c:
        out.append("%s  %d parts (%s)  DNA %s (balance %s)" % (c.get("name", ""), len(c.get("parts", [])), ", ".join(c.get("parts", [])),
                                                                c.get("dna", {}).get("total"), c.get("dna", {}).get("balance")))
    q = m.get("quest")
    if q:
        out.append("quest %s  step %d/%d" % (q.get("task") or ("done" if q.get("finished") else "-"), int(q["step"]) + 1, int(q["total"])))
    cam = m.get("camera", {})
    if "pos" in cam:
        out.append("cam %s, %s, %s  pitch %s yaw %s" % (_f(cam["pos"][0]), _f(cam["pos"][1]), _f(cam["pos"][2]), _f(cam["angle_deg"][0], 0), _f(cam["angle_deg"][1], 0)))
    pf = m.get("perf")
    if pf:
        out.append("%s fps  p95 %s ms" % (_f(pf["fps"], 0), _f(pf["frame_ms_p95"], 1)))
    r = m.get("render")
    if r:
        w = m.get("window", [0, 0])
        out.append("%s  %s  %dx%d" % (r.get("renderer", "?"), str(r.get("gpu", "?"))[:34], w[0], w[1]))
    o = m.get("options")
    if o:
        out.append("F10: " + " | ".join("%s %s" % (k.split("/")[-1], v) for k, v in o.items()))
    nb = m.get("nearby", [])
    if nb:
        out.append("nearby %d:" % len(nb))
        for e in nb:
            out.append("  %s #%d  %s m  %s  %s  hp %s" % (e["species"], e["id"], _f(e["dist"]), e["state"], e["temperament"], _f(e["hp"], 0)))
    return out


def show_text(n):
    """A note laid out for people: header, text, then the meta lines and the files."""
    n = {k: v for k, v in n.items() if k != "_dir"}
    t = n["target"]
    out = ["#%s  %s  [%s]  severity %d  status %s%s" % (n["id"], n["stamp"], ",".join(n["tags"]) or "-", n["severity"], n["status"],
                                                      ("  fix " + n["fix"]) if n.get("fix") else ""),
           "target: %s %s" % (t["kind"], t["name"]), "text: " + (n["text"] or "(no text)")]
    if n.get("origin"):
        out.append("origin: " + n["origin"])
    m = n.get("meta")
    if m:
        out.append("--- meta (%s)" % m.get("schema", "?"))
        out.extend("  " + ln for ln in meta_lines(m))
    else:
        out.append("--- no meta (an older note): tick %s, build %s" % (n.get("tick"), n.get("build")))
    return "\n".join(out)


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
    sp = sub.add_parser("show")
    sp.add_argument("id")
    sp.add_argument("--json", action="store_true", help="the raw note.json")
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
        if a.json:
            print(json.dumps({k: v for k, v in n.items() if k != "_dir"}, indent=2))
        else:
            print(show_text(n))
            d = n["_dir"]
            files = [f for f in ("screenshot.jpg", "crop.jpg", "scenario.json") if os.path.isfile(os.path.join(d, f))]
            print("files: " + (d + "/ " + " ".join(files) if files else "-"))
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
