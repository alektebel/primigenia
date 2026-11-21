# Brief: L1 posture and head (first motion fix, measured by the L0 scorecard)

Worktree `/home/diego/Desarrollo/cpore-wt/l1-posture`, branch `anim/l1-posture` (from main `claude/v0.1-restore` at 39e28bc). Work only here.
Read first: `AGENTS.md` (rules), `docs/canon/MOTION.md` (owner's taste; §5 is the failure table), `.claude/skills/cpore-motion/SKILL.md`, `docs/godot/LOCOMOTION.md`, `godot/locomotion/README.md`.

## Goal
Fix the posture problems the scorecard measures, without touching gameplay. The C sim owns root motion; all changes are visual GDScript in `godot/locomotion/` (loco_controller, loco_gait, loco_ik, loco_morphology, loco_rig_adapter, loco_support) and `godot/game/actors/actor_driver.gd`. Do not change `core/`, C state, speeds, turning or the zoo bodies.

Baseline (scorecard label 9095d8c, `docs/evidence/loco/score/9095d8c/summary.md`):
- Head pitch mean 15–19° on hero/giant/trotter, 32–38° on longneck (target within ±12° of level when walking; gorilla ≈ 0°).
- Leg extension 0.77–0.88 on every body (target ≥ 0.9: legs carry the body, not crouched).
- Torso: hero walk roll 3.0° (gorilla ≈ 7° ±3, peaking near front-foot plant); bob 22% of shoulder height (gorilla ≈ 4%): far too bouncy.
- Foot slip p95 4–24 cm on 4-leg bodies, hero walk 17 cm (target < 3 cm).

## Steps
0. **Check the head metric first.** The scorecard measures head pitch as head-bone → snout-tip vector. Measure it on the rest pose (no motion) for each body. If the rest mesh itself points up, the fix is a head/neck counter-rotation in the rig, and say so; if the metric is biased by the mesh shape, fix the metric in `loco_score_core.gd` and document it. Do not hide a real problem by changing the metric.
1. **Head level**: neck/head bones counter-rotate so the gaze stays near level while walking (gaze stabilisation; small natural nod with the front legs is fine). Longneck carries the head forward, not up (no periscope).
2. **Straighter legs**: raise body height / adjust IK so stance legs reach ≥ 0.9 of rest length; bigger bodies straighter (Froude/size rule in the canon §2).
3. **Torso**: reduce bob to the reference range, add roll that peaks near front-foot touchdown (gorilla), scaled by body size.
4. **Foot slip**: planted feet stay locked to the ground during stance (check the stance/swing timing in loco_gait vs the C speed; a foot that arrives late counts as slip).
After each step run `make godot-loco-score LOCO_LABEL=<step>` and `python3 tools/loco/compare.py 9095d8c <step>`; keep a step only if it improves its metric without regressing others. Commit each step separately with its compare table in the message.

## Evidence
- Final scorecard under `docs/evidence/loco/score/<final hash>/`, plus compare vs 9095d8c in `docs/evidence/loco/l1-posture.md` (what improved, what still fails and why).
- A side-by-side clip of hero walk vs the gorilla: `REF_START=6 CROP_REF=576:574:0:298 sh tools/loco/sidebyside.sh ~/Desarrollo/cpore-refs/videos/spore-gorilla-knucklewalk.mp4 <ours.avi> /home/diego/Desarrollo/cpore-wt/_agent/loco-clips/side_by_side_hero_walk_<hash>.mp4 <hash>` (record ours with `godot/devtools/zoo/loco_clip.gd`, see the Makefile/scorecard brief). Clips stay outside the repo.
- Contact sheet JPGs (software GL, xvfb) of hero, giant, longneck, centipede walking: before and after, in `docs/evidence/loco/l1/`.

## Acceptance
- Head pitch within ±12° on walk/gallop/turn for hero, giant, trotter, longneck; leg extension ≥ 0.9 on 4-leg bodies; hero walk roll within 7 ± 3°, bob ≤ 8%; foot slip p95 < 3 cm on hero walk. Anything not reached: explain with numbers.
- No regression in other scorecard metrics beyond noise; no change in C state (same trajectories: compare `x`, `z`, `speed` in the case JSONs).
- Suites green: `make godot-devtools-test`, `make godot-test`, `make godot-play-test`, `make godot-loco-test` (if present), `make godot-actions-test`, `make godot-feel-test`.
- Commit on `anim/l1-posture`; do not merge.
