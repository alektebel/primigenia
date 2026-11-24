# Brief: three.js gait lab — 16 mutated creatures walking side by side (4×4)

Worktree `/home/diego/Desarrollo/cpore-wt/gait-lab`, branch `anim/gait-lab` (from main bd673cd). Work only here.
Tracker test: M1 (movement looks like the references). Read first: `AGENTS.md`, `docs/canon/MOTION.md` (§2 size sets the rhythm, §5 failures), `.claude/skills/cpore-motion/SKILL.md`, `docs/research/procedural-locomotion.md`, `docs/evidence/loco/limp.md`, and `godot/locomotion/loco_gait.gd` (current gait tables) for reference only.

## Why (owner, 2026-11-21)
"The legs are not moving correctly. Maybe because it is just walking fast, not the animation of running. Let's do this step by step." In the game every body moves at the same C speed (hero 5.1 m/s), so the gait code stretches a walk/amble instead of switching to a run. Before touching Godot again we want a fast, visual lab where gait selection and leg mechanics are right, then port the rules (A35: prototype in three.js, ship in Godot).

## What to build: `web/gaitlab/index.html`
Single page, three.js r128 from cdnjs (same as `web/lookdev`, `web/studio`), no other dependency, no build step. Opens from file:// and works at phone width.

**Grid: 16 creatures in a 4×4 layout, all walking in a straight line at the same time,** each on its own lane (side camera per cell, or one wide scene with 16 parallel lanes and a camera that tracks forward; pick what reads best). Ground with stripes/ticks every 0.5 body lengths so foot slip is visible. Each cell labelled: body plan, size, leg length, speed m/s, Froude number, chosen gait, duty factor.

**Mutation axes (rows × columns):**
- Rows, body plan: biped (digitigrade, tail counterbalance), quadruped, hexapod, 8-leg segmented (centipede-like).
- Columns, size × leg length: small short-leg, small long-leg, large short-leg, large long-leg (small ≈ 0.3 m hip height, large ≈ 1.5 m; short = 0.6× long). Body length and leg spacing follow the plan.
Primitive geometry (capsules/boxes) is fine; the mechanics matter, not the look. Two-segment legs with analytic 2-bone IK, knees bending the anatomically right way per plan (biped/quadruped hind knees back-pointing ankle, insect legs out-and-down).

**Gait mechanics (each number cites a source or is marked "starting value"):**
- Speed control in **Froude units** Fr = v²/(g·h) (h = hip height) — Alexander & Jayes 1983 dynamic similarity — plus an alternative "same absolute speed for all" mode (default 5.1 m/s, the game's hero speed) to show what goes wrong today.
- Gait chosen by Fr: walk below ~0.5, trot (quadruped) / run (biped) between ~0.5 and ~2.5, gallop/bound above ~2.5 (Alexander 1989); hexapod: tripod at all speeds above slow wave gait; 8-leg: metachronal wave with phase lag that shortens with speed. Footfall phase offsets per gait (walk lateral sequence, trot diagonal pairs, gallop rotary/transverse with a flight phase, biped run with flight phase).
- Stride length from relative stride λ/h ≈ 2.3·Fr^0.3 (Alexander 1976/1984); cadence = v/λ. Duty factor falling with speed (≥0.5 walk, <0.5 run/trot, flight phase when duty < 0.5 for bipeds); cite or mark starting value.
- Stance feet locked to the ground (zero slip by construction: stance foot fixed in world, body moves over it); swing foot follows a smooth arc to a target placed ahead by half the stride; body height bob twice per stride in walk (vaulting, low at mid-swing… check: walking = high at mid-stance, inverted pendulum) and once per step with lowest point at mid-stance in running (spring-mass). Small roll toward the planted side. Head stabilised near level.
- Gait transitions blend over one stride, no pops.

**Controls (top bar, Emil rules: ease-out ≤250 ms, press 0.97):** speed slider (Fr 0.05–4) and preset buttons Walk / Trot-Run / Gallop / "Game speed 5.1 m/s"; mode toggle Froude vs absolute; pause/step-frame; playback 0.25×/0.5×/1× (default 1× real time, clock shown); toggle footfall strips (per cell, last 2 strides, one row per foot, black = stance).

## Evidence
- `tools/gaitlab/capture.cjs`: SwiftShader only (`NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules`, never GPU flags), screenshots of the grid at Walk, Trot-Run, Gallop and Game-speed presets into `docs/evidence/loco/gaitlab/*.jpg`, plus a ~6 s real-time video per preset if Playwright video works under SwiftShader (keep videos in `/home/diego/Desarrollo/cpore-wt/_agent/gaitlab-clips/`, not the repo).
- `docs/evidence/loco/gaitlab.md`: per cell at each preset: gait, duty, stride, cadence, measured foot slip (should be ~0), and which rules would port to `godot/locomotion/loco_gait.gd` (gait by Froude, duty curve, stride curve, bob phase). Note any cell that looks wrong and why.
- A small self-check in the page (console or `?test=1`): for each cell, assert stance slip < 1 mm, duty in the expected range for its gait, and flight phase present only when the gait has one. Capture script fails if any assertion fails.

## Rules
- Do not touch `core/`, `godot/` or other web pages. This is a lab (A35).
- Commit on `anim/gait-lab`; do not merge. Report: what you built, the table per preset, screenshots paths, anything you could not do.
