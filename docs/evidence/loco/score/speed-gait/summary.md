# Locomotion scorecard `speed-gait`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | limp index | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mite | walk | 0.2 / 3.3 | - | - | 2.9 | 0.14 | - | 0.0 | 0.66 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 0.99 | 1.01 | **FAIL** 2/9 |
| mite | gallop | -2.6 / 0.9 | - | - | 3.2 | 0.06 | - | 0.0 | 0.30 | 0.41 | 0.75 | - | 0.00 | 0.00 | 0.5 | 0.00 | 0.00 | 0.99 | 1.15 | **FAIL** 2/8 |
| mite | turn | -0.7 / 2.4 | - | - | 2.9 | 0.14 | - | 0.0 | 0.66 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | **FAIL** 2/7 |
| mite | climb | 0.2 / 2.5 | - | - | 2.9 | 0.14 | - | 0.0 | 0.66 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | PASS 0/4 |
| mite | steps | 0.1 / 3.5 | - | - | 2.9 | 0.14 | - | 0.0 | 0.66 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.01 | **FAIL** 2/8 |
| trotter | walk | 1.1 / 4.3 | 1.12 | 5.2 | 6.8 | 0.20 | 9.9 | 0.0 | 0.67 | 0.00 | 0.84 | 0.82 | 0.00 | 0.00 | 0.8 | 0.00 | 0.00 | 0.99 | 2.16 | **FAIL** 2/9 |
| trotter | gallop | -2.2 / 1.5 | 1.06 | 2.4 | 5.9 | 0.15 | 16.9 | 0.0 | 0.32 | 0.10 | 0.78 | 0.69 | 0.00 | 0.00 | 0.9 | 0.00 | 0.00 | 0.44 | 1.45 | **FAIL** 1/8 |
| trotter | turn | 0.4 / 2.9 | 1.13 | 5.5 | 6.5 | 0.20 | 3.0 | 0.0 | 0.67 | 0.00 | 0.85 | 0.79 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.02 | 1.08 | **FAIL** 1/7 |
| trotter | climb | 0.8 / 3.2 | 1.13 | 5.5 | 6.5 | 0.21 | 4.8 | 0.0 | 0.67 | 0.00 | 0.85 | 0.81 | 0.00 | 0.00 | 2.0 | 0.00 | 0.00 | 1.00 | 1.20 | **FAIL** 1/6 |
| trotter | steps | 1.0 / 4.1 | 1.13 | 5.5 | 6.8 | 0.20 | 3.4 | 0.0 | 0.67 | 0.00 | 0.85 | 0.79 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 0.99 | 1.33 | **FAIL** 1/9 |
| hero | walk | 1.0 / 4.6 | 1.12 | 5.0 | 6.9 | 0.21 | 10.3 | 0.0 | 0.67 | 0.00 | 0.86 | 0.87 | 0.00 | 0.00 | 1.4 | 0.00 | 0.00 | 0.98 | 2.25 | **FAIL** 6/16 |
| hero | gallop | -2.6 / 0.5 | 1.07 | 2.9 | 4.8 | 0.13 | 13.2 | 0.8 | 0.33 | 0.14 | 0.82 | 0.65 | 0.00 | 0.00 | 1.6 | 0.00 | 0.00 | 0.55 | 2.17 | **FAIL** 1/8 |
| hero | turn | 0.5 / 2.9 | 1.12 | 5.3 | 7.0 | 0.21 | 4.1 | 0.0 | 0.67 | 0.00 | 0.87 | 0.82 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.03 | **FAIL** 1/7 |
| hero | climb | 0.3 / 4.6 | 1.14 | 6.1 | 6.6 | 0.23 | 12.7 | 0.0 | 0.68 | 0.00 | 0.86 | 0.87 | 0.03 | 0.00 | 0.4 | 0.00 | 0.00 | 0.96 | 2.83 | **FAIL** 1/6 |
| hero | steps | 1.1 / 4.7 | 1.12 | 5.2 | 7.2 | 0.21 | 8.7 | 0.0 | 0.67 | 0.00 | 0.86 | 0.82 | 0.00 | 0.00 | 1.2 | 0.00 | 0.00 | 1.00 | 1.15 | **FAIL** 1/9 |
| giant | walk | 0.7 / 4.6 | 1.12 | 5.2 | 7.0 | 0.21 | 11.4 | 0.0 | 0.67 | 0.00 | 0.87 | 0.92 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 1.01 | 1.36 | **FAIL** 6/16 |
| giant | gallop | -2.7 / 0.7 | 1.07 | 2.9 | 4.7 | 0.14 | 11.3 | 0.0 | 0.34 | 0.27 | 0.84 | 0.63 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 0.77 | 1.18 | **FAIL** 1/8 |
| giant | turn | 0.4 / 2.9 | 1.12 | 5.3 | 7.2 | 0.21 | 4.4 | 0.0 | 0.67 | 0.00 | 0.87 | 0.83 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.02 | **FAIL** 1/7 |
| giant | climb | 4.8 / 65.2 | 1.24 | 8.1 | 7.6 | 0.22 | 17.6 | 0.0 | 0.68 | 0.00 | 0.84 | 0.87 | 0.00 | 0.01 | - | 0.00 | 0.00 | 0.99 | 1.81 | **FAIL** 1/6 |
| giant | steps | 1.1 / 4.8 | 1.12 | 5.3 | 7.5 | 0.22 | 9.6 | 0.0 | 0.67 | 0.00 | 0.86 | 0.83 | 0.00 | 0.00 | 1.6 | 0.00 | 0.00 | 0.99 | 1.32 | **FAIL** 1/9 |
| longneck | walk | -1.9 / 0.1 | 1.55 | 18.7 | 7.1 | 0.21 | 5.6 | 0.0 | 0.68 | 0.00 | 0.87 | 0.89 | 0.00 | 0.00 | 1.0 | 0.00 | 0.00 | 1.00 | 2.60 | **FAIL** 3/9 |
| longneck | gallop | -4.8 / -1.9 | 1.46 | 14.9 | 6.0 | 0.14 | 10.2 | 0.0 | 0.34 | 0.28 | 0.81 | 0.60 | 0.00 | 0.00 | 1.2 | 0.00 | 0.00 | 0.79 | 1.25 | **FAIL** 2/8 |
| longneck | turn | -2.5 / -0.3 | 1.55 | 18.8 | 6.9 | 0.20 | 2.1 | 0.0 | 0.68 | 0.00 | 0.87 | 0.87 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.03 | **FAIL** 2/7 |
| longneck | climb | -2.1 / 0.6 | 1.59 | 20.2 | 6.6 | 0.23 | 7.8 | 0.0 | 0.69 | 0.00 | 0.85 | 0.87 | 0.03 | 0.00 | 0.5 | 0.00 | 0.00 | 1.03 | 1.48 | **FAIL** 1/6 |
| longneck | steps | -1.8 / 0.1 | 1.55 | 18.8 | 6.9 | 0.20 | 2.8 | 0.0 | 0.68 | 0.00 | 0.87 | 0.87 | 0.00 | 0.00 | 0.7 | 0.00 | 0.00 | 1.01 | 1.56 | **FAIL** 2/9 |
| centipede | walk | 0.5 / 2.9 | 1.25 | 6.3 | 1.9 | 0.19 | 5.1 | 0.0 | 0.64 | 0.00 | 0.88 | 0.28 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 5.23 | **FAIL** 3/10 |
| centipede | gallop | -3.0 / -0.1 | 1.26 | 6.5 | 2.3 | 0.12 | 4.6 | 1.2 | 0.57 | 0.00 | 0.86 | 0.43 | 0.00 | 0.00 | 0.8 | 0.00 | 0.00 | 1.00 | 1.06 | **FAIL** 1/8 |
| centipede | turn | -0.2 / 2.4 | 1.24 | 6.3 | 1.9 | 0.19 | 0.3 | 0.0 | 0.64 | 0.00 | 0.89 | 0.26 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.01 | 1.04 | **FAIL** 2/8 |
| centipede | climb | 0.4 / 2.7 | 1.26 | 6.4 | 1.9 | 0.19 | 1.0 | 0.0 | 0.65 | 0.00 | 0.87 | 0.28 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.01 | 1.57 | **FAIL** 1/6 |
| centipede | steps | 0.4 / 3.3 | 1.24 | 6.3 | 1.9 | 0.19 | 0.5 | 0.0 | 0.64 | 0.00 | 0.89 | 0.26 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 0.99 | 1.65 | **FAIL** 2/10 |
| hexapod | walk | 0.7 / 2.7 | 1.18 | 5.3 | 2.2 | 0.19 | 5.7 | 0.0 | 0.61 | 0.00 | 0.89 | 0.41 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 1.39 | **FAIL** 2/10 |
| hexapod | gallop | -2.6 / 1.5 | 1.19 | 5.3 | 2.7 | 0.15 | 8.6 | 3.2 | 0.53 | 0.00 | 0.86 | 0.37 | 0.00 | 0.00 | 0.7 | 0.00 | 0.00 | 1.00 | 1.22 | **FAIL** 2/8 |
| hexapod | turn | 0.1 / 2.5 | 1.18 | 5.4 | 2.1 | 0.19 | 4.2 | 0.0 | 0.61 | 0.00 | 0.89 | 0.40 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | **FAIL** 1/8 |
| hexapod | climb | 0.7 / 2.6 | 1.18 | 5.3 | 2.1 | 0.19 | 4.4 | 0.0 | 0.61 | 0.00 | 0.88 | 0.41 | 0.00 | 0.00 | 1.8 | 0.00 | 0.00 | 1.01 | 1.02 | **FAIL** 1/6 |
| hexapod | steps | 0.7 / 3.3 | 1.18 | 5.4 | 2.1 | 0.19 | 4.8 | 0.0 | 0.61 | 0.00 | 0.89 | 0.40 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 1.12 | **FAIL** 1/10 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| uneven left/right footfall drops or roll | limp | 6 / 7 |
| head pitched to the sky | head_pitch | 0 / 28 |
| crouched legs | leg_extension | 28 / 28 |
| gallop is a fast walk | air_gallop | 0 / 5 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 8 / 69 |
| centipede legs bunched | foot_spacing | 3 / 8 |
| climbing barely changes posture | climb_posture, climb_follow | 6 / 12 |
| steps course stalls | stall_steps | 0 / 7 |
| legs bend the wrong way | knee_flip | 0 / 35 |
| legs through the ground | foot_penetration | 0 / 35 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 4 / 6 |

## Failing checks

- **mite walk**: leg_extension 0.845 vs >=0.9 (leg_extension); head_periscope 38.150 vs <30 (head_yaw_vs_body_deg.p95)
- **mite gallop**: leg_extension 0.748 vs >=0.9 (leg_extension); head_periscope 40.790 vs <30 (head_yaw_vs_body_deg.p95)
- **mite turn**: leg_extension 0.845 vs >=0.9 (leg_extension); head_periscope 56.760 vs <30 (head_yaw_vs_body_deg.p95)
- **mite steps**: leg_extension 0.845 vs >=0.9 (leg_extension); head_periscope 42.630 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter walk**: limp 2.161 vs <=1.15 (limp_index); leg_extension 0.845 vs >=0.9 (leg_extension)
- **trotter gallop**: leg_extension 0.777 vs >=0.9 (leg_extension)
- **trotter turn**: leg_extension 0.853 vs >=0.9 (leg_extension)
- **trotter climb**: climb_posture 0.280 vs >=5 (climb_posture_shift_deg)
- **trotter steps**: leg_extension 0.853 vs >=0.9 (leg_extension)
- **hero walk**: limp 2.249 vs <=1.15 (limp_index); leg_extension 0.863 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.115 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 4.980 vs 22+-8 (back_slope_deg); gorilla:roll_plant_lag 0.214 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.103 vs 0.04+-0.03 (torso_bob_frac)
- **hero gallop**: leg_extension 0.815 vs >=0.9 (leg_extension)
- **hero turn**: leg_extension 0.867 vs >=0.9 (leg_extension)
- **hero climb**: climb_posture 1.090 vs >=5 (climb_posture_shift_deg)
- **hero steps**: leg_extension 0.864 vs >=0.9 (leg_extension)
- **giant walk**: limp 1.357 vs <=1.15 (limp_index); leg_extension 0.867 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.119 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 5.180 vs 22+-8 (back_slope_deg); gorilla:roll_plant_lag 0.213 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.114 vs 0.04+-0.03 (torso_bob_frac)
- **giant gallop**: leg_extension 0.836 vs >=0.9 (leg_extension)
- **giant turn**: leg_extension 0.870 vs >=0.9 (leg_extension)
- **giant climb**: climb_posture 2.930 vs >=5 (climb_posture_shift_deg)
- **giant steps**: leg_extension 0.862 vs >=0.9 (leg_extension)
- **longneck walk**: limp 2.605 vs <=1.15 (limp_index); leg_extension 0.870 vs >=0.9 (leg_extension); head_periscope 65.110 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck gallop**: leg_extension 0.810 vs >=0.9 (leg_extension); head_periscope 53.540 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck turn**: leg_extension 0.874 vs >=0.9 (leg_extension); head_periscope 136.110 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck climb**: climb_posture 1.510 vs >=5 (climb_posture_shift_deg)
- **longneck steps**: leg_extension 0.874 vs >=0.9 (leg_extension); head_periscope 100.350 vs <30 (head_yaw_vs_body_deg.p95)
- **centipede walk**: limp 5.235 vs <=1.15 (limp_index); leg_extension 0.878 vs >=0.9 (leg_extension); foot_spacing 0.277 vs >=0.3 (foot_spacing_ratio)
- **centipede gallop**: leg_extension 0.861 vs >=0.9 (leg_extension)
- **centipede turn**: leg_extension 0.891 vs >=0.9 (leg_extension); foot_spacing 0.256 vs >=0.3 (foot_spacing_ratio)
- **centipede climb**: climb_posture 0.100 vs >=5 (climb_posture_shift_deg)
- **centipede steps**: leg_extension 0.890 vs >=0.9 (leg_extension); foot_spacing 0.260 vs >=0.3 (foot_spacing_ratio)
- **hexapod walk**: limp 1.390 vs <=1.15 (limp_index); leg_extension 0.885 vs >=0.9 (leg_extension)
- **hexapod gallop**: foot_slip 3.160 vs <3 (foot_slip_cm.p95); leg_extension 0.861 vs >=0.9 (leg_extension)
- **hexapod turn**: leg_extension 0.890 vs >=0.9 (leg_extension)
- **hexapod climb**: climb_posture 0.050 vs >=5 (climb_posture_shift_deg)
- **hexapod steps**: leg_extension 0.889 vs >=0.9 (leg_extension)
