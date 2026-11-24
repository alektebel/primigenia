# Brief: L0 locomotion scorecard (measure how creatures move, against reference clips)

Worktree `/home/diego/Desarrollo/cpore-wt/loco-score`, branch `tools/loco-score` (from main `claude/v0.1-restore`). Work only here.
Read the rules first: `/home/diego/Desarrollo/cpore-wt/continuity/AGENTS.md` (not merged yet; same rules apply). Key ones: software GL only (`LIBGL_ALWAYS_SOFTWARE=1`, xvfb), `timeout` + `nice -n 10` on every Godot run, `--check-only` new scripts first, kill only your own pids, never `pkill -f`, no installs, no pushes. Commit WIP before stopping.

## Why
The owner wants creature motion to look like the reference clips (a Spore-made gorilla knuckle-walking; Spore captures). We need numbers that show progress build over build, the same numbers measured on the references, and side-by-side clips. This is step L0 of `docs/research/procedural-locomotion.md` (copy on branch `docs/continuity`: `/home/diego/Desarrollo/cpore-wt/continuity/docs/research/procedural-locomotion.md`, read §L0 and the metric list there). The capture review script that already places cameras per body × scenario is `/home/diego/Desarrollo/cpore-wt/continuity/docs/research/loco_review.gd`; reuse its scenario setup.

Known visual problems the metrics must expose: head pitched to the sky, crouched legs, gallop is just a fast walk, pivot turns + periscope neck, centipede legs bunched, climbing barely changes posture, steps course stalls, eat mouth never reaches food, dig has no body motion, rigid torso (no roll).

## What to build
1. **`godot/devtools/zoo/loco_score.gd`** (SceneTree script, runs headless or under xvfb, deterministic: fixed ticks, `--fixed-fps 30`). For each body in the zoo (`zoo_genomes.gd`: mite, trotter, hero, giant, longneck, centipede, hexapod) × scenario (walk, run/gallop, turn (figure8/uturn), climb (ramps), steps), run a fixed number of ticks and sample the **visual rig** every frame (bone/foot world transforms from the actor rig; find them in `game/actors/` and the creature rig code) plus the C state (`zoo.stats(i)`).
   Per body × scenario, compute:
   - `head_pitch_deg`: mean and p95 of the head's forward vector angle above horizontal (positive = looking up).
   - `shoulder_hip_ratio`: mean height above ground of the front limb roots ÷ rear limb roots.
   - `back_slope_deg`: spine angle, shoulders vs hips.
   - `torso_roll_deg`: amplitude of body roll, and `roll_plant_lag`: phase of peak roll relative to front-foot touchdown (fraction of cycle).
   - `torso_bob_cm`: vertical amplitude of the body root per stride.
   - `foot_slip_cm`: mean and p95 world-space horizontal motion of each foot while it is in stance.
   - `duty_factor`: per foot, fraction of cycle in contact; `airborne_frac`: fraction of frames with no foot in contact.
   - `footfall`: per-foot contact boolean sequence for 2 strides (for the diagram).
   - `stride_len_m`, `cadence_hz`, `leg_extension`: mean hip-to-foot distance ÷ leg rest length in stance (catches crouching).
   - `min_turn_radius_m`, `pivot_frac` (fraction of frames in pivot state), `stall_frac` (stalled state).
   If a metric cannot be measured for a body (no head, no front limbs) write `null` with a reason, never a fake number.
2. **Output**: `docs/evidence/loco/score/<label>/` with one `<body>_<scenario>.json` each, a `summary.json`, and `summary.md` (table: body × scenario rows, metric columns, PASS/FAIL against targets where a target exists). `<label>` defaults to the short git hash.
3. **Targets file** `docs/research/loco-reference.json`: per reference creature (start with `gorilla_knuckle`, see values below), metric → `{value, tolerance, source}`, and a mapping of which zoo bodies are compared with which reference (hero and giant → gorilla_knuckle for posture metrics; every body for universal targets: foot_slip p95 < 3 cm, head_pitch within ±12°, pivot_frac < 0.05 while moving, stall_frac = 0 on steps, airborne_frac > 0.05 only in gallop and 0 in walk).
   Gorilla values, eyeballed by Claude from the clip's side-view frames (mark `source: "estimate from frames 2026-11-21, replace with keypoint measurement"`): head_pitch ≈ 0° (±10), shoulder_hip_ratio ≈ 1.35 (±0.15), back_slope ≈ 22° down to the hips (±8), torso_roll ≈ 7° (±4) peaking near front-hand plant, torso_bob ≈ 4% of shoulder height, foot_slip ≈ 0.
4. **Footfall diagram**: `tools/loco/footfall_svg.py` turns the `footfall` arrays into an SVG per body × scenario (one row per foot, bars where in contact; reference row optional). Python 3 stdlib only.
5. **Compare two runs**: `tools/loco/compare.py <labelA> <labelB>` prints metrics that improved / regressed / unchanged (markdown table), so every motion change shows its delta.
6. **Make target** `godot-loco-score` (writes evidence with the current hash label), and a small test in the existing devtools test runner that runs one body × one scenario for a few hundred ticks and checks every metric key exists and is finite or null-with-reason.
7. **Side-by-side clip (phase 2, after 1–6 are green and committed)**: `tools/loco/sidebyside.sh <reference.mp4> <ours.mp4> <out.mp4>` with ffmpeg (hstack, same height, labels "reference" / "ours <hash>"). Record "ours" with Godot `--write-movie` under xvfb software GL from the side camera of loco_review.gd (hero walk, 6 s). The reference video is outside the repo (`~/Descargas/WhatsApp Video 2026-11-21 at 00.48.30.mp4`); never copy it or any Spore capture into the repo; write the side-by-side output to `/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/` (outside the repo) only.

Do **not** change locomotion or animation behaviour in this task: measure only. If you find a measurement needs a hook in the rig (e.g. exposing foot contact), add a read-only accessor.

## Acceptance
- `make godot-loco-score` runs in under 10 minutes on this machine with software GL and writes the full evidence set for 7 bodies × 5 scenarios.
- summary.md exposes the known problems above as FAILs (head pitch, crouch/leg extension, gallop airborne, pivots, centipede, steps stall). If a known problem shows as PASS, the metric is wrong: fix it or explain.
- Running twice gives identical JSON (determinism).
- compare.py works on two labels; footfall SVGs render.
- Existing suites still green: devtools test, M0 godot-test (`make godot-test`), play test.
- Commit on `tools/loco-score` with evidence; report back: summary table, which known problems each metric catches, run time, anything you could not measure.
