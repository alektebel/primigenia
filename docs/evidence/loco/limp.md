# M1 — post-L1 limp diagnosis (`anim/limp`)

2026-11-21. Starting point: main 6644d86; comparison baseline L1 `ffea2c1`.
Work is deliberately uncommitted, per the owner’s brief. Intended commit message:
`fix(locomotion): overlap amble support and measure footfall limp`

## Diagnosis

The hero’s “walk” scenario is actually 100% **amble**, selected by its Froude number (speed 5.1236 m/s). Its recorded duty was 0.4097 per foot. This was not a walk with >half-stride support: the amble table explicitly permitted duty 0.30–0.52 and therefore disabled the controller’s half-the-legs-down guard. The visually hoppy, rocking support transfer explains the reported limp better than a unilateral injury.

Hypothesis 1 (one bob/roll per stride) was **not confirmed**. There is no once-per-stride body-bob sine: the support plane uses each leg’s pendulum height and the bounce uses summed leg forces. Roll is driven separately by each front plant. The new baseline hero index is already inside the provisional 1.15 bound; calling this a large left/right imbalance would overstate the evidence. Hypothesis 2 (short contacts) **is confirmed**. Keeping amble contacts overlapping reduces bob and keeps an actual support overlap without changing C speed.

Hypothesis 3 (“all true” saved contacts) is **not reproduced**: `ffea2c1/hero_walk.json` already contains bit strings with both `0` and `1`. The first L0 row is `111111110000000000011111110000000000`. Treating characters by truthiness can turn both into true. New recordings use native JSON boolean arrays; the SVG reader supports both formats explicitly. A regression test verifies each diagram sample against the raw contacts, and another check confirms identical legacy/native SVG bars.

## Changes

- Amble duty uses `clamp(0.55 * Fr^-0.1, 0.53, 0.65)` (M1 starting values). This activates overlapping support and the existing stance guard.
- Amble roll pulse peaks at 0.10 stride after **each front touchdown**, independent of duty; other gaits keep their existing pulse.
- Amble soles stay planted; the existing root drop handles reach instead of rotating the heel under load. A duty-only trial raised giant slip to 3.82 cm p95; retaining heel-off would lose L1’s gain.
- Quadruped straight-leg share 0.960 → 0.958 (M1 starting value). The extra spring/IK margin removes a hero steps knee-flip regression seen in the first candidate (0.0087 → 0).
- `limp_index` is now in case JSON, summary tables, comparisons, and universal walk checks (<=1.15; provisional, owner validation pending).

## Metric definition

Use the existing root-height-above-terrain and root-roll signals, detrended over two strides. For each moving touchdown, sample the root’s low point within ±0.10 stride and subtract it from the preceding stride’s peak; sample peak roll **toward the planted side** in the following quarter stride. Average each quantity per foot, compare left/right within each anatomical pair, then take the worst max/min ratio across both quantities and pairs. 1.0 means even. Denominator floors are 1 mm and 0.1 degree; no fabricated motion is added. `limp.per_foot` retains drops (cm), roll (degrees), sides, pairs and sample counts; no usable paired touchdowns yields null with a reason. Synthetic tests accept two equal drops/stride and reject a once/stride drop.

This is a symmetry diagnostic, not a measure of bounce magnitude or gait correctness. A left-lead gallop and uneven terrain may deliberately score poorly. The universal rule currently applies to scenario “walk”, even when speed selects a gallop/trot; those failures remain visible.

## Measurements

`limp-before` reruns the four quadruped walks with the metric added and animation unchanged. **Every pre-existing metric exactly matches `ffea2c1`** in all four runs. `limp` contains the final full 35-case scorecard.

| body (actual walk-scenario gait) | limp index before → after | drop ratio before → after | roll ratio before → after | <=1.15 |
|---|---|---|---|---|
| trotter (gallop) | 1.7315 → 1.4966 | 1.5325 → 1.4966 | 1.7315 → 1.2519 | no |
| hero (amble) | 1.1071 → 1.0663 | 1.1071 → 1.0316 | 1.0713 → 1.0663 | yes |
| giant (amble) | 1.0832 → 1.0698 | 1.0832 → 1.0309 | 1.0331 → 1.0698 | yes |
| longneck (trot) | 1.3080 → 1.3523 | 1.1368 → 1.1569 | 1.3080 → 1.3523 | no |

| walk body | duty before → after | bob cm before → after | roll deg before → after | plant lag before → after | slip p95 cm before → after | head mean deg before → after | extension before → after |
|---|---|---|---|---|---|---|---|
| trotter | 0.255 → 0.258 | 4.180 → 3.860 | 2.020 → 1.850 | 0.048 → 0.042 | 0.000 → 0.000 | -4.440 → -4.460 | 0.854 → 0.852 |
| hero | 0.410 → 0.533 | 23.610 → 19.430 | 5.220 → 4.740 | 0.129 → 0.134 | 1.230 → 0.000 | -3.890 → -4.150 | 0.845 → 0.847 |
| giant | 0.463 → 0.558 | 39.170 → 35.900 | 5.710 → 5.030 | 0.172 → 0.138 | 2.810 → 1.140 | -2.900 → -2.840 | 0.848 → 0.848 |
| longneck | 0.517 → 0.516 | 9.560 → 8.100 | 4.900 → 5.290 | 0.152 → 0.142 | 2.140 → 2.650 | -6.800 → -6.470 | 0.865 → 0.866 |

The C-derived speed, moving/pivot/stall/slide fractions, turning fractions and minimum turn radius are identical across **all 35 cases**. No core, C state, event ids, snapshots or gameplay trajectories changed. Root-height changes are visual only.

Across 35 cases, the L1 comparison counts 123 improved, 80 regressed and 372 unchanged scalar metrics (directional counts, not pass/fail counts).

Full comparisons: [L1 → final](limp/compare.md), [new metric baseline → final](limp/compare-limp.md). The full scorecard still contains pre-existing canon failures; a green unit suite does not mean M1 is Passed.

## Validation and limits

| suite | checks | failures | final exit |
|---|---|---|---|
| `godot-loco-test` | 299 | 0 | 0 |
| `godot-devtools-test` | 909 | 0 | 0 |
| `godot-test` | 1138 | 0 | 0 |
| `godot-feel-test` | 76 | 0 | 0 |
| `godot-actions-test` | 383 | 0 | 0 |
| `godot-play-test` | 237 | 0 | 0 |

M0 diagnostics in unchanged files: `player_input.gd:151` accesses a missing `order` in the input test; `test_interp.gd:52` has an unsupported string format character; `test_flight.gd:167` attempts to free a RefCounted. Terrain-cache negative-path errors and exit resource leaks also appear. These are not counted as failed assertions by the suite; they remain unresolved here. Earlier project STATUS already warned about script-error lines in M0, but this task does not establish the history of each diagnostic.

Additional checks: `--check-only` passes for controller, gait, score entrypoint and score test; legacy-bit-string vs native-boolean SVG parity passes; `git diff --check` passes. New devtools assertions cover metric presence/finite values, synthetic even vs once-per-stride drops, and exact diagram/raw-contact agreement.

Build: initial `make godot` failed because SCons attempted to regenerate the shared read-only godot-cpp dependency. Copied that dependency to `/tmp/limp-godot-cpp` and built with `GODOT_CPP=/tmp/limp-godot-cpp`. Godot’s parallel resource import then crashed in a font import; a temporary override disabled multi-threaded importing and import completed; the override was removed after validation. No dependency install or shared checkout edit. Subsequent make invocations use `-o godot` to reuse the built/imported extension. Scripts were checked with `--check-only` via the score entrypoint and directly for controller/gait/test scripts (the core cannot compile standalone before its Game autoload exists).

Assertion summary excerpts are saved in [validation.txt](limp/validation.txt).

All suite runs use `LIBGL_ALWAYS_SOFTWARE=1`, `nice -n 10`, headless Godot and timeouts. Writable user/config directories are redirected with `XDG_DATA_HOME=/tmp/...` and `XDG_CONFIG_HOME=/tmp/limp-config`. An initial devtools run without that redirect had 18 filesystem-related failures; the final results above use writable temporary data. Godot reports resource/ObjectDB leaks at exit; these are recorded in logs, not counted as successful assertions.

Clip capture attempted under software GL with `xvfb-run -a`, `--rendering-driver opengl3`, nice and timeout. **Blocked:** Xvfb cannot establish listening sockets in this sandbox; Godot cannot open an X11 display. No clip or visual approval is claimed. Owner M1 confirmation and before/after visual judgment remain pending.

Remaining targets/regressions: see final scorecard and comparison. In particular, trotter’s walk scenario is still a left-lead gallop and fails the new symmetry check; longneck exceeds the provisional ratio on small hind roll. These gaits are not silently converted to walks. Hero/giant bob and leg extension remain short of L1’s desired <=8% and >=0.9 targets, respectively; no C-speed or morphology change was authorized.

## Files changed

- `godot/locomotion/loco_gait.gd`, `loco_controller.gd`: amble timing, roll phase, planted heel and reach margin.
- `godot/devtools/zoo/loco_score_core.gd`: limp measurement and boolean contact recording.
- `godot/devtools/tests/test_loco_score.gd`: metric key, synthetic asymmetry and contact-slice regression checks.
- `tools/loco/summary.py`, `compare.py`, `footfall_svg.py`: display/compare metric and read both contact encodings.
- `docs/research/loco-reference.json`: universal starting target and known-problem mapping.
- `docs/STATUS.md`, this report and `docs/evidence/loco/limp/`: scope, status and comparisons.
- `docs/evidence/loco/score/limp-before/`, `score/limp/`: measured JSON, summaries and footfall SVGs.

No commits, git metadata writes, merges, pushes, main-checkout edits or other-worktree edits. Claude can review, integrate main and commit after handoff. This task is awaiting owner M1 confirmation, not marked Passed.
