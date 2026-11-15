#!/usr/bin/env python3
"""Smoke check for the P4 world ctypes binding."""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cpore.world import StageWorld

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLI = os.path.join(ROOT, "build", "world_cli")
GOLDEN = os.path.join(ROOT, "tests", "golden", "world-42.log")
HASHES = os.path.join(ROOT, "tests", "golden", "world-42.hashes")

fails = []


def check(cond, msg):
    print(("  ok    " if cond else "  FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def run_episode(seed: int, script):
    w = StageWorld(seed=seed)
    hashes = []
    for tick in range(script["ticks"]):
        if tick in script["commands"]:
            w.step(script["commands"][tick])
        else:
            w.step()
        hashes.append(w.hash())
    final = w.hash()
    obs = w.observe()
    return hashes, final, obs


def cli_final_hash(seed: int) -> str:
    out = subprocess.check_output([CLI, str(seed)], text=True)
    m = re.search(r'\{"final_hash":"([0-9a-f]+)"\}', out)
    if not m:
        raise RuntimeError("world_cli did not print final_hash")
    return m.group(1)


# Narrative episode from the task brief: walk, approach, attack, return to nest.
SHORT = {
    "ticks": 120,
    "commands": {
        0: "heading 0",
        15: "approach #1",
        35: "attack #1 bite",
        70: "go_nest",
    },
}

# Same script as apps/world_cli.c (native reference for hash parity).
CLI_SCRIPT = {
    "ticks": 300,
    "commands": {
        0: "approach #1",
        30: "attack #1 0",
        150: "flee",
        220: "go_nest",
    },
}


def main():
    if not os.path.isfile(CLI):
        check(False, f"build {CLI} first (make lib && make build/world_cli)")
        print(f"\n{len(fails)} failed")
        return 1

    a_hashes, a_final, obs = run_episode(42, SHORT)
    b_hashes, b_final, _ = run_episode(42, SHORT)
    check(a_hashes == b_hashes, "short episode is deterministic (hash sequence)")
    check(obs.get("schema") == "world-1" and "legal_verbs" in obs,
          f"observe() returns world-1 JSON (tick {obs.get('tick')})")

    cli_hashes, cli_final, _ = run_episode(42, CLI_SCRIPT)
    cli_hashes2, cli_final2, _ = run_episode(42, CLI_SCRIPT)
    check(cli_hashes == cli_hashes2, "CLI script episode is deterministic")
    try:
        ref = cli_final_hash(42)
        check(f"{cli_final:016x}" == ref,
              f"final hash matches world_cli ({ref})")
    except Exception as exc:
        check(False, f"world_cli parity: {exc}")

    if os.path.isfile(GOLDEN) and os.path.isfile(HASHES):
        w = StageWorld(seed=0)
        py_hashes, py_final = w.replay_log(GOLDEN, tick_limit=50)
        with open(HASHES, encoding="utf-8") as f:
            golden = [int(line.strip(), 16) for line in f if line.strip()]
        check(py_hashes == golden[:50],
              "replay_log matches golden hashes for first 50 ticks")
        check(py_final == golden[49], "replay tick-49 hash matches golden")

    print("\nall world smoke checks passed" if not fails else f"\n{len(fails)} failed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())