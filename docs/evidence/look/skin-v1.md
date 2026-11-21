# Skin v1 (art/skin-v1): baseline vs skin2

Change: matte dry skin (weak specular fading at grazing angles, clearcoat mostly on wet zones), ground bounce and sky floor in the skin's own colour, night moonlight fill and edge rim (shader global `moon_k`, set by day_night.gd), fill boosted with view distance, same for keratin. Hues untouched (all added light is sk/cA coloured); CPORE_REALISM=0 unchanged. Lab prototype: variant 2 in web/lookdev, captures in docs/evidence/look/lab/. Official run: `docs/evidence/look/score/skin2` (compare: `python3 tools/look/compare.py baseline skin2`). Blind A/B sheet: /home/diego/Desarrollo/cpore-wt/_agent/look-ab/skin2.jpg (+ .key.json).

## Creature shots, min / mean / max over the shots of each kind

| metric | baseline | skin2 |
|---|---|---|
| glint fraction (midday) | 0.004 / 0.012 / 0.023 | 0.003 / 0.005 / 0.009 |
| crush (night) | 0.586 / 0.699 / 0.842 | 0.188 / 0.308 / 0.607 |
| contrast (night) | 0.118 / 0.121 / 0.129 | 0.278 / 0.355 / 0.459 |
| night/midday lum (night) | 0.108 / 0.126 / 0.137 | 0.364 / 0.412 / 0.471 |
| warmth R/B vs midday (dawn+dusk) | 0.886 / 0.908 / 0.946 | 0.961 / 0.980 / 1.007 |

## Targets
| target | baseline | skin2 | verdict |
|---|---|---|---|
| plastic_shine < 0.01 | 6 failing, worst 0.0232 | 0 failing, worst 0.009 | PASS |
| creature_crushed < 0.25 (night) | 8 failing, worst 0.84 | 5 failing: beetle chase/close (0.40, 0.61, dark chitin palette, hues cannot shift) and giant/hero close at 0.25-0.29 | partly |
| creature_flat_light >= 0.3 | 8 failing | 2 failing (night spider chase 0.278, beetle close) | mostly |
| day_cycle_night (night/midday lum < 0.5) | creature 0.11-0.14 | creature 0.36-0.47, no creature shot fails; the 11 world failures are unchanged | PASS |
| day_cycle_warmth > 1.05 | creatures 0.886-0.946 | 0.961-1.007 | still FAIL |
| creature_readability night/dist >= 0.10 | low 0.0719, medium 0.0709 | low 0.0619, medium 0.0565 | FAIL, slightly worse |

## Why not all targets pass
- Warmth: what the skin controls (blue-neutral fill in skin colour) lifted R/B by about 0.07. The rest is the capture light (blue ambient, sun energy cut at k=0.5 in day_night.gd). Follow-up in day_night/look.gd, not in this branch.
- Readability: dist_contrast is |mean(creature mask) - mean(ring)|. The mask (pixels that change when the creature is hidden, 2.9k px) is mostly the creature's shadow and nest, not skin: creature mean 19 -> 23, ring 37.5. A brighter skin moves the mean towards the ring, so the metric falls. Passing needs the mask mean at least 25 levels from the ring, which means a glowing far creature (against LOOK.md 5). Recommend changing the check to a creature-only mask (hidden-creature diff with shadows off) before judging skin on it. Visually the far creature now reads more clearly against the dark nest.
- Beetle crush: albedo is near black by the player's palette.

## Regressions (compare baseline skin2, 105 metric x shot)
Creature shots only; world shots do not move (world shaders untouched). Creature: sat_p95 / sat_over up (the added coloured light), sharp_p99 down 5-10%, crush up at dawn/dusk giant/hero close (0.10 -> 0.15, under 0.25), night/dist hf_noise 3.1 -> 4.9 (rim on a few-pixel creature). Dawn creature_dist sat_over 0.101 -> 0.106.
