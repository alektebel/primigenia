# Visual scorecard `wl4`

PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.

## Summary by check

| check | LOOK.md failure | target | shots checked | failing | worst |
|---|---|---|---|---|---|
| creature_flat_light | Flat light, no shadows | >= 0.3 | 32 | 0 | - |
| creature_crushed | Flat light, no shadows | < 0.25 | 32 | 0 | - |
| bloom | Too much bloom or blur | < 0.02 | 88 | **4** | creature_dawn_hero_close = 0.04149 |
| noise_creature | Noisy, dirty textures | < 6.0 | 32 | 0 | - |
| blur | Too much bloom or blur | >= 120 | 66 | 0 | - |
| plastic_shine | Plastic shine | < 0.01 | 32 | **11** | creature_dawn_hero_close = 0.06659 |
| day_cycle_warmth | Light does not follow the day cycle | > 1.05 | 44 | **8** | creature_dawn_hero_chase = 0.949 |
| day_cycle_night | Light does not follow the day cycle | < 0.5 | 22 | **13** | creature_night_giant_close = 0.9276 |
| creature_readability | Creature does not read at distance | >= 0.1 | 8 | 0 | - |
| saturation_over | Oversaturated colour | < 0.1 | 48 | 0 | - |
| saturation_p95 | Oversaturated colour | <= 0.9 | 48 | 0 | - |
| flat_light | Flat light, no shadows | >= 0.35 | 36 | 0 | - |
| world_crushed | Flat light, no shadows | < 0.05 | 36 | 0 | - |
| noise_world | Noisy, dirty textures | < 6.0 | 48 | 0 | - |
| tiling | Visible tiling | < 0.3 | 40 | **3** | low_dusk_riverbank = 0.3355 |
| tier_parity | Low tier is not the same game | < 0.1 | 24 | **6** | low_midday_forest_floor = 0.318 |
| flat_light_night | Flat light, no shadows | >= 0.15 | 12 | **1** | medium_night_riverbank = 0.1373 |
| world_crushed_night | Flat light, no shadows | < 0.35 | 12 | 0 | - |

## Weak spots today (failing checks)

- **bloom** (Too much bloom or blur): creature_dawn_giant_close=0.04059; creature_dawn_hero_close=0.04149; creature_midday_beetle_chase=0.03215; creature_midday_beetle_close=0.02344
- **plastic_shine** (Plastic shine): creature_dawn_beetle_close=0.01551; creature_dawn_giant_close=0.06606; creature_dawn_hero_close=0.06659; creature_dusk_giant_chase=0.02795; creature_dusk_giant_close=0.03197; creature_dusk_hero_chase=0.02894; creature_dusk_hero_close=0.03231; creature_midday_beetle_chase=0.03849; creature_midday_beetle_close=0.03112; creature_night_giant_close=0.01265; creature_night_hero_close=0.01283
- **day_cycle_warmth** (Light does not follow the day cycle): creature_dawn_beetle_chase=1.0448; creature_dawn_giant_chase=0.9718; creature_dawn_hero_chase=0.949; creature_dawn_spider_chase=0.9815; low_dawn_valley_chase=0.9952; low_dusk_valley_chase=1.015; medium_dawn_valley_chase=0.9884; medium_dusk_valley_chase=1.0101
- **day_cycle_night** (Light does not follow the day cycle): creature_night_beetle_chase=0.842; creature_night_beetle_close=0.8096; creature_night_giant_chase=0.8095; creature_night_giant_close=0.9276; creature_night_hero_chase=0.809; creature_night_hero_close=0.9276; creature_night_spider_chase=0.7554; creature_night_spider_close=0.8591; low_night_creature_dist=0.5139; low_night_valley_chase=0.7718; low_night_valley_east=0.5333; medium_night_valley_chase=0.7709 ...
- **tiling** (Visible tiling): low_dawn_riverbank=0.3106; low_dusk_riverbank=0.3355; low_midday_riverbank=0.3113
- **tier_parity** (Low tier is not the same game): low_dawn_forest_floor=0.2179; low_dawn_riverbank=0.1157; low_dusk_forest_floor=0.2457; low_dusk_riverbank=0.105; low_midday_forest_floor=0.318; low_midday_riverbank=0.2475
- **flat_light_night** (Flat light, no shadows): medium_night_riverbank=0.1373

## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)

| tier | median ms/frame | p95 ms | fps (median) | shots timed |
|---|---|---|---|---|
| low | 3993.5 | 10768.0 | 0.25 | 28 |
| medium | 1641.0 | 12991.2 | 0.61 | 28 |

## Per shot

| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| creature_dawn_beetle_chase | 0.6314 | 0.00197 | 0.5725 | 0.00622 | 0.02339 | 1.4696 | 168 | - | - | - | - | 1.0448 | **day_cycle_warmth** |
| creature_dawn_beetle_close | 0.7569 | 0.01472 | 0.6549 | 0.01238 | 0.05087 | 1.6431 | 176 | - | - | - | - | 1.32 | **plastic_shine** |
| creature_dawn_giant_chase | 0.7725 | 0.0228 | 0.6588 | 0.00269 | 0.01337 | 3.6911 | 254 | - | - | - | - | 0.9718 | **day_cycle_warmth** |
| creature_dawn_giant_close | 0.8353 | 0.03998 | 0.9176 | 0.04059 | 0.03349 | 3.008 | 218 | - | - | - | - | 1.0577 | **bloom, plastic_shine** |
| creature_dawn_hero_chase | 0.7451 | 0.01612 | 0.6431 | 0.00287 | 0.00612 | 3.4549 | 254 | - | - | - | - | 0.949 | **day_cycle_warmth** |
| creature_dawn_hero_close | 0.8235 | 0.03233 | 0.9137 | 0.04149 | 0.02965 | 2.8411 | 220 | - | - | - | - | 1.0609 | **bloom, plastic_shine** |
| creature_dawn_spider_chase | 0.6549 | 0.00475 | 0.5255 | 0.00042 | 0.00214 | 3.3464 | 254 | - | - | - | - | 0.9815 | **day_cycle_warmth** |
| creature_dawn_spider_close | 0.7176 | 0.00717 | 0.7176 | 0.00479 | 0.00326 | 3.2196 | 232 | - | - | - | - | 1.1546 | - |
| creature_dusk_beetle_chase | 0.7412 | 0.00858 | 0.6157 | 0.00736 | 0.01666 | 2.1618 | 188 | - | - | - | - | 1.3305 | - |
| creature_dusk_beetle_close | 0.698 | 0.00424 | 0.6078 | 0.00153 | 0.06807 | 1.4838 | 194 | - | - | - | - | 1.1294 | - |
| creature_dusk_giant_chase | 0.8745 | 0.0656 | 0.8039 | 0.01299 | 0.00349 | 5.5045 | 255 | - | - | - | - | 1.2352 | **plastic_shine** |
| creature_dusk_giant_close | 0.8941 | 0.08032 | 0.8431 | 0.01713 | 0.0114 | 4.3 | 254 | - | - | - | - | 1.1797 | **plastic_shine** |
| creature_dusk_hero_chase | 0.8667 | 0.0591 | 0.8 | 0.0134 | 0.00257 | 5.4123 | 255 | - | - | - | - | 1.2369 | **plastic_shine** |
| creature_dusk_hero_close | 0.8902 | 0.07399 | 0.8392 | 0.01755 | 0.00984 | 4.1708 | 254 | - | - | - | - | 1.1817 | **plastic_shine** |
| creature_dusk_spider_chase | 0.7882 | 0.02471 | 0.6667 | 0.00334 | 0.00094 | 5.1337 | 254 | - | - | - | - | 1.3535 | - |
| creature_dusk_spider_close | 0.7686 | 0.01611 | 0.6706 | 0.00564 | 0.00206 | 4.3106 | 254 | - | - | - | - | 1.2327 | - |
| creature_midday_beetle_chase | 0.5843 | 0.00266 | 0.7294 | 0.03215 | 0.02673 | 2.1916 | 254 | - | - | - | - | - | **bloom, plastic_shine** |
| creature_midday_beetle_close | 0.4667 | 0.00185 | 0.6667 | 0.02344 | 0.06851 | 1.9624 | 254 | - | - | - | - | - | **bloom, plastic_shine** |
| creature_midday_giant_chase | 0.7686 | 0.02583 | 0.6706 | 0.00136 | 0.01609 | 5.3069 | 255 | - | - | - | - | - | - |
| creature_midday_giant_close | 0.7765 | 0.02475 | 0.7216 | 0.00365 | 0.05214 | 2.7356 | 248 | - | - | - | - | - | - |
| creature_midday_hero_chase | 0.7608 | 0.02232 | 0.6667 | 0.00155 | 0.01177 | 5.1773 | 255 | - | - | - | - | - | - |
| creature_midday_hero_close | 0.7569 | 0.02115 | 0.7176 | 0.00314 | 0.04373 | 2.5689 | 248 | - | - | - | - | - | - |
| creature_midday_spider_chase | 0.6471 | 0.00955 | 0.6078 | 0.00482 | 0.00212 | 4.8629 | 254 | - | - | - | - | - | - |
| creature_midday_spider_close | 0.5922 | 0.00454 | 0.5882 | 0.00319 | 0.00333 | 3.1195 | 254 | - | - | - | - | - | - |
| creature_night_beetle_chase | 0.6275 | 4e-05 | 0.5922 | 0.00184 | 0.03805 | 1.4189 | 178 | - | - | - | 0.842 | - | **day_cycle_night** |
| creature_night_beetle_close | 0.4745 | 5e-05 | 0.5333 | 0.00413 | 0.09133 | 1.0336 | 146 | - | - | - | 0.8096 | - | **day_cycle_night** |
| creature_night_giant_chase | 0.8 | 0.02634 | 0.5843 | 0.00014 | 0.00316 | 4.1081 | 254 | - | - | - | 0.8095 | - | **day_cycle_night** |
| creature_night_giant_close | 0.8275 | 0.03566 | 0.702 | 0.00089 | 0.00688 | 3.3828 | 246 | - | - | - | 0.9276 | - | **plastic_shine, day_cycle_night** |
| creature_night_hero_chase | 0.7882 | 0.02199 | 0.5843 | 0.00012 | 0.00184 | 3.9475 | 255 | - | - | - | 0.809 | - | **day_cycle_night** |
| creature_night_hero_close | 0.8157 | 0.03004 | 0.6902 | 0.00096 | 0.00489 | 3.1891 | 240 | - | - | - | 0.9276 | - | **plastic_shine, day_cycle_night** |
| creature_night_spider_chase | 0.6627 | 0.0042 | 0.4627 | 0.00013 | 0.00131 | 3.5516 | 254 | - | - | - | 0.7554 | - | **day_cycle_night** |
| creature_night_spider_close | 0.6275 | 0.00319 | 0.5412 | 0.00053 | 0.00299 | 2.8808 | 244 | - | - | - | 0.8591 | - | **day_cycle_night** |
| low_dawn_creature_dist | 0.7608 | 0.0245 | 0.4471 | 0.0 | 0.00062 | 15.7324 | 255 | - | 0.2101 | - | - | 1.0657 | - |
| low_dawn_forest_floor | 0.5373 | 0.0002 | 0.4353 | 0.0 | 1e-05 | 1.1841 | 188 | - | - | 0.2179 | - | 1.1806 | **tier_parity** |
| low_dawn_madre_spring | 0.5569 | 0.00104 | 0.5137 | 0.0 | 0.0 | 1.7702 | 194 | 0.0511 | - | 0.0161 | - | 1.3377 | - |
| low_dawn_riverbank | 0.5686 | 8e-05 | 0.5059 | 0.0 | 0.0 | 0.9209 | 144 | 0.3106 | - | 0.1157 | - | 1.2975 | **tiling, tier_parity** |
| low_dawn_valley_chase | 0.6824 | 0.0023 | 0.5255 | 0.0 | 0.00041 | 2.9466 | 246 | 0.0681 | - | 0.0035 | - | 0.9952 | **day_cycle_warmth** |
| low_dawn_valley_east | 0.6745 | 0.00369 | 0.5882 | 0.0 | 0.00016 | 3.0795 | 254 | 0.1543 | - | 0.0175 | - | 1.1475 | - |
| low_dawn_vista_wide | 0.498 | 0.0 | 0.498 | 0.0 | 0.0 | 1.6779 | 148 | 0.1024 | - | 0.0003 | - | 1.4051 | - |
| low_dusk_creature_dist | 0.7882 | 0.02697 | 0.4745 | 0.0 | 0.00045 | 16.777 | 255 | - | 0.2298 | - | - | 1.1438 | - |
| low_dusk_forest_floor | 0.5176 | 0.00036 | 0.4353 | 0.0 | 2e-05 | 1.2187 | 166 | - | - | 0.2457 | - | 1.3964 | **tier_parity** |
| low_dusk_madre_spring | 0.5451 | 0.00088 | 0.3843 | 0.0 | 0.0 | 1.8604 | 186 | 0.0785 | - | 0.0154 | - | 1.3276 | - |
| low_dusk_riverbank | 0.5804 | 0.00024 | 0.3725 | 0.0 | 5e-05 | 0.9733 | 142 | 0.3355 | - | 0.105 | - | 1.2874 | **tiling, tier_parity** |
| low_dusk_valley_chase | 0.6863 | 0.00273 | 0.5098 | 0.0 | 0.00031 | 3.2592 | 254 | 0.1014 | - | 0.0036 | - | 1.015 | **day_cycle_warmth** |
| low_dusk_valley_east | 0.6667 | 0.00256 | 0.5255 | 0.0 | 0.00096 | 3.5545 | 254 | 0.1431 | - | 0.0184 | - | 1.2676 | - |
| low_dusk_vista_wide | 0.5804 | 2e-05 | 0.5882 | 0.0 | 0.0 | 1.8392 | 178 | 0.0855 | - | 0.0002 | - | 1.6138 | - |
| low_midday_creature_dist | 0.7373 | 0.01398 | 0.5529 | 0.0 | 0.0 | 19.3131 | 255 | - | 0.3181 | - | - | - | - |
| low_midday_forest_floor | 0.5255 | 0.00013 | 0.6588 | 0.00078 | 1e-05 | 1.6764 | 254 | - | - | 0.318 | - | - | **tier_parity** |
| low_midday_madre_spring | 0.5922 | 0.0006 | 0.6902 | 0.00482 | 0.0 | 2.4739 | 254 | 0.0437 | - | 0.0546 | - | - | - |
| low_midday_riverbank | 0.6549 | 0.00017 | 0.6078 | 0.00224 | 3e-05 | 1.5128 | 226 | 0.3113 | - | 0.2475 | - | - | **tiling, tier_parity** |
| low_midday_valley_chase | 0.8235 | 0.02744 | 0.5216 | 0.0 | 0.0 | 3.8782 | 252 | 0.0655 | - | 0.0035 | - | - | - |
| low_midday_valley_east | 0.7725 | 0.00768 | 0.5569 | 0.0 | 0.0 | 4.0388 | 254 | 0.1149 | - | 0.0277 | - | - | - |
| low_midday_vista_wide | 0.502 | 1e-05 | 0.5765 | 0.0 | 0.0 | 1.881 | 150 | 0.0713 | - | 0.0002 | - | - | - |
| low_night_creature_dist | 0.5098 | 0.00374 | 0.2667 | 0.0 | 0.00035 | 11.3518 | 255 | - | 0.1027 | - | 0.5139 | - | **day_cycle_night** |
| low_night_forest_floor | 0.6667 | 0.00064 | 0.2706 | 0.0 | 0.19463 | 0.4388 | 68 | - | - | 0.0761 | 0.3279 | - | - |
| low_night_madre_spring | 0.6471 | 0.00743 | 0.2784 | 0.0 | 0.28248 | 1.2002 | 148 | 0.0755 | - | 0.0058 | 0.2687 | - | - |
| low_night_riverbank | 0.6039 | 5e-05 | 0.2471 | 0.0 | 0.23854 | 0.4153 | 70 | 0.2675 | - | 0.0821 | 0.3677 | - | - |
| low_night_valley_chase | 0.4627 | 0.00041 | 0.4549 | 0.0 | 9e-05 | 2.8811 | 176 | 0.0735 | - | 0.001 | 0.7718 | - | **day_cycle_night** |
| low_night_valley_east | 0.6157 | 0.01451 | 0.498 | 0.0 | 0.07654 | 2.5326 | 184 | 0.1565 | - | 0.0029 | 0.5333 | - | **day_cycle_night** |
| low_night_vista_wide | 0.5294 | 0.0 | 0.3412 | 0.0 | 0.0501 | 1.0985 | 138 | 0.0805 | - | 0.0003 | 0.4417 | - | - |
| medium_dawn_creature_dist | 0.8353 | 0.04295 | 0.4863 | 0.0 | 0.00079 | 16.5025 | 255 | - | 0.1962 | - | - | 1.0605 | - |
| medium_dawn_forest_floor | 0.8196 | 0.01925 | 0.7451 | 0.0 | 0.00945 | 2.766 | 254 | - | - | - | - | 1.2272 | - |
| medium_dawn_madre_spring | 0.6588 | 0.0157 | 0.549 | 0.0 | 0.0 | 1.8372 | 200 | 0.0617 | - | - | - | 1.3904 | - |
| medium_dawn_riverbank | 0.5843 | 0.00033 | 0.4157 | 0.0 | 0.0 | 0.7327 | 140 | 0.2836 | - | - | - | 1.4564 | - |
| medium_dawn_valley_chase | 0.6824 | 0.00287 | 0.5294 | 0.0 | 0.0136 | 3.0101 | 244 | 0.0707 | - | - | - | 0.9884 | **day_cycle_warmth** |
| medium_dawn_valley_east | 0.749 | 0.01634 | 0.6 | 8e-05 | 0.00321 | 3.2239 | 254 | 0.1417 | - | - | - | 1.1409 | - |
| medium_dawn_vista_wide | 0.498 | 4e-05 | 0.498 | 0.0 | 0.0 | 1.7412 | 158 | 0.1012 | - | - | - | 1.4047 | - |
| medium_dusk_creature_dist | 0.8824 | 0.06466 | 0.5333 | 0.0 | 0.0021 | 18.4112 | 255 | - | 0.2277 | - | - | 1.1854 | - |
| medium_dusk_forest_floor | 0.8196 | 0.02144 | 0.6078 | 0.0 | 0.0001 | 2.5711 | 254 | - | - | - | - | 1.2693 | - |
| medium_dusk_madre_spring | 0.6549 | 0.0122 | 0.4196 | 6e-05 | 1e-05 | 1.944 | 194 | 0.0753 | - | - | - | 1.3765 | - |
| medium_dusk_riverbank | 0.5765 | 0.00037 | 0.4667 | 0.0 | 0.0 | 1.0011 | 128 | 0.1163 | - | - | - | 1.5375 | - |
| medium_dusk_valley_chase | 0.6863 | 0.00392 | 0.5137 | 0.0 | 0.00535 | 3.476 | 254 | 0.0918 | - | - | - | 1.0101 | **day_cycle_warmth** |
| medium_dusk_valley_east | 0.7255 | 0.01224 | 0.5451 | 0.0 | 0.01173 | 3.62 | 254 | 0.1496 | - | - | - | 1.2598 | - |
| medium_dusk_vista_wide | 0.5804 | 6e-05 | 0.5882 | 0.0 | 0.0 | 1.8895 | 186 | 0.086 | - | - | - | 1.613 | - |
| medium_midday_creature_dist | 0.8275 | 0.04042 | 0.698 | 0.00051 | 0.0 | 25.3848 | 255 | - | 0.3555 | - | - | - | - |
| medium_midday_forest_floor | 0.8039 | 0.01561 | 0.7373 | 0.00015 | 4e-05 | 3.4682 | 255 | - | - | - | - | - | - |
| medium_midday_madre_spring | 0.7137 | 0.01346 | 0.7765 | 0.00476 | 0.0 | 2.715 | 254 | 0.0442 | - | - | - | - | - |
| medium_midday_riverbank | 0.6588 | 0.0003 | 0.8157 | 0.00315 | 0.00488 | 0.9834 | 202 | 0.234 | - | - | - | - | - |
| medium_midday_valley_chase | 0.8235 | 0.02931 | 0.5294 | 0.00018 | 0.0 | 4.331 | 254 | 0.0606 | - | - | - | - | - |
| medium_midday_valley_east | 0.8078 | 0.02444 | 0.6 | 6e-05 | 0.0 | 4.4832 | 254 | 0.1051 | - | - | - | - | - |
| medium_midday_vista_wide | 0.502 | 0.0001 | 0.5765 | 0.0 | 0.0 | 1.9613 | 162 | 0.0692 | - | - | - | - | - |
| medium_night_creature_dist | 0.6118 | 0.00954 | 0.3255 | 0.0 | 0.00066 | 13.8628 | 255 | - | 0.1071 | - | 0.4902 | - | - |
| medium_night_forest_floor | 0.8431 | 0.03333 | 0.2588 | 0.0 | 0.04151 | 0.5758 | 66 | - | - | - | 0.4181 | - | - |
| medium_night_madre_spring | 0.549 | 0.01574 | 0.2745 | 0.0 | 0.26902 | 1.1989 | 150 | 0.0813 | - | - | 0.2891 | - | - |
| medium_night_riverbank | 0.6 | 0.00221 | 0.1373 | 0.0 | 0.29306 | 0.2222 | 50 | 0.079 | - | - | 0.2843 | - | **flat_light_night** |
| medium_night_valley_chase | 0.4667 | 0.00074 | 0.451 | 0.0 | 0.00025 | 3.0351 | 190 | 0.0717 | - | - | 0.7709 | - | **day_cycle_night** |
| medium_night_valley_east | 0.502 | 0.00833 | 0.498 | 0.0 | 0.06249 | 2.5854 | 194 | 0.1502 | - | - | 0.5575 | - | **day_cycle_night** |
| medium_night_vista_wide | 0.5294 | 1e-05 | 0.3412 | 0.0 | 0.05012 | 1.1365 | 144 | 0.0816 | - | - | 0.441 | - | - |

## Not measurable

- Plastic shine as specular/roughness per material (needs the material parameters, only a glint-fraction proxy is measured)
- Black cartoon outlines (never used; no check)
- Creature skin wet/matte rules (LOOK.md 4): a design rule, not an image statistic
- Frame time is wall clock on software GL under a shared CPU (llvmpipe): informational and only comparable between runs on a similarly loaded machine; it does not show real GPU fps
- Sun direction and terrain light are fixed by the hero look: dawn and dusk differ only by sky/cloud tint and the creature light, so the light-per-time-of-day checks measure what the game does today
- Creature close-ups are on the studio preview stage (CreaturePreview) with the game's day_night light numbers, not inside the island; the game's own terrain bounce and fog are absent
