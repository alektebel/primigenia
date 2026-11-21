# Brief: creature parts fit together (the starter looks "buggy")

Worktree `/home/diego/Desarrollo/cpore-wt/creature-fit`, branch `art/creature-fit` (from main). Work only here.
Read first: `AGENTS.md`, `docs/canon/LOOK.md`, `docs/DESIGN.md` A24 (player's choices authoritative, hues never shift), `docs/godot/CREATURE-REALISM.md`, the Creature class and part placement code under `godot/creature/`, skills `procedural-modeling`, `godot-3d-materials`.

## Owner feedback (2026-11-21, playing on the RTX)
"The creature looks a bit buggy." Claude's review of `docs/evidence/look/score/baseline/creature_midday_hero_{close,chase}.jpg`:
1. Teeth float outside the snout instead of sitting in the jaw line / inside the mouth.
2. Eye is a flat white disc protruding from the head (cartoon look): it should sit in a socket, with lids/brow overlap and a naturalistic sclera/iris (canon: no cartoon).
3. Limbs read as separate pieces: big balls at shoulders/hips, tubes that do not blend into the body. Limb roots should blend into the torso (smooth union / skinning / shoulder-hip mass), joints should not show as spheres.
4. Pattern scale differs between body and limbs; belly flat white. Keep the player's colours; make the pattern continuous in scale and the belly countershading a gradient (A24), not a patch.
5. Horn oversized and attached at the back of the skull: parts should attach where their anatomy says, at a size proportionate to the head.
Also check the other pilot creatures (giant, beetle, spider) and a few creator-made genomes for the same class of problems.

## Make it measurable first
Add a **part-fit check** (Godot, headless if possible): for every attached part, the gap between the part's base and the body surface (floating) and how deep it sinks into the body (penetration), plus teeth inside the mouth volume and eyes inside a socket depth range. Report per creature. Add it to `make godot-creature-test` or a new `make godot-creature-fit`. Run on the 4 pilot creatures + 10 random valid genomes (fixed seeds).

## Then fix, one issue at a time
Measure → fix → re-measure, one commit per issue with before/after numbers. Visual-only: no C, no gameplay, no genome format change (if a fix needs a genome field, stop and write the proposal in the report instead). Creator choices remain authoritative.

## Evidence
- Before/after: `make godot-creature-realism-shots TAG=fit` and `make godot-look-score LOOK_LABEL=fit` + `python3 tools/look/compare.py baseline fit --side /home/diego/Desarrollo/cpore-wt/_agent/look-ab/fit.jpg` (force-add only the final label).
- `docs/evidence/godot/creature-fit.md`: per issue, numbers and before/after crops.

## Acceptance
- Part-fit check passes on all test creatures (zero floating parts, teeth in the mouth, eyes socketed) or each exception explained.
- No regression on the look scorecard; suites green: `make godot-test`, `make godot-studio-test`, `make godot-studio-ix-test`, `make godot-ui-test`, `make godot-play-test`.
- Commit on `art/creature-fit`; do not merge.

Coordination: another agent changes skin shaders on `art/skin-v1` (godot/creature/shaders/). Avoid editing those shader files; if you must (eye material), keep the change minimal and note it for the merge.
