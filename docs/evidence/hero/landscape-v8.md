# P0-land: meadow and distant landscape, v8

The hero now uses a continuous green-yellow meadow, tufted grass through two
LODs, stratified alpine terrain and three layered backdrop ranges. All visual
changes are asserted patches in `tools/hero/build_hero.py`; regenerate with
`nice -n 10 python3 tools/hero/build_hero.py`. The generated page is
`web/hero/index.html`.

## Implementation

- `MEADOW` supplies the same height-map fbm patch tone, preset grass tint,
  stepped light response, tree shade, procedural color detail and wind waves
  to ground and blades. Both use ACES and sRGB output. Near blades taper,
  darken at the root, brighten at the tip and transmit sunlight. Creature
  occlusion shades the ground as well as the blades; near blades still bend
  away from the body and feet.
- 200,000 near blades form eight-blade tufts through 44 m. A second, sparse
  LOD contains 52,000 wider, shorter blades in four-blade tufts, fading between
  110 and 140 m. Both rings shrink into matching ground. Clump seeds and a
  low-frequency field vary meadow height. Total: **252,000 instances**.
- The terrain shader keeps turf on gentle low slopes, gives cliffs darker
  stepped lighting, breaks horizontal strata with erosion noise, and places
  noise-edged snow above 120–145 m on flatter faces. Tree placement and its
  altitude thinning are unchanged.
- The built-in fog chunks are replaced once, including world positions for
  instanced materials. The same exponential height-density function fogs
  grass and water. Per-preset `HL.air` values control density, height falloff,
  cool ambient haze and warm sunward scattering. Clouds receive it too; the
  sky remains the atmospheric endpoint.
- Three render-only ring meshes at crest radii 900, 1,550 and 2,450 m use the
  same alpine material and aerial perspective. Their seeded silhouettes and
  high snow caps sit behind the gameplay bowl. The sky and camera far plane
  extend to contain them. They do not participate in gameplay collision.
- `cam=vista` uses the existing sun-relative azimuth, 175 m distance, 0.48 rad
  elevation and 62-degree field of view. The original three cameras retain
  their framing.

`height()` and `groundY()` remain byte-identical to the reference, enforced
by the generator. Every file under `art/reference/` was compared to Git HEAD
byte for byte. No C core, simulation, other worktree, or reference was edited.

## Evidence and measurements

The final 4×4 contact sheet, 16 full-size frames, body/sky masks, per-frame
metrics and browser settings are in [grid/](grid/README.md).
[comparison-v8.png](comparison-v8.png) pairs the preserved v7 golden-mid and
golden-far with v8 and adds golden-vista. The standalone golden is
[v8-golden-mid.png](v8-golden-mid.png).

Golden-mid mean meadow hue: **70.50° before → 77.04° after**
(88,600 and 88,600 sampled pixels; required 65–100°).

Both original v7 full-grid timing and fresh v7 subset timing are preserved in
[v8-baseline.json](v8-baseline.json); the matched full-grid comparison is the paired
data in [v8-measurements.json](v8-measurements.json). Same Chromium 158,
SwiftShader, 1280×800, three-render mask procedure and niceness:

| Frame | v7 seconds | v8 seconds | Ratio |
|---|---:|---:|---:|
| golden-close | 52.60 | 58.12 | 1.10× |
| noon-close | 52.59 | 64.56 | 1.23× |
| overcast-close | 54.16 | 69.65 | 1.29× |
| night-close | 58.55 | 73.31 | 1.25× |
| golden-mid | 54.19 | 75.91 | 1.40× |
| noon-mid | 64.37 | 65.17 | 1.01× |
| overcast-mid | 52.70 | 69.91 | 1.33× |
| night-mid | 53.43 | 72.33 | 1.35× |
| golden-far | 54.35 | 79.90 | 1.47× |
| noon-far | 56.16 | 70.68 | 1.26× |
| overcast-far | 59.58 | 74.11 | 1.24× |
| night-far | 59.83 | 70.92 | 1.19× |

Mean matched full-grid capture time (12 existing views): **56.04 → 70.38 seconds (1.26×)**.
Every matched full-grid frame remains below 1.5×. The grid records every other frame's
time as well. Vista is new and has no v7 counterpart. These are wall-clock
capture costs (page load, warmup, renders, screenshots, decoding and masks),
not interactive FPS claims.

A separate adjacent two-frame check (late v8, then unchanged v7) gave:

| Frame | v7 recheck seconds | v8 recheck seconds | Ratio |
|---|---:|---:|---:|
| golden-mid | 61.34 | 76.71 | 1.25× |
| golden-far | 59.21 | 81.29 | 1.37× |

Both versions used the same two-frame order, browser, viewport, SwiftShader
arguments and niceness. The v7 page was read unchanged from
`3a07527^:web/hero/index.html` into `/tmp`; its screenshots match the initial
v7 baseline byte-for-byte. The repeated v8 screenshots match the final grid
byte-for-byte. Both adjacent ratios remain below 1.5×.

For transparency, the initial fresh v7 subset was faster (46.19/48.60 s) than
the late v7 recheck (61.34/59.21 s). Comparing the initial subset with the late
v8 subset yields 1.66×/1.67×, above the budget. The archived full-grid and
adjacent subset comparisons both meet it. This measured timing variance is
consistent with changing machine load; its cause was not established. All
raw timing records are retained in the measurement JSON.


Hue uses two fixed, visually inspected golden-mid meadow rectangles:
`[80,520,390,720]` and `[1000,500,1190,640]` (half-open pixel coordinates).
It excludes the creature mask and pixels with HSV saturation <0.2 or value
<0.15, then computes arithmetic mean hue in degrees. There is **no hue
filter**. This samples meadow pixels, not every grass pixel in the image.
The same regions and thresholds are used before and after. The before hue
can be reproduced without launching Chromium:

```bash
NODE_PATH=<brief's scratchpad/node_modules> nice -n 10 node tools/hero/capture_grid.cjs \
  --measure-hue docs/evidence/hero/v7-golden-mid.png
```

Acceptance retains creature mean luminance inside environment p10–p90 and
absolute saturation difference ≤0.15. Only vista frames with a creature mask
smaller than 512 pixels skip these two creature checks; all their metrics
are still saved. Zero page/console errors are required for every frame, and
golden-mid also requires mean meadow hue within 65–100 degrees.

## Commands and validation

All browser/render/image-conversion processes ran at `nice -n 10`, including
children. Browser arguments were exactly the two software-WebGL arguments
from the brief; every browser closed in `finally`.

```bash
nice -n 10 python3 tools/hero/build_hero.py
nice -n 10 python3 -m py_compile tools/hero/build_hero.py
node --check tools/hero/capture_grid.cjs
git diff --check
NODE_PATH=<brief's scratchpad/node_modules> nice -n 10 node tools/hero/capture_grid.cjs \
  --only golden:mid,golden:far --out /tmp/p0-land-baseline
# Iteration used --only subsets in /tmp; successful final full grid:
NODE_PATH=<brief's scratchpad/node_modules> nice -n 10 node tools/hero/capture_grid.cjs
```

Build, Python/JavaScript syntax and whitespace checks pass. Rebuilding twice
produced the same SHA-256. The generator's gameplay-function assertions pass,
and a byte comparison of all reference files against HEAD passes. The
Impeccable mechanical detector returned `[]`. Browser acceptance exercises
actual shader compilation and the three render masks; no unrelated test
suite or GPU FPS benchmark was run.

## Capture diagnostic and limitations

One intermediate capture failed at Playwright `Page.captureScreenshot` with
`Unable to capture screenshot` on the first night-mid screenshot, after a
successful golden-mid. No page/console error preceded it. Memory, disk and
shared-memory checks showed capacity available. Root cause is **unconfirmed**;
a transient Chromium capture/compositor failure is a hypothesis. A contained
fresh-browser night-mid + golden-vista run passed 2/2, and browser debug output
confirmed graceful shutdown. The capture tool now saves frame state, error
stack and console errors to `*.failure.json` if a future operation fails.
No automatic screenshot retry hides failures.

The first full-grid attempt was interrupted by SIGTERM (exit 143) during
noon-close, with no JavaScript/page error and no capture browser left running.
Its cause is unconfirmed. The final attempt was restarted with direct tool
output and frequent session polling; the reported final metrics come only
from that completed attempt.

Final validation: **16/16 frames pass, zero page/console errors**. The full
grid completed in one final run without a capture failure. No implementation
items from A–G remain outstanding. Normal-browser performance was not
measured; owner visual approval remains pending.

Visual approval remains the owner's judgement. The backdrop is a cosmetic
hero-shot treatment, not implementation of the W1/W6 island generator. Wind
is frozen at t=3 for evidence; the same wave field animates with `live=1`.

## V9 — lush meadow, clear bowl relief and a valley-facing vista

This section supersedes the v8 implementation and acceptance results above.
The current [grid](grid/README.md) is v9. Original v8 frames and metrics remain
in commit `0f23d02`; its [comparison](comparison-v8.png) and
[measurements](v8-measurements.json) are preserved.

### Changes

- Keep 200,000 near blades and 52,000 far blades, with the existing 140 m
  outer fade. A smooth radial bias (`r = 44 * u^0.72`) concentrates near tufts
  without a density boundary. Near height is now
  `(0.48 + 0.75 * clump) * rolling * grassMask * fade` metres; near width is
  0.12 m before seed scaling. Eight-blade tufts vary in height and colour;
  near blades bend around the creature. The golden views show grass reaching
  its knees and obscuring most of the nearby ground.
- Ground uses the shared patch/wind/light colour multiplied by linear
  `(0.60, 0.68, 0.54)`. Its green channel is reduced less than red/blue, giving
  a darker, more saturated base beneath blade mid-tones. Beyond the blades,
  the same fbm patches, procedural detail, tree shade and animated wind waves
  remain. No circular bright base is introduced.
- Golden fog begins at 140 m, with density 0.00052 instead of 0.00135.
  Optical depth ramps in as `path * (1 - exp(-path / 240))`, with exponential
  height density integrated at three points along the ray. It scatters toward
  blue away from the normalized sun direction and toward warm amber sunward.
  The other presets receive the same delayed, reduced-density treatment.
  All surfaces retain the shared ACES/sRGB pipeline.
- Bowl rock mixes ochre, grey and brown mineral patches. Subtle strata vary
  their spacing, use noise to break their phase and coverage, and fade from
  steep faces onto ledges. A two-scale positive heightfield Laplacian is
  computed once per terrain vertex, stored as `cavity`, and darkens concave
  gullies. The large terrain normal drives three light levels; scree and turf
  collect on gentle slopes and ledges. Snow thresholds and colours stay as in
  v8, as do the three backdrop meshes.
- Vista searches 96 directions for a broad low saddle, samples across a
  20-degree opening, and penalizes trees obscuring the creature or nest.
  Distance is 125 m, elevation 0.40 rad, FOV 62 degrees; the look target is
  36 m above the creature centre. The creature and nest remain in the lower
  third, with the bowl saddle and layered ranges above them. Other camera
  positions are unchanged.

### Measured acceptance

**16/16 frames pass, with zero page/console errors.** The full 16-frame grid
completed in one final run. All four vista frames pass the framing check
(≥150 body pixels, mean body y in the lower third).

Golden-mid meadow hue: **74.69°** over
88,600 pixels, using the unchanged meadow rectangles and thresholds
(required 65–100°).

| Frame | Lit pixels | Lit mean Y | Shaded pixels | Shaded mean Y | Difference | Required |
|---|---:|---:|---:|---:|---:|---:|
| golden-far | 56,369 | 0.2816 | 2,934 | 0.0632 | **0.2185** | ≥0.12 |
| golden-vista | 142,744 | 0.2892 | 173,932 | 0.0382 | **0.2511** | ≥0.12 |

Golden-vista body: 245 pixels, mean y **597.7**,
extent y 583–610 (lower third begins at y 533.3). The nest
is visible below it in the beauty frame. Raw masks and both normal/cavity
passes are saved with the grid.

Mountain classification uses a fourth render for golden-far and golden-vista.
The bowl shader outputs raw `R = max(N·L, 0)`, `G = cavity`, `B = eligibility`,
with tone mapping, output encoding and fog bypassed. Eligibility requires
world height ≥20 m, camera distance 150–500 m, snow fraction <0.02, turf
fraction <0.10 and blade mask <0.05, using the same normals, height map and
snow/turf equations as the beauty shader. The far camera keeps its original
framing and samples the visible lower rock faces, whose upper-row ray hits
are roughly 200–230 m away and 37–42 m high. Other objects render black as
depth occluders (leaf cards conservatively occlude their full geometry); grass
is hidden because it occupies lower terrain.
Backdrop ranges are excluded. Pixels with blue ≥254 are classified as lit at
N·L ≥0.55 and shaded at N·L ≤0.20; intermediate light values are excluded.
At least 200 pixels per class are required. Linear Rec.709 luminance is sampled
from the **original fogged beauty frame**, so this checks surviving image
contrast, including material, exposure and atmosphere, rather than an unfogged
lighting value. The N·L classification thresholds were fixed before measuring
the final material. Two initial far-view masks selected no pixels: both
required height ≥45 m (the first also capped it at 120 m), excluding the
lower mountain faces in this framing. The final mask lowers the elevation cutoff to 20 m, follows the exposed rock
material and retains the 150–500 m distance restriction for both views. CPU
terrain ray-hit samples in the metrics make the visible geometry auditable.
A diagnostic far check first tested the material mask without the minimum
distance; a final far check restored 150 m before the complete grid.

[comparison-v9.png](comparison-v9.png) has v7 / v8 / v9 columns and golden-mid /
golden-far / golden-vista rows. V7 has no vista camera; that cell says so.
`tools/hero/compare_landscape.py` reads full-size v7 and v8 images directly
from `3a07527^` and `0f23d02`, avoiding new baseline browser renders. Source
image SHA-256 hashes, contrast measurements, framing, hue and capture times
are in [v9-measurements.json](v9-measurements.json).

### Commands, scope and limitations

```bash
HERO_NODE_PATH=/tmp/claude-1000/-home-diego-Desarrollo-cpore/52130491-4ef1-4633-b55d-8ccffceb2b8f/scratchpad/node_modules
nice -n 10 python3 tools/hero/build_hero.py
nice -n 10 python3 -m py_compile tools/hero/build_hero.py tools/hero/compare_landscape.py
node --check tools/hero/capture_grid.cjs
git diff --check
# Two golden-only iteration sets and two far-only mask checks, in /tmp:
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs \
  --only golden:mid,golden:far,golden:vista --out /tmp/p0-land-v9-iteration1
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs \
  --only golden:mid,golden:far,golden:vista --out /tmp/p0-land-v9-iteration2
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs \
  --only golden:far --out /tmp/p0-land-v9-far-check
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs \
  --only golden:far --out /tmp/p0-land-v9-far-final
# Run the complete grid once, after golden views pass:
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs
nice -n 10 python3 tools/hero/compare_landscape.py
# Reproduce mountain measurements without another browser render:
NODE_PATH="$HERO_NODE_PATH" nice -n 10 node tools/hero/capture_grid.cjs \
  --measure-mountain docs/evidence/hero/grid/golden-far.png \
  --debug-pass docs/evidence/hero/grid/golden-far.mountain-debug.png
```

Build, Python/JavaScript syntax, generated inline-script parsing and whitespace
checks pass. A second build produced an identical SHA-256. The generator
asserts exact preservation of `height()` and `groundY()`, and all three tracked
files under `art/reference/` match HEAD byte for byte. Final golden-mid,
golden-far and golden-vista beauty images match the last full golden iteration
byte for byte. Offline remeasurement of both mountain beauty/debug pairs
reproduces the recorded differences and passes. No unrelated game test suite
or hardware FPS benchmark was run.

Browser and heavy image processes use `nice -n 10` and inherit that niceness.
Chromium is the brief's `chromium-1254/chrome-linux64/chrome`, with exactly
`--use-angle=swiftshader` and `--enable-unsafe-swiftshader` as explicit launch
arguments, 1280×800, scale 1. Pages and browsers close in `finally`. Golden
far/vista take an extra debug render and CPU terrain ray checks, which
increase their capture cost.
Timings are wall-clock capture costs under uncontrolled machine load; no
interactive frame-rate claim or controlled performance comparison is made.

Owner visual approval and normal-browser performance remain unverified.
This work changes only the cosmetic hero scene and its evidence tooling;
it does not implement the C island generator or alter gameplay terrain.
