# T15 frame time — 2026-11-22

The full-roster nest drops from **16.840 to 2.991 ms/frame** of instrumented main-thread script time (82% lower), with **24 C creatures + 5 visual radial animals** present. The starting T15 target is ≤8 ms. Owner RTX FPS and visual acceptance remain pending; these measurements use headless/software rendering, never the GPU.

## Headless table

Milliseconds per frame, 600 measured frames after 120 warmup frames; fixed simulation delta 1/60 s, seed 1, 1280×720, 3,000 grass blades. Loading is excluded. `nest_start` really contains only player + Garfio; `crowd` contains player + five Garfios. `nest_all` starts the normal game with all 24 C entities. Each scenario uses its own process to avoid stale developer-tool scene bindings.

| Exclusive script bucket | Nest 2 before | after | Crowd 6 before | after | Nest 24 before | after |
|---|---:|---:|---:|---:|---:|---:|
| world advance + HUD signals | 0.200 | 0.197 | 0.220 | 0.244 | 0.238 | 0.264 |
| dev monitors | 0.004 | 0.004 | 0.009 | 0.009 | 0.009 | 0.005 |
| legend | 0.010 | 0.007 | 0.018 | 0.014 | 0.018 | 0.009 |
| options HUD | 0.026 | 0.021 | 0.055 | 0.051 | 0.054 | 0.031 |
| world sampling | 0.071 | 0.059 | 0.177 | 0.166 | 0.451 | 0.297 |
| locomotion gait/support | 0.803 | 0.711 | 3.402 | 3.583 | 7.238 | 0.797 |
| locomotion IK/rig | 0.638 | 0.218 | 2.188 | 1.044 | 5.932 | 0.241 |
| actor driver/actions | 0.509 | 0.388 | 1.910 | 1.938 | 1.799 | 0.439 |
| grass uniforms | 0.002 | 0.002 | 0.004 | 0.004 | 0.003 | 0.002 |
| actors/context/occluders | 0.112 | 0.108 | 0.342 | 0.290 | 0.619 | 0.537 |
| camera | 0.208 | 0.203 | 0.264 | 0.273 | 0.127 | 0.104 |
| flora | 0.044 | 0.045 | 0.048 | 0.049 | 0.039 | 0.042 |
| island other | 0.020 | 0.018 | 0.039 | 0.037 | 0.037 | 0.023 |
| terrain LOD | 0.001 | 0.001 | 0.002 | 0.003 | 0.002 | 0.001 |
| stage UI/audio | 0.024 | 0.021 | 0.048 | 0.046 | 0.049 | 0.027 |
| HUD animation | 0.026 | 0.023 | 0.056 | 0.054 | 0.055 | 0.032 |
| minimap | 0.002 | 0.001 | 0.003 | 0.003 | 0.003 | 0.002 |
| ambient radial fauna | 0.009 | 0.007 | 0.017 | 0.018 | 0.018 | 0.010 |
| day/night uniforms | 0.024 | 0.021 | 0.056 | 0.054 | 0.051 | 0.030 |
| minimap draw | 0.079 | 0.079 | 0.100 | 0.101 | 0.100 | 0.096 |
| Instrumented script total | 2.813 | 2.135 | 8.960 | 7.980 | 16.840 | 2.991 |

Buckets are exclusive: nested locomotion, sampling, grass and camera time is removed from the caller. “World advance + HUD signals” includes C stepping and synchronous HUD state callbacks; it is conservative as a script estimate. Native renderer/skeleton processing and uninstrumented small UI callbacks are outside the script sum. Raw logs retain calls/frame and Godot `Performance.TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, node and object counts.

Godot's Performance timing counters refresh on wall time. An average across a short fixed-FPS run can retain the loading-frame spike (the original two-creature `TIME_PROCESS` average is therefore unusable). The final benchmark reports the last timing-counter snapshot, not that contaminated average. Script buckets use `Time.get_ticks_usec()` every call and do not depend on the monitor refresh interval. Fixed-FPS wall-frame numbers are diagnostic; they are not owner FPS.

The final invocation of **`make godot-frame-bench` exited 0** and measured 1.551 / 5.403 / 2.207 ms script per frame for nest_start / crowd / nest_all. Its final `TIME_PROCESS` snapshots were 9.251 / 9.505 / 7.229 ms; physics 0.027 / 0.613 / 0.025 ms; mean nodes 3886 / 4279 / 6058 and objects 10093 / 11095 / 15356. [Complete make output](frame-time/make-bench.log). These repeat measurements strengthen the ≤8 ms full-nest result; the first before/after table is retained rather than selecting the fastest run.

A repeated full-rate reference run with the two primary optimizations disabled measured 19.129 ms at the full nest (versus the original 16.840), illustrating CPU-run variance. The improvement comfortably exceeds that variance.

## Changes

- `ActorHost` owns a conservative `VisibleOnScreenNotifier3D`. Player and creatures within 40 m of the player **or camera** retain full-rate poses. Hidden models and farther off-screen creatures skip pose/action work. Headless uses the camera frustum because the dummy renderer never emits visibility signals. Visible creatures farther away update every second frame below 80 m, every fourth frame beyond, staggered by entity ID. These distances are starting values checked by T15 and owner review.
- C root transforms keep updating while poses are skipped. Re-entry rebases feet at the current root and discards invisible time. Visible lower-rate updates accumulate delta, preserving gait time. All C world stepping, snapshots and event IDs are unchanged.
- The rig reads a yaw-only callable instead of computing the unused lateral spine integral (12 yaw interpolations per bone). Exact arithmetic for the used result is unchanged; older pose providers retain the original fallback.
- Actor samples are reused within the actor pass. Contact-shadow collection stops once the twelve shader slots are filled, producing exactly the same sphere prefix. Legend context comparisons and options-choice comparisons avoid rebuilding unchanged display strings.
- Grass/flora, camera, day/night uniforms and ambient radial fauna were measured; they are small relative to locomotion. There are no per-frame `get_nodes_in_group` calls in this checkout. WorkerThreadPool was not used: the expensive paths call terrain/game callbacks, emit footfalls, or write scene/skeleton nodes. Splitting those safely requires immutable ground snapshots and a main-thread apply phase; culling and exact math already meet the CPU target.

At the final full nest, LOD intervals were: 21 skipped, 1 full, 1 half-rate, 1 quarter-rate. At the crowded close-up, all six remained full-rate. The 5 radial animals remain present and keep their existing distance-cull behavior.

## Reproduce

```sh
make godot-frame-bench
make godot-frame-bench FRAME_MODE=baseline
make godot-frame-test
```

The benchmark uses headless/software rendering and isolated user settings under `/tmp/cpore-frame-bench`. Warm terrain cache: approximately two minutes across the three scenes, machine dependent; first generation/build costs extra. `FRAME_FRAMES=600` is the default. Baseline mode disables locomotion LOD and restores the original spine calculation; shared sample/HUD caching remains enabled, so it is a conservative reference for the main changes.

Sandbox build: the shared godot-cpp checkout was read-only, so a copy at `/tmp/cpore-frame-godot-cpp` was used through `GODOT_CPP=...`. No dependency was installed.

Owner command for **real FPS**, run normally without `--fixed-fps`:

```sh
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only godot --path godot --print-fps -- --play
```

Godot prints its real FPS to the terminal once per second. The agent did not execute this GPU command.

## Validation

The near-creature L0 scorecard ran all seven bodies × five courses in both modes: **35/35 entire JSON scorecards identical**, including footfall traces and existing failures. [SHA-256 comparison](frame-time/score-compare.json).

Additional LOD regression covers near/full, visible half/quarter rates, off-screen frustum rejection, hidden sleepers, unthrottled player, root tracking during skip, and resume without time debt.

Required suites (exit 0): `make godot-test` **1358/0**, `godot-play-test` **237/0**, `godot-loco-test` **299/0**, `godot-ui-test` **990/0**, `godot-devtools-test` **1084/0**. `godot-frame-test`: 0 failed. M0/UI were rerun after repairing three existing test-fixture aborts (missing `order`, `free()` on RefCounted, an unescaped `%` in assertion text); the reruns contain no script errors. Existing engine teardown/resource warnings, out-of-tree fixture transform warnings and deliberate corrupt-cache diagnostics remain.

## Rendered software-GL check: blocked by sandbox

Both llvmpipe runs were attempted with `LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=2`, Xvfb, `nice -n 10`, `timeout`, and `--rendering-driver opengl3`. Xvfb cannot establish any listening sockets in this sandbox; Godot cannot open X11/Wayland. No rendered software-GL timing is claimed. [Xvfb diagnostic](frame-time/xvfb-error.log). The numeric before/after tables above are **headless**, and actual notifier behavior and rendered FPS still require the owner/outside-sandbox run.

Reproduce the missing rendered comparison outside the sandbox (same 24-creature nest; each mode uses a fresh process):

```sh
for mode in baseline optimized; do
  LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 nice -n 10 timeout 240 xvfb-run -a \
    -s '-screen 0 1280x720x24' godot --rendering-driver opengl3 --path godot \
    --fixed-fps 60 --script res://game/tests/frame_bench.gd -- \
    frames=60 warm=30 scenario=nest_all "$mode"
done
```

Work is intentionally uncommitted. The required merge from main was attempted with `--no-commit`; Git was denied creation of `.git/worktrees/frame-time/ORIG_HEAD.lock` by the sandbox. The committing/reviewing agent must merge current main and commit the work. No gate is marked Passed; T15 owner acceptance remains pending.
