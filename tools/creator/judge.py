#!/usr/bin/env python3
"""Blind judge for the creator scorecard (phase 2, a SOFT signal: the hard metrics in score.py gate).
  judge.py pairs <run dir>            build side-by-side pairs, ours vs the reference moment, random left/right (seeded by moment),
                                      into <run dir>/pairs/ (git-ignored: it holds reference frames) with pairs/key.json
  judge.py run <run dir> [--run]      ask each judge CLI (two model families) to score both sides on the rubric. Without --run it
                                      only prints the commands (dry run). Writes <run dir>/judge.json with the averaged ours-minus-reference gap.
  judge.py vote <run dir> <moment> <ours|ref>   append an owner vote to docs/evidence/godot/creator-score/votes.jsonl
  judge.py agreement                  judge-to-owner agreement over votes.jsonl (A33: a judge replaces the owner only at >= 80%)
Judges: codex (OpenAI family, reads images with -i) and claude (Anthropic family, reads the pair with its Read tool). Prompt carries
no owner or project names. The rubric: framing, handle clarity, visible feedback, uncluttered, alive; 1-5 each."""
import json, os, random, subprocess, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "godot", "creator-score")
VOTES = os.path.join(ROOT, "votes.jsonl")
RUBRIC = ["framing", "handles", "feedback", "uncluttered", "alive"]
MOMENTS = ["start", "spine_hover", "part_picked", "part_dropped", "spine_drag", "part_rotate", "final"]
PROMPT = ("Two screenshots of a creature editor are side by side in one image (left and right). Judge only the editor's feel and flow, "
          "not the art style. For EACH side score 1-5 on: framing (creature large and centred, about half the frame height), handles "
          "(manipulation handles on the body are clear and minimal), feedback (a visible reaction to the last action: puff, cost number, "
          "counter), uncluttered (no big panels or foreground clutter covering the creature), alive (the creature looks posed and "
          "alive, not frozen). Answer with one JSON line only: "
          '{"left": {"framing": n, "handles": n, "feedback": n, "uncluttered": n, "alive": n}, "right": {...}}. Image: %s')
JUDGES = {
    "codex": lambda img, p: ["codex", "exec", "-m", "gpt-6.1-sol", "-s", "read-only", "--skip-git-repo-check", "-i", img, p],
    "claude": lambda img, p: ["claude", "-p", "--model", "sonnet", "--allowedTools", "Read", p],
}


def pairs(d):
    ref = json.load(open(os.path.join(ROOT, "reference.json")))
    os.makedirs(os.path.join(d, "pairs"), exist_ok=True)
    key = {}
    for n in MOMENTS:
        rp = os.path.join(ROOT, "ref_frames", ref["ours_to_ref"][n] + ".png")
        if not os.path.exists(rp):
            sys.exit("reference frames missing: run tools/creator/ref_frames.py first")
        ours = Image.open(os.path.join(d, n + ".jpg")).convert("RGB").resize((640, 360))
        rf = Image.open(rp).convert("RGB").resize((358, 356))
        left_ours = random.Random(n + os.path.basename(os.path.abspath(d))).random() < 0.5
        W = Image.new("RGB", (640 + 358 + 10, 360), (0, 0, 0))
        a, b = (ours, rf) if left_ours else (rf, ours)
        W.paste(a, (0, 0))
        W.paste(b, (a.size[0] + 10, 0))
        W.save(os.path.join(d, "pairs", n + ".jpg"), quality=90)
        key[n] = "left" if left_ours else "right"
    json.dump({"ours_side": key}, open(os.path.join(d, "pairs", "key.json"), "w"), indent=1)
    print("pairs in", os.path.join(d, "pairs"))


def parse(txt):
    for line in reversed(txt.strip().splitlines()):
        line = line.strip().strip("`")
        if line.startswith("{"):
            try:
                return json.loads(line)
            except ValueError:
                pass
    return None


def run(d, live):
    key = json.load(open(os.path.join(d, "pairs", "key.json")))["ours_side"]
    res = {}
    for n in MOMENTS:
        img = os.path.abspath(os.path.join(d, "pairs", n + ".jpg"))
        for jn, mk in JUDGES.items():
            cmd = mk(img, PROMPT % img)
            if not live:
                print("DRY", jn, n, " ".join(cmd[:8]), "...")
                continue
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=300, stdin=subprocess.DEVNULL)
            j = parse(r.stdout)
            if j is None:
                print("judge", jn, n, "gave no JSON")
                continue
            o, f = j[key[n]], j["right" if key[n] == "left" else "left"]
            res.setdefault(n, {})[jn] = {"ours": sum(o[k] for k in RUBRIC), "ref": sum(f[k] for k in RUBRIC), "detail": {"ours": o, "ref": f}}
    if live:
        for n, js in res.items():
            gaps = [v["ours"] - v["ref"] for v in js.values()]
            js["mean_gap_ours_minus_ref"] = round(sum(gaps) / len(gaps), 2)
        json.dump(res, open(os.path.join(d, "judge.json"), "w"), indent=1)
        print(json.dumps({n: v["mean_gap_ours_minus_ref"] for n, v in res.items()}))


def vote(d, moment, pick):
    open(VOTES, "a").write(json.dumps({"run": os.path.basename(os.path.abspath(d)), "moment": moment, "owner_pick": pick}) + "\n")


def agreement():
    if not os.path.exists(VOTES):
        print("no votes yet")
        return
    ok = tot = 0
    for line in open(VOTES):
        v = json.loads(line)
        jp = os.path.join(ROOT, v["run"], "judge.json")
        if not os.path.exists(jp):
            continue
        j = json.load(open(jp)).get(v["moment"])
        if not j:
            continue
        pick = "ours" if j["mean_gap_ours_minus_ref"] > 0 else "ref"
        tot += 1
        ok += pick == v["owner_pick"]
    print("agreement %d/%d%s" % (ok, tot, "" if tot == 0 else " = %.0f%% (needs >= 80%% to replace the owner, A33)" % (100.0 * ok / tot)))


if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else ""
    if c == "pairs":
        pairs(sys.argv[2])
    elif c == "run":
        run(sys.argv[2], "--run" in sys.argv)
    elif c == "vote":
        vote(sys.argv[2], sys.argv[3], sys.argv[4])
    elif c == "agreement":
        agreement()
    else:
        print(__doc__)
