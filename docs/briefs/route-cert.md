# Brief: route certification for the creature stage (risk C1 of docs/RISKS-CREATURE-GPT.md)

Worktree `/home/diego/Desarrollo/cpore-wt/route-cert`, branch `c2/route-certification` (from main). Work only here.
**Your sandbox cannot write git metadata and has no X11:** do NOT try to commit or take screenshots. Leave all work
uncommitted in the worktree and write `docs/ROUTES-REPORT.md` (intended commit messages per slice, what you verified,
what is left). Claude will commit and review. Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.

Read: `docs/RISKS-CREATURE-GPT.md` (C1 "Matching terrain is not navigable terrain"), `docs/godot/NAV.md`,
`docs/TERRAIN.md` (v4 rivers, guarantees per seed), `docs/godot/LOCOMOTION.md` §8 (steering v3, climb by legs, slide,
slope ceiling 1.26 for wild creatures, player exempt), `core/src/stage_world.c` (nav grid, `nav_astar` ~l.406,
`plan_path`, `walk_ok`, `water_clear`, `cp_stage_can_walk`, `walk()`), `core/src/steer.c`, `tests/test_nav.c`.

Other agents: `c2/lineage-cousins` (Sonnet) is merging lineage work that touches `stage_world.c` (ledger hooks, evolve,
cousin spawn). Keep your `stage_world.c` changes confined to the nav/planner functions and `walk_ok`, small and
isolated, so the later merge is easy. Put new logic in new files where possible (e.g. `core/src/routes.c`).

## S1: Certified route set (C test plus tool)
- Define the curated region's required places for seed 1 (and check 7, 42) as data, e.g. `tests/routes/seed1.json`: nest/start,
  spring/water, the start valley, Garfio's area, each herd's home range (Rondo, Zanco, Espinodo), the lake shore, the river
  gap, the hidden cave entrance and fossil sites if they exist in data (else mark TODO with coordinates proposed from the
  terrain features), the crater rim, the meteor shard positions if defined.
- `routes_test` (in `make test`): for each required ordered pair, both directions, plan and **simulate** the walk with the real
  steering for the default player body and for each leg class (2, 4, 6, 8 legs; small and giant radius), with no teleport.
  Assert arrival within a tick budget. Report per route: reached, ticks, path length, max grade met, ford crossings, stalls
  and replans. Deterministic.
- A tool (`tools/routes/report.py` or a `world_cli` mode) prints a table and writes `docs/evidence/routes/seed1.md`.

## S2: Close the player's slope gap
Today wild creatures never rest on ground steeper than 1.26 (51.6°), but the player is exempt because the planner's
routes cross river-bank facets steeper than that. Fix it properly: the planner and `walk_ok` use the same grade rule as the
body (per-morphology climb, ceiling 1.26), so routes go around steep banks. If a required route then fails, add the
minimal deterministic fix (e.g. treat ford cells as gentle crossings, or a bank-gentling pass in the river carve kept
under the TERRAIN.md limits). Then remove the player exemption. NAV gate must stay at least 18/20 (report the number), `steer_test` green,
`godot-heights-test` must not regress (you cannot run Godot with a display; run what is headless, say what you could not).

## S3: Arrival and blocked feedback
Orders report arrival or blocked results (risk C1 mitigation): make sure GO completion ("arrived") and failure
("blocked: reason") are visible as events in world-2 for agents and UI (check what exists: `blocked`, `last_error`,
events). Add only what is missing; keep event schema compatible.

## Rules
Determinism: integer/fixed math, `+ - * / sqrtf`, no libm trig. Goldens: if a sim-affecting change alters hashes,
regenerate once and document why in ROUTES-REPORT.md. `make test`, `make smoke`, `make tourney` must pass. Report the
cold and warm plan times.
