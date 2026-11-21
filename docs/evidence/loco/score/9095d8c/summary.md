# Locomotion scorecard `9095d8c`

Rows: body x scenario. PASS/FAIL against `docs/research/loco-reference.json`; `-` = not measurable (reason in the case JSON). Verdict = failed/checked.

| body | scenario | head pitch mean/p95 | shoulder/hip | back slope | roll deg | roll lag | bob % | slip p95 cm | duty | airborne | leg ext | foot spacing | pivot | stall | turn R m | knee flip | pen p95 cm | symmetry | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| mite | walk | 9.0 / 18.2 | - | - | 2.5 | 0.35 | - | - | 0.24 | 0.51 | 0.78 | - | 0.00 | 0.00 | 2.8 | 0.00 | 0.00 | 0.90 | **FAIL** 2/7 |
| mite | gallop | 6.2 / 19.7 | - | - | 2.8 | -0.47 | - | - | 0.21 | 0.58 | 0.78 | - | 0.00 | 0.00 | 2.9 | 0.00 | 0.00 | 1.06 | **FAIL** 1/7 |
| mite | turn | 12.4 / 26.3 | - | - | 1.1 | 0.37 | - | 0.1 | 0.25 | 0.49 | 0.80 | - | 0.00 | 0.00 | 0.2 | 0.00 | 0.00 | 1.02 | **FAIL** 3/8 |
| mite | climb | 14.1 / 34.7 | - | - | 0.5 | 0.10 | - | 0.0 | 0.25 | 0.50 | 0.77 | - | 0.00 | 0.21 | 7.9 | 0.00 | 0.00 | 0.97 | **FAIL** 1/5 |
| mite | steps | 12.6 / 33.4 | - | - | 1.5 | 0.39 | - | 3.8 | 0.26 | 0.49 | 0.80 | - | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 5/9 |
| trotter | walk | 19.0 / 26.2 | 1.29 | 10.5 | 2.5 | 0.34 | 15.1 | 7.6 | 0.26 | 0.32 | 0.77 | 0.97 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 7.97 | **FAIL** 4/8 |
| trotter | gallop | 21.8 / 33.7 | 1.36 | 12.7 | 4.6 | 0.44 | 13.4 | 4.9 | 0.19 | 0.40 | 0.78 | 0.98 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 8.18 | **FAIL** 3/8 |
| trotter | turn | 17.7 / 31.4 | 1.21 | 8.0 | 2.5 | 0.32 | 18.6 | 7.4 | 0.27 | 0.30 | 0.78 | 0.93 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 5.83 | **FAIL** 5/8 |
| trotter | climb | 24.4 / 61.5 | 1.17 | 6.4 | 1.3 | 0.24 | 23.4 | 0.0 | 0.26 | 0.30 | 0.78 | 0.94 | 0.00 | 0.21 | 7.3 | 0.00 | 0.00 | 6.32 | **FAIL** 1/6 |
| trotter | steps | 19.1 / 36.1 | 1.25 | 9.2 | 4.9 | 0.45 | 21.7 | 7.6 | 0.28 | 0.27 | 0.77 | 0.90 | 0.05 | 0.05 | 0.3 | 0.01 | 0.00 | 4.56 | **FAIL** 7/9 |
| hero | walk | 16.6 / 21.8 | 1.24 | 9.1 | 3.0 | 0.49 | 21.9 | 17.4 | 0.41 | 0.00 | 0.83 | 0.77 | 0.00 | 0.00 | 3.6 | 0.00 | 0.00 | 1.00 | **FAIL** 9/15 |
| hero | gallop | 18.8 / 27.2 | 1.29 | 10.7 | 2.3 | -0.39 | 15.1 | 14.7 | 0.52 | 0.00 | 0.81 | 0.53 | 0.00 | 0.00 | 3.8 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| hero | turn | 16.6 / 26.4 | 1.18 | 7.5 | 2.6 | 0.01 | 5.4 | 15.1 | 0.42 | 0.00 | 0.88 | 0.72 | 0.04 | 0.00 | 0.4 | 0.00 | 0.00 | 0.97 | **FAIL** 4/8 |
| hero | climb | 22.9 / 51.3 | 1.15 | 6.2 | 2.4 | -0.03 | 22.1 | 11.4 | 0.41 | 0.00 | 0.86 | 0.72 | 0.00 | 0.13 | 10.7 | 0.00 | 0.00 | 0.93 | **FAIL** 2/6 |
| hero | steps | 17.5 / 36.0 | 1.21 | 8.6 | 5.7 | 0.43 | 16.7 | 16.7 | 0.43 | 0.00 | 0.86 | 0.74 | 0.05 | 0.06 | 0.4 | 0.00 | 0.00 | 0.98 | **FAIL** 6/9 |
| giant | walk | 15.0 / 20.8 | 1.21 | 8.1 | 3.0 | -0.42 | 28.9 | 24.0 | 0.46 | 0.00 | 0.83 | 0.82 | 0.00 | 0.00 | 3.2 | 0.00 | 0.00 | 1.01 | **FAIL** 10/15 |
| giant | gallop | 15.6 / 25.2 | 1.20 | 7.8 | 2.8 | -0.39 | 14.4 | 23.2 | 0.51 | 0.00 | 0.83 | 0.54 | 0.00 | 0.00 | 3.4 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| giant | turn | 16.4 / 24.2 | 1.17 | 7.1 | 3.2 | 0.02 | 6.7 | 9.9 | 0.47 | 0.00 | 0.88 | 0.76 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| giant | climb | 24.7 / 52.5 | 1.22 | 8.2 | 4.0 | -0.03 | 26.9 | 20.2 | 0.47 | 0.00 | 0.86 | 0.76 | 0.00 | 0.02 | 11.9 | 0.00 | 0.00 | 1.02 | **FAIL** 2/6 |
| giant | steps | 16.6 / 26.9 | 1.17 | 7.2 | 4.3 | -0.46 | 13.3 | 20.2 | 0.47 | 0.00 | 0.87 | 0.77 | 0.00 | 0.00 | 0.6 | 0.00 | 0.00 | 1.01 | **FAIL** 3/9 |
| longneck | walk | 35.7 / 44.4 | 1.69 | 21.8 | 2.6 | 0.45 | 5.3 | 10.5 | 0.52 | 0.00 | 0.85 | 0.69 | 0.00 | 0.00 | 2.8 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| longneck | gallop | 37.6 / 50.5 | 1.75 | 23.0 | 1.9 | 0.37 | 5.0 | 10.3 | 0.53 | 0.00 | 0.84 | 0.67 | 0.00 | 0.00 | 3.0 | 0.00 | 0.00 | 1.00 | **FAIL** 5/8 |
| longneck | turn | 31.6 / 47.4 | 1.59 | 19.9 | 1.5 | 0.14 | 3.0 | 1.9 | 0.51 | 0.00 | 0.87 | 0.65 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 0.98 | **FAIL** 4/8 |
| longneck | climb | 33.8 / 58.1 | 1.55 | 18.7 | 2.5 | 0.12 | 9.3 | 9.8 | 0.51 | 0.00 | 0.85 | 0.63 | 0.00 | 0.12 | 7.1 | 0.00 | 0.00 | 1.00 | **FAIL** 3/6 |
| longneck | steps | 36.0 / 56.9 | 1.64 | 20.6 | 3.3 | 0.34 | 5.9 | 9.7 | 0.51 | 0.00 | 0.86 | 0.66 | 0.06 | 0.01 | 0.3 | 0.01 | 0.00 | 1.04 | **FAIL** 7/9 |
| centipede | walk | 18.3 / 22.6 | 1.32 | 7.4 | 1.9 | 0.48 | 7.9 | 7.9 | 0.52 | 0.00 | 0.83 | 0.18 | 0.00 | 0.00 | 2.0 | 0.00 | 0.00 | 0.99 | **FAIL** 4/9 |
| centipede | gallop | 19.8 / 30.1 | 1.43 | 8.9 | 1.3 | -0.40 | 6.9 | 5.5 | 0.54 | 0.00 | 0.80 | 0.19 | 0.00 | 0.00 | 1.9 | 0.00 | 0.00 | 1.00 | **FAIL** 4/8 |
| centipede | turn | 17.4 / 29.0 | 1.28 | 6.8 | 0.8 | -0.25 | 3.0 | 1.1 | 0.52 | 0.00 | 0.86 | 0.16 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 0.98 | **FAIL** 4/9 |
| centipede | climb | 23.1 / 49.9 | 1.26 | 6.2 | 0.6 | -0.36 | 10.9 | 5.8 | 0.51 | 0.00 | 0.84 | 0.16 | 0.01 | 0.07 | 6.4 | 0.01 | 0.00 | 0.97 | **FAIL** 3/6 |
| centipede | steps | 18.2 / 32.9 | 1.30 | 7.0 | 1.8 | -0.29 | 4.3 | 4.8 | 0.52 | 0.00 | 0.85 | 0.16 | 0.03 | 0.00 | 0.3 | 0.00 | 0.00 | 1.01 | **FAIL** 5/10 |
| hexapod | walk | 18.5 / 22.9 | 1.25 | 6.7 | 1.4 | 0.44 | 7.6 | 6.9 | 0.51 | 0.00 | 0.84 | 0.32 | 0.00 | 0.00 | 2.2 | 0.00 | 0.00 | 1.00 | **FAIL** 3/9 |
| hexapod | gallop | 19.9 / 30.7 | 1.35 | 8.5 | 1.1 | 0.36 | 7.5 | 6.0 | 0.53 | 0.00 | 0.80 | 0.31 | 0.00 | 0.00 | 2.3 | 0.00 | 0.00 | 1.01 | **FAIL** 4/8 |
| hexapod | turn | 17.7 / 27.1 | 1.21 | 5.8 | 0.8 | 0.31 | 4.7 | 1.9 | 0.51 | 0.00 | 0.87 | 0.28 | 0.02 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 4/9 |
| hexapod | climb | 23.3 / 51.6 | 1.18 | 5.0 | 0.6 | 0.28 | 8.5 | 6.2 | 0.51 | 0.00 | 0.85 | 0.28 | 0.01 | 0.11 | 6.7 | 0.01 | 0.00 | 0.98 | **FAIL** 3/6 |
| hexapod | steps | 18.7 / 34.3 | 1.23 | 6.2 | 1.6 | 0.39 | 6.2 | 6.7 | 0.51 | 0.00 | 0.86 | 0.29 | 0.04 | 0.00 | 0.3 | 0.00 | 0.00 | 1.00 | **FAIL** 5/10 |

## Known problems and the checks that catch them

| known problem | checks | failing rows / checked rows |
|---|---|---|
| head pitched to the sky | head_pitch | 26 / 28 |
| crouched legs | leg_extension | 28 / 28 |
| gallop is a fast walk | air_gallop | 3 / 5 |
| pivot turns, periscope neck | pivot, pivot_turns, head_periscope | 22 / 77 |
| centipede legs bunched | foot_spacing | 6 / 8 |
| climbing barely changes posture | climb_posture, climb_follow | 7 / 13 |
| steps course stalls | stall_steps | 3 / 7 |
| legs bend the wrong way | knee_flip | 6 / 35 |
| legs through the ground | foot_penetration | 0 / 35 |
| rigid torso (no roll, no bob) | gorilla:torso_roll_deg, gorilla:roll_plant_lag, gorilla:torso_bob_frac | 6 / 6 |

## Failing checks

- **mite walk**: air_walk 0.514 vs <=0.005 (airborne_frac); leg_extension 0.780 vs >=0.9 (leg_extension)
- **mite gallop**: leg_extension 0.784 vs >=0.9 (leg_extension)
- **mite turn**: head_pitch 12.410 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.795 vs >=0.9 (leg_extension); head_periscope 51.020 vs <30 (head_yaw_vs_body_deg.p95)
- **mite climb**: climb_follow 0.160 vs >=0.6 (pitch_follow)
- **mite steps**: foot_slip 3.800 vs <3 (foot_slip_cm.p95); head_pitch 12.600 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.178 vs <0.15 (pivot_frac_of_turns); leg_extension 0.796 vs >=0.9 (leg_extension); head_periscope 40.230 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter walk**: foot_slip 7.600 vs <3 (foot_slip_cm.p95); head_pitch 18.990 vs 0+-12 (head_pitch_deg.mean); air_walk 0.318 vs <=0.005 (airborne_frac); leg_extension 0.772 vs >=0.9 (leg_extension)
- **trotter gallop**: foot_slip 4.880 vs <3 (foot_slip_cm.p95); head_pitch 21.840 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.782 vs >=0.9 (leg_extension)
- **trotter turn**: foot_slip 7.440 vs <3 (foot_slip_cm.p95); head_pitch 17.670 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.324 vs <0.15 (pivot_frac_of_turns); leg_extension 0.783 vs >=0.9 (leg_extension); head_periscope 31.100 vs <30 (head_yaw_vs_body_deg.p95)
- **trotter climb**: climb_posture 4.040 vs >=5 (climb_posture_shift_deg)
- **trotter steps**: knee_flip 0.012 vs ==0 (knee_flip_frac); foot_slip 7.600 vs <3 (foot_slip_cm.p95); head_pitch 19.120 vs 0+-12 (head_pitch_deg.mean); pivot 0.052 vs <0.05 (pivot_frac); pivot_turns 0.235 vs <0.15 (pivot_frac_of_turns); stall_steps 0.048 vs ==0 (stall_frac); leg_extension 0.770 vs >=0.9 (leg_extension)
- **hero walk**: foot_slip 17.420 vs <3 (foot_slip_cm.p95); head_pitch 16.640 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.834 vs >=0.9 (leg_extension); gorilla:head_pitch_deg 16.640 vs 0+-10 (head_pitch_deg.mean); gorilla:back_slope_deg 9.100 vs 22+-8 (back_slope_deg); gorilla:torso_roll_deg 3.040 vs 7+-3 (torso_roll_deg); gorilla:roll_plant_lag 0.492 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.220 vs 0.04+-0.03 (torso_bob_frac); gorilla:foot_slip_cm 17.420 vs 0+-3 (foot_slip_cm.p95)
- **hero gallop**: foot_slip 14.740 vs <3 (foot_slip_cm.p95); head_pitch 18.820 vs 0+-12 (head_pitch_deg.mean); air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.805 vs >=0.9 (leg_extension)
- **hero turn**: foot_slip 15.120 vs <3 (foot_slip_cm.p95); head_pitch 16.600 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.436 vs <0.15 (pivot_frac_of_turns); leg_extension 0.879 vs >=0.9 (leg_extension)
- **hero climb**: foot_slip 11.360 vs <3 (foot_slip_cm.p95); climb_posture 2.920 vs >=5 (climb_posture_shift_deg)
- **hero steps**: foot_slip 16.690 vs <3 (foot_slip_cm.p95); head_pitch 17.470 vs 0+-12 (head_pitch_deg.mean); pivot 0.052 vs <0.05 (pivot_frac); pivot_turns 0.214 vs <0.15 (pivot_frac_of_turns); stall_steps 0.057 vs ==0 (stall_frac); leg_extension 0.858 vs >=0.9 (leg_extension)
- **giant walk**: foot_slip 23.960 vs <3 (foot_slip_cm.p95); head_pitch 14.960 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.835 vs >=0.9 (leg_extension); head_periscope 30.690 vs <30 (head_yaw_vs_body_deg.p95); gorilla:head_pitch_deg 14.960 vs 0+-10 (head_pitch_deg.mean); gorilla:back_slope_deg 8.120 vs 22+-8 (back_slope_deg); gorilla:torso_roll_deg 3.050 vs 7+-3 (torso_roll_deg); gorilla:roll_plant_lag -0.424 vs 0+-0.15 (roll_plant_lag); gorilla:torso_bob_frac 0.289 vs 0.04+-0.03 (torso_bob_frac); gorilla:foot_slip_cm 23.960 vs 0+-3 (foot_slip_cm.p95)
- **giant gallop**: foot_slip 23.240 vs <3 (foot_slip_cm.p95); head_pitch 15.640 vs 0+-12 (head_pitch_deg.mean); air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.827 vs >=0.9 (leg_extension)
- **giant turn**: foot_slip 9.940 vs <3 (foot_slip_cm.p95); head_pitch 16.410 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.880 vs >=0.9 (leg_extension); head_periscope 32.340 vs <30 (head_yaw_vs_body_deg.p95)
- **giant climb**: foot_slip 20.250 vs <3 (foot_slip_cm.p95); climb_posture 0.130 vs >=5 (climb_posture_shift_deg)
- **giant steps**: foot_slip 20.210 vs <3 (foot_slip_cm.p95); head_pitch 16.600 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.869 vs >=0.9 (leg_extension)
- **longneck walk**: foot_slip 10.480 vs <3 (foot_slip_cm.p95); head_pitch 35.670 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.847 vs >=0.9 (leg_extension); head_periscope 43.430 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck gallop**: foot_slip 10.350 vs <3 (foot_slip_cm.p95); head_pitch 37.630 vs 0+-12 (head_pitch_deg.mean); air_gallop 0.000 vs >0.05 (airborne_frac); leg_extension 0.839 vs >=0.9 (leg_extension); head_periscope 42.720 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck turn**: head_pitch 31.590 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.433 vs <0.15 (pivot_frac_of_turns); leg_extension 0.872 vs >=0.9 (leg_extension); head_periscope 106.560 vs <30 (head_yaw_vs_body_deg.p95)
- **longneck climb**: knee_flip 0.003 vs ==0 (knee_flip_frac); foot_slip 9.820 vs <3 (foot_slip_cm.p95); climb_posture 3.180 vs >=5 (climb_posture_shift_deg)
- **longneck steps**: knee_flip 0.006 vs ==0 (knee_flip_frac); foot_slip 9.740 vs <3 (foot_slip_cm.p95); head_pitch 35.990 vs 0+-12 (head_pitch_deg.mean); pivot 0.057 vs <0.05 (pivot_frac); pivot_turns 0.289 vs <0.15 (pivot_frac_of_turns); stall_steps 0.013 vs ==0 (stall_frac); leg_extension 0.857 vs >=0.9 (leg_extension)
- **centipede walk**: foot_slip 7.860 vs <3 (foot_slip_cm.p95); head_pitch 18.260 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.834 vs >=0.9 (leg_extension); foot_spacing 0.184 vs >=0.3 (foot_spacing_ratio)
- **centipede gallop**: foot_slip 5.470 vs <3 (foot_slip_cm.p95); head_pitch 19.800 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.797 vs >=0.9 (leg_extension); foot_spacing 0.187 vs >=0.3 (foot_spacing_ratio)
- **centipede turn**: head_pitch 17.420 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.440 vs <0.15 (pivot_frac_of_turns); leg_extension 0.860 vs >=0.9 (leg_extension); foot_spacing 0.164 vs >=0.3 (foot_spacing_ratio)
- **centipede climb**: knee_flip 0.011 vs ==0 (knee_flip_frac); foot_slip 5.780 vs <3 (foot_slip_cm.p95); climb_posture 1.220 vs >=5 (climb_posture_shift_deg)
- **centipede steps**: foot_slip 4.850 vs <3 (foot_slip_cm.p95); head_pitch 18.210 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.258 vs <0.15 (pivot_frac_of_turns); leg_extension 0.850 vs >=0.9 (leg_extension); foot_spacing 0.164 vs >=0.3 (foot_spacing_ratio)
- **hexapod walk**: foot_slip 6.870 vs <3 (foot_slip_cm.p95); head_pitch 18.460 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.842 vs >=0.9 (leg_extension)
- **hexapod gallop**: knee_flip 0.001 vs ==0 (knee_flip_frac); foot_slip 6.040 vs <3 (foot_slip_cm.p95); head_pitch 19.910 vs 0+-12 (head_pitch_deg.mean); leg_extension 0.802 vs >=0.9 (leg_extension)
- **hexapod turn**: head_pitch 17.660 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.400 vs <0.15 (pivot_frac_of_turns); leg_extension 0.875 vs >=0.9 (leg_extension); foot_spacing 0.283 vs >=0.3 (foot_spacing_ratio)
- **hexapod climb**: knee_flip 0.008 vs ==0 (knee_flip_frac); foot_slip 6.200 vs <3 (foot_slip_cm.p95); climb_posture 1.790 vs >=5 (climb_posture_shift_deg)
- **hexapod steps**: foot_slip 6.650 vs <3 (foot_slip_cm.p95); head_pitch 18.670 vs 0+-12 (head_pitch_deg.mean); pivot_turns 0.270 vs <0.15 (pivot_frac_of_turns); leg_extension 0.856 vs >=0.9 (leg_extension); foot_spacing 0.288 vs >=0.3 (foot_spacing_ratio)
