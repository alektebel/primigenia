# Eroded terrain (W11–W18 + rivers, generator version 4)

The default is **v2 + cliffs + caves** (W20 owner choice in the task brief), using the v2+ generator in
`core/include/cpore/terrain.h` and `core/src/terrain.c`. It retains v2's massif
construction, multiscale stream power, droplets and scree sweeps. Seven
independent switches add gentle approaches, layout variety, high-face detail,
sea cliffs, resistant strata, one stratovolcano and cave entrances.
Gentle approaches, layout variety and the volcano now default to **0**;
high-face bands, sea cliffs, resistant strata and caves remain **1**.
No generation algorithm changed for this default selection.

The island is about 3.2 km across in a **3.6 km square** (W14). The default seed
is **1**. Sea level is 0 m, the start valley's reference floor 42 m. The lake,
river gap and high col remain guaranteed on seeds **1, 7, 42, 99, 1234, 31337**.
Game integration, cache/loading-screen integration, smoke and cave meshes are
later work; the standalone terrain lab consumes this generator's actual maps.

The comparison sheet is [v2 versus v2 + cliffs + caves](evidence/terrain/shape-v2cc.png): seed
42 in the same three views as the [previous v2+ sheet](evidence/terrain/shape-v2plus.png),
followed by seeds 1 and 7 and sea-cliff/cave-notch close views. The
[material and cave view](evidence/terrain/v2cc/lab-material-caves.png) shows the
C material classes and numbered entrances. [Measured acceptance and limits](evidence/terrain/v2cc/metrics.md)
include exact values, runtime parity and independent ablations. **The unchanged
Rb gate fails on seed 31337 (5.9713 > 5.5); `make terrain-test` remains red.** The original
[v2 sheet](evidence/terrain/shape-v2.png) and [v2 measurements](evidence/terrain/metrics.md)
remain historical evidence.

## Run

```sh
nice -n 10 make test
source ~/emsdk/emsdk_env.sh
nice -n 10 make terrain-test
nice -n 10 make wasm-test
nice -n 10 build/terrain_cli stats --seed 42 --n 1024
nice -n 10 build/terrain_cli features --seed 42 --n 1024
nice -n 10 build/terrain_cli dump --seed 42 --n 1024 --out build/map.bin
nice -n 10 python3 tools/terrain/ablations.py
nice -n 10 python3 tools/terrain/ablations.py --v2cc --out build/terrain/v2cc-ablations.json
nice -n 10 ./build/terrain_test --heavy --gentle
nice -n 10 python3 -m http.server 8031 --bind 127.0.0.1
```

Open `http://127.0.0.1:8031/web/terrain-lab/`. Serve the repository root, because
the module Worker imports `build/wasm/cpore_terrain.mjs`. Three.js r128 uses the
existing CDN. No packages or SDKs need installing. The lab provides natural
materials, the categorical C material map, altitude, slope, flow and sediment,
plus orbit and valley-floor cameras. The material legend names each class;
numbered circles mark caves, outward lines show their facing, and cyan marks
the waterfall entrance. Four checkboxes independently toggle W16–W18 features.

`stats` reports height, flat start-floor fraction, lake bottom and spill, and
connected escape sills with and without the river corridor. `features` prints
JSON with the volcano's position/radii, six material counts and cave records.
`--base` disables all erosion work and keeps the selected landform switches;
this is the paired comparison used by the structure gates.

## Pipeline and bounded changes

1. **v2 shape.** Ridged, domain-warped gradient noise shapes the connecting
   range, the individually elongated massifs and their arête spurs, the
   unwarped start floor and lake bowl, a river corridor, a deliberately lowered
   col and a noisy coast. With `layout_variety=0` it uses the original seven
   slots and their original jitter and sizes. At 1, a common seeded hash
   selects **6–8** slots, increases angular jitter and varies widths. The count
   hash domain was calibrated on the six public development seeds (counts
   6/7/8/7/8/6); it contains no per-seed branches. This does not prove drainage
   acceptance on unseen seeds.
2. **Sea cliffs (W16).** Selected angular sectors replace the long beach
   transition with a roughly 38 m rock shelf and short face. The mask only acts
   within the coastal transition; it cannot raise inland lake/valley floors.
   Other sectors retain beaches, and the river-mouth corridor is exempt.
3. **One volcano (W17).** One slot, selected away from the promised exits,
   replaces its massif with a smooth, concave radial cone, a 62 m summit
   crater and old lava ribs that run outward toward the coast. Other massifs
   retain v2's construction. The crater may hold a small lake. The flanks
   undergo the same erosion passes at reduced strength (18% in the inner
   cone), so barrancos form without removing the landmark. The small crater
   bowl is protected from pit infill. No active lava/fire is simulated.
4. **Stream power.** The original implicit `dh/dt = −K·sqrt(A)·S` solver runs
   48/16/6 steps at N/4, N/2 and N, resampling height change and sediment while
   sampling the analytic base afresh at each scale. Below about 1,600 m² of
   catchment, hillslope wear is 2.5% of channel wear. Pits half fill per step;
   the start floor and lake are protected. A bedrock sweep follows each step.
   **Resistant strata (W16)** are gently dipping, spatially perturbed layers
   above 342 m, strongest above 375 m. They reduce incision and droplet wear
   by up to 90%, allow steeper bedrock and resist the final scree transport.
   Soft layers still erode; the interfaces leave steps and high cliff faces.
5. **Droplets and scree.** The original 80,000 droplets run before the fine
   stream-power pass. Lifetime, inertia, brush, capacity, deposition and
   evaporation are unchanged. Fixed scree sweeps move a quarter of the largest
   excess to the steepest D8 neighbour; resistant rock scales this transport.
   Transport conserves mass; stream-power incision exports material.
6. **Gentle approaches (W15).** A smooth C1 hypsometric remap follows erosion.
   It is identity below 100 m and above 342 m. Compression grows smoothly
   above 100 m, then recovers over relief 160–300 m above the reference floor.
   It changes no erosion pass and introduces no radial apron. Lowland slope
   acceptance samples **all land between 42 and 192 m**, using central
   differences, and requires a median of 15–30° on every development seed
   only when `gentle_bases > 0`. Run `build/terrain_test --heavy --gentle`
   to check that optional configuration; it is not the default acceptance.
7. **Subtle high bands.** Up to 0.9 m of relief, only above 302 m and on faces
   steeper than 40°, with full strength above 332 m and 55°. There is no
   mid-height cosmetic band. These are separate from resistant geological
   strata, which affect erosion itself.
8. **Drainage and caves (W18).** Original priority-flood routing with an epsilon
   gradient preserves physical lake bowls and produces an acyclic D8 network.
   Cave placement then chooses **3–6** separated steep, dry sites at production
   resolutions. A qualifying waterfall (river area ≥8,000 m² and a receiver
   drop >max(4 m, 0.8 cell)) reserves the first entrance. Every site must also
   retain a downhill outlet below its carved floor. The other sites are
   chosen by a deterministic ranking, with 180 m separation. Small notches
   lower only a few nearby height samples; routing is recomputed afterward.
   Cave records describe their final floor positions. There are **no tunnels
   or chamber meshes** in this output. N<64 omits entrances rather than
   inventing sites on a grid too coarse to describe them.
9. **Material classification.** The final height, slope, aspect, sediment and
   volcanic footprint produce the material map. Water remains a separate
   surface inferred from height/routing level.

All work is fixed by parameters, never by a time budget. Counts of droplets,
stream steps and thermal sweeps remain v2's. With **all seven switches set to
0**, height, flow and sediment retain v2's bytes; the versioned hash still
changes because v3 includes the new output schema.

## Parameters and output

`cp_terrain_params_default` initializes everything; `cp_terrain_generate`
validates before touching the buffers. The seven switch strengths are finite
floats in [0,1]. The layout count changes discretely when
variety is enabled; the geometric strengths interpolate.

| C parameter | CLI option | JS request / lab query | Default |
|---|---|---|---:|
| `gentle_bases` | `--gentle-bases` | `gentle` | 0 |
| `layout_variety` | `--layout-variety` | `variety` | 0 |
| `cliff_bands` | `--cliff-bands` | `bands` | 1 |
| `sea_cliffs` | `--sea-cliffs` | `coast` | 1 |
| `hard_rock` | `--hard-rock` | `rock` | 1 |
| `volcano` | `--volcano` | `volcano` | 0 |
| `caves` | `--caves` | `caves` | 1 |

The lab's last four queries are boolean, e.g. `?seed=42&volcano=0&caves=0`.
Other capture queries include `n`, `base=1`, `view=valley`, `map=<pixels>`,
`mesh=<segments>` and `shading=classification`.

Other defaults remain v2's: N=1024, 5 octaves, 760 m noise wavelength, 240 m
warp, ridge weight 0.60, valley radius 300 m, range feet 340–1500 m, relief
parameter 470 m, coast radius 1600 m, lake at (−150,70) m with radius 68 m,
stream K·dt 0.07, bedrock angle 62°, 80,000 droplets of lifetime 64 and brush
radius 2, and 8 scree sweeps at 38°. The CLI retains the work/noise/erosion
options documented in its source, including `--stream`, `--droplets`,
`--thermal`, `--lifetime`, `--radius`, `--erosion`, `--capacity`, `--stream-k`,
`--talus`, `--cliff`, `--relief`, `--ridge` and `--octaves`.

`CpTerrain` owns no allocation: callers supply three N² float maps (`height`,
`flow`, `sediment`) and **one N² byte `material` map**. Its fixed output fields
hold the volcano's world x/y, cone/crater radii, `cave_count` and at most six
`CpTerrainCave` records. Each cave has x/y position, z altitude, outward unit
facing x/y, width/height/depth in metres and a uint32 waterfall flag.
Notches are heightfield hints; renderers can later attach short cave meshes.

| Material ID | Class |
|---|---|
| 0 | Meadow / turf |
| 1 | Rock |
| 2 | Scree |
| 3 | Volcanic rock, including old flows |
| 4 | Sand |
| 5 | Snow |

The volcanic footprint retains ID 3 on its high cone so renderers can identify
its dark rock. Other massifs use aspect-dependent snow. The material map does
not encode water depth; sample height and routing level for that.

Workspace remains one N² float scratch map and three N² int32 arrays. Total
map/workspace storage is **29 N² bytes (29 MiB at N=1024)**, plus the small
fixed records. There is no malloc in core. N is 8–2048; the standalone WASM
arena caps it at 1024. Coordinates sample cell centres,
`((index + 0.5) * size_m / N) - size_m / 2`; map +y is south and north is up.
Sediment measures cumulative deposition, not the amount still present.

Progress callbacks retain stages 0 base/coarse streams, 1 droplets, 2 fine
streams/scree, 3 routing, 4 done. All run synchronously on the calling thread.

## ABI, dumps and determinism

The WASM API retains `ct_config`, `ct_deltas`, `ct_generate`, `ct_map` (0 height,
1 flow, 2 sediment, 3 routing water level), `ct_hash`, `ct_size`, `ct_version`.
It adds `ct_features(coast,rock,volcano,caves)`, `ct_material` (byte pointer),
`ct_cave_count`, `ct_caves` and `ct_volcano` (four float32 values). A cave record
is eight float32 values followed by one uint32 flag (36 bytes). The wrapper
returns copied typed arrays, `entrances` objects and a `landmark` array; Worker
transfers preserve the byte material map. Configuration precedes generation.

The CLI dump keeps the `CPTER10\0` header and original height/flow/sediment/D8
payload. Version 3 flags bit 1 signals a feature extension: N² material bytes,
four float32 landmark values, a uint32 cave count, then that many 36-byte cave
records. Bit 0 still identifies a base-only terrain. The metrics reader
accepts old v1/v2/early-v3 dumps and validates the feature extension.

Official parity remains x86-64 Linux versus WASM, `-O2 -std=c99 -fno-fast-math
-ffp-contract=off`. Canonical generation uses arithmetic, sqrtf, integer hashing
and polynomial fades; no libm trigonometry enters the maps. The FNV-1a hash
serializes version **3**, N, world size, height, flow, sediment, material bytes,
landmark fields and live cave records, explicitly little-endian. Signed zero
is canonicalized, pointers/padding/unused cave slots are excluded. The three
N=32 goldens were deliberately re-recorded; tests never regenerate them.

## Verification and evidence

`make terrain-test` runs six-seed N=1024 guarantees, paired base/eroded metrics,
three small goldens, native/WASM parity at N=256 on all six seeds and N=1024 on
1 and 42, plus separate switch combinations. Erosion must improve both valley
depth and ridge sharpness on every seed. The **unchanged** natural-structure
gate targets Rb 3–5 and Hack 0.5–0.6, with its existing tolerances of 0.5 and
0.05 respectively. Actual values, including Hack values below 0.5, are reported
in the evidence; a passing tolerance is not a claim of strict target coverage.
The all-switches-off parity test also pins height/flow/sediment bytes against
original v2 fixtures, independently of v3's expanded output hash schema.

Browser evidence uses headless Chromium 1254, only
`--use-angle=swiftshader --enable-unsafe-swiftshader`, and asserts SwiftShader.
Run browser/heavy processes with `nice -n 10`; the capture script closes its
browser in `finally`. No normal-browser frame rate or owner approval is claimed.

```sh
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/terrain/capture.cjs --out docs/evidence/terrain/v2cc --no-base --details
nice -n 10 python3 tools/terrain/sheet.py docs/evidence/terrain/v2cc docs/evidence/terrain/shape-v2cc.png 'v2 + cliffs + caves'
nice -n 10 node tools/terrain/compare_v2.mjs build/terrain/v2-disabled.json
```

For the comparison row, extract `core/src/terrain.c`, its header, `cpore.h`,
`rng.c` and `apps/terrain_wasm_api.c` from **0386bb8** into ignored scratch
storage and compile the terrain WASM exports into `build/wasm-v2/`. Read files
with `git show`; do not check out or merge another branch. The sheet tool
accepts a source directory and optional destination path.

Remaining limits: six seeds are calibration evidence, not a proof for all
uint32 seeds; high rock walls retain v2's steep character; D8 floor channels
are routing rather than fully carved riverbeds; cave notches cannot represent
overhangs; renderers still need cave interiors and volcanic smoke. Islets,
whole-island biome/game placement and W13 caching belong to later integration.

## Version 4: rivers and the smoother look (branch terrain/look-hydro)

**Rivers** (new, `rivers` switch, default 1, CLI `--rivers`, `build/terrain_cli`): the D8 flow is carved into deterministic channels with bank
profiles, a class map (stream / shallow / deep) and water levels the C world reads. Full description, thresholds and tests:
[HYDROLOGY.md](godot/HYDROLOGY.md). `CP_TERRAIN_VERSION` is 4; the dump appends the n*n river map after the caves. The lake, river gap and
high col guarantees hold on seeds 1, 7, 42, 99, 1234, 31337 (`terrain_test --heavy`). With `--rivers 0` the generator is v3 bytes plus the version word.

**Why the mountains looked "voxel"** (diagnosis from `docs/evidence/godot/look/before/`, same cameras as `s2/` and `after/`):
1. *Shading facets.* The fragment normal came from central differences of the **triangulated** surface, so each 3.5 m triangle had a nearly constant normal.
   With the toon light ramp (`landRamp`, `rock_light`) each facet read as a flat polygon; on sand and scree the diagonals were visible. Fix: C1 Catmull-Rom
   gradient of the height texels (`ground_normal`, mirrored by `TerrainData.smooth_normal`). The geometry stays the exact triangle surface, so the sim and
   `ground()` agree to the millimetre (deviation 0); a Catmull-Rom *height* differs from the triangle surface by p99 0.5 m on this island (max 6 m at cliff steps), too much for foot placement
   without changing the C sim (which the C branches own), so only the normal is smoothed. Test: unit, upward, continuous across cell borders (below 0.1 degrees at a border), median 1.3 degrees from the triangle normal.
2. *Polygonal far silhouettes.* LOD steps of 28 and 56 m triangles began at 1.2 km, exactly where the mountains are. Fix: LOD ranges 250/550/1200/2600 -> 300/700/1500/3200 m and a vertex
   **geomorph** (`lod_step`, `morph_range`): vertices slide onto the next lattice between 0.6 and 0.9 of the switch distance, so the swap happens between identical surfaces (no pop).
3. *Hard cell borders* in the material: the generator's per-cell material was already blended bilinearly (`material_weights`); the remaining blob edges are the thresholds of the
   classification (slope/altitude steps), unchanged here.
4. *Missing sub-cell detail.* The rock tiers already add triplanar strata and a detail normal (docs/godot/ROCK.md); no geometric micro-relief was added, because the sim ignores it and feet must stay on `ground()`.

Wetness now also comes from the river map (wet banks). Evidence: `docs/evidence/godot/look/`. Deferred: raising the generator to n=2048 (measured in the report, not forced), geometric micro-relief on rock, softer classification thresholds.

## Version 5 (visual erosion; branch terrain/erosion-detail)

Presentation only: the C core, its hash and goldens are unchanged (`CP_TERRAIN_VERSION` stays 4). Mountains were good from afar but up close the 3.5 m
triangles gave angular silhouettes and no sub-cell relief. v5 derives a **visual heightfield 4x finer (4096 squared, 0.88 m)** from the sim heights and
adds the fine erosion the sim cannot afford. The sim stays authoritative.

**Pipeline** (`godot/extension/visual_terrain.cpp`, `CporeTerrain.visual_maps(entry, options)`; called by `TerrainData.prepare`, cached with the entry):
1. *Bicubic base.* Catmull-Rom upsample of the sim heights at the 4096 grid.
2. *Droplet erosion* (Beyer/Lague particles: inertia 0.1, capacity 4, erode/deposit 0.3, brush radius 2, lifetime 90) with 0.12 droplets per visual cell (about 2 M),
   then a x3 amplification of the carved delta (rills have to read at 0.9 m texels). Parallel and deterministic: the grid is cut into 512 cell tiles run in four
   checkerboard phases (tiles of one phase are further apart than a droplet travels) with a per-tile RNG, so the result is bit-identical for any thread count
   (test). Visits give a **flow** map, deposits a **deposition** map.
3. *Thermal talus*, 6 Jacobi sweeps at 36 degrees; the material that arrives is the **talus apron** map.
4. *Bound against the sim.* `visual = S + b * tanh((V - S) / b)` where `S` is the exact triangle surface of the sim (`TerrainData.ground`) and the budget `b` is
   0.4 m on walkable ground, growing to 10 m on steep rock (sim slope 42 to 61 degrees), and 0.06 m within ~10 m of a river, lake or the coast (below 1.5 m altitude).
   So rivers, lakes and the coast stay where the sim and the water meshes put them, and a creature never stands more than the budget from where the C world thinks it is.
5. *Maps* at 2048 squared RGBA8: R flow (log), G droplet deposition, B talus apron, A exposure (curvature at 2.6 and 6 m; > 0.5 convex).
   Heights are stored as uint16 (`vh_min + vh_range * v / 65535`, 1 cm steps over 600 m).

**Rendering.** Chunks keep their 224 m footprint but are 256 visual cells wide; 7 LODs (step 1..64 cells = 0.9, 1.8, 3.5, 7, 14, 28, 56 m) switch at 130/280/600/1200/2400/3800 m
with the existing geomorph; all of them read the visual texture (R16). The fragment normal is the visual field's up to ~140 m and the sim's Catmull-Rom normal beyond ~340 m (no
aliasing of 0.9 m texels, far palette unchanged). Materials (terrain_body.gdshaderinc, `erosion_maps`): gully water streaks on steep ground (flow into the existing wet-streak path),
deposition fans (feed the existing sediment-fan look of scree and the fine pebble tile), talus aprons turn rock below cliffs into scree on stable slopes, exposed convex ridges lose grass
and wetness and sharpen the relief cue, the class lookup is domain-warped by 2.5 m so the 3.5 m cell borders stop showing, and the rock sheets are domain-warped by about 1 m so the plate pattern is not a regular honeycomb.
Close to the camera (22 to 85 m) a derivative-damped eroded fBm (3 octaves, 2.4 m wavelength, triplanar) tilts the rock normal. It is normal-only: no geometric displacement, so feet and
`visual_ground` agree with the mesh (a vertex displacement of a few cm is deferred). The maps fade out between 500 and 1500 m.

**Feet and camera.** `TerrainData.visual_ground(x, z)` is the exact surface of the LOD0 mesh (same diagonal on the 4096 grid). `Game.visual_ground` feeds creature bodies and feet
(`stage.ground_fn`, actor hosts, loco IK), chase camera, pointer and icons; the grass shader roots blades with `vground_tri`. The C sim keeps `ground()`; the two differ by at most the
budget (below).

**Measured** (seed 1, 1024 sim cells; `test_visual.gd`, `make godot-test`):
|visual - sim| on walkable ground (sim slope below 35 degrees, away from water): p50 0.10 m, **p99 0.40 m**, max 0.96 m (cliff-edge samples, where the budget starts to grow);
on river, lake and coast cells at most 0.064 m. Second difference at 0.9 m is more than 1.5x the triangle surface's (test). Rendered frames: `docs/evidence/godot/terrain-v5/`.

**Cost** (`make godot-visual-bench`, 16 cores, `docs/evidence/godot/terrain-v5/bench-visual-gen.json`): first generation of the visual maps 1.5 s on 8 threads (5.4 s on 1 thread) on top of
3.5 s for the sim; cache file 38 MB (was 10 MB), cache hit 85 ms; transient RAM during generation about 330 MB, resident +48 MB (uint16 heights 32 MB + maps 16 MB) plus the same in VRAM
(R16 4096 squared = 32 MB, RGBA8 2048 squared = 16 MB; a float heightfield would have been 64 MB). The generator is CPU code (C++ in the GDExtension, multithreaded), not a compute shader: it works headless, is testable and
deterministic, and its cost is paid once per island (cache key: terrain hash, `CP_TERRAIN_VERSION`, `RENDER_PREP_VERSION` 5). The numbers scale with cores; on the owner's desktop with 8+ cores expect 1 to 2 s,
on a 4-core laptop 3 to 5 s. Rendering cost, llvmpipe medium tier, 1280x720, 40 frames, 60000 grass (software raster, noisy, a relative ratio and never a GPU number; `bench-before/after-medium-llvmpipe.json`),
mean frame ms before -> after: chase 429 -> 853, mid 203 -> 407, far 594 -> 640, cliff_lit 212 -> 471. Near views double (about 4x the vertices in range, a 16-fetch fragment normal, the fBm and domain warp); far views
are within 8 %. The RTX figure is open: `make godot-terrain-bench TIER=high` writes `docs/evidence/godot/terrain-v5/bench-high-*.json`. Knobs if it is too much: LOD0 range (130 m), the vis_normal fetch count, the fBm range.

**Deferred.** A Mei/grid hydraulic pass or a compute-shader port (would allow re-eroding in the editor); geometric micro-displacement on rock at LOD0; D8 stair steps of the carved rivers remain (the sim channels are
exact and protected by design); softer classification thresholds for the generator itself; a visual field for n=2048 uses factor 2 only.

**v5 follow-up: photographic ground materials (branch terrain/rock-textures).** Up close the dominant look of v5 was still the Voronoi plate sheet at 2 to 10 m. The terrain material now reads eight CC0 photographic
materials (ambientCG: andesite, bedded strata, basalt, tuff, scree gravel, talus debris, volcanic soil, sediment; `godot/game/textures/CREDITS.md`) through the same biplanar/triplanar rock mapping, with two scales,
stochastic taps (no visible tiling), anisotropic filtering, height-based blending driven by the v5 erosion maps, wet gravel and silt banks, bare soil at turf edges and sand from the sediment sheet. Colours keep the island's
palette (each texel is divided by its sheet's mean and multiplies the palette colour), so far views are recognisable. Shading only: the C core, its hash and goldens, the geometry and the visual heightfield are unchanged.
Details, tiers, constants and tests: docs/godot/ROCK.md "Photographic materials". Frames: `docs/evidence/godot/terrain-photo/` against `terrain-v5/after`.
