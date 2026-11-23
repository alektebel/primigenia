#!/usr/bin/env python3
"""Creature-loop scorecard (docs/plans/creature-loop.md, T1).

  tools/loop/score.py <dir>                    score every *.jsonl in <dir> (the wander bot, one file per seed); writes
                                               metrics_<name>.json and summary.md next to them and prints the table
  tools/loop/score.py --session <file> [...]   one real play session (owner: user://loop/<stamp>.jsonl), owner targets
  options: --kind bot|owner (default bot for a dir, owner for --session)   --json   --quiet

Input: JSONL written by godot/devtools/loop/loop_recorder.gd: {"n": name, "tick": sim tick, "ms": wall ms, "ts": unix s, "d": {...}}.
Time is the sim's: 10 ticks = 1 s of game time; a run starts at its island_ready. A session file holding several runs (menu ->
Play again) scores the run with the most events. Every target is a starting value from the plan (see TARGETS); a metric that the
file cannot answer is `n/a`, never a pass.
"""
import glob, json, os, sys

TPS = 10.0
QUIET = {"sample", "perf", "session_start", "island_ready"}      # events that are not something the player did or saw
NOVELTY = {"species_seen", "part_found", "shard_found", "cave", "first_bond", "move_learned", "cousin_seen", "flight_start", "evolve", "first_evolve", "fight_end"}
BEATS = [("first_move", "first input", "first_move", None), ("first_select", "first select", "select", None), ("hunt", "hunt", "quest_done:hunt", None),
         ("friend", "friend", "quest_done:friend", None), ("dig", "dig", "quest_done:dig", None), ("wings", "wings", "quest_done:wings", None),
         ("fire", "fire", "quest_done:fire", None), ("cousin", "cousin seen", "cousin_seen", None)]
# The e2e's own tick budget per task (first_quest_e2e.gd BUDGET/TOTAL), measured from the previous task's completion.
BOT_BUDGET = {"hunt": 15000, "friend": 12000, "dig": 2500, "wings": 6000, "fire": 6000}
BOT_TOTAL = 40000

# key, label, op, bot target, owner target, scope (both|owner), unit
TARGETS = [
    ("t_first_move_s", "time to first input", "<=", 10, 10, "both", "s"),
    ("t_first_select_s", "time to first select", "<=", 120, 120, "both", "s"),
    ("t_hunt_s", "time to hunt", "<=", 360, 360, "both", "s"),
    ("t_friend_s", "time to friend", "<=", 720, 720, "both", "s"),
    ("t_dig_s", "time to dig", "<=", 840, 840, "both", "s"),
    ("t_wings_s", "time to wings", "<=", 1080, 1080, "both", "s"),
    ("t_fire_s", "time to fire", "<=", 1500, 1500, "both", "s"),
    ("t_cousin_s", "time to cousin seen", "<=", 1620, 1620, "both", "s"),
    ("deaths_before_evolve", "deaths before the first evolve", "<=", 0, 1, "both", ""),
    ("fights_per_kill", "fights per kill", "<=", 2, 2, "both", ""),
    ("befriend_tries", "befriend tries before the first bond", "<=", 3, 3, "both", ""),
    ("garfio_win_rate", "Garfio win rate", "in", (0.35, 0.80), (0.35, 0.80), "both", ""),
    ("load_cold_s", "cold load", "<=", 15, 15, "owner", "s"),
    ("load_reentry_s", "re-entry load", "<=", 5, 5, "owner", "s"),
    ("load_creatures_s", "creatures phase", "<=", 2.5, 2.5, "owner", "s"),
    ("load_stage_setup_s", "stage_setup phase", "<=", 0.3, 0.3, "owner", "s"),
    ("frame_p95_ms", "frame time p95 (low tier)", "<=", 33.3, 33.3, "owner", "ms"),
    ("max_gap_s", "longest stretch without progress or stimulus", "<=", 90, 90, "both", "s"),
    ("dead_frac_30", "dead time share of the first 30 min", "<=", 0.10, 0.10, "both", ""),
    ("dna_at_editor", "DNA when the editor first opens", ">=", 30, 30, "both", ""),
    ("max_novelty_gap_min", "longest gap between novelties", "<=", 15, 15, "both", "min"),
    ("species_10min", "species seen in the first 10 min", ">=", 4, 4, "both", ""),
    ("species_30min", "species seen by 30 min", ">=", 8, 8, "both", ""),
]
# Metrics with no plan target but part of the report.
INFO = [("walked_m", "distance walked", "m"), ("run_s", "run length", "s"), ("kills", "kills", ""), ("fights", "fights", ""), ("bonds", "bonds", ""),
        ("deaths", "deaths", ""), ("dna_total", "DNA earned", ""), ("evolves", "evolves", ""), ("species_seen", "species seen", ""), ("flight_s", "first flight at", "s"),
        ("editor_open_s", "editor first opened at", "s"), ("part_found_s", "first part found at", "s"), ("nest_visits", "nest visits", ""), ("w_fire_s", "wall time to fire", "s")]
BOT_ONLY = [("bot_task_hunt", "hunt task ticks (budget 15000)", BOT_BUDGET["hunt"]), ("bot_task_friend", "friend task ticks (budget 12000)", BOT_BUDGET["friend"]),
            ("bot_task_dig", "dig task ticks (budget 2500)", BOT_BUDGET["dig"]), ("bot_task_wings", "wings task ticks (budget 6000)", BOT_BUDGET["wings"]),
            ("bot_task_fire", "fire task ticks (budget 6000)", BOT_BUDGET["fire"]), ("bot_total", "chain ticks (budget 40000)", BOT_TOTAL)]


def read(path):
    out = []
    for line in open(path, errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            pass            # a half-written last line of a live session
    return out


def runs(events):
    """Split on island_ready; the first group holds anything before the first island_ready."""
    groups, cur = [], []
    for e in events:
        if e["n"] == "island_ready" and any(x["n"] == "island_ready" for x in cur):
            groups.append(cur)
            cur = []
        cur.append(e)
    groups.append(cur)
    return groups


def pick(events):
    best = max(runs(events), key=lambda g: sum(1 for e in g if e["n"] not in QUIET)) if events else []
    return best


def first(ev, name, pred=None):
    for e in ev:
        if e["n"] == name and (pred is None or pred(e)):
            return e
    return None


def compute(events, kind="bot"):
    allruns = runs(events)
    ev = pick(events)
    m = {k: None for k, *_ in TARGETS}
    m.update({k: None for k, *_ in INFO})
    m.update({k: None for k, *_ in BOT_ONLY})
    ir = first(ev, "island_ready")
    if ir is None and not ev:
        return m
    t0 = ev[0]["tick"] if ir is None else max(ir["tick"], 0)
    ms0 = ev[0]["ms"] if ir is None else ir["ms"]
    sec = lambda e: (e["tick"] - t0) / TPS if e is not None and e["tick"] >= 0 else None
    wall = lambda e: (e["ms"] - ms0) / 1000.0 if e is not None else None
    last_tick = max([e["tick"] for e in ev] + [t0])
    m["run_s"] = (last_tick - t0) / TPS

    # time to each beat
    beat_ev = {}
    for key, _label, name, _ in BEATS:
        e = first(ev, name)
        beat_ev[key] = e
        m["t_%s_s" % key] = sec(e)
    m["w_fire_s"] = wall(beat_ev["fire"])

    # fights, kills, deaths, befriend
    fight_start = [e for e in ev if e["n"] == "fight_start"]
    fight_end = [e for e in ev if e["n"] == "fight_end"]
    kills = [e for e in ev if e["n"] == "kill"]
    m["fights"], m["kills"] = len(fight_start), len(kills)
    m["fights_per_kill"] = len(fight_start) / len(kills) if kills else None
    evolve = first(ev, "first_evolve") or first(ev, "evolve")
    deaths = [e for e in ev if e["n"] == "player_death"]
    m["deaths"] = len(deaths)
    m["deaths_before_evolve"] = len([e for e in deaths if evolve is None or e["tick"] <= evolve["tick"]]) if ev else None
    m["evolves"] = len([e for e in ev if e["n"] == "evolve"])
    bond = first(ev, "first_bond")
    starts = [e for e in ev if e["n"] == "befriend_start"]
    if bond is not None:
        m["befriend_tries"] = len([e for e in starts if e["tick"] <= bond["tick"]])
    m["bonds"] = len([e for e in ev if e["n"] == "bond_made"])
    garfio = [e for e in fight_end if str(e["d"].get("name", "")).lower() == "garfio"]
    if garfio:
        m["garfio_win_rate"] = sum(1 for e in garfio if e["d"].get("result") == "kill") / len(garfio)

    # DNA, nest, flight, parts
    dna = [e for e in ev if e["n"] == "sample"]
    if dna:
        m["dna_total"] = max(e["d"].get("dna_total", 0) for e in dna)
        m["walked_m"] = max(e["d"].get("dist", 0) for e in dna)
    eo = first(ev, "editor_open")
    if eo is not None:
        m["dna_at_editor"] = eo["d"].get("dna")
        m["editor_open_s"] = sec(eo)
    m["flight_s"] = sec(first(ev, "flight_start"))
    m["part_found_s"] = sec(first(ev, "part_found"))
    m["nest_visits"] = len([e for e in ev if e["n"] == "nest_enter"])

    # species
    seen = [e for e in ev if e["n"] == "species_seen"]
    m["species_seen"] = len(seen)
    m["species_10min"] = len([e for e in seen if sec(e) is not None and sec(e) <= 600])
    m["species_30min"] = len([e for e in seen if sec(e) is not None and sec(e) <= 1800])

    # dead time: gaps between consecutive things the player did or saw
    marks = [t0] + [e["tick"] for e in ev if e["n"] not in QUIET and e["tick"] >= t0] + [last_tick]
    marks = sorted(marks)
    gaps = [(b - a) / TPS for a, b in zip(marks, marks[1:])]
    m["max_gap_s"] = max(gaps) if gaps else 0.0
    horizon = min(last_tick - t0, 1800 * TPS)
    dead = 0.0
    for a, b in zip(marks, marks[1:]):
        if (b - a) / TPS > 90 and a - t0 < horizon:
            dead += min(b, t0 + horizon) - a
    m["dead_frac_30"] = dead / horizon if horizon > 0 else 0.0

    # novelty
    nov = sorted([t0] + [e["tick"] for e in ev if e["n"] in NOVELTY and e["tick"] >= t0] + [e["tick"] for e in ev if e["n"].startswith("quest_done:")])
    nov.append(last_tick)
    m["max_novelty_gap_min"] = max((b - a) / TPS / 60.0 for a, b in zip(sorted(nov), sorted(nov)[1:])) if len(nov) > 1 else 0.0

    # load (owner RTX; software GL in the bot is only informative)
    irs = [e for e in allruns_flat(allruns) if e["n"] == "island_ready"]
    if irs:
        m["load_cold_s"] = irs[0]["d"].get("ms", 0) / 1000.0
        ph = irs[0]["d"].get("phases", {})
        if "creatures" in ph:
            m["load_creatures_s"] = ph["creatures"] / 1000.0
        if "stage_setup" in ph:
            m["load_stage_setup_s"] = ph["stage_setup"] / 1000.0
        re = [e for e in irs[1:] if "kit_reused" in e["d"].get("phases", {})]
        if re:
            m["load_reentry_s"] = re[0]["d"].get("ms", 0) / 1000.0
    perf = [e["d"]["ms_p95"] for e in ev if e["n"] == "perf" and "ms_p95" in e["d"]]
    if perf:
        perf.sort()
        m["frame_p95_ms"] = perf[len(perf) // 2]

    # bot budgets: ticks per task measured from the previous task's completion (hunt from the first tick)
    prev = t0
    for key in ("hunt", "friend", "dig", "wings", "fire"):
        e = beat_ev[key]
        if e is not None:
            m["bot_task_" + key] = e["tick"] - prev
            prev = e["tick"]
    if beat_ev["fire"] is not None:
        m["bot_total"] = beat_ev["fire"]["tick"] - t0
    return m


def allruns_flat(groups):
    return [e for g in groups for e in g]


def judge(op, target, v):
    if v is None:
        return "n/a"
    if op == "<=":
        return "pass" if v <= target else "fail"
    if op == ">=":
        return "pass" if v >= target else "fail"
    return "pass" if target[0] <= v <= target[1] else "fail"


def fmt(v, unit=""):
    if v is None:
        return "-"
    if isinstance(v, float):
        return ("%.2f" % v).rstrip("0").rstrip(".") if abs(v) < 100 else "%.0f" % v
    return str(v)


def evaluate(metrics_by_run, kind):
    """-> [(key, label, op, target, scope, unit, [(value, status)...])]; owner-scope targets are n/a for the bot."""
    rows = []
    for key, label, op, bt, ot, scope, unit in TARGETS:
        target = bt if kind == "bot" else ot
        cells = []
        for m in metrics_by_run.values():
            v = m.get(key)
            st = "n/a (owner)" if scope == "owner" and kind == "bot" else judge(op, target, v)
            if st == "n/a" and key.startswith("t_"):
                # a beat that never happened: a failure once the run is over (the chain is finished, or the target time has passed)
                if m.get("t_fire_s") is not None or (m.get("run_s") or 0) > target:
                    st = "fail"
            cells.append((v, st))
        rows.append((key, label, op, target, scope, unit, cells))
    if kind == "bot":
        for key, label, budget in BOT_ONLY:
            cells = [(m.get(key), judge("<=", budget, m.get(key))) for m in metrics_by_run.values()]
            rows.append((key, label, "<=", budget, "bot", "ticks", cells))
    return rows


def table(rows, names):
    out = ["| metric | target | " + " | ".join(names) + " | status |", "|---|---|" + "---|" * len(names) + "---|"]
    failing = []
    for key, label, op, target, scope, unit, cells in rows:
        tgt = "%s %s%s" % (op, ("%s..%s" % target) if isinstance(target, tuple) else fmt(target), (" " + unit) if unit else "")
        sts = [c[1] for c in cells]
        status = "FAIL" if "fail" in sts else ("pass" if "pass" in sts and all(s in ("pass", "n/a") for s in sts) else "n/a")
        if all(s.startswith("n/a") for s in sts):
            status = "n/a"
        if status == "FAIL":
            failing.append(label)
        out.append("| %s | %s | %s | %s |" % (label, tgt, " | ".join(("%s%s" % (fmt(v), "" if s in ("pass", "n/a", "n/a (owner)") else " !")) for v, s in cells), status))
    return "\n".join(out), failing


def info_table(metrics_by_run):
    names = list(metrics_by_run)
    out = ["| info | " + " | ".join(names) + " |", "|---|" + "---|" * len(names)]
    for key, label, unit in INFO:
        out.append("| %s%s | %s |" % (label, (" (%s)" % unit) if unit else "", " | ".join(fmt(m.get(key)) for m in metrics_by_run.values())))
    return "\n".join(out)


def main(argv):
    kind, files, outdir, as_json = None, [], None, False
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--kind":
            kind = args.pop(0)
        elif a == "--session":
            kind = kind or "owner"
            files.append(args.pop(0))
        elif a == "--json":
            as_json = True
        elif a == "--quiet":
            pass
        elif os.path.isdir(a):
            outdir = a
            files += sorted(glob.glob(os.path.join(a, "*.jsonl")))
            kind = kind or "bot"
        else:
            files.append(a)
    if not files:
        sys.exit("usage: score.py <dir> | --session <file.jsonl> [--kind bot|owner] [--json]")
    kind = kind or "bot"
    by = {}
    for f in files:
        by[os.path.splitext(os.path.basename(f))[0]] = compute(read(f), kind)
    rows = evaluate(by, kind)
    if as_json:
        print(json.dumps({"kind": kind, "metrics": by}, indent=1, sort_keys=True))
        return 0
    tbl, failing = table(rows, list(by))
    text = "# Loop scorecard (%s)\n\n%s\n\n%s\n\nFailing targets: %s\n" % (kind, tbl, info_table(by), ", ".join(failing) if failing else "none")
    print(text)
    if outdir:
        for name, m in by.items():
            json.dump({"kind": kind, "metrics": m}, open(os.path.join(outdir, "metrics_%s.json" % name), "w"), indent=1, sort_keys=True)
        open(os.path.join(outdir, "summary.md"), "w").write(text)
    return 1 if failing and kind == "bot" and os.environ.get("LOOP_STRICT") == "1" else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
