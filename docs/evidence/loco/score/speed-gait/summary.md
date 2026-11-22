# Locomotion scorecard `speed-gait`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | limp index | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mite | walk | 0.2 / 3.0 | - | - | 2.6 | 0.13 | - | 0.0 | 0.55 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.01 | 1.01 | **FAIL** 2/9 |
| mite | gallop | -5.0 / 2.4 | - | - | 3.2 | 0.03 | - | 0.0 | 0.23 | 0.55 | 0.69 | - | 0.00 | 0.00 | 0.5 | 0.00 | 0.00 | 0.97 | 1.09 | **FAIL** 2/8 |
| mite | turn | -0.6 / 2.6 | - | - | 2.6 | 0.13 | - | 0.0 | 0.55 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | **FAIL** 2/7 |
| mite | climb | 0.2 / 2.7 | - | - | 2.6 | 0.13 | - | 0.0 | 0.55 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | PASS 0/4 |
| mite | steps | 0.1 / 3.5 | - | - | 2.6 | 0.13 | - | 0.0 | 0.55 | 0.00 | 0.84 | - | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.00 | **FAIL** 2/8 |
| trotter | walk | 1.2 / 3.7 | 1.17 | 5.5 | 4.3 | 0.22 | 7.4 | 0.0 | 0.70 | 0.00 | 0.68 | 0.88 | 0.00 | 0.00 | 0.8 | 0.00 | 0.00 | 0.98 | 2.51 | **FAIL** 2/9 |
| trotter | gallop | -1.9 / 3.6 | 1.01 | 0.3 | 4.1 | 0.38 | 18.5 | 0.0 | 0.25 | 0.25 | 0.77 | 1.08 | 0.00 | 0.00 | 0.9 | 0.00 | 0.00 | 3.67 | 1.47 | **FAIL** 1/8 |
| trotter | turn | 0.6 / 3.1 | 1.17 | 5.7 | 3.8 | 0.21 | 3.7 | 0.0 | 0.70 | 0.00 | 0.69 | 0.86 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.48 | **FAIL** 2/7 |
| trotter | climb | 1.1 / 3.8 | 1.17 | 5.7 | 3.9 | 0.21 | 4.9 | 0.0 | 0.70 | 0.00 | 0.68 | 0.88 | 0.00 | 0.00 | 2.0 | 0.00 | 0.00 | 0.99 | 1.31 | **FAIL** 1/6 |
| trotter | steps | 1.2 / 4.0 | 1.17 | 5.6 | 4.0 | 0.22 | 4.8 | 0.0 | 0.70 | 0.00 | 0.69 | 0.86 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 0.99 | 1.66 | **FAIL** 1/9 |
| hero | walk | 1.2 / 4.0 | 1.10 | 4.1 | 4.0 | 0.24 | 9.4 | 0.0 | 0.70 | 0.00 | 0.87 | 0.82 | 0.00 | 0.00 | 1.4 | 0.00 | 0.00 | 0.95 | 2.17 | **FAIL** 6/16 |
| hero | gallop | -2.8 / 0.6 | 1.09 | 4.0 | 3.2 | 0.10 | 14.5 | 0.0 | 0.54 | 0.00 | 0.84 | 0.86 | 0.00 | 0.00 | 1.6 | 0.00 | 0.00 | 1.02 | 1.32 | **FAIL** 2/8 |
| hero | turn | 0.5 / 3.1 | 1.12 | 5.2 | 4.1 | 0.24 | 4.6 | 0.0 | 0.70 | 0.00 | 0.88 | 0.82 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.32 | **FAIL** 1/7 |
| hero | climb | 1.4 / 18.8 | 1.13 | 5.6 | 3.6 | 0.24 | 9.3 | 0.0 | 0.70 | 0.00 | 0.86 | 0.87 | 0.03 | 0.00 | 0.4 | 0.00 | 0.00 | 0.98 | 1.96 | **FAIL** 2/6 |
| hero | steps | 1.1 / 4.1 | 1.12 | 5.1 | 4.3 | 0.26 | 5.8 | 0.0 | 0.70 | 0.00 | 0.88 | 0.82 | 0.00 | 0.00 | 1.2 | 0.00 | 0.00 | 1.00 | 1.27 | **FAIL** 1/9 |
| giant | walk | 0.7 / 4.0 | 1.11 | 5.0 | 3.9 | 0.24 | 6.3 | 0.0 | 0.70 | 0.00 | 0.88 | 0.93 | 0.00 | 0.00 | 2.1 | 0.00 | 0.00 | 0.95 | 1.59 | **FAIL** 6/16 |
| giant | gallop | -3.4 / 0.8 | 1.10 | 4.0 | 3.2 | 0.09 | 14.5 | 0.9 | 0.54 | 0.00 | 0.84 | 0.87 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.00 | 1.19 | **FAIL** 2/8 |
| giant | turn | 0.4 / 3.1 | 1.12 | 5.2 | 4.1 | 0.24 | 4.9 | 0.0 | 0.70 | 0.00 | 0.88 | 0.83 | 0.00 | 0.00 | - | 0.00 | 0.00 | 0.99 | 1.28 | **FAIL** 1/7 |
| giant | climb | 3.8 / 61.3 | 1.26 | 8.6 | 3.7 | 0.21 | 19.3 | 0.0 | 0.69 | 0.00 | 0.83 | 0.89 | 0.00 | 0.01 | - | 0.01 | 0.00 | 1.00 | 2.02 | **FAIL** 2/6 |
| giant | steps | 1.0 / 4.2 | 1.12 | 5.1 | 4.7 | 0.26 | 5.7 | 0.0 | 0.70 | 0.00 | 0.87 | 0.83 | 0.00 | 0.00 | 1.6 | 0.00 | 0.00 | 1.01 | 1.28 | **FAIL** 1/9 |
| longneck | walk | -2.4 / -0.0 | 1.54 | 18.5 | 4.2 | 0.23 | 4.4 | 0.0 | 0.70 | 0.00 | 0.87 | 0.90 | 0.00 | 0.00 | 1.0 | 0.00 | 0.00 | 0.99 | 1.96 | **FAIL** 3/9 |
| longneck | gallop | -5.1 / -2.3 | 1.50 | 17.1 | 3.8 | 0.11 | 8.3 | 0.0 | 0.54 | 0.00 | 0.87 | 0.91 | 0.00 | 0.00 | 1.2 | 0.00 | 0.00 | 1.00 | 1.12 | **FAIL** 3/8 |
| longneck | turn | -2.6 / -0.2 | 1.54 | 18.7 | 4.0 | 0.22 | 2.4 | 0.0 | 0.70 | 0.00 | 0.88 | 0.88 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.40 | **FAIL** 2/7 |
| longneck | climb | -2.2 / 0.6 | 1.59 | 20.0 | 2.8 | 0.22 | 8.3 | 0.0 | 0.70 | 0.00 | 0.85 | 0.89 | 0.03 | 0.00 | 0.5 | 0.00 | 0.00 | 0.95 | 1.78 | **FAIL** 1/6 |
| longneck | steps | -1.7 / 0.9 | 1.54 | 18.7 | 4.2 | 0.22 | 2.5 | 0.0 | 0.70 | 0.00 | 0.88 | 0.88 | 0.00 | 0.00 | 0.7 | 0.00 | 0.00 | 0.98 | 1.47 | **FAIL** 2/9 |
| centipede | walk | 0.5 / 3.2 | 1.25 | 6.3 | 1.9 | 0.18 | 7.6 | 0.3 | 0.68 | 0.00 | 0.88 | 0.35 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 4.99 | **FAIL** 2/10 |
| centipede | gallop | -3.0 / 0.1 | 1.26 | 6.5 | 2.3 | 0.12 | 5.7 | 1.3 | 0.56 | 0.00 | 0.86 | 0.45 | 0.00 | 0.00 | 0.8 | 0.00 | 0.00 | 1.00 | 1.08 | **FAIL** 2/8 |
| centipede | turn | -0.1 / 2.5 | 1.24 | 6.3 | 1.9 | 0.19 | 1.2 | 0.0 | 0.68 | 0.00 | 0.89 | 0.33 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 4.17 | **FAIL** 1/8 |
| centipede | climb | 0.4 / 2.6 | 1.26 | 6.4 | 2.0 | 0.20 | 1.7 | 0.1 | 0.68 | 0.00 | 0.87 | 0.35 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.00 | 2.66 | **FAIL** 1/6 |
| centipede | steps | 0.4 / 3.2 | 1.24 | 6.3 | 1.9 | 0.19 | 1.8 | 0.0 | 0.68 | 0.00 | 0.89 | 0.33 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 3.54 | **FAIL** 1/10 |
| hexapod | walk | 0.7 / 2.8 | 1.19 | 5.1 | 2.1 | 0.21 | 6.0 | 0.0 | 0.66 | 0.00 | 0.82 | 0.40 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.01 | 1.56 | **FAIL** 2/10 |
| hexapod | gallop | -2.8 / 1.4 | 1.20 | 5.4 | 2.8 | 0.12 | 6.8 | 0.0 | 0.51 | 0.00 | 0.82 | 0.35 | 0.00 | 0.00 | 0.7 | 0.00 | 0.00 | 1.00 | 1.19 | **FAIL** 1/8 |
| hexapod | turn | 0.1 / 2.6 | 1.19 | 5.3 | 2.0 | 0.20 | 2.2 | 0.0 | 0.66 | 0.00 | 0.83 | 0.42 | 0.00 | 0.00 | - | 0.00 | 0.00 | 1.00 | 1.37 | **FAIL** 1/8 |
| hexapod | climb | 0.7 / 2.6 | 1.19 | 5.3 | 2.1 | 0.21 | 2.7 | 0.0 | 0.66 | 0.00 | 0.83 | 0.43 | 0.00 | 0.00 | 1.8 | 0.00 | 0.00 | 1.00 | 1.22 | **FAIL** 1/6 |
| hexapod | steps | 0.7 / 3.3 | 1.20 | 5.4 | 2.1 | 0.21 | 2.8 | 0.0 | 0.66 | 0.00 | 0.83 | 0.42 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | 1.24 | **FAIL** 1/10 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| uneven left/right footfall drops or roll | limp | 6 / 7 |
| head pitched to the sky | head_pitch | 0 / 28 |
| crouched legs | leg_extension | 28 / 28 |
| gallop is a fast walk | air_gallop | 3 / 5 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 9 / 69 |
| centipede legs bunched | foot_spacing | 0 / 8 |
| climbing barely changes posture | climb_posture, climb_follow | 6 / 12 |
| steps course stalls | stall_steps | 0 / 7 |
| legs bend the wrong way | knee_flip | 3 / 35 |
| legs through the ground | foot_penetration | 0 / 35 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 4 / 6 |

## Failing checks

- **mite walk**: leg_extension 0.843 vs >=0.9 (leg_extension); head_periscope 38.090 vs <30 (head_yaw_vs_body_deg.p95)
- **mite gallop**: leg_extension 0.690 vs >=0.9 (leg_extension); head_periscope 41.200 vs <30 (head_yaw_vs_body_deg.p95)
- **mite turn**: leg_extension 0.843 vs >=0.9 (leg_extension); head_periscope 56.970 vs <30 (head_yaw_vs_body_deg.p95)
- **mite steps**: leg_extension 0.843 vs >=0.9 (leg_extension); head_periscope 41.620 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter walk**: limp 2.511 vs <=1.15 (limp_index); leg_extension 0.684 vs >=0.9 (leg_extension)
- **trotter gallop**: leg_extension 0.770 vs >=0.9 (leg_extension)
- **trotter turn**: leg_extension 0.689 vs >=0.9 (leg_extension); head_periscope 31.890 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter climb**: climb_posture 0.150 vs >=5 (climb_posture_shift_deg)
- **trotter steps**: leg_extension 0.689 vs >=0.9 (leg_extension)
- **hero walk**: limp 2.171 vs <=1.15 (limp_index); leg_extension 0.868 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.095 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 4.100 vs 22+-8 (back_slope_deg); gorilla:roll_plant_lag 0.237 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.094 vs 0.04+-0.03 (torso_bob_frac)
- **hero gallop**: air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.843 vs >=0.9 (leg_extension)
- **hero turn**: leg_extension 0.879 vs >=0.9 (leg_extension)
- **hero climb**: knee_flip 0.003 vs ==0 (knee_flip_frac); climb_posture 1.540 vs >=5 (climb_posture_shift_deg)
- **hero steps**: leg_extension 0.878 vs >=0.9 (leg_extension)
- **giant walk**: limp 1.586 vs <=1.15 (limp_index); leg_extension 0.880 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.113 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 5.000 vs 22+-8 (back_slope_deg); gorilla:torso_roll_deg 3.940 vs 7+-3 (torso_roll_deg); gorilla:roll_plant_lag 0.238 vs 0+-0.15 (roll_plant_lag)
- **giant gallop**: air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.844 vs >=0.9 (leg_extension)
- **giant turn**: leg_extension 0.882 vs >=0.9 (leg_extension)
- **giant climb**: knee_flip 0.006 vs ==0 (knee_flip_frac); climb_posture 3.580 vs >=5 (climb_posture_shift_deg)
- **giant steps**: leg_extension 0.875 vs >=0.9 (leg_extension)
- **longneck walk**: limp 1.956 vs <=1.15 (limp_index); leg_extension 0.875 vs >=0.9 (leg_extension); head_periscope 69.550 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck gallop**: air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.866 vs >=0.9 (leg_extension); head_periscope 58.090 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck turn**: leg_extension 0.877 vs >=0.9 (leg_extension); head_periscope 149.530 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck climb**: climb_posture 1.490 vs >=5 (climb_posture_shift_deg)
- **longneck steps**: leg_extension 0.877 vs >=0.9 (leg_extension); head_periscope 96.610 vs <30 (head_yaw_vs_body_deg.p95)
- **centipede walk**: limp 4.993 vs <=1.15 (limp_index); leg_extension 0.876 vs >=0.9 (leg_extension)
- **centipede gallop**: knee_flip 0.001 vs ==0 (knee_flip_frac); leg_extension 0.860 vs >=0.9 (leg_extension)
- **centipede turn**: leg_extension 0.891 vs >=0.9 (leg_extension)
- **centipede climb**: climb_posture 0.110 vs >=5 (climb_posture_shift_deg)
- **centipede steps**: leg_extension 0.890 vs >=0.9 (leg_extension)
- **hexapod walk**: limp 1.558 vs <=1.15 (limp_index); leg_extension 0.822 vs >=0.9 (leg_extension)
- **hexapod gallop**: leg_extension 0.815 vs >=0.9 (leg_extension)
- **hexapod turn**: leg_extension 0.831 vs >=0.9 (leg_extension)
- **hexapod climb**: climb_posture 0.130 vs >=5 (climb_posture_shift_deg)
- **hexapod steps**: leg_extension 0.830 vs >=0.9 (leg_extension)
