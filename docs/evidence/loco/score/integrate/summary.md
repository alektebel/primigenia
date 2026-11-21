# Locomotion scorecard `integrate`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mite | walk | -3.4 / 0.2 | - | - | 2.5 | 0.04 | - | - | 0.24 | 0.51 | 0.79 | - | 0.00 | 0.00 | 2.8 | 0.00 | 0.00 | 0.90 | **FAIL** 2/7 |
| mite | gallop | -3.4 / 2.5 | - | - | 2.9 | -0.13 | - | - | 0.21 | 0.58 | 0.78 | - | 0.00 | 0.00 | 2.9 | 0.00 | 0.00 | 1.06 | **FAIL** 1/7 |
| mite | turn | -3.3 / 1.5 | - | - | 1.3 | 0.01 | - | 0.1 | 0.25 | 0.49 | 0.79 | - | 0.00 | 0.00 | 0.2 | 0.00 | 0.00 | 1.02 | **FAIL** 2/8 |
| mite | climb | -4.2 / 16.6 | - | - | 1.4 | -0.00 | - | 0.0 | 0.25 | 0.50 | 0.77 | - | 0.00 | 0.21 | 7.9 | 0.00 | 0.00 | 0.97 | **FAIL** 1/5 |
| mite | steps | -2.5 / 5.0 | - | - | 1.8 | 0.01 | - | 1.8 | 0.26 | 0.49 | 0.80 | - | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 3/9 |
| trotter | walk | -4.4 / -0.7 | 1.24 | 10.0 | 2.0 | 0.05 | 4.4 | 0.0 | 0.26 | 0.32 | 0.85 | 0.99 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 4.47 | **FAIL** 2/8 |
| trotter | gallop | -4.2 / -0.5 | 1.32 | 12.6 | 2.1 | -0.02 | 7.9 | 0.1 | 0.19 | 0.41 | 0.84 | 0.92 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 1.87 | **FAIL** 1/8 |
| trotter | turn | -3.4 / 1.5 | 1.18 | 7.6 | 2.2 | 0.04 | 3.3 | 0.0 | 0.27 | 0.30 | 0.86 | 0.98 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 3.20 | **FAIL** 3/8 |
| trotter | climb | -0.7 / 19.6 | 1.16 | 6.8 | 2.1 | 0.04 | 8.5 | 0.0 | 0.26 | 0.33 | 0.86 | 0.99 | 0.00 | 0.21 | 7.3 | 0.00 | 0.00 | 2.78 | **FAIL** 1/6 |
| trotter | steps | -2.9 / 2.8 | 1.21 | 8.9 | 3.1 | 0.06 | 7.2 | 0.5 | 0.28 | 0.29 | 0.84 | 0.97 | 0.05 | 0.05 | 0.3 | 0.04 | 0.00 | 2.88 | **FAIL** 5/9 |
| hero | walk | -3.9 / 0.0 | 1.20 | 8.1 | 5.2 | 0.13 | 13.0 | 1.2 | 0.41 | 0.00 | 0.84 | 0.85 | 0.00 | 0.00 | 3.6 | 0.00 | 0.00 | 1.00 | **FAIL** 4/15 |
| hero | gallop | -4.5 / -0.6 | 1.22 | 9.2 | 4.0 | 0.18 | 10.4 | 2.9 | 0.52 | 0.00 | 0.85 | 0.66 | 0.00 | 0.00 | 3.8 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| hero | turn | -2.8 / 1.4 | 1.15 | 6.5 | 6.2 | 0.13 | 4.6 | 0.0 | 0.41 | 0.00 | 0.87 | 0.83 | 0.04 | 0.00 | 0.4 | 0.00 | 0.00 | 1.00 | **FAIL** 3/8 |
| hero | climb | -0.5 / 21.1 | 1.13 | 5.7 | 6.0 | 0.12 | 14.1 | 0.0 | 0.42 | 0.00 | 0.86 | 0.83 | 0.00 | 0.13 | 10.7 | 0.00 | 0.00 | 1.08 | **FAIL** 1/6 |
| hero | steps | -2.6 / 6.9 | 1.17 | 7.2 | 6.3 | 0.14 | 13.8 | 2.4 | 0.43 | 0.00 | 0.86 | 0.83 | 0.05 | 0.06 | 0.4 | 0.00 | 0.00 | 0.96 | **FAIL** 5/9 |
| giant | walk | -2.9 / 2.1 | 1.16 | 6.8 | 5.7 | 0.17 | 16.3 | 2.8 | 0.46 | 0.00 | 0.85 | 0.88 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 1.00 | **FAIL** 6/15 |
| giant | gallop | -4.5 / -0.6 | 1.14 | 6.1 | 4.3 | 0.19 | 10.7 | 8.6 | 0.51 | 0.00 | 0.88 | 0.71 | 0.00 | 0.00 | 3.4 | 0.00 | 0.00 | 1.00 | **FAIL** 3/8 |
| giant | turn | -1.2 / 2.8 | 1.13 | 5.8 | 6.6 | 0.16 | 6.3 | 0.0 | 0.47 | 0.00 | 0.88 | 0.86 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| giant | climb | 2.1 / 22.6 | 1.18 | 7.1 | 6.7 | 0.15 | 23.6 | 0.0 | 0.47 | 0.00 | 0.86 | 0.86 | 0.00 | 0.02 | 11.9 | 0.00 | 0.00 | 0.97 | **FAIL** 1/6 |
| giant | steps | -0.6 / 7.2 | 1.13 | 5.7 | 6.5 | 0.16 | 12.6 | 5.0 | 0.48 | 0.00 | 0.86 | 0.82 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | **FAIL** 2/9 |
| longneck | walk | -6.8 / -4.1 | 1.64 | 21.2 | 4.9 | 0.15 | 6.4 | 2.1 | 0.52 | 0.00 | 0.87 | 0.74 | 0.00 | 0.00 | 2.8 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| longneck | gallop | -5.9 / -3.3 | 1.73 | 22.6 | 4.2 | 0.13 | 9.0 | 4.3 | 0.53 | 0.00 | 0.84 | 0.61 | 0.00 | 0.00 | 3.0 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| longneck | turn | -5.7 / -2.7 | 1.56 | 19.3 | 5.3 | 0.14 | 4.3 | 0.0 | 0.52 | 0.00 | 0.89 | 0.71 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 3/8 |
| longneck | climb | -5.9 / 8.5 | 1.51 | 18.3 | 5.2 | 0.12 | 9.7 | 3.5 | 0.52 | 0.00 | 0.87 | 0.72 | 0.00 | 0.12 | 7.1 | 0.00 | 0.00 | 1.11 | **FAIL** 3/6 |
| longneck | steps | -4.9 / 2.7 | 1.60 | 20.1 | 5.4 | 0.15 | 7.2 | 2.1 | 0.52 | 0.00 | 0.87 | 0.72 | 0.06 | 0.01 | 0.3 | 0.01 | 0.00 | 0.96 | **FAIL** 5/9 |
| centipede | walk | -3.7 / -1.2 | 1.33 | 7.4 | 2.6 | 0.17 | 10.6 | 2.9 | 0.52 | 0.00 | 0.83 | 0.19 | 0.00 | 0.00 | 2.0 | 0.00 | 0.00 | 0.99 | **FAIL** 2/9 |
| centipede | gallop | -3.9 / -0.5 | 1.43 | 8.9 | 2.0 | 0.05 | 9.5 | 2.5 | 0.54 | 0.00 | 0.79 | 0.19 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| centipede | turn | -3.6 / 2.1 | 1.28 | 6.8 | 1.5 | 0.12 | 2.9 | 1.0 | 0.52 | 0.00 | 0.86 | 0.16 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 0.99 | **FAIL** 4/9 |
| centipede | climb | -0.8 / 17.8 | 1.26 | 6.2 | 1.7 | 0.11 | 10.4 | 1.1 | 0.51 | 0.00 | 0.84 | 0.16 | 0.01 | 0.07 | 6.4 | 0.02 | 0.00 | 1.00 | **FAIL** 2/6 |
| centipede | steps | -3.1 / 4.8 | 1.30 | 7.0 | 2.2 | 0.14 | 4.9 | 1.0 | 0.52 | 0.00 | 0.85 | 0.16 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.01 | **FAIL** 3/10 |
| hexapod | walk | -3.5 / -1.1 | 1.25 | 6.7 | 2.5 | 0.13 | 9.9 | 3.6 | 0.51 | 0.00 | 0.84 | 0.31 | 0.00 | 0.00 | 2.2 | 0.00 | 0.00 | 1.00 | **FAIL** 2/9 |
| hexapod | gallop | -3.9 / -0.1 | 1.36 | 8.5 | 1.8 | 0.05 | 10.7 | 2.7 | 0.53 | 0.00 | 0.78 | 0.30 | 0.00 | 0.00 | 2.3 | 0.00 | 0.00 | 1.00 | **FAIL** 2/8 |
| hexapod | turn | -3.1 / -0.2 | 1.21 | 5.8 | 1.6 | 0.11 | 4.4 | 1.8 | 0.51 | 0.00 | 0.88 | 0.28 | 0.02 | 0.00 | 0.3 | 0.00 | 0.00 | 0.99 | **FAIL** 3/9 |
| hexapod | climb | -1.1 / 19.4 | 1.18 | 5.1 | 1.7 | 0.12 | 9.9 | 4.4 | 0.51 | 0.00 | 0.85 | 0.28 | 0.01 | 0.11 | 6.7 | 0.01 | 0.00 | 1.04 | **FAIL** 3/6 |
| hexapod | steps | -3.0 / 4.1 | 1.23 | 6.2 | 2.3 | 0.12 | 6.4 | 1.9 | 0.51 | 0.00 | 0.86 | 0.29 | 0.04 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 3/10 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| head pitched to the sky | head_pitch | 0 / 28 |
| crouched legs | leg_extension | 28 / 28 |
| gallop is a fast walk | air_gallop | 3 / 5 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 24 / 77 |
| centipede legs bunched | foot_spacing | 7 / 8 |
| climbing barely changes posture | climb_posture, climb_follow | 7 / 13 |
| steps course stalls | stall_steps | 3 / 7 |
| legs bend the wrong way | knee_flip | 6 / 35 |
| legs through the ground | foot_penetration | 0 / 35 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 3 / 6 |

## Failing checks

- **mite walk**: air_walk 0.514 vs <=0.005 (airborne_frac); leg_extension 0.791 vs >=0.9 (leg_extension)
- **mite gallop**: leg_extension 0.783 vs >=0.9 (leg_extension)
- **mite turn**: leg_extension 0.793 vs >=0.9 (leg_extension); head_periscope 61.960 vs <30 (head_yaw_vs_body_deg.p95)
- **mite climb**: climb_follow 0.160 vs >=0.6 (pitch_follow)
- **mite steps**: pivot_turns 0.178 vs <0.15 (pivot_frac_of_turns); leg_extension 0.795 vs >=0.9 (leg_extension); head_periscope 46.120 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter walk**: air_walk 0.317 vs <=0.005 (airborne_frac); leg_extension 0.854 vs >=0.9 (leg_extension)
- **trotter gallop**: leg_extension 0.841 vs >=0.9 (leg_extension)
- **trotter turn**: pivot_turns 0.324 vs <0.15 (pivot_frac_of_turns); leg_extension 0.865 vs >=0.9 (leg_extension); head_periscope 32.420 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter climb**: climb_posture 3.240 vs >=5 (climb_posture_shift_deg)
- **trotter steps**: knee_flip 0.037 vs ==0 (knee_flip_frac); pivot 0.052 vs <0.05 (pivot_frac); pivot_turns 0.235 vs <0.15 (pivot_frac_of_turns); stall_steps 0.048 vs ==0 (stall_frac); leg_extension 0.841 vs >=0.9 (leg_extension)
- **hero walk**: leg_extension 0.845 vs >=0.9 (leg_extension); gorilla:shoulder_hip_ratio 1.197 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 8.070 vs 22+-8 (back_slope_deg); gorilla:torso_bob_frac 0.130 vs 0.04+-0.03 (torso_bob_frac)
- **hero gallop**: air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.853 vs >=0.9 (leg_extension)
- **hero turn**: pivot_turns 0.436 vs <0.15 (pivot_frac_of_turns); leg_extension 0.874 vs >=0.9 (leg_extension); head_periscope 37.580 vs <30 (head_yaw_vs_body_deg.p95)
- **hero climb**: climb_posture 2.420 vs >=5 (climb_posture_shift_deg)
- **hero steps**: pivot 0.052 vs <0.05 (pivot_frac); pivot_turns 0.214 vs <0.15 (pivot_frac_of_turns); stall_steps 0.057 vs ==0 (stall_frac); leg_extension 0.856 vs >=0.9 (leg_extension); head_periscope 36.990 vs <30 (head_yaw_vs_body_deg.p95)
- **giant walk**: leg_extension 0.848 vs >=0.9 (leg_extension); head_periscope 39.840 vs <30 (head_yaw_vs_body_deg.p95); gorilla:shoulder_hip_ratio 1.164 vs 1.35+-0.15 (shoulder_hip_ratio); gorilla:back_slope_deg 6.810 vs 22+-8 (back_slope_deg); gorilla:roll_plant_lag 0.172 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.163 vs 0.04+-0.03 (torso_bob_frac)
- **giant gallop**: foot_slip 8.580 vs <3 (foot_slip_cm.p95); air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.875 vs >=0.9 (leg_extension)
- **giant turn**: leg_extension 0.875 vs >=0.9 (leg_extension); head_periscope 37.180 vs <30 (head_yaw_vs_body_deg.p95)
- **giant climb**: climb_posture 0.270 vs >=5 (climb_posture_shift_deg)
- **giant steps**: foot_slip 5.020 vs <3 (foot_slip_cm.p95); leg_extension 0.860 vs >=0.9 (leg_extension)
- **longneck walk**: leg_extension 0.865 vs >=0.9 (leg_extension); head_periscope 71.870 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck gallop**: foot_slip 4.350 vs <3 (foot_slip_cm.p95); air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.840 vs >=0.9 (leg_extension); head_periscope 74.260 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck turn**: pivot_turns 0.433 vs <0.15 (pivot_frac_of_turns); leg_extension 0.885 vs >=0.9 (leg_extension); head_periscope 151.640 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck climb**: knee_flip 0.001 vs ==0 (knee_flip_frac); foot_slip 3.540 vs <3 (foot_slip_cm.p95); climb_posture 2.880 vs >=5 (climb_posture_shift_deg)
- **longneck steps**: knee_flip 0.007 vs ==0 (knee_flip_frac); pivot 0.057 vs <0.05 (pivot_frac); pivot_turns 0.289 vs <0.15 (pivot_frac_of_turns); stall_steps 0.013 vs ==0 (stall_frac); leg_extension 0.868 vs >=0.9 (leg_extension)
- **centipede walk**: leg_extension 0.826 vs >=0.9 (leg_extension); foot_spacing 0.186 vs >=0.3 (foot_spacing_ratio)
- **centipede gallop**: leg_extension 0.787 vs >=0.9 (leg_extension); foot_spacing 0.191 vs >=0.3 (foot_spacing_ratio)
- **centipede turn**: knee_flip 0.003 vs ==0 (knee_flip_frac); pivot_turns 0.440 vs <0.15 (pivot_frac_of_turns); leg_extension 0.860 vs >=0.9 (leg_extension); foot_spacing 0.164 vs >=0.3 (foot_spacing_ratio)
- **centipede climb**: knee_flip 0.015 vs ==0 (knee_flip_frac); climb_posture 1.210 vs >=5 (climb_posture_shift_deg)
- **centipede steps**: pivot_turns 0.258 vs <0.15 (pivot_frac_of_turns); leg_extension 0.850 vs >=0.9 (leg_extension); foot_spacing 0.165 vs >=0.3 (foot_spacing_ratio)
- **hexapod walk**: foot_slip 3.580 vs <3 (foot_slip_cm.p95); leg_extension 0.839 vs >=0.9 (leg_extension)
- **hexapod gallop**: leg_extension 0.784 vs >=0.9 (leg_extension); foot_spacing 0.296 vs >=0.3 (foot_spacing_ratio)
- **hexapod turn**: pivot_turns 0.400 vs <0.15 (pivot_frac_of_turns); leg_extension 0.875 vs >=0.9 (leg_extension); foot_spacing 0.283 vs >=0.3 (foot_spacing_ratio)
- **hexapod climb**: knee_flip 0.011 vs ==0 (knee_flip_frac); foot_slip 4.360 vs <3 (foot_slip_cm.p95); climb_posture 1.670 vs >=5 (climb_posture_shift_deg)
- **hexapod steps**: pivot_turns 0.270 vs <0.15 (pivot_frac_of_turns); leg_extension 0.857 vs >=0.9 (leg_extension); foot_spacing 0.287 vs >=0.3 (foot_spacing_ratio)
