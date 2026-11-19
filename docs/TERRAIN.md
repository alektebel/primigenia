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
9. **Trails and fords (route certification, v4 output at n >= 512).** Every body must be able to walk from the start
   valley to the river gap and to the first cave. Two deterministic graded trails guarantee it. *Gap trail:* the gap
   checkpoint is the lowest dry cell (away from the river bed) on the 809 m circle around the start (`(796.3,138.9)` on seeds 1
   and 42, `(768.2,258.4)` on seed 7: the long-published `(800,120)` was only ever valid where the range happens to open
   there, it sits on a 114 m massif on seed 7). The cheapest walk (integer costs, raster sweeps, no heap, no allocation) joins
   the start, the checkpoint and the nearest river mouth. *Cave approach:* the first (gameplay) entrance ranks its candidate
   sites by the cost of the graded trail that joins them to the network, still preferring a waterfall, and the trail is cut
   to the entrance floor. A trail is a profile that follows the old heights as closely as a **0.30 slope limit** allows
   (anchored at both ends and wherever it passes a river), on a smoothed centreline, stamped as a flat-bottomed corridor
   (11 m half width, 12 m blend) that is never graded next to a shallow-or-deeper river or inside the protected lake bowl.
   The rock behind an entrance is not touched: only ground in front of its plane is graded, so the entrance cell stays a
   steep face (slope > 0.8) with a walkable apron in front of it (the route certification stands 6 m in front of the entrance). Where a corridor core meets deep or
   standing water the crossing is a ford: deep class becomes shallow and pits rise to a shoal 0.55 m below the surface.
   Slope 0.30 is below the two-leg directional climb (0.457 for the 4 m body) and its holding limit (0.70). Cost: about
   +1.5 s at n=1024 (three cost fields). Gap trail and ford apply when `rivers>0`, the cave trail when `caves>0`.
   Cave records report the final floor after trails and fords.
10. **Material classification.** The final height, slope, aspect, sediment and
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
