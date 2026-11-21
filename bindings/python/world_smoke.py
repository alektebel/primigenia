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
            command = script["commands"][tick]
            rc = w.command(command)
            # world_cli records rejections and still steps. During Garfio's grace,
            # this narrative can end a fight before tick 150, leaving no threat.
            assert rc == 0 or (command == "flee" and rc == -5), (tick, command, rc)
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
    check(obs.get("schema") == "world-2" and "legal_verbs" in obs and obs["world"]["bound"] == 195.0,
          f"observe() returns world-2 JSON (tick {obs.get('tick')})")
    w1 = StageWorld(seed=42)
    o1 = w1.observe()
    mv = o1["attack_moves"]
    check(mv and all(list(m) == ["index", "id", "name", "role", "stamina_cost", "range_m", "windup_ticks", "active_ticks",
                                 "recover_ticks", "cooldown_ticks", "cooldown_left", "equipped", "slot", "usable",
                                 "target_in_range"] for m in mv),
          "observe().attack_moves lists index, name, role, cost, range, ticks, cooldown, equipped, slot, usable")
    check(o1["loadout"] == {"slots": ["bite", "charge", "spit", "tail_strike"], "signature_slot": None, "can_edit": True,
                            "nest_radius_m": 12.0} and o1["known_moves"] == ["bite", "charge", "spit", "tail_strike"]
          and "loadout" in o1["legal_verbs"], "observe() carries the loadout, known_moves and offers the loadout verb at the nest")
    check(w1.command("loadout 1 none") == 0 and w1.observe()["loadout"]["slots"][0] is None, "loadout SLOT none empties a slot")
    check(w1.command("attack #1 bite") < 0 and w1.observe()["last_error"] == "not_equipped", "an unequipped move gives not_equipped")
    check(w1.command("loadout 1 bite") == 0 and w1.command("attack #1 bite") == 0, "the move can be slotted back and used")
    check(w1.command("loadout 9 bite") < 0 and w1.command("loadout 1 guard") < 0 and w1.observe()["last_error"] == "unknown_move",
          "bad slot and non-attack moves are rejected")
    w1.reset(42)
    check(all("attackable" in n for n in o1["nearby"] if n["type"] == "creature"), "nearby creatures carry attackable")
    check(w1.command("attack #1 BITE") == 0 and w1.command("attack #1 0") == 0, "attack accepts name (any case) or index")
    check(w1.command("attack #1 atack") < 0 and w1.observe()["last_error"] == "unknown_move", "unknown move gives unknown_move")
    check(w1.observe(schema=1).get("schema") == "world-1", "observe(schema=1) still gives the world-1 text")
    check(w1.command("dance") < 0 and w1.observe()["last_error"] != "ok", "a rejected text command shows in observe().last_error")
    w1.step(None)
    w1.step(None)
    check(w1.observe()["last_error"] != "ok", "last_error survives steps with no input")
    check(any(e["type"] == "order_rejected" for e in w1.observe(ack=False)["events"]) is False,
          "events are listed once: the second observe() starts empty")
    check(w1.path() == [], "path() is empty outside FIELD mode")

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

    w = StageWorld(seed=1)
    check(w.observe()["player"] == {"running": False, "stamina": 1000, "falling": False,
                                   "y": w.observe()["player"]["y"], "vertical_velocity": 0},
          "run/fall defaults exposed")
    w.set_run(True)
    check(w.observe()["player"]["running"], "set_run reaches C")
    w.step("heading 0")
    check(w.observe()["player"]["stamina"] < 1000, "running movement drains stamina")
    w.set_run(False)
    check(not w.observe()["player"]["running"], "run release reaches C")

    print("\nall world smoke checks passed" if not fails else f"\n{len(fails)} failed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())