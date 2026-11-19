# Dev tools of the creature stage (DT0, C0)

Implements `PLAN-devtools.md` and `PLAN-heights.md`. Code: `godot/devtools/`, C: `core/src/stage_world.c`.

## Interfaces
* **C world:** `cp_stage_snapshot/restore` (raw POD copy, 48-byte header with layout fingerprint), `cp_stage_debug` (teleport, spawn,
  kill, heal, clock, flags god / ai off, param), `CP_STAGE_PARAMS`, `cp_stage_replay_ex`, FIELD terrain (`cp_stage_attach_field`,
  `cp_stage_water_depth`, `cp_stage_bound`). Debug ops, per-world motion and the field hash enter `cp_stage_hash` only when they differ
  from the default, so the committed goldens, `make tourney` and the feel numbers are byte-identical.
* **Logs:** `CPORE_WORLD_LOG 3` = v2 body + optional `snapshot <file>` and `field <seed> <n> <size> <hash>` lines after the header and a
  debug-op section after the inputs. `world_cli --replay` reads v2 and v3 (strict: a rejected op is an error) and regenerates the island
  from the `field` line; `world_cli --field <seed> <n> <out.log>` records one.
* **Godot bridge:** `CporeWorld` snapshot/restore/debug/params/set_field; `StageWorld` debug queue, `debug_now`, `queue_order`, snapshot
  ring, time control, v3 export.

## Keys (InputMap actions, physical keycodes; the legend shows the real label)
F1 legend in all builds: hold = the key sheet (a veil with Alegreya text and outlined key caps, no panel; the menu's "Keys" pins it until Esc). The corner hint is off by default since the diegetic UI (docs/godot/UI-DIEGETIC.md; `legend.corner_visible`, a tap on F1 still toggles it); the onboarding hints replace it in play (D13 is the sheet only). `legend.json` lists `journal` (J) and `family_tree` (T) and the four ring gestures of the `radial` context; the `radial_*` letter actions are gone. Dev builds: console on the key left of 1 or F12; F2 sites picker, Ctrl+B
bookmark; F3 tuning panel, F4 swap A/B; F5 quick save, F6 scenario picker; F8 feedback; P pause, `.` step, `[` `]` timescale.
Reserved, not bound: F7 free camera, F9 scrubber, F10 overlays.

## Formats
Scenario: `<name>.json` (`primigenia.scenario/1`) + `.cpstate` + `.log` recipe; saves are scenarios with `kind: "save"` in
`user://saves/slot1` (pause menu Save game / Load game). Tuning diff: `primigenia.tuning/1` in `godot/tuning/` or `user://tuning/`.
Feedback bundle: `feedback/<stamp>/` (git-ignored) with screenshot, scenario, replay.log + replay.hashes, tuning, meta, log.txt.
Agent socket: `godot/devtools/agent/PROTOCOL.md`; Python client `agent/client.py`.

## Curated scenarios (`godot/scenarios/creature/`)

Regenerate after terrain or engine changes: `godot --headless --path godot --script res://devtools/tools/make_scenarios.gd`.

| Scenario | What to test here |
|---|---|
| `nest_start` | Fresh game at the nest with Garfio at home: baseline movement, nest and first quest beats. |
| `garfio_close` | First meeting 8 m from Garfio: opening attack timings, combat tuning, chase camera. |
| `far_meadow` | Remote slope with no creatures: island scale, heightfield and camera on inclines. |
| `cliff_crossing` | Player below a cliff with an active GO to the rim: `overlay path`, A* detours and waypoint following. |
| `water_edge` | Shore GO to dry ground across shallow water: unreachable snap, `last_error` and `blocked` readouts. |
| `garfio_low_hp` | Garfio near death, player full: finisher moves, kill events and fight teardown. |
| `player_low_hp` | Player nearly dead beside Garfio: flee, death, respawn and panic UI. |
| `dusk_meadow` | Far meadow at 19:30: sun angle, ambient colour and time-of-day on slopes. |
| `crowd` | Several Garfios around the nest: nameplates, icons and camera readability in a cluster. |

## Owner-question defaults (single settings in `dev.gd`)
Dev tools on in every debug build (`--dev` / `--no-dev`); console on the key left of 1 and F12; feedback in repo `feedback/` falling
back to `user://feedback/`; raw snapshots with recipes; fights next to cliffs stop at the edge; island mode stays out of WASM and
Python in C0; caves unwalkable.

## Verified
`make test` (new: golden logs + snapshot round trips, field mode, field fights, debug ops, world-debug-42 and world-field-1 goldens via
world_cli), `make tourney` identical, `make godot-test`, `godot-play-test`, `godot-ui-test`, `godot-feel-test` (numbers unchanged),
`godot-devtools-test`, `godot-heights-test`, `godot-agent-test`. Not verified: WASM build (no emcc here), interactive use of the
dialogs on a real display (only software screenshots), the F5 quick-save write path in an exported build.

## Known limits
GO orders plan around cliffs (A* on the walk grid; 20/20 far targets reached on the island, `docs/godot/NAV.md`); `tp` into water or an obstacle is refused;
thumbnails in the picker are DT1; `tune`/scenario loads of another island regenerate it only through the cache.

## Locomotion zoo (`devtools/zoo/`)

Console: `zoo [mite,trotter,hero,giant,longneck,centipede,hexapod | all] [figure8|zigzag|steps|uturn|ramps|all]`, `zoo exit`
(or Esc). Standalone: `godot --path godot res://devtools/zoo/zoo.tscn -- --zoo=mite,giant --course=uturn`. Each creature has its
own C world on one synthetic field (lanes 24 m wide; ramps of 10, 20, 30, 40 and 50 degrees, a stair pyramid, a slalom, a U-turn
lane, a figure-8) and runs the same scripted orders, so you watch the real steering. HUD per creature: legs, radius, speed, yaw
rate, turn radius, grade, state (run, turn, pivot, climb, descend, stalled, slide). Keys: Space pause, +/- speed, 1-9 follow, 0 all.
Bodies are the Merodeador scaled or re-legged (`zoo_genomes.gd`). Test: `test_zoo.gd`; evidence: `devtools/tests/zoo_evidence.gd`
(`make godot-zoo-evidence`).
