# Plan: rock and terrain material (branch g-rock)

Owner feedback (G77, first Godot playtest): *"it seems that the shaders or texture of the mountain is not quite right,
what can we do to fix it?"* The rock looks like smeared vertical streaks stretched down steep faces. It has no fine
detail up close, and the strata and cliffs barely read. The far view is acceptable.

This is a plan for the implementer (Claude Sonnet 5.5). The planner changed no code. Every step below is small,
names its files and has an acceptance check. Keep the rules in `_agent/briefs/common.md` and `godot-common.md`:
software GL only for renders, `timeout` around every Godot run, `--check-only` first, `nice -n 10`, few renders,
and commit after each step.

Scope: `godot/game/shaders/`, `godot/game/island/` (terrain_data, terrain_chunks, look), `godot/game/textures/` (new),
`godot/game/tools/` (new), `godot/game/tests/`, the presentation-only `surface_maps()` in `godot/extension/cpore_terrain.cpp`,
`Makefile` targets, `docs/godot/ROCK.md` and `docs/evidence/godot/rock/`. **Never touch `core/`** (W20 keeps the
generator as it is) or `art/reference/`.

---

## 1. Diagnosis

### Measured facts (seed 1, N=1024, cell 3.516 m, from `build/terrain_cli dump`)

| Material | Share of land | Median slope | Slope >60° | Mean planar stretch 1/cos(slope) | p90 stretch |
|---|---:|---:|---:|---:|---:|
| meadow | 22.7% | 23.7° | 0% | 1.13 | 1.32 |
| **rock** | **28.8%** | **59.3°** | **44%** | **2.01** | **2.40** |
| **scree** | **44.6%** | 45.4° | 0% | 1.41 | 1.65 |
| snow | 1.5% | 45.7° | 7% | 1.48 | 1.92 |
| sand | 2.4% | 15.1° | 0% | 1.05 | 1.13 |

* Rock lies on 60° faces. Its distance from the valley centre is p10 650 m, median 1000 m, p90 1300 m. At 1080p with the
  48° vertical FOV, one pixel covers 0.54 m at 650 m and 0.82 m at 1000 m. **From where the player stands, the detail that can
  show is 2 to 40 m in size, not centimetres.**
* Scree covers 45% of the land, and today it is one flat colour.
* Only 2.4% of rock cells lie above 342 m, where the generator's resistant strata (W16) exist. The strata the player sees
  must therefore be mostly a shading feature, aligned with the generator where it has real steps.
* Rock curvature is roughly half concave (47%) and half convex (53%), but the cavity map only encodes the concave half.

### Causes in the current shader

1. **Planar (top-down) projection of all rock detail.** `rock_color()` in `godot/game/shaders/land.gdshaderinc:139-150`
   samples every noise on `xz`:
   * `grain` at 0.17/m (l.140);
   * `mineral` at 0.023/m (l.141), which picks the grey `R0` against the tan `R1`;
   * `erosion` at 0.081/m (l.142);
   * the strata mask and frequency (l.143);
   * the fine term (l.147), whose only height input is `wp.y * 0.04`.

   On a 60° face, one metre of horizontal `xz` spans 2 m of surface, so every feature stretches 2.0x down the slope
   (2.4x at p90). Long features lie down the fall line, and in `chase.png` they read as beige/grey streaks.
   `terrain.gdshader:26` jitters the material boundaries in `xz` only, which smears them the same way.
2. **The lighting normal is smooth at 7 m and is the only relief input.** `ground_normal()`
   (`terrain_maps.gdshaderinc:124-128`) takes central differences over ±1 cell (a 7 m baseline) of the triangle surface. No
   texture or noise perturbs it. Under the low sun (`SUN_DIR.y = 0.28`, about 16° of elevation), the toon steps of
   `rock_light` (`land.gdshaderinc:144`, `terrain.gdshader:37`) and the `ROCK_SHADE`/`ROCK_LIT` tint (l.148) cut long,
   smooth blue-and-tan bands that follow the gully walls downhill. That is the second source of "vertical streaks": real
   relief, but with nothing below 7 m to break it into facets.
3. **No detail below about 1.6 m, and none that survives distance.** The finest term is value noise at 0.63/m (l.147).
   Nothing is mip-filtered, so at 500-1000 m the 0.17 and 0.63/m noises are sub-pixel. They alias and shimmer in motion
   instead of adding structure, and at the scale that matters (2-40 m) there is only `erosion` and `mineral`, both stretched.
4. **The strata cannot read.** In `land.gdshaderinc:143,147`, `sin(wp.y * (0.075..0.11))` has a period of 57-84 m and an
   amplitude of **±4.5%** of value (`strata * 0.045`), which disappears after ACES. A noise mask (`smoothstep(.4,.72,…)`)
   removes it from about half the faces. The phase adds `erosion*6 + mineral*8`, which shift in `xz`. The bands bear no
   relation to the generator's hard layers (`core/src/terrain.c:641-647`: period 47 m, dipping by `+.025x −.018y`, above
   342 m, which leave the real steps).
5. **Concave cavity only, and the sediment is unused.** `surface_maps()` (`godot/extension/cpore_terrain.cpp:237-243`)
   keeps `max(0, laplacian)`, so ridges get no signal (no "ridges catch light"). `sediment` is generated and cached
   (`cpore_terrain.cpp:106,131`, `terrain_cache.gd:33`) but never reaches shading, so scree fans and deposits are invisible.
   Scree is `mix(rock_c, SCREE*…, 0.85)` (`terrain.gdshader:38`): flat colour on 45% of the land.
6. **Snow sits on steep faces.** `terrain.gdshader:41,46` uses the raw `w[5]`. The classifier marks snow up to a slope of 2
   (63°) (`terrain.c:1269`), so snow is painted onto cliffs and stretched like the rock. The hero gates snow with
   `smoothstep(.48,.80,gn.y)` (`tools/hero/build_hero.py:404`).
7. **Material boundaries are 3.5 m bilinear id blends.** `material_weights()` (`terrain_maps.gdshaderinc:145-158`) on a
   `filter_nearest` id map gives soft, cell-shaped transitions. On 60° faces they are 7 m tall gradients. Nothing (rock
   poking through scree, scree filling cracks) makes them crisp.
8. *(Suspected, verify on the 860M.)* `landHash()` (`land.gdshaderinc:88-90`) is `fract(sin(dot(p, (127.1, 311.7))) * 43758.5)`.
   At `xz*0.63`, the sin argument reaches about 3.5e5 rad, where fp32 `sin` precision differs between GPUs. The AMD driver
   and llvmpipe may draw different (banded) noise, so the owner may see something worse than the evidence.

Why the approved hero got away with it: the hero has the same planar rock (`build_hero.py:390-400`), but its cliffs are
smaller (snow line 120-145 m against 437 m peaks here), seen from one fixed view, and judged as a still image. The palette,
tints, ramp and cavity factor are right and stay. The projection and the structure are what must change at this scale.

Cost note: `rock_color()` is evaluated twice per pixel (rock and volcanic, `terrain.gdshader:36,39`), even though W20 turns
the volcano off. `ground_normal()` costs 16 `texelFetch`. There is budget to recover.

---

## 2. Mapping: biplanar for rock, scree and cliffs

**Choice: biplanar mapping** (Quilez 2020), meaning 2 samples per layer: the major and median axes of |n|, with sharp
weights. It costs two thirds of triplanar and has no visible difference at k=8. **Triplanar is the High tier only.**

Conventions, written once in `rock_mapping.gdshaderinc`:

* Projections: x uses `uv = (p.z, -p.y)`, y uses `(p.x, p.z)`, z uses `(p.x, -p.y)`. In both side projections, v points
  down in the image and up in the world, so the texture's vertical axis is the world vertical. Layered features baked
  horizontally in the texture are horizontal on every cliff.
* Weights: `w = clamp((|n_major|, |n_median|) − 0.5773, 0, 1) / (1 − 0.5773)`, then `w = pow(w, 8)`, normalised. They are
  computed from the **macro normal** `gn`, never from the detail normal, so the weights do not flicker.
* Sampling: use `textureGrad(tex, uv, dFdx(uvk), dFdy(uvk))`. Each projection's derivatives come from the continuous
  world position, so axis switches leave no mip seam.
* Per-layer tile sizes are non-integer ratios, to break tiling (section 3).

**Expected texel density ratio** (surface texels per metre on a 60° slope against flat; computed analytically, to be
measured in step 1):

| Mapping | Downslope (the visible stretch) | Along the contour | Area |
|---|---|---|---|
| current planar xz | **0.50** at every azimuth | 1.00 | 0.50 |
| biplanar/triplanar, dominant axis | **0.87-0.94** (mean 0.89) | min 0.71 at 45° azimuth, mean 0.90 | mean 0.80 |

Triplanar cannot reach exactly 1 at diagonal azimuths. The worst case is √2/2 along the contour at a 45° azimuth, where
a feature is 1.4x wider than tall. That is mild and unlike the current 2x vertical smear. The acceptance bands in step 1
use these numbers.

---

## 3. Detail: procedural, baked into two small tileable textures (no downloads)

**Choice: procedural detail, baked once by a committed tool into tileable PNGs.** No CC0 photo textures.

* Photo rock (ambientCG, Poly Haven) carries centimetre detail and photographic lighting. Our rock is seen at 300-1300 m,
  where the useful structure is 2-40 m. Photo textures would have to be stripped of colour, re-graded and posterized anyway,
  and their micro detail aliases at these distances.
* A baked texture costs one filtered fetch per sample and gets distance filtering from its mipmaps. Per-pixel procedural
  noise would cost more ALU on the iGPU than the current shader does, with no mip filtering.
* No licences, no assets/credits bookkeeping, deterministic and reproducible from code. Every pixel of colour still comes
  from palette C constants.

### Textures

**`godot/game/textures/rock_detail.png`**: 512², RGBA8, lossless, mipmaps on.

| Channel | Content |
|---|---|
| R, G | Detail normal as `−∇h` in (u, v), encoded `0.5 + 0.5·d` with v up |
| B | Height (0..1) |
| A | Crack/cavity occlusion (1 = open, 0 = deep crack) |

The content is built for side faces (u horizontal, v vertical):

* blocky plates from periodic Voronoi (F2−F1), whose cell edges become cracks;
* horizontal bedding, an anisotropic fbm with periods of 3 in u and 14 in v;
* a little grain.

The height is `0.55·plates + 0.30·bedding + 0.15·grain − 0.35·cracks`. Normals come from a wrapped Sobel filter of the
height, and AO from the cracks and the difference between the height and a blurred copy of it.

**`godot/game/textures/scree_detail.png`**: 256², RGBA8, same layout. Rounded pebbles and stones from periodic Voronoi
F1 at two sizes, with sand-filled gaps (low height, A darker).

The tool is **`godot/game/tools/bake_rock_detail.gd`**, a headless `SceneTree` script. It writes its own periodic value
noise and Voronoi: the lattice hash takes `i mod P`, so the output is exactly tileable without FastNoiseLite's seamless
mode, and the result is deterministic. It writes the two PNGs, their `.import` files (mipmaps on, lossless, **not** imported
as a normal map, because the channels are packed) and a preview sheet `docs/evidence/godot/rock/detail_sheet.png`.

### Scales, as world metres per tile

| Layer | Tile | What it shows | Visible range | Tiers |
|---|---|---|---|---|
| mineral (B of rock_detail) | 263 m | Large grey/tan mineral patches (replaces the stretched `mineral` noise) | everywhere | all |
| macro (rock_detail) | 41 m | 5-15 m plates, crack lines and bedding: what the player sees on the ring of mountains | to about 2 km (mips) | all |
| meso (rock_detail) | 9.7 m | 1-4 m blocks and cracks | fades over 120 → 380 m (Medium), 200 → 500 m (High) | Medium, High |
| micro (rock_detail) | 2.3 m | Close climbing detail (future W3 ledges) | fades over 25 → 70 m | High |
| scree (scree_detail) | 6.1 m | Pebble breakup and the edges of fans | fades over 150 → 450 m | Medium, High (Low: macro only) |

To break tiling, the macro layer's u is offset by `0.37 × mineral` (one more mix, no fetch). The ratios 263 : 41 : 9.7 : 2.3
are not integers. A fade means the shader **skips the fetch** past the end distance (a coherent branch on distance).

### Toon and palette C conversion (no photographic colour ever)

* **Albedo.** The base stays the hero's `mix(R0, R1, smoothstep(.25,.78, mineral))`, then `mix(…, R2, erosion*0.4)`.
  `mineral` and `erosion` now come from biplanar samples of B at 263 m and 41 m instead of `xz` noise. Same constants,
  same smoothsteps, no new hues.
* **Occlusion, posterized to 3 levels like `landRamp`.**
  `ao = 1 − 0.22·smoothstep(.40,.50, 1−A) − 0.16·smoothstep(.72,.80, 1−A)`, then
  `rock = mix(rock, rock * ROCK_SHADE * 0.62, 1−ao)`. Cracks are cool (palette C's cool shade), never black.
* **Height highlights.** `rock *= 1 + 0.10·smoothstep(.62,.70,B)·lit`, where `lit` is the lit mask from the ramp. Raised
  plate tops catch warm light, tinted toward `ROCK_LIT`.
* **The normal goes through the existing ramp** (section 5), so detail shows as crisp light/shade facets: the BotW read.

---

## 4. Relief cues from the generator maps

### New presentation map

`surface_maps()` returns a second RGBA8 map, **`relief`**, filtered linearly (one hardware bilinear fetch). It is computed
in `cpore_terrain.cpp` next to `surface`. It is presentation only: it adds nothing to the hash and does not touch `core/`.

| Channel | Content | Encoding |
|---|---|---|
| R | Fine signed curvature, Laplacian at r = 1 and 2 cells (3.5 and 7 m) | `0.5 + 0.5·clamp(k/0.26, −1, 1)`, with k as today's `lap·rm·0.5` but signed; >0.5 concave |
| G | Broad signed curvature, r = 5 and 10 cells (17.6 and 35 m) | same |
| B | Sediment | `clamp(log10(1+sed) / log10(201), 0, 1)` (scree p50 is 10 m, land p99 199 m) |
| A | Sun visibility | 255 = lit. Reserved: constant 255 until step 9 |

Keep `surface` B (cavity) as it is: grass and water read it. Bump `TerrainData.RENDER_PREP_VERSION` to 2 (cache key) and
add `relief` to `terrain_cache.gd _valid()`, `terrain_data.gd` (`relief`, `relief_tex`) and `terrain_chunks.gd`
(`relief_tex` parameter). `surface_maps` must require `sediment` in its input check.

### Shading rules (all values posterized with smoothstep pairs; constants named in `look.gd` and the shader)

* **Gullies darken, ridges catch light.** `conc = max(0, 2R−1)`, `conv = max(0, 1−2R)`, and the same for G at broad scale.
  * Rock: `rock *= mix(1, 0.64, smoothstep(.15,.55, max(concF, concB)))`. The 0.64 is the hero's cavity factor.
  * `rock *= 1 + 0.18·smoothstep(.20,.55, max(convF, convB))·lit`, warm-tinted by `ROCK_LIT`. Ridges catch light only on
    the lit side; on the shade side, a convex rim gets `+0.08` of `SKY_MID`-tinted rim.
* **Flow.** Wet streaks run on cliffs where `surface.A` (wetness) > 0.35 and the macro normal is steep: a narrow,
  biplanar-sampled vertical streak mask (macro A channel stretched in v). It applies `rock *= mix(1, 0.72, mask)` with the
  existing `WET_TINT`. At gully floors (`concB` high and wet high), add a darker floor. The channel trace in the meadow is unchanged.
* **Sediment and scree fans.** On scree, `fan = smoothstep(.25,.75, B_sed)`.
  * Thick deposit gives finer and lighter scree: scale the scree detail by `mix(1, 0.6, fan)` (by switching between two
    pebble channels, never by changing the tile size, which would swim) and lighten by `mix(1, 1.08, fan)`.
  * Thin scree over rock shows rock through (height blend below).
  * At the toe of a fan (fan high, slope < 30°), add sparse turf from the existing meadow, only where the grass mask allows.
* **Strata bands** on rock (and volcanic, at double the thickness):
  * Generator-aligned cap rock: `phase = (wp.y + 0.025·wp.x − 0.018·wp.z + 10·n400)/47`, with `n400` a smooth 400 m noise.
    In Godot, x = map x and z = map y (`terrain_data.gd:57-58`, `terrain.c:721-722`). Where `t = fract(phase)` falls in
    [.12, .62] and `wp.y > 342` (fully above 375), the rock is the hard layer: lighter (`mix(rock, R1·1.1, .35)`), with fewer
    cracks (AO weight 0.5). This band coincides with the real W16 steps.
  * Cosmetic bedding everywhere on steep rock (`steep` from `gn.y` as today):
    `b = fract((wp.y + 0.3·dip + 2.5·(B_macro − 0.5)) / 7.3)`, with the period wobbling by ±25% through the 263 m mineral
    sample. Bands alternate R0/R1/R2 tints in 3 posterized steps, at about **±14% value** (not 4.5%).
  * At the lower edge of each band (`b < 0.06`) draw a dark under-ledge line; at the upper edge, a light lip. These are
    relief cues without geometry.
  * The B_macro offset breaks the bands, and a 263 m mask fades them out on 30% of faces so not every cliff is banded.
* **Slope and height blends: meadow → scree → rock → snow.** Use a height blend instead of the plain bilinear id weights:
  * `hw_i = w_i + 0.5·H_i`, with `H_rock = B_macro`, `H_scree = 1 − B_macro` (scree fills cracks) and
    `H_meadow = 0.5 + 0.5·grass`.
  * `w_i' = max(hw_i − max_j hw_j + 0.18, 0)`, then normalise.
  * The `xz` jitter at `terrain.gdshader:26` goes; B_macro breaks the boundaries in all three projections.
* **Snow rests on flat-ish faces.**
  `snow = w5' · smoothstep(.55,.75, n_d.y)`, where `n_d` is the **detail** normal, so snow sits on the up-facing facets of
  the plates. Add ledge dusting on rock near the classifier's line:
  `line = 365 − clamp(gy,−1,1)·45`, with `gy = −gn.z/gn.y`, the same aspect rule as `terrain.c:1269`;
  `dust = w1' · smoothstep(line−30, line+5, wp.y + 20·(B_macro−.5)) · smoothstep(.80,.92, n_d.y)·0.8`.
  Snow on faces steeper than about 55° falls back to rock.

---

## 5. Lighting consistency (Compatibility renderer, unshaded, calibrated ACES)

* The terrain stays `render_mode unshaded`. Normal mapping is done in the shader's own light term, not with
  `NORMAL_MAP`. Switching to lit would bypass the calibrated `scene_out()` path (M0 "look pipeline findings").
* Detail normal (UDN blend, cheap and correct for any face sign when the texture stores −∇h):
  `n_d = normalize(gn + s·(w_x·(0, d_x.y, d_x.x) + w_y·(d_y.x, 0, d_y.y) + w_z·(d_z.x, d_z.y, 0)))`.
  * `d_k` is the decoded RG of each projection, with the macro, meso and micro layers summed per projection before the
    blend.
  * `s` is the strength: 0.55 macro, 0.45 meso, 0.35 micro, each times its distance fade.
  * The sign of v must match the `-p.y` convention; step 4 has a sign test.
* `light = max(dot(n_d, SUN_DIR), 0)` feeds **the existing ramps unchanged**: `rock_light`, `landRamp` and
  `mix(ROCK_SHADE, ROCK_LIT, smoothstep(.18,.52, light))`. Nothing else changes in the lighting model.
* Anti-flicker: widen each ramp smoothstep by `fwidth(light)` (`smoothstep(a − fw, b + fw, light)`). At far distance
  `s → 0`, so the far view has today's lighting and the "far OK-ish" look is preserved by construction.
* The output path is unchanged: `land` is linear, then `ALBEDO = scene_out(land, wp, CAMERA_POSITION_WORLD)`, which calls
  `godot_albedo(tm_inv(…aerial…))`. Detail never adds HDR above the current maximum: clamp the multipliers so
  `max(land) ≤ 1.2×` today's snow value. `tm_inv` clamps at 0.985 display.
* Every new constant is mirrored in `look.gd` and checked by `test_look.gd` (extend `_consts()` to read
  `rock.gdshaderinc`).

---

## 6. Performance budget and quality tiers

The game runs on the **integrated Radeon 860M** (RDNA 3.5, 8 CU) of a hybrid laptop by default. That is the target: Medium
holds 60 fps at 1080p on it. The owner can start the dGPU with `DRI_PRIME=1` or `prime-run`; High is for that.

Current terrain fragment, estimated (to be measured in step 0):

* 16 `texelFetch` in `ground_normal`;
* 4 + 4 for the surface and material weights;
* about 15 value noises (60 `sin`): `tone`, `meadowColor`, the jitter and **two** `rock_color` calls;
* the occluder loop (near only) and the `scene_out` Newton loop.

| Tier | Rock/scree sampling | Fetches added | Removed | Budget on the 860M at 1080p (terrain pass vs today) |
|---|---|---|---|---|
| **Low** | Biplanar macro + mineral, scree macro only, no meso/micro, strata on, relief on | 4 + 1 relief | about 12 noises (rock_color ×2, jitter) | **≤ +0.0 ms** (must not be slower than today) |
| **Medium** (default on iGPU) | + meso (≤380 m) + scree detail (≤450 m) | 8 + 1 | same | **≤ +1.0 ms** |
| **High** (dGPU) | Triplanar + micro (≤70 m), anisotropic 4x on the detail samplers | 12-15 + 1 | same | ≤ +2.5 ms on the iGPU, informative only |

Other rules:

* **Optional saving, step 8:** a `normal_tex` (RG8, linear filter, built from the height in `surface_maps`) replaces the 16
  fetches of `ground_normal` for shading only. Gameplay keeps `TerrainData.normal()`; grass keeps `ground_normal`. Adopt it
  only if the frames match within 2/255 on the far view.
* Gate the volcanic `rock_color` with `if (w[3] > 0.001)` and the meadow work with `if (w_meadow + grass > 0.001)`. Region
  branches are coherent.
* Tiers are compile-time: `terrain_low.gdshader`, `terrain_medium.gdshader` and `terrain_high.gdshader` each contain
  `#define ROCK_TIER n` and `#include "res://game/shaders/terrain_body.gdshaderinc"`. Only one compiles at load.
  `terrain_chunks.gd` picks it from `Game.settings.quality`.
  * `"auto"` is the new default. It resolves through `RenderingServer.get_video_adapter_name()`: Radeon(TM) 8xxM/7xxM,
    "Radeon Graphics", Intel UHD/Iris/Arc integrated → `"medium"`; otherwise `"high"`. `"low"`, `"medium"` and `"high"` are
    explicit.
  * Grass density stays as it is.
* Texture memory: 1.4 MB + 0.35 MB with mips, plus 4 MB for `relief` (1024² RGBA8). `normal_tex`, if adopted, is 2 MB.

Measurement (step 0 tool, `godot/game/tests/bench_terrain.gd`, target `make godot-rock-bench`):

* Fixed views (chase, mid, far, cliff_lit), vsync off, `--max-fps 0`, 120 warm-up frames, then 600 frames per view.
* It prints the mean and p95 frame ms, and the GPU ms from `RenderingServer.viewport_get_measured_render_time_gpu` when the
  Compatibility backend reports it (it may return 0; then the frame delta is the measure, because the terrain is GPU-bound).
* Grass is set to the game default 252000. It writes `docs/evidence/godot/rock/bench-<tier>-<adapter>.json`.
* **The owner runs it on the 860M** (agents never use the GPU). Agents run the same script under llvmpipe only for a
  relative ratio: new/old must be ≤ 1.3 at Medium as a sanity check.

---

## 7. Ordered steps

Each step is one or two commits and keeps `make godot-test`, `make godot-render-test` and `make godot-play-test` green
(plus `--check-only` on every new script). Evidence goes to `docs/evidence/godot/rock/`. "Frames" means the five views of
step 0, rendered with `make godot-rock-evidence` (xvfb, llvmpipe, 1280x720) into `after-<step>/`, and a side-by-side sheet
against `before/`.

### Step 0: baseline tools and before frames (no look change)

* Files: `godot/game/tests/rock_evidence.gd`, `godot/game/tests/bench_terrain.gd`, and Makefile targets
  `godot-rock-evidence` and `godot-rock-bench` (same xvfb/software flags as `godot-wire-evidence`; the bench target has no
  xvfb, for the owner's GPU).
* Views:
  * **chase:** as `wire_evidence.gd` chase;
  * **mid:** camera (0, 80, 0) looking at the highest peak;
  * **far:** (0, 900, 2600) → (0, 150, 0), as m0/wire;
  * **cliff_lit:** the rock cell nearest the origin with slope 55-65°, horizontal normal·sun > 0.6 and r > 250 m. On seed 1
    this is **(−68.6, h 83, −392.0)**, normal (−1.00, 0.03). The camera sits 60 m out along the normal, 15 m up, looking at it.
  * **cliff_shade:** the same rule with normal·sun < −0.6. On seed 1 this is **(290.0, h 60, −226.8)**, normal (0.43, 0.90).

  The script finds both cliffs by rule and prints their coordinates. They must match the values above.
* Accept:
  * `before/{chase,mid,far,cliff_lit,cliff_shade}.png` are committed;
  * the llvmpipe bench JSON is committed;
  * the owner is asked to run `make godot-rock-bench` once on the 860M (record the adapter name).

### Step 1: mapping include and the stretch test

* Files:
  * new `godot/game/shaders/rock_mapping.gdshaderinc` (weights, biplanar/triplanar `textureGrad` sampling, UDN detail
    normal);
  * `terrain.gdshader`: a `uniform int rock_debug` (0 off, 1 = 4 m checker through the active mapping, 2 = mapping weights,
    3 = relief channels, 4 = light only, 5 = legacy planar checker);
  * new test `godot/game/tests/rock_stretch_test.gd` with target `godot-rock-stretch-test` (xvfb, software).
* Test:
  * Build a synthetic `height_tex` (N = 256, cell 1 m): a 60° cone (radius 110 m) on a flat ring. Draw it with the terrain
    material on a subdivided `PlaneMesh`, with uniforms set by hand.
  * Use an orthographic top-down camera (1024², 0.29 m/px) and debug mode 1.
  * Count checker edges along the radial (downslope) and circumferential (contour) lines at 8 azimuths on the 60° flank,
    and on the flat ring. Convert from screen to surface metres (the radial horizontal length divided by cos 60°).
* Accept:
  * flat density 1.00 ± 0.03;
  * on the 60° flank, **downslope ratio within [0.85, 1.10] at all 8 azimuths**, and contour ratio ≥ 0.68 (expected 0.71 at
    45°);
  * **mode 5 (legacy planar) must measure 0.50 ± 0.05 downslope**, which proves the test measures stretch.

  Record the 16 numbers in `docs/godot/ROCK.md`.

### Step 2: bake the detail textures

* Files: `godot/game/tools/bake_rock_detail.gd`, `godot/game/textures/rock_detail.png` (+ `.import`),
  `godot/game/textures/scree_detail.png` (+ `.import`), and `docs/evidence/godot/rock/detail_sheet.png`.
* Accept:
  * a second run gives byte-identical PNGs (test hashes them in `run_m0_tests`);
  * tileable: the mean |Δ| across the wrap edge is ≤ 1.5× the mean interior neighbour |Δ|;
  * the B histogram spans ≥ 0.1..0.9;
  * the decoded normals have |n| ≤ 1;
  * the imports have mipmaps and are lossless.

### Step 3: biplanar rock and scree colour, with no normals yet

* Files:
  * new `godot/game/shaders/rock.gdshaderinc` with `rock_shade()` and `scree_shade()`;
  * `land.gdshaderinc`: `rock_color` replaced (keep R0/R1/R2 and the ramps);
  * `terrain.gdshader`: remove the xz jitter, gate the volcanic call;
  * `terrain_chunks.gd`: texture uniforms;
  * `look.gd` and `test_look.gd`: new constants.
* Accept:
  * the stretch test still passes;
  * frames: cliff_lit and cliff_shade show no downslope streaks. Metric: on a 64×64 crop of the cliff, the ratio of
    vertical to horizontal autocorrelation length of luminance must be ≤ 1.4 (before: expect about 2). The script prints it.
  * far: the mean rock RGB within 4/255 of `before/far.png` on a fixed mask;
  * bench ratio recorded.

### Step 4: detail normals through the toon ramp, with distance fades

* Files: `rock.gdshaderinc`, `rock_mapping.gdshaderinc`, `terrain.gdshader`.
* Accept:
  * **sign test** in `rock_stretch_test.gd`: replace the detail texture with a synthetic one holding a single raised
    horizontal ridge. In mode 4 on the cone, the up-facing side of the ridge is brighter than the down-facing side at all
    8 azimuths;
  * no new HDR maximum (the clamp test);
  * frames: the cliff views show crisp facets; far within 4/255 as in step 3;
  * a temporal-flicker check: render cliff_lit twice with the camera moved 0.25 m. The fraction of pixels whose ramp band
    changes is ≤ 3% outside the moved silhouette;
  * bench within the tier budget.

### Step 5: strata bands

* Files: `rock.gdshaderinc`, plus `look.gd` and `test_look.gd` (band constants).
* Accept:
  * debug mode 3 shows the cap-rock band where a GDScript replica of the phase (unit-tested at 5 points) says so;
  * frames: bands visible on cliff_lit and mid (the luminance profile along a vertical line on the cliff shows ≥ 3 peaks
    over 40 m);
  * far within 4/255.

### Step 6: relief map in the extension; gullies, ridges, flow and scree fans

* Files: `godot/extension/cpore_terrain.cpp` (+ `.h` docs), `terrain_data.gd` (`RENDER_PREP_VERSION := 2`, `relief`,
  `relief_tex`), `terrain_cache.gd`, `terrain_chunks.gd`, `rock.gdshaderinc` and `terrain.gdshader`. Rebuild with `make godot`.
* Accept:
  * new tests in `test_terrain.gd`:
    * `relief` has n²·4 bytes;
    * R and G read 128 ± 1 on a flat synthetic map;
    * a synthetic V-gully reads > 128 at its floor and a ridge < 128 at its crest;
    * B is monotone in sediment;
  * cache tests pass with the new version (old cache files miss cleanly);
  * the M0 render-test checks still pass;
  * frames: gullies darker and ridges lighter on cliff_lit (sample the gully and ridge cells by coordinate); scree fans
    visible on mid.

### Step 7: height blends and snow placement

* Files: `terrain.gdshader` and `rock.gdshaderinc`.
* Accept:
  * on far and mid, the share of snow pixels on faces steeper than 55° (from a debug mask render) is < 5% (before: measure);
  * the material boundaries' gradient width on cliff_lit is under 2 m of surface (debug mode 2);
  * the meadow and grass in the chase frame are unchanged within 2/255 off the mountains.

### Step 8: quality tiers and the performance pass

* Files: `terrain_low/medium/high.gdshader`, `terrain_body.gdshaderinc` (the old `terrain.gdshader` content moves here),
  `terrain_chunks.gd`, `game/game.gd` (`quality: "auto"`) and the optional `normal_tex`.
* Accept:
  * all three tiers compile (`--check-only` plus the stretch test runs per tier);
  * Low's llvmpipe frame time ≤ before;
  * the owner's 860M numbers within the section 6 budget (or recorded as open if not run);
  * play test green with quality forced to each tier.

### Step 9 (optional, owner A/B): baked sun shadows

* Bake sun visibility into `relief.A` in `surface_maps`:
  * ray-march at N/2 toward `SUN_DIR` (passed in as an argument), with early exit above the chunk max bound;
  * soften with a 3×3 blur;
  * expect ≤ 0.3 s, cached.
* Apply it to rock, scree, meadow **and grass** (`grass.gdshader`), so that shadowed slopes do not keep sunlit grass.
* The hero had no terrain cast shadows, so this ships only if the owner prefers the A/B frames.
* Risk: it ties the look to the fixed sun.

### Step 10: documentation

* `docs/godot/ROCK.md`: what changed, the stretch numbers, the before/after sheets, the bench table, and the new constants
  listed for **owner approval** (as M0 did for sand and volcanic).
* A one-line pointer in `docs/godot/WIRE.md`, and a DESIGN.md entry only when the owner approves.

---

## 8. Risks

* **Tiling repetition.** A 41 m tile on a 1 km mountain repeats about 25 times. Mitigations: the mineral-driven u offset,
  non-integer tile ratios, and the bands and relief maps varying on top. Check the mid frame by eye and with the
  autocorrelation script (no peak at the tile period above 0.3).
* **Toon flicker.** Detail normals crossing hard ramp thresholds can crawl in motion. Mitigations: `fwidth` widening,
  distance fades, mip filtering, the step 4 flicker test, and lower `s` if needed.
* **Palette drift from the approved look.** No new hues are planned: only R0/R1/R2, SCREE, SNOW, ROCK_SHADE/LIT and
  WET_TINT. Any new number is listed for approval, and the far view is gated within 4/255. The M0 note that "rock reads
  greyer than the hero's warm cliffs" is not fixed silently; propose it as a separate tweak.
* **Mip seams and derivatives.** Use `textureGrad` with world-position derivatives, and do not sample inside divergent
  branches without explicit gradients (the distance-fade branch must use `textureGrad`).
* **Compatibility renderer limits.** Fragment samplers rise from 3 to 6 (the limit is 16). `textureGrad`, `fwidth` and
  `uint` are available in GLES3/GL3.3. Shader compile time grows a little; there are three variant files, but only one
  compiles per run.
* **The extension change touches M0's C++.** It needs `make godot`, bumps the cache version (a one-time 3.7 s regeneration
  for players) and may conflict with other branches editing `cpore_terrain.cpp`. Keep the diff local to `surface_maps`.
* **The cap-rock phase is approximate.** The generator's `noise2` is static in `core/`, so the shader's 400 m noise differs
  and the bands sit within a few metres of the real W16 steps, not on them. The fine curvature channel marks the real
  steps anyway.
* **Performance numbers.** Agents only have llvmpipe, so the 860M budget is verified only when the owner runs the bench.
  Until then, mark it as not verified.
* **GPU sin-hash differences** (diagnosis item 8) remain in the meadow noise. If the owner sees banding on the 860M,
  replace `landHash` with an integer hash (PCG) in a follow-up. That is out of scope for rock.
* **Shared includes.** `grass.gdshader` and `water.gdshader` include `terrain_maps.gdshaderinc`. Do not change existing
  function signatures there; add new functions in `rock*.gdshaderinc`.
* **Scope creep.** Trees, boulders and cave meshes are not part of this plan. Rock props on scree would help, but they are
  separate work.
