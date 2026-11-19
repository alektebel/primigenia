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

## Terrain look update (terrain/look-hydro)

`ground_normal` (terrain_maps.gdshaderinc) is now a Catmull-Rom bicubic gradient of the height texels instead of differences of the triangle surface; the geometry (`ground_tri`, `TerrainData.ground`)
is unchanged. The vertex shader geomorphs each LOD onto the next lattice (`lod_step`, `morph_range` uniforms) and the LOD ranges are 300/700/1500/3200 m. The terrain light is multiplied by the cloud shadow
(docs/godot/CLOUDS.md). See docs/TERRAIN.md "Version 4" for the diagnosis.

## Terrain v5 (visual erosion)

Full description in docs/TERRAIN.md "Version 5". What changes for the rock material:

* The terrain mesh samples a 4096 visual heightfield (0.88 m) bounded against the sim; the shading normal is the visual field's near the camera.
* New erosion maps (`vmaps_tex`, `erosion_maps()` in terrain_body.gdshaderinc) feed the material: flow -> wet streaks (`wet_rock`, the existing ROCK_WET_* path), deposition -> sediment fans
  (`fan`), talus apron -> rock to scree on slopes with normal y above 0.55 to 0.7, exposure -> clean rock and no turf on convex ridges, plus a sharper `rl.r` relief cue.
  Strata (cap rock, bedding) and snow rules are untouched: they run on world position and the gated detail normal. The maps fade between 500 and 1500 m.
* Class borders: the material lookup is warped by +-2.5 m of value noise (`warp`), so the 3.5 m classification steps are not straight.
* Rock sheet mapping is domain-warped (`ROCK_WARP` 1.0 m plus a 0.35 m octave at 2.7x): the Voronoi plates no longer form a regular honeycomb. Same warp at all distances (no swimming).
* Eroded fBm (`fbm_tilt`, `FBM_*`): normal-only, 22 to 85 m, tiers medium and high.
* Debug modes: 12 erosion maps (R flow, G deposition, B apron), 13 exposure.
* New constants for owner approval: EROSION_FADE 500/1500, FBM_AMP 0.4, FBM_WAVELENGTH 2.4, FBM 22/85, ROCK_WARP 1.0, warp 5 m of the class lookup (`warp * 5.0`).

Tier note: the Voronoi plate sheet (rock_detail.png) is still the dominant read at 2 to 10 m; replacing it with a less cellular sheet is the next visual step (texture art, not geometry).

## Photographic materials (terrain/rock-textures)

The Voronoi plate sheets (`rock_detail.png`, `scree_detail.png`: the "crocodile skin" at 2 to 10 m) are gone. Rock, scree, volcanic rock, bare soil, sand and river banks now read eight CC0
photographic materials from ambientCG (`godot/game/textures/CREDITS.md`: names, URLs, licence). The C sim, the geometry and the v5 visual heightfield are untouched; this is shading only.

**Assets** (`textures/photo/`, baked by `tools/bake_photo_textures.py` from the 1K-JPG packs): two 4x2 atlases of 1024 tiles, imported as `Texture2DArray` (8 layers, VRAM compressed,
about 5.6 MB of video memory each with mipmaps, 10.7 MB together; the repository holds 9.7 MB of source). `rock_albedo.jpg` is sRGB colour, `rock_pack.jpg` is R,G = tangent normal xy (OpenGL),
B = height. A sampler array means two texture units instead of sixteen. Layers: 0 andesite (Rock048), 1 bedded strata (Rock022), 2 basalt (Rock050), 3 tuff (Rock061), 4 scree gravel (Gravel040),
5 talus debris (Ground108), 6 volcanic soil (Ground039), 7 sediment (Ground079S).

**Shader** (`shaders/rock_photo.gdshaderinc`, included by `rock.gdshaderinc`; `rock_sample`, `rock_shade`, `scree_sample`, `scree_shade` and `rock_blend` were rewritten on it):

* *Mapping.* The existing rock mapping: biplanar (Low and Medium) or triplanar (High) on the steep macro normal, the planar top projection on flat ground (the weights pass to the top axis as the face flattens).
  `textureGrad` with the continuous world position, so there is no mip seam; anisotropic filtering in every tier (the ground is nearly always seen at a grazing angle and trilinear smeared it into streaks; the chunk
  node sets the viewport to 2x in Medium, 8x in High; the grazing blur is the one real cost, see Cost). The domain warp of the rock mapping is removed: it stretched photographs (it only hid the plate pattern).
* *No visible repetition.* Each fetch blends two random shifts of the sheet by a low-frequency noise (Quilez's "virtual pattern" without the contrast term: the blend band is about a quarter of the surface, so
  elsewhere one tap of each sheet is enough); two scales (the close tile of 1 to 3 m and a macro tile 7x larger, so no feature repeats inside 7 to 20 m); the close scale fades out between 30 and 110 m; the macro scale
  fades to "no variation" between 250 and 900 m, beyond which no fetch is made (a macro texel at 1 km reads as grain, and the far view keeps its palette). Fine-grained sheets (scree, talus, soil, sediment) have the close
  scale only. Broad mineral patches, strata and tuff patches come from procedural noise and the generator's own cap-rock phase, not from a texture. The sheets' heights decide material borders (`rock_blend`) only inside 120 to 450 m.
* *Palette stays.* A texel is divided by its sheet's mean (`PH_MEAN_*`, kept equal to the atlas means by `test_photo.gd`) and multiplies the island's palette colour (R0/R1/R2, SCREE, SAND, VOLCANIC_*): the photographs
  supply flecks, cracks, grain and relief, the palette supplies the colour mood (mean colour of the far, valley, ridge, coast and mid crops against v5: at most 4.3/255, far within 1/255). `PH_CHROMA` 0.75 keeps most of the texel's hue variation.
* *Normals.* Each projection's tangent normal is turned into a world tilt and added to the face's own tangent plane (the UDN/whiteout combination in the macro normal's frame; the v5 smooth normal stays the base) and
  the eroded-fBm tilt stays on top. `rock_stretch_test.gd` drives a synthetic ridge through `ph_synth` and checks the sign at all 8 azimuths (it passes at all three tiers; the plan's up/down-facing prediction holds).
* *Height blend.* Rock height is the photograph's, scree's is the gravel's: `rock_blend` (rock, scree, steep meadow, sand, snow weights) picks by `weight + 0.5 height` as before, so rock pokes through scree and gravel
  fills cracks. Cavity occlusion is read from the same height (`ph_ao`).
* *Erosion maps.* Unchanged inputs, new readers: gully flow -> streak mask (procedural noise stretched down the face, no sheet) and darker gully floors; deposition fans -> talus sheet (coarse debris, warm) crossfaded over the
  gravel; talus apron -> scree; exposure -> clean rock; steep slopes with `steep` < 1 and a gentle face show bare soil (`PH_SOIL_SHARE`) before rock; banks (surface wetness 0.22 to 0.5) are wet gravel and silt patches.
* *Light.* The toon steps of the rock ramp are mostly replaced by a smooth curve with the same floor (0.36) and ceiling (1.4): `PH_SOFT` 0.75. Water, snow and grass keep their toon ramps.

**Tiers.** Low: the macro scale only (no close scale, no fBm; scree, soil, sand and banks are flat palette colour). Medium: both scales, biplanar, 2x anisotropy. High: triplanar, 8x anisotropy.
Quality knobs without recompiling: uniforms `ph_stochastic` (1 = two shifts, 0 = one tap) and `ph_near` (0 = macro scale only), `fbm_gain`; `BENCH_SET`, `BENCH_ANISO`, `BENCH_VIEWS`, `LOOK_SET`, `LOOK_ANISO` env vars in the benchmark and frame scripts.

**Tests.** `test_photo.gd` (in `make godot-test`: 584 checks, 0 failures): atlas import, layer count, `PH_MEAN_*` against the atlas, credits and URLs, size budget. `make godot-rock-stretch-test`: 3 tiers x 42 checks,
0 failures; it was already failing on terrain v5 (its synthetic cone had no visual heightfield, so nothing rendered), now repaired in `cone_entry`.

**Cost.** Video memory: two S3TC arrays, 5.6 MB each, 11.2 MB (v5 sheets: about 1.8 MB), so +9.4 MB. Fetches per rock fragment at Medium: close scale about 1.3 to 2.6 per projection and sheet (one tap of albedo and pack where one shift is alone,
two inside the blend band), macro scale the same inside 900 m, one to two projections, one sheet on andesite, two or three where strata or tuff are mixed; fine sheets only inside 110 m. llvmpipe is software and decodes S3TC
per texel, so it overstates texture cost; read it as a ratio. llvmpipe medium tier, 1280x720, interleaved runs of v5 (this branch's parent) and this branch, mean frame ms v5 -> photo (ratio): chase 1001 -> 1270 (1.27), mid 480 -> 821 (1.71),
far 704 -> 688 (0.98), cliff_lit 547 -> 1216 (2.22) (`terrain-photo/bench-summary.json`). The first version (two taps everywhere, 4x anisotropy, macro to 1500 m) was 3 to 4x on the near views; the largest wins were the blend-band-only second tap (-55 %
with one tap), 2x instead of 4x anisotropy in Medium (aniso off alone was -42 %), no macro scale on fine sheets and the 900 m macro cut. The Radeon 860M and RTX figures are open:
`make godot-terrain-bench TIER=medium|high` (windowed, writes `docs/evidence/godot/terrain-photo/bench-*.json`; `make godot-terrain-bench-sw` is the llvmpipe variant). If the iGPU is too slow: `ph_near` 0, `ph_stochastic` 0, anisotropy 1x, `PH_NEAR_FAR`.

**Evidence.** `docs/evidence/godot/terrain-photo/` (`make godot-terrain-look`; the v5 frames in `terrain-v5/after` are the "before"): `sheet_1.jpg`, `sheet_2.jpg`, `sheet_closeups.jpg` (before | after), `after/` and `before/` frames of the 12 v5 viewpoints plus `mid` and `close_cave` (`close_cave` is the widest cave record's site seen from 16 m: the generator's caves are records plus a shallow notch in the heightfield, there is no lava-tube geometry, so the frame shows its rock and scree rather than an opening; deferred).
Tuning without editing shaders: `LOOK_SET="fbm_gain=0.5" make godot-terrain-look`.

**New constants for owner approval** (all in `rock_photo.gdshaderinc`; the old plate-sheet constants in `rock.gdshaderinc` are no longer read and are kept only so `test_look.gd` stays green until retired): tiles 1.7/2.4/2.0/3.0/1.0/1.4/1.2/1.3 m,
macro factor 7, close fade 30 to 110 m, macro fade 250 to 900 m, height-blend fade 120 to 450 m, normal strengths 0.6 (close) and 0.5 (macro), `PH_CHROMA` 0.75, ratio clamp 0.3 to 2.4, `PH_AO_DEPTH` 0.4, `PH_SOFT` 0.75, `PH_SOIL_SHARE` 0.6, `PH_SOIL_PAL`, `PH_BANK_*`.
