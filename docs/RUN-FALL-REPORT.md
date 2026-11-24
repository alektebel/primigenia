# Running and fall damage

Worktree: `/home/diego/Desarrollo/cpore-wt/run-fall`, branch `c2/run-fall`.
Changes are intentionally uncommitted. No screenshots or graphical Godot runs were made.

## Intended commits

1. `feat(sim): add player run toggle and locomotion stamina`
2. `feat(sim): simulate direct-movement falls and landing damage`
3. `feat(bindings): expose run and airborne player state`
4. `test(sim): cover running, falling, eggs and deterministic continuation`

These are proposed messages; no commits were created.

## Behavior and API

- `cp_stage_set_run(world, on)`, Python `StageWorld.set_run(bool)`, Godot `CporeWorld.set_run(bool)`.
- Running targets 1.8 times the body's existing walk speed (`profile.speed * motion.jog_k`), retaining steering, acceleration, braking and slope speed factors. Wild speeds and `steer.c` are unchanged.
- A separate integer locomotion stamina starts at 1000. Running movement drains 10 per tick (100/s); other ticks regenerate 5 (50/s), capped at 1000. Starting requires at least 150. Exhaustion releases the toggle. Combat, falling, death and respawn prevent starting it. Combat stamina and legacy `sprint` inputs retain their existing behavior.
- Observation schema 2 and Godot state add `player: {running, stamina, falling, y, vertical_velocity}`. Existing `own.stamina` / entity stamina remain combat stamina. Heights are metres; vertical velocity is m/s.
- Direct `HEADING` movement can enter a facet beyond `min(body.climb, 1.26)` and then falls/slides downhill, including along a contour or into an uphill bank. A downward discontinuity exceeding the climbable step also starts a fall. Planner, shortcuts and GO following retain their existing restrictions; falling cannot be cancelled with a GO or combat order.
- Airborne height and velocity use integer millimetres and mm/s, with trapezoidal gravity at 10 Hz (velocity -981 mm/s per tick, height advances by the mean velocity). Damage uses the impact speed as an equivalent drop v²/2g (D8). Horizontal inertia persists; contact with a steep facet redirects motion downhill. Water, obstacles and world bounds still block horizontal movement. Landing requires contact with ground the body can hold.
- Landing emits `fell {drop_cm, damage}` in the normal observation event ring (`move` carries drop in cm; `value` carries damage in C). Damage is 20 HP per metre beyond the safe drop; debug GOD suppresses it. The fall begins at takeoff height and tracks any higher contact before landing.
- Safe drop is 1.5 times mean leg length of the current confirmed genome, using the same `|k| + |f-k|` bone lengths as the rig. Legs with implicit geometry use the rig defaults. Legacy setups without leg geometry use a leg-length proxy of twice collision radius (safe drop = three radii).
- A lethal landing invokes `cp_stage_parts_death`, clears the order/path, and emits the existing death event. The existing egg, hatchling, respawn and last-egg loss behavior is retained.
- Godot's stage sampler interpolates C airborne height. The island forwards `sm.falling` to the player animation consumer; animation changes remain outside this task.
- Run and airborne state are included in hashes when non-default, and in snapshots. Snapshot format is now **8**, with all new members in the layout fingerprint; older snapshots must be rebuilt from recipes. At default run state, no extra hash fields are appended.

## Verification

- Tests were added first; the initial build failed on the missing API/state as expected.
- `tests/test_run_fall.c`, included in `make test`, passes. It covers run speed, drain, regeneration, 149/150 threshold, exhaustion, stationary recovery, uphill entry, contour sliding, morphology and ceiling, safe landing, damage curve (including a 6000 m drop with no arbitrary damage cap), actual genome leg lengths, death, egg consumption, respawn, last-egg loss, observation events, and tick-by-tick snapshot continuation during both running and falling.
- `steer_test` passes **260 checks**. Its former direct-input stall assertion now checks that the two-legged body slides back instead of traversing the ramp; planner refusal assertions are unchanged.
- `make smoke` passes, including new Python run-toggle/state/drain checks.
- `make tourney` passes all existing balance gates.
- All five native world golden replays match their committed hashes. No golden files were modified.
- Targeted gcov run/fall integration coverage: **50/54 executable lines (92.6%)** for setter/collision/fall helpers and **29/29 (100%)** for direct entry. This is coverage of those source regions, not overall core coverage. Artifacts are in `build/run-fall-coverage/final/`.
- The Godot extension compiles and links against the existing godot-cpp static archive. Compilation wrote only this worktree's output, avoiding SCons writes into the external dependency checkout.
- `godot --headless --path godot --log-file /tmp/run-fall-godot.log --check-only --script res://game/stage/stage_world.gd` passes with the rebuilt extension.
- Standalone island `--check-only` reaches a pre-existing autoload dependency limitation: `Identifier not found: Game` at `island.gd:94`. The same occurs with `--editor --check-only`. This is not a successful island parse check. No scene execution, import command, screenshots or X11 were used. Local ignored extension/class caches were prepared for standalone checking.
- `git diff --check` passes.

`make test` passes, including routes **288/288** for each of seeds **1, 7 and 42**, with every route trajectory replayed identically. After removing the arbitrary upper damage clamp, run/fall and steering tests and Python smoke were rerun successfully; this final arithmetic change does not affect planner routes. Local logs are retained in `build/run-fall-verification/` (ignored build artifacts).

## Open questions / integration limits

- Owner feel/balance remains untested: 10-second full-stamina run, 20-second empty-to-full recovery, 20 HP/m damage, and the legacy radius-based leg-length fallback are explicit tuning choices.
- This delivers the requested run API. The existing Shift/`sprint` input remains the legacy action; a UI caller must invoke `set_run` to opt into the new stamina system. When wiring that control, record toggle calls alongside inputs or start replay from a snapshot: the existing v3 text input log does not encode standalone setter calls.
- Visual animation and full-scene Godot verification need the animation/integration agent; only C height following and the island's falling hook are included here.
- Old curated binary snapshots were not regenerated; format 8 rejects them explicitly. Native input-log goldens remain valid.
