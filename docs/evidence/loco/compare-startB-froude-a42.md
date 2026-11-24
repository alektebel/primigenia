# Compare startB-froude -> startB-a42

improved 18, regressed 33, unchanged 36 (cases in both: 5)

## Improved

| case | metric | startB-froude | startB-a42 |
|---|---|---|---|
| startB_climb | head_pitch_deg.mean | 0.860 | 0.810 |
| startB_climb | shoulder_hip_ratio | 1.077 | 1.101 |
| startB_climb | foot_spacing_ratio | 0.458 | 0.492 |
| startB_gallop | head_yaw_vs_body_deg.p95 | 54.730 | 48.510 |
| startB_gallop | leg_extension | 0.770 | 0.773 |
| startB_gallop | foot_spacing_ratio | 0.323 | 0.657 |
| startB_steps | head_pitch_deg.mean | 0.890 | 0.720 |
| startB_steps | shoulder_hip_ratio | 1.077 | 1.101 |
| startB_steps | foot_spacing_ratio | 0.457 | 0.489 |
| startB_turn | shoulder_hip_ratio | 1.077 | 1.101 |
| startB_turn | foot_spacing_ratio | 0.457 | 0.495 |
| startB_turn | gait_symmetry | 0.996 | 0.999 |
| startB_walk | head_pitch_deg.mean | 0.940 | 0.720 |
| startB_walk | head_yaw_vs_body_deg.p95 | 53.860 | 51.880 |
| startB_walk | shoulder_hip_ratio | 1.076 | 1.101 |
| startB_walk | torso_bob_frac | 0.059 | 0.033 |
| startB_walk | foot_spacing_ratio | 0.462 | 0.499 |
| startB_walk | gait_symmetry | 1.014 | 0.996 |

## Regressed

| case | metric | startB-froude | startB-a42 |
|---|---|---|---|
| startB_climb | limp_index | 1.091 | 1.158 |
| startB_climb | head_yaw_vs_body_deg.p95 | 55.620 | 62.270 |
| startB_climb | torso_roll_deg | 5.660 | 4.350 |
| startB_climb | roll_plant_lag | 0.131 | 0.169 |
| startB_climb | torso_bob_frac | 0.052 | 0.027 |
| startB_climb | leg_extension | 0.847 | 0.658 |
| startB_climb | gait_symmetry | 0.997 | 0.990 |
| startB_gallop | limp_index | 1.959 | 2.029 |
| startB_gallop | head_pitch_deg.mean | -0.810 | -1.700 |
| startB_gallop | shoulder_hip_ratio | 1.033 | 1.007 |
| startB_gallop | back_slope_deg | 2.080 | 0.440 |
| startB_gallop | torso_roll_deg | 6.370 | 3.820 |
| startB_gallop | roll_plant_lag | 0.121 | 0.183 |
| startB_gallop | torso_bob_frac | 0.116 | 0.120 |
| startB_gallop | gait_symmetry | 0.807 | 0.317 |
| startB_steps | limp_index | 1.025 | 1.139 |
| startB_steps | head_yaw_vs_body_deg.p95 | 67.450 | 73.540 |
| startB_steps | torso_roll_deg | 5.640 | 4.360 |
| startB_steps | roll_plant_lag | 0.132 | 0.168 |
| startB_steps | torso_bob_frac | 0.051 | 0.028 |
| startB_steps | leg_extension | 0.847 | 0.658 |
| startB_steps | gait_symmetry | 1.004 | 1.007 |
| startB_turn | limp_index | 1.060 | 1.163 |
| startB_turn | head_pitch_deg.mean | 0.270 | 0.340 |
| startB_turn | head_yaw_vs_body_deg.p95 | 79.260 | 85.820 |
| startB_turn | torso_roll_deg | 5.660 | 4.360 |
| startB_turn | roll_plant_lag | 0.133 | 0.168 |
| startB_turn | torso_bob_frac | 0.052 | 0.027 |
| startB_turn | leg_extension | 0.847 | 0.658 |
| startB_walk | limp_index | 1.089 | 1.417 |
| startB_walk | torso_roll_deg | 5.590 | 4.530 |
| startB_walk | roll_plant_lag | 0.133 | 0.176 |
| startB_walk | leg_extension | 0.848 | 0.657 |

