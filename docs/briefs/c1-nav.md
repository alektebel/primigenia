# Task C1-nav: pathfinding for GO orders + observation v2 (C core, Python binding, Godot glue)

Worktree /home/diego/Desarrollo/cpore-wt/c1-nav, branch c1-nav (from main 89a4bbb). Read first:
core/src/stage_world.c and its header in core/include/cpore/, docs/godot/PLAN-heights.md, docs/audit/AGENTPLAY.md
(bug list + "Observations on the interface"), bindings/python/cpore/world.py, tools/agentplay/env.py,
godot/game/ (how click-to-move issues GO), docs/DEVTOOLS.md §3 rules.

## Hard rules
- Determinism (Q24) is sacred: same inputs → bit-identical hashes on every run. Integer costs, fixed tie-breaking,
  no hash maps with pointer order, no malloc inside step (fixed buffers in the world or in derived data built at attach).
- `make test` goldens: FLAT-mode goldens must stay byte-identical. If a FIELD-mode or snapshot golden must change, do it in
  a separate commit that says exactly why. Bump the snapshot version if the POD layout changes (keep the LAY checks).
- Godot rules: read /home/diego/Desarrollo/cpore-wt/_agent/briefs/godot-common.md (timeout on every Godot run,
  --check-only first, software rendering only, nice -n 10). No installs, no pushes. Small commits, each ending with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Part A: pathfinding (FIELD mode; FLAT keeps straight lines)
Today GO / GO_NEST steer in a straight line, so on the real island 10 of 20 far targets get stuck at cliffs.
1. Walk grid built once per attached field (in `cp_stage_attach_field` / restore), as DERIVED data outside the
   snapshot payload (like `field`): cells of ~4 m, 8-neighbour passability bits computed with `cp_stage_can_walk`
   between cell centres for the player's radius. Not hashed (it's a pure function of the field, which is hashed).
2. On a GO/GO_NEST order: A* over the grid with integer costs (10/14), octile heuristic, deterministic tie-break
   (lowest f, then lowest h, then lowest cell index), a node-expansion cap (e.g. 200k), then string-pull with
   `cp_stage_can_walk` line-of-sight into ≤ 64 waypoints stored in the world struct (part of the state, hashed).
   No path → reject the order with a new error code `unreachable`; target inside water/cliff → snap to the nearest
   walkable cell within 12 m first, else `unreachable`.
3. The player follows waypoints; replan if blocked for > 1 s (deterministic counter). Wild creatures' roam goals:
   only pick reachable goals (cheap check), no full A* per creature unless it's cheap.
4. Expose the current path: C getter + Python `world.path()` + a GDExtension call so the Godot game can draw it
   (a thin line/dots on the ground in debug builds; off by default, console `overlay path` toggles it).
5. Test: a C test that 20 seeded far targets on the generated island are reached (≥ 18/20, report the rest with a reason),
   timing of A* (report ms; must be < 20 ms worst case on this laptop), replay determinism with paths.

## Part B: observation v2 (schema "world-2"; keep world-1 output available behind a flag for old goldens if needed)
Fix the agentplay bugs and gaps:
- player can exceed the ±bound (seen at 195.7): clamp properly; blocked movement must never be silent.
- `last_error` persists until the next command (a step with no input must not reset it); the string command API's
  rejections must show in `observe().last_error`. `flee` with no threat → error `no_threat`.
- `blocked`: null or {"reason":"cliff|water|edge|creature|unreachable","x":..,"z":..} for the last step.
- `events`: what happened since the last observe (hit {by,target,move,damage}, kill, death, respawn, order_rejected,
  path_found, arrived), bounded ring buffer in the world struct, deterministic.
- nearby entries: add hp, hp_max, state (roam|alert|fighting|carcass|dead), and `in_fight`.
- a `world` block: bound, units ("metres, degrees, heading 0 = +z, clockwise"? — read the code and state the truth),
  nest x/z, tick rate.
Update world.py, tools/agentplay/env.py (TOP_KEYS, invariants, the prompt text describing fields), and any Godot
consumer of the observation. Then run `python3 tools/agentplay/batch.py --policy scripted --seeds 5 --turns 200`
and regenerate docs/audit/AGENTPLAY.md sections for scripted runs (do NOT run the qwen LLM batch).

## Done means
make test (goldens as above), world_smoke, make godot-test godot-play-test godot-devtools-test godot-heights-test
godot-agent-test all green; the 20-target test result; A* timings; agentplay scripted batch with zero out_of_bounds
and zero last_error_blind. Write docs/godot/NAV.md (short: design, numbers, limits). Report honestly what is
verified and what is not.
