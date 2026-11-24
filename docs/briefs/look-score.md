# Brief: visual scorecard + three.js look-dev lab (measure the look before changing it)

Worktree `/home/diego/Desarrollo/cpore-wt/look-score`, branch `art/look-score` (from main `claude/v0.1-restore` at f6d1e63). Work only here.
Read first: `AGENTS.md`, `docs/canon/LOOK.md` (owner's taste; §7 failures), `docs/DESIGN.md` A24, A28, A35, A36, `docs/godot/CREATURE-REALISM.md`, skills `godot-shaders`, `godot-3d-materials`, `godot-3d-lighting`, `.claude/skills/cpore-media`.

## Why
Same method as the motion scorecard (`godot/devtools/zoo/loco_score*.gd`, `tools/loco/`): numbers that show whether the look improved, at fixed cameras, every build, so visual changes can merge without the owner (A33) when they improve the numbers and break nothing in LOOK.md §7.

## Phase 1: visual scorecard (Godot, measure only; no look changes)
Build on the existing capture tools: `make godot-world-look` (`game/tests/world_look_evidence.gd`, shots valley_chase, vista_wide, riverbank, forest_floor, madre_spring, rocks, …) and `make godot-creature-realism-shots` (`creature/tools/realism_shots.gd`).
1. `make godot-look-score [LOOK_LABEL=…]`: captures a fixed shot set at **dawn, midday, dusk, night** and **low + medium** tiers (software GL, xvfb, 1280×720, JPG): 5–6 world shots + 4 creature close-ups (the realism pilot creatures) + 1 creature-at-distance shot (player creature on the ground at strategic zoom).
2. `tools/look/score.py <dir>` (Python 3 stdlib + Pillow only if already installed; check, do not install) computes per image: mean/p95 saturation and fraction above a palette limit; luminance contrast (p95−p5) and fraction of clipped highlights (bloom proxy) and crushed shadows; high-frequency energy at game distance (noise proxy); tiling score on wide shots (autocorrelation peaks of the ground region); creature-vs-background value contrast on the creature-at-distance shot (mask from a second render with the creature only, or a known screen rect); sharpness (blur proxy). Also fps / frame time per tier from the capture run.
3. Output `docs/evidence/look/score/<label>/` with images, per-shot JSON, `summary.json`, `summary.md` (PASS/FAIL vs `docs/research/look-targets.json`, each target marked "starting value" with a source note), plus a contact sheet JPG per time of day.
4. `tools/look/compare.py <a> <b>` (improved / regressed / unchanged) and a side-by-side image builder (`<a>` | `<b>` per shot) for the owner's blind A/B.
5. Deterministic: same label twice → identical metrics (fix the time of day, seeds, camera; no TAA jitter in captures).

## Phase 2: three.js look-dev lab (only after phase 1 is green and committed)
- `web/lookdev/index.html` (single page, three.js from the version already used in `web/studio`, no new dependencies): loads one exported creature (GLB from the studio/realism pilot or a sphere/capsule proxy), a ground patch and a sky; sliders for time of day and quality; a material panel to swap shader variants. Purpose: iterate skin shaders fast; it is a lab, never kept in sync with Godot (A35).
- Port the current Godot skin look (`godot/creature/shaders/skin_common.gdshaderinc`, `skin.gdshader`) as variant 0 so the lab starts from today's look, not from scratch.
- Capture script with SwiftShader only (see memory/rule: never GPU flags): headless Chromium/Playwright via `NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules`, screenshots at the same four times of day.
- Do **not** change the Godot shaders in this task; the first skin improvement is a separate brief after review.

## Acceptance
- `make godot-look-score` runs under 15 minutes with software GL; full evidence written; deterministic.
- summary.md flags today's real weak spots (if everything passes, the targets are too loose: tighten or explain).
- Lab page renders variant 0 with the creature at four times of day (SwiftShader screenshots in `docs/evidence/look/lab/`).
- Suites green: `make godot-test`, `make godot-ui-test`, `make godot-play-test`, `make godot-studio-test`.
- Commit on `art/look-score`; do not merge. Report: summary table, weak spots found, run time, determinism, anything not measurable.
