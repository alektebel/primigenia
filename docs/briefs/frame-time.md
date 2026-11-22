# Brief: frame time (the game runs at full fps on the owner's machine)

Worktree `/home/diego/Desarrollo/cpore-wt/frame-time`, branch `perf/frame-time`. Plan task T15 (frame part), pulled forward by the owner, 2026-11-22: "game is kinda laggy; how can we run at full speed and real fps?"
Read first:
- `AGENTS.md`
- `docs/plans/creature-loop.md`

You cannot commit: leave the changes uncommitted. Software GL only (`LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a`, `timeout`, `nice -n 10`); never the GPU.

## Fact (measured on the owner's machine, RTX at 35 W, Forward+, in game at the nest)
The Godot main thread is at **99% CPU** while the GPU is at about 42%: the game is **CPU-bound on the main thread**. The worker threads are idle.

## Do
1. **Profile at the nest scenario** (`godot/scenarios/creature/nest_start`, and `crowd`), headless or software GL. Read `Performance` monitors (TIME_PROCESS, TIME_PHYSICS_PROCESS, object and node counts). Use Godot's built-in profiler or manual `Time.get_ticks_usec()` buckets to split per-frame script time by system:
   - locomotion per creature (`godot/locomotion/*`: IK, support, gait)
   - actor drivers
   - camera
   - UI/HUD (`stage_ui`, minimap, legend, options)
   - flora/grass updates
   - `stage_world.gd` sampling
   - ambient and radial fauna
   - anything polled per frame (e.g. `get_nodes_in_group`, string formatting in HUDs, per-frame material updates)
   Output: a table of ms per frame per system, with creature count.
2. **Fix the top costs**, keeping visuals identical:
   - LOD for locomotion: full IK only for creatures near the camera or on screen; distant ones at a lower update rate (every 2nd–4th frame) or a cheap pose
   - skip creatures off screen (VisibleOnScreenNotifier3D)
   - cache per-frame lookups
   - stop per-frame string and HUD rebuilds when nothing changed
   - move pure-math work to WorkerThreadPool where safe
   Determinism: these are visual only; the C sim is untouched.
3. **Target** (starting values, plan T15): main-thread script time ≤ 8 ms per frame at the nest with all creatures; software-GL measurement before and after reported. A `make godot-frame-bench` target (headless, about 2 min) prints the table.
4. **Suites green:** `make godot-test`, `godot-play-test`, `godot-loco-test`, `godot-ui-test`, `godot-devtools-test`. Loco scorecard no worse for near creatures.
5. **Evidence:** `docs/evidence/godot/frame-time.md` (table before and after, what changed, the command the owner runs to see fps: the F3/monitor overlay or a printed fps line).
