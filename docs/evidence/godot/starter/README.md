# Starter creature: 4 candidates (branch art/starter-design)

Tracker C1/C6, owner 2026-11-21 "make a better initial design". Today's default is `game/data/hatchling.json` (option 0). Nothing is switched: the owner picks.
Contact sheet: `candidates.jpg` (rows: side midday, 3/4 front midday, close-up dusk; columns 0, A, B, C, D). All stills (side, 3/4, close, midday and dusk) are in `shots/`. Walk clips (6 s, side camera, outside the repo): `/home/diego/Desarrollo/cpore-wt/_agent/starter-clips/start{0,A,B,C,D}.mp4`.

Data: `godot/game/data/starters/{a_grazer,b_runner,c_sprawler,d_knuckle}.json` (cpore.creature/4, no format change). Parts are only basic ones (mouth romo, eye, ear, legs pata/pezuna, horn cuerno, crest, plate, spike, arm_grasper). The A25 starter budget is not numerically defined in the repo (creator shows x/320); proposal: starter budget 120 DNA (starting value, to be checked in play): all candidates fit it. DNA = part costs + 5 per node beyond 6 (creature.gd).

## Numbers (zoo bodies start0/startA-D, `make`-less: see "Reproduce")
| | parts | DNA | length m | hip m | mass kg | fit fails | leg ext (walk) | head pitch mean (walk) | slip p95 cm (turn / steps) |
|---|---|---|---|---|---|---|---|---|---|
| hero (Merodeador, 6 t, reference) | 8 | 129 | 6.8 | 1.69 | 6247 | 0 | 0.84 | -3.9 | 0.0 / 2.4 |
| 0 today's hatchling | 4 | 85 | 1.18 | 0.26 | 36.0 | 0 | 0.78 | -2.6 | 0.5 / 0.3 |
| A grazer-hunter | 7 | 100 | 1.20 | 0.52 | 42.4 | 0 | 0.86 | -4.4 | 2.2 / 2.2 |
| B lean runner | 6 | 85 | 1.51 | 0.59 | 38.3 | 0 | 0.86 | -3.2 | 0.0 / 0.0 |
| C armoured sprawler | 7 | 108 | 1.29 | 0.27 | 45.4 | 0 | 0.82 | -3.6 | 0.0 / 1.2 |
| D knuckle-walker | 6 | 114 | 1.13 | 0.59 | 53.1 | 0 | 0.85 | -4.2 | 1.8 / 2.3 |

Full scorecard (5 scenarios x 6 bodies): `scorecard.md`, raw JSON and summary in `docs/evidence/loco/score/starter/`. Fit: `fit.txt`; `make godot-creature-fit` reports 0 of 14 creatures failing (the candidates are checked by `devtools/zoo/starter_check.gd`, 0 failures each).
Read-outs: head pitch is inside 0..-12 deg for every body and scenario; knee flips 0; every candidate beats today's hatchling on leg extension (0.82-0.86 vs 0.78) and matches the hero (0.84-0.87) within 0.02-0.05; slip stays under 3 cm everywhere it is measurable (C had 20 cm on turns until its legs were raised, now 0).
Caveats: at the zoo/play speed (about 5 m/s) every ~1 m body gallops (airborne 0.3-0.5), so slip is "-" (not measurable) on walk/gallop for bodies with flight; the flat profile.speed is S2's job (HATCHLING.md). Foot spacing is below the reference 0.5-1.0 only for D (0.48): the narrow knuckle stance.

## What each is like
- **A Grazer-hunter** (romo, eye, ear, brow horn t .92 ang .55, 2 hoofed legs, crest): sturdy boar-like quadruped, ochre stripes, strong barrel; steady, forgiving, a bit slow-looking. Horn len/head 1.44 (proposal ~1.25).
- **B Lean runner** (romo, large eye, big ear, 2 hoofed legs, crest): long legs and neck, sandy spotted gazelle, lightest and fastest looking, 85 DNA; fragile build.
- **C Armoured sprawler** (romo, eye, 2 clawed legs, 2 plates, spike): low wide olive-slate lizard with banded plates, steady and defensive; low hip (0.27 m) so close to the ground camera-wise.
- **D Knuckle-walker** (romo, eye, 2 clawed legs, arm_grasper, crest): shoulders 1.47x hips, dark ape-like back sloping to the rear, head forward. The arms are the cosmetic `arm_grasper` (arms rule D-12 is still open), so today D locomotes on its legs as a quadruped with raised shoulders; nothing walks on the knuckles yet.

## Switch the default (one line)
`godot/game/game.gd`: `const STARTER := "hatchling"` -> `"a_grazer"`, `"b_runner"`, `"c_sprawler"` or `"d_knuckle"`. The player's fallback genome and the creator's opening seed both follow it (the creator also lists "Starter A..D" among its seeds, copied from the JSON files). `play_test.gd` line 635 expects the creator to open on a creature named "Hatchling": update it with the pick. A saved studio genome in user://studio still wins over the starter, as before.

## Reproduce
- Fit/size/mass/DNA: `godot --headless --path godot --script res://devtools/zoo/starter_check.gd`
- Scorecard: `godot --headless --fixed-fps 30 --path godot --script res://devtools/zoo/loco_score.gd -- <dir> hero,start0,startA,startB,startC,startD`; `python3 tools/loco/summary.py <dir>`; `python3 tools/loco/starter_table.py <dir>`
- Stills: `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/zoo/starter_shots.gd -- <out>`
- Clip: `devtools/zoo/loco_clip.gd -- startA walk 6` (see its header).

## Notes for later
- Winnability vs Garfio (A31) was not run for the candidates (C world, out of scope): the heavier bodies (A, D 42-53 kg vs 36) change the C radius; run `game/tests/winnability_c.gd genome=res://game/data/starters/<file>` before the owner's pick.
- Horn proposal t .92 / ang .55 is used in A; a longer (len .65) horn on a 1 m body is not proportional, so len follows the head (0.12).
