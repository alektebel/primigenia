# Brief T2: island load time (creature loop plan `docs/plans/creature-loop.md`)

Worktree `/home/diego/Desarrollo/cpore-wt/load-time`, branch `perf/load-time`. Read first:
- `AGENTS.md`
- `docs/plans/creature-loop.md` (finding 1, T2)
- `godot/game/island/island.gd` (`build()` phases, `_slice()`, `Game.report_entry`)
- `godot/game/loading/entry_veil.gd`
- `godot/game/stage/stage_setup.gd`
- `godot/game/island/radial_fauna.gd`
- `godot/game/actors/actor_host.gd`
- `godot/creature/creature_materials.gd`
- `project.godot`

You cannot commit: leave the changes uncommitted and say so. Software GL only (`LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a`, `timeout`, `nice -n 10`); never the GPU.

## Facts
- The owner's RTX (Forward+): entry takes 46 s, with stage_setup 15.7 s and creatures 19.9 s.
- Software GL: 11–18 s, with stage_setup 2–11 ms and creatures 2 s.
- So the extra time is almost certainly GPU shader/pipeline compilation, landing on the first frames after the camera turns on and after each creature is added. Agents cannot measure the GPU. The owner's log is the measurement.

## Do
1. **Honest log.** In `island.gd`, record per phase both the CPU time (work inside the phase) and the stall time (wall time of the awaited frames). Print one `island entry` line with both, plus a `slowest_frames` list (top 5 frame times with the phase they belong to). Keep the existing line format compatible with any parser, and add fields; don't rename.
2. **Shader and pipeline warm-up under the veil.** Once the veil is up, render every distinct material the island will show for one frame: each creature species' skin variants, terrain, water, grass, flora, props, sky and FX (flame, dig). Use a hidden SubViewport or a tiny off-screen quad set in front of the camera. Check that Godot's shader cache is enabled in `project.godot` (`rendering/shader_compiler/shader_cache/enabled`, and the Vulkan pipeline cache), and keep the warm-up idempotent on re-entry.
3. **One build per species.** Build the creature mesh and materials once per species and genome and reuse them for every individual of that species (the wild hosts today build their own). Keep the visuals identical (same seeds and colours).
4. **Plan once.** `RadialFauna.plan` currently runs twice (in `StageSetup.add_radial` and `island.gd`); compute it once and pass the result along.
5. **nav_warm (4–7 s CPU):** overlap it with the props and flora phases if it's thread-safe (WorkerThreadPool). Otherwise spread it across frames under the veil. Determinism: nav results must be identical (test it).

## Acceptance
- Software-GL `entry_bench` (or the existing entry timing) is no worse. Report CPU per phase before and after.
- `make godot-test`, `make godot-play-test`, `make godot-ui-test`, `make godot-devtools-test` all green. Goldens untouched; no C changes.
- A screenshot comparison (software GL) of the nest view before and after shows identical creatures (same pixels within noise).
- Write `docs/evidence/godot/load-time.md`: what changed, CPU numbers, and the exact command the owner runs on his RTX to measure (launch line plus where the `island entry` line appears). Targets on the owner's machine: cold ≤ 15 s, re-entry ≤ 5 s.
