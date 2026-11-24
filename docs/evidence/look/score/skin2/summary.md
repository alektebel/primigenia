# Visual scorecard `skin2`

PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.

## Summary by check

| check | LOOK.md failure | target | shots checked | failing | worst |
|---|---|---|---|---|---|
| creature_flat_light | Flat light, no shadows | >= 0.3 | 32 | **2** | creature_night_spider_chase = 0.2784 |
| creature_crushed | Flat light, no shadows | < 0.25 | 32 | **5** | creature_night_beetle_close = 0.60681 |
| bloom | Too much bloom or blur | < 0.02 | 88 | **7** | low_midday_madre_spring = 0.0321 |
| noise_creature | Noisy, dirty textures | < 6.0 | 32 | 0 | - |
| blur | Too much bloom or blur | >= 120 | 66 | 0 | - |
| plastic_shine | Plastic shine | < 0.01 | 32 | 0 | - |
| day_cycle_warmth | Light does not follow the day cycle | > 1.05 | 44 | **39** | creature_dawn_spider_close = 0.9607 |
| day_cycle_night | Light does not follow the day cycle | < 0.5 | 22 | **11** | low_night_madre_spring = 0.6429 |
| creature_readability | Creature does not read at distance | >= 0.1 | 8 | **2** | medium_night_creature_dist = 0.0565 |
| saturation_over | Oversaturated colour | < 0.1 | 48 | **8** | medium_night_valley_chase = 0.29728 |
| saturation_p95 | Oversaturated colour | <= 0.9 | 48 | **6** | medium_dusk_forest_floor = 0.9294 |
| flat_light | Flat light, no shadows | >= 0.35 | 48 | 0 | - |
| world_crushed | Flat light, no shadows | < 0.05 | 48 | **7** | medium_night_forest_floor = 0.65294 |
| noise_world | Noisy, dirty textures | < 6.0 | 48 | **3** | medium_midday_forest_floor = 7.3144 |
| tiling | Visible tiling | < 0.3 | 40 | **3** | low_midday_riverbank = 0.3943 |
| tier_parity | Low tier is not the same game | < 0.1 | 24 | **8** | low_midday_forest_floor = 0.2815 |

## Weak spots today (failing checks)

- **creature_flat_light** (Flat light, no shadows): creature_night_beetle_close=0.298; creature_night_spider_chase=0.2784
- **creature_crushed** (Flat light, no shadows): creature_night_beetle_chase=0.39815; creature_night_beetle_close=0.60681; creature_night_giant_chase=0.27767; creature_night_giant_close=0.27659; creature_night_hero_chase=0.28531
- **bloom** (Too much bloom or blur): low_dawn_madre_spring=0.0233; low_dusk_madre_spring=0.02254; low_midday_madre_spring=0.0321; medium_dawn_madre_spring=0.02226; medium_dusk_madre_spring=0.02158; medium_midday_forest_floor=0.02195; medium_midday_madre_spring=0.02938
- **day_cycle_warmth** (Light does not follow the day cycle): creature_dawn_beetle_chase=0.9744; creature_dawn_beetle_close=0.9687; creature_dawn_giant_chase=1.0069; creature_dawn_giant_close=0.984; creature_dawn_hero_chase=0.9824; creature_dawn_hero_close=0.9799; creature_dawn_spider_chase=0.9938; creature_dawn_spider_close=0.9607; creature_dusk_beetle_chase=0.9738; creature_dusk_beetle_close=0.9684; creature_dusk_giant_chase=0.9874; creature_dusk_giant_close=0.9849 ...
- **day_cycle_night** (Light does not follow the day cycle): low_night_forest_floor=0.5638; low_night_madre_spring=0.6429; low_night_riverbank=0.5773; low_night_valley_chase=0.6056; low_night_valley_east=0.594; low_night_vista_wide=0.6386; medium_night_madre_spring=0.6341; medium_night_riverbank=0.5528; medium_night_valley_chase=0.6022; medium_night_valley_east=0.5828; medium_night_vista_wide=0.6376
- **creature_readability** (Creature does not read at distance): low_night_creature_dist=0.0619; medium_night_creature_dist=0.0565
- **saturation_over** (Oversaturated colour): low_night_valley_chase=0.29447; low_night_valley_east=0.11739; medium_dawn_forest_floor=0.1096; medium_dusk_forest_floor=0.10837; medium_midday_forest_floor=0.11485; medium_night_riverbank=0.11761; medium_night_valley_chase=0.29728; medium_night_valley_east=0.12124
- **saturation_p95** (Oversaturated colour): low_night_valley_chase=0.9255; medium_dawn_forest_floor=0.9216; medium_dusk_forest_floor=0.9294; medium_midday_forest_floor=0.9176; medium_night_riverbank=0.9176; medium_night_valley_chase=0.9255
- **world_crushed** (Flat light, no shadows): low_night_forest_floor=0.1125; low_night_riverbank=0.05734; low_night_valley_east=0.06527; medium_night_forest_floor=0.65294; medium_night_madre_spring=0.07672; medium_night_riverbank=0.05254; medium_night_valley_east=0.10875
- **noise_world** (Noisy, dirty textures): medium_dawn_forest_floor=6.5666; medium_dusk_forest_floor=6.3515; medium_midday_forest_floor=7.3144
- **tiling** (Visible tiling): low_dusk_riverbank=0.3579; low_midday_riverbank=0.3943; low_night_riverbank=0.3114
- **tier_parity** (Low tier is not the same game): low_dawn_forest_floor=0.2632; low_dawn_riverbank=0.1386; low_dusk_forest_floor=0.2643; low_dusk_riverbank=0.1408; low_midday_forest_floor=0.2815; low_midday_riverbank=0.1547; low_night_forest_floor=0.2311; low_night_riverbank=0.1183

## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)

| tier | median ms/frame | p95 ms | fps (median) | shots timed |
|---|---|---|---|---|
| low | 2894.7 | 8515.9 | 0.35 | 28 |
| medium | 1861.0 | 9478.8 | 0.54 | 28 |

## Per shot

| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| creature_dawn_beetle_chase | 0.702 | 0.00187 | 0.4392 | 0.00075 | 0.08124 | 1.412 | 184 | - | - | - | - | 0.9744 | **day_cycle_warmth** |
| creature_dawn_beetle_close | 0.5569 | 0.00223 | 0.3725 | 0.00352 | 0.1412 | 1.1218 | 180 | - | - | - | - | 0.9687 | **day_cycle_warmth** |
| creature_dawn_giant_chase | 0.8 | 0.03014 | 0.5255 | 0.00044 | 0.13687 | 3.5896 | 254 | - | - | - | - | 1.0069 | **day_cycle_warmth** |
| creature_dawn_giant_close | 0.7725 | 0.01413 | 0.5804 | 0.001 | 0.16902 | 2.0079 | 172 | - | - | - | - | 0.984 | **day_cycle_warmth** |
| creature_dawn_hero_chase | 0.7765 | 0.02504 | 0.5098 | 0.00032 | 0.04658 | 3.403 | 254 | - | - | - | - | 0.9824 | **day_cycle_warmth** |
| creature_dawn_hero_close | 0.7608 | 0.01078 | 0.5765 | 0.0008 | 0.14595 | 1.8527 | 170 | - | - | - | - | 0.9799 | **day_cycle_warmth** |
| creature_dawn_spider_chase | 0.7333 | 0.0071 | 0.4157 | 0.00047 | 0.01448 | 2.8515 | 240 | - | - | - | - | 0.9938 | **day_cycle_warmth** |
| creature_dawn_spider_close | 0.6078 | 0.00227 | 0.4471 | 0.00058 | 0.0222 | 1.9677 | 180 | - | - | - | - | 0.9607 | **day_cycle_warmth** |
| creature_dusk_beetle_chase | 0.6431 | 0.00147 | 0.4392 | 0.00081 | 0.07644 | 1.4252 | 182 | - | - | - | - | 0.9738 | **day_cycle_warmth** |
| creature_dusk_beetle_close | 0.5569 | 0.00224 | 0.3725 | 0.00352 | 0.14136 | 1.1215 | 180 | - | - | - | - | 0.9684 | **day_cycle_warmth** |
| creature_dusk_giant_chase | 0.7843 | 0.02733 | 0.5176 | 0.0003 | 0.07499 | 3.5886 | 254 | - | - | - | - | 0.9874 | **day_cycle_warmth** |
| creature_dusk_giant_close | 0.7725 | 0.01428 | 0.5804 | 0.001 | 0.16938 | 2.0006 | 172 | - | - | - | - | 0.9849 | **day_cycle_warmth** |
| creature_dusk_hero_chase | 0.7882 | 0.02767 | 0.5137 | 0.00024 | 0.06644 | 3.4029 | 254 | - | - | - | - | 0.9879 | **day_cycle_warmth** |
| creature_dusk_hero_close | 0.7608 | 0.01074 | 0.5765 | 0.0008 | 0.14562 | 1.8558 | 170 | - | - | - | - | 0.9791 | **day_cycle_warmth** |
| creature_dusk_spider_chase | 0.6706 | 0.00657 | 0.4118 | 0.0006 | 0.01297 | 2.8421 | 236 | - | - | - | - | 0.9814 | **day_cycle_warmth** |
| creature_dusk_spider_close | 0.6078 | 0.00232 | 0.4471 | 0.00058 | 0.0221 | 1.9772 | 182 | - | - | - | - | 0.9618 | **day_cycle_warmth** |
| creature_midday_beetle_chase | 0.5922 | 0.00131 | 0.5686 | 0.00439 | 0.02997 | 1.988 | 248 | - | - | - | - | - | - |
| creature_midday_beetle_close | 0.4275 | 0.0008 | 0.498 | 0.00682 | 0.06708 | 1.4801 | 228 | - | - | - | - | - | - |
| creature_midday_giant_chase | 0.7529 | 0.01977 | 0.6863 | 0.00191 | 0.03644 | 5.0619 | 255 | - | - | - | - | - | - |
| creature_midday_giant_close | 0.7451 | 0.0106 | 0.7216 | 0.0021 | 0.07965 | 2.2571 | 212 | - | - | - | - | - | - |
| creature_midday_hero_chase | 0.749 | 0.01799 | 0.6824 | 0.00171 | 0.03416 | 4.7648 | 255 | - | - | - | - | - | - |
| creature_midday_hero_close | 0.7373 | 0.00803 | 0.7255 | 0.00174 | 0.0787 | 2.0678 | 210 | - | - | - | - | - | - |
| creature_midday_spider_chase | 0.6235 | 0.004 | 0.5765 | 0.00409 | 0.00349 | 4.3397 | 254 | - | - | - | - | - | - |
| creature_midday_spider_close | 0.5647 | 0.00117 | 0.6 | 0.00202 | 0.00611 | 2.7018 | 236 | - | - | - | - | - | - |
| creature_night_beetle_chase | 0.4863 | 0.00016 | 0.3569 | 5e-05 | 0.39815 | 1.1375 | 152 | - | - | - | 0.4712 | - | **creature_crushed** |
| creature_night_beetle_close | 0.4745 | 0.00021 | 0.298 | 0.00149 | 0.60681 | 0.7363 | 114 | - | - | - | 0.3994 | - | **creature_flat_light, creature_crushed** |
| creature_night_giant_chase | 0.9098 | 0.10886 | 0.3294 | 5e-05 | 0.27767 | 3.2781 | 254 | - | - | - | 0.3966 | - | **creature_crushed** |
| creature_night_giant_close | 0.9333 | 0.16427 | 0.4588 | 0.00022 | 0.27659 | 3.115 | 246 | - | - | - | 0.4412 | - | **creature_crushed** |
| creature_night_hero_chase | 0.9059 | 0.11278 | 0.3294 | 8e-05 | 0.28531 | 3.1752 | 254 | - | - | - | 0.3972 | - | **creature_crushed** |
| creature_night_hero_close | 0.9255 | 0.18445 | 0.4549 | 0.00019 | 0.23886 | 2.9834 | 242 | - | - | - | 0.4377 | - | - |
| creature_night_spider_chase | 0.7882 | 0.02367 | 0.2784 | 0.00013 | 0.19369 | 2.8202 | 254 | - | - | - | 0.3645 | - | **creature_flat_light** |
| creature_night_spider_close | 0.7961 | 0.02595 | 0.3373 | 0.00015 | 0.18833 | 2.4401 | 232 | - | - | - | 0.386 | - | - |
| low_dawn_creature_dist | 0.9216 | 0.10559 | 0.4118 | 0.0 | 0.00014 | 17.4465 | 255 | - | 0.1513 | - | - | 1.4077 | - |
| low_dawn_forest_floor | 0.6627 | 0.00407 | 0.6824 | 0.00383 | 0.00634 | 3.4735 | 255 | - | - | 0.2632 | - | 1.0222 | **tier_parity, day_cycle_warmth** |
| low_dawn_madre_spring | 0.7255 | 0.00276 | 0.6863 | 0.0233 | 0.00176 | 3.0942 | 255 | 0.066 | - | 0.0359 | - | 0.9957 | **bloom, day_cycle_warmth** |
| low_dawn_riverbank | 0.702 | 0.00097 | 0.4235 | 0.0 | 0.00159 | 1.6907 | 254 | 0.2582 | - | 0.1386 | - | 1.0065 | **tier_parity, day_cycle_warmth** |
| low_dawn_valley_chase | 0.8471 | 0.04025 | 0.4902 | 0.0 | 9e-05 | 3.1581 | 254 | 0.0695 | - | 0.0032 | - | 0.9953 | **day_cycle_warmth** |
| low_dawn_valley_east | 0.8275 | 0.02121 | 0.5529 | 0.0 | 0.0004 | 3.9078 | 255 | 0.1546 | - | 0.0215 | - | 0.9875 | **day_cycle_warmth** |
| low_dawn_vista_wide | 0.7647 | 0.00117 | 0.5216 | 0.0 | 1e-05 | 1.745 | 138 | 0.087 | - | 0.0004 | - | 1.0094 | **day_cycle_warmth** |
| low_dusk_creature_dist | 0.9216 | 0.10321 | 0.4039 | 0.0 | 0.00014 | 17.453 | 255 | - | 0.14 | - | - | 1.4069 | - |
| low_dusk_forest_floor | 0.6588 | 0.00368 | 0.6392 | 0.00219 | 0.00588 | 3.0817 | 255 | - | - | 0.2643 | - | 1.0913 | **tier_parity** |
| low_dusk_madre_spring | 0.749 | 0.0041 | 0.6784 | 0.02254 | 0.00171 | 3.1462 | 255 | 0.0448 | - | 0.0358 | - | 1.0314 | **bloom, day_cycle_warmth** |
| low_dusk_riverbank | 0.7529 | 0.00123 | 0.5137 | 0.0 | 0.00148 | 1.7061 | 254 | 0.3579 | - | 0.1408 | - | 0.9777 | **tiling, tier_parity, day_cycle_warmth** |
| low_dusk_valley_chase | 0.8431 | 0.03896 | 0.4706 | 0.0 | 7e-05 | 3.4144 | 254 | 0.071 | - | 0.003 | - | 1.011 | **day_cycle_warmth** |
| low_dusk_valley_east | 0.8235 | 0.02095 | 0.4941 | 0.0 | 0.00037 | 4.5121 | 255 | 0.1294 | - | 0.021 | - | 1.0173 | **day_cycle_warmth** |
| low_dusk_vista_wide | 0.7725 | 0.00166 | 0.4902 | 0.0 | 1e-05 | 2.024 | 154 | 0.0795 | - | 0.0003 | - | 1.0123 | **day_cycle_warmth** |
| low_midday_creature_dist | 0.749 | 0.02047 | 0.549 | 0.0 | 0.00014 | 19.21 | 255 | - | 0.2727 | - | - | - | - |
| low_midday_forest_floor | 0.6392 | 0.00083 | 0.702 | 0.0026 | 1e-05 | 2.8658 | 255 | - | - | 0.2815 | - | - | **tier_parity** |
| low_midday_madre_spring | 0.7255 | 0.00492 | 0.7255 | 0.0321 | 0.0 | 3.0963 | 255 | 0.0298 | - | 0.0373 | - | - | **bloom** |
| low_midday_riverbank | 0.7216 | 0.00039 | 0.5569 | 1e-05 | 4e-05 | 1.9351 | 254 | 0.3943 | - | 0.1547 | - | - | **tiling, tier_parity** |
| low_midday_valley_chase | 0.8275 | 0.02524 | 0.5098 | 0.0 | 3e-05 | 3.3547 | 254 | 0.0646 | - | 0.0037 | - | - | - |
| low_midday_valley_east | 0.8 | 0.01027 | 0.5098 | 0.0 | 0.0 | 4.5242 | 255 | 0.1282 | - | 0.0211 | - | - | - |
| low_midday_vista_wide | 0.7529 | 0.00056 | 0.5412 | 0.0 | 0.0 | 2.0747 | 158 | 0.0823 | - | 0.0002 | - | - | - |
| low_night_creature_dist | 0.9137 | 0.09124 | 0.1843 | 0.0 | 0.25487 | 5.2684 | 255 | - | 0.0619 | - | 0.1663 | - | **creature_readability** |
| low_night_forest_floor | 0.8353 | 0.04749 | 0.6588 | 0.0024 | 0.1125 | 3.6204 | 255 | - | - | 0.2311 | 0.5638 | - | **world_crushed, tier_parity, day_cycle_night** |
| low_night_madre_spring | 0.8353 | 0.03675 | 0.6824 | 0.01641 | 0.04383 | 2.853 | 255 | 0.0463 | - | 0.0309 | 0.6429 | - | **day_cycle_night** |
| low_night_riverbank | 0.8078 | 0.02249 | 0.4745 | 0.0 | 0.05734 | 1.3618 | 254 | 0.3114 | - | 0.1183 | 0.5773 | - | **world_crushed, tiling, tier_parity, day_cycle_night** |
| low_night_valley_chase | 0.9255 | 0.29447 | 0.4314 | 0.0 | 0.01111 | 2.1825 | 180 | 0.0602 | - | 0.0025 | 0.6056 | - | **saturation_over, saturation_p95, day_cycle_night** |
| low_night_valley_east | 0.8902 | 0.11739 | 0.5176 | 0.0 | 0.06527 | 3.5682 | 254 | 0.2312 | - | 0.0177 | 0.594 | - | **saturation_over, world_crushed, day_cycle_night** |
| low_night_vista_wide | 0.8392 | 0.0306 | 0.4275 | 0.0 | 0.00079 | 1.6708 | 146 | 0.0807 | - | 0.0004 | 0.6386 | - | **day_cycle_night** |
| medium_dawn_creature_dist | 1.0 | 0.19046 | 0.4902 | 0.0 | 0.00041 | 19.6687 | 255 | - | 0.1329 | - | - | 1.4184 | - |
| medium_dawn_forest_floor | 0.9216 | 0.1096 | 0.8275 | 0.00824 | 0.03611 | 6.5666 | 255 | - | - | - | - | 1.0061 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dawn_madre_spring | 0.7569 | 0.01613 | 0.7529 | 0.02226 | 0.00201 | 3.2699 | 255 | 0.0525 | - | - | - | 0.9979 | **bloom, day_cycle_warmth** |
| medium_dawn_riverbank | 0.7804 | 0.00142 | 0.5529 | 0.0 | 0.00068 | 1.0454 | 220 | 0.0967 | - | - | - | 0.9671 | **day_cycle_warmth** |
| medium_dawn_valley_chase | 0.8471 | 0.04357 | 0.4941 | 3e-05 | 0.00026 | 3.3549 | 254 | 0.0722 | - | - | - | 0.9932 | **day_cycle_warmth** |
| medium_dawn_valley_east | 0.8353 | 0.03451 | 0.6392 | 0.0 | 0.00129 | 4.0332 | 255 | 0.1419 | - | - | - | 0.9857 | **day_cycle_warmth** |
| medium_dawn_vista_wide | 0.7647 | 0.00145 | 0.5216 | 0.0 | 2e-05 | 1.8146 | 148 | 0.0885 | - | - | - | 1.0093 | **day_cycle_warmth** |
| medium_dusk_creature_dist | 1.0 | 0.18933 | 0.4941 | 0.0 | 0.00069 | 19.7363 | 255 | - | 0.1228 | - | - | 1.4191 | - |
| medium_dusk_forest_floor | 0.9294 | 0.10837 | 0.8235 | 0.00791 | 0.03272 | 6.3515 | 255 | - | - | - | - | 1.0212 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dusk_madre_spring | 0.7804 | 0.01887 | 0.7412 | 0.02158 | 0.00196 | 3.3059 | 255 | 0.0381 | - | - | - | 1.0321 | **bloom, day_cycle_warmth** |
| medium_dusk_riverbank | 0.7804 | 0.00146 | 0.5294 | 0.0 | 0.00066 | 1.0264 | 216 | 0.1104 | - | - | - | 1.0182 | **day_cycle_warmth** |
| medium_dusk_valley_chase | 0.8471 | 0.04224 | 0.4745 | 1e-05 | 0.00018 | 3.6098 | 254 | 0.0731 | - | - | - | 1.0089 | **day_cycle_warmth** |
| medium_dusk_valley_east | 0.8314 | 0.03442 | 0.5725 | 0.0 | 0.0013 | 4.6438 | 255 | 0.117 | - | - | - | 1.018 | **day_cycle_warmth** |
| medium_dusk_vista_wide | 0.7725 | 0.00202 | 0.4902 | 0.0 | 2e-05 | 2.0766 | 160 | 0.08 | - | - | - | 1.0122 | **day_cycle_warmth** |
| medium_midday_creature_dist | 0.8902 | 0.06514 | 0.6902 | 0.0 | 0.00026 | 24.8048 | 255 | - | 0.2885 | - | - | - | - |
| medium_midday_forest_floor | 0.9176 | 0.11485 | 0.8235 | 0.02195 | 6e-05 | 7.3144 | 255 | - | - | - | - | - | **saturation_over, saturation_p95, bloom, noise_world** |
| medium_midday_madre_spring | 0.8078 | 0.03716 | 0.7765 | 0.02938 | 0.0 | 3.459 | 255 | 0.0345 | - | - | - | - | **bloom** |
| medium_midday_riverbank | 0.749 | 0.00133 | 0.6314 | 1e-05 | 0.0 | 1.4138 | 254 | 0.1189 | - | - | - | - | - |
| medium_midday_valley_chase | 0.8275 | 0.02738 | 0.5098 | 0.0001 | 8e-05 | 3.6795 | 254 | 0.0816 | - | - | - | - | - |
| medium_midday_valley_east | 0.8235 | 0.03704 | 0.5529 | 0.00018 | 2e-05 | 5.1413 | 255 | 0.103 | - | - | - | - | - |
| medium_midday_vista_wide | 0.7529 | 0.00082 | 0.5412 | 0.0 | 0.0 | 2.1491 | 170 | 0.0827 | - | - | - | - | - |
| medium_night_creature_dist | 0.8941 | 0.08847 | 0.2078 | 0.0 | 0.41219 | 4.8902 | 255 | - | 0.0565 | - | 0.1618 | - | **creature_readability** |
| medium_night_forest_floor | 0.8353 | 0.04047 | 0.7961 | 0.00365 | 0.65294 | 5.3941 | 255 | - | - | - | 0.4836 | - | **world_crushed** |
| medium_night_madre_spring | 0.8431 | 0.04314 | 0.7451 | 0.01631 | 0.07672 | 2.8623 | 254 | 0.0348 | - | - | 0.6341 | - | **world_crushed, day_cycle_night** |
| medium_night_riverbank | 0.9176 | 0.11761 | 0.4784 | 0.0 | 0.05254 | 0.6791 | 178 | 0.0869 | - | - | 0.5528 | - | **saturation_over, saturation_p95, world_crushed, day_cycle_night** |
| medium_night_valley_chase | 0.9255 | 0.29728 | 0.4314 | 0.0 | 0.02247 | 2.21 | 180 | 0.0603 | - | - | 0.6022 | - | **saturation_over, saturation_p95, day_cycle_night** |
| medium_night_valley_east | 0.8902 | 0.12124 | 0.5412 | 0.0 | 0.10875 | 3.3495 | 254 | 0.2277 | - | - | 0.5828 | - | **saturation_over, world_crushed, day_cycle_night** |
| medium_night_vista_wide | 0.8392 | 0.03076 | 0.4275 | 0.0 | 0.00173 | 1.7328 | 152 | 0.0816 | - | - | 0.6376 | - | **day_cycle_night** |

## Not measurable

- Plastic shine as specular/roughness per material (needs the material parameters, only a glint-fraction proxy is measured)
- Black cartoon outlines (never used; no check)
- Creature skin wet/matte rules (LOOK.md 4): a design rule, not an image statistic
- Frame time is wall clock on software GL under a shared CPU (llvmpipe): informational and only comparable between runs on a similarly loaded machine; it does not show real GPU fps
- Sun direction and terrain light are fixed by the hero look: dawn and dusk differ only by sky/cloud tint and the creature light, so the light-per-time-of-day checks measure what the game does today
- Creature close-ups are on the studio preview stage (CreaturePreview) with the game's day_night light numbers, not inside the island; the game's own terrain bounce and fog are absent
