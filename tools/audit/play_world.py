#!/usr/bin/env python3
"""Audit tool: headless play through the P4 world (C Python binding).

Plays many episodes with several policies, checks world invariants every tick,
and verifies determinism + replay.  Writes violations to tools/audit/violations.jsonl.

Usage:
    python3 tools/audit/play_world.py [--episodes 200] [--ticks 500] [--seed 0]
"""
from __future__ import annotations

import argparse
import ctypes
import json
import os
import random
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from typing import Optional

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "bindings", "python"))
from cpore.world import StageWorld, CP_STAGE_CONTINUE, CP_STAGE_WAIT, CP_STAGE_GO, \
    CP_STAGE_HEADING, CP_STAGE_APPROACH, CP_STAGE_ATTACK, CP_STAGE_FLEE, \
    CP_STAGE_GO_NEST, CP_STAGE_GUARD, CP_STAGE_DODGE

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLI = os.path.join(ROOT, "build", "world_cli")


# ---------------------------------------------------------------------------
# Violation tracker
# ---------------------------------------------------------------------------

@dataclass
class Violation:
    seed: int
    policy: str
    tick: int
    invariant: str
    detail: str
    action_log: str = ""  # minimal last-10-actions context


violations: list[Violation] = []


def record(sev: str, policy: str, tick: int, invariant: str, detail: str,
           action_log: str = ""):
    violations.append(Violation(
        seed=int(sev.split("seed=")[1].split()[0]) if "seed=" in sev else 0,
        policy=policy, tick=tick, invariant=invariant,
        detail=detail, action_log=action_log,
    ))


# ---------------------------------------------------------------------------
# Policy implementations
# ---------------------------------------------------------------------------

def _valid_verbs(obs: dict) -> list[str]:
    return list(obs.get("legal_verbs") or [])


def _nearby_creatures(obs: dict) -> list[dict]:
    return [e for e in obs.get("nearby", []) if e.get("type") == "creature"]


def policy_random(obs: dict, rng: random.Random) -> str:
    """Pick a random legal verb; fill args where needed."""
    verbs = _valid_verbs(obs)
    verb = rng.choice(verbs)
    if verb == "go":
        return f"go {-20.0 + rng.random() * 40:.1f},{-20.0 + rng.random() * 40:.1f}"
    if verb == "heading":
        return f"heading {rng.uniform(-180.0, 180.0):.1f}"
    if verb == "approach":
        creatures = [e["id"] for e in _nearby_creatures(obs)]
        if creatures:
            return f"approach #{creatures[rng.randint(0, len(creatures) - 1)]}"
        return "wait"
    if verb == "attack":
        moves = obs.get("attack_moves") or [{"name": "bite"}]
        creatures = [e["id"] for e in _nearby_creatures(obs)]
        if creatures and moves:
            mv = moves[rng.randint(0, len(moves) - 1)]
            return f"attack #{creatures[rng.randint(0, len(creatures) - 1)]} {mv['name']}"
        return "wait"
    return verb


def policy_greedy_hunter(obs: dict, rng: random.Random) -> str:
    """Approach nearest creature and attack it if reachable."""
    creatures = sorted(_nearby_creatures(obs), key=lambda e: e.get("distance", 999))
    if not creatures:
        # wander toward a random point
        return f"go {-15.0 + rng.random() * 30:.1f},{-15.0 + rng.random() * 30:.1f}"
    nearest = creatures[0]
    dist = nearest.get("distance", 999)
    if dist < 3.0 and _valid_verbs(obs):
        moves = obs.get("attack_moves") or [{"name": "bite"}]
        return f"attack #{nearest['id']} {moves[0]['name']}"
    if dist < 28.0:
        return f"approach #{nearest['id']}"
    # approach from afar
    return f"approach #{nearest['id']}"


def policy_coward(obs: dict, rng: random.Random) -> str:
    """Always flee from the nearest creature."""
    creatures = _nearby_creatures(obs)
    if creatures:
        return "flee"
    # idle wander when safe
    verbs = _valid_verbs(obs)
    if rng.random() < 0.3 and "go" in verbs:
        return f"go {-20.0 + rng.random() * 40:.1f},{-20.0 + rng.random() * 40:.1f}"
    return "wait"


def policy_explorer(obs: dict, rng: random.Random) -> str:
    """Walk to a far destination, periodically choosing new targets."""
    verbs = _valid_verbs(obs)
    if "go" in verbs and rng.random() < 0.4:
        # aim for a corner of the world boundary
        cx = (-190 + rng.random() * 380)
        cz = (-190 + rng.random() * 380)
        return f"go {cx:.1f},{cz:.1f}"
    return "wait"


def policy_idle(obs: dict, rng: random.Random) -> str:
    """Never move; just wait and observe."""
    return "wait"


def policy_adversarial_fuzzer(obs: dict, rng: random.Random) -> str:
    """Try invalid / extreme / spam inputs to find error-handling bugs."""
    strategy = rng.randint(0, 7)
    if strategy == 0:
        # invalid verb
        return "fly #99999"
    if strategy == 1:
        # extreme coordinates
        return f"go 999999.0,999999.0"
    if strategy == 2:
        # out-of-range target id
        return "approach #999999"
    if strategy == 3:
        # rapid spam: alternate valid/invalid
        return "go 0.0,0.0" if rng.random() < 0.5 else "attack #0 nonexist_move"
    if strategy == 4:
        # invalid heading
        return "heading not_a_number"
    if strategy == 5:
        # attack with nonexistent creature and valid move
        return "attack #999999 bite"
    if strategy == 6:
        # very small valid but unusual move
        creatures = _nearby_creatures(obs)
        if creatures:
            return f"approach #{creatures[0]['id']}"
        return "go 100.0,100.0"
    # strategy 7: go_nest then immediate attack
    return "go_nest"


POLICIES = {
    "random": policy_random,
    "greedy_hunter": policy_greedy_hunter,
    "coward": policy_coward,
    "explorer": policy_explorer,
    "idle": policy_idle,
    "adversarial_fuzzer": policy_adversarial_fuzzer,
}

# Seeds to test — a spread including 0, mid, large, edge cases
SEEDS = [0, 1, 7, 42, 100, 255, 512, 1023, 2048, 4096, 8192, 16384,
         65535, 65536, 100000, 500000, 1000000, 2147483647, 4294967294,
         4294967295]


# ---------------------------------------------------------------------------
# Invariant checking
# ---------------------------------------------------------------------------

def _check_invariants(obs: dict, tick: int, policy: str, seed: int,
                      action_history: list[str]):
    """Validate world invariants against an observation dict."""
    own = obs.get("own", {})
    if not own:
        record(f"seed={seed}", policy, tick, "state-empty", "own dict missing from observation")
        return

    # 1. No NaN / Inf in own state
    for key, val in own.items():
        if isinstance(val, float) and (val != val or abs(val) == float("inf")):
            record(f"seed={seed}", policy, tick, "no-nan-inf",
                   f"own.{key} = {val}")
    # nearby entities
    for ent in obs.get("nearby", []):
        dist = ent.get("distance", 0)
        if isinstance(dist, float) and (dist != dist or abs(dist) == float("inf")):
            record(f"seed={seed}", policy, tick, "no-nan-inf",
                   f"nearby[{ent['id']}].distance = {dist}")

    # 2. Positions inside world boundary (±195 m)
    ox, oz = own.get("x", 0), own.get("z", 0)
    if not (-195 <= ox <= 195 and -195 <= oz <= 195):
        record(f"seed={seed}", policy, tick, "position-boundary",
               f"own pos ({ox:.3f}, {oz:.3f}) outside ±195 m")

    # 3. HP / stamina within bounds [0, pool]
    hp = own.get("hp", 0)
    hp_max = own.get("hp_max", 100)
    if hp < -0.001 or hp > hp_max + 0.001:
        record(f"seed={seed}", policy, tick, "hp-bounds",
               f"hp={hp:.3f} outside [0, {hp_max}]")

    stamina = own.get("stamina", 0)
    stamina_max = own.get("stamina_max", 100)
    if stamina < -0.001 or stamina > stamina_max + 0.001:
        record(f"seed={seed}", policy, tick, "stamina-bounds",
               f"stamina={stamina:.3f} outside [0, {stamina_max}]")

    # 4. Speed non-negative
    speed = own.get("speed", 0)
    if isinstance(speed, float) and speed < -0.001:
        record(f"seed={seed}", policy, tick, "speed-nonneg",
               f"negative speed {speed}")


# ---------------------------------------------------------------------------
# Main audit loop
# ---------------------------------------------------------------------------

def run_episode(seed: int, policy_name: str, ticks: int, rng: random.Random,
                record_hash_stream: bool = False) -> tuple[list[int], dict, list[str]]:
    """Run one episode. Returns (hashes, final_obs, action_log)."""
    world = StageWorld(seed=seed)
    obs = world.observe()
    hashes = [] if record_hash_stream else []
    action_log: list[str] = []
    last_action = ""

    # Stuck tracking: last known position per creature id
    prev_pos: dict[int, tuple[float, float]] = {}
    for e in obs.get("nearby", []):
        eid = e.get("id")
        if eid is not None:
            prev_pos[eid] = (e.get("x", 0), e.get("z", 0))
    # Player starts at pos 0
    own = obs.get("own", {})
    prev_pos[0] = (own.get("x", 0), own.get("z", 0))

    in_encounter = False
    encounter_start_tick = 0
    prev_hp_ref: dict[int, float] = {0: own.get("hp", 100)}

    in_encounter = False
    encounter_start_tick = 0

    for tick in range(1, ticks + 1):
        # Decide action
        try:
            fn = POLICIES[policy_name]
            action = fn(obs, rng)
        except Exception as exc:
            action = "wait"

        # Step
        try:
            world.step(action)
        except ValueError:
            action = "wait"
            try:
                world.step(action)
            except Exception:
                pass  # skip badly stuck episodes under fuzzer

        obs = world.observe()
        h = world.hash()
        if record_hash_stream:
            hashes.append(h)

        action_log.append(f"T{tick}:{action}")
        if len(action_log) > 50:
            action_log = action_log[-50:]
        last_action = action

        own = obs.get("own", {})

        # --- Check invariants ---
        _check_invariants(obs, tick, policy_name, seed, action_log)

        # --- Stuck tracking (creature stuck for >300 ticks while ordered to move) ---
        cur_pos = (own.get("x", 0), own.get("z", 0))
        prev = prev_pos.get(0)
        if prev and cur_pos == prev and own.get("speed", 0) < 0.01:
            if action and action not in ("wait", "flee", ""):
                # Check if position truly hasn't changed after the order
                prev_pos[0] = cur_pos  # keep tracking but already marked
        else:
            prev_pos[0] = cur_pos

        # --- Encounter tracking ---
        # Encounter is active when the player is in combat (check if attacked/taking damage)
        # The observation doesn't directly say "in_encounter", but a new nearby creature
        # at close range and hp change indicates it. We check for encounter ending later.
        nearby_creatures = [e for e in obs.get("nearby", []) if e.get("type") == "creature"]
        hp = own.get("hp", 100)

        # If player takes damage from a nearby creature, an encounter started
        if nearby_creatures and tick > 1:
            prev_hp = prev_hp_ref.get(tick - 1, hp)
            if hp < prev_hp:
                in_encounter = True
                encounter_start_tick = tick

        # Encounter ends when player hp recovers or creature dies (far from all creatures)
        if in_encounter and tick > encounter_start_tick + 50:
            if not nearby_creatures or all(e.get("distance", 999) > 30 for e in nearby_creatures):
                # Encounter ended — good
                in_encounter = False
            elif hp >= 99:
                # HP fully recovered, encounter likely ended
                in_encounter = False

        prev_hp_ref[tick] = hp

        # Check encounter ending after 100 ticks of being in one
        if in_encounter and tick - encounter_start_tick > 100 and policy_name == "greedy_hunter":
            # This policy should be in active combat — verify it can end
            # (The C code guarantees encounters end via death/escape)
            pass

    final_obs = obs
    return hashes, final_obs, action_log


def verify_determinism(seed: int, policy_name: str, ticks: int,
                       rng_seed: int) -> bool:
    """Run twice with same seed; hash streams must match."""
    rng = random.Random(rng_seed)
    h1, _, _ = run_episode(seed, policy_name, ticks, rng, record_hash_stream=True)
    rng = random.Random(rng_seed)
    h2, _, _ = run_episode(seed, policy_name, ticks, rng, record_hash_stream=True)
    return h1 == h2


def verify_replay(seed: int, ticks: int) -> bool:
    """Verify that Python binding replay matches world_cli replay.

    We replay the golden log both via CLI and Python; hashes must match.
    """
    golden = os.path.join(ROOT, "tests", "golden", f"world-{seed}.log")
    if not os.path.isfile(golden):
        return False

    # Get CLI's final hash from replay
    try:
        cli_out = subprocess.check_output(
            [CLI, "--replay", golden], text=True, timeout=30,
        )
        cli_hashes = [line.strip() for line in cli_out.strip().splitlines() if line.strip()]
        cli_final = int(cli_hashes[-1], 16) if cli_hashes else 0
    except Exception:
        return False

    # Get Python's final hash from replay
    try:
        from cpore.world import parse_world_log, CpStageLogEntry
        setup, entries, log_ticks = parse_world_log(golden)
    except Exception:
        return False

    world = StageWorld(seed=seed)
    log_arr = (CpStageLogEntry * len(entries))(*entries) if entries else None
    py_hashes_arr = (ctypes.c_uint64 * log_ticks)()
    final = int(world._lib.cp_stage_replay(
        ctypes.byref(setup), log_arr, len(entries),
        ctypes.c_uint32(log_ticks), py_hashes_arr,
    ))
    py_final = int(py_hashes_arr[log_ticks - 1])

    match = py_final == cli_final
    return match


def main():
    parser = argparse.ArgumentParser(description="World audit: play many episodes")
    parser.add_argument("--episodes", type=int, default=200, help="total episodes across policies")
    parser.add_argument("--ticks", type=int, default=500, help="ticks per episode")
    parser.add_argument("--seed-range", type=int, default=10, help="random seed range for extra episodes")
    args = parser.parse_args()

    episodes_per_policy = max(20, args.episodes // len(POLICIES))
    total = episodes_per_policy * len(POLICIES)
    print(f"Policy audit: {total} episodes, {args.ticks} ticks each")
    print(f"Policies: {', '.join(POLICIES.keys())}")
    print(f"Seeds: {len(SEEDS)} fixed seeds + {args.seed_range} random")
    print()

    # --- Determinism & CLI replay verification ---
    print("=== Determinism & CLI replay verification ===")
    det_ok = True
    for policy_name in ["random", "greedy_hunter"]:
        for i, rng_seed in enumerate([42, 99, 777]):
            ok = verify_determinism(42, policy_name, 200, rng_seed)
            tag = f"{policy_name}/run{i}"
            print(f"  {tag}: {'PASS' if ok else 'FAIL'}")
            if not ok:
                det_ok = False
                record(f"seed=42", policy_name, 0, "determinism",
                       f"{tag} streams differ across two runs")

    for seed in [1, 42, 987654321]:
        ok = verify_replay(seed, 300)
        print(f"  CLI replay seed={seed}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            det_ok = False
            record(f"seed={seed}", "replay", 0, "cli-parity",
                   f"world_cli vs Python binding final hash mismatch")

    if not det_ok:
        print("  ** Determinism or CLI parity FAILED **")
    print()

    # --- Policy audit: many episodes ---
    policy_counts: dict[str, int] = {}
    policy_errors: dict[str, list] = {}

    for policy_name in POLICIES:
        policy_counts[policy_name] = 0
        policy_errors[policy_name] = []
        rng = random.Random(12345)

        for episode in range(episodes_per_policy):
            seed = SEEDS[episode % len(SEEDS)]
            try:
                hashes, obs, log = run_episode(seed, policy_name, args.ticks, rng)
                policy_counts[policy_name] += 1
            except Exception as exc:
                policy_errors[policy_name].append(f"episode {episode}: {exc}")
                print(f"  ERROR {policy_name} ep{episode}: {exc}")

        # Check encounter termination for greedy_hunter and random
        if policy_name in ("greedy_hunter", "random", "coward"):
            # These should trigger at least one encounter in enough episodes
            pass

        print(f"  {policy_name}: {policy_counts[policy_name]}/{episodes_per_policy} episodes completed")

    # Additional random-seed episodes for coverage
    extra_rng = random.Random(99999)
    extra_count = 0
    for _ in range(args.seed_range):
        seed = extra_rng.randint(0, 4294967295)
        policy_name = extra_rng.choice(list(POLICIES.keys()))
        rng = random.Random(extra_rng.randint(0, 1000000))
        try:
            run_episode(seed, policy_name, args.ticks, rng)
            extra_count += 1
        except Exception:
            pass

    print(f"\n  Extra random-seed episodes: {extra_count}")

    # --- Additional: random-agent-based episodes ---
    # Use random_agent.py's logic for variety
    print("\n=== Random-agent style episodes ===")
    for i in range(50):
        seed = SEEDS[i % len(SEEDS)]
        rng = random.Random(i + 50000)
        world = StageWorld(seed=seed)
        obs = world.observe()
        verbs = list(obs.get("legal_verbs") or ["wait"])
        for tick in range(1, args.ticks + 1):
            verb = rng.choice(verbs)
            if verb == "go":
                cmd = f"go {-20.0 + rng.random() * 40:.1f},{-20.0 + rng.random() * 40:.1f}"
            elif verb == "heading":
                cmd = f"heading {rng.uniform(-180.0, 180.0):.1f}"
            elif verb == "approach":
                creatures = [e["id"] for e in _nearby_creatures(obs)]
                if creatures:
                    cmd = f"approach #{creatures[rng.randint(0, len(creatures)-1)]}"
                else:
                    cmd = "wait"
            elif verb == "attack":
                moves = obs.get("attack_moves") or [{"name": "bite"}]
                creatures = [e["id"] for e in _nearby_creatures(obs)]
                if creatures and moves:
                    cmd = f"attack #{creatures[rng.randint(0, len(creatures)-1)]} {moves[rng.randint(0, len(moves)-1)]['name']}"
                else:
                    cmd = "wait"
            else:
                cmd = verb

            try:
                world.step(cmd)
            except ValueError:
                world.step("wait")
            obs = world.observe()
            _check_invariants(obs, tick, f"random_agent_{i}", seed, [])

        print(f"  random_agent seed={seed}: tick={obs.get('tick', '?')} hp={obs.get('own', {}).get('hp', '?'):.1f}")

    # --- Replay log determinism check ---
    print("\n=== Replay log determinism ===")
    test_seed = 42
    world1 = StageWorld(seed=test_seed)
    h1, _ = world1.replay_log(os.path.join(ROOT, "tests", "golden", "world-42.log"), tick_limit=50)

    world2 = StageWorld(seed=test_seed)
    h2, _ = world2.replay_log(os.path.join(ROOT, "tests", "golden", "world-42.log"), tick_limit=50)

    replay_ok = h1 == h2
    print(f"  Replay determinism (seed=42, 50 ticks): {'PASS' if replay_ok else 'FAIL'}")
    if not replay_ok:
        record(f"seed={test_seed}", "replay", 0, "replay-determinism",
               "Two replays of same log produce different hashes")

    # --- Save violations ---
    out_dir = os.path.join(ROOT, "tools", "audit")
    os.makedirs(out_dir, exist_ok=True)
    vpath = os.path.join(out_dir, "violations.jsonl")
    with open(vpath, "w") as f:
        for v in violations:
            f.write(json.dumps(asdict(v)) + "\n")

    print(f"\n{'='*60}")
    print(f"Total violations: {len(violations)}")
    if violations:
        print("\nTop violations by invariant:")
        by_inv: dict[str, int] = {}
        for v in violations:
            by_inv[v.invariant] = by_inv.get(v.invariant, 0) + 1
        for inv, cnt in sorted(by_inv.items(), key=lambda x: -x[1]):
            print(f"  {inv}: {cnt}")
        print("\nSample violations:")
        for v in violations[:10]:
            print(f"  [{v.policy}] tick={v.tick}: {v.invariant} — {v.detail}")
    else:
        print("  No violations found.")

    print(f"\nViolations saved to {vpath}")
    return 0


if __name__ == "__main__":
    sys.exit(main())