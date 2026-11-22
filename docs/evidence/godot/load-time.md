# T2 — island entry load time

2026-11-22. Tracker: creature-loop **T2 / Load**, finding 1 in `docs/plans/creature-loop.md`; brief `docs/briefs/load-time.md`. Implementation ready for review; **owner acceptance pending**. No C or golden changes. Work is uncommitted as requested.

## Changes

- The original `island entry (...): ... ms since goto_island; build ...` prefix and phase names remain. Appended JSON fields: `cpu_ms`, `stall_ms`, `slowest_frames`. The entry log retains its existing keys and adds these fields. Phase-ending frame waits now belong to that phase, including yields inside flora/ambient fauna. Top five full process-frame intervals include their phase, rather than reporting only script delta.
- `cpu_ms` measures elapsed time executing main-thread work plus elapsed worker work. `stall_ms` measures wall time suspended awaiting frames (including rendering, frame pacing and worker polling); it is **not a GPU-only measurement**. Worker work and awaited wall time overlap, so CPU + stall is not additive. `nav_warm` CPU includes the entire worker duration; its legacy phase value covers only the remaining join wait. These are elapsed work timings, not OS CPU-accounting samples.
- A 128×128 SubViewport with its own world, matching MSAA, sky/environment and sun submits representative real meshes/materials, with separate instanced and skinned layouts. It includes every live creature skin variant and terrain, water, rivers, grass, near/far flora, props, cave/quest nodes, flame particles, screen-reading heat shimmer and dig dust. Samples use independent skeletons and fit transforms. Island geometry stays out of the main camera until the warm-up draws under the veil; the final real view is then submitted before `island_ready`.
- Warmed signatures and material references survive re-entry. Keys include shader/material parameters, vertex layout, instancing and skinning, MSAA and shadow state. FX warm only once per rendering context. Shader and RenderingDevice/Vulkan pipeline caches are explicitly enabled in `godot/project.godot`; [Godot documents both settings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-shader-compiler-shader-cache-enabled).
- A bounded session cache builds a pristine rig once per complete genome and realism mode. Individuals share immutable meshes, skins and textures; cloning remaps bones, parts, metadata hooks, IK and radial references. Material uniforms remain independent because leg flex, skin edits and animation must not affect other individuals. Mesh generation, biological derivation and palette/texture generation happen once. No seeded geometry, colours or placement inputs change.
- StageSetup passes the single radial habitat plan through an output dictionary, outside the strict C setup schema. Ambient fauna reuse it; wild-disabled/herds-disabled paths still work.
- Navigation runs on WorkerThreadPool after reset/legacy application, overlapping flora planning/build. The stage is paused; there are no ticks, resets, path queries or debug calls until the join. The C grid is global derived storage, so this is exclusive access, **not general thread safety**. Flora reads terrain and never touches that cache.
- `entry_bench` waits for `_building == false`; it previously could leave while radial/UI work was still running. It also has an optional synchronously frozen nest JPG capture.

## Measurements

**Rendered software-GL acceptance is blocked in this sandbox.** `xvfb-run` fails with `Cannot establish any listening sockets`; its log shows both local/unix listener binds rejected. No GPU was used. No rendered screenshot or visual parity claim is supplied. Warm-up node construction is tested with the dummy renderer, but actual shader/pipeline draws and RTX targets remain unverified.

The following is a sequential **headless CPU diagnostic**, not software-GL or RTX evidence. Both runs use Godot 4.7.2, seed 1, 20,000 grass blades, the same temporary user directory and terrain cache. Baseline is HEAD 264b823 plus the identical timing instrumentation and completed-entry predicate; no performance changes. It ran from an isolated `/tmp/cpore-load-baseline` copy with the same native library. The machine is shared; one paired sample gives direction, not a statistical performance guarantee. Raw phase/wait/frame results: [load-time-headless.json](load-time-headless.json).

| Entry wall time since goto_island | Before | After |
| --- | ---: | ---: |
| cold | 12596 ms | 9398 ms |
| menu again | 8390 ms | 6471 ms |
| studio | 8173 ms | 6461 ms |

CPU work per phase, milliseconds (includes worker elapsed work as described above):

| Phase | Cold before | Cold after | Menu before | Menu after |
| --- | ---: | ---: | ---: | ---: |
| environment | 9.2 | 8.9 | 2.8 | 0.1 |
| terrain_meshes | 169.7 | 199.5 | — | — |
| kit_reused | — | — | 0.5 | 0.3 |
| water | 1930.8 | 1673.6 | — | — |
| rivers | 268.7 | 325.7 | — | — |
| grass | 34.8 | 34.0 | — | — |
| camera | 0.1 | 0.1 | 0.1 | 0.1 |
| stage_setup | 2154.0 | 1714.6 | 2290.1 | 1853.6 |
| stage_reset | 249.9 | 218.0 | 284.1 | 155.4 |
| props_flora | 1790.4 | 1842.1 | 1186.2 | 1893.6 |
| nav_warm | 3361.9 | 3489.3 | 3274.0 | 4102.1 |
| creatures | 1152.2 | 581.9 | 719.1 | 179.7 |
| ui_and_rest | 575.9 | 178.5 | 507.6 | 47.3 |
| shader_warmup | — | 0.1 | — | 0.0 |

Navigation itself is not made cheaper: it overlaps flora. Ambient planning moves out of `ui_and_rest` because it is already done during stage setup. Headless `shader_warmup` is a no-op and does not predict renderer overhead.

Reproduce the CPU diagnostic:

```sh
XDG_DATA_HOME=/tmp/cpore-load-home/data \
XDG_CONFIG_HOME=/tmp/cpore-load-home/config \
LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 \
  godot --headless --path godot --script res://game/tests/entry_bench.gd
```

## Validation

- `make godot-test`: 1,354 checks, 0 failures.
- `make godot-play-test`: 237 checks, 0 failures.
- `make godot-ui-test`: 972 checks, 0 failures.
- `make godot-devtools-test`: 1,084 checks, 0 failures.
- Entry-loading test: 23 checks, 0 failed (menu, repeat, studio and cell routes).
- `test_load_time.gd`: **11,385 checks, 0 failed**. All nine island/ambient genomes compared against fresh builds, identical vertex/index/UV/skin arrays, rest transforms, seeded biology and shader uniforms; shared body meshes with independent skeletons, feet and palettes. Changed-genome invalidation tested. Six GO targets × 30 ticks × seeds 1, 7, 11: lazy versus worker-warmed hashes and paths identical; snapshots unchanged; concurrent flora records identical. Warm-up collection, material/layout variants, viewport/skeleton/FX assembly also checked.
  Run it with `LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 godot --headless --path godot --script res://game/tests/test_load_time.gd`.
- Script `--check-only` and `git diff --check` pass. Goldens and C sources untouched.

The runners return success but also emit diagnostics from unchanged tests (`test_input.gd` missing `order`, `test_flight.gd` freeing RefCounted, UI test `%` formatting), sandbox sockets, and shutdown leaks. These are recorded rather than hidden. The initial cache implementation exposed a dummy-renderer error when overriding surfaces already covered by a material override; corrected before the passing play run.

Build/test commands used `GODOT_CPP=/tmp/cpore-load-godot-cpp` (a local copy of the existing dependency) because SCons cannot write the shared dependency directory. No install was performed. Logs for this session are `/tmp/load-time-suites.log` (M0), `/tmp/load-time-suites-final.log` (play/UI/devtools), `/tmp/load-time-entry-test.log`, `/tmp/load-time-regression-final.log`.

## Owner: exact RTX measurement

Run from this worktree. This explicitly selects NVIDIA **Forward+ / Vulkan** and prints three entry lines (cold, menu again, studio) to the terminal and the tee log:

```sh
cd /home/diego/Desarrollo/cpore-wt/load-time
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
  nice -n 10 timeout 300 godot --path godot \
  --rendering-method forward_plus --rendering-driver vulkan \
  --resolution 1280x720 --script res://game/tests/entry_bench.gd \
  2>&1 | tee /tmp/primigenia-load-rtx.log
```

Find `island entry (` in that terminal/log (also normally `~/.local/share/primigenia/logs/godot.log`). Compare **since goto_island** with cold ≤15,000 ms and menu re-entry ≤5,000 ms; creature phase ≤2,500 ms and stage_setup ≤300 ms are the plan's additional owner targets. Inspect CPU and waits separately. The benchmark loads/generates terrain before `goto_island`, so terrain generation is excluded. “Cold” means first island in this process; driver-cache coldness depends on prior runs. Repeat a second process to observe the persistent shader/pipeline cache without deleting owner caches.

Software-GL timing outside the restricted sandbox:

```sh
LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 xvfb-run -a \
  godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
  --script res://game/tests/entry_bench.gd \
  2>&1 | tee /tmp/primigenia-load-software.log
```

Frozen nest view (software GL; use this same benchmark helper in baseline and changed checkouts, with identical settings/user data):

```sh
LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 300 xvfb-run -a \
  godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
  --script res://game/tests/entry_bench.gd -- \
  capture=/tmp/primigenia-nest-after.jpg
```

The capture pauses synchronously on `island_ready`, hides HUD/veil and freezes engine time. The baseline image and pixel comparison remain outstanding because the display cannot start here. The mesh/uniform comparisons are supporting evidence, not a substitute for the requested screenshot.

## Handoff

All changes are uncommitted. `git merge --no-commit --no-ff claude/v0.1-restore` was attempted and denied when Git tried to create read-only `ORIG_HEAD.lock`; the only intervening main commit is a STATUS update. STATUS is reconciled in the working files. A writer with Git metadata access must merge main, commit and arrange Claude review; owner tracker confirmation is still required. T2 is **not Passed** until the rendered comparisons and RTX timing meet the targets.
