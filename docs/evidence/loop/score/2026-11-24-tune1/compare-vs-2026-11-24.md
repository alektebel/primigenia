# Loop compare 2026-11-24 -> 2026-11-24-tune1 (seeds in both: seed1, seed42, seed7)

better 53, regressed more than 20%: 12, within tolerance 31

## Regressions

| seed | metric | 2026-11-24 | 2026-11-24-tune1 | change |
|---|---|---|---|---|
| seed1 | load_cold_s | 6.33 | 25.95 | +310% |
| seed1 | load_creatures_s | 0.81 | 3.69 | +354% |
| seed1 | load_stage_setup_s | 1.05 | 4.22 | +303% |
| seed42 | fights_per_kill | 2 | 3 | +50% |
| seed42 | load_cold_s | 7.57 | 34.74 | +359% |
| seed42 | load_creatures_s | 0.81 | 3.7 | +356% |
| seed42 | load_stage_setup_s | 1.4 | 6.9 | +395% |
| seed42 | walked_m | 1368 | 809 | -41% |
| seed7 | load_cold_s | 6.21 | 23.37 | +276% |
| seed7 | load_creatures_s | 0.74 | 2.33 | +215% |
| seed7 | load_stage_setup_s | 0.31 | 1.01 | +225% |
| seed7 | walked_m | 1093 | 695 | -36% |

## Improved

| seed | metric | 2026-11-24 | 2026-11-24-tune1 | change |
|---|---|---|---|---|
| seed1 | t_friend_s | 453 | 222 | -51% |
| seed1 | t_dig_s | 458 | 224 | -51% |
| seed1 | t_wings_s | 691 | 484 | -30% |
| seed1 | t_fire_s | 748 | 540 | -28% |
| seed1 | t_cousin_s | 700 | 491 | -30% |
| seed1 | befriend_tries | 2 | 1 | -50% |
| seed1 | max_gap_s | 115 | 41.3 | -64% |
| seed1 | dead_frac_30 | 0.15 | 0 | -100% |
| seed1 | dna_at_editor | 96 | 103 | +7% |
| seed1 | max_novelty_gap_min | 4.98 | 1.64 | -67% |
| seed1 | species_10min | 2 | 4 | +100% |
| seed1 | species_30min | 2 | 4 | +100% |
| seed1 | bot_task_friend | 3589 | 1283 | -64% |
| seed1 | bot_task_dig | 51 | 21 | -59% |
| seed1 | bot_task_fire | 567 | 563 | -1% |
| seed1 | bot_total | 7478 | 5405 | -28% |
| seed1 | dna_total | 97 | 104 | +7% |
| seed1 | species_seen | 2 | 4 | +100% |
| seed42 | t_friend_s | 589 | 220 | -63% |
| seed42 | t_dig_s | 593 | 223 | -62% |
| seed42 | t_wings_s | - | 447 | now measured |
| seed42 | t_fire_s | - | 499 | now measured |
| seed42 | t_cousin_s | - | 448 | now measured |
| seed42 | befriend_tries | 2 | 1 | -50% |
| seed42 | max_gap_s | 326 | 42.7 | -87% |
| seed42 | dead_frac_30 | 0.32 | 0 | -100% |
| seed42 | dna_at_editor | 68 | 101 | +49% |
| seed42 | max_novelty_gap_min | 7.26 | 2.22 | -69% |
| seed42 | species_10min | 2 | 5 | +150% |
| seed42 | species_30min | 3 | 5 | +67% |
| seed42 | bot_task_friend | 5080 | 1393 | -73% |
| seed42 | bot_task_dig | 36 | 22 | -39% |
| seed42 | bot_task_wings | - | 2248 | now measured |
| seed42 | bot_task_fire | - | 519 | now measured |
| seed42 | bot_total | - | 4993 | now measured |
| seed42 | dna_total | 68 | 126 | +85% |
| seed42 | species_seen | 3 | 5 | +67% |
| seed7 | t_friend_s | 490 | 265 | -46% |
| seed7 | t_dig_s | 495 | 267 | -46% |
| seed7 | t_wings_s | 731 | 446 | -39% |
| seed7 | t_fire_s | 782 | 497 | -36% |
| seed7 | t_cousin_s | 731 | 447 | -39% |
| seed7 | max_gap_s | 95.8 | 41.9 | -56% |
| seed7 | dead_frac_30 | 0.12 | 0 | -100% |
| seed7 | max_novelty_gap_min | 4.91 | 1.75 | -64% |
| seed7 | species_10min | 2 | 4 | +100% |
| seed7 | species_30min | 2 | 4 | +100% |
| seed7 | bot_task_friend | 3995 | 1744 | -56% |
| seed7 | bot_task_dig | 51 | 21 | -59% |
| seed7 | bot_task_wings | 2356 | 1794 | -24% |
| seed7 | bot_task_fire | 513 | 508 | -1% |
| seed7 | bot_total | 7819 | 4971 | -36% |
| seed7 | species_seen | 2 | 4 | +100% |

