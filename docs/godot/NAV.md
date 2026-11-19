# NAV: GO pathfinding and the world-2 observation (C1-nav)

Scope: the C world (`core/src/stage_world.c`), the Python binding, the GDExtension glue and the agent harness.
Pathfinding exists in **FIELD** terrain only (the generated island). ANALYTIC and FLAT keep the straight line (their goldens are untouched).

## Design

**Walk grid.** Cells of about 4 m (`2*bound/ceil(2*bound/4)`, 3.998 m on the 3600 m island, 897x897 cells, at most 1024x1024). Each cell has 8 passability bits
computed with `cp_stage_can_walk` between cell centres for the player's body radius, so the planner and the movement rule can never disagree about
a step. The grid is a pure function of the attached field, the obstacles and the radius, so it is **derived data**: static storage (not in the world,
not in the snapshot, not hashed), keyed by a signature of those inputs and thrown away when it changes. It fills lazily, one undirected edge at a time
(forward edges E/SE/S/SW are memoised, the others read the neighbour), or all at once with `cp_stage_nav_warm()` (620 ms on this laptop; the island scene
calls it right after reset).

**Planner** (`plan_path`, called from `cp_stage_order` for GO and GO_NEST while no fight is active):
1. a straight `can_walk` to the target needs no search: the path is the target;
2. start cell: the nearest of the 5x5 cells around the player that the player can walk to; goal cell: the nearest connected cell within 12 m of the
   target from which the target itself is walkable, else the nearest connected cell and the target is **snapped** to its centre; none -> `unreachable`;
3. A* over the grid, integer costs 10/14, octile heuristic, ties by lowest f, then lowest h, then lowest cell index (one packed 64-bit heap key), a
   120 000-expansion cap and a 2M-entry heap (the largest search seen on the island expands 23k cells);
4. string pull over player, cell centres, end point: each kept segment is validated by `can_walk` (doubling reach, then bisection), at most 64
   waypoints kept in the world struct (hashed while a path is active). If the stored waypoints run out before the goal the rest is planned when the last one is reached.

**Following.** Waypoints are taken when reached (1.5 m) or when the next one is in a clear line and the current one is within 8 m. Blocked steps are
counted (`blocked_ticks`, deterministic); after 10 ticks (1 s) the route is planned again from where the player stands, at most 4 times, then the order
is dropped with `path_failed` and `unreachable`. Re-sending the identical GO while its path runs keeps the path (clients may repeat the order every tick).
A fight clears the path; a fight ending clears the order, as before.

**Wild creatures.** A new roam goal is used only if a straight `can_walk` to it succeeds (cheap, 3 RNG draws kept); otherwise the creature stays put. No A* for wildlife.

**Determinism.** Integer costs, fixed neighbour order and tie-breaks, no allocation inside a step, no pointer-ordered containers. The path state is hashed only
while `n_path > 0`, so every FLAT/ANALYTIC hash and the `world-field-1` golden are byte-identical. Replay (`cp_stage_replay_ex`) and snapshot/restore mid-path give the same hashes (`tests/test_nav.c`).

## Observation `world-2` (`cp_stage_observe`; `cp_stage_observe_v(...,1)` gives the old `world-1`, the wasm API keeps world-1)

Top-level keys in order: `schema, tick, clock, world, own, last_error, blocked, events_dropped, events, nearby, legal_verbs, attack_moves, summary`.
- `world`: `bound` (walkable half-extent: 195 for ANALYTIC/FLAT, `half - 2*cell` for FIELD), `units` (the truth: metres; heading 0 = +z, 90 = +x, clockwise seen from above with +z up;
  `bearing` is relative to facing, positive = clockwise/right, +-180 = behind), `nest {x,z}`, `tick_hz` 10.
- `last_error`: the result of the last command. Set by `cp_stage_order` and `cp_stage_command` (text rejections included), **kept** by steps with no input, cleared by the next command. New codes: `-4 unreachable`, `-5 no_threat`.
  `flee` with no creature within 30 m: the text API rejects it with `no_threat`; the struct API (replay logs) still accepts it, so recorded logs replay unchanged, and flags `no_threat`. `flee` is not listed in `legal_verbs` then.
- `blocked`: `null` or `{reason: cliff|water|edge|obstacle|creature|unreachable, x, z}` for the last step (the refused target point). `creature` is reserved (creatures do not collide yet).
- `events` (ring of 64, deterministic, not hashed): `hit {by,target,move,damage}`, `kill`, `death`, `respawn`, `order_rejected {error}`, `path_found {length,x,z}`, `arrived`, `fled`, `path_failed`; ids 0 = player. Listed until acknowledged: `cp_stage_ack_events` (the Python `observe()` and the agent socket `observe` do it; the console `obs` does not). `events_dropped` counts events lost to the ring.
- `nearby` creatures add `hp, hp_max, state (roam|alert|fighting|carcass|dead), in_fight, attackable` (alive, and in reach of at least one of the player's attack moves: centre distance minus target body radius <= `range_m`).
- `attack_moves`: the player's attack moves, `{index, id (=index), name, stamina_cost, range_m, windup_ticks, active_ticks, recover_ticks, usable, target_in_range}`. `usable` = enough stamina and (in a fight) not mid-move, recovering or stunned; `target_in_range` refers to the nearest valid target (null if none). `attack #ID MOVE` takes the name case-insensitively or the index; an unknown move sets `last_error` `unknown_move` (code -6); a known move the player lacks stays `invalid or unavailable attack move`.
- Walkable bound: fights now clamp both fighters to `+-bound` (agentplay saw 195.7).

## API

C: `cp_stage_path`, `cp_stage_nav_cell`, `cp_stage_nav_warm`, `cp_stage_ack_events`, `cp_stage_observe_v`. Python: `StageWorld.path()`, `observe(schema=2, ack=True)`.
GDExtension: `CporeWorld.path() -> PackedVector2Array`, `nav_warm()`, `nav_cell()`, `ack_events()`. Console: `overlay path [on|off]` (off by default) draws the route (`godot/devtools/path_overlay.gd`).
Snapshot format is now **2** (the world struct grew before `field`; layout fingerprint covers the new members); the three curated scenario snapshots were rebuilt from their recipes.

## Numbers (this laptop, seed 1 island, n 1024, `make nav-test`)

- 20 seeded far targets (500-1600 m from the nest, dry gentle ground): **20/20 reached** (arrival < 3 m), 5-30 waypoints. Before: 10 of 20 grid targets stuck at cliffs. The Godot grid test (`godot-heights-test`, the same 5x4 grid as before) also reaches 20/20.
- Rivers (terrain v4): deep river cells (1.2 m, > 0.7 m) are one cell wide and carved diagonally, so a plan could thread the corner between two of them and the steering body (yaw inertia) then drove into the channel and stalled (5/20 on seed 1 after the C1 + hydrology merge). `walk_ok` (planner, shortcuts, waypoint following) now also requires blocking water to be at least body radius + 1 m away on both sides of the line (`water_clear`, field terrain only). Streams and shallow fords (depth <= 0.7) stay walkable; deep cells stay blocked until swimming (C4). Seed 1: 20/20, seed 7: 20/20, seed 42: 19/20; the island keeps 99.99% of its land reachable at cell level (4-connected, deep blocked), so no extra fords are needed.
- Plan time with the lazily filled grid (cold, includes cell fill): mean 8.0 ms, **worst 25.9 ms** (over the 20 ms goal); with the grid warm: **worst 3.4 ms**, mean 1.5 ms; full warm 620 ms once at load. Unreachable sea target: 0.03 ms.
- Static memory of the planner: about 29 MB of BSS (untouched pages cost nothing); none in wasm.

## Limits

- First-time plans on a cold grid can exceed 20 ms; the game warms the grid at load. Non-island worlds that set a FIELD without `nav_warm` pay lazily.
- One shared grid (single signature slot): two worlds with different fields or player radii in one process alternate and rebuild it. Not thread safe.
- Segments are checked by the centre line only (like movement); the body is not swept except against obstacles.
- A target in a pocket enclosed from the player costs up to 120k expansions (~15 ms warm) before `unreachable`.
- Replans are bounded (4); a creature standing on the route is not an obstacle.
- The Python harness runs ANALYTIC terrain, so agentplay does not exercise the pathfinder.
