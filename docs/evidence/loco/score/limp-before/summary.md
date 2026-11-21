# Locomotion scorecard `limp-before`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | limp index | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| trotter | walk | -4.4 / -0.7 | 1.24 | 10.0 | 2.0 | 0.05 | 4.4 | 0.0 | 0.26 | 0.32 | 0.85 | 0.99 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 4.47 | 1.73 | **FAIL** 3/9 |
| hero | walk | -3.9 / 0.0 | 1.20 | 8.1 | 5.2 | 0.13 | 13.0 | 1.2 | 0.41 | 0.00 | 0.84 | 0.85 | 0.00 | 0.00 | 3.6 | 0.00 | 0.00 | 1.00 | 1.11 | **FAIL** 4/16 |
| giant | walk | -2.9 / 2.1 | 1.16 | 6.8 | 5.7 | 0.17 | 16.3 | 2.8 | 0.46 | 0.00 | 0.85 | 0.88 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 1.00 | 1.08 | **FAIL** 6/16 |
| longneck | walk | -6.8 / -4.1 | 1.64 | 21.2 | 4.9 | 0.15 | 6.4 | 2.1 | 0.52 | 0.00 | 0.87 | 0.74 | 0.00 | 0.00 | 2.8 | 0.00 | 0.00 | 1.00 | 1.31 | **FAIL** 3/9 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| uneven left/right footfall drops or roll | limp | 2 / 4 |
| head pitched to the sky | head_pitch | 0 / 4 |
| crouched legs | leg_extension | 4 / 4 |
| gallop is a fast walk | air_gallop | 0 / 0 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 2 / 8 |
| centipede legs bunched | foot_spacing | 0 / 0 |
| climbing barely changes posture | climb_posture, climb_follow | 0 / 0 |
| steps course stalls | stall_steps | 0 / 0 |
| legs bend the wrong way | knee_flip | 0 / 4 |
| legs through the ground | foot_penetration | 0 / 4 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 3 / 6 |

## Failing checks

- **trotter walk**: limp 1.732 vs <=1.15 (limp_index); air_walk 0.317 vs <=0.005 (airborne_frac); leg_extension 0.854 vs >=0.9 (leg_extension)
- **hero walk**: leg_extension 0.845 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.197 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 8.070 vs 22+-8 (back_slope_deg); gorilla:torso_bob_frac 0.130 vs 0.04+-0.03 (torso_bob_frac)
- **giant walk**: leg_extension 0.848 vs >=0.9 (leg_extension); head_periscope 39.840 vs <30 (head_yaw_vs_body_deg.p95); gorilla:shoulder_hip_ratio 1.164 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 6.810 vs 22+-8 (back_slope_deg); gorilla:roll_plant_lag 0.172 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.163 vs 0.04+-0.03 (torso_bob_frac)
- **longneck walk**: limp 1.308 vs <=1.15 (limp_index); leg_extension 0.865 vs >=0.9 (leg_extension); head_periscope 71.870 vs <30 (head_yaw_vs_body_deg.p95)
