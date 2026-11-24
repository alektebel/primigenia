# Visual scorecard `baseline`

PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.

## Summary by check

| check | LOOK.md failure | target | shots checked | failing | worst |
|---|---|---|---|---|---|
| creature_flat_light | Flat light, no shadows | >= 0.3 | 32 | **8** | creature_night_giant_chase = 0.1176 |
| creature_crushed | Flat light, no shadows | < 0.25 | 32 | **8** | creature_night_beetle_close = 0.84166 |
| bloom | Too much bloom or blur | < 0.02 | 88 | **7** | low_midday_madre_spring = 0.0321 |
| noise_creature | Noisy, dirty textures | < 6.0 | 32 | 0 | - |
| blur | Too much bloom or blur | >= 120 | 66 | 0 | - |
| plastic_shine | Plastic shine | < 0.01 | 32 | **6** | creature_midday_spider_chase = 0.02315 |
| day_cycle_warmth | Light does not follow the day cycle | > 1.05 | 44 | **39** | creature_dawn_spider_close = 0.8864 |
| day_cycle_night | Light does not follow the day cycle | < 0.5 | 22 | **11** | low_night_madre_spring = 0.6429 |
| creature_readability | Creature does not read at distance | >= 0.1 | 8 | **2** | medium_night_creature_dist = 0.0709 |
| saturation_over | Oversaturated colour | < 0.1 | 48 | **8** | medium_night_valley_chase = 0.29758 |
| saturation_p95 | Oversaturated colour | <= 0.9 | 48 | **6** | medium_dusk_forest_floor = 0.9294 |
| flat_light | Flat light, no shadows | >= 0.35 | 48 | 0 | - |
| world_crushed | Flat light, no shadows | < 0.05 | 48 | **7** | medium_night_forest_floor = 0.65294 |
| noise_world | Noisy, dirty textures | < 6.0 | 48 | **3** | medium_midday_forest_floor = 7.3144 |
| tiling | Visible tiling | < 0.3 | 40 | **3** | low_midday_riverbank = 0.3943 |
| tier_parity | Low tier is not the same game | < 0.1 | 24 | **8** | low_midday_forest_floor = 0.2815 |

## Weak spots today (failing checks)

- **creature_flat_light** (Flat light, no shadows): creature_night_beetle_chase=0.1294; creature_night_beetle_close=0.1216; creature_night_giant_chase=0.1176; creature_night_giant_close=0.1176; creature_night_hero_chase=0.1176; creature_night_hero_close=0.1176; creature_night_spider_chase=0.1294; creature_night_spider_close=0.1176
- **creature_crushed** (Flat light, no shadows): creature_night_beetle_chase=0.7983; creature_night_beetle_close=0.84166; creature_night_giant_chase=0.69277; creature_night_giant_close=0.5914; creature_night_hero_chase=0.68679; creature_night_hero_close=0.58646; creature_night_spider_chase=0.71316; creature_night_spider_close=0.68355
- **bloom** (Too much bloom or blur): low_dawn_madre_spring=0.0233; low_dusk_madre_spring=0.02254; low_midday_madre_spring=0.0321; medium_dawn_madre_spring=0.02226; medium_dusk_madre_spring=0.02158; medium_midday_forest_floor=0.02195; medium_midday_madre_spring=0.02938
- **plastic_shine** (Plastic shine): creature_dawn_spider_chase=0.01062; creature_dusk_spider_chase=0.01072; creature_midday_beetle_close=0.01105; creature_midday_giant_chase=0.02003; creature_midday_hero_chase=0.02048; creature_midday_spider_chase=0.02315
- **day_cycle_warmth** (Light does not follow the day cycle): creature_dawn_beetle_chase=0.9044; creature_dawn_beetle_close=0.8916; creature_dawn_giant_chase=0.9456; creature_dawn_giant_close=0.899; creature_dawn_hero_chase=0.9298; creature_dawn_hero_close=0.8969; creature_dawn_spider_chase=0.9251; creature_dawn_spider_close=0.8864; creature_dusk_beetle_chase=0.9032; creature_dusk_beetle_close=0.8916; creature_dusk_giant_chase=0.9304; creature_dusk_giant_close=0.8996 ...
- **day_cycle_night** (Light does not follow the day cycle): low_night_forest_floor=0.5638; low_night_madre_spring=0.6429; low_night_riverbank=0.5773; low_night_valley_chase=0.6046; low_night_valley_east=0.593; low_night_vista_wide=0.6386; medium_night_madre_spring=0.634; medium_night_riverbank=0.5528; medium_night_valley_chase=0.601; medium_night_valley_east=0.5815; medium_night_vista_wide=0.6375
- **creature_readability** (Creature does not read at distance): low_night_creature_dist=0.0719; medium_night_creature_dist=0.0709
- **saturation_over** (Oversaturated colour): low_night_valley_chase=0.29488; low_night_valley_east=0.11759; medium_dawn_forest_floor=0.1096; medium_dusk_forest_floor=0.10837; medium_midday_forest_floor=0.11485; medium_night_riverbank=0.11761; medium_night_valley_chase=0.29758; medium_night_valley_east=0.12136
- **saturation_p95** (Oversaturated colour): low_night_valley_chase=0.9255; medium_dawn_forest_floor=0.9216; medium_dusk_forest_floor=0.9294; medium_midday_forest_floor=0.9176; medium_night_riverbank=0.9176; medium_night_valley_chase=0.9255
- **world_crushed** (Flat light, no shadows): low_night_forest_floor=0.1125; low_night_riverbank=0.05734; low_night_valley_east=0.0665; medium_night_forest_floor=0.65294; medium_night_madre_spring=0.07672; medium_night_riverbank=0.05254; medium_night_valley_east=0.11077
- **noise_world** (Noisy, dirty textures): medium_dawn_forest_floor=6.5666; medium_dusk_forest_floor=6.3515; medium_midday_forest_floor=7.3144
- **tiling** (Visible tiling): low_dusk_riverbank=0.3579; low_midday_riverbank=0.3943; low_night_riverbank=0.3114
- **tier_parity** (Low tier is not the same game): low_dawn_forest_floor=0.2632; low_dawn_riverbank=0.1386; low_dusk_forest_floor=0.2643; low_dusk_riverbank=0.1408; low_midday_forest_floor=0.2815; low_midday_riverbank=0.1547; low_night_forest_floor=0.2311; low_night_riverbank=0.1183

## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)

| tier | median ms/frame | p95 ms | fps (median) | shots timed |
|---|---|---|---|---|
| low | 2769.5 | 8572.2 | 0.36 | 28 |
| medium | 1447.2 | 10252.1 | 0.69 | 28 |

## Per shot

| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| creature_dawn_beetle_chase | 0.702 | 0.00145 | 0.4235 | 0.00075 | 0.10362 | 1.703 | 190 | - | - | - | - | 0.9044 | **day_cycle_warmth** |
| creature_dawn_beetle_close | 0.498 | 0.00133 | 0.4196 | 0.00448 | 0.18452 | 1.4611 | 190 | - | - | - | - | 0.8916 | **day_cycle_warmth** |
| creature_dawn_giant_chase | 0.7255 | 0.00555 | 0.5059 | 0.00147 | 0.07542 | 3.8483 | 254 | - | - | - | - | 0.9456 | **day_cycle_warmth** |
| creature_dawn_giant_close | 0.7059 | 0.00133 | 0.5373 | 0.00112 | 0.10239 | 1.8596 | 194 | - | - | - | - | 0.899 | **day_cycle_warmth** |
| creature_dawn_hero_chase | 0.6745 | 0.0029 | 0.4941 | 0.00195 | 0.02881 | 3.8157 | 254 | - | - | - | - | 0.9298 | **day_cycle_warmth** |
| creature_dawn_hero_close | 0.7176 | 0.00115 | 0.5294 | 0.00082 | 0.07747 | 1.7665 | 194 | - | - | - | - | 0.8969 | **day_cycle_warmth** |
| creature_dawn_spider_chase | 0.7098 | 0.00111 | 0.4039 | 0.00709 | 0.01497 | 3.2075 | 254 | - | - | - | - | 0.9251 | **plastic_shine, day_cycle_warmth** |
| creature_dawn_spider_close | 0.5098 | 0.00029 | 0.4039 | 0.00163 | 0.01861 | 2.326 | 194 | - | - | - | - | 0.8864 | **day_cycle_warmth** |
| creature_dusk_beetle_chase | 0.6431 | 0.00143 | 0.4235 | 0.00077 | 0.09895 | 1.722 | 188 | - | - | - | - | 0.9032 | **day_cycle_warmth** |
| creature_dusk_beetle_close | 0.498 | 0.00132 | 0.4196 | 0.00448 | 0.18461 | 1.4612 | 190 | - | - | - | - | 0.8916 | **day_cycle_warmth** |
| creature_dusk_giant_chase | 0.6902 | 0.00397 | 0.502 | 0.00167 | 0.05033 | 3.8561 | 254 | - | - | - | - | 0.9304 | **day_cycle_warmth** |
| creature_dusk_giant_close | 0.7059 | 0.00127 | 0.5373 | 0.00112 | 0.10278 | 1.8563 | 192 | - | - | - | - | 0.8996 | **day_cycle_warmth** |
| creature_dusk_hero_chase | 0.698 | 0.00393 | 0.4941 | 0.00171 | 0.04367 | 3.7849 | 254 | - | - | - | - | 0.9305 | **day_cycle_warmth** |
| creature_dusk_hero_close | 0.7137 | 0.00114 | 0.5294 | 0.00082 | 0.07687 | 1.7675 | 194 | - | - | - | - | 0.8959 | **day_cycle_warmth** |
| creature_dusk_spider_chase | 0.6431 | 0.00085 | 0.4078 | 0.00708 | 0.01394 | 3.2114 | 254 | - | - | - | - | 0.9166 | **plastic_shine, day_cycle_warmth** |
| creature_dusk_spider_close | 0.5098 | 0.00027 | 0.4039 | 0.00163 | 0.01877 | 2.3414 | 194 | - | - | - | - | 0.8873 | **day_cycle_warmth** |
| creature_midday_beetle_chase | 0.5922 | 0.00151 | 0.5804 | 0.0039 | 0.0187 | 2.2235 | 242 | - | - | - | - | - | - |
| creature_midday_beetle_close | 0.4588 | 0.00059 | 0.5569 | 0.00857 | 0.06014 | 1.7649 | 226 | - | - | - | - | - | **plastic_shine** |
| creature_midday_giant_chase | 0.6941 | 0.00564 | 0.698 | 0.01093 | 0.01842 | 5.3439 | 255 | - | - | - | - | - | **plastic_shine** |
| creature_midday_giant_close | 0.7059 | 0.00249 | 0.7176 | 0.00285 | 0.03393 | 2.4876 | 254 | - | - | - | - | - | - |
| creature_midday_hero_chase | 0.698 | 0.00457 | 0.6902 | 0.01154 | 0.01679 | 5.143 | 255 | - | - | - | - | - | **plastic_shine** |
| creature_midday_hero_close | 0.7137 | 0.00199 | 0.7059 | 0.00242 | 0.02567 | 2.358 | 254 | - | - | - | - | - | - |
| creature_midday_spider_chase | 0.6039 | 0.00103 | 0.6 | 0.0164 | 0.00101 | 4.614 | 254 | - | - | - | - | - | **plastic_shine** |
| creature_midday_spider_close | 0.5451 | 0.00051 | 0.5686 | 0.00436 | 0.0008 | 3.1532 | 252 | - | - | - | - | - | - |
| creature_night_beetle_chase | 0.6471 | 0.00215 | 0.1294 | 4e-05 | 0.7983 | 0.7731 | 114 | - | - | - | 0.1275 | - | **creature_flat_light, creature_crushed** |
| creature_night_beetle_close | 0.7059 | 0.01056 | 0.1216 | 0.00066 | 0.84166 | 0.7039 | 132 | - | - | - | 0.1246 | - | **creature_flat_light, creature_crushed** |
| creature_night_giant_chase | 0.7176 | 0.00507 | 0.1176 | 0.0003 | 0.69277 | 1.1963 | 168 | - | - | - | 0.1306 | - | **creature_flat_light, creature_crushed** |
| creature_night_giant_close | 0.7059 | 0.00061 | 0.1176 | 0.00022 | 0.5914 | 0.5949 | 88 | - | - | - | 0.1223 | - | **creature_flat_light, creature_crushed** |
| creature_night_hero_chase | 0.7216 | 0.00388 | 0.1176 | 0.00041 | 0.68679 | 1.2317 | 170 | - | - | - | 0.1327 | - | **creature_flat_light, creature_crushed** |
| creature_night_hero_close | 0.7059 | 0.00087 | 0.1176 | 0.00015 | 0.58646 | 0.5915 | 82 | - | - | - | 0.1223 | - | **creature_flat_light, creature_crushed** |
| creature_night_spider_chase | 0.7529 | 0.01448 | 0.1294 | 0.00023 | 0.71316 | 1.3137 | 178 | - | - | - | 0.1372 | - | **creature_flat_light, creature_crushed** |
| creature_night_spider_close | 0.7255 | 0.00381 | 0.1176 | 0.00014 | 0.68355 | 0.9381 | 122 | - | - | - | 0.1085 | - | **creature_flat_light, creature_crushed** |
| low_dawn_creature_dist | 0.9137 | 0.10057 | 0.4078 | 0.0 | 0.00014 | 17.4422 | 255 | - | 0.1522 | - | - | 1.4038 | - |
| low_dawn_forest_floor | 0.6627 | 0.00407 | 0.6824 | 0.00383 | 0.00634 | 3.4735 | 255 | - | - | 0.2632 | - | 1.0222 | **tier_parity, day_cycle_warmth** |
| low_dawn_madre_spring | 0.7255 | 0.00275 | 0.6863 | 0.0233 | 0.00176 | 3.0941 | 255 | 0.0657 | - | 0.0359 | - | 0.9957 | **bloom, day_cycle_warmth** |
| low_dawn_riverbank | 0.702 | 0.00097 | 0.4235 | 0.0 | 0.00159 | 1.6907 | 254 | 0.2582 | - | 0.1386 | - | 1.0065 | **tier_parity, day_cycle_warmth** |
| low_dawn_valley_chase | 0.8471 | 0.03999 | 0.4902 | 0.0 | 3e-05 | 3.1549 | 254 | 0.0696 | - | 0.0032 | - | 0.9953 | **day_cycle_warmth** |
| low_dawn_valley_east | 0.8275 | 0.02095 | 0.5529 | 0.0 | 0.0004 | 3.9054 | 255 | 0.1551 | - | 0.0214 | - | 0.9876 | **day_cycle_warmth** |
| low_dawn_vista_wide | 0.7647 | 0.00117 | 0.5216 | 0.0 | 1e-05 | 1.7448 | 138 | 0.087 | - | 0.0004 | - | 1.0095 | **day_cycle_warmth** |
| low_dusk_creature_dist | 0.9176 | 0.10126 | 0.4078 | 0.0 | 0.0 | 17.4072 | 255 | - | 0.1406 | - | - | 1.4086 | - |
| low_dusk_forest_floor | 0.6588 | 0.00368 | 0.6392 | 0.00219 | 0.00588 | 3.0817 | 255 | - | - | 0.2643 | - | 1.0913 | **tier_parity** |
| low_dusk_madre_spring | 0.749 | 0.00411 | 0.6784 | 0.02254 | 0.00171 | 3.1461 | 255 | 0.0449 | - | 0.0358 | - | 1.0314 | **bloom, day_cycle_warmth** |
| low_dusk_riverbank | 0.7529 | 0.00123 | 0.5137 | 0.0 | 0.00148 | 1.7061 | 254 | 0.3579 | - | 0.1408 | - | 0.9777 | **tiling, tier_parity, day_cycle_warmth** |
| low_dusk_valley_chase | 0.8392 | 0.0387 | 0.4706 | 0.0 | 2e-05 | 3.4114 | 254 | 0.0706 | - | 0.003 | - | 1.011 | **day_cycle_warmth** |
| low_dusk_valley_east | 0.8235 | 0.02067 | 0.4941 | 0.0 | 0.00037 | 4.5098 | 255 | 0.1302 | - | 0.021 | - | 1.0173 | **day_cycle_warmth** |
| low_dusk_vista_wide | 0.7725 | 0.00166 | 0.4902 | 0.0 | 1e-05 | 2.023 | 154 | 0.0796 | - | 0.0003 | - | 1.0122 | **day_cycle_warmth** |
| low_midday_creature_dist | 0.7412 | 0.01615 | 0.549 | 0.0 | 0.0 | 19.0704 | 255 | - | 0.2746 | - | - | - | - |
| low_midday_forest_floor | 0.6392 | 0.00083 | 0.702 | 0.0026 | 1e-05 | 2.8658 | 255 | - | - | 0.2815 | - | - | **tier_parity** |
| low_midday_madre_spring | 0.7255 | 0.00492 | 0.7255 | 0.0321 | 0.0 | 3.0964 | 255 | 0.0298 | - | 0.0373 | - | - | **bloom** |
| low_midday_riverbank | 0.7216 | 0.00039 | 0.5569 | 1e-05 | 4e-05 | 1.9351 | 254 | 0.3943 | - | 0.1547 | - | - | **tiling, tier_parity** |
| low_midday_valley_chase | 0.8275 | 0.02502 | 0.5098 | 0.0 | 0.0 | 3.3495 | 254 | 0.0644 | - | 0.0037 | - | - | - |
| low_midday_valley_east | 0.8 | 0.01014 | 0.5098 | 0.0 | 0.0 | 4.5187 | 255 | 0.1301 | - | 0.0211 | - | - | - |
| low_midday_vista_wide | 0.7529 | 0.00056 | 0.5412 | 0.0 | 0.0 | 2.0749 | 158 | 0.0823 | - | 0.0002 | - | - | - |
| low_night_creature_dist | 0.9137 | 0.09975 | 0.1569 | 0.0 | 0.27685 | 4.1154 | 140 | - | 0.0719 | - | 0.1477 | - | **creature_readability** |
| low_night_forest_floor | 0.8353 | 0.04749 | 0.6588 | 0.0024 | 0.1125 | 3.6204 | 255 | - | - | 0.2311 | 0.5638 | - | **world_crushed, tier_parity, day_cycle_night** |
| low_night_madre_spring | 0.8353 | 0.03677 | 0.6824 | 0.01641 | 0.04383 | 2.8513 | 255 | 0.0473 | - | 0.0309 | 0.6429 | - | **day_cycle_night** |
| low_night_riverbank | 0.8078 | 0.02249 | 0.4745 | 0.0 | 0.05734 | 1.3618 | 254 | 0.3114 | - | 0.1183 | 0.5773 | - | **world_crushed, tiling, tier_parity, day_cycle_night** |
| low_night_valley_chase | 0.9255 | 0.29488 | 0.4314 | 0.0 | 0.0122 | 2.1555 | 178 | 0.0604 | - | 0.0025 | 0.6046 | - | **saturation_over, saturation_p95, day_cycle_night** |
| low_night_valley_east | 0.8902 | 0.11759 | 0.5176 | 0.0 | 0.0665 | 3.5431 | 254 | 0.2425 | - | 0.0178 | 0.593 | - | **saturation_over, world_crushed, day_cycle_night** |
| low_night_vista_wide | 0.8392 | 0.03051 | 0.4275 | 0.0 | 0.00079 | 1.6638 | 144 | 0.0807 | - | 0.0004 | 0.6386 | - | **day_cycle_night** |
| medium_dawn_creature_dist | 1.0 | 0.18656 | 0.4902 | 0.0 | 0.00027 | 19.6461 | 255 | - | 0.1334 | - | - | 1.417 | - |
| medium_dawn_forest_floor | 0.9216 | 0.1096 | 0.8275 | 0.00824 | 0.03611 | 6.5666 | 255 | - | - | - | - | 1.0061 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dawn_madre_spring | 0.7569 | 0.01613 | 0.7529 | 0.02226 | 0.00201 | 3.2698 | 255 | 0.052 | - | - | - | 0.9979 | **bloom, day_cycle_warmth** |
| medium_dawn_riverbank | 0.7804 | 0.00142 | 0.5529 | 0.0 | 0.00068 | 1.0454 | 220 | 0.0967 | - | - | - | 0.9671 | **day_cycle_warmth** |
| medium_dawn_valley_chase | 0.8471 | 0.04325 | 0.4941 | 5e-05 | 0.00021 | 3.3523 | 254 | 0.0721 | - | - | - | 0.9933 | **day_cycle_warmth** |
| medium_dawn_valley_east | 0.8353 | 0.03414 | 0.6392 | 0.0 | 0.00131 | 4.0314 | 255 | 0.142 | - | - | - | 0.9856 | **day_cycle_warmth** |
| medium_dawn_vista_wide | 0.7647 | 0.00145 | 0.5216 | 0.0 | 2e-05 | 1.814 | 148 | 0.0885 | - | - | - | 1.0093 | **day_cycle_warmth** |
| medium_dusk_creature_dist | 1.0 | 0.18442 | 0.4941 | 0.0 | 0.00041 | 19.6912 | 255 | - | 0.1234 | - | - | 1.4172 | - |
| medium_dusk_forest_floor | 0.9294 | 0.10837 | 0.8235 | 0.00791 | 0.03272 | 6.3515 | 255 | - | - | - | - | 1.0212 | **saturation_over, saturation_p95, noise_world, day_cycle_warmth** |
| medium_dusk_madre_spring | 0.7804 | 0.01887 | 0.7412 | 0.02158 | 0.00196 | 3.3057 | 255 | 0.038 | - | - | - | 1.0321 | **bloom, day_cycle_warmth** |
| medium_dusk_riverbank | 0.7804 | 0.00146 | 0.5294 | 0.0 | 0.00066 | 1.0264 | 216 | 0.1104 | - | - | - | 1.0182 | **day_cycle_warmth** |
| medium_dusk_valley_chase | 0.8431 | 0.042 | 0.4745 | 4e-05 | 0.00012 | 3.607 | 254 | 0.0728 | - | - | - | 1.0087 | **day_cycle_warmth** |
| medium_dusk_valley_east | 0.8275 | 0.03404 | 0.5725 | 1e-05 | 0.00132 | 4.6423 | 255 | 0.1174 | - | - | - | 1.0177 | **day_cycle_warmth** |
| medium_dusk_vista_wide | 0.7725 | 0.00202 | 0.4902 | 0.0 | 2e-05 | 2.0752 | 160 | 0.0803 | - | - | - | 1.0122 | **day_cycle_warmth** |
| medium_midday_creature_dist | 0.8745 | 0.05965 | 0.6902 | 0.00013 | 0.0 | 24.7142 | 255 | - | 0.2904 | - | - | - | - |
| medium_midday_forest_floor | 0.9176 | 0.11485 | 0.8235 | 0.02195 | 6e-05 | 7.3144 | 255 | - | - | - | - | - | **saturation_over, saturation_p95, bloom, noise_world** |
| medium_midday_madre_spring | 0.8078 | 0.03717 | 0.7765 | 0.02938 | 0.0 | 3.4591 | 255 | 0.0345 | - | - | - | - | **bloom** |
| medium_midday_riverbank | 0.749 | 0.00133 | 0.6314 | 1e-05 | 0.0 | 1.4138 | 254 | 0.1189 | - | - | - | - | - |
| medium_midday_valley_chase | 0.8275 | 0.02711 | 0.5098 | 0.00011 | 3e-05 | 3.6752 | 254 | 0.0806 | - | - | - | - | - |
| medium_midday_valley_east | 0.8235 | 0.03684 | 0.5529 | 0.00022 | 1e-05 | 5.1355 | 255 | 0.1045 | - | - | - | - | - |
| medium_midday_vista_wide | 0.7529 | 0.00082 | 0.5412 | 0.0 | 0.0 | 2.1494 | 170 | 0.0827 | - | - | - | - | - |
| medium_night_creature_dist | 0.8902 | 0.08864 | 0.1725 | 0.0 | 0.46517 | 3.1191 | 134 | - | 0.0709 | - | 0.1354 | - | **creature_readability** |
| medium_night_forest_floor | 0.8353 | 0.04047 | 0.7961 | 0.00365 | 0.65294 | 5.3941 | 255 | - | - | - | 0.4836 | - | **world_crushed** |
| medium_night_madre_spring | 0.8431 | 0.04317 | 0.7451 | 0.01631 | 0.07672 | 2.8605 | 254 | 0.0349 | - | - | 0.634 | - | **world_crushed, day_cycle_night** |
| medium_night_riverbank | 0.9176 | 0.11761 | 0.4784 | 0.0 | 0.05254 | 0.6791 | 178 | 0.0869 | - | - | 0.5528 | - | **saturation_over, saturation_p95, world_crushed, day_cycle_night** |
| medium_night_valley_chase | 0.9255 | 0.29758 | 0.4314 | 0.0 | 0.0242 | 2.1803 | 178 | 0.0628 | - | - | 0.601 | - | **saturation_over, saturation_p95, day_cycle_night** |
| medium_night_valley_east | 0.8902 | 0.12136 | 0.5412 | 0.0 | 0.11077 | 3.3203 | 254 | 0.24 | - | - | 0.5815 | - | **saturation_over, world_crushed, day_cycle_night** |
| medium_night_vista_wide | 0.8392 | 0.03067 | 0.4235 | 0.0 | 0.00173 | 1.7258 | 152 | 0.0819 | - | - | 0.6375 | - | **day_cycle_night** |

## Not measurable

- Plastic shine as specular/roughness per material (needs the material parameters, only a glint-fraction proxy is measured)
- Black cartoon outlines (never used; no check)
- Creature skin wet/matte rules (LOOK.md 4): a design rule, not an image statistic
- Frame time is wall clock on software GL under a shared CPU (llvmpipe): informational and only comparable between runs on a similarly loaded machine; it does not show real GPU fps
- Sun direction and terrain light are fixed by the hero look: dawn and dusk differ only by sky/cloud tint and the creature light, so the light-per-time-of-day checks measure what the game does today
- Creature close-ups are on the studio preview stage (CreaturePreview) with the game's day_night light numbers, not inside the island; the game's own terrain bounce and fog are absent
