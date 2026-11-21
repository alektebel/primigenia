# World light (art/world-light, A1 / D-25): baseline vs wl7

Final scorecard: `docs/evidence/look/score/wl7` (rounds: wl1 to wl3 in the first pass, wl4 to wl7 in round 2; intermediate captures were dropped, they are in git history). Compare: `python3 tools/look/compare.py baseline wl7` (improved 299, regressed 207, unchanged 182 over metric x shot; the regressions are the night shots that the baseline passed only because they were not night, plus small drifts). Blind A/B sheet: `docs/evidence/look/world-light-ab.jpg` (+ `_2` .. `_15`, 88 shots at the 4 times of day, left/right hidden), key: `docs/evidence/look/world-light-ab.jpg.key.json`.

## Failing shots per check, baseline to final

Baseline was re-scored with the new night targets (`docs/research/look-targets.json`: `flat_light` and `world_crushed` now apply to dawn/midday/dusk, with `_night` variants `flat_light_night` >= 0.15 and `world_crushed_night` < 0.35; the reason is in the file: the baseline night passed the day targets only because it was blue sky and green grass, not night). Column wl2 is the first-pass result Claude reviewed.

| check | baseline | wl2 | final (wl7) |
|---|---|---|---|
| creature_flat_light | 8/32 | 0/32 | 0/32 |
| creature_crushed | 8/32 | 2/32 | 2/32 |
| bloom | 7/88 | 2/88 | 2/88 |
| noise_creature | 0/32 | 0/32 | 0/32 |
| blur | 0/66 | 0/66 | 0/66 |
| plastic_shine | 6/32 | 6/32 | 6/32 |
| day_cycle_warmth | 39/44 | 4/44 | 7/44 |
| day_cycle_night | 11/22 | 6/22 | 9/22 |
| creature_readability | 2/8 | 2/8 | 2/8 |
| saturation_over | 8/48 | 10/48 | 0/48 |
| saturation_p95 | 6/48 | 11/48 | 0/48 |
| flat_light | 0/36 | 0/36 | 0/36 |
| world_crushed | 0/36 | 0/36 | 0/36 |
| noise_world | 3/48 | 1/48 | 0/48 |
| tiling | 3/40 | 3/40 | 3/40 |
| tier_parity | 8/24 | 6/24 | 6/24 |
| flat_light_night | 0/12 | 1/12 | 0/12 |
| world_crushed_night | 1/12 | 3/12 | 0/12 |

Performance (software GL, informational): low 2770 -> 2630 ms/frame, medium 1447 -> 1479 ms/frame (unchanged within noise; no real GPU fps).

## What changed in round 2
- Night targets split from day (above). Readability checks (day_cycle_night, creature_readability, creature_crushed) are untouched.
- Near ground lifted at night, staying blue-grey: terrain `light()` uses a soft moon-shadow tint at night (`world_light.gdshaderinc`, was the day shadow tint, which crushed everything in shadow), night ambient fill `K_AMBIENT` 0.008 to 0.022/0.030/0.055, moon fill `K_SUN` night 0.45/0.56/0.84 to 0.68/0.82/1.05, a slightly lighter night sky/fog so the sky is not crushed (day_night.gd). Flora gets its own night fill (`EMISSION` from the `ambient_color` global in `flora.gdshader`), so trees are not black silhouettes and the creature stage keeps its wl2 lights (a stronger env ambient made creature night/day and plastic-shine worse: wl4).
- Dawn and dusk chroma: `scene_out` (look.gdshaderinc) calms the chroma of every world material by 20% when the sun is the warm low key (hue kept); crown pigment 18% calmer. saturation_over 8 to 0, saturation_p95 6 to 0.
- Forest floor noise: the noisy surface was the compound-leaf crowns (leaflet pattern shimmering under alpha-to-coverage), not the ground. The leaflet pattern now fades to the solid crown envelope when it is under about 2 px (`flora.gdshader`). medium_midday_forest_floor hf_noise 7.2 to 3.5; noise_world 3 to 0 failing.
- Low-tier parity: not touched (optional, not cheap: the low tier differs in terrain relief and the forest floor shot).

## What remains (not worse than baseline, but still failing)
- day_cycle_night 9/22 (baseline 11): the five creature close-up night shots (0.51 to 0.59, the stage's moon fill) and the grass-heavy `valley_chase` (0.84, because midday there is a dark-green grass scene) and `valley_east` (0.59 to 0.61, baseline 0.58). The night world is now a readable blue-grey moonlit scene, so these ratios cannot all reach 0.5 without crushing the near ground again; the owner may prefer to judge them by eye in the A/B sheet.
- creature_crushed 2 (night beetle chase/close, dark chitin palette, hues cannot shift), creature_readability 2 (night creature_dist 0.05, target 0.10), plastic_shine 6, bloom 2 (creature stage, skin v1), day_cycle_warmth 7 (4 creature chase shots on the stage and the grass-heavy valley_chase dawn/dusk at 0.99 to 1.04), tiling 3 (low riverbank), tier_parity 6 (low forest floor and riverbank).
- `flat_light_night` passes with a small margin (medium_night_riverbank 0.157 against 0.15); the night riverbank is the flattest scene.
- Starting values: all night values above are starting values checked by this scorecard only.
