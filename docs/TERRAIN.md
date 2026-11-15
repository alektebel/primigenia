# Eroded terrain (W11–W13, generator version 2)

The standalone generator is `core/include/cpore/terrain.h` and
`core/src/terrain.c`. From a seed it produces a 3.6 km square holding one
island: a flat start valley with a lake, a chain of massifs around it, a river
gap that drains the valley to the sea, cols between the massifs, and a coast.
The default seed is **1**. Phase A supplied the engineering (determinism,
parity, tests); this version reshapes the range and its erosion, because the
phase-A result read as a crater wall with scratched slopes. Game integration
still belongs to phase B. It does not replace the old land-stage height function.

Before and after, three views each: [evidence/terrain/shape-v2.png](evidence/terrain/shape-v2.png).

## Run

From the repository root:

```sh
nice -n 10 make test            # native regression suite; terrain smoke is N=32
nice -n 10 make terrain-test    # 1024 guarantees on seeds 1/7/42, paired metrics, WASM parity
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
installation is needed. If `emcc` is absent from PATH, Make sources
`~/emsdk/emsdk_env.sh`; no SDK is downloaded.

`stats` prints the height range, land fraction, the start-floor check, the
lake's bottom and spill level, and two sills found by flooding: the lowest
level at which water from the start reaches the sea (the river gap), and the
same with the gap corridor closed (the lowest col).

## Pipeline

1. **Base shape.** Sea level is 0 m. No angle is ever computed: the unit vector
   to a point, scaled, samples 2D gradient noise on a circle, which is a smooth
   periodic function of direction without trig. Those angular fields move a low
   connecting ridge in and out, widen and narrow its flanks (spurs with bays
   between), and shape the coast. On top stand **seven massifs** in hashed slots
   measured from the river gap, each with its own radius, height, long axis and
   arête spurs; saddles form where two meet, at different depths. A corridor
   along the pass direction is the **river gap**: its floor starts just under
   the valley floor and falls to the sea, so the valley drains instead of being
   a closed bowl. One **col** is lowered on purpose in the `col_x, col_y`
   direction. Lower ridges and hills fill the land between the range and the
   coast. Detail is a ridged multifractal whose octaves are damped by the
   gradient summed so far (Musgrave's fold with Quílez's derivative trick), so
   detail sits on crests and floors and the flanks stay clean. The start floor
   and the lake bowl are unwarped.
2. **Stream power, coarse to fine.** `dh/dt = −K·√A·S`, solved implicitly from
   the outlets upstream ([Braun & Willett 2013](https://doi.org/10.1016/j.geomorph.2012.10.008)),
   which is stable at any K. Incision grows with drainage area, so trunks deepen
   and branch headward; droplets with a short life cannot gather a valley
   network. It runs `stream_iters` steps at N/4, a third of that at N/2 and an
   eighth at N. The base is analytic, so each level samples it afresh and adds
   the coarser level's height change and sediment, resampled; fine noise is
   never lost to a blurry upsample. Below about 1,600 m² of catchment the ground
   counts as hillslope and wears at 2.5% of the rate, so crests are not ground
   down while their gullies cut. Closed pits fill by half per step and are
   recorded as sediment. A talus sweep at the **bedrock angle** follows every
   step; that angle varies with a rock-strength noise (hard bands hold cliffs).
   The start floor and the lake bowl are exempt.
3. **Droplets** ([Beyer 2015](https://www.firespark.de/resources/downloads/implementation%20of%20a%20methode%20for%20hydraulic%20erosion.pdf)),
   80,000 at N. They run before the fine stream-power pass and add gullies too
   small for it. Evaporation is set so a droplet sheds its load gradually over
   its life; whatever is left at the end is spread over the brush, not dumped in
   one cell. A droplet that reaches the sea stops there. The fine stream-power
   pass then cuts the dams the deposits leave in the valleys.
4. **Scree.** Fixed sweeps at the loose-material angle move a quarter of the
   largest excess to the steepest D8 neighbour, alternating direction. What
   arrives is added to the sediment map. Finite sweeps approach the angle; they
   do not cap slope.
5. **Drainage.** Priority flood with an epsilon gradient
   ([Barnes et al.](https://github.com/r-barnes/Barnes2013-Depressions), the
   improved +ε variant): each cell is at least 1 mm above the cell that flooded
   it, so every cell but an outlet has a strictly lower neighbour and D8 on the
   water level cannot stall or cycle. Outlets are the map edge and every cell at
   or under the sea. Routing reads height plus a hashed jitter of up to 4% of a
   cell, which changes nothing on a slope and breaks ties on floors, so channels
   there wander and join instead of running in parallel lines. The physical
   height keeps its lake. The same routing is used inside stream power.

Hydraulic and thermal transport conserve the height sum; stream power does not
(detachment-limited: what it cuts leaves the map), and tests check each.

## Parameters and units

`cp_terrain_params_default(&p)` initializes every parameter. Set overrides,
then call `cp_terrain_validate` or `cp_terrain_generate`, which validates again.

| Group | Default |
|---|---|
| Seed / N / world width | 1 / 1024 / 3600 m (cell 3.52 m) |
| Noise | 5 octaves; lowest octave 760 m; warp 240 m; ridge weight 0.60 |
| Valley | radius 300 m; reference floor 42 m |
| Range | inner foot 340 m; outer foot 1500 m; relief parameter 470 m |
| River gap | direction (1, 0.15); half-width 90 m; floor 26 m at the crest line |
| Col | direction (−0.55, −0.83); crest height 230 m |
| Coast | mean radius 1600 m; the square edge is always sea |
| Lake | centre (−150, 70) m; radius 68 m; depth parameter 34 m |
| Stream power | 48 steps at N/4 (16 at N/2, 6 at N); K·dt 0.07; bedrock angle 62° |
| Droplets | 80,000; lifetime 64; brush radius 2 cells |
| Droplet dynamics | inertia 0.30; capacity 2.5; deposition 0.25; erosion 0.30 |
| Water / speed | evaporation 0.045; gravity 4; minimum capacity slope 0.01 |
| Scree | 8 sweeps; talus 38° |

Heights and sediment are float32 metres above sea level, flow is the fraction of
map area contributing to a cell, slope is rise/run. Sediment is cumulative
**deposition**: pit fill and talus from the stream-power passes (resampled from
the coarse levels), droplet deposits and scree. Later erosion may remove
material already counted.

Coordinates sample cell centres: `((i + 0.5) * size_m / N) - size_m / 2`.
Map +y is south; north is up in the hillshade. Work counts are absolute and
part of a world's identity, as is N; a small map is not a downsample of a large
one. Grids under 64 cells skip the N/4 level and under 32 the N/2 level.

N is 8–2048; the standalone WASM ABI caps N at 1024 to bound its static arena.
The CLI accepts `--stream`, `--droplets`, `--thermal`, `--lifetime`, `--radius`,
`--erosion`, `--capacity`, `--stream-k`, `--talus`, `--cliff`, `--relief`,
`--ridge`, `--octaves`, `--base` and `--out`. `--base` turns off stream power,
droplets and scree.

## C ownership and progress

Allocate three non-overlapping N² float arrays for `CpTerrain` (`height`, `flow`,
`sediment`), one N² float scratch array and three N² int32 arrays for
`CpTerrainWorkspace` (`recv`, `ups`, `queue`). Core uses **no malloc**: the
coarse levels live inside those same buffers. Total storage is 28 N² bytes:
**28 MiB at N=1024**. After generation `scratch` holds the routing water level
(above the ground where a basin holds a lake), `recv` the receivers and `queue`
all cells in topological order.

The optional callback receives `(stage, done, total, user)` synchronously.
Stage 0 is the base and the coarse stream-power passes, 1 the droplets, 2 the
fine stream-power pass and the scree sweeps, 3 the drainage, 4 done. `done` is
monotone within a stage. Zero-work stages may be skipped.

The WASM ABI is `ct_config(seed, n, droplets, thermal, warp, ridge, erosion,
stream)`, `ct_generate`, `ct_map(layer)` (0 height, 1 flow, 2 sediment, 3 water
level), `ct_hash`, `ct_version` and `ct_size`.

## Determinism and hashes

Official scope matches combat: x86-64 Linux and WASM, both `-O2 -std=c99
-fno-fast-math -ffp-contract=off`. The only floating-point arithmetic feeding
output is `+ - * / sqrtf` with comparisons, integer hashing and polynomial
fades. The seven slot directions are literal cos/sin constants; their jitter is
a rotation by a normalised `(1, j)`. The two angles are converted once with a
polynomial tangent. Counts are fixed. A dedicated `CpRng` seeded with
`seed ^ 0xE501D35D` drives the droplets.

`cp_terrain_hash` is FNV-1a 64 over version, N, size, then height, flow and
sediment, little-endian, with −0 canonicalized. **The generator version is 2.**
Every byte changed from version 1, so the three `tests/golden/terrain-*.hash`
fixtures (seeds 1/7/42, N=32, 300 droplets, 3 scree sweeps, other defaults) were
re-recorded on purpose for this version. Tests read them; they never regenerate
them.

## Verification and timings

`make terrain-test` checks, on seeds 1, 7 and 42 at N=1024:

| Guarantee | Threshold | Measured (1 / 7 / 42) |
|---|---|---|
| Start floor | ≥90% of cells within 90 m of the centre have slope <10° | 100% each |
| Lake | Centre <30 m; its sublevel set at centre +10 m reaches neither sea nor edge | holds 30.9 / 31.9 / 29.7 m |
| River gap | A connected path from the start to the sea never rises above start +5 m | sill 41.9 m each (the start itself) |
| Col | With the gap closed, the sea is unreachable under 100 m and reachable under 300 m | lowest col 163 / 180 / 152 m |
| Peaks | Maximum height >400 m | 434 / 472 / 482 m |

These prove terrain properties, not creature pathfinding. Seed 1's peak clears
the 400 m line by 34 m; other seeds are not checked.

Native/WASM parity compares the three small goldens, seeds 1/7/42 at N=256 and
seed 1 at N=1024: all match. Seed 1 at N=1024 took **2.61 s native and 3.56 s in
Node/WASM** (phase A: 1.30 s and 1.36 s), inside W13's ~10 s. ASan/UBSan pass on
the full suite; gcov measures 100% of 755 lines, 99.59% of branches executed and
93.36% taken. See [the metrics report](evidence/terrain/metrics.md).

Screenshots come from the lab through the agent Playwright install:

```sh
# Keep the server above running, then:
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/terrain/capture.cjs
python3 tools/terrain/sheet.py          # composes shape-v2.png
```

The capture script uses only Chromium 1254 with `--use-angle=swiftshader
--enable-unsafe-swiftshader`, asserts SwiftShader, takes three pictures per
terrain from one page load, and always closes the browser. The "before" row
needs the phase-A module, which is not kept in the tree: check out
`core/src/terrain.c`, `core/include/cpore/terrain.h` and
`apps/terrain_wasm_api.c` from commit `6336202` into a scratch directory and
build them with the Makefile's terrain `emcc` line into `build/wasm-v1/`.
Without it the script skips that row.

## The lab

Lighting is baked from the maps at full resolution into one texture: slope and
aspect, ambient occlusion and the sun's cast shadow from the height field, then
materials (meadow, forest on moderate low slopes, alpine turf, banded rock where
steep or high, scree where sediment lies steep, gravel where it lies flat, sand
at the shore, snow by altitude, slope and aspect, rivers by contributing area).
Standing water is where the routing level is more than 0.5 m above the ground;
channels are not drawn across it. Views: from above (orbit) and from the valley
floor (eye 2.2 m up). Query parameters `seed`, `n`, `base=1`, `view=valley`,
`map=<pixels>`, `mesh=<segments>` and `engine=v1` drive captures.

## Remaining scope and known weaknesses

- **Slopes are steep.** Of the ground above 100 m, about 60% stands between
  40° and 60° and another 20% above 60° (central differences, three seeds). Stream power cuts until walls reach the bedrock angle,
  and 430–480 m peaks inside a 3.6 km square leave no room for gentler ones.
  The faces read as steep fluted rock, not as alpine benches and meadows.
- **World size is 3.6 km, island about 3.2 km.** W1 says about 2–3 km. At 2 km
  the range could only be a wall. This needs the owner's decision.
- **Massif faces seen from the valley are smooth.** Ribs and gullies are there
  in the hillshade but faint at eye level; there are no cliff bands or cirque
  headwalls.
- **Fans are modest.** Scree aprons show at slope feet; clear alluvial fans at
  valley mouths do not.
- **The seven-slot layout is recognisable** across seeds from above: a wheel of
  massifs with radial valleys. Outer land is spurs and foothills, not separate
  ranges.
- Routing on the start floor is still D8: channels there are plausible lines,
  not riverbeds, and the floor itself is nearly featureless.
- Three seeds are a small set. Pooled Hack fits stay under 0.5.

Phase B still needs terrain placement in the game, creature traversal and
material/LOD integration. Whole-island biomes, islets, caves, the W13 cache,
pre-bake and loading story are not part of this work.
