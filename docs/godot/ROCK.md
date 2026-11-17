# Rock and terrain material (G77 follow-up)

Plan: `docs/godot/PLAN-rock.md`. Branch `g-rock`. The mountain rock no longer reads as smeared vertical streaks: detail is mapped
biplanar (not top-down), baked into two small tileable sheets, lit through the existing toon ramps, and shaped by generator
relief cues. No palette C hue was added. Hardware numbers are still open (see Open items).

## What changed

| Step | Change | Files |
|---|---|---|
| 1 | Biplanar/triplanar mapping include and the stretch test | `shaders/rock_mapping.gdshaderinc`, `tests/rock_stretch_test.gd` |
| 2 | Baked `rock_detail.png` (512) and `scree_detail.png` (256): normal as -grad h, height, crack occlusion; deterministic, tileable | `tools/bake_rock_detail.gd`, `textures/` |
| 3 | Rock and scree colour from the sheets (mineral 263 m, macro 41 m, meso 9.7 m, scree 6.1 m); the xz jitter and the double `rock_color` are gone | `shaders/rock.gdshaderinc`, `terrain_body.gdshaderinc` |
| 4 | Detail normals (UDN) through the unchanged toon ramps, widened by `fwidth` | same |
| 5 | Strata: generator-aligned cap rock (period 47 m) and cosmetic bedding (7.3 m, about 14 % value) | same |
| 6 | `relief` map from the extension (signed curvature fine/broad, sediment): gullies, ridges, wet streaks, scree fans | `extension/cpore_terrain.cpp`, `terrain_data.gd` (`RENDER_PREP_VERSION` 2), cache, chunks |
| 7 | Height blend of materials (crisp boundaries) and snow that rests on flat facets only | `rock.gdshaderinc` (`rock_blend`) |
| 8 | Quality tiers `terrain_low/medium/high.gdshader` over `terrain_body.gdshaderinc`; `quality: "auto"` (default) resolves from the adapter | `terrain_chunks.gd`, `game.gd` |
| 9 | Optional baked sun shadows, **off by default** (`Game.settings.sun_shadows`) | `CporeTerrain.sun_visibility`, `island.gd`, `grass.gdshader` |

## Evidence (seed 1, llvmpipe, 1280x720; metrics by `tests/rock_metrics.gd`)

* **Stretch (step 1, `make godot-rock-stretch-test`, all three tiers).** Texel density per surface metre on the 60 degree cone,
  azimuths 0,45..315. Medium: downslope 0.87 0.87 0.87 0.87 0.87 0.87 0.87 0.87; contour 0.99 0.80 0.99 0.85 0.99 0.81 0.99 0.85;
  legacy planar xz 0.50 0.50 0.50 0.50 0.50 0.50 0.50 0.50 (the old mapping stretched 2x); flat ring 1.00 1.01 1.00 1.00 1.00 0.99 1.00 1.00. Low is identical;
  High (triplanar, read 7 degrees off the exact 45 degree ties) also passes. Files: `stretch-*.json`.
* **Streaks (step 3).** Autocorrelation length ratio vertical/horizontal of the high-passed luminance, 64x64 crop: cliff_lit 3.10 ->
  0.57, cliff_shade 2.70 -> 0.83 (limit 1.4). Before/after frames: `before/`, `after-3` .. `after-7`.
* **Far view palette.** Mean rock RGB against `before/far.png` on the rock mask: step 3 +3.0/+1.9/+0.2, step 4 +3.3/+2.1/+0.4,
  step 5 +3.3/+2.2/+0.4, step 6 +2.6/+2.8/+2.9, step 7 +1.7/+2.2/+2.9 (limit 4/255).
* **Sign test (step 4).** The ridge's up-facing side shades as the geometry predicts at all 8 azimuths (see the note on the plan below).
* **Flicker (step 4).** 0.04 % of rock pixels change ramp band beyond a 5 px shift after a 0.25 m camera move (limit 3 %).
* **Strata (step 5).** Mode 3 agrees with a GDScript replica of the cap-rock phase at 660 of 660 off-edge points
  (`strata_mode3.png`); bedding visible on `mid` (`after-5/strata_mid_compare.png`).
* **Relief (step 6).** Tests in `test_terrain.gd` (size, flat 128, gully > 128, ridge < 128, sediment monotone) and `test_cache.gd`
  (old render-prep entries miss cleanly). Rock pixels on convex relief are 10-14 % lighter than flat ones, concave 6-9 % darker.
* **Snow and blends (step 7).** Snow pixels on faces steeper than 55 degrees: far 9.6 % -> 0 %, mid 59.4 % -> 0 %. Rock/scree
  transition width in a top-down frame 2.44 m -> 0.41 m (`after-7/topdown_mode10/11.png`). Visible snow area on the peaks drops
  clearly (see Open items).
* **Tiers (step 8).** llvmpipe mean frame ms new/before (`after-8/bench-*.json`; before: `bench-before-llvmpipe.json`, 40 frames,
  not a GPU number): Low 1.05 / 1.06 / 1.08 / 1.07 (chase, mid, far, cliff_lit), Medium 1.04 / 1.01 / 1.07 / 1.06. Under 1.3, but Low is
  not strictly <= before. The first High run under load was discarded as noise; High is informative only.
  Play test green with `QUALITY=low|medium|high` (178 checks each).
* **Shadows (step 9).** `shadows-ab/{view}.png` against `{view}_shadows.png` and `ab_mid.png`, `ab_far.png`. Bake: 187 ms.

## Tests and commands

* `make godot-test` (M0 suite, includes `test_rock_detail.gd`, relief and sun tests): 449 checks, 0 failures.
* `make godot-rock-stretch-test` (3 tiers x 42 checks), `make godot-render-test` (14), `make godot-play-test [QUALITY=x]` (178).
* `make godot-rock-evidence ROCK_OUT=dir [ROCK_VIEWS=..] [ROCK_MASKS=masks,m7,m9,cells,flicker,topdown,shadows]`, `make godot-rock-bench-sw TIER=low|medium|high`.

## New constants for owner approval

All in `rock.gdshaderinc`, mirrored in `look.gd` and checked by `test_look.gd`: tile sizes (263, 41, 9.7, 2.3, 6.1 m), fades
(meso 120-380, micro 25-70, scree 150-450), normal strengths (0.55, 0.45, 0.35, scree 0.5), mineral blur/gain/bias (14, 2.2, -0.10),
plate value 0.22, AO steps 0.22/0.16/0.62, ridge light 0.07, rim 0.025, gully 0.64, wet streak 0.72, fan light 1.08,
bedding 7.3 m and 0.14, cap rock mix 0.35, snow gates (detail 0.55-0.75, macro 0.54-0.58, dust 0.8), `ROCK_MAX` 1.09 (1.2 x lit snow).
Rock still reads greyer than the hero's warm cliffs (M0 note); not changed here.

## Deviations from the plan

* Debug mode 3 is the strata view and mode 9 the relief channels (mode 3 was planned as relief). Modes 6/7 are masks, 8 ramp bands, 10/11 weights.
* Sign test: the plan's "up-facing side brighter at all azimuths" is false for faces turned toward the low sun (tilting up moves the
  normal away from it). The test checks the sign of the analytic derivative instead, at every azimuth where it exceeds 0.08.
* Mineral patches come from the macro sheet read 14 mips up (blurred) with gain/bias, not from a separate texture.
* Bedding phase wobble is additive (plus or minus half a band), not +-25 % of the period (that swirls at altitude); the 0.3 dip term is the generator's dip.
* Gullies: `max(cavity, concave relief)` instead of replacing the cavity factor, to keep the far view. Ridge light and rim were lowered (0.18/0.08 -> 0.07/0.025) and the mineral bias set to -0.10 to hold the far view within 4/255.
* Snow gate also requires the macro face to be flatter than about 55 degrees; with the detail normal alone, plate tops on cliffs still took snow.
* Fans: crossfade between two fixed scree tiles (6.1 and 2.65 m) instead of two pebble channels.
* Triplanar weights use exponent 8; the High-tier stretch test reads the dominant axis.
* Step 9 is a separate `CporeTerrain.sun_visibility(data, sun)` (not part of `surface_maps`, not cached, 0.19 s) so the cache version is unaffected; the switch only scales `relief.A`.
* The optional `normal_tex` of step 8 was not built. The plan's "strata visible >= 3 peaks" luminance metric could not discriminate (patch shading dominates); bands were judged on the compare image and by the cap-rock replica test.
* The chase-frame meadow check (2/255) could not be measured: two runs of the same code differ by 4-5/255 (the meadow wave uses TIME). Meadow cells never enter the rock path, so they are unchanged by construction.

## Open items for the owner

* **Run on the Radeon 860M:** `make godot-rock-bench TIER=medium` (also `TIER=low`, and with `DRI_PRIME=1` `TIER=high`), then paste the
  `docs/evidence/godot/rock/bench-*.json`. The Section 6 budget (Low +0.0 ms, Medium <= +1.0 ms) is not verified.
* Choose on sun shadows: compare `shadows-ab/`; enable with `Game.settings.sun_shadows = true`.
* Snow amount: peaks now carry much less snow (facets flatter than 55 degrees only). Loosen `SNOW_MACRO_*` if wanted.
* Approve the constants above, and DESIGN.md entry afterwards.
* Verify the sin-hash banding suspicion (plan item 8) on the real GPU; strata use a sin-free hash.
