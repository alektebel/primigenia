# Compare limp-before -> limp

improved 28, regressed 18, unchanged 26 (cases in both: 4)

## Improved

| case | metric | limp-before | limp |
|---|---|---|---|
| giant_walk | limp_index | 1.083 | 1.070 |
| giant_walk | head_pitch_deg.mean | -2.900 | -2.840 |
| giant_walk | roll_plant_lag | 0.172 | 0.138 |
| giant_walk | torso_bob_frac | 0.163 | 0.150 |
| giant_walk | foot_slip_cm.p95 | 2.810 | 1.140 |
| giant_walk | foot_slip_cm.mean | 0.480 | 0.160 |
| giant_walk | foot_spacing_ratio | 0.880 | 0.929 |
| hero_walk | limp_index | 1.107 | 1.066 |
| hero_walk | head_yaw_vs_body_deg.p95 | 26.070 | 20.960 |
| hero_walk | torso_bob_frac | 0.130 | 0.107 |
| hero_walk | foot_slip_cm.p95 | 1.230 | 0.000 |
| hero_walk | foot_slip_cm.mean | 0.270 | 0.010 |
| hero_walk | leg_extension | 0.845 | 0.847 |
| hero_walk | foot_spacing_ratio | 0.853 | 0.912 |
| longneck_walk | head_pitch_deg.mean | -6.800 | -6.470 |
| longneck_walk | shoulder_hip_ratio | 1.639 | 1.636 |
| longneck_walk | torso_roll_deg | 4.900 | 5.290 |
| longneck_walk | roll_plant_lag | 0.152 | 0.142 |
| longneck_walk | torso_bob_frac | 0.064 | 0.054 |
| longneck_walk | leg_extension | 0.865 | 0.866 |
| longneck_walk | foot_spacing_ratio | 0.737 | 0.753 |
| trotter_walk | limp_index | 1.732 | 1.497 |
| trotter_walk | head_yaw_vs_body_deg.p95 | 22.690 | 22.350 |
| trotter_walk | roll_plant_lag | 0.048 | 0.042 |
| trotter_walk | torso_bob_frac | 0.044 | 0.041 |
| trotter_walk | foot_slip_cm.mean | 0.050 | 0.040 |
| trotter_walk | foot_spacing_ratio | 0.991 | 1.003 |
| trotter_walk | gait_symmetry | 4.468 | 2.989 |

## Regressed

| case | metric | limp-before | limp |
|---|---|---|---|
| giant_walk | head_yaw_vs_body_deg.p95 | 39.840 | 40.240 |
| giant_walk | shoulder_hip_ratio | 1.164 | 1.155 |
| giant_walk | back_slope_deg | 6.810 | 6.480 |
| giant_walk | torso_roll_deg | 5.710 | 5.030 |
| giant_walk | gait_symmetry | 1.003 | 0.993 |
| hero_walk | head_pitch_deg.mean | -3.890 | -4.150 |
| hero_walk | shoulder_hip_ratio | 1.197 | 1.184 |
| hero_walk | back_slope_deg | 8.070 | 7.580 |
| hero_walk | torso_roll_deg | 5.220 | 4.740 |
| hero_walk | roll_plant_lag | 0.129 | 0.134 |
| hero_walk | gait_symmetry | 0.998 | 0.997 |
| longneck_walk | limp_index | 1.308 | 1.352 |
| longneck_walk | head_yaw_vs_body_deg.p95 | 71.870 | 82.200 |
| longneck_walk | back_slope_deg | 21.180 | 21.170 |
| longneck_walk | foot_slip_cm.p95 | 2.140 | 2.650 |
| longneck_walk | foot_slip_cm.mean | 0.350 | 0.410 |
| trotter_walk | torso_roll_deg | 2.020 | 1.850 |
| trotter_walk | leg_extension | 0.854 | 0.852 |

