# A59 — slope grip by adaptations

2026-11-23. Branch `sim/slope-grip`, based on main `2d70fde` plus brief `6c2410f`. **Uncommitted; owner tracker confirmation and Claude review/merge remain pending.** No Space/jump input changes.

## Starting values (owner A59; validate with tracker A59)

All numbers below are game tuning starting values, not measured animal traction. Tests: `tests/test_world.c` (profile arithmetic/hash), `tests/test_run_fall.c` (holding/slipping/impact), `tests/test_steer.c` (planning and movement), and `godot/game/tests/test_grip.gd` (editor/live/replay agreement).

| Trait | Rule | Starting value |
|---|---|---:|
| Plain body | No grip adaptations | 35° |
| Digging claws | `excavadora`, presence only | +10° |
| Ground-reaching grasper | `arm_grasper`, estimated reach ≥ ground distance | +8° |
| Adhesive contacts | `leg_sucker`, `foot_gecko`, radial hydrostat/tubefeet arms | +20°, minimum 75° |
| Many legs | At least 6 actual contacts (mirrored pair = 2; single = 1) | +8° |
| Low sprawl | Lateral foot offset ≥ 0.4 × vertical reach; stance ≤ 3 × largest spine radius; spine height range ≤ 2 × that radius | +5° |
| Prehensile tail | Explicit `CP_GRIP_TAIL` profile flag; no existing weapon/paddle tail is mislabeled prehensile | +5° |
| Heavy body | Resolved body radius > 2 m | −5° |
| Hooves | `pezuna`, `foot_hoof` | −5° |
| Other parts | Wings/flippers, horns, jaws, weapons, etc. | 0° |
| Cap | Ordinary / adhesive | 70° / 80° |

The claw-holds-50° example uses the **same low sprawler** before/after claws: 40° → 50°. A plain upright body with claws reaches 45°. Adhesion needs the 75° floor to satisfy the requested 75° example; 35 + 20 alone would only give 55°.

Grasper reach is a conservative starting approximation: `size × 1.5 ≥ maximum leg vertical reach + spine height range`, with legs present. It is derived in C from the genome and does not depend on rendered pose. Existing starter D's short arms do not qualify. Tune this with the owner's A59 ground-contact trial; do not infer grip from the combat claw-swipe ability.

No substrate map is exposed to the simulation's attached heightfield. The hoof penalty conservatively applies everywhere for now (including rock), rather than guessing rock from visuals. Prehensile tails have no existing catalog part; their profile flag is supported, and the current tail weapons grant no traction bonus.

## Starter limits (measured through the C projection and Godot bridge)

| Starter | Contacts | Adaptation | Grip |
|---|---:|---|---:|
| A grazer | 4 | Hooves | 30° |
| B runner | 4 | Hooves | 30° |
| C sprawler | 4 | Low sprawl | 40° |
| D knuckle | 4 | Short graspers do not reach by the starting rule | 35° |

## Part limits

Individual part contribution on a plain four-contact, light body (foot rows mean replacing feet; adding enough leg pairs also grants the separate ≥6-contact bonus). Bonuses never stack per copy or combat level.

| Part | Grip with this adaptation |
|---|---:|
| `fauces` | 35° |
| `romo` | 35° |
| `pico` | 35° |
| `ojo` | 35° |
| `tallo` | 35° |
| `antena` | 35° |
| `trompa` | 35° |
| `pinzas` | 35° |
| `oreja` | 35° |
| `pata` | 35° |
| `zanca` | 35° |
| `pezuna` | 30° |
| `asta` | 35° |
| `aguijon` | 35° |
| `cuerno` | 35° |
| `pua` | 35° |
| `maza` | 35° |
| `placa` | 35° |
| `cresta` | 35° |
| `bulbo` | 35° |
| `aleta` | 35° |
| `excavadora` | 45° |
| `eye_stalk` | 35° |
| `eye_triad` | 35° |
| `jaw_nipper` | 35° |
| `horn_crown` | 35° |
| `shell_plate` | 35° |
| `leg_sprinter` | 35° |
| `leg_sucker` | 75° |
| `arm_grasper` | 43° if reaching; otherwise 35° |
| `tail_paddle` | 35° |
| `tail_spike` | 35° |
| `wing_glider` | 35° |
| `frill_fan` | 35° |
| `beak_crusher` | 35° |
| `mandible_shear` | 35° |
| `snout_trumpet` | 35° |
| `tongue_spring` | 35° |
| `sac_spitter` | 35° |
| `arm_smasher` | 35° |
| `foot_spring` | 35° |
| `foot_hoof` | 30° |
| `foot_gecko` | 75° |
| `lure_lantern` | 35° |
| `wing_insect` | 35° |
| `tail_hammer` | 35° |
| `espinas_dorsales` | 35° |

## Simulation and compatibility

- `cp_stage_grip_project` projects contact traits and contact count in C; `cp_stage_grip_deg/grade` compute the limit. Fixed polynomial sine/cosine avoids platform libm trig. The old exact `1.26f` grade is retained for a hypothetical 51.6° profile; the current integer-degree tuning does not produce that value.
- Steering retains the original comfortable uphill climb/stall limits, capped by grip. Full-gradient holding, fall-line sliding and uphill refusal use the creature's grip. Planning and shortcuts retain the original conservative contour margin (`climb × stall_mul × slide_mul`), capped by grip. Nav cache signatures include grip; slope cost scales with `1.26 / grip_grade`.
- Above grip, the player and wildlife use integer mm gravity and impact speed. Contact friction bounds retained vertical slide velocity to measured descent, at most 5 m/s (starting value; slide/cliff regression). Leaving contact becomes a free fall. A31 keeps 10 HP/m beyond safe drop, its 60% cap and free-fall exception. Wildlife without a retained genome uses A31's existing `3 × radius` safe-drop fallback.
- A fight cannot start with an airborne/sliding creature, so an encounter cannot freeze its fall. Wildlife roam/chase/flee goals use grip-aware straight reachability checks; this AI has no A* route planner. Unreachable goals are held instead of walking up the forbidden slope. The player A* checks all sampled segment gradients and lateral clearance. A planned walk interrupted by slipping reports an unreachable path.
- Godot exposes `grip_deg` and `sliding` on live entities/player state and profile output, and forwards them in animation samples. The studio shows `Grip: N°`. The first player slip displays the requested hint once per stage UI instance; wildlife landings do not trigger the player's landing effect.
- Snapshot **12** adds profile grip/contact fields and wildlife integer fall state; layout fingerprint includes those fields. No event ids added. Hashes include adaptation and airborne state. Five world golden hash files regenerated for the final mechanics; combat goldens unchanged. Godot text logs use an optional `grip` header in v3/v4, read by both Godot and world_cli.
- Terrain/placement fixture JSON and terrain hashes are unchanged. Route/navigation connectivity benchmarks now explicitly use adapted reference profiles. Plain 35° feet rejected 16/20 far targets on seed 1 during development; this is an intended traversal restriction, not certified universal starter access. The final adapted navigation benchmark reached 20/20. The route matrix still checks nine sizes/leg counts, exact replay, water exclusion, and the profile's own maximum grade.

## Validation

- Run/fall: PASS, including 50° plain/clawed sprawler, 75° sucker, player and wildlife sliding over a cliff, nearby encounters not freezing falls, A31 cap/free fall, snapshots/replay.
- Steering: PASS, 259 checks; lower-grip planner rejection and higher-grip reachability included.
- World: PASS, including profile arithmetic/hash, golden replay, snapshot rejection/restore, and field movement.
- Navigation seed 1: PASS, 20/20 adapted far targets; replay and snapshot restored mid-route.
- Radial plan cases: PASS, 32; adhesive radial grip is the only permitted profile difference, combat stats/part costs stay equal.
- Godot play: PASS, 239 checks, 0 failures (software/headless).
- Godot studio: PASS, 932 checks, 0 failures; web validator cross-check: 45 files, 0 failures. Test fixture root now resolves from its script location, so the harness also works from the main project.
- Focused Godot grip bridge: PASS, 0 failures; all 4 starter live/preview limits agree, and their exported logs replay to identical world_cli hashes.
- Godot extension built using a `/tmp` copy of the existing godot-cpp checkout because its shared location is read-only in this sandbox; no installation performed. Check-only passes for changed test entry points.
- **`make test`: PASS (exit 0)** on the final C source, including the encounter fall guard. Core/combat/world/fall/steer/nav/terrain/social/parts/plan/secrets/first-quest checks and every golden replay passed.
- Final route run used `BASH_ENV=/tmp/grip-parallel-env make test SHELL=/bin/bash` with a 4-hour timeout. The temporary shell helper only ran the three existing route commands concurrently and waited for every exit status; no cases, assertions, or replay checks were skipped. Ordinary `make test` runs the same matrices sequentially.

| Final route matrix | Reached | Replay |
|---|---:|---|
| Seed 1, nine bodies | 288 / 288 | Every trajectory identical |
| Seed 7, nine bodies | 288 / 288 | Every trajectory identical |
| Seed 42, nine bodies | 288 / 288 | Every trajectory identical |
| Total | **864 / 864** | **PASS** |

The initial seed-7 failures for the largest biped were fixed by restoring the planner's conservative contour margin while capping it by actual grip; the baseline comparison and focused 32/32 rerun confirmed the diagnosis. The full final matrices above validate the correction.

- Xvfb **blocked**: cannot bind UNIX/display sockets; Godot reports no available display server. Rendered captures and the motion L0 visual scorecard could not run. Headless tests completed. Engine resource/RID warnings appear at shutdown after passing Godot suites.

## Handoff

Leave these changes uncommitted as requested; Sonnet commits and Claude reviews/merges after the owner's A59 tracker confirmation. Main `2d70fde` is already an ancestor of this branch. Coordinate snapshot **12** and the fall code with parallel `feat/jump`; no new event ids or jump bindings are used here.
