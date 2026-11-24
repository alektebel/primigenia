# Loop compare baseline -> 2026-11-24-tune1 (seeds in both: seed1, seed42, seed7)

better 61, regressed more than 20%: 12, within tolerance 23

## Regressions

| seed | metric | baseline | 2026-11-24-tune1 | change |
|---|---|---|---|---|
| seed1 | load_cold_s | 14.68 | 25.95 | +77% |
| seed1 | load_creatures_s | 1.4 | 3.69 | +163% |
| seed1 | load_stage_setup_s | 2.36 | 4.22 | +79% |
| seed1 | bot_task_wings | 1360 | 2599 | +91% |
| seed1 | walked_m | 1393 | 792 | -43% |
| seed42 | load_cold_s | 15.78 | 34.74 | +120% |
| seed42 | load_creatures_s | 1.17 | 3.7 | +216% |
| seed42 | load_stage_setup_s | 2.93 | 6.9 | +136% |
| seed42 | walked_m | 1921 | 809 | -58% |
| seed7 | load_cold_s | 14.49 | 23.37 | +61% |
| seed7 | load_creatures_s | 1.8 | 2.33 | +30% |
| seed7 | walked_m | 1333 | 695 | -48% |

## Improved

| seed | metric | baseline | 2026-11-24-tune1 | change |
|---|---|---|---|---|
| seed1 | t_hunt_s | 126 | 93.9 | -25% |
| seed1 | t_friend_s | 1178 | 222 | -81% |
| seed1 | t_dig_s | 1189 | 224 | -81% |
| seed1 | t_wings_s | 1325 | 484 | -63% |
| seed1 | t_fire_s | 1427 | 540 | -62% |
| seed1 | t_cousin_s | - | 491 | now measured |
| seed1 | befriend_tries | 2 | 1 | -50% |
| seed1 | max_gap_s | 90.7 | 41.3 | -54% |
| seed1 | dead_frac_30 | 0.13 | 0 | -100% |
| seed1 | max_novelty_gap_min | 15.08 | 1.64 | -89% |
| seed1 | species_10min | 2 | 4 | +100% |
| seed1 | species_30min | 3 | 4 | +33% |
| seed1 | bot_task_hunt | 1255 | 939 | -25% |
| seed1 | bot_task_friend | 10522 | 1283 | -88% |
| seed1 | bot_task_dig | 110 | 21 | -81% |
| seed1 | bot_task_fire | 1024 | 563 | -45% |
| seed1 | bot_total | 14271 | 5405 | -62% |
| seed1 | species_seen | 3 | 4 | +33% |
| seed42 | t_hunt_s | 353 | 81.1 | -77% |
| seed42 | t_friend_s | - | 220 | now measured |
| seed42 | t_dig_s | - | 223 | now measured |
| seed42 | t_wings_s | - | 447 | now measured |
| seed42 | t_fire_s | - | 499 | now measured |
| seed42 | t_cousin_s | - | 448 | now measured |
| seed42 | deaths_before_evolve | 2 | 1 | -50% |
| seed42 | befriend_tries | - | 1 | now measured |
| seed42 | max_gap_s | 180 | 42.7 | -76% |
| seed42 | dead_frac_30 | 0.16 | 0 | -100% |
| seed42 | dna_at_editor | 65 | 101 | +55% |
| seed42 | max_novelty_gap_min | 23.45 | 2.22 | -91% |
| seed42 | species_10min | 2 | 5 | +150% |
| seed42 | species_30min | 2 | 5 | +150% |
| seed42 | bot_task_hunt | 3526 | 811 | -77% |
| seed42 | bot_task_friend | - | 1393 | now measured |
| seed42 | bot_task_dig | - | 22 | now measured |
| seed42 | bot_task_wings | - | 2248 | now measured |
| seed42 | bot_task_fire | - | 519 | now measured |
| seed42 | bot_total | - | 4993 | now measured |
| seed42 | dna_total | 65 | 126 | +94% |
| seed42 | species_seen | 3 | 5 | +67% |
| seed42 | bonds | 0 | 1 | +100000000000% |
| seed7 | t_hunt_s | 172 | 90.4 | -47% |
| seed7 | t_friend_s | 988 | 265 | -73% |
| seed7 | t_dig_s | 1078 | 267 | -75% |
| seed7 | t_wings_s | 1272 | 446 | -65% |
| seed7 | t_fire_s | 1375 | 497 | -64% |
| seed7 | t_cousin_s | - | 447 | now measured |
| seed7 | deaths_before_evolve | 1 | 0 | -100% |
| seed7 | fights_per_kill | 3 | 2 | -33% |
| seed7 | load_stage_setup_s | 1.5 | 1.01 | -33% |
| seed7 | max_gap_s | 58.7 | 41.9 | -29% |
| seed7 | max_novelty_gap_min | 8.12 | 1.75 | -78% |
| seed7 | species_10min | 3 | 4 | +33% |
| seed7 | species_30min | 3 | 4 | +33% |
| seed7 | bot_task_hunt | 1715 | 904 | -47% |
| seed7 | bot_task_friend | 8168 | 1744 | -79% |
| seed7 | bot_task_dig | 892 | 21 | -98% |
| seed7 | bot_task_wings | 1950 | 1794 | -8% |
| seed7 | bot_task_fire | 1029 | 508 | -51% |
| seed7 | bot_total | 13754 | 4971 | -64% |
| seed7 | species_seen | 3 | 4 | +33% |

