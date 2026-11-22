# Compare startB-a42 -> startB-longer

improved 31, regressed 19, unchanged 37 (cases in both: 5)

## Improved

| case | metric | startB-a42 | startB-longer |
|---|---|---|---|
| startB_climb | head_pitch_deg.mean | 0.810 | 0.710 |
| startB_climb | head_yaw_vs_body_deg.p95 | 62.270 | 51.000 |
| startB_climb | shoulder_hip_ratio | 1.101 | 1.131 |
| startB_climb | torso_roll_deg | 4.350 | 4.590 |
| startB_climb | roll_plant_lag | 0.169 | 0.143 |
| startB_climb | torso_bob_frac | 0.027 | 0.044 |
| startB_climb | gait_symmetry | 0.990 | 1.003 |
| startB_gallop | limp_index | 2.029 | 1.526 |
| startB_gallop | head_pitch_deg.mean | -1.700 | -1.120 |
| startB_gallop | shoulder_hip_ratio | 1.007 | 1.016 |
| startB_gallop | back_slope_deg | 0.440 | 0.920 |
| startB_gallop | torso_roll_deg | 3.820 | 3.860 |
| startB_gallop | foot_spacing_ratio | 0.657 | 0.670 |
| startB_steps | head_pitch_deg.mean | 0.720 | 0.710 |
| startB_steps | head_yaw_vs_body_deg.p95 | 73.540 | 68.180 |
| startB_steps | shoulder_hip_ratio | 1.101 | 1.130 |
| startB_steps | torso_roll_deg | 4.360 | 4.450 |
| startB_steps | roll_plant_lag | 0.168 | 0.138 |
| startB_steps | torso_bob_frac | 0.028 | 0.044 |
| startB_steps | gait_symmetry | 1.007 | 1.006 |
| startB_turn | head_pitch_deg.mean | 0.340 | 0.110 |
| startB_turn | shoulder_hip_ratio | 1.101 | 1.131 |
| startB_turn | torso_roll_deg | 4.360 | 4.610 |
| startB_turn | roll_plant_lag | 0.168 | 0.143 |
| startB_turn | torso_bob_frac | 0.027 | 0.045 |
| startB_walk | limp_index | 1.417 | 1.266 |
| startB_walk | head_pitch_deg.mean | 0.720 | 0.650 |
| startB_walk | shoulder_hip_ratio | 1.101 | 1.130 |
| startB_walk | torso_roll_deg | 4.530 | 4.610 |
| startB_walk | roll_plant_lag | 0.176 | 0.147 |
| startB_walk | torso_bob_frac | 0.033 | 0.047 |

## Regressed

| case | metric | startB-a42 | startB-longer |
|---|---|---|---|
| startB_climb | limp_index | 1.158 | 1.207 |
| startB_climb | leg_extension | 0.658 | 0.551 |
| startB_climb | foot_spacing_ratio | 0.492 | 0.440 |
| startB_gallop | head_yaw_vs_body_deg.p95 | 48.510 | 56.650 |
| startB_gallop | roll_plant_lag | 0.183 | 0.246 |
| startB_gallop | torso_bob_frac | 0.120 | 0.138 |
| startB_gallop | leg_extension | 0.773 | 0.671 |
| startB_gallop | gait_symmetry | 0.317 | 0.313 |
| startB_steps | limp_index | 1.139 | 1.153 |
| startB_steps | leg_extension | 0.658 | 0.551 |
| startB_steps | foot_spacing_ratio | 0.489 | 0.434 |
| startB_turn | limp_index | 1.163 | 1.169 |
| startB_turn | head_yaw_vs_body_deg.p95 | 85.820 | 88.730 |
| startB_turn | leg_extension | 0.658 | 0.551 |
| startB_turn | foot_spacing_ratio | 0.495 | 0.444 |
| startB_walk | head_yaw_vs_body_deg.p95 | 51.880 | 59.620 |
| startB_walk | leg_extension | 0.657 | 0.549 |
| startB_walk | foot_spacing_ratio | 0.499 | 0.456 |
| startB_walk | gait_symmetry | 0.996 | 1.025 |

