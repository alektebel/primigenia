#!/usr/bin/env python3
"""Random valid verb smoke for the P4 world binding (stdlib only)."""
import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cpore.world import StageWorld


def random_command(obs: dict, rng: random.Random) -> str:
    verbs = list(obs.get("legal_verbs") or ["wait"])
    verb = rng.choice(verbs)
    if verb == "go":
        x = rng.uniform(-20.0, 20.0)
        z = rng.uniform(-20.0, 20.0)
        return f"go {x:.1f},{z:.1f}"
    if verb == "heading":
        return f"heading {rng.uniform(-180.0, 180.0):.1f}"
    if verb == "approach":
        creatures = [e["id"] for e in obs.get("nearby", [])
                     if e.get("type") == "creature"]
        if creatures:
            return f"approach #{creatures[0]}"
        return "wait"
    if verb == "attack":
        moves = [m for m in obs.get("attack_moves", []) if m.get("equipped", True)] or [{"id": 0, "name": "bite"}]
        creatures = [e["id"] for e in obs.get("nearby", [])
                     if e.get("type") == "creature"]
        if creatures and moves:
            mv = rng.choice(moves)
            return f"attack #{creatures[0]} {mv['name']}"
        return "wait"
    if verb == "loadout":
        known = obs.get("known_moves") or ["bite"]
        return f"loadout {rng.randint(1, 4)} {rng.choice(known)}"
    return verb


def main():
    p = argparse.ArgumentParser(description="Random P4 world agent")
    p.add_argument("--seed", type=int, default=42, help="world setup seed")
    p.add_argument("--steps", type=int, default=40, help="ticks to simulate")
    p.add_argument("--rng", type=int, default=7, help="python RNG seed")
    args = p.parse_args()

    rng = random.Random(args.rng)
    world = StageWorld(seed=args.seed)
    obs = world.observe()
    print(f"seed={args.seed} steps={args.steps} start tick={obs['tick']} hp={obs['own']['hp']:.1f}")

    last_hash = None
    for step in range(args.steps):
        cmd = random_command(obs, rng)
        try:
            world.step(cmd)
        except ValueError as exc:
            world.step("wait")
            print(f"  tick {obs['tick']}: rejected {cmd!r} ({exc}), waited")
        obs = world.observe()
        last_hash = world.hash()
        if step % 10 == 9:
            print(f"  tick {obs['tick']}: {cmd!r} hp={obs['own']['hp']:.1f} "
                  f"stamina={obs['own']['stamina']:.1f}")

    print(f"done tick={obs['tick']} hash={last_hash:016x} summary={obs.get('summary')!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())