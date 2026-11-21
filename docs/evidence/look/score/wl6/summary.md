# Visual scorecard `wl6`

PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.

## Summary by check

| check | LOOK.md failure | target | shots checked | failing | worst |
|---|---|---|---|---|---|
| creature_flat_light | Flat light, no shadows | >= 0.3 | 32 | 0 | - |
| creature_crushed | Flat light, no shadows | < 0.25 | 32 | **2** | creature_night_beetle_close = 0.35226 |
| bloom | Too much bloom or blur | < 0.02 | 88 | **2** | creature_midday_beetle_chase = 0.03215 |
| noise_creature | Noisy, dirty textures | < 6.0 | 32 | 0 | - |
| blur | Too much bloom or blur | >= 120 | 66 | 0 | - |
| plastic_shine | Plastic shine | < 0.01 | 32 | **6** | creature_midday_beetle_chase = 0.03849 |
| day_cycle_warmth | Light does not follow the day cycle | > 1.05 | 44 | **7** | creature_dawn_hero_chase = 0.9221 |
| day_cycle_night | Light does not follow the day cycle | < 0.5 | 22 | **9** | low_night_valley_chase = 0.8083 |
| creature_readability | Creature does not read at distance | >= 0.1 | 8 | **2** | medium_night_creature_dist = 0.0611 |
| saturation_over | Oversaturated colour | < 0.1 | 48 | 0 | - |
| saturation_p95 | Oversaturated colour | <= 0.9 | 48 | 0 | - |
| flat_light | Flat light, no shadows | >= 0.35 | 36 | 0 | - |
| world_crushed | Flat light, no shadows | < 0.05 | 36 | 0 | - |
| noise_world | Noisy, dirty textures | < 6.0 | 48 | 0 | - |
| tiling | Visible tiling | < 0.3 | 40 | **3** | low_dusk_riverbank = 0.3394 |
| tier_parity | Low tier is not the same game | < 0.1 | 24 | **6** | low_midday_forest_floor = 0.318 |
| flat_light_night | Flat light, no shadows | >= 0.15 | 12 | **1** | medium_night_riverbank = 0.149 |
| world_crushed_night | Flat light, no shadows | < 0.35 | 12 | 0 | - |

## Weak spots today (failing checks)

- **creature_crushed** (Flat light, no shadows): creature_night_beetle_chase=0.26017; creature_night_beetle_close=0.35226
- **bloom** (Too much bloom or blur): creature_midday_beetle_chase=0.03215; creature_midday_beetle_close=0.02344
- **plastic_shine** (Plastic shine): creature_dawn_giant_close=0.02642; creature_dawn_hero_close=0.02666; creature_dusk_giant_close=0.01124; creature_dusk_hero_close=0.01158; creature_midday_beetle_chase=0.03849; creature_midday_beetle_close=0.03112
- **day_cycle_warmth** (Light does not follow the day cycle): creature_dawn_beetle_chase=1.0066; creature_dawn_giant_chase=0.9416; creature_dawn_hero_chase=0.9221; creature_dawn_spider_chase=0.93; low_dawn_valley_chase=1.0206; medium_dawn_valley_chase=1.0106; medium_dusk_valley_chase=1.0433
- **day_cycle_night** (Light does not follow the day cycle): creature_night_beetle_chase=0.5723; creature_night_beetle_close=0.5373; creature_night_giant_close=0.5864; creature_night_hero_close=0.5807; creature_night_spider_close=0.5068; low_night_valley_chase=0.8083; low_night_valley_east=0.56; medium_night_valley_chase=0.8067; medium_night_valley_east=0.5859
- **creature_readability** (Creature does not read at distance): low_night_creature_dist=0.0634; medium_night_creature_dist=0.0611
- **tiling** (Visible tiling): low_dawn_riverbank=0.309; low_dusk_riverbank=0.3394; low_midday_riverbank=0.3113
- **tier_parity** (Low tier is not the same game): low_dawn_forest_floor=0.2396; low_dawn_riverbank=0.1174; low_dusk_forest_floor=0.2791; low_dusk_riverbank=0.1087; low_midday_forest_floor=0.318; low_midday_riverbank=0.2475
- **flat_light_night** (Flat light, no shadows): medium_night_riverbank=0.149

## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)

| tier | median ms/frame | p95 ms | fps (median) | shots timed |
|---|---|---|---|---|
| low | 3121.5 | 9725.8 | 0.32 | 28 |
| medium | 2028.8 | 11367.9 | 0.49 | 28 |

## Per shot

| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| creature_dawn_beetle_chase | 0.6863 | 0.00374 | 0.4745 | 0.00287 | 0.05183 | 1.3987 | 176 | - | - | - | - | 1.0066 | **day_cycle_warmth** |
| creature_dawn_beetle_close | 0.8196 | 0.03049 | 0.5804 | 0.00632 | 0.08713 | 1.5916 | 178 | - | - | - | - | 1.3524 | - |
| creature_dawn_giant_chase | 0.7843 | 0.02488 | 0.5373 | 0.00075 | 0.05134 | 3.2221 | 254 | - | - | - | - | 0.9416 | **day_cycle_warmth** |
| creature_dawn_giant_close | 0.8706 | 0.062 | 0.8745 | 0.01415 | 0.10431 | 3.1045 | 230 | - | - | - | - | 1.0775 | **plastic_shine** |
| creature_dawn_hero_chase | 0.7647 | 0.02045 | 0.5176 | 0.00074 | 0.02247 | 3.0739 | 254 | - | - | - | - | 0.9221 | **day_cycle_warmth** |
| creature_dawn_hero_close | 0.8627 | 0.05548 | 0.8706 | 0.01421 | 0.08909 | 2.9884 | 234 | - | - | - | - | 1.0797 | **plastic_shine** |
| creature_dawn_spider_chase | 0.698 | 0.00674 | 0.4196 | 0.00024 | 0.0094 | 2.8553 | 244 | - | - | - | - | 0.93 | **day_cycle_warmth** |
| creature_dawn_spider_close | 0.7608 | 0.0123 | 0.6431 | 0.00102 | 0.01437 | 3.045 | 230 | - | - | - | - | 1.169 | - |
| creature_dusk_beetle_chase | 0.7882 | 0.01656 | 0.5569 | 0.00551 | 0.03581 | 2.0998 | 184 | - | - | - | - | 1.3541 | - |
| creature_dusk_beetle_close | 0.7529 | 0.01011 | 0.5098 | 0.00121 | 0.10952 | 1.4403 | 194 | - | - | - | - | 1.1149 | - |
| creature_dusk_giant_chase | 0.9098 | 0.1031 | 0.7294 | 0.00242 | 0.01915 | 5.4175 | 254 | - | - | - | - | 1.3511 | - |
| creature_dusk_giant_close | 0.9373 | 0.12428 | 0.7686 | 0.00512 | 0.05932 | 4.4697 | 254 | - | - | - | - | 1.249 | **plastic_shine** |
| creature_dusk_hero_chase | 0.902 | 0.10297 | 0.7255 | 0.00258 | 0.01631 | 5.3802 | 255 | - | - | - | - | 1.3548 | - |
| creature_dusk_hero_close | 0.9333 | 0.1252 | 0.7686 | 0.00529 | 0.04831 | 4.3848 | 254 | - | - | - | - | 1.2483 | **plastic_shine** |
| creature_dusk_spider_chase | 0.8235 | 0.03452 | 0.6157 | 0.00126 | 0.00366 | 4.8869 | 254 | - | - | - | - | 1.4384 | - |
| creature_dusk_spider_close | 0.8039 | 0.02455 | 0.6235 | 0.00238 | 0.00846 | 4.1893 | 254 | - | - | - | - | 1.2652 | - |
| creature_midday_beetle_chase | 0.5843 | 0.00266 | 0.7294 | 0.03215 | 0.02673 | 2.1918 | 254 | - | - | - | - | - | **bloom, plastic_shine** |
| creature_midday_beetle_close | 0.4667 | 0.00185 | 0.6667 | 0.02344 | 0.06851 | 1.9624 | 254 | - | - | - | - | - | **bloom, plastic_shine** |
| creature_midday_giant_chase | 0.7686 | 0.02583 | 0.6706 | 0.00136 | 0.01608 | 5.3067 | 255 | - | - | - | - | - | - |
| creature_midday_giant_close | 0.7765 | 0.02475 | 0.7216 | 0.00365 | 0.05214 | 2.7356 | 248 | - | - | - | - | - | - |
| creature_midday_hero_chase | 0.7608 | 0.02233 | 0.6667 | 0.00155 | 0.01177 | 5.1772 | 255 | - | - | - | - | - | - |
| creature_midday_hero_close | 0.7569 | 0.02115 | 0.7176 | 0.00314 | 0.04373 | 2.5689 | 248 | - | - | - | - | - | - |
| creature_midday_spider_chase | 0.6471 | 0.00955 | 0.6078 | 0.00482 | 0.00212 | 4.863 | 254 | - | - | - | - | - | - |
| creature_midday_spider_close | 0.5922 | 0.00454 | 0.5882 | 0.00319 | 0.00333 | 3.1195 | 254 | - | - | - | - | - | - |
| creature_night_beetle_chase | 0.4824 | 2e-05 | 0.4588 | 9e-05 | 0.26017 | 1.3662 | 176 | - | - | - | 0.5723 | - | **creature_crushed, day_cycle_night** |
| creature_night_beetle_close | 0.5098 | 5e-05 | 0.4078 | 0.0018 | 0.35226 | 0.9687 | 138 | - | - | - | 0.5373 | - | **creature_crushed, day_cycle_night** |
| creature_night_giant_chase | 0.8706 | 0.05933 | 0.3922 | 3e-05 | 0.17976 | 3.5673 | 255 | - | - | - | 0.4733 | - | - |
| creature_night_giant_close | 0.8863 | 0.07378 | 0.5608 | 0.00031 | 0.13617 | 3.8966 | 254 | - | - | - | 0.5864 | - | **day_cycle_night** |
| creature_night_hero_chase | 0.8588 | 0.05472 | 0.3961 | 1e-05 | 0.16354 | 3.5274 | 255 | - | - | - | 0.4741 | - | - |
| creature_night_hero_close | 0.8745 | 0.06668 | 0.549 | 0.00028 | 0.08351 | 3.7423 | 254 | - | - | - | 0.5807 | - | **day_cycle_night** |
| creature_night_spider_chase | 0.6902 | 0.00929 | 0.3216 | 1e-05 | 0.13768 | 2.9488 | 255 | - | - | - | 0.4317 | - | - |
| creature_night_spider_close | 0.698 | 0.00794 | 0.3804 | 0.00023 | 0.04112 | 2.6935 | 252 | - | - | - | 0.5068 | - | **day_cycle_night** |
| low_dawn_creature_dist | 0.8549 | 0.05203 | 0.4 | 0.0 | 0.00137 | 15.7281 | 255 | - | 0.1361 | - | - | 1.1788 | - |
| low_dawn_forest_floor | 0.5843 | 0.00047 | 0.4588 | 0.0 | 0.00338 | 1.343 | 222 | - | - | 0.2396 | - | 1.2062 | **tier_parity** |
| low_dawn_madre_spring | 0.6078 | 0.00038 | 0.5216 | 0.0 | 0.0008 | 1.839 | 208 | 0.055 | - | 0.0188 | - | 1.3516 | - |
| low_dawn_riverbank | 0.6588 | 0.00015 | 0.5176 | 0.0 | 0.00055 | 1.0208 | 156 | 0.309 | - | 0.1174 | - | 1.3131 | **tiling, tier_parity** |
| low_dawn_valley_chase | 0.7961 | 0.01767 | 0.5294 | 0.0 | 0.00065 | 2.9505 | 254 | 0.0573 | - | 0.004 | - | 1.0206 | **day_cycle_warmth** |
| low_dawn_valley_east | 0.7686 | 0.01208 | 0.5961 | 0.0 | 0.00047 | 3.1822 | 254 | 0.1718 | - | 0.0206 | - | 1.1679 | - |
| low_dawn_vista_wide | 0.5647 | 3e-05 | 0.502 | 0.0 | 0.0 | 1.6826 | 150 | 0.1032 | - | 0.0004 | - | 1.4245 | - |
| low_dusk_creature_dist | 0.8863 | 0.07275 | 0.4353 | 0.0 | 0.0021 | 17.2582 | 255 | - | 0.1651 | - | - | 1.3035 | - |
| low_dusk_forest_floor | 0.5373 | 0.00104 | 0.4941 | 0.0 | 0.00187 | 1.3661 | 202 | - | - | 0.2791 | - | 1.4552 | **tier_parity** |
| low_dusk_madre_spring | 0.6196 | 0.00092 | 0.3961 | 0.0 | 0.00039 | 1.9275 | 200 | 0.0818 | - | 0.0182 | - | 1.3457 | - |
| low_dusk_riverbank | 0.6863 | 0.0006 | 0.3922 | 0.0 | 0.00023 | 1.0449 | 152 | 0.3394 | - | 0.1087 | - | 1.3104 | **tiling, tier_parity** |
| low_dusk_valley_chase | 0.8 | 0.02017 | 0.5098 | 0.0 | 0.0005 | 3.2656 | 254 | 0.0962 | - | 0.004 | - | 1.0511 | - |
| low_dusk_valley_east | 0.7647 | 0.01213 | 0.5647 | 0.0 | 0.00249 | 3.5982 | 254 | 0.1617 | - | 0.0211 | - | 1.301 | - |
| low_dusk_vista_wide | 0.6078 | 6e-05 | 0.5922 | 0.0 | 2e-05 | 1.8368 | 178 | 0.0864 | - | 0.0002 | - | 1.633 | - |
| low_midday_creature_dist | 0.7373 | 0.01398 | 0.5529 | 0.0 | 0.0 | 19.3131 | 255 | - | 0.3181 | - | - | - | - |
| low_midday_forest_floor | 0.5255 | 0.00013 | 0.6588 | 0.00078 | 1e-05 | 1.6764 | 254 | - | - | 0.318 | - | - | **tier_parity** |
| low_midday_madre_spring | 0.5922 | 0.0006 | 0.6902 | 0.00482 | 0.0 | 2.474 | 254 | 0.0436 | - | 0.0546 | - | - | - |
| low_midday_riverbank | 0.6549 | 0.00017 | 0.6078 | 0.00224 | 3e-05 | 1.5128 | 226 | 0.3113 | - | 0.2475 | - | - | **tiling, tier_parity** |
| low_midday_valley_chase | 0.8235 | 0.02744 | 0.5216 | 0.0 | 0.0 | 3.8782 | 252 | 0.0655 | - | 0.0035 | - | - | - |
| low_midday_valley_east | 0.7725 | 0.00768 | 0.5569 | 0.0 | 0.0 | 4.0388 | 254 | 0.1149 | - | 0.0277 | - | - | - |
| low_midday_vista_wide | 0.502 | 1e-05 | 0.5765 | 0.0 | 0.0 | 1.881 | 150 | 0.0713 | - | 0.0002 | - | - | - |
| low_night_creature_dist | 0.4784 | 0.00401 | 0.2392 | 0.0 | 0.00263 | 9.8635 | 255 | - | 0.0634 | - | 0.4688 | - | **creature_readability** |
| low_night_forest_floor | 0.6588 | 0.0006 | 0.2902 | 0.0 | 0.19485 | 0.3945 | 56 | - | - | 0.0814 | 0.3433 | - | - |
| low_night_madre_spring | 0.5922 | 0.0056 | 0.302 | 0.0 | 0.28251 | 1.2529 | 150 | 0.0788 | - | 0.0057 | 0.2819 | - | - |
| low_night_riverbank | 0.6118 | 3e-05 | 0.2706 | 0.0 | 0.23862 | 0.4208 | 66 | 0.2734 | - | 0.089 | 0.389 | - | - |
| low_night_valley_chase | 0.4392 | 0.00038 | 0.4431 | 0.0 | 0.00053 | 2.9454 | 164 | 0.0738 | - | 0.0011 | 0.8083 | - | **day_cycle_night** |
| low_night_valley_east | 0.5255 | 0.00686 | 0.5059 | 0.0 | 0.07741 | 2.5443 | 172 | 0.1432 | - | 0.0027 | 0.56 | - | **day_cycle_night** |
| low_night_vista_wide | 0.5137 | 0.0 | 0.3686 | 0.0 | 0.05015 | 1.1549 | 136 | 0.0758 | - | 0.0004 | 0.4663 | - | - |
| medium_dawn_creature_dist | 0.9059 | 0.07272 | 0.4118 | 0.0 | 0.00291 | 14.3801 | 255 | - | 0.1069 | - | - | 1.1288 | - |
| medium_dawn_forest_floor | 0.8196 | 0.0183 | 0.7529 | 0.0 | 0.03498 | 2.7701 | 255 | - | - | - | - | 1.2446 | - |
| medium_dawn_madre_spring | 0.6118 | 0.00189 | 0.6118 | 0.0 | 0.00097 | 1.8993 | 218 | 0.0616 | - | - | - | 1.4082 | - |
| medium_dawn_riverbank | 0.6784 | 0.00056 | 0.4275 | 0.0 | 0.00024 | 0.7603 | 146 | 0.2839 | - | - | - | 1.4681 | - |
| medium_dawn_valley_chase | 0.7961 | 0.01811 | 0.5373 | 0.0 | 0.0145 | 2.9279 | 236 | 0.064 | - | - | - | 1.0106 | **day_cycle_warmth** |
| medium_dawn_valley_east | 0.7804 | 0.01704 | 0.6549 | 3e-05 | 0.00419 | 3.2373 | 254 | 0.157 | - | - | - | 1.1609 | - |
| medium_dawn_vista_wide | 0.5647 | 0.00013 | 0.502 | 0.0 | 0.0 | 1.7537 | 160 | 0.1012 | - | - | - | 1.4241 | - |
| medium_dusk_creature_dist | 0.9608 | 0.11159 | 0.4706 | 0.0 | 0.00319 | 16.72 | 255 | - | 0.1423 | - | - | 1.3087 | - |
| medium_dusk_forest_floor | 0.8275 | 0.0281 | 0.6588 | 0.0 | 0.01759 | 2.5889 | 254 | - | - | - | - | 1.3011 | - |
| medium_dusk_madre_spring | 0.6275 | 0.0033 | 0.4824 | 5e-05 | 0.00064 | 1.9973 | 210 | 0.0787 | - | - | - | 1.3979 | - |
| medium_dusk_riverbank | 0.6706 | 0.00063 | 0.4745 | 0.0 | 0.00016 | 1.0068 | 130 | 0.117 | - | - | - | 1.5647 | - |
| medium_dusk_valley_chase | 0.8 | 0.02156 | 0.5176 | 0.0 | 0.00612 | 3.4037 | 254 | 0.0796 | - | - | - | 1.0433 | **day_cycle_warmth** |
| medium_dusk_valley_east | 0.7647 | 0.01385 | 0.5961 | 0.0 | 0.01388 | 3.5818 | 254 | 0.1719 | - | - | - | 1.2976 | - |
| medium_dusk_vista_wide | 0.6078 | 0.00012 | 0.5922 | 0.0 | 4e-05 | 1.8879 | 186 | 0.0864 | - | - | - | 1.6324 | - |
| medium_midday_creature_dist | 0.8275 | 0.04042 | 0.698 | 0.00051 | 0.0 | 25.3848 | 255 | - | 0.3555 | - | - | - | - |
| medium_midday_forest_floor | 0.8039 | 0.01561 | 0.7373 | 0.00015 | 4e-05 | 3.4682 | 255 | - | - | - | - | - | - |
| medium_midday_madre_spring | 0.7137 | 0.01346 | 0.7765 | 0.00476 | 0.0 | 2.7152 | 254 | 0.0442 | - | - | - | - | - |
| medium_midday_riverbank | 0.6588 | 0.0003 | 0.8157 | 0.00315 | 0.00488 | 0.9834 | 202 | 0.234 | - | - | - | - | - |
| medium_midday_valley_chase | 0.8235 | 0.02931 | 0.5294 | 0.00018 | 0.0 | 4.331 | 254 | 0.0606 | - | - | - | - | - |
| medium_midday_valley_east | 0.8078 | 0.02444 | 0.6 | 6e-05 | 0.0 | 4.4832 | 254 | 0.1051 | - | - | - | - | - |
| medium_midday_vista_wide | 0.502 | 0.0001 | 0.5765 | 0.0 | 0.0 | 1.9613 | 162 | 0.0692 | - | - | - | - | - |
| medium_night_creature_dist | 0.549 | 0.00707 | 0.2706 | 0.0 | 0.00457 | 11.054 | 255 | - | 0.0611 | - | 0.4368 | - | **creature_readability** |
| medium_night_forest_floor | 0.851 | 0.0482 | 0.2824 | 0.0 | 0.04087 | 0.5178 | 58 | - | - | - | 0.4271 | - | - |
| medium_night_madre_spring | 0.5373 | 0.01264 | 0.2941 | 0.0 | 0.2692 | 1.2622 | 154 | 0.084 | - | - | 0.304 | - | - |
| medium_night_riverbank | 0.5843 | 0.00164 | 0.149 | 0.0 | 0.29304 | 0.2157 | 46 | 0.0756 | - | - | 0.2974 | - | **flat_light_night** |
| medium_night_valley_chase | 0.4392 | 0.00049 | 0.4431 | 0.0 | 0.00081 | 3.0681 | 170 | 0.0731 | - | - | 0.8067 | - | **day_cycle_night** |
| medium_night_valley_east | 0.4902 | 0.00499 | 0.5059 | 0.0 | 0.06332 | 2.5764 | 178 | 0.1412 | - | - | 0.5859 | - | **day_cycle_night** |
| medium_night_vista_wide | 0.5137 | 0.0 | 0.3647 | 0.0 | 0.05017 | 1.1996 | 142 | 0.0772 | - | - | 0.4654 | - | - |

## Not measurable

- Plastic shine as specular/roughness per material (needs the material parameters, only a glint-fraction proxy is measured)
- Black cartoon outlines (never used; no check)
- Creature skin wet/matte rules (LOOK.md 4): a design rule, not an image statistic
- Frame time is wall clock on software GL under a shared CPU (llvmpipe): informational and only comparable between runs on a similarly loaded machine; it does not show real GPU fps
- Sun direction and terrain light are fixed by the hero look: dawn and dusk differ only by sky/cloud tint and the creature light, so the light-per-time-of-day checks measure what the game does today
- Creature close-ups are on the studio preview stage (CreaturePreview) with the game's day_night light numbers, not inside the island; the game's own terrain bounce and fog are absent
