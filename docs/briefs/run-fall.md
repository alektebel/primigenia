# Brief (Codex): running and fall damage in the C sim
Worktree `/home/diego/Desarrollo/cpore-wt/run-fall`, branch `c2/run-fall`. **Your sandbox cannot write git metadata and has
no X11: do NOT commit or take screenshots.** Leave work uncommitted and write `docs/RUN-FALL-REPORT.md` (intended commit
messages, what you verified, open questions). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.
Owner: "I want to have the option to run." "I want to be able to fall and receive damage if I go to terrain too vertical."
Read `core/src/stage_world.c` (walk, steering, planner, `walk_ok`, slope rules, player exemption), `core/src/steer.c`,
`docs/godot/LOCOMOTION.md` §8 (slope ceiling 1.26), `docs/godot/NAV.md`, the Godot binding (`godot/extension/`, `CporeWorld`),
the Python binding, `tests/`.
S1 Run: player run toggle (`cp_stage_set_run(world, on)`), speed ×1.8 of the body's walk speed (morphology based), stamina
0–1000 drains while running and moving, regenerates when not, can't start running under 150; exposed in observation/state
(`player.running`, `player.stamina`) and Godot binding `CporeWorld.set_run(bool)`; wild creatures already have flee/charge speeds,
leave them. Goldens must stay byte-identical when run is never toggled.
S2 Falling: when the player steps onto ground steeper than its climb limit (per morphology, ceiling 1.26) or walks off a drop,
it slides/falls instead of walking: a deterministic fall state with vertical velocity under gravity in fixed point, landing when
it meets the ground; damage = max(0, (drop − safe_drop(body)) × k) with safe drop ≈ 1.5× leg length; event `fell {drop_cm, damage}`;
death by fall goes through the existing death/egg path. Remove the player's slope exemption only for direct (WASD/steer) movement;
planner routes must still avoid steep cells (routes 288/288 per seed must stay green). Godot side: a minimal hook so the island
reads `player.falling` (another agent does animation).
Tests in `make test` for every rule (stamina drain/regen, threshold, run speed, slide on steep, fall damage curve, no damage under
safe drop, death by fall, determinism), plus `make smoke`, `make tourney`, routes. Godot: headless `--check-only` only.

## Integration note (added after Codex launch, apply when integrating)
Fall damage must be computed from the vertical impact speed converted to an equivalent drop (v²/2g), not from the height
difference, so gliding and flaring (motion-flight-plan.md §3c, decision D8) reduce damage correctly.
