# Visual scorecard `fit`

PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.

## Summary by check

| check | LOOK.md failure | target | shots checked | failing | worst |
|---|---|---|---|---|---|
| creature_flat_light | Flat light, no shadows | >= 0.3 | 32 | **8** | creature_night_spider_close = 0.1059 |
| creature_crushed | Flat light, no shadows | < 0.25 | 32 | **8** | creature_night_beetle_close = 0.83676 |
| bloom | Too much bloom or blur | < 0.02 | 88 | **7** | low_midday_madre_spring = 0.0321 |
| noise_creature | Noisy, dirty textures | < 6.0 | 32 | 0 | - |
| blur | Too much bloom or blur | >= 120 | 66 | 0 | - |
| plastic_shine | Plastic shine | < 0.01 | 32 | **6** | creature_midday_spider_chase = 0.02389 |
| day_cycle_warmth | Light does not follow the day cycle | > 1.05 | 44 | **39** | creature_dawn_spider_close = 0.8889 |
| day_cycle_night | Light does not follow the day cycle | < 0.5 | 22 | **11** | low_night_madre_spring = 0.6429 |
| creature_readability | Creature does not read at distance | >= 0.1 | 8 | **2** | medium_night_creature_dist = 0.0707 |
| saturation_over | Oversaturated colour | < 0.1 | 48 | **8** | medium_night_valley_chase = 0.29754 |
| saturation_p95 | Oversaturated colour | <= 0.9 | 48 | **6** | medium_dusk_forest_floor = 0.9294 |
| flat_light | Flat light, no shadows | >= 0.35 | 48 | 0 | - |
| world_crushed | Flat light, no shadows | < 0.05 | 48 | **7** | medium_night_forest_floor = 0.65294 |
| noise_world | Noisy, dirty textures | < 6.0 | 48 | **3** | medium_midday_forest_floor = 7.3144 |
| tiling | Visible tiling | < 0.3 | 40 | **3** | low_midday_riverbank = 0.3943 |
| tier_parity | Low tier is not the same game | < 0.1 | 24 | **8** | low_midday_forest_floor = 0.2815 |

## Weak spots today (failing checks)

- **creature_flat_light** (Flat light, no shadows): creature_night_beetle_chase=0.1333; creature_night_beetle_close=0.1216; creature_night_giant_chase=0.1137; creature_night_giant_close=0.1176; creature_night_hero_chase=0.1098; creature_night_hero_close=0.1176; creature_night_spider_chase=0.1216; creature_night_spider_close=0.1059
- **creature_crushed** (Flat light, no shadows): creature_night_beetle_chase=0.79419; creature_night_beetle_close=0.83676; creature_night_giant_chase=0.67715; creature_night_giant_close=0.56234; creature_night_hero_chase=0.67122; creature_night_hero_close=0.55776; creature_night_spider_chase=0.74153; creature_night_spider_close=0.70891
- **bloom** (Too much bloom or blur): low_dawn_madre_spring=0.0233; low_dusk_madre_spring=0.02254; low_midday_madre_spring=0.0321; medium_dawn_madre_spring=0.02226; medium_dusk_madre_spring=0.02158; medium_midday_forest_floor=0.02195; medium_midday_madre_spring=0.02938
- **plastic_shine** (Plastic shine): creature_dawn_spider_chase=0.01082; creature_dusk_spider_chase=0.01097; creature_midday_beetle_close=0.01109; creature_midday_giant_chase=0.0208; creature_midday_hero_chase=0.02155; creature_midday_spider_chase=0.02389
- **day_cycle_warmth** (Light does not follow the day cycle): creature_dawn_beetle_chase=0.9047; creature_dawn_beetle_close=0.8929; creature_dawn_giant_chase=0.9515; creature_dawn_giant_close=0.9043; creature_dawn_hero_chase=0.9351; creature_dawn_hero_close=0.9016; creature_dawn_spider_chase=0.9295; creature_dawn_spider_close=0.8889; creature_dusk_beetle_chase=0.9033; creature_dusk_beetle_close=0.8929; creature_dusk_giant_chase=0.9358; creature_dusk_giant_close=0.9043 ...
- **day_cycle_night** (Light does not follow the day cycle): low_night_forest_floor=0.5638; low_night_madre_spring=0.6429; low_night_riverbank=0.5773; low_night_valley_chase=0.6046; low_night_valley_east=0.593; low_night_vista_wide=0.6386; medium_night_madre_spring=0.634; medium_night_riverbank=0.5528; medium_night_valley_chase=0.6011; medium_night_valley_east=0.5814; medium_night_vista_wide=0.6375
- **creature_readability** (Creature does not read at distance): low_night_creature_dist=0.0717; medium_night_creature_dist=0.0707
- **saturation_over** (Oversaturated colour): low_night_valley_chase=0.2949; low_night_valley_east=0.11758; medium_dawn_forest_floor=0.1096; medium_dusk_forest_floor=0.10837; medium_midday_forest_floor=0.11485; medium_night_riverbank=0.11761; medium_night_valley_chase=0.29754; medium_night_valley_east=0.12133
- **saturation_p95** (Oversaturated colour): low_night_valley_chase=0.9255; medium_dawn_forest_floor=0.9216; medium_dusk_forest_floor=0.9294; medium_midday_forest_floor=0.9176; medium_night_riverbank=0.9176; medium_night_valley_chase=0.9255
- **world_crushed** (Flat light, no shadows): low_night_forest_floor=0.1125; low_night_riverbank=0.05734; low_night_valley_east=0.06639; medium_night_forest_floor=0.65294; medium_night_madre_spring=0.07672; medium_night_riverbank=0.05254; medium_night_valley_east=0.11062
- **noise_world** (Noisy, dirty textures): medium_dawn_forest_floor=6.5666; medium_dusk_forest_floor=6.3515; medium_midday_forest_floor=7.3144
- **tiling** (Visible tiling): low_dusk_riverbank=0.3579; low_midday_riverbank=0.3943; low_night_riverbank=0.3114
- **tier_parity** (Low tier is not the same game): low_dawn_forest_floor=0.2632; low_dawn_riverbank=0.1386; low_dusk_forest_floor=0.2643; low_dusk_riverbank=0.1408; low_midday_forest_floor=0.2815; low_midday_riverbank=0.1547; low_night_forest_floor=0.2311; low_night_riverbank=0.1183

## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)

| tier | median ms/frame | p95 ms | fps (median) | shots timed |
|---|---|---|---|---|
| low | 3851.1 | 10680.4 | 0.26 | 28 |
| medium | 2095.2 | 11339.0 | 0.48 | 28 |

## Per shot

| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| creature_dawn_beetle_chase | 0.702 | 0.0014 | 0.4275 | 0.00074 | 0.10099 | 1.6845 | 190 | - | - | - | - | 0.9047 | **day_cycle_warmth** |
| creature_dawn_beetle_close | 0.4941 | 0.0012 | 0.4196 | 0.00451 | 0.18332 | 1.4713 | 188 | - | - | - | - | 0.8929 | **day_cycle_warmth** |
| creature_dawn_giant_chase | 0.7137 | 0.00551 | 0.498 | 0.0014 | 0.06483 | 3.9453 | 254 | - | - | - | - | 0.9515 | **day_cycle_warmth** |
| creature_dawn_giant_close | 0.6824 | 0.00112 | 0.5294 | 0.00065 | 0.09451 | 1.9324 | 186 | - | - | - | - | 0.9043 | **day_cycle_warmth** |
| creature_dawn_hero_chase | 0.6588 | 0.003 | 0.4863 | 0.00202 | 0.02457 | 3.9324 | 254 | - | - | - | - | 0.9351 | **day_cycle_warmth** |
| creature_dawn_hero_close | 0.7059 | 0.00094 | 0.5137 | 0.00045 | 0.06929 | 1.849 | 188 | - | - | - | - | 0.9016 | **day_cycle_warmth** |
| creature_dawn_spider_chase | 0.7098 | 0.00119 | 0.3922 | 0.00723 | 0.01433 | 3.0827 | 254 | - | - | - | - | 0.9295 | **plastic_shine, day_cycle_warmth** |
| creature_dawn_spider_close | 0.5059 | 0.00037 | 0.3961 | 0.00139 | 0.01796 | 2.2348 | 200 | - | - | - | - | 0.8889 | **day_cycle_warmth** |
| creature_dusk_beetle_chase | 0.6431 | 0.00139 | 0.4235 | 0.00076 | 0.09676 | 1.7038 | 184 | - | - | - | - | 0.9033 | **day_cycle_warmth** |
| creature_dusk_beetle_close | 0.498 | 0.00121 | 0.4196 | 0.00451 | 0.18342 | 1.4704 | 188 | - | - | - | - | 0.8929 | **day_cycle_warmth** |
| creature_dusk_giant_chase | 0.6745 | 0.00401 | 0.4902 | 0.00158 | 0.04317 | 3.9611 | 254 | - | - | - | - | 0.9358 | **day_cycle_warmth** |
| creature_dusk_giant_close | 0.6863 | 0.00114 | 0.5294 | 0.00065 | 0.09479 | 1.9216 | 186 | - | - | - | - | 0.9043 | **day_cycle_warmth** |
| creature_dusk_hero_chase | 0.6863 | 0.004 | 0.4824 | 0.00183 | 0.03618 | 3.9157 | 254 | - | - | - | - | 0.9353 | **day_cycle_warmth** |
| creature_dusk_hero_close | 0.7059 | 0.00094 | 0.5137 | 0.00045 | 0.06869 | 1.8529 | 190 | - | - | - | - | 0.9012 | **day_cycle_warmth** |
| creature_dusk_spider_chase | 0.6471 | 0.00094 | 0.3922 | 0.00723 | 0.01327 | 3.0772 | 254 | - | - | - | - | 0.9209 | **plastic_shine, day_cycle_warmth** |
| creature_dusk_spider_close | 0.5059 | 0.00037 | 0.3961 | 0.00139 | 0.0182 | 2.2434 | 200 | - | - | - | - | 0.8906 | **day_cycle_warmth** |
| creature_midday_beetle_chase | 0.5922 | 0.0014 | 0.5765 | 0.00387 | 0.01812 | 2.2081 | 238 | - | - | - | - | - | - |
| creature_midday_beetle_close | 0.4588 | 0.00052 | 0.5529 | 0.0086 | 0.06102 | 1.7762 | 222 | - | - | - | - | - | **plastic_shine** |
| creature_midday_giant_chase | 0.6824 | 0.00588 | 0.6863 | 0.01132 | 0.01133 | 5.4257 | 255 | - | - | - | - | - | **plastic_shine** |
| creature_midday_giant_close | 0.6863 | 0.00281 | 0.7059 | 0.0019 | 0.02163 | 2.5628 | 254 | - | - | - | - | - | - |
| creature_midday_hero_chase | 0.6863 | 0.00488 | 0.6824 | 0.012 | 0.00609 | 5.2805 | 255 | - | - | - | - | - | **plastic_shine** |
| creature_midday_hero_close | 0.7059 | 0.00228 | 0.6902 | 0.00149 | 0.01161 | 2.4616 | 254 | - | - | - | - | - | - |
| creature_midday_spider_chase | 0.6078 | 0.00107 | 0.5804 | 0.01717 | 0.00085 | 4.4696 | 254 | - | - | - | - | - | **plastic_shine** |
| creature_midday_spider_close | 0.5412 | 0.00069 | 0.5608 | 0.00418 | 0.00071 | 3.0655 | 254 | - | - | - | - | - | - |
| creature_night_beetle_chase | 0.6471 | 0.00234 | 0.1333 | 4e-05 | 0.79419 | 0.7721 | 114 | - | - | - | 0.1284 | - | **creature_flat_light, creature_crushed** |
| creature_night_beetle_close | 0.7059 | 0.01072 | 0.1216 | 0.00066 | 0.83676 | 0.7122 | 132 | - | - | - | 0.1258 | - | **creature_flat_light, creature_crushed** |
| creature_night_giant_chase | 0.6784 | 0.00498 | 0.1137 | 0.00032 | 0.67715 | 1.2339 | 178 | - | - | - | 0.1303 | - | **creature_flat_light, creature_crushed** |
| creature_night_giant_close | 0.6 | 0.00059 | 0.1176 | 8e-05 | 0.56234 | 0.6107 | 84 | - | - | - | 0.1206 | - | **creature_flat_light, creature_crushed** |
| creature_night_hero_chase | 0.6706 | 0.00385 | 0.1098 | 0.0004 | 0.67122 | 1.2855 | 188 | - | - | - | 0.1323 | - | **creature_flat_light, creature_crushed** |
| creature_night_hero_close | 0.6 | 0.00069 | 0.1176 | 5e-05 | 0.55776 | 0.5976 | 78 | - | - | - | 0.1201 | - | **creature_flat_light, creature_crushed** |
| creature_night_spider_chase | 0.7529 | 0.01662 | 0.1216 | 0.00022 | 0.74153 | 1.225 | 176 | - | - | - | 0.1325 | - | **creature_flat_light, creature_crushed** |
| creature_night_spider_close | 0.6902 | 0.00453 | 0.1059 | 8e-05 | 0.70891 | 0.8619 | 118 | - | - | - | 0.1022 | - | **creature_flat_light, creature_crushed** |
| low_dawn_creature_dist | 0.9098 | 0.09991 | 0.4078 | 0.0 | 0.0 | 17.4261 | 255 | - | 0.1526 | - | - | 1.4072 | - |
| low_dawn_forest_floor | 0.6627 | 0.00407 | 0.6824 | 0.00383 | 0.00634 | 3.4735 | 255 | - | - | 0.2632 | - | 1.0222 | **tier_parity, day_cycle_warmth** |
| low_dawn_madre_spring | 0.7255 | 0.00275 | 0.6863 | 0.0233 | 0.00176 | 3.094 | 255 | 0.0656 | - | 0.0359 | - | 0.9957 | **bloom, day_cycle_warmth** |
| low_dawn_riverbank | 0.702 | 0.00097 | 0.4235 | 0.0 | 0.00159 | 1.6907 | 254 | 0.2582 | - | 0.1386 | - | 1.0065 | **tier_parity, day_cycle_warmth** |
| low_dawn_valley_chase | 0.8471 | 0.03995 | 0.4902 | 0.0 | 2e-05 | 3.1539 | 254 | 0.0682 | - | 0.0032 | - | 0.9953 | **day_cycle_warmth** |
| low_dawn_valley_east | 0.8275 | 0.02093 | 0.5529 | 0.0 | 0.0004 | 3.9022 | 255 | 0.1557 | - | 0.0214 | - | 0.9875 | **day_cycle_warmth** |
| low_dawn_vista_wide | 0.7647 | 0.00117 | 0.5216 | 0.0 | 1e-05 | 1.7446 | 138 | 0.087 | - | 0.0004 | - | 1.0095 | **day_cycle_warmth** |
| low_dusk_creature_dist | 0.9176 | 0.10003 | 0.4 | 0.0 | 0.0 | 17.4542 | 255 | - | 0.141 | - | - | 1.4089 | - |
| low_dusk_forest_floor | 0.6588 | 0.00368 | 0.6392 | 0.00219 | 0.00588 | 3.0817 | 255 | - | - | 0.2643 | - | 1.0913 | **tier_parity** |
| low_dusk_madre_spring | 0.749 | 0.00411 | 0.6784 | 0.02254 | 0.00171 | 3.1462 | 255 | 0.0448 | - | 0.0358 | - | 1.0314 | **bloom, day_cycle_warmth** |
| low_dusk_riverbank | 0.7529 | 0.00123 | 0.5137 | 0.0 | 0.00148 | 1.7061 | 254 | 0.3579 | - | 0.1408 | - | 0.9777 | **tiling, tier_parity, day_cycle_warmth** |
| low_dusk_valley_chase | 0.8392 | 0.03865 | 0.4706 | 0.0 | 2e-05 | 3.4087 | 254 | 0.0708 | - | 0.003 | - | 1.0111 | **day_cycle_warmth** |
| low_dusk_valley_east | 0.8235 | 0.02066 | 0.4941 | 0.0 | 0.00036 | 4.5074 | 255 | 0.1309 | - | 0.021 | - | 1.0172 | **day_cycle_warmth** |
| low_dusk_vista_wide | 0.7725 | 0.00166 | 0.4902 | 0.0 | 1e-05 | 2.023 | 154 | 0.0796 | - | 0.0003 | - | 1.0122 | **day_cycle_warmth** |
| low_midday_creature_dist | 0.7412 | 0.01528 | 0.549 | 0.0 | 0.0 | 19.1189 | 255 | - | 0.2756 | - | - | - | - |
| low_midday_forest_floor | 0.6392 | 0.00083 | 0.702 | 0.0026 | 1e-05 | 2.8658 | 255 | - | - | 0.2815 | - | - | **tier_parity** |
| low_midday_madre_spring | 0.7255 | 0.00492 | 0.7255 | 0.0321 | 0.0 | 3.0963 | 255 | 0.0297 | - | 0.0373 | - | - | **bloom** |
| low_midday_riverbank | 0.7216 | 0.00039 | 0.5569 | 1e-05 | 4e-05 | 1.9351 | 254 | 0.3943 | - | 0.1547 | - | - | **tiling, tier_parity** |
| low_midday_valley_chase | 0.8275 | 0.02499 | 0.5098 | 0.0 | 0.0 | 3.346 | 254 | 0.0654 | - | 0.0038 | - | - | - |
| low_midday_valley_east | 0.8 | 0.01012 | 0.5098 | 0.0 | 0.0 | 4.5134 | 255 | 0.1318 | - | 0.0212 | - | - | - |
| low_midday_vista_wide | 0.7529 | 0.00056 | 0.5412 | 0.0 | 0.0 | 2.0747 | 158 | 0.0823 | - | 0.0002 | - | - | - |
| low_night_creature_dist | 0.9137 | 0.09963 | 0.1529 | 0.0 | 0.2775 | 4.1259 | 140 | - | 0.0717 | - | 0.1476 | - | **creature_readability** |
| low_night_forest_floor | 0.8353 | 0.04749 | 0.6588 | 0.0024 | 0.1125 | 3.6204 | 255 | - | - | 0.2311 | 0.5638 | - | **world_crushed, tier_parity, day_cycle_night** |
| low_night_madre_spring | 0.8353 | 0.03677 | 0.6824 | 0.01641 | 0.04383 | 2.8512 | 255 | 0.0473 | - | 0.0309 | 0.6429 | - | **day_cycle_night** |
| low_night_riverbank | 0.8078 | 0.02249 | 0.4745 | 0.0 | 0.05734 | 1.3618 | 254 | 0.3114 | - | 0.1183 | 0.5773 | - | **world_crushed, tiling, tier_parity, day_cycle_night** |
| low_night_valley_chase | 0.9255 | 0.2949 | 0.4314 | 0.0 | 0.01221 | 2.1545 | 178 | 0.0604 | - | 0.0025 | 0.6046 | - | **saturation_over, saturation_p95, day_cycle_night** |
| low_night_valley_east | 0.8902 | 0.11758 | 0.5176 | 0.0 | 0.06639 | 3.541 | 254 | 0.2422 | - | 0.0178 | 0.593 | - | **saturation_over, world_crushed, day_cycle_night** |
| low_night_vista_wide | 0.8392 | 0.03053 | 0.4275 | 0.0 | 0.00079 | 1.6638 | 144 | 0.0807 | - | 0.0004 | 0.6386 | - | **day_cycle_night** |
| medium_dawn_creature_dist | 1.0 | 0.18495 | 0.4863 | 0.00014 | 0.00041 | 19.6687 | 255 | - | 0.1343 | - | - | 1.4192 | - |
| medium_dawn_forest_floor | 0.9216 | 0.1096 | 0.8275 | 0.00824 | 0.03611 | 6.5666 | 255 | - | - | - | - | 1.0061 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dawn_madre_spring | 0.7569 | 0.01613 | 0.7529 | 0.02226 | 0.00201 | 3.2697 | 255 | 0.0521 | - | - | - | 0.9979 | **bloom, day_cycle_warmth** |
| medium_dawn_riverbank | 0.7804 | 0.00142 | 0.5529 | 0.0 | 0.00068 | 1.0454 | 220 | 0.0967 | - | - | - | 0.9671 | **day_cycle_warmth** |
| medium_dawn_valley_chase | 0.8471 | 0.04323 | 0.4941 | 0.0 | 0.00018 | 3.3507 | 254 | 0.0716 | - | - | - | 0.9931 | **day_cycle_warmth** |
| medium_dawn_valley_east | 0.8353 | 0.03408 | 0.6392 | 0.0 | 0.00129 | 4.0279 | 255 | 0.1424 | - | - | - | 0.9858 | **day_cycle_warmth** |
| medium_dawn_vista_wide | 0.7647 | 0.00145 | 0.5216 | 0.0 | 2e-05 | 1.8137 | 148 | 0.0885 | - | - | - | 1.0093 | **day_cycle_warmth** |
| medium_dusk_creature_dist | 1.0 | 0.18356 | 0.4863 | 0.0 | 0.00027 | 19.7306 | 255 | - | 0.1235 | - | - | 1.424 | - |
| medium_dusk_forest_floor | 0.9294 | 0.10837 | 0.8235 | 0.00791 | 0.03272 | 6.3515 | 255 | - | - | - | - | 1.0212 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dusk_madre_spring | 0.7804 | 0.01887 | 0.7412 | 0.02158 | 0.00196 | 3.3057 | 255 | 0.038 | - | - | - | 1.0321 | **bloom, day_cycle_warmth** |
| medium_dusk_riverbank | 0.7804 | 0.00146 | 0.5294 | 0.0 | 0.00066 | 1.0264 | 216 | 0.1104 | - | - | - | 1.0182 | **day_cycle_warmth** |
| medium_dusk_valley_chase | 0.8431 | 0.04194 | 0.4745 | 0.0 | 0.0001 | 3.6047 | 254 | 0.0728 | - | - | - | 1.0089 | **day_cycle_warmth** |
| medium_dusk_valley_east | 0.8275 | 0.03398 | 0.5725 | 0.0 | 0.00131 | 4.6403 | 255 | 0.1174 | - | - | - | 1.0181 | **day_cycle_warmth** |
| medium_dusk_vista_wide | 0.7725 | 0.00202 | 0.4902 | 0.0 | 2e-05 | 2.0751 | 160 | 0.0803 | - | - | - | 1.0122 | **day_cycle_warmth** |
| medium_midday_creature_dist | 0.8745 | 0.05859 | 0.6863 | 0.00026 | 0.0 | 24.7871 | 255 | - | 0.2915 | - | - | - | - |
| medium_midday_forest_floor | 0.9176 | 0.11485 | 0.8235 | 0.02195 | 6e-05 | 7.3144 | 255 | - | - | - | - | - | **saturation_over, saturation_p95, bloom, noise_world** |
| medium_midday_madre_spring | 0.8078 | 0.03717 | 0.7765 | 0.02938 | 0.0 | 3.459 | 255 | 0.0345 | - | - | - | - | **bloom** |
| medium_midday_riverbank | 0.749 | 0.00133 | 0.6314 | 1e-05 | 0.0 | 1.4138 | 254 | 0.1189 | - | - | - | - | - |
| medium_midday_valley_chase | 0.8275 | 0.02708 | 0.5098 | 5e-05 | 2e-05 | 3.6724 | 254 | 0.0812 | - | - | - | - | - |
| medium_midday_valley_east | 0.8235 | 0.03682 | 0.5529 | 0.00021 | 1e-05 | 5.1303 | 255 | 0.1064 | - | - | - | - | - |
| medium_midday_vista_wide | 0.7529 | 0.00082 | 0.5412 | 0.0 | 0.0 | 2.1491 | 170 | 0.0827 | - | - | - | - | - |
| medium_night_creature_dist | 0.8902 | 0.08901 | 0.1725 | 0.0 | 0.46227 | 3.1884 | 126 | - | 0.0707 | - | 0.1357 | - | **creature_readability** |
| medium_night_forest_floor | 0.8353 | 0.04047 | 0.7961 | 0.00365 | 0.65294 | 5.3941 | 255 | - | - | - | 0.4836 | - | **world_crushed** |
| medium_night_madre_spring | 0.8431 | 0.04316 | 0.7451 | 0.01631 | 0.07672 | 2.8604 | 254 | 0.0349 | - | - | 0.634 | - | **world_crushed, day_cycle_night** |
| medium_night_riverbank | 0.9176 | 0.11761 | 0.4784 | 0.0 | 0.05254 | 0.6791 | 178 | 0.0869 | - | - | 0.5528 | - | **saturation_over, saturation_p95, world_crushed, day_cycle_night** |
| medium_night_valley_chase | 0.9255 | 0.29754 | 0.4314 | 0.0 | 0.02411 | 2.1789 | 178 | 0.0617 | - | - | 0.6011 | - | **saturation_over, saturation_p95, day_cycle_night** |
| medium_night_valley_east | 0.8902 | 0.12133 | 0.5412 | 0.0 | 0.11062 | 3.3188 | 254 | 0.2396 | - | - | 0.5814 | - | **saturation_over, world_crushed, day_cycle_night** |
| medium_night_vista_wide | 0.8392 | 0.03069 | 0.4235 | 0.0 | 0.00173 | 1.7259 | 152 | 0.0818 | - | - | 0.6375 | - | **day_cycle_night** |

## Not measurable

- Plastic shine as specular/roughness per material (needs the material parameters, only a glint-fraction proxy is measured)
- Black cartoon outlines (never used; no check)
- Creature skin wet/matte rules (LOOK.md 4): a design rule, not an image statistic
- Frame time is wall clock on software GL under a shared CPU (llvmpipe): informational and only comparable between runs on a similarly loaded machine; it does not show real GPU fps
- Sun direction and terrain light are fixed by the hero look: dawn and dusk differ only by sky/cloud tint and the creature light, so the light-per-time-of-day checks measure what the game does today
- Creature close-ups are on the studio preview stage (CreaturePreview) with the game's day_night light numbers, not inside the island; the game's own terrain bounce and fog are absent
