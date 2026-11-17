#!/usr/bin/env python3
"""Run one agent episode: tools/agentplay/play.py --seed 1 --persona fighter --turns 60 --model qwen3.6"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from env import Episode  # noqa: E402
from policies import LLMPolicy, PERSONAS, RandomPolicy, ScriptedPolicy, parse_reply  # noqa: E402


def max_run(cmds):
    best = cur = 0
    prev = None
    for c in cmds:
        cur = cur + 1 if c == prev and c is not None else 1
        best = max(best, cur)
        prev = c
    return best


def run(seed, persona, turns, model, policy, tpt=20, out_root=None, run_id=None):
    tag = policy if policy != "llm" else model
    run_id = run_id or f"{tag}-{persona}-s{seed}-t{turns}"
    out = os.path.join(out_root or os.path.join(HERE, "runs"), run_id)
    os.makedirs(out, exist_ok=True)
    ep = Episode(seed, tpt)
    if policy == "llm":
        pol = LLMPolicy(persona, model, seed)
    elif policy == "scripted":
        pol = ScriptedPolicy(persona, seed)
    else:
        pol = RandomPolicy(random.Random(seed * 31 + 1))
    history, cmds, invalid, notes = [], [], 0, []
    t0 = time.time()
    log = open(os.path.join(out, "log.jsonl"), "w")
    for t in range(1, turns + 1):
        obs = ep.obs
        cmd, note = pol.act(obs, history)
        parsed = cmd
        if policy == "llm":
            if cmd is None:
                invalid += 1
        if note:
            notes.append({"turn": t, "note": note})
        res = ep.play_turn(cmd)
        if res["error"] != "ok" and policy == "llm":
            pass
        cmds.append(cmd)
        history.append({"turn": t, **res, "hp": ep.obs["own"]["hp"]})
        log.write(json.dumps({
            "turn": t, "tick": ep.obs["tick"], "obs": obs, "prompt_chars": getattr(pol, "last_prompt_chars", 0),
            "reply": getattr(pol, "last_reply", None), "parse": getattr(pol, "last_parse", None),
            "action": parsed, "error": res["error"], "moved": res["moved"]}) + "\n")
    log.close()
    det = ep.replay_check()
    stats = {k: v for k, v in ep.verb_stats.items()}
    errs = sum(v["err"] for v in ep.verb_stats.values())
    issued = sum(v["n"] for v in ep.verb_stats.values())
    summary = {
        "id": run_id, "seed": seed, "persona": persona, "policy": policy, "model": model if policy == "llm" else None,
        "turns": turns, "ticks_per_turn": tpt, "final_tick": ep.obs["tick"],
        "deaths": ep.deaths, "wins": len(ep.wins), "won": len(ep.wins) > 0,
        "final_hp": ep.obs["own"]["hp"], "distance": round(ep.dist_travelled, 1), "cells_visited": len(ep.cells),
        "nest_visits": ep.nest_visits, "stuck": any(b["kind"] == "stuck" for b in ep.bugs),
        "invalid_replies": invalid, "invalid_reply_rate": round(invalid / turns, 3),
        "commands_issued": issued, "command_errors": errs, "error_rate": round(errs / issued, 3) if issued else 0,
        "error_by_verb": stats, "longest_repeat": max_run(cmds), "determinism": det,
        "bugs": ep.bugs, "notes": notes[-30:], "seconds": round(time.time() - t0, 1),
    }
    if policy == "llm":
        summary["tokens"] = {k: pol.usage[k] for k in ("prompt", "completion", "calls")}
        summary["avg_prompt_chars"] = None
        summary["llm_errors"] = pol.errors[:5]
        issues, raw = pol.usability_question(
            f"{turns} turns, {errs} rejected commands, {invalid} unparseable replies, {ep.deaths} deaths, "
            f"win={bool(ep.wins)}")
        summary["usability_llm"] = issues
        summary["usability_raw"] = raw
        summary["tokens"] = {k: pol.usage[k] for k in ("prompt", "completion", "calls")}
    with open(os.path.join(out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--persona", default="fighter", choices=list(PERSONAS))
    ap.add_argument("--turns", type=int, default=60)
    ap.add_argument("--model", default="qwen3.6")
    ap.add_argument("--policy", default="llm", choices=["llm", "scripted", "random"])
    ap.add_argument("--ticks-per-turn", type=int, default=20)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    s = run(a.seed, a.persona, a.turns, a.model, a.policy, a.ticks_per_turn, a.out)
    print(json.dumps({k: s[k] for k in ("id", "won", "deaths", "stuck", "invalid_replies", "error_rate", "determinism")}
                     | {"bugs": [b["kind"] for b in s["bugs"]], "tokens": s.get("tokens")}))


if __name__ == "__main__":
    main()
