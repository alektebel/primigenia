# Integration QA, 2026-11-19 (main after social loop, steering v3, lineage, diegetic UI, realism, terrain v5, rivers, clouds)

Two passes: the qwen3.6 agentplay batch on the C world, and a scripted ten-minute play of the real Godot island.

## 1. agentplay (tools/agentplay, NAN qwen3.6, 2 concurrent, 70 turns, seeds 1-5)

Two batches of 20 episodes (friend, chaos, fighter, explorer). Batch A is the unchanged harness. Batch B has the island herds
(`AGENTPLAY_HERDS=1`, new): Rondo x4 at ~24 m, Zanco x4 at ~34 m, Espinodo x3 at ~45 m around the nest, so the social verbs have
someone to talk to (the harness world only held Garfio, so the friend persona could never bond anyone).

* No invariant failure in either batch (NaN, hp range, teleports, tick monotonic, determinism replay 20/20 ok, no dead creature moving).
* **Harness drift (fixed, tools/agentplay/env.py):** `TOP_KEYS` lacked the new top-level `lineage` key, so every episode reported a
  `schema_drift` bug (20/20 in batch A). Added `lineage` after `world`.
* **Batch B friend persona:** 31 / 19 / 34 / 8 / 31 social skills performed, 1 bond_made (seed 3), 20% "win"; the model keeps
  being interrupted by Garfio (aggressive, 18 m from the nest): deaths 2.4 per episode, 100% of episodes died at least once.
  That is game design, not a bug, but the first Garfio is the only thing the text agent meets by default.
* **Low: inconsistent error for an order during a fight.** While the player is in a fight, `befriend/observe/gift #other` return
  -14 `in_fight`, but `approach #other` returns -2 "invalid or unavailable target" (24 rejected approaches in batch B, one episode
  repeated it 20 times because the message says nothing). Repro (verified): `AGENTPLAY_HERDS=1`, seed 4: `attack #1 bite`, run 20
  ticks, then `approach #3` -> -2 while `befriend #3 sing` -> -14. Suggest the same `in_fight` code for approach.
* **Low (model error, not a bug):** `pose #1` (6 times) and `approach 1` without `#`: the model treats a befriend skill as a verb.
  The prompt lists `befriend #ID pose`; a hint in the error ("did you mean befriend #1 pose?") would help.
* Chaos persona: 82% rejected commands by design; all rejections are well-formed errors (`unknown_move`, `invalid slot`,
  `invalid command or value` for 90-digit numbers), no crash, no state corruption.
* Usability themes are as in AGENTPLAY.md (rejected-command feedback unclear 17/20, no outcome field 13/20).

## 2. Godot soak (godot/game/tests/island_soak.gd, `make godot-soak`)

Real island (seed 1), real input (`Input.parse_input_event` keys and mouse), real UI and C world. Stages, all asserted:
befriend a Rondo to trust 60 with an in-rhythm skill and a `bond_made` event; observe a Zanco chain (three clues teach a
move); fight and kill a Garfio; eat its carcass (food 59 -> 99); family tree opens and closes with T; Esc menu, settings column
(14 rows, every choice row changed); hold-to-follow (15.9 m walked); far click sets a destination and the move marker; cross a
ford (found by rule on the river classes) ; then 10.2 simulated minutes of random walking with the wild awake. Checks: no NaN/inf
in any host or player position every frame, finite positive host scales, frame-time sanity.

* Headless, `--fixed-fps 60`: 10.2 sim min in 67 s, 9380 frames, 27 checks, 0 failures, no SCRIPT ERROR.
* Software GL under xvfb (1280x720, llvmpipe, machine under load average 15+): the full stage run works and writes the strip in
  docs/evidence/godot/soak/. Software rendering plus a C sim at x6 reaches ~3.6 ticks/s wall, so a full 10-minute windowed
  run takes about 40 minutes; the windowed strip uses `MINUTES=2.5`. Not a game fault (an RTX is not available here).
