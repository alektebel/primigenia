# Eroded terrain (W11–W13, phase A)

The standalone generator is `core/include/cpore/terrain.h` and
`core/src/terrain.c`. It produces a 2 km valley and mountain-ring slice for
Primigenia, from a seed. The default seed is **1**. This phase supplies the
maps, tests, measurements and an independent preview; game integration belongs
to phase B. It does not replace the old land-stage height function.

## Run

From the repository root:

```sh
nice -n 10 make test            # native regression suite; terrain smoke is N=32
nice -n 10 make terrain-test    # 1024 guarantees, paired metrics and WASM parity
nice -n 10 make wasm            # combat + terrain ES modules and companion WASM
nice -n 10 make wasm-test       # existing combat checks plus terrain parity
nice -n 10 make build/terrain_cli
nice -n 10 build/terrain_cli stats --seed 1 --n 1024
nice -n 10 build/terrain_cli dump --seed 7 --n 1024 --out build/map.bin
nice -n 10 build/terrain_cli hash --seed 1 --n 256 --base
nice -n 10 python3 -m http.server 8031 --bind 127.0.0.1
```

Open `http://127.0.0.1:8031/web/terrain-lab/`. It imports
`build/wasm/cpore_terrain.mjs` from a module Worker; serve the repository root,
not just `web/`. Three.js r128 uses the same CDN as the existing studio, so
loading the preview requires network access for that script. No Node package
installation is needed to use the page. If `emcc` is absent from PATH, Make
sources `~/emsdk/emsdk_env.sh`; no SDK is downloaded.

The lab provides seed/resolution and warp/ridge/erosion/work controls, five
surface modes, orbit/zoom (pointer or keyboard), progress, hillshade and a
contributing-area drainage overlay. Generation runs on demand in the Worker;
the page renders on interaction rather than running an idle animation loop.
The display mesh samples at most 256² cells, dropping to 128² when zoomed out;
all calculations and material sampling use the full generated maps.

## Pipeline

1. **Base:** hash-gradient noise with quintic fades, five-octave fbm and
   Musgrave-style ridged multifractal (fold, square, previous-octave weight).
   Two fbm fields warp the domain. A radially irregular mountain mask reserves
   the central valley, forms broad foothills and a mountain ring, subtracts a
   lake bowl, and opens a corridor in the positive pass direction.
2. **Hydraulic:** fixed-count, seeded particles follow bilinear height gradients
   with inertia. Sediment capacity depends on downhill drop, speed and water.
   Uphill/over-capacity particles deposit bilinearly; under-capacity particles
   remove a weighted radial brush, with a downhill-drop cap. The brush uses
   squared-distance falloff and renormalizes at boundaries. Erosion is damped
   near the guaranteed start and lake; deposition is retained. Every particle's
   remaining load settles when it stops, exits or reaches its lifetime limit.
   The model follows [Beyer’s particle-erosion thesis (2015)](https://www.firespark.de/resources/downloads/implementation%20of%20a%20methode%20for%20hydraulic%20erosion.pdf),
   with these explicit game-oriented mask and brush choices.
3. **Thermal:** fixed, row-major in-place relaxation moves one quarter of the
   largest excess above the talus threshold to the steepest D8 neighbour.
   The tangent is evaluated once as a ratio of polynomial sine/cosine
   approximations. Finite iterations approach the angle; they do **not** promise
   a hard slope cap. Hydraulic and thermal transport conserve height sum within
   float rounding; tests check both independently.
4. **Drainage:** a deterministic binary-heap priority flood computes spill
   water levels in scratch. D8 steepest descent on that surface, with flood
   parents resolving flats, produces an acyclic graph. Topological accumulation
   adds one unit of rainfall per cell, then divides by N². Heap ties use cell
   index, directional ties the lowest direction index. The physical height
   map retains its depressions and lake. This is depression routing derived
   from the [Priority-Flood method](https://github.com/r-barnes/Barnes2013-Depressions),
   not a water-volume or river-flow simulation.

Raw D8 on the eroded heights fragmented into many tiny pits and gave
unusable channel counts. Routing over spill levels fixed that failure without
removing the lake. Water on a flat filled basin follows deterministic parent
paths; the straight lines visible in the valley drainage overlay are routing
artifacts, not incised rivers. The `cp_terrain_directions` helper intentionally
returns **raw** local D8 directions; generation's actual routed receivers are
`workspace.recv` after generation, and the CLI dump stores those directions.

## Parameters and units

`cp_terrain_params_default(&p)` initializes every parameter. Set overrides,
then call `cp_terrain_validate` or `cp_terrain_generate`, which validates again.

| Group | Default |
|---|---|
| Seed / N / world width | 1 / 1024 / 2000 m |
| Noise | 5 octaves; frequency 1.7 / 2000 cycles/m; warp 280 m; ridge weight 0.72 |
| Valley | radius 300 m; reference floor 42 m |
| Mountain ring | inner 430 m; outer 820 m; relief parameter 540 m |
| Pass | direction (1, 0.15), normalized internally; half-width 120 m; floor 118 m |
| Lake | centre (−150, 70) m; radius 68 m; depth parameter 34 m |
| Hydraulic work | 70,000 droplets; lifetime 32; brush radius 4 cells |
| Droplet dynamics | inertia 0.40; capacity 4; deposition 0.28; erosion 0.32 |
| Water / speed | evaporation 0.015; gravity 4; minimum capacity slope 0.012 |
| Thermal | 5 passes; talus 34° |

Heights and deposited sediment are float32 metres, flow is the fraction of
map area contributing to a cell, and slope is rise/run (tan of slope angle).
Sediment is cumulative **hydraulic deposition**, not final loose-material
thickness: later erosion may remove material already counted. Thermal movement
is not included in this diagnostic deposition map.

Coordinates sample cell centres: `((i + 0.5) * size_m / N) - size_m / 2`.
Map +y is south; north is up in the hillshade. Droplet steps/brush radius are in
cells; work counts are absolute. Using the same 70,000 droplets at N=256 erodes
more heavily per unit area than at N=1024. Resolution and every parameter are
part of a world's identity; a small map is not an exact downsample of a large one.

The header exposes all mask/droplet settings and their limits. N is 8–2048;
the standalone WASM ABI caps N at 1024 to bound its static arena. Errors reject
bad dimensions, counts, nonfinite/unsafe values or missing buffer pointers
before writing maps. Pointer capacity and overlap are caller preconditions.
The CLI additionally accepts `--droplets`, `--thermal`, `--lifetime`, `--radius`,
`--erosion`, `--capacity`, `--base` and `--out`.

## C ownership and progress

Allocate three non-overlapping N² float arrays for `CpTerrain` (`height`, `flow`,
`sediment`), one N² float scratch array and three N² int32 arrays for
`CpTerrainWorkspace` (`recv`, `ups`, `queue`). All buffers must be suitably
aligned and have at least N² elements. Core uses **no malloc**. Total storage
is 28 N² bytes: **28 MiB at N=1024**, **112 MiB at N=2048**. Output metadata is
written by `cp_terrain_generate`; workspace contents may be overwritten.
The reusable WASM module owns one static arena of the same total size and has
48 MiB initial linear memory including stack/runtime space.

```c
CpTerrainParams p;
cp_terrain_params_default(&p);
p.seed = 7;
/* Allocate output and workspace arrays as above. */
int rc = cp_terrain_generate(&p, &terrain, &workspace, on_progress, user);
uint64_t hash = rc == CP_TERR_OK ? cp_terrain_hash(&terrain) : 0;
```

The optional callback receives `(stage, done, total, user)` synchronously.
Stage values are base=0, hydraulic=1, thermal=2, flow=3, done=4. `done` is
monotone within each emitted stage, and resets at the next. Zero-work stages
may be skipped. Base reports rows, hydraulic fixed droplet chunks, thermal
iterations and flow chunks. The Worker forwards progress with `postMessage`;
it transfers copies of the three map arrays after completion. Callbacks must
not mutate generator parameters/buffers or reenter that instance.

## Determinism and hashes

Official scope matches combat: x86-64 Linux and WASM. Both use `-O2 -std=c99
-fno-fast-math -ffp-contract=off`; Make appends the determinism flags after
native user CFLAGS. The only floating-point arithmetic feeding output is
`+ - * / sqrtf` with comparisons, integer hashing and polynomial fades.
No transcendental library calls or time budgets feed generation. A dedicated
`CpRng` is seeded with `seed ^ 0xE501D35D` for droplets; no game RNG stream is
consumed. Counts are fixed; particles can terminate early for local stopping
conditions, consistently across platforms. Sorting/routing ties are explicit.

`cp_terrain_hash` uses FNV-1a 64 over explicit little-endian fields:
uint32 generator version, uint32 N, float32 size, then all height, all flow,
and all sediment cells in row-major order. Float signed zero is canonicalized
to +0. The hash excludes padding, pointers, workspace and seed/params metadata;
it identifies **output bytes**, not an input configuration. Cache metadata must
include the version and full parameter set. The current generator version is 1.

Three committed `tests/golden/terrain-*.hash` fixtures use seeds 1/7/42,
N=32, 300 droplets, 3 thermal iterations and all other final defaults.
Tests read these fixtures; they never regenerate them. Initial checkpoints were
intentionally recaptured while fixing the routing, mask and brush before this
first version was finalized. Future byte changes require an explained version
change and reviewed fixture update.

## Verification and timings

The native smoke covers determinism/divergence, committed small-map goldens,
validation, progress, finite map ranges, flow conservation, unique topological
routing, hydraulic/thermal mass conservation, slope/direction helpers, and
signed-zero hashes. The full-size default-seed checks require:

| Guarantee | Threshold | Measured |
|---|---|---|
| Start floor | ≥90% of cells within 90 m of centre have slope <10° | 100% |
| Lake | Centre <30 m and its sublevel set at centre +10 m cannot reach any map edge | Holds ≥10 m |
| Pass | Four-connected sublevel path ≤150 m from start beyond radius 850 m | Reachable |
| Peaks | Maximum height >400 m | 580.96 m |

These prove terrain properties, not creature pathfinding, a dry placed nest,
or full W6 island guarantees. The pass check is an elevation-connectivity
check, not a slope/locomotion-capability proof.

Native/WASM parity compares all three small goldens and seeds 1/7/42 at N=256
plus seed 1 at N=1024. Exact hashes and measured generation times are in
[evidence/terrain/parity.json](evidence/terrain/parity.json). The measurements
exclude output hashing, map copies and rendering. See the evidence report for
machine/compiler versions and browser results. W13's 10 s budget passes.
ASan/UBSan pass; gcov measured 100% terrain lines, 99.43% branch execution and
92.29% branches taken on the smoke + full-size checks (unoptimized coverage
build, not a performance measurement).

[The metrics report](evidence/terrain/metrics.md) records the base/eroded
comparison and limitations. With independent basin-outlet Hack fits, paired
range gaps are non-worse for every seed and improve in aggregate. Seed 1
already lies inside both ranges, and seed 42's eroded h=0.4985 remains just
below the strict 0.5 boundary. Pooled junction fits do not meet the requested
Hack range; this is an explicit sensitivity limitation, not hidden acceptance.

Screenshots are reproducible with the existing agent Playwright installation:

```sh
# Keep the server above running, then:
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/terrain/capture.cjs
```

The capture script uses only Chromium 1254 with
`--use-angle=swiftshader --enable-unsafe-swiftshader`, asserts SwiftShader,
exercises controls, and always closes the browser. All captures are generated
landscapes from the final WASM; no reference art is modified. An independent
source/screenshot review shipped the standalone preview, with no material
finding within its scope. This does not replace the owner's visual approval.

## Remaining scope

The square valley slice is visibly shaped by its gameplay mask. The drainage
on filled lakes/flats is an analytic diagnostic, and finite thermal iterations
leave some slopes above talus. Three seeds are a small calibration set; this
is not evidence of statistical naturalness across arbitrary worlds. The
[drainage study used to clarify the Hack definition](https://essd.copernicus.org/articles/16/1151/2024/index.html#section3)
measures longest rivers from divide to mouth; our small artificial basins are
far smaller and more constrained than those natural datasets.

Phase B still needs terrain placement in the game, creature traversal and
material/LOD integration. Whole-island biomes, islets and caves remain future
work. W13's game cache, pre-baked curated seed and panspermia loading story
are not implemented by this phase-A lab.
