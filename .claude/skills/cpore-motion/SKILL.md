---
name: cpore-motion
description: Procedural creature movement in Primigenia (cpore): references to match, the L0 scorecard, known problems, the fix order, and the arms rule. Use when working on creature locomotion, gaits, posture, turning, climbing, arms, eat/dig motion, or when judging whether movement improved.
---

# Creature motion work (cpore)

## Goal
Creatures should move like the reference clips: weight, posture and rhythm, not just feet moving. Owner direction 2026-11-21: "make it look somewhat as these videos in the mechanics".

## References (outside the repo, never commit them)
- `~/Desarrollo/cpore-refs/videos/spore-gorilla-knucklewalk.mp4` — main reference. A Spore-built ape knuckle-walking: head level and forward, shoulders higher than hips (~1.35×), back slopes ~22° down to the hips, long arms carry the weight on the knuckles, torso rolls ~7° peaking at each hand plant, short legs push from behind. (Eyeball estimates; replace with keypoint measurement.)
- `~/Desarrollo/cpore-refs/spore-captures/` — owner's Spore screenshots.
- Make frame sheets with the `cpore-media` skill to look at them.

## Architecture constraints
- Godot 4.7 + deterministic C core. **The C sim owns root motion** (position, heading, speed, pivot, grade); animation is visual-only GDScript over it. Never move gameplay into the animation layer.
- Zoo test bed: `godot/devtools/zoo/` (`zoo.gd`, `zoo_genomes.gd` bodies mite/trotter/hero/giant/longneck/centipede/hexapod, `zoo_course.gd` courses figure8/zigzag/steps/uturn/ramps). Run `--zoo=a,b --course=x --run=1.8`. `zoo.stats(i)` gives the C state (run/turn/pivot/climb/descend/stalled/slide).
- Capture contact sheets per body × scenario: `docs/research/loco_review.gd` (copy to `godot/devtools/tools/_loco_review_tmp.gd`, run under xvfb software GL, delete after).

## Measure before and after every change (L0 scorecard)
Branch `tools/loco-score` (brief `docs/briefs/loco-score.md`). `make godot-loco-score` → `docs/evidence/loco/score/<hash>/summary.md`; `tools/loco/compare.py <a> <b>` shows deltas. Targets in `docs/research/loco-reference.json`.
Metrics: head pitch, shoulder/hip ratio, back slope, torso roll + lag to hand plant, torso bob, foot slip in stance, duty factor, airborne fraction, footfall diagram, stride/cadence, leg extension (crouch), min turn radius, pivot and stall fractions.
Progress is shown three ways: metrics vs reference, side-by-side clips (reference | ours), and the owner's blind A/B vote. A change merges only if metrics improve and the owner does not vote it worse.

## Known problems (2026-11-20 capture review)
1. head pitched to the sky  2. crouched legs  3. gallop = fast walk (no flight phase)  4. pivot turns + periscope neck  5. centipede legs bunched  6. climbing barely changes posture; steps course stalls  7. eating mouth never reaches the food  8. dig has no body motion  9. rigid torso (no roll/bob).

## Fix order (research plan `docs/research/procedural-locomotion.md`, tracker stages M0–M6)
L0 scorecard → L1 posture + head (level head, straighter legs on big bodies, neck carries head forward) → torso roll/bob → arms → L2 turning (arcs, lean, head leads) → L5 gaits (walk/trot/gallop distinct, flight phase, spine flex) → L3 terrain (tilt into slopes, step up, lean back downhill) → L4 eat reach / dig scratch / idle → L6 many legs + perf (30 creatures at 30 fps).
Approach: Spore-style procedural (gait tables, foot planner, IK, secondary motion). The physics-optimised gait pilot (tools/gaitopt) failed: 6/10 bodies fell.

## Arms (tracker D-12, open; recommended rule)
Parts `arm_grasper`, `arm_smasher` (category arms, CP4_ARM, cosmetic today, mount at the shoulder). Reach rule: if the hand can touch the ground from the shoulder with the body level, the arms **walk** (knuckle gait like the gorilla: shoulders up, torso rolls with each plant). Otherwise they swing opposite to the legs while walking and reach/strike in combat.

## Real-animal data
For gait timing from real animals: SAM 2 tracking + SuperAnimal (DeepLabCut) keypoints (trial, needs owner OK for GPU). Human mocap / text-to-motion tools do not apply (see `docs/RESOURCES.md`).
