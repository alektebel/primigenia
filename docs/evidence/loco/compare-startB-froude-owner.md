# Compare startB-froude -> startB-owner

improved 12, regressed 38, unchanged 37 (cases in both: 5)

## Improved

| case | metric | startB-froude | startB-owner |
|---|---|---|---|
| startB_climb | shoulder_hip_ratio | 1.077 | 1.104 |
| startB_climb | torso_bob_frac | 0.052 | 0.037 |
| startB_gallop | limp_index | 1.959 | 1.631 |
| startB_gallop | head_yaw_vs_body_deg.p95 | 54.730 | 53.790 |
| startB_gallop | foot_spacing_ratio | 0.323 | 0.645 |
| startB_steps | shoulder_hip_ratio | 1.077 | 1.103 |
| startB_steps | torso_bob_frac | 0.051 | 0.037 |
| startB_turn | head_pitch_deg.mean | 0.270 | 0.210 |
| startB_turn | shoulder_hip_ratio | 1.077 | 1.104 |
| startB_turn | torso_bob_frac | 0.052 | 0.037 |
| startB_walk | shoulder_hip_ratio | 1.076 | 1.103 |
| startB_walk | torso_bob_frac | 0.059 | 0.054 |

## Regressed

| case | metric | startB-froude | startB-owner |
|---|---|---|---|
| startB_climb | limp_index | 1.091 | 1.137 |
| startB_climb | head_pitch_deg.mean | 0.860 | 1.120 |
| startB_climb | head_yaw_vs_body_deg.p95 | 55.620 | 63.020 |
| startB_climb | torso_roll_deg | 5.660 | 4.440 |
| startB_climb | roll_plant_lag | 0.131 | 0.137 |
| startB_climb | leg_extension | 0.847 | 0.665 |
| startB_climb | foot_spacing_ratio | 0.458 | 0.445 |
| startB_climb | gait_symmetry | 0.997 | 0.978 |
| startB_gallop | head_pitch_deg.mean | -0.810 | -1.200 |
| startB_gallop | shoulder_hip_ratio | 1.033 | 1.017 |
| startB_gallop | back_slope_deg | 2.080 | 1.090 |
| startB_gallop | torso_roll_deg | 6.370 | 3.960 |
| startB_gallop | roll_plant_lag | 0.121 | 0.253 |
| startB_gallop | torso_bob_frac | 0.116 | 0.129 |
| startB_gallop | leg_extension | 0.770 | 0.745 |
| startB_gallop | gait_symmetry | 0.807 | 0.297 |
| startB_steps | limp_index | 1.025 | 1.164 |
| startB_steps | head_pitch_deg.mean | 0.890 | 1.210 |
| startB_steps | head_yaw_vs_body_deg.p95 | 67.450 | 72.130 |
| startB_steps | torso_roll_deg | 5.640 | 4.590 |
| startB_steps | roll_plant_lag | 0.132 | 0.143 |
| startB_steps | leg_extension | 0.847 | 0.664 |
| startB_steps | foot_spacing_ratio | 0.457 | 0.436 |
| startB_turn | limp_index | 1.060 | 1.155 |
| startB_turn | head_yaw_vs_body_deg.p95 | 79.260 | 85.940 |
| startB_turn | torso_roll_deg | 5.660 | 4.600 |
| startB_turn | roll_plant_lag | 0.133 | 0.143 |
| startB_turn | leg_extension | 0.847 | 0.664 |
| startB_turn | foot_spacing_ratio | 0.457 | 0.444 |
| startB_turn | gait_symmetry | 0.996 | 1.008 |
| startB_walk | limp_index | 1.089 | 1.444 |
| startB_walk | head_pitch_deg.mean | 0.940 | 1.220 |
| startB_walk | head_yaw_vs_body_deg.p95 | 53.860 | 62.760 |
| startB_walk | torso_roll_deg | 5.590 | 4.520 |
| startB_walk | roll_plant_lag | 0.133 | 0.134 |
| startB_walk | leg_extension | 0.848 | 0.666 |
| startB_walk | foot_spacing_ratio | 0.462 | 0.427 |
| startB_walk | gait_symmetry | 1.014 | 0.980 |

