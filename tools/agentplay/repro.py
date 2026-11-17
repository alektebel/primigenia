#!/usr/bin/env python3
"""Replay a repro (seed + [[turn, cmd],...]) and shrink it while the bug kind still fires.
   repro.py --seed 3 --tpt 20 --turns 12 --kind stuck --ops '[[1,"flee"]]'"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from env import Episode  # noqa: E402


def run_ops(seed, tpt, turns, ops, kind, detail_prefix=None):
    """Returns the turn where bug `kind` first fires, or None."""
    m = {t: c for t, c in ops}
    ep = Episode(seed, tpt)
    for t in range(turns):
        ep.play_turn(m.get(t))
        for b in ep.bugs:
            if b["kind"] == kind and (not detail_prefix or b["detail"][:40] == detail_prefix):
                return t + 1
    if kind == "nondeterminism":
        ep.replay_check()
        return turns if any(b["kind"] == kind for b in ep.bugs) else None
    return None


def shrink(seed, tpt, turns, ops, kind, detail_prefix=None, budget=150):
    """Chunked delta-debugging over the command list (keeps the bug kind firing)."""
    t = run_ops(seed, tpt, turns, ops, kind, detail_prefix)
    if t is None:
        return None
    turns, ops = t, [o for o in ops if o[0] < t]
    tries, n = 0, 2
    while len(ops) >= 1 and tries < budget:
        size = max(1, len(ops) // n)
        reduced = False
        for i in range(0, len(ops), size):
            cand = ops[:i] + ops[i + size:]
            tries += 1
            t2 = run_ops(seed, tpt, turns, cand, kind, detail_prefix)
            if t2 is not None:
                ops, turns, reduced = [o for o in cand if o[0] < t2], t2, True
                n = max(n - 1, 2)
                break
            if tries >= budget:
                break
        if not reduced:
            if size == 1:
                break
            n = min(len(ops), n * 2)
    return {"seed": seed, "ticks_per_turn": tpt, "turns": turns, "ops": ops}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--tpt", type=int, default=20)
    ap.add_argument("--turns", type=int, required=True)
    ap.add_argument("--kind", required=True)
    ap.add_argument("--ops", required=True)
    a = ap.parse_args()
    r = shrink(a.seed, a.tpt, a.turns, json.loads(a.ops), a.kind)
    print(json.dumps(r) if r else "bug did not reproduce")
