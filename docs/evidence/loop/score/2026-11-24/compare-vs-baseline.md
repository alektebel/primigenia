# Loop compare baseline -> 2026-11-24 (seeds in both: seed1, seed42, seed7)

better 49, regressed more than 20%: 15, within tolerance 26

## Regressions

| seed | metric | baseline | 2026-11-24 | change |
|---|---|---|---|---|
| seed1 | max_gap_s | 90.7 | 115 | +27% |
| seed1 | dead_frac_30 | 0.13 | 0.15 | +21% |
| seed1 | species_30min | 3 | 2 | -33% |
| seed1 | bot_task_wings | 1360 | 2332 | +71% |
| seed1 | walked_m | 1393 | 950 | -32% |
| seed1 | species_seen | 3 | 2 | -33% |
| seed42 | max_gap_s | 180 | 326 | +81% |
| seed42 | dead_frac_30 | 0.16 | 0.32 | +100% |
| seed42 | walked_m | 1921 | 1368 | -29% |
| seed7 | max_gap_s | 58.7 | 95.8 | +63% |
| seed7 | dead_frac_30 | 0 | 0.12 | +12250639386% |
| seed7 | species_10min | 3 | 2 | -33% |
| seed7 | species_30min | 3 | 2 | -33% |
| seed7 | bot_task_wings | 1950 | 2356 | +21% |
| seed7 | species_seen | 3 | 2 | -33% |

## Improved

| seed | metric | baseline | 2026-11-24 | change |
|---|---|---|---|---|
| seed1 | t_hunt_s | 126 | 93.9 | -25% |
| seed1 | t_friend_s | 1178 | 453 | -62% |
| seed1 | t_dig_s | 1189 | 458 | -61% |
| seed1 | t_wings_s | 1325 | 691 | -48% |
| seed1 | t_fire_s | 1427 | 748 | -48% |
| seed1 | t_cousin_s | - | 700 | now measured |
| seed1 | load_cold_s | 14.68 | 6.33 | -57% |
| seed1 | load_creatures_s | 1.4 | 0.81 | -42% |
| seed1 | load_stage_setup_s | 2.36 | 1.05 | -56% |
| seed1 | max_novelty_gap_min | 15.08 | 4.98 | -67% |
| seed1 | bot_task_hunt | 1255 | 939 | -25% |
| seed1 | bot_task_friend | 10522 | 3589 | -66% |
| seed1 | bot_task_dig | 110 | 51 | -54% |
| seed1 | bot_task_fire | 1024 | 567 | -45% |
| seed1 | bot_total | 14271 | 7478 | -48% |
| seed42 | t_hunt_s | 353 | 81.1 | -77% |
| seed42 | t_friend_s | - | 589 | now measured |
| seed42 | t_dig_s | - | 593 | now measured |
| seed42 | deaths_before_evolve | 2 | 1 | -50% |
| seed42 | fights_per_kill | 3 | 2 | -33% |
| seed42 | befriend_tries | - | 2 | now measured |
| seed42 | load_cold_s | 15.78 | 7.57 | -52% |
| seed42 | load_creatures_s | 1.17 | 0.81 | -31% |
| seed42 | load_stage_setup_s | 2.93 | 1.4 | -52% |
| seed42 | dna_at_editor | 65 | 68 | +5% |
| seed42 | max_novelty_gap_min | 23.45 | 7.26 | -69% |
| seed42 | species_30min | 2 | 3 | +50% |
| seed42 | bot_task_hunt | 3526 | 811 | -77% |
| seed42 | bot_task_friend | - | 5080 | now measured |
| seed42 | bot_task_dig | - | 36 | now measured |
| seed42 | dna_total | 65 | 68 | +5% |
| seed42 | bonds | 0 | 1 | +100000000000% |
| seed7 | t_hunt_s | 172 | 90.4 | -47% |
| seed7 | t_friend_s | 988 | 490 | -50% |
| seed7 | t_dig_s | 1078 | 495 | -54% |
| seed7 | t_wings_s | 1272 | 731 | -43% |
| seed7 | t_fire_s | 1375 | 782 | -43% |
| seed7 | t_cousin_s | - | 731 | now measured |
| seed7 | deaths_before_evolve | 1 | 0 | -100% |
| seed7 | fights_per_kill | 3 | 2 | -33% |
| seed7 | load_cold_s | 14.49 | 6.21 | -57% |
| seed7 | load_creatures_s | 1.8 | 0.74 | -59% |
| seed7 | load_stage_setup_s | 1.5 | 0.31 | -79% |
| seed7 | max_novelty_gap_min | 8.12 | 4.91 | -40% |
| seed7 | bot_task_hunt | 1715 | 904 | -47% |
| seed7 | bot_task_friend | 8168 | 3995 | -51% |
| seed7 | bot_task_dig | 892 | 51 | -94% |
| seed7 | bot_task_fire | 1029 | 513 | -50% |
| seed7 | bot_total | 13754 | 7819 | -43% |

