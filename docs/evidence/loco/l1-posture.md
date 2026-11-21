# L1 posture and head: result (branch anim/l1-posture)

Baseline scorecard `9095d8c`, final `ffea2c1` (`docs/evidence/loco/score/ffea2c1/`). Full compare: `python3 tools/loco/compare.py 9095d8c ffea2c1` (253 improved, 119 regressed, 203 unchanged; most regressions are noise-level movement in secondary metrics).
Commits: 6cc970a step 1, c1d233f step 2, b85fd05 step 3, 81e0959 step 4, ffea2c1 fix-up (suites).

## Step 0: rest-pose head check
Head bone to snout tip at rest, no motion: 19.3 deg up on mite, trotter, hero, giant, centipede, hexapod; 37.1 deg on longneck. The generated spine centreline itself rises over the last bones, so the metric is not biased: the rig needs a head/neck counter-rotation (done in `loco_rig_adapter._stabilise_head`). The metric was not changed.

## Key numbers (walk), 9095d8c -> ffea2c1
| body | head pitch mean | leg ext | roll deg | bob frac | slip p95 cm |
|---|---|---|---|---|---|
| hero | 16.6 -> -3.9 | 0.83 -> 0.84 | 3.0 -> 5.2 | 0.220 -> 0.130 | 17.4 -> 1.2 |
| giant | 15.0 -> -2.9 | 0.83 -> 0.85 | 3.0 -> 5.7 | 0.289 -> 0.163 | 24.0 -> 2.8 |
| trotter | 19.0 -> -4.4 | 0.77 -> 0.85 | 2.5 -> 2.0 | 0.151 -> 0.044 | 7.6 -> 0.0 |
| longneck | 35.7 -> -6.8 | 0.85 -> 0.87 | 2.6 -> 4.9 | 0.053 -> 0.064 | 10.5 -> 2.1 |

## What reached the targets
- Head pitch: all four bodies within +-12 deg in walk, gallop, turn and steps (worst: longneck walk -6.8). Longneck head yaw p95 43 -> 13 deg (the steep neck now yaws about the creature's up axis, so the periscope flip is gone) and the neck leans forward by the excess over 34 deg.
- Hero walk roll 5.2 deg (gorilla 7 +- 3), lag 0.13 (0 +- 0.15). Giant 5.7 / 0.17 (lag just outside 0.15).
- Foot slip p95 on hero walk 1.2 cm (< 3), giant walk 2.8 cm. Cause found per stance: hind feet landed with the hip ~1.0 of leg length above the ankle, the reach guard raised the heel to its 60 deg limit, and because the ankle is higher than the toe is long this moves the ankle away: a 15 cm pop on the first frames of the stance. The heel is now only raised when it can fix the leg.
- C trajectory unchanged: speed_mean, moving, pivot, stall, slide fractions and minimum turn radius identical in all 35 cases (visual-only changes; core/ untouched).
- Suites: godot-loco-test 299/0, godot-devtools-test 895/0, godot-test 1138/0, godot-play-test 237/0, godot-actions-test 383/0, godot-feel-test 76/0 (failures in the same suites before the fix-up: loco 11, feel 13, actions 14, play 1, devtools 3 when world_cli was not yet built).

## What did not reach the targets, and why
- Leg extension is 0.84-0.88 on 4-leg bodies, target 0.9. A first version reached 0.90-0.92 (hero, giant, trotter walk) and slip 1.5 cm, but it did so by clipping the stride to 0.34-0.40 of leg length from vertical, which made cadence independent of mass (hero walk 1.2 -> 2.9 Hz) and broke the locomotion suite (stride must shorten uphill, heavier bodies must step slower) and the feel suite. The C speed is fixed (hero 5 m/s on a 1.7 m hip height, Froude ~1), so straight legs and a mass-scaled rhythm cannot both hold; this needs a speed change (C profile, owner decision) or a longer rig leg. Current values are the version that keeps every suite green.
- Hero walk bob 13% (giant 16%), target <= 8% (gorilla 4%); it was 22% / 29% and 5% in the discarded version, for the same reason. Longneck 6%, trotter 4% are inside.
- Foot slip: gallop is still 2.9 (hero), 8.6 (giant) and 4.3 (longneck); giant walk 2.8 passes by a hair. Centipede 2.9, hexapod 3.6.
- Hexapod/centipede leg extension (0.83) and the multi-leg foot spacing (hexapod 0.30, centipede 0.19) are unchanged by design: this step only touched quadrupeds beyond the head.
- Knee flip on trotter steps 0.012 -> 0.037 (still tiny; noted).
- Torso roll for trotter (2.0 deg): it runs a gallop gait at walking speed and the gait roll is scaled 0.55.

## Other changes worth knowing
- Heads now carry a small nod (20% of the controller neck pitch survives, head ~ -3 to -7 deg mean, slightly nose down) and a rate limit per frame; legless bodies are not head-stabilised.
- Neck and head bones use creature-axis rotations relative to the parent's actual pose, so action-layer rotations (bite, eat) still carry the head.

## Evidence
- Scorecards: `docs/evidence/loco/score/ffea2c1/` (baseline `9095d8c`).
- Contact sheets, hero/giant/longneck/centipede walking, before and after: `docs/evidence/loco/l1/*_walk_{before,after}.jpg`.
- Side-by-side with the gorilla (outside the repo): `/home/diego/Desarrollo/cpore-wt/_agent/loco-clips/side_by_side_hero_walk_ffea2c1.mp4`.
