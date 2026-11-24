# Locomotion scorecard `starter`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| hero | walk | -3.9 / 0.0 | 1.20 | 8.1 | 5.2 | 0.13 | 13.0 | 1.2 | 0.41 | 0.00 | 0.84 | 0.85 | 0.00 | 0.00 | 3.6 | 0.00 | 0.00 | 1.00 | **FAIL** 4/15 |
| hero | gallop | -4.5 / -0.6 | 1.22 | 9.2 | 4.0 | 0.18 | 10.4 | 2.9 | 0.52 | 0.00 | 0.85 | 0.66 | 0.00 | 0.00 | 3.8 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| hero | turn | -2.8 / 1.4 | 1.15 | 6.5 | 6.2 | 0.13 | 4.6 | 0.0 | 0.41 | 0.00 | 0.87 | 0.83 | 0.04 | 0.00 | 0.4 | 0.00 | 0.00 | 1.00 | **FAIL** 3/8 |
| hero | climb | -0.5 / 21.1 | 1.13 | 5.7 | 6.0 | 0.12 | 14.1 | 0.0 | 0.42 | 0.00 | 0.86 | 0.83 | 0.00 | 0.13 | 10.7 | 0.00 | 0.00 | 1.08 | **FAIL** 1/6 |
| hero | steps | -2.6 / 6.9 | 1.17 | 7.2 | 6.3 | 0.14 | 13.8 | 2.4 | 0.43 | 0.00 | 0.86 | 0.83 | 0.05 | 0.06 | 0.4 | 0.00 | 0.00 | 0.96 | **FAIL** 5/9 |
| start0 | walk | -2.6 / -0.5 | 1.22 | 8.6 | 2.7 | -0.01 | 9.3 | - | 0.20 | 0.38 | 0.78 | 0.91 | 0.00 | 0.00 | 1.8 | 0.00 | 0.00 | 1.68 | **FAIL** 2/7 |
| start0 | gallop | -2.1 / 6.0 | 1.28 | 9.5 | 3.4 | 0.03 | 30.3 | - | 0.15 | 0.48 | 0.74 | 0.89 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 1.91 | **FAIL** 1/7 |
| start0 | turn | -2.7 / -1.0 | 1.16 | 6.4 | 1.9 | -0.08 | 9.4 | 0.5 | 0.20 | 0.38 | 0.78 | 0.90 | 0.01 | 0.00 | 0.2 | 0.00 | 0.00 | 1.61 | **FAIL** 2/8 |
| start0 | climb | -0.2 / 17.0 | 1.14 | 5.7 | 2.0 | -0.05 | 11.8 | 0.0 | 0.20 | 0.38 | 0.79 | 0.90 | 0.00 | 0.14 | 7.1 | 0.00 | 0.00 | 1.51 | **FAIL** 1/6 |
| start0 | steps | -2.2 / 4.2 | 1.18 | 7.0 | 2.3 | -0.05 | 10.0 | 0.3 | 0.21 | 0.37 | 0.77 | 0.90 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.53 | **FAIL** 2/9 |
| startA | walk | -4.4 / -0.5 | 1.17 | 10.1 | 2.1 | 0.07 | 2.0 | - | 0.24 | 0.35 | 0.86 | 0.65 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.28 | **FAIL** 2/7 |
| startA | gallop | -4.2 / 6.3 | 1.18 | 10.6 | 3.0 | -0.00 | 6.8 | - | 0.17 | 0.44 | 0.85 | 0.57 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 1.24 | **FAIL** 1/7 |
| startA | turn | -4.7 / -0.9 | 1.12 | 7.3 | 1.5 | -0.00 | 1.9 | 2.2 | 0.25 | 0.33 | 0.86 | 0.63 | 0.01 | 0.00 | 0.2 | 0.00 | 0.00 | 1.26 | **FAIL** 2/8 |
| startA | climb | -2.6 / 18.4 | 1.11 | 6.6 | 1.6 | -0.01 | 5.9 | 0.6 | 0.24 | 0.33 | 0.85 | 0.63 | 0.00 | 0.14 | 7.1 | 0.00 | 0.00 | 1.45 | **FAIL** 1/6 |
| startA | steps | -4.0 / 4.4 | 1.13 | 8.0 | 2.0 | 0.01 | 2.6 | 2.2 | 0.26 | 0.33 | 0.85 | 0.63 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.22 | **FAIL** 2/9 |
| startB | walk | -3.2 / -0.9 | 1.14 | 9.8 | 2.6 | -0.00 | 1.8 | 0.5 | 0.25 | 0.33 | 0.86 | 0.61 | 0.00 | 0.00 | 2.2 | 0.00 | 0.00 | 1.43 | **FAIL** 3/8 |
| startB | gallop | -4.0 / 4.3 | 1.15 | 10.1 | 2.7 | 0.01 | 5.2 | - | 0.18 | 0.42 | 0.86 | 0.52 | 0.00 | 0.00 | 2.3 | 0.00 | 0.00 | 1.08 | **FAIL** 2/7 |
| startB | turn | -4.1 / -1.7 | 1.10 | 6.6 | 1.8 | -0.01 | 1.8 | 0.0 | 0.25 | 0.32 | 0.86 | 0.60 | 0.01 | 0.00 | 0.2 | 0.00 | 0.00 | 1.42 | **FAIL** 3/8 |
| startB | climb | -4.5 / 9.4 | 1.08 | 5.8 | 1.9 | -0.01 | 4.3 | 0.0 | 0.25 | 0.33 | 0.85 | 0.61 | 0.00 | 0.14 | 7.1 | 0.00 | 0.00 | 1.47 | **FAIL** 1/6 |
| startB | steps | -3.6 / 10.0 | 1.11 | 7.7 | 2.8 | -0.01 | 3.8 | 0.0 | 0.27 | 0.31 | 0.84 | 0.59 | 0.03 | 0.09 | 0.3 | 0.00 | 0.00 | 1.38 | **FAIL** 4/9 |
| startC | walk | -3.6 / -0.9 | 1.11 | 3.8 | 2.5 | -0.04 | 4.4 | - | 0.20 | 0.38 | 0.82 | 1.20 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 1.35 | **FAIL** 2/7 |
| startC | gallop | -3.1 / 5.0 | 1.18 | 5.8 | 3.1 | 0.07 | 15.2 | - | 0.15 | 0.48 | 0.79 | 1.10 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 2.51 | **FAIL** 1/7 |
| startC | turn | -3.6 / -1.0 | 1.07 | 2.5 | 1.8 | -0.04 | 4.2 | 0.0 | 0.21 | 0.37 | 0.82 | 1.19 | 0.01 | 0.00 | 0.2 | 0.00 | 0.00 | 1.32 | **FAIL** 2/8 |
| startC | climb | -1.4 / 19.2 | 1.05 | 1.6 | 1.8 | -0.03 | 8.3 | 0.0 | 0.21 | 0.37 | 0.82 | 1.20 | 0.00 | 0.14 | 7.1 | 0.00 | 0.00 | 1.34 | **FAIL** 1/6 |
| startC | steps | -2.5 / 14.8 | 1.09 | 2.9 | 2.4 | -0.03 | 9.7 | 1.2 | 0.22 | 0.36 | 0.80 | 1.18 | 0.03 | 0.09 | 0.3 | 0.00 | 0.00 | 1.25 | **FAIL** 3/9 |
| startD | walk | -4.4 / -0.1 | 1.47 | 25.4 | 2.1 | 0.06 | 5.7 | 1.0 | 0.25 | 0.33 | 0.85 | 0.49 | 0.00 | 0.00 | 1.8 | 0.00 | 0.00 | 1.33 | **FAIL** 2/8 |
| startD | gallop | -4.2 / 5.8 | 1.49 | 25.5 | 2.8 | 0.02 | 10.0 | - | 0.17 | 0.43 | 0.83 | 0.45 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 1.01 | **FAIL** 1/7 |
| startD | turn | -4.7 / -0.9 | 1.41 | 22.3 | 1.9 | 0.01 | 5.1 | 1.8 | 0.26 | 0.32 | 0.85 | 0.48 | 0.01 | 0.00 | 0.2 | 0.00 | 0.00 | 1.32 | **FAIL** 2/8 |
| startD | climb | -2.7 / 17.2 | 1.40 | 22.4 | 1.9 | -0.01 | 7.6 | 0.3 | 0.25 | 0.32 | 0.85 | 0.48 | 0.00 | 0.14 | 7.1 | 0.00 | 0.00 | 1.29 | **FAIL** 3/6 |
| startD | steps | -3.8 / 4.9 | 1.42 | 22.9 | 2.5 | 0.03 | 5.6 | 2.3 | 0.26 | 0.31 | 0.84 | 0.47 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.30 | **FAIL** 2/9 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| head pitched to the sky | head_pitch | 0 / 24 |
| crouched legs | leg_extension | 24 / 24 |
| gallop is a fast walk | air_gallop | 1 / 6 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 19 / 66 |
| centipede legs bunched | foot_spacing | 0 / 0 |
| climbing barely changes posture | climb_posture, climb_follow | 7 / 12 |
| steps course stalls | stall_steps | 3 / 6 |
| legs bend the wrong way | knee_flip | 1 / 30 |
| legs through the ground | foot_penetration | 0 / 30 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 1 / 3 |

## Failing checks

- **hero walk**: leg_extension 0.845 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.197 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 8.070 vs 22+-8 (back_slope_deg); gorilla:torso_bob_frac 0.130 vs 0.04+-0.03 (torso_bob_frac)
- **hero gallop**: air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.853 vs >=0.9 (leg_extension)
- **hero turn**: pivot_turns 0.436 vs <0.15 (pivot_frac_of_turns); leg_extension 0.874 vs >=0.9 (leg_extension); head_periscope 37.580 vs <30 (head_yaw_vs_body_deg.p95)
- **hero climb**: climb_posture 2.420 vs >=5 (climb_posture_shift_deg)
- **hero steps**: pivot 0.052 vs <0.05 (pivot_frac); pivot_turns 0.214 vs <0.15 (pivot_frac_of_turns); stall_steps 0.057 vs ==0 (stall_frac); leg_extension 0.856 vs >=0.9 (leg_extension); head_periscope 36.990 vs <30 (head_yaw_vs_body_deg.p95)
- **start0 walk**: air_walk 0.379 vs <=0.005 (airborne_frac); leg_extension 0.780 vs >=0.9 (leg_extension)
- **start0 gallop**: leg_extension 0.743 vs >=0.9 (leg_extension)
- **start0 turn**: pivot_turns 0.174 vs <0.15 (pivot_frac_of_turns); leg_extension 0.783 vs >=0.9 (leg_extension)
- **start0 climb**: climb_posture 2.890 vs >=5 (climb_posture_shift_deg)
- **start0 steps**: pivot_turns 0.188 vs <0.15 (pivot_frac_of_turns); leg_extension 0.774 vs >=0.9 (leg_extension)
- **startA walk**: air_walk 0.353 vs <=0.005 (airborne_frac); leg_extension 0.858 vs >=0.9 (leg_extension)
- **startA gallop**: leg_extension 0.845 vs >=0.9 (leg_extension)
- **startA turn**: pivot_turns 0.167 vs <0.15 (pivot_frac_of_turns); leg_extension 0.855 vs >=0.9 (leg_extension)
- **startA climb**: climb_posture 3.480 vs >=5 (climb_posture_shift_deg)
- **startA steps**: pivot_turns 0.188 vs <0.15 (pivot_frac_of_turns); leg_extension 0.847 vs >=0.9 (leg_extension)
- **startB walk**: air_walk 0.331 vs <=0.005 (airborne_frac); leg_extension 0.862 vs >=0.9 (leg_extension); head_periscope 55.490 vs <30 (head_yaw_vs_body_deg.p95)
- **startB gallop**: leg_extension 0.855 vs >=0.9 (leg_extension); head_periscope 57.620 vs <30 (head_yaw_vs_body_deg.p95)
- **startB turn**: pivot_turns 0.217 vs <0.15 (pivot_frac_of_turns); leg_extension 0.861 vs >=0.9 (leg_extension); head_periscope 86.170 vs <30 (head_yaw_vs_body_deg.p95)
- **startB climb**: climb_posture 3.950 vs >=5 (climb_posture_shift_deg)
- **startB steps**: pivot_turns 0.182 vs <0.15 (pivot_frac_of_turns); stall_steps 0.091 vs ==0 (stall_frac); leg_extension 0.843 vs >=0.9 (leg_extension); head_periscope 100.580 vs <30 (head_yaw_vs_body_deg.p95)
- **startC walk**: air_walk 0.376 vs <=0.005 (airborne_frac); leg_extension 0.817 vs >=0.9 (leg_extension)
- **startC gallop**: leg_extension 0.789 vs >=0.9 (leg_extension)
- **startC turn**: pivot_turns 0.217 vs <0.15 (pivot_frac_of_turns); leg_extension 0.824 vs >=0.9 (leg_extension)
- **startC climb**: climb_posture 2.220 vs >=5 (climb_posture_shift_deg)
- **startC steps**: pivot_turns 0.188 vs <0.15 (pivot_frac_of_turns); stall_steps 0.091 vs ==0 (stall_frac); leg_extension 0.802 vs >=0.9 (leg_extension)
- **startD walk**: air_walk 0.332 vs <=0.005 (airborne_frac); leg_extension 0.845 vs >=0.9 (leg_extension)
- **startD gallop**: leg_extension 0.835 vs >=0.9 (leg_extension)
- **startD turn**: pivot_turns 0.174 vs <0.15 (pivot_frac_of_turns); leg_extension 0.850 vs >=0.9 (leg_extension)
- **startD climb**: knee_flip 0.002 vs ==0 (knee_flip_frac); climb_follow 0.549 vs >=0.6 (pitch_follow); climb_posture 3.030 vs >=5 (climb_posture_shift_deg)
- **startD steps**: pivot_turns 0.194 vs <0.15 (pivot_frac_of_turns); leg_extension 0.843 vs >=0.9 (leg_extension)
