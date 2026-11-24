# Island realism plan: Star massif frozen, moisture climate, jungle, sky, ground, clouds (Opus, 2026-11-24)

Goal: turn the picked layout (A95, Star massif) into the first real island, built the way A97 and A98 decided:
- **authored macro, procedural micro**, tuned in a browser map editor;
- a **wind-driven moisture climate** in C that places forest, grass, snow and clouds (the A86 rain shadow made real);
- a **jungle belt** done properly, after a look study;
- the A98 realism ingredients, in order: Hillaire sky → moisture → Blender trees and rocks with impostors → ground materials → volumetric clouds;
- the **orbit-to-nest** opening shot (v1), and a sketch of gameplay weather (later).

This plan names the work. Each step becomes a brief in `docs/briefs/island-<step>.md` when it starts, naming its tracker test. Every number is a **starting value** unless it cites canon, a paper or a measurement. Owner questions with recommended defaults are in §16; each default applies after 48 h unless the owner answers.

Sources read for this plan:
- Decisions: DESIGN A83, A86, A95, A97, A98, W11–W20, A35, A36. Look canon: `docs/canon/LOOK.md`, with the A98 update. Lore: `docs/lore/FLORA.md`, `lore/worlds/primigenia.json` (F2, F4, F7, F8, F15, F17, F18, F19). Plans: `docs/plans/night-sky.md` (merged here, not duplicated), `docs/plans/befriend-port.md` (style).
- Code:
  - C terrain: `core/src/terrain.c`, `core/src/terrain_layouts.inc`, `core/include/cpore/terrain.h`.
  - C stage field: `core/include/cpore/world.h` (`CpStageField`, snapshot header).
  - Godot: `godot/extension/cpore_terrain.cpp`, `godot/game/island/{environment,clouds,day_night,world_light,grass,flora_placement,island_props,terrain_data,terrain_cache}.gd`, `godot/game/shaders/{sky.gdshader,look.gdshaderinc,clouds.gdshaderinc,rock_photo.gdshaderinc,rock_mapping.gdshaderinc}`.
  - Tools: `tools/island/{maps,shots}.py`, `godot/game/tests/island_layout_shots.gd`, `web/gaitlab/island.html`, `web/gaitlab/island/stats.json`, `tools/look/score.py`, Makefile targets.
- Papers, fetched and read: Hillaire 2020 (EGSR, the full PDF); Smith & Barstad's extended abstract of their linear theory (AMS 2003, carrying the JAS 2004 equations); Schneider & Vos 2015 (the SIGGRAPH slides with notes); Hillaire 2016 (Frostbite course notes); Mikkelsen 2022 (JCGT hex-tiling, the paper and its listings). §17 lists them with URLs.

Measured in this worktree (native `build/terrain_cli time --layout 1`, this laptop, `nice -n 10`):
| n | Time | Notes |
|---|---|---|
| 256 | 0.23 s | full pipeline |
| 256 (`--base`) | 0.075 s | shape only |
| 512 | 0.88 s | |
| 1536 | 9.1 s | the A95 setting: 5.2 m cells over the 8 km square |

At n = 1536 the highest point is **824 m**. Canon F7 says ~2,050 m. See Q3.

---

## 0. Ground rules for every step

- **Renderers.** Compatibility (GL3) is the default renderer; Forward+ runs only on discrete GPUs (`render_choice.gd`).
  - Compatibility has no compute shaders and no `RenderingDevice`, so `CompositorEffect` is Forward+ only.
  - So every new GPU pass (sky LUTs, aerial perspective, clouds) is written first as a **fragment pass in a `SubViewport`**, which works in both renderers.
  - A Forward+ compute path is an optional later speed-up, never a requirement.
- **The pipeline convention stays.** Shaders write display colour through `display_out()` / `scene_out()` (`look.gdshaderinc`): the hero's three.js ACES is pre-inverted.
  - Physically based steps compute in linear radiance, multiply by one exposure, and then go through the same `tm()` → `display_out()`.
  - There is no second output path.
- **Determinism.** The terrain is deterministic by *float discipline*, not by fixed-point:
  - `+ - * / sqrtf` only, `-fno-fast-math -ffp-contract=off`, polynomial trig (`sincos_deg`);
  - native == WASM, proven by `make terrain-parity`.
  - New C code in `terrain.c`, `island_desc.c` and `climate.c` follows the same rules.
  - Authored data is stored as **integers** (decimetres, centimetres, millidegrees, permille) and converted to float once. That conversion is exact below 2^24, so the data is bit-identical on every platform.
- **Snapshot.** Main is snapshot **16**, stage engine version `CP_STAGE_VERSION 3`.
  - The island field (`CpStageField`) is attached by pointer and is not in the snapshot payload. Only its hash is in the 48-byte header.
  - So new **static, derived maps never bump the snapshot version.** They change the field hash: old saves fail with `CP_STAGE_SNAP_ERR_FIELD`, as they should.
  - Only new **mutable state** in `CpStageWorld` bumps the snapshot (weather, W1). Steps that touch it are marked **[SNAP]**.
- **Machine.** Software GL only:
  - `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a … --rendering-driver opengl3`;
  - `--check-only` first; `timeout`; `nice -n 10`;
  - one Godot process at a time;
  - kill only your own recorded pid.
  - Browser captures use SwiftShader. Blender bakes use Cycles on the **CPU** (`--cycles-device CPU`), never the GPU.
- **Never commit** reference photos or footage. They live in `~/Desarrollo/cpore-refs/look/<topic>/`, with licence notes in `docs/RESOURCES.md`.

## 1. What exists and what changes

| Area | Today | Where | Changes in this plan |
|---|---|---|---|
| Island shape | Star massif as a C table: `L1_F` feature list (`LF_MASSIF`, `LF_RANGE`, `LF_RING`, `LF_PLATEAU`, `LF_TERRACE`, `LF_BADLANDS`, `LF_CHANNEL`, `LF_ISLET`) and meta (`L1_R` regions, `L1_T` routes, `L1_M` marks). Design coordinates ×`LSCALE` 1.56. `layout_height()` evaluates it. `cp_terrain_layout_apply()` sets 8000 m, n 1536 and island radius 2450 m | `core/src/terrain_layouts.inc` | Becomes **data** (`CpIslandDesc`, §3), loaded from the island file. The layout table stays only as the parity reference for F0 |
| Pipeline | `fill_base` → multiscale `stream_power` (N/4, N/2) → `hydraulic` droplets → fine `stream_power` → `thermal` → `cliff_bands` → `flow_accum` → `carve_rivers` → `cave_entrances` → `river_water` → `material_map`. `gap_trail` is skipped for layouts | `core/src/terrain.c` `cp_terrain_generate` | Macro from the desc; a new `climate_maps` pass after `river_water`; `material_map` takes snow from the climate; trails come back for authored hints |
| Game island | Layout 0: the v4 ring island, 3.6 km, n 1024, seed 1 (`terrain_cache.gd` resolves `CporeTerrain.defaults()`) | `godot/game/game.gd` `settings.seed` | Switches to Star massif in **B1** |
| Lab tools | `maps.py` (relief, slope classes, reach), `shots.py`, `island_layout_shots.gd`, picker page, `stats.json` | `tools/island/`, `web/gaitlab/island*` | Gain a `--desc` input; the editor replaces the picker |
| WASM terrain | `cpore_terrain.wasm`, exports `_ct_generate`, `_ct_map`, `_ct_hash`… `make terrain-parity` | `apps/terrain_wasm_api.c`, `tests/test_wasm_terrain.mjs` | Add desc and climate exports; the editor preview runs on it |
| Flora | GDScript placement on a 20 m grid. Habitats from material, wetness, altitude and **`p.x < -110` = western fog forest** (old island). Recipes in `godot/game/data/flora.json`. Meshes built in code (`flora_mesh.gd`). MultiMesh per 64-cell chunk with `visibility_range` NEAR 90/135/190 m and FAR 460/720/1050 m by tier | `flora_placement.gd`, `island_props.gd` | Habitats from the climate maps; gameplay trees placed in C; Blender meshes + LODs + octahedral impostors |
| Grass | 252,000 blades: near ring 44 m, far ring 140 m, wrapped around the camera | `grass.gd` | Density from the climate; a third ring of clump cards to 250 m |
| Sky | 3-colour gradient + sun + 2D cumulus (1,800 m) + cirrus (7,000 m). Palette keys `K_*` in `day_night.gd`. Haze `aerial()` in display space after tone mapping; `ground_fog()` | `sky.gdshader`, `look.gdshaderinc`, `clouds.gdshaderinc` | Hillaire LUTs (§6); aerial perspective in linear space; night layers from `night-sky.md` |
| Ground | Photo rock atlas (8 ambientCG CC0 layers, albedo + normal/height), biplanar/triplanar, a two-tap "stochastic" fetch (`ph_stochastic`) | `rock_photo.gdshaderinc`, `rock_mapping.gdshaderinc`, `godot/game/textures/CREDITS.md` | Soil, litter, grass ground, mud, sand and snow layers; hex-tiling; roughness; detail octaves; biome weights |
| Sim | `CpStageField {n, size_m, cell, half, height, water_level, hash}`. Obstacles ≤ 1024 in the setup. Trees are not obstacles | `world.h` | Field gains `cover` (undergrowth) and `trunks` (static trunk grid), both hashed. No snapshot change |

## 2. The review camera path (step P0, used by every step)

A98 asks for "a fixed orbit-to-ground camera path with screenshots after each change". One script, one make target, the names `tools/look/score.py` already parses (`<tier>_<tod>_<shot>.jpg`).

- **Script:** `godot/game/tests/island_path_shots.gd`. It builds the island like `island_layout_shots.gd`, forces `day_night.force_hour` and freezes clouds with `Clouds.frozen_time`.
- **Target:** `make godot-island-path LABEL=<label> [TIER=low|medium] [SHOTS=OG2,OG5]`. It writes `docs/evidence/island/path/<label>/`, plus `times_<tier>.json` (software-GL ms per frame, a relative number only) and a contact sheet.
- **Compare:** `python3 tools/look/compare.py <labelA> <labelB>`, plus the §7 failure list of LOOK, through `score.py`.
- **Times of day:** dawn 06:30, midday 12:30, dusk 18:40, night 23:00. Tiers low and medium under software GL. High is run by the owner on the RTX (`make godot-terrain-bench TIER=high` style, Q14).

Coordinates are world metres. The nest is at the origin; x is east; z is the map's y, **south positive**. Design points convert by ×1.56.

| Shot | Camera position (x, altitude, z) | Looks at | What it judges | Available from |
|---|---|---|---|---|
| OG0 | orbit, 400 km over 27° N (night-sky §3.1 observer) | planet limb | atmosphere from space, cloud field | O1 |
| OG1 | (0, 60 km, 0) | straight down | island in its sea, reef colour, cloud cap | O1 (before that, 12 km) |
| OG2 | (3500, 12000, −3500), NE over the sea | Crown Horn (−468, 600, −374) | **rain shadow**: green NE vs brown SW, the orographic cloud cap | P0 |
| OG3 | (1800, 3000, −2400) | (−300, 300, −200) | forest belt edges, canyon, mesa, aerial perspective | P0 |
| OG4 | (−300, 800, 2200), S of the canyon | (−936, 80, 1186) | badlands, canyon walls, desert ground | P0 |
| OG5 | over the forest vale (874, 150 AGL, −1076) | NE along the vale | **canopy flyover**: impostor range, closure from above | P0 |
| OG6 | forest edge from the meadow (520, 4 AGL, −640) | (874, 10 AGL, −1076) | LOD and impostor transitions at 40–100 m, edge structure | P0 |
| OG7 | under the canopy on a game trail (940, 1.8 AGL, −1180) | along the trail | under-canopy light, undergrowth, trail readability, a climbable trunk | P0 (after B2 it means something) |
| OG8 | nest valley at chase height (0, 2.5 AGL, 40) | the north pass (390, 60, −515) | the start view, grass to 250 m, ground tiling | P0 |
| OG9 | creature close-up at the nest (existing `creature_dist`) | creature | creature readability against the new ground | P0 |

**Built (P0, 2026-11-24):**
- `make godot-island-path [LABEL=<name>] [PATH_TIER=low|medium|low,medium] [LAYOUT=1|0] [ISLAND=<params.json>] [SHOTS=OG2,OG5] [TODS=dawn,night] [PATH_OUT=<dir>]`. The tier variable is `PATH_TIER`, not `TIER`, because `TIER` already drives `godot-terrain-bench`.
- `LAYOUT=1` (default) is the Star massif lab island; `LAYOUT=0` is the game's own island; `ISLAND` points at a terrain params JSON (the `params` object of `terrain_cli layout-json`, or a whole island file later), so F4, B1 and later steps reuse the same path.
- Script `godot/game/tests/island_path_shots.gd` (the shot table is at the top); sheet `tools/island/path_sheet.py` (rows = times of day, columns = OG0..OG9).
- Output per tier: `<tier>_<tod>_OGn.jpg`, `times_<tier>.json`, `path_<tier>.json` (the exact camera of each frame), `sheet_<tier>.jpg`. Default folder `docs/evidence/island/path/<date>-<hash>`; pass `PATH_OUT` for a folder outside the repo.
- No wildlife (`wild = false`), frozen clouds, `--fixed-fps 30`, fixed hours, so runs repeat.
- **OG0 and OG1 are stand-ins** until O1 (no planet or orbit sky exists yet): OG0 is a 20 km oblique view, OG1 is 12 km straight down. They are marked `stand_in` in `path_<tier>.json`.
- OG8's look-at height 60 is read as metres above ground. OG7 looks 40 m ahead along Exit 2.

**P0 acceptance:**
- two runs at the same label are pixel-identical (same convention as `godot-look-score`);
- runs on the current layout-1 lab island;
- the baseline label `island-p0` is committed as JPG, with the evidence README.

## 3. Part I: freeze Star massif

### 3.1 Data format
One human-edited source file, one binary the C core reads, one generated C include for the shipped island.

| File | Role |
|---|---|
| `data/islands/star_massif.island.json` | **Source of truth.** Written by the editor; reviewed in git diffs; integers only |
| `tools/island/pack.mjs` (+ `web/gaitlab/island/pack.js`, the same module) | JSON → binary `CpIslandDesc` blob, little-endian, versioned, CRC-32. **One packer**, shared by node and the browser |
| `core/src/islands/star_massif.inc` | Generated by `make island-pack` (a `static const uint8_t` array); committed. The shipped game needs no file I/O in core |
| `godot/game/data/islands/star_massif.isl` | The same blob, for the extension and dev tools |

The JSON shape below is the contract for F1 and F2:
- Units: positions in **decimetres** of world metres; heights in **centimetres**; angles in millidegrees; factors in permille.
- Each kind maps onto today's `LFeat` kinds, plus two generalisations: **polylines** for ranges and channels, and **masks**.

```json
{
  "format": "primigenia.island/1",
  "id": "star-massif",
  "size_dm": 80000, "island_radius_dm": 24500, "n": 1536,
  "wind": {"dir_mdeg": 135000, "speed_cms": 800},
  "climate": {"scale_h_pm": 8000, "scale_z_pm": 2500, "t_sea_cC": 1400, "lapse_cK_per_km": 620},
  "nest": {"r_dm": 1900, "floor_cm": 4200, "lake": {"x_dm": -1500, "y_dm": 700, "r_dm": 680, "depth_cm": 3400}},
  "features": [
    {"kind": "massif", "x_dm": -4680, "y_dm": -3744, "across_dm": 6708, "along_dm": 8112, "axis_mdeg": 20000, "h_cm": 64000, "name": "Crown Horn"},
    {"kind": "range", "pts": [[-4680,-3744,3900,33000],[686,14992,3900,9000]], "rugged_pm": 800, "name": "S spur"},
    {"kind": "channel", "pts": [[0,0,1716,3800],[7020,6552,1716,2600],[14820,12792,1716,1200],[21528,15912,1404,0]], "wall_dm": 4056, "sea": 1, "river": 1, "name": "Exit 1: river valley"},
    {"kind": "plateau", "x_dm": -16536, "y_dm": -8736, "r_dm": 4212, "cliff_dm": 780, "top_cm": 49000, "name": "Mesa"},
    {"kind": "terrace", "x_dm": 12168, "y_dm": 5928, "r_dm": 7332, "feather_dm": 4056, "step_cm": 2400, "k_pm": 900},
    {"kind": "badlands", "x_dm": -8736, "y_dm": 15600, "r_dm": 6240, "amp_cm": 13000, "freq_pm": 1000},
    {"kind": "islet", "x_dm": 18408, "y_dm": -16536, "r_dm": 2496, "top_cm": 17000, "bay_dm": 6240}
  ],
  "trails": [{"pts": [[0,0],[3900,-5148],[8736,-10764]], "kind": "game_trail"}],
  "regions": [{"name": "Forest vale", "kind": "forest", "biome": "jungle", "gate": 0, "w_dm": 5928, "pts": [[4680,-5928],[8736,-10764]]}],
  "marks": [{"name": "Great tree", "kind": "tree", "x_dm": 9672, "y_dm": -11856}],
  "masks": {"res": 128, "climate_bias": "<base64 u8, 128 = neutral>", "canopy": "<base64>", "erosion": "<base64>", "protect": "<base64>"}
}
```

**Rules:**
- **Wind convention (verified in M2).** `wind.dir_mdeg` is the direction the wind blows TOWARD, as `atan2(y, x)` in map axes (x east, y south), in millidegrees. The Star massif's NE trade wind blows toward the south-west: `(-0.7, 0.7)` = **135000**, which is what `from_layout.mjs` writes. (The 225000 this example carried before M2 was a placeholder; it would be a wind from the SE.) `tests/test_terrain_climate.c` pins it: under 135000 the NE side of the island is the wet one, under 315000 the SW side.
- **Climate calibration block (M2).** `climate.calib` holds sixteen optional integers, an own header flag (bit 0 of the u16 flags) and 64 bytes after the masks; 0 or absent means the kernel default. Keys and units are `CALIB_KEYS` in `pack.mjs` and `CP_ISL_CAL_*` in `island.h`.
- **Polylines:** each point is `[x_dm, y_dm, half_width_dm, height_cm]`. They are evaluated as **centripetal Catmull–Rom**, sampled at a fixed 16 segments per span into a segment list. The parameter spacing uses `sqrtf(sqrtf(d²))` = d^0.5, so the sampling stays inside the float rules. Distance to the curve is the existing `seg_dist`, and height and width are interpolated along it.
- **Masks:** 128² u8 over the 8 km square (62.5 m texels), sampled bilinearly. Four masks:
  - `climate_bias`: ±50% on the precipitation; the art lever for "make this valley wetter";
  - `canopy`: forest allowed (255) or barred (0); authors the forest-belt edges A97 asks for;
  - `erosion`: a multiplier on droplet and stream-power strength (calm the nest, roughen the badlands);
  - `protect`: cells that keep their authored height through erosion (nest floor, mesa ramps).
- **Limits** (no malloc; POD): 96 features, 1,024 polyline points, 32 trails, 24 regions, 32 marks, 4 masks. `sizeof(CpIslandDesc)` ≈ 90 KB; it lives in the caller's memory, like the workspace.
- **A97 authored list** (all must exist as data):
  - the spine and Crown Horn (massif + ranges);
  - the canyon (channels);
  - the forest-belt edges (`canopy` mask + region);
  - rivers (channels with `river: 1`, whose floor is cut 2 m below the valley floor so drainage follows them);
  - the nest valley (`nest`);
  - the mesa ramps (a channel with `protect`);
  - the paths (`trails`).

### 3.2 Generation
- **New header** `core/include/cpore/island.h`:
  - `CpIslandDesc` (POD; integer fields plus the float cache that `cp_island_prepare` fills);
  - `int cp_island_parse(const uint8_t *blob, size_t len, CpIslandDesc *out)` (magic `"ISL1"`, version, CRC; returns `CP_TERR_ERR_*`);
  - `uint64_t cp_island_hash(const CpIslandDesc *)`.
- **Terrain:** `int cp_terrain_generate_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out, const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user)`.
  - `cp_terrain_generate` keeps its signature and calls it with `d = NULL` (layouts 0..4 unchanged).
- **Macro from data, micro from the seed:**
  - `island_height(p, d, x, y)` is `layout_height()` with its loops reading `d->feat[]` instead of `LAYOUTS[]`.
  - Everything the seed drives stays seeded: domain warp (`fbm` with `S ^ 0xA341316C`…), ridged detail (`rd`, `rd2`), `spur` lobes, coast noise (`a_coast`, `a_coast2`), channel wobble, terrace contour wobble, badlands buttes, droplets, cave picks.
  - Changing the seed changes the micro relief and the erosion, never the spine, the exits or the regions (Q1).
- **Erosion masks:** `erosion_mask(d, x, y)` multiplies `erode_scale_at()`. `protect` cells are restored to `max(eroded, authored − 0.5 m)` after `thermal()`, so the nest floor and the ramps survive.
- **Authored trails** come back for desc islands (today `gap_trail` is skipped for layouts). For each `trails[]` polyline, `trail_walk` on `trail_costs` finds the walkable route near the hint (a corridor of ±40 m), and `trail_carve` flattens it to the 51.6° grip rule (A66). Game trails also set the `cover` map to 0 later (M3).
- **F1 as built** (details in `core/include/cpore/island.h`):
  - **Splines:** `spline: 1` on a range or channel makes the polyline a centripetal Catmull–Rom curve through its points (end points exact; phantom end points are reflected), 16 evaluator segments per span; width and height are splined with x and y. `CP_ISL_MAX_EVAL` is 4096 (about 250 spline spans); more is `CP_TERR_ERR_ISL_LIMIT`.
  - **Noise index:** the per-feature noise offsets use the running count of **control spans** (one per non-polyline feature, one per control segment of a polyline). For straight polylines that is the evaluator-entry position, so layout-1 parity holds. A spline span gives its 16 sub-segments one index, so toggling a spline never moves another feature's noise, and the along-range noise runs on through the sub-segments (`a0`).
  - **Masks** (slots: climate_bias, canopy, erosion, protect): bilinear, 128 neutral and exact. `erosion` multiplies stream-power and droplet strength by `v/128` (0..1.5); `protect` above 128 holds the cell within `0.5 m / ((v-128)/127)` of its authored height, applied after the cliff bands, again after the rivers and after the trails.
  - **Trails:** kinds `game_trail` and `path` are routed (±40 m corridor around the hint, waypoints snapped within 20 m) and graded to 0.30 rise over run; other kinds (`exit`) stay descriptive. A trail that cannot be joined inside its corridor is skipped whole. Needs n ≥ 512.
  - **v5 hash:** `CpTerrain.island_hash` (0 for layouts) is mixed in after the version word. The F0 parity gate is now: the desc terrain with `island_hash` cleared hashes like `--layout 1`.
- **Version:** `CP_TERRAIN_VERSION 5`. `cp_terrain_hash` adds `cp_island_hash(d)` after the version when `d` is set. The `terrain_cache.gd` key gains the island id and desc hash.

### 3.3 Compatibility, goldens and how tests move
| Thing | What happens |
|---|---|
| Layout 0 (v4 ring island) and its goldens `tests/golden/terrain-*.hash`, `terrain-v2-maps.json` | **Unchanged, byte for byte.** `cp_terrain_generate` with `d = NULL` takes the same path |
| Layout 1 → desc parity (F0) | `tools/island/from_layout.mjs` converts `L1_F/L1_R/L1_T/L1_M` × 1.56 to `star_massif.island.json`, with straight-segment polylines (Catmull–Rom off, `"spline": 0`). **Gate:** the desc island hashes **identically** to `--layout 1` at n 256, 512 and 1536. This proves the evaluator, not just a lookalike |
| New goldens | `tests/golden/island-star-<seed>.hash` for seeds 1, 7, 42 at n 512 (fast) plus seed 1 at n 1536 (`--heavy`). WASM parity runs the same blobs (`tests/test_wasm_island.mjs`) |
| `test_routes.c`, `test_first_quest.c`, `test_secrets.c`, `test_nav.c` | Stay on layout 0 until **B1**. B1 adds island-star variants (`--island star`), re-certifies the routes on the new map, then retires the layout-0 variants. Separate commits, so a reviewer sees each hash move once |
| Snapshot | **No version change** in F0–F5. B1 changes the field hash: saved states and `godot/scenarios/creature/*.json` (made on the ring island) stop restoring with `CP_STAGE_SNAP_ERR_FIELD`. B1 re-records the five creature scenarios on the nest valley |
| Combat goldens | Untouched (no terrain) |

### 3.4 The browser map editor (phone-usable)
Page: `web/gaitlab/island_editor.html` + `island_editor.js` + `island/pack.js`. It replaces the picker as the island's home page.

- **Faithful preview: the same C, compiled to WASM.**
  - `cpore_terrain.wasm` gains `_ct_desc_set(ptr, len)` (parse into a static desc), `_ct_generate_desc`, `_ct_shape_desc` (base height only, no erosion) and `_ct_climate` (M2).
  - The preview is not a JS port. It is `island_height()` itself, so what the owner sees is what the game builds.
  - The page shows the desc hash, the terrain hash, and "matches native build <git short hash>". `make island-editor-check` regenerates the expected hash with the native CLI for the committed file.
  - **Needs `emcc`.** It is not on PATH here; the Makefile looks for `~/emsdk/emsdk_env.sh`. The built `.wasm` exists in the owner's main checkout `build/wasm/`. If emsdk is not installed, the owner must approve installing it (AGENTS: no emsdk without asking; Q12).
- **Three preview levels:**
  - **Shape:** base only at 256² while dragging (75 ms native; expect ~150 ms WASM). The worker answers the last request only.
  - **Eroded:** full pipeline at 512² on release (0.9 s native, ~2 s WASM, in a Web Worker).
  - **Bake:** n 1536 on demand (9 s native, ~20 s WASM), with the slope/reach overlays.
- **Layers:**
  - shaded relief;
  - slope classes (the `SLOPE_RGB` scheme of `maps.py`: walk, steep, climb 51.6°, cliff);
  - plain and climber reach from the nest (a JS port of `maps.py grid_paths`, at 256², for a live check only);
  - regions, routes, marks, masks;
  - climate (precipitation, biome, cloud cap) after M2.
- **Edit:**
  - drag control points; add or delete points on a polyline; change width and height with a slider in the inspector;
  - paint masks with a soft brush (radius, strength, erase);
  - move marks and regions;
  - undo/redo (50 steps); numeric entry for exact values.
- **Validation panel** (red/green, live at the shape or eroded level). These are the A83/A95 guarantees:
  - nest floor flat (`valley_flat` ≥ 0.85, as `terrain_cli stats`);
  - 4 exits walkable;
  - mesa reachable only by climbing (`core_climb_only_pct` ≥ 80);
  - islet gated;
  - forest vale ≥ 1.5 km² of land under the canopy mask;
  - land area 16–18 km² (A97 keeps the size).
- **Phone:**
  - one column, the map on top and a bottom-sheet inspector;
  - handles with a 44 px hit radius; pinch zoom, two-finger pan;
  - a long press adds a point;
  - the Emil rules (ease-out, ≤ 250 ms, press scale 0.97, no animation on keyboard actions);
  - it works at 360×740.
- **Save:**
  - "Download island.json", plus "Copy" (clipboard, with a textarea fallback as `island.html` has today);
  - a draft autosaved in `localStorage`;
  - optional: publish the editor as an artifact with a shared store, so phone saves reach Claude without a file transfer (Q11).
  - The committed source changes only when an agent commits the owner's JSON (F4).
- **Tests:**
  - `node tools/island/editor_check.cjs`: the same blob gives the same terrain and climate hashes in WASM and native; packer round trip; validation numbers equal `maps.py --desc` within 1%;
  - a SwiftShader screenshot at 360×740 and 1280×800.

- **F2 as built:**
  - Files: `web/gaitlab/island_editor.html`, `island_editor.js`, and `island/` (`pack.js` is a copy of `tools/island/pack.mjs`, `model.js`, `analysis.js`, `engine.js`, `terrain_worker.js`, `wasm/cpore_terrain.{mjs,wasm}`, `star_massif.island.json`, `expected.json`). `make island-editor-assets` refreshes the copies; `make island-editor-check` runs `tools/island/editor_check.cjs` (node) and `editor_page_check.cjs` (Chromium on SwiftShader).
  - New C: `cp_terrain_shape_desc` (every erosion pass off), exported as `_ct_shape_desc`; `terrain_cli hash --desc F --base` runs it. The terrain WASM now takes n up to 1536 (the bake), arena 67 MiB.
  - Hosting API: `window.IslandEditor.exportJSON()` / `importJSON(text)` and an `IslandEditor.events` `change` event carrying the JSON, so a hosting artifact can mirror edits to a store.
  - `expected.json` holds the native hashes of the committed island (seed 1: shape 256, eroded 512, bake 1024 and 1536); the page says "matches native build" only for that island at those levels, and prints the `terrain_cli` command for an edited one.
  - Validation numbers come from `analysis.js` (a port of `terrain_cli maps` and the `maps.py` region and route code); the check holds them to `maps.py` within 1 point (areas 1 to 2%).

- **F4 as built (A101, the owner froze Star massif as it is; F3 skipped):**
  - Source `data/islands/star_massif.island.json` (the editor's export format, moved from `web/gaitlab/island/`). `make island-pack` (`tools/island/freeze.mjs`) packs it twice (must match) and writes `godot/game/data/islands/star_massif.isl`, `core/src/islands/star_massif.inc` (compiled into libcpore; `cp_island_star_massif(&len)` in `island.h`) and the editor's byte copy `web/gaitlab/island/star_massif.island.json`. `make island-pack-check` (part of `island-test`) fails on a stale copy.
  - Blob 4,504 bytes, crc32 `4741cef1`, desc hash `eab02da256cfeae6`. Masks are not authored (the climate calibration block is).
  - Goldens `tests/golden/island-star-<seed>.hash`, lines `n terrain-hash climate-hash`: seeds 1, 7, 42 at n 512; seed 1 also n 1536 (`island-test-heavy`). `tests/test_island_star.c` checks them and that the compiled-in blob equals the `.isl`; `tests/test_wasm_island.mjs` checks the n 512 lines in WASM. Regenerate on purpose: `./build/island_star_test --heavy --write-golden`.
  - `maps.py --names <island.json>` names the routes (the blob keeps no trail names). The maps were regenerated from the frozen blob; `stats.json` came out the same as before (v5 == layout-1 stats), and `star-massif-{precip,biome,veg,cloud}.jpg` plus `star-massif-climate-gates.json` were added.

### 3.5 Steps F0–F5
| # | Step | Files | Tests | Gate |
|---|---|---|---|---|
| **F0** | Desc evaluator + parity with layout 1 | `island.h`, `core/src/island_desc.c`, `terrain.c` (`island_height`, `cp_terrain_generate_desc`), `tools/island/from_layout.mjs`, `tools/island/pack.mjs` | `tests/test_island.c`: parse errors, CRC, limits; hash(desc from L1) == hash(`--layout 1`) at 256/512/1536 | identical hashes; `make test` and `make terrain-test` green; layout-0 goldens untouched |
| **F1** | Splines, masks, protect, trails; terrain v5; WASM exports | `island_desc.c`, `terrain.c`, `apps/terrain_wasm_api.c`, `apps/terrain_cli.c` (`--desc file`), `terrain_cache.gd` key | `test_island.c` (Catmull–Rom endpoints pass through control points; masks bilinear; `protect` keeps ±0.5 m; trails walkable); `tests/test_wasm_island.mjs` | native == WASM for 3 seeds; `maps.py --desc` stats within 2% of the layout-1 `stats.json` with splines off |
| **F2** | Map editor | `web/gaitlab/island_editor.*`, `island/pack.js` | `editor_check.cjs`; SwiftShader shots | phone layout works; preview hash == native; validation == `maps.py` within 1% |
| **F3** | Owner tuning session | the JSON only | the editor's validation panel | owner says "freeze" (tracker test I1) |
| **F4** | Freeze | `data/islands/star_massif.island.json`, generated `core/src/islands/star_massif.inc`, `godot/game/data/islands/star_massif.isl`, goldens, `web/gaitlab/island/` maps regenerated | `make island-pack` reproducible (same bytes twice); goldens added | all gates green; maps and stats committed |
| **F5** | Climate-aware tuning (after M2) | JSON (`climate_bias`, `canopy`) | M-gates on the regions (§4.5) | owner signs off the climate maps (tracker I2) |

## 4. Part II: moisture simulation in C

### 4.1 The model (Smith & Barstad 2004, linear theory of orographic precipitation)
Quoted from the authors' extended abstract (AMS 2003), which gives the JAS 2004 equations.

- **Steady advection of condensed water:**
  - (1a) `U·∇q_c = S(x,y) − q_c/τ_c`
  - (1b) `U·∇q_h = q_c/τ_c − q_h/τ_f`
  - Here `q_c` is cloud water, `q_h` hydrometeors, and `P = q_h/τ_f` the rain at the ground. The source is upslope condensation, `S = C_w U·∇h`.
- **The transfer function** (eq. 2), from the Fourier transform of the terrain `ĥ(k,l)` to the Fourier transform of precipitation:
  `P̂(k,l) = C_w i σ ĥ(k,l) / ( [1 − i m H_w] [1 + i σ τ_c] [1 + i σ τ_f] )`
  - `σ = U k + V l` is the intrinsic frequency.
  - (3) `m = { [(N_m² − σ²)/σ²] (k² + l²) }^½` is the vertical wavenumber.
  - (4) `C_w = ρ_v0 Γ_m / γ` is the uplift sensitivity.
  - "The negative sign in the dynamics factor gives an upwind shift… the positive signs in the cloud factors cause a downstream shift."
  - With `m = τ_c = τ_f = 0` it reduces to the classic upslope model (Smith 1979). **That is our analytic unit test.**
- **Truncation:** "downslope evaporation… is present when the predicted field is truncated according to `P_trun = max(P, 0)`". The JAS paper adds a background rate, `P = max(P + P∞, 0)`; verify the exact form in JAS §2 before coding.
- **Branch of m:** for `N_m² > σ²` (propagating waves) take `m = sgn(σ)·√(…)`; for `σ² > N_m²` (evanescent) take `m = i·√((σ²−N_m²)/σ² · K²)`. This is the standard choice in the JAS paper; the implementer confirms it there.
- **Reference parameters** (the abstract's examples):
  - `T₀ = 280 K`, `γ = −5.8 °C/km`, `Γ_m = −6.5 °C/km`, `U = 15 m/s`, `N_m = 0.005 s⁻¹`, `ρ_Sref = 7.4 g/m³`, `H_w = 2500 m`, `τ_c = τ_f = 1000 s`;
  - the Olympic Mountains example: SW wind 15 m/s, 280 K, 6.2 g/kg, moist layer 2.5 km, 1000 s delays, 26 mm in 6 h just upwind of the 2428 m peak.
- **Cloud water for the weather map** (derived from 1a): `q̂_c = τ_c Ŝ_dyn / (1 + i σ τ_c)`, with `Ŝ_dyn = C_w i σ ĥ / (1 − i m H_w)`. This is the orographic cloud cap, at no extra cost. The efficiencies `PE_dyn = S_dyn/S_ref` and `PE_cloud = P/S_dyn` (eq. 5) are logged for tuning.

**Why the island needs a climate scale.** At true scale a 5 km island makes no rain shadow. With trade wind `U = 8 m/s`, the island's wavenumber is `k ≈ 2π/5000 = 1.26·10⁻³ m⁻¹`:
- `σ ≈ 0.01 s⁻¹`, twice `N_m`, so the uplift is evanescent and reduced by `|1 − i m H_w| ≈ 3.7`;
- `σ τ ≈ 10`, so each cloud factor cuts the amplitude about 10×;
- the condensate drifts `U τ ≈ 8 km`, which is off the island and into the sea.

That is real physics: islands this small do not wring rain out of the trades. The A86 rain shadow comes from islands of 40–80 km (Tenerife, Kaua'i, La Palma).

So the model runs in **climate coordinates**:
- horizontal ×`scale_h` (starting value 8: the island behaves like a ~40 km island);
- vertical ×`scale_z` (starting value 2.5 = canon summit 2,050 m / generated 824 m, F7).

Then `σ ≈ 0.0013 s⁻¹ < N_m` (propagating), `σ τ ≈ 1.3`, and the drift is ~8 km in climate units (1 km in game units). This gives a windward maximum just upwind of the crest and a dry lee. Both scales are in the island file (Q3, Q4).

**The real analogue** is Tenerife and La Gomera: NE trade winds, wet laurel cloud forest (laurisilva) on the windward NE slopes under the trade-wind cloud belt ("mar de nubes"), and a dry SW. The Star massif already has its jungle on the wet NE and its desert in the SW lee (`LAYOUT_ROW` wind `(−0.7, 0.7)` is the direction of travel, so the wind comes from the NE).

Two consequences:
- The "jungle" at canon temperatures (F15: 14 °C at sea level) is a **humid subtropical cloud forest**, not a lowland tropical rainforest. That fits the lore's Nieblón fog-drip forest. The look study (§5) uses laurisilva and Hawaiian windward forest as its references.
- Canon F18 says westerlies make the *west* wet. The map is NE-wet, so the lore follows the map (Q2).

### 4.2 What it outputs (all deterministic, generation time only)
`climate_maps()` runs inside `cp_terrain_generate_desc` after `river_water`, before `material_map`. Grid: **256²** over the 8 km square (31 m texels). The physics is smooth at that scale, and the FFT is cheap.

**Outputs:**
- `CpTerrain.climate` (caller-owned, `256*256*4` bytes, RGBA8):
  - R precipitation (0–4,000 mm/yr, linear);
  - G temperature (−10..+30 °C);
  - B cloud water `q_c` (normalised);
  - A fog frequency.
- At `n`, bilinearly upsampled:
  - `CpTerrain.biome` (u8 id: sea, reef, beach, meadow, jungle, dry forest, scrub, desert, badlands, alpine, tundra, snow, cliff);
  - `CpTerrain.veg` (RGBA8: R canopy density, G undergrowth, B grass density, A litter/moss wetness).

**Steps of the computation:**
1. **Heights:** downsample to 256² (box filter of the eroded height, sea clamped to 0), then scale to climate coordinates.
2. **Spectral solve:**
   - a radix-2 complex FFT, own code; twiddles from the `sincos_deg` polynomial, so there is no libm;
   - zero-pad to 512² so the island's lee is not wrapped onto its windward side;
   - apply eq. (2) per wavenumber, with the m-branch rule above; `σ = 0` → `P̂ = 0`;
   - inverse FFT; truncate.
   - Cost: 2 × 512² complex FFTs ≈ 20 M flops, a few ms.
3. **Two wind regimes**, weighted into one year:
   - trades from the island's `wind` (75%, 8 m/s);
   - storms from the opposite quarter (25%, 15 m/s; F8 "evening convection storms", F19 winter gales).
   - Annual `P = 8760 h × Σ wᵢ Pᵢ + P∞`. Calibrated so that:
     - the windward maximum is 3,000–4,000 mm/yr (Hilo, Hawai'i, ≈ 3,200 mm);
     - the lee minimum is 150–300 mm/yr (leeward Hawai'i and south Tenerife, 100–250 mm).
   - `climate_bias` multiplies the result.
4. **Temperature:** `T = t_sea − lapse × h × scale_z` (F15: 14 °C, 6.2 K/km), plus −1.5 °C on slopes facing away from the sun (the existing `gy` aspect term in `material_map`), plus +1 °C in the lee (föhn).
5. **Snow:** where `T_winter = T − 7 °C < 0` and `P > 400 mm`. This replaces `h > 365 − gy·45` in `material_map`. With the scales above, the canon snowline at 1,750 m lands at ~700 m game height on shaded slopes (Q3).
6. **Fog frequency:**
   - the trade-wind inversion belt (canon 900–1,500 m, i.e. 360–600 m game at `scale_z` 2.5) on windward slopes, times `q_c`;
   - plus the valley fog trap F8 (concave cells below 100 m with low `flow` gradients; this generalises `ground_fog()`'s hard-coded "east of x = 0").
7. **Biome:** a **Whittaker (1975) biome diagram** lookup on (annual P, mean T), then terrain overrides:
   - slope > 1.05 → cliff/rock (as `material_map` today);
   - the sea classes from depth and the reef direction;
   - `canopy` mask 0 → no forest class.
   - The table lives in `core/src/climate_biomes.inc` and is cited row by row.
8. **Vegetation:**
   - canopy density `= smoothstep(P_forest_min, P_forest_full, P) × canopy_mask × soil`, where `soil` is 0 on rock and scree, ½ on young volcanic rock (FLORA succession);
   - undergrowth `= canopy × (0.6 + 0.4·wetness)`;
   - grass `= (1 − canopy)·smoothstep(250, 800, P)`.
9. **Cloud weather map** for the sky (H) and the clouds (V): RGBA8 256², laid out like Schneider & Vos's weather map ("Red is coverage, Green is precipitation and blue is cloud type"):
   - R coverage from `q_c` and the fog belt;
   - G precipitation;
   - B type: 0 stratus deck on the windward belt, 0.5 stratocumulus, 1 the afternoon cumulus cap over the summit.

### 4.3 How the game and the sim consume it
- **Flora** (`flora_placement.gd`):
  - `habitats()` reads `d.biome` and `d.veg` at the site instead of `p.x < -110` and the `mat == 0 and h < 300` meadow rule;
  - `flora.json` recipes gain `"climate": {"p_mm": [min, max], "t_c": [min, max], "canopy": [min, max]}`; the old `altitude` stays as a hard limit;
  - the zones `forest`, `litter`, `shade`, `meadow`, `snowline`, `bank`, `spray`, `hollow`, `wet_fringe`, `valley_edge` and `disturbed` are recomputed from biome + veg + the existing bank/cave tests;
  - spacing changes too: forest cells use a 6 m grid, not the global 20 m `SPACING`, via a per-biome spacing table.
- **Gameplay trees move to C:** `cp_flora_trunks()` in the new file `core/src/flora_place.c` places only **trunks that matter to the sim**: radius ≥ 0.3 m (blocking), climbable (A59, A97), and landmark trees (Madre de agua).
  - Inputs: `veg` and the seed, on a 6 m jittered grid with Poisson rejection.
  - Output: records (x, z, radius, height, species id), stored in the field as a static spatial hash.
  - Godot reads the records for the big trees (no second placement). GDScript keeps the purely visual small flora.
- **Grass:** `grass.gdshader` samples `veg.B` through a new `veg_tex`, so density follows the climate (no grass in the desert, lush on the delta).
- **Terrain shader:** biome and veg drive the ground material weights (G1).
- **Sim (`CpStageField`):** gains `const uint8_t *cover` (undergrowth 0..255 at sim resolution) and `const CpStageTrunks *trunks`, both covered by `field.hash`.
  - Movement: speed × `lerp(1, 0.6, cover/255)` in undergrowth, × 1.15 on game trails (cover is 0 there). Starting values, checked by the loop score.
  - Trunks are circle obstacles for nav and steer.
  - **No snapshot change** (static and derived), but the stage behaviour changes, so bump `CP_STAGE_VERSION` 3 → 4 in M3.

### 4.4 When it runs
At island generation, inside the same deterministic call and the W13 loading screen. It is cached with the terrain, so `terrain_cache.gd` stores `climate`, `biome` and `veg`. The shipped island is pre-baked. There is no runtime climate; weather is a separate state (§12).

### 4.5 Steps M0–M4
| # | Step | Files | Tests | Gate |
|---|---|---|---|---|
| **M0** | Python reference | `tools/climate/lt_ref.py` (numpy; eq. 2 with the m-branch rule) + `tools/climate/README.md` with the paper quotes | reproduce the abstract's triangle-ridge figure qualitatively (dynamics shifts the peak upwind; delays cut it and shift it downstream); Gaussian-hill cases | figure JPG in `docs/evidence/island/climate/ref/` |
| **M1** | C kernel (pure) | `core/include/cpore/climate.h`, `core/src/climate.c` (FFT, LT, temperature, biome, veg), `climate_biomes.inc` | `tests/test_climate.c`: (a) `m = τ = 0` equals the upslope `C_w U·∇h` within 1e-4 relative; (b) C vs `lt_ref.py` fixtures within 1e-3 of the max on 4 terrains; (c) wind rotated 90° = map rotated 90° (on a square, exact up to resampling); (d) hash stable over 3 runs, gcc/clang, -O0/-O2 | all pass; ≤ 15 ms native for 256² (padded 512²) |
| **M2** | Pipeline + WASM + editor layer | `terrain.c` (`climate_maps`), `CpTerrain` fields, `apps/terrain_wasm_api.c` (`_ct_climate`), `cpore_terrain.cpp` (dict keys `climate`, `biome`, `veg`), `terrain_cache.gd`, `maps.py --climate` | WASM parity of the climate maps; terrain v5 goldens extended | **Region gates on Star massif:** ≥ 80% of the "Forest vale" region polygon classifies as forest/jungle; ≥ 70% of "Canyon badlands" as desert/badlands/scrub; mesa top is tundra or alpine; the nest valley is meadow; windward/lee annual P ratio ≥ 8 (Hilo ~3,200 mm vs Waikoloa ~250 mm gives ~13); snow only above 600 m game |
| **M3** | Sim: cover, trunks, trails | `core/src/flora_place.c`, `world.h` (`CpStageField`), `stage_world.c` (speed, nav obstacles), `CP_STAGE_VERSION 4` | `test_nav.c` forest cases; `make nav-test` 20/20; `test_world.c` field hash covers cover and trunks | nav gate 20/20 on the star island; a creature crosses the forest vale by trail in ≤ 70% of the off-trail time |
| **M4** | Flora consumes the climate | `flora_placement.gd`, `flora.json`, `grass.gd`, `grass.gdshader`, `terrain_data.gd` (`veg_tex`, `biome_tex`) | `godot/game/tests/flora_climate_test.gd` (counts per biome; no tree in desert cells; Madre de agua at the spring) | OG2/OG3 show the rain shadow; owner eyeball (tracker I2) |

**M2 as built (2026-11-24):** the pipeline, WASM, Godot and cache plumbing are in (details and file list: `tools/climate/README.md`, "M2"). Calibration lives in the island data as a `climate.calib` block. On the Star massif all six gates pass for seeds 1, 7 and 42 (numbers, images and the tuning method: `docs/evidence/island/climate/star/README.md`). Two readings of the gate text and two known gaps:
- the forest and canyon percentages leave the terrain overrides (cliff, beach) out of the denominator (the all-land numbers are in the JSON: 79.8 and 74.2); the mesa top is the region's cells within 10 % of its highest ground; windward/lee is the 95th percentile of land precipitation over the Canyon badlands mean (the vale over the canyon is 5.2);
- the tuned constants differ from the starting values: `rain_scale` 0.22, `p_inf` 250, `tau` 800 s, trade share 0.88, storm speed 25 m/s, `qc_ref` 3; the summits then get about 9,000 mm/yr, far over the 3,000 to 4,000 windward target, and the RGBA8 precipitation map saturates at 4,000;
- the trade-wind fog belt (360 to 600 m game) touches only the mesa and Crown Horn, not the NE vale floor;
- `material_map` still uses the altitude snow rule (365 m); G1 switches it to the biome.

## 5. Part III: the jungle look study (lab, 3–4 versions)

A97: "closed canopy and dim green light, dense undergrowth that slows you, faster game trails, big climbable trees (A59), clearings with fruit and light shafts". A95: the lab's forest "reads as scattered trees, not a dense belt".

**Where:** `web/gaitlab/forest.html` + `forest_core.js`, a three.js look-dev lab (A35: prototype in three.js, ship in Godot).
- It loads the forest vale height and veg crop (a 600 × 600 m tile) exported by `terrain_cli` (`--crop` writes a small `.bin`).
- Trees are the T0 test glTFs, or procedural stand-ins if T0 is late.
- The same 4 camera slots as OG5, OG6, OG7 and a clearing shot; a version switcher; a "copy pick" button (same UI rules as the other labs).

**What varies between the 4 versions:**
| Version | Canopy | Structure | Under-canopy light | Undergrowth | Trails and clearings |
|---|---|---|---|---|---|
| A "Laurisilva" | closure 85% | 2 layers: 15–22 m canopy (Nieblón), understory ferns | soft, green-tinted, no shafts | dense 0.5–1.5 m ferns | narrow 1.2 m trails, few clearings |
| B "Cloud forest" | 90% | 3 layers + epiphyte moss, rope vines | fog in the stand (the A fog-frequency channel), light diffused | dense, mossy logs | trails 1.5 m along streams, small spring clearings |
| C "Cathedral" | 80% with emergents to 30 m | tall straight trunks, open understory, buttress roots | strong light shafts in clearings and gaps | sparse except in gaps | wide 2 m trails, 3–4 large clearings with fruit |
| D "Tangle" | 95% | low 10–14 m canopy, lianas | darkest | very dense, slows most | game trails the only fast way |

**How each version is judged** (numbers in the lab, so the owner judges with data; all targets are starting values):
| Criterion | Measure in the lab | Target | Basis |
|---|---|---|---|
| Canopy closure | Gap fraction from 20 ground points, a 64-ray hemispherical "photo" each (the forestry measure, Jennings, Brown & Sheil 1999, *Forestry* 72) | 80–95% closed in the belt, 30–60% at the edge | reads as a belt, not scattered trees (A95) |
| Under-canopy light | Mean ground luminance at OG7 / the same point with the canopy removed | 0.12–0.25 (stylised) | Real understory gets ~1–2% of full sun (Chazdon & Pearcy 1991, *BioScience* 41). A real value would fail LOOK §5 readability, so it is lifted; light shafts carry the contrast |
| Light shafts | Fraction of the OG7 frame lit by direct sun | 3–10%, clustered | "clearings with light shafts" (A97) |
| Undergrowth | Cover fraction between 0.3 and 1.5 m along a 50 m transect | 50–80% off-trail, ≤ 10% on trails | slows you; trails are faster (A97) |
| Trail readability | Luminance and hue contrast of the trail strip vs the undergrowth at OG7 and OG5 | ΔL ≥ 0.08 | must read from the strategic camera (LOOK §5) |
| Climbable trees | Count per hectare with trunk ≥ 0.8 m diameter and a reachable first branch or vine ≤ 4 m | ≥ 6/ha in the belt; one landmark giant per clearing | A59, A97 |
| Readability | `dist_contrast` of a creature on the trail (the `score.py` metric) | ≥ 0.10 | LOOK §5 |
| Cost | Instances and triangles in view at OG5 and OG6 | within the §10 budget | performance |

**References to gather** (agent collects into `~/Desarrollo/cpore-refs/look/forest/`, licence notes in RESOURCES.md, **never committed**):
- **Laurisilva:** Anaga (Tenerife) and Garajonay National Park (La Gomera), Fanal (Madeira). Wikimedia Commons categories "Laurisilva", "Anaga", "Garajonay National Park". This is the closest real analogue (§4.1).
- **Hawaiian windward rainforest:** Hakalau Forest NWR, Kīpahulu valley, Koʻolau. USFWS and NPS images are US public domain.
- **Temperate rainforest moss and epiphytes:** Hoh Rain Forest, Olympic National Park (NPS, public domain).
- **Footage for light shafts, fog in the stand and scale:** BBC *Planet Earth II* episode 3 "Jungles"; Netflix *Our Planet* episode 3 "Jungles"; Apple *Prehistoric Planet* forest sequences. Watched for technique, never copied or committed.
- **Games, technique only:** *Horizon Forbidden West* (jungle density at distance), *Red Dead Redemption 2* (forest light and fog), *Ghost of Tsushima* (wind in foliage), *Uncharted 4* (undergrowth readability).

**Steps:**
- **L0:** reference board. The agent collects and writes a one-page board; the page `web/gaitlab/forest_refs.html` shows only thumbnails from local paths, never committed.
- **L1:** the lab, 4 versions. Gate: numbers computed in the lab for each version; SwiftShader shots.
- **L2:** owner pick (tracker I3). The pick fixes `flora.json` forest rows, canopy targets for M2, and T1 species priorities.

## 6. Part IV: trees and rocks

### 6.1 Tools available
- **Blender 5.3.0** is installed: `/home/diego/.local/bin/blender` → `~/.local/opt/blender-5.3.0-linux-x64`.
- The repo has its own **MCP bridge** (`tools/blender-mcp/`, `docs/BLENDER_MCP.md`, `make blender`): live scene, Python execution and renders. Good for an agent iterating on one species with renders as feedback.
- **The reproducible pipeline is the scripted CLI:** `blender --background --factory-startup --python tools/flora/grow.py -- --species <id> --seed <n> --out art/generated/flora/<id>/`. The same script is used from MCP while designing. A species is done when its CLI rebuild is byte-stable for the same inputs (Blender version pinned in the output's metadata).

### 6.2 Species (from `docs/lore/FLORA.md`) and the jungle gap
| Asset | Lore id | Form, height | Needed for |
|---|---|---|---|
| Canopy tree | `nieblon` (Fogcomber) | tree 12–22 m | the belt (all versions) |
| Landmark giant | `madre_de_agua` (Springmother) | tree 28–32 m | spring basin, the Great tree mark |
| Valley tree | `caramillo` (Whistlewood) | tree 5–9 m, drought-deciduous | nest-valley margins |
| Vines | `soga_de_dosel` (Canopy Rope) | vine 1–32 m | climbable trunks, versions B/D |
| Fern understory | `pluma_de_sombra` (Shade Feather) | fern 0.3–1.4 m | undergrowth |
| Shrubs | `perlilla`, `suspiro`, `trenza_de_ribera`, `salvisca` | 0.1–6 m | fringes, banks, coast |
| Rosette | `rodela_de_nieve` (Snowshield) | 1.5–2.5 m | alpine |
| Grasses | `paja_dulce`, `grama_de_ceniza` | 0.08–1.2 m | grass cards and clumps |
| **Gap** | emergent buttressed giant; understory small tree or tree-fern | 25–35 m; 3–6 m | version C, and a 3-layer jungle needs an understory tree. Lore council (Q6) |
| Rocks | boulder, outcrop, scree (today's `ROCKS`), plus canyon pillars, mesa cap blocks, cliff chunks | 0.2–40 m | all biomes |

### 6.3 How they are grown
**Trees:**
- Branching follows Weber & Penn 1995 ("Creation and Rendering of Realistic Trees", SIGGRAPH; the model behind Blender's Sapling add-on), with parameters per species from `flora.json` (`angle`, `levels`, `droop`, `spread`).
- The crown is filled by **space colonisation** (Runions, Lane & Prusinkiewicz 2007, "Modeling Trees with a Space Colonization Algorithm") inside an envelope per species. This gives believable crowns, not lollipops; the shape stays slightly stylised (A98).
- Bark: a trunk mesh with a 2-texture bark (albedo, normal + roughness) baked from a procedural Blender material.
- Leaves: cards from a per-species leaf atlas (alpha-tested); the hue shift (LOOK §2 alien accents) is applied in the atlas, recorded per species.

**Rocks:**
- High-poly shapes from Blender geometry nodes: a displaced, Voronoi-fractured icosphere with strata planes for the mesa and canyon.
- Retopo to LOD0 by decimate, then a normal bake from the high-poly.
- Materials use the same photo rock layers as the terrain (`rock_photo.gdshaderinc`), so props and ground match.

**Outputs** per asset: `lod0.glb` (trees 8–15k tris; hero giants 40k), `lod1.glb` (~3k), `lod2.glb` (~800), the impostor atlas, and `meta.json` (seed, Blender version, tri counts, bounds, licence and AI flags).

### 6.4 LODs and impostors in Godot 4.7
**What Godot provides (checked against the installed 4.7.2 API):**
- `GeometryInstance3D.visibility_range_begin/end` with `visibility_range_fade_mode`: `DISABLED`, `SELF`, `DEPENDENCIES`. This is the manual HLOD chain; `island_props.gd` already uses it.
- `lod_bias`, and automatic mesh LOD generated at glTF import.
- `MultiMesh` instancing.

**What Godot does not provide:** impostors. There is no impostor class. Plugins exist:
- `zhangjt93/godot-imposter`: MIT, a Godot 4 port of wojtekpil's;
- `hdrsniped/octahedral-impostor-lod-godot`: custom licence, credit required.

**We build our own:**
- **Bake in Blender** (no runtime plugin), per Ryan Brucks's octahedral impostors (2018, shaderbits.com):
  - a **hemi-octahedral** view grid of 8×8 frames (12×12 for the giant);
  - each frame orthographic, Cycles CPU;
  - two atlases at 2048² (1024² on low): albedo + alpha (BC3), and normal + depth (BC3);
  - written by `tools/flora/bake_impostor.py`.
- **Shader** `godot/game/shaders/impostor.gdshader`:
  - pick the 3 nearest frames from the view direction in octahedral space, blend with barycentric weights;
  - depth-offset parallax per frame, as in the MIT shader of wojtekpil and zhangjt93, which we may port with credit;
  - alpha-scissor so it works in Compatibility;
  - lit by `scene_out()`, so the impostor matches the mesh under the day cycle.
- **Spike T0** checks two things before anything else:
  1. auto mesh LOD and `visibility_range_fade_mode = SELF` in **Compatibility**. If the fade needs alpha blending there, use a dithered distance fade in our shaders instead.
  2. impostor vs LOD2 colour match: mean ΔE < 3 at the switch distance.

**Distances** (A98: "impostors from ~100 m, grass to ~250 m"):
| Range | High (tier 3) | Medium (tier 2) | Low (tier 1) |
|---|---|---|---|
| Tree LOD0 | 0–40 m | 0–30 m | 0–20 m |
| Tree LOD1 | 40–100 m | 30–80 m | 20–50 m |
| Impostor | 100 m–2.5 km | 80 m–2 km | 50 m–1.5 km |
| Beyond | terrain canopy tint and bump | same | same |
| Grass blades near | 0–44 m (today) | 0–40 m | 0–30 m |
| Grass blades far | 44–140 m (today) | 40–120 m | 30–90 m |
| **Grass clumps (new)** | 140–250 m: one card per ~1.5 m² from `veg.B` | 120–200 m | 90–120 m |
| Rocks LOD0/1 | 0–60 / 60–300 m; boulders and outcrops as impostors beyond | 0–50 / 50–250 m | 0–35 / 35–200 m |

**Scatter:**
- `island_props.gd` keeps its 64-cell chunk batching (`chunk_width`) and makes one MultiMesh per chunk × species × LOD.
- Impostors use a coarser 512 m chunk, so there are fewer draw calls.
- Big trees come from the C trunk records (M3), small flora from GDScript.

### 6.5 Steps T0–T5
| # | Step | Files | Tests | Gate |
|---|---|---|---|---|
| **T0** | Spike: one `nieblon`, CLI grow + LODs + impostor bake + Godot shader | `tools/flora/grow.py`, `bake_impostor.py`, `impostor.gdshader`, a test scene | `godot/game/tests/impostor_test.gd`: ΔE at the switch; no popping over a 30-frame dolly (max per-frame luminance change in the tree's bbox < 0.06) | spike report with numbers; Compatibility behaviour of fades recorded |
| **T1** | Jungle species set (after L2): canopy, giant, vines, ferns, plus the Q6 species | `art/generated/flora/<id>/`, `flora.json` (`mesh` field) | CLI rebuild byte-stable; tri budgets in `meta.json`; `make godot-creature-fit`-style fit check for scale | owner eyeball at OG6/OG7 |
| **T2** | Rocks set | `art/generated/rocks/`, `tools/rocks/grow.py` | as T1 | OG4 (canyon), OG8 |
| **T3** | Props pipeline in Godot: glTF LOD chain + impostor MultiMesh, chunked, tier distances | `island_props.gd`, `flora_mesh.gd` (kept for small procedural flora), `godot/game/data/flora_assets.json` | `godot-test`; draw calls and instances at OG5/OG6 logged | within the §10 budget under software GL (relative); no pop at transitions (T0 metric) |
| **T4** | Grass to 250 m: clump card ring, density from `veg` | `grass.gd`, `grass.gdshader` | grass test (`wrap_base` cases) + OG8 | `tiling` and `hf_noise` pass at OG8; frame-time ratio ≤ 1.10 vs P0 |
| **T5** | Valley and other-biome species | as T1 | as T1 | OG8 |

## 7. Part V: Hillaire 2020 sky, merged with the night-sky plan

### 7.1 The paper's technique (quoted numbers)
Hillaire, "A Scalable and Production Ready Sky and Atmosphere Rendering Technique", EGSR 2020.

**Model** (eqs. 1–4):
- `L(c,v) = T(c,p) L_o(p,v) + ∫ L_scat(c, c − t v, v) dt`
- `T(x_a,x_b) = exp(−∫ σ_t)`
- `L_scat = σ_s Σᵢ T(c,x) S(x,lᵢ) p(v,lᵢ) Eᵢ`
- `S = Vis · T(x, x + t_atmo lᵢ)`, with N lights (sun **and moon**).

**Phase functions:**
- Rayleigh `p_r = 3(1 + cos²θ)/(16π)`;
- Mie by Cornette–Shanks `p_m = 3/(8π) · (1−g²)(1+cos²θ) / ((2+g²)(1+g² − 2g cosθ)^{3/2})`, `g = 0.8`. "it is also appropriate to use the simpler Henyey-Greenstein phase function";
- isotropic `p_u = 1/4π`.

**Earth (Table 1):**
- Rayleigh `σ_s = (5.802, 13.558, 33.1)·10⁻⁶ m⁻¹`, no absorption;
- Mie `σ_s = 3.996·10⁻⁶`, `σ_a = 4.40·10⁻⁶`;
- ozone `σ_a = (0.650, 1.881, 0.085)·10⁻⁶`, no scattering;
- densities `d_r = e^{−h/8 km}`, `d_m = e^{−h/1.2 km}`, ozone a tent `max(0, 1 − |h − 25|/15)` (km);
- `R_ground = 6360 km`, `R_top = 6460 km`, ground albedo `ρ = 0.3`.

**Multiple scattering (§5.5):**
- `L_2nd = ∫_{4π} L₀(x_s, −ω) p_u dω` (5), with `L₀` the single scattering and ground bounce for unit illuminance (6);
- `f_ms = ∫_{4π} L_f(x_s, −ω) p_u dω` (7), `L_f = ∫ σ_s T dt` (8): "skip the sampling of the shadowing term S and phase function";
- `F_ms = 1 + f_ms + f_ms² + … = 1/(1 − f_ms)` (9);
- `Ψ_ms = L_2nd F_ms` (10);
- the final `L_scat = σ_s Σ (T S p + Ψ_ms) Eᵢ` (11).
- "integration of f_ms and L_2nd order over the unit sphere is achieved using 64 uniformly distributed directions".
- LUT parameterisation `u = 0.5 + 0.5 cos θ_s`, `v = (h − R_ground)/(R_top − R_ground)`.
- Visibility is ignored for multiple scattering.

**Sky-View LUT (§5.3):** a lat/long texture around the camera's local up, so the horizon is always a horizontal line.
- Non-linear latitude `v = 0.5 + 0.5·sign(l)·√(|l|/(π/2))` "compress[es] more texels near the horizon".
- "The sun disk is not rendered as part of that texture… It is composited after."

**Aerial perspective (§5.4):** a camera-frustum volume, RGB in-scattering + A mean transmittance.
- "32 × 32 over the screen and 32 depth slices over a depth range of 32 kilometers"; "the case for… Fortnite, having a world map size of 3km²".
- Applied to opaques as a post step; "for transparent elements… at the per-vertex level".

**Transmittance LUT:** the Bruneton & Neyret 2008 §4 parameterisation. With `H = √(R_t² − R_g²)`, `ρ = √(r² − R_g²)`, `d` the distance to the top along μ, `d_min = R_t − r`, `d_max = ρ + H`:
- `x_μ = (d − d_min)/(d_max − d_min)`;
- `x_r = ρ/H`.

**Table 2:**
| LUT | PC (GTX 1080): size, steps, time | iPhone 6s: size, steps, time |
|---|---|---|
| Transmittance | 256×64, 40, 0.01 ms | 256×64, 40, 0.53 ms |
| Sky-View | 200×100, 30, 0.05 ms | 96×50, 8, 0.27 ms |
| Aerial perspective | 32³, 30, 0.04 ms | 32²×16, 8, 0.11 ms |
| Multi-scattering | 32², 20, 0.07 ms | 32², 20, 0.12 ms |

Whole sky and atmosphere: 0.31 ms at 1280×720 on the PC. Views from space ray-march per pixel instead of using the sky-view LUT ("0.33ms… total… 0.5ms"); this matters for OG0/OG1. iPhone total ≈ 1 ms.

### 7.2 Our atmosphere (canon → parameters)
| Parameter | Value (starting) | Basis |
|---|---|---|
| `R_ground` | 6614 km | F2: 1.04 R⊕ × 6360 |
| `R_top` | `R_ground` + 100 km | paper default |
| Rayleigh σ_s | Earth × 1.6 | F4 1.6 bar; F17 "1.6× Rayleigh depth" → copper sunsets for free |
| Rayleigh scale height | 7.6 km | 8 km / 1.05 g (F2), same temperature assumed |
| Mie σ_s, σ_a | Earth × 1.5 | F15 "humid", F17 "milky horizon" |
| Mie g | 0.8 | paper |
| Ozone | Earth | not in canon; needed for blue at sunset (paper §4) |
| Ground albedo | 0.12 | mostly ocean around the island (Q8) |
| Exposure | one `sky_ev` | calibrated so that midday OG8 and the look-score `valley_*` shots stay within the scorecard's tolerance of the baseline |

LOOK §2's off-Earth sunset tint is now physical (denser Rayleigh). If the owner wants more violet, there is one knob (Rayleigh RGB tilt), recorded as a deliberate stylisation.

### 7.3 Implementation in Godot (both renderers)
| LUT | Where computed | Size (high / low) | When |
|---|---|---|---|
| Transmittance | **CPU in the extension** (`godot/extension/atmosphere.cpp`, a C++ port of the paper's model). Upload as `ImageTexture` `FORMAT_RGBH` | 256×64, 40 steps | at load and when parameters change (never in play) |
| Multi-scattering | CPU, same file (64 directions × 20 steps per texel) | 32×32 | same |
| Sky-View | GPU: a `SubViewport` with a full-rect `canvas_item` shader, `use_hdr_2d = true` (16-bit float) | 200×100, 30 steps / 96×50, 8 steps | every frame (the sun moves 0.3°/s) |
| Aerial perspective | GPU: `SubViewport` holding a **2D atlas** of the 32 slices (1024×32; Compatibility has no 3D render targets) | 32×32×32 over 32 km / 32×32×16 | every frame |
| Sun colour, ambient, fog tint | CPU from the transmittance LUT (sun through the air at the camera) and a 16-angle sky irradiance table (cosine-weighted hemisphere integral of the same model) | — | per frame, a few lookups |

**Plumbing:**
- **New node** `godot/game/island/atmosphere.gd` owns the viewports and textures. It sets new shader globals `atmo_trans`, `atmo_ms`, `atmo_skyview`, `atmo_ap`, `atmo_params` and `sky_ev`.
- **Sky shader** (`sky.gdshader`):
  - `L = skyview(EYEDIR)` + the sun disc (limb darkening, composited after the LUT as the paper says) + the night layers;
  - `COLOR = display_out(tm(L · sky_ev))`;
  - clouds: the existing 2D layers until V, lit by the transmittance toward the sun (no more `sky_glow` hack).
- **Aerial perspective:** `aerial()` in `look.gdshaderinc` becomes `aerial_lin(lin, wp, cam)`: `lin·T + S·sun_illum` **in linear space before `tm()`**. That is the physical order. The hero hazed in display space after tone mapping, so every look-score baseline moves once (Q9).
  - `ground_fog()` (the F8 fog trap) stays, generalised to the M fog-frequency map; its colour comes from the AP in-scattering, not constants.
- **`day_night.gd`** stays the one driver of the clock.
  - `palette()`'s `K_*` keys are replaced by values from `atmosphere.gd`: `sun_color` from transmittance; `ambient_color` and `env.ambient_light_color` from irradiance; `fog_color` from AP at 1 km; `sky_*` kept only as fallbacks for the reflection-cube pass (`AT_CUBEMAP_PASS`).
  - `light_dir()` keeps the art arc (38° noon) as night-sky Q9 decided.
  - Low tier runs the same path with the iPhone LUT sizes, so LOOK §6 "same game" holds.
- **HDR spike (H0):** in Compatibility, does a `SubViewport` with `use_hdr_2d` give a float target that a sky shader can sample?
  - If not, encode RGBM in RGBA8 (range 8) for the sky-view, and keep the AP in RGBA8 (in-scattering is low range).
  - Last fallback: the sky-view on CPU in the extension at 96×50, multithreaded.

### 7.4 Merging with `docs/plans/night-sky.md` (no duplication)
| Night-sky item | With Hillaire |
|---|---|
| §6.1 "Gradient, extinction" layer in `sky.gdshader` | **Replaced** by the sky-view LUT. Star extinction and reddening toward the "milky horizon" (night-sky §3.4) sample `atmo_trans`, the same atmosphere as the day |
| Airglow, zodiacal light, aurora, galaxy cube, star MultiMesh, moon disc, planets, meteors | **Kept as planned** (NS2, NS3, NS6), added on top of the LUT sky in linear space before `tm()` |
| Moon as a light | The moon is light 2 in eq. (11): the sky-view and AP passes take `E_moon` and `moon_dir` from `cp_sky_at` (NS1). Physical moon illuminance is ~2.5·10⁻⁶ of the sun; night uses night-sky §3.3's playable target (new moon 0.55× full moon ground luminance) as a **floor ambient**, and the moonlit sky colour comes from the LUT. The wl4 night key stays the "full moon high" calibration |
| §6.3 "no new HDR path" | Respected: linear → one exposure → the same `tm()` → `display_out()`. The dark adaptation of stargaze mode is a `sky_ev` change |
| `sky_altitude` (glimpse of space, A92; space-stage transition) | Becomes **real camera altitude** in the LUTs. Above ~20 km the sky shader ray-marches per pixel (paper §7, "from space… 0.33 ms"). The same code serves OG0/OG1 |
| NS order (NS0, NS1 now; NS2+ after the loop focus) | H0–H2 should land before NS2, so NS2 builds on the LUT sky and not on the gradient that H replaces. NS1 (system in C) is independent |

### 7.5 Steps H0–H4
| # | Step | Files | Tests | Gate |
|---|---|---|---|---|
| **H0** | Compatibility spike: HDR SubViewport, sampling from sky and spatial shaders, atlas AP | throwaway scene in `godot/game/tests/atmo_spike.gd` | headless + xvfb readback of known values | report: format available, precision, cost ratio |
| **H1** | CPU LUTs in the extension + reference check | `godot/extension/atmosphere.{h,cpp}`, `register_types.cpp`; `tools/atmo/ref.py` (numpy port of eqs. 1–11) | `godot/game/tests/atmo_test.gd`: C++ vs Python transmittance and Ψ_ms within 1%; Earth parameters reproduce the paper's Figure 7 trend (Ψ_ms broadly uniform) | pass; LUTs ≤ 40 ms at load |
| **H2** | Sky-view + sky shader + sun disc | `atmosphere.gd`, `sky.gdshader`, `island.gd` hookup | OG2, OG3, OG8 × 4 times; look-score world shots | sky zenith luminance and horizon hue within the `look-targets.json` sky checks; dusk `warmth_shift` passes; frame-time ratio ≤ 1.05 |
| **H3** | Aerial perspective in linear space; `day_night` values from the atmosphere; fog colour from AP | `look.gdshaderinc` (`aerial_lin`, `scene_out`), `day_night.gd`, `clouds.gdshaderinc` (lighting from transmittance), water and grass shaders | full look score (`make godot-look-score`); OG path | no LOOK §7 failure; `tier_delta` ≤ baseline; owner blind sheet old vs new (tracker I4) |
| **H4** | Altitude and space mode (per-pixel ray-march above 20 km), moon as light 2 (with NS1 data) | `sky.gdshader`, `atmosphere.gd` | OG0/OG1 stills with a sphere planet stub | ready for O1 and for night-sky NS2 |

## 8. Part VI: ground materials
- **Layers:** today's 8 photo rock layers (ambientCG CC0, `CREDITS.md`) plus 8 ground layers in a second `Texture2DArray` pair:
  - volcanic soil (exists), forest litter, moss, laurel-leaf litter, mud, dry clay/caliche (desert), red sandstone (canyon), beach sand (exists as sediment), snow.
  - First choice is ambientCG CC0 photogrammetry, as today.
  - Every layer gets **albedo**, **normal**, **roughness**, **height** (the current pack has normal xy + height but no roughness). The pack becomes 2 arrays: `alb_rough` (RGB albedo + A roughness) and `nrm_h` (RG normal, B height, A AO), both BC3.
- **No visible tiling.** Replace the two-tap `ph_stochastic` with **hex-tiling** (Mikkelsen 2022, JCGT 11(2)):
  - the UV is scaled by `2√3` and skewed onto a triangle grid (`gridToSkewedGrid = [[1, −0.57735027],[0, 1.15470054]]`);
  - each of the 3 hex vertices gets a random offset (hash) and rotation (`rotStrength`), and is fetched with `textureGrad` using the rotated derivatives;
  - weights: barycentrics raised to `g_exp = 7` × a luminance term `Dw = mix(1, lum(c), g_fallOffContrast = 0.6)`, normalised, then a contrast gain with **r = 0.75 for albedo and roughness**, and **r = 0.5 (off) for normal maps**;
  - normals are blended as **derivatives**, not vectors: "by blending the partial derivatives, the obtained result is equivalent to blending directly from the height map".
  - Cost: 3 fetches per layer per mapping axis.
  - The alternative of Heitz & Neyret 2018 ("High-Performance By-Example Noise using a Histogram-Preserving Blending Operator", HPG; a Gaussianised texture with a variance-preserving blend and inverse-LUT) keeps histograms better, but needs a per-texture LUT and breaks on normals. Hex-tiling is the default; Heitz–Neyret only if the `tiling` metric still fails on sand and snow.
- **Triplanar on cliffs:** keep `rock_mapping.gdshaderinc`'s biplanar default and triplanar on High, gated on slope (> 40°). Ground layers use top projection plus hex-tiling.
- **Detail octaves (A98: "fine noise octaves down to ~1 m live in shaders only"):**
  - 3 octaves of the existing `terrain_body.gdshaderinc` FBM tilt at 8 m, 3 m and 1 m wavelengths, faded by distance (`FBM_FAR`);
  - plus a sub-metre micro-normal from the layer's normal map;
  - macro variation from `relief` (curvature, sediment) and the M maps (wetness darkens and smooths: roughness −0.25 on wet litter).
- **Weights:** `biome`, `veg.A` wetness, slope, `material`, `sediment`, and the snow from M2. Smooth height-based blending between layers (`height` channel, the classic height-lerp), not linear alpha.
- **Steam AI disclosure:** ambientCG and Blender-procedural textures are not AI-generated. **Any** AI-made or AI-edited texture (an upscale with Real-ESRGAN, RESOURCES V4; a generated moss tint; Tripo meshes) is listed in `godot/game/textures/AI-DISCLOSURE.md` (asset, tool, model, date, what was generated). The Steam content survey ("pre-generated AI content") is written from that file when Steam comes (G60). The look tools reject an asset whose `meta.json` has `ai: true` and no disclosure row.
- **Steps:**
  - **G0:** layer set + packer (`tools/bake_photo_textures.py` gains roughness and AO; CREDITS rows).
  - **G1:** hex-tiling include (`ground_hex.gdshaderinc`) + tests (a shader unit scene comparing per-pixel weights with a CPU port of Listing 1).
  - **G2:** biome-driven layer weights + detail octaves.
  - **G3:** wet/dry roughness by the time of day and later by weather.
- **Gates:**
  - `score.py` `tiling` ≤ target at OG3, OG4 and OG8 and on the look-score wide shots;
  - `hf_noise` within target (LOOK §7 "noisy, dirty textures");
  - `spec_frac` low on wet litter (no plastic shine);
  - frame-time ratio ≤ 1.10.

## 9. Part VII: volumetric clouds (last)
**Technique** (Schneider & Vos 2015, "The Real-time Volumetric Cloudscapes of Horizon Zero Dawn", SIGGRAPH; Hillaire 2016, "Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite"):

**Noise:**
- base shape **128³** RGBA: Perlin-Worley in R ("Perlin… dilated by Worley… we referred to this as Perlin-Worley"), plus 3 Worley octaves at increasing frequencies;
- detail **32³**: Worley octaves that erode edges ("invert the Worley noise at the base of the clouds you get some nice whispy shapes");
- curl **128²** for turbulence.
- Baked once by `tools/clouds/bake_noise.py` into `Texture3D` (Compatibility samples `sampler3D`).

**Density:**
- the base shape × a height gradient per cloud type ("3 mathematical presets": stratus, stratocumulus, cumulus, blended by the weather map's type);
- × coverage, then eroded by the detail texture;
- weather map: R coverage, G precipitation, B type. **Ours comes from M2** (§4.2 step 9): the windward stratocumulus deck in the trade-inversion belt, the cumulus cap over Crown Horn, clear skies in the lee.

**Lighting:**
- Beer's law + the "powdered sugar" term, combined as `2·e^{−d}·(1 − e^{−2d})`, "view dependent";
- Henyey–Greenstein (a two-lobe blend for the silver lining);
- darker absorption for rain clouds (weather G);
- 6 light samples "in a cone toward the sun";
- Hillaire 2016's energy-conserving step `S_int = (S − S·T_step)/σ_t` ("only 21 samples are enough… instead of 512");
- the Wrenninge et al. 2013 multiple-scattering octaves `σ_s' = σ_s aⁿ`, `σ_e' = σ_e bⁿ`, `p'(θ) = p(θ cⁿ)` with `a ≤ b` for energy conservation, N = 2 (Frostbite's setting).
- Cloud medium: Hillaire 2016 cites Hess et al. 1998: single-scattering albedo ≈ 1, `σ_t` 0.04–0.06 m⁻¹ for stratus and 0.05–0.12 for cumulus.

**Sampling:**
- "64-128 potential march samples", with cheap steps until a cloud is hit, then full steps after a step back.
- **Temporal:** "a quarter res buffer… to update 1 out of 16 pixels for each 4x4 pixel block… We reproject the previous frame", and the half-resolution upscale. This took HZD from ~20 ms to "around 2 milliseconds" on PS4. Frostbite: 0.91 ms at 720p main view, half resolution, 16 samples per pass (Xbox One).
- **Ours:** half resolution with 1/16 pixel updates per frame, a ping-pong pair of `SubViewport`s (current, history) with reprojection from the previous view-projection matrix (a uniform), and a bilateral upsample against depth in the composite.
- **Layers:** the stratus deck base 360 m and top 600 m game (canon 900–1,500 m ÷ `scale_z` 2.5); cumulus 600–2,500 m. The 2D cirrus at 7,000 m stays a 2D layer (HZD keeps alto/cirrus "scrolling textures").
- **Cloud shadows:** `cloud_shadow()` in `terrain_body.gdshaderinc` samples the same weather map + base noise (one 2D tap).

**Cost and tiers:**
| Tier | Clouds | Budget |
|---|---|---|
| High (Forward+, RTX) | volumetric, half res + 1/16 temporal, 64–128 steps, 6 light samples | ≤ 1.5 ms at 1080p |
| Medium (Compatibility, discrete GPU) | volumetric at quarter res, 32–64 steps, 3 light samples | ≤ 2.5 ms; if it misses, use the low path |
| Low (integrated) | the existing 2D `cloud_cov` layer, **driven by the same weather map** (same placement and palette, LOOK §6) | ≤ 0.3 ms |

**Steps:**
- **V0:** noise bake + a three.js lab (A35) with 3 cloud looks for the owner.
- **V1:** Godot raymarch at half res, no temporal.
- **V2:** temporal 1/16 + upsample + sky/AP composite (clouds receive AP; the sky-view behind them).
- **V3:** tiers and cloud shadows.

**Gates:**
- clipped pixels < 0.2%;
- no temporal ghosting: max luminance change between consecutive frames of a static shot < 0.02 after 16 frames;
- OG2 and OG3 show the deck on the windward side only;
- owner pick in the lab (tracker I6).

## 10. Performance budget
Frame targets (from `docs/plans/creature-loop.md`): high ≥ 60 fps, medium ≥ 45, low ≥ 30. Agents measure only relative software-GL ratios against P0. The owner runs high on the RTX (`make godot-terrain-bench TIER=high`; nvidia-powerd at 45 W is still pending on the owner, STATUS).

| GPU ms (starting values) | High, RTX, 1080p, 16.6 ms frame | Low, integrated, 720p, 33 ms frame |
|---|---|---|
| Terrain (+ hex-tiling, detail octaves) | 1.6 | 4.0 |
| Water | 0.6 | 1.2 |
| Grass (blades + clumps to 250 m / 120 m) | 1.5 | 3.0 |
| Trees: LODs + impostors | 2.2 | 4.0 |
| Rocks and small flora | 0.8 | 1.5 |
| Creatures | 1.0 | 2.0 |
| Sun shadows (4 cascades, 200 m / none on low) | 2.0 | 0 |
| Sky LUTs + sky + AP | 0.35 | 1.0 (iPhone-size LUTs) |
| Clouds | 1.5 | 0.3 (2D) |
| Post, UI | 0.6 | 1.0 |
| **Total** | **12.15** (27% headroom) | **18.0** (45% headroom) |

**Counts:**
- draw calls ≤ 1,500 on high and ≤ 600 on low;
- tree instances drawn ≤ 60k on high (the forest vale is ~3 km²; at ~150 visible stems per hectare that is ≈ 45k, mostly impostors).

**Memory:**
- impostor atlases ≈ 5.3 MB per species at 2048² (BC3 × 2), ×10 species ≈ 53 MB high, ~13 MB low;
- ground arrays ≈ 22 MB;
- cloud noise 8.4 MB (128³ RGBA8) + 0.1 MB.

**CPU:** climate and trunks inside generation, ≤ 200 ms added to the 9 s of n 1536; atmosphere LUTs ≤ 40 ms at load; per frame ≤ 0.2 ms.

## 11. Godot build of the island (A97 order) and loop re-tune
| # | Step | Files | Tests | Gate |
|---|---|---|---|---|
| **B1** | **Switch the game to Star massif.** `game.gd` default params use the frozen desc; `stage_setup.gd` `find_nest` / `find_home` / herds on the new valley; cave and secrets placement re-checked; scenarios re-recorded | `game.gd`, `terrain_cache.gd`, `stage_setup.gd`, `tests/test_{routes,first_quest,secrets,nav}.c` star variants, `godot/scenarios/creature/*.json` | full suites: `make test`, `godot-test`, first-quest e2e (30/0), nav 20/20, routes certification, secrets, soak 10 min | all green on seed 1, plus 2 more seeds for nav and first-quest; load time ≤ the W13 budget with the pre-baked cache |
| **B2** | Jungle in game (L2 pick + T1 + M3 + M4) | the T and M files | OG5–OG7; loop score | the L-criteria hold in Godot within 20% of the lab numbers |
| **B3** | Biome dressing for the other 7 biomes (T2, T5, G2) | flora, rocks, ground | OG2–OG8 | owner eyeball per biome (tracker I5) |
| **R** | **Loop re-tune on the new island** (A83 (6), A97 (5)), per `docs/plans/creature-loop.md` and `make godot-loop-score` | creature-loop branches | loop score, 3 seeds | the creature-loop gates, re-baselined on Star massif |

**B1 as built (2026-11-24, branch `island/b1-switch`):**
- `TerrainCache.game_params(seed)` = `{seed, n: 1536, island_blob}` (the blob is `res://game/data/islands/star_massif.isl`). `Game.enter_island` and every game-island test and evidence script pass it; plain `{"seed": s}` still means the layout-0 ring island (terrain tests, parity). The shipped seed is 1. Snapshot stays 16; the field hash changes (hash `21bdd31b1ce706a5` for seed 1).
- **The nest valley is a lake.** About 100 m around the origin is a pond up to 2.4 m deep (the basin of the valley floor fills; the desc lake at (-150, 70) is a second, deeper one). The old `find_nest` returned a cell standing in 0.5 m of water, and the OG9 chase camera showed the water sheet as a flat sky-coloured band under the nest. `StageSetup.find_nest` now needs a cell that is dry, gentle (normal.y at least 0.9) and 30 m clear of any pond (seeds 1 and 42: (0, 115); seed 7: (101.6, 42.1)). Authored islands only (`data.has_climate()`); the ring island keeps the origin.
- Placements on authored islands: spots must be normal.y > 0.9 along the whole line from the nest (0.8 let a 38 degree bank hold Babosa's home), 4 to 8 m clear of the shore, inside a +-195 m box around the nest (it was around the origin), Garfio's home in sight of the nest at chase-camera height, and every herd joined to Garfio's home and to the earlier herds by a dry straight line (the approach order is a straight pursuit; seed 42's first befriend target was across the lake). Babosa falls back to an unjoined spot if none is joined.
- **Cave and secrets.** `stage_secrets.c` placed shards on a grid of 8 m cells that must fit `GRID_MAX` 640; the 8 km field needs 997. The cell now grows to fit (12.5 m); smaller fields are bit-identical. The first cave (-362, -91) and its chamber are reached by the real planner on seeds 1, 7, 42, but only from the mouth apron: the nav grid of the 8 km field has 7.8 m cells (`NAV_DIM` 1024) and refuses a GO from far away into the passage. `secrets_test` and the route fixtures therefore certify nest -> mouth -> chamber.
- **Tests.** `tests/island_gen.h` + `--island star` for nav, routes, first quest and secrets; layout-0 variants and fixtures retired in the next commit (the star variants are the gate). Route fixtures `tests/routes/star-seed*.json/.txt` (places: nest, six homes, four exits, mouth, five shards, chamber), 294/294 on seeds 1, 7, 42. The passes (exits 2 to 4) are certified for 4+ legs only: no two-legged body takes a 0.8 grade (`min_legs` in the fixture; see `tests/routes/README.md`). Nav 20/20 on seeds 1, 7, 42.
- **Scenarios** re-recorded on the star island (`make_scenarios.gd`, plus `-- --only-flight`: `flight_cliff` needed a wider plateau search because the nearest cliff has no flat ground within 60 m behind it).
- Smaller fixes: lake, river culling boxes cover the whole field (they were +-2 km); `test_field` ground tolerance 1 cm (steeper 5.2 m cells show up to 5 mm); `godot-island-path` defaults to the game island (`LAYOUT=star`; `LAYOUT=1` is the old lab island, `LAYOUT=0` the ring); the e2e bot rests until it can dig (stamina 12) before the wing bed.
- Evidence: loop scorecard `docs/evidence/loop/score/b1-star`, island path `docs/evidence/island/path/b1-star` (OG9 fixed, OG8 moved to the nest), routes `docs/evidence/routes/star-seed*.md`.
- Known gaps: a paler water-quad rectangle on the lake in OG8; the 7.8 m nav grid (a GO into a narrow passage from far away is refused as unreachable; a finer or windowed grid is a core change); two-legged bodies cannot leave the valley through the passes; the lake-filled nest valley is a design question for the owner (drain it, or keep the lakeside nest); the ring terrain tests still use the ring island.

## 12. Orbit-to-nest opening shot (A98 (4))
**What it needs:**
1. **A planet.** A sphere of `R_ground` = 6614 km in a separate "planet" scene in km units, with a 2048×1024 equirectangular albedo:
   - ocean colour by depth;
   - the island as a few pixels (5 km is ~0.1° of latitude; it is invisible from orbit, so the shot frames the ocean and the clouds first);
   - a seeded hotspot chain of small islets (F7 says hotspot; Q10).
2. **The atmosphere from space:** H4 (per-pixel ray-march above 20 km).
3. **A cloud layer seen from above:**
   - from orbit, a global 2D cloud shell (seeded coverage plus the island's M weather map pasted at its location);
   - near the island, the V volumetric clouds.
4. **The camera path** (≈ 25 s, skippable):
   - 400 km → 60 km over 27° N (OG0 → OG1);
   - descent toward the island's NE into the windward cloud deck;
   - at ~12 km the cloud deck fills the view (whiteout), and the planet scene hands over to the game scene;
   - the game scene continues 12 km → 3 km (OG2 → OG3), down the forest vale or the north pass, and lands at the nest in the chase-camera pose (OG8).
   - One `Path3D` per scene, eased (ease-in-out for the long legs, ease-out for the landing); camera FOV 50° → 60°.
5. **Precision:** the planet scene in km units avoids float32 trouble at 400 km. The game scene never exceeds 12 km from the origin.

**When it becomes possible:**
- **O0** (a graybox path in the game scene from 12 km to the nest, with 2D clouds): after **H2**.
- **O1** (planet scene + space atmosphere + handover): after **H4**.
- **O2** (the real shot, volumetric cloud dive): after **V2**.

It replaces or precedes the current new-game entry (the cell bridge or the loading veil decides, Q13). The glimpse-of-space secret (A92) reuses O1 in reverse.

## 13. Gameplay weather (later; sketch only)
- After the loop re-tune (A98 (5)). **[SNAP]**: the next free snapshot after 16, whatever STATUS says then.
- **State**, a C struct in `CpStageWorld`:
  - `CpStageWeather { int32 regime; int32 timer; int32 front_x, front_z; uint8 rain[4][4]; uint8 fog[4][4]; int32 wind_dir_mdeg, wind_cms; CpRng rng; }`;
  - regimes: clear trades, windward showers, dawn fog, storm, and calm (scent);
  - a Markov chain stepped every 600 ticks (1 game minute) on its own RNG stream, biased by the climate maps (windward rains more, the F8 valley fogs at dawn).
- **Effects** (each its own brief):
  - rain → prey seek cover (a wild AI goal toward trunks and overhangs);
  - fog → detection radius × 0.6 (stalking);
  - wind → the scent cone direction and reach (F16);
  - storm → lightning near peaks (A87 storm capacitor).
- **Visuals** read the state through JSON: cloud coverage multiplier, rain particles, wet roughness (G3).
- Events from the next free id (STATUS: 32, check first).

## 14. Steps, order and parallel lanes

**Every step must keep the base gates green:**
- merge main first;
- `make test`; `make terrain-test` (it includes `terrain-parity`);
- `make godot-test`; first-quest e2e 30/0; the snapshot round trip.

**Agents:** C and terrain steps by Sonnet 5.5 or Codex (AGENTS.md). The lab pages and the reference board can go to an art-lane model, audited. Keep at most 3 implementation agents and the WIP limit of 3.

| Lane | Steps | Depends on |
|---|---|---|
| **Review** | P0 | — (first, small) |
| **Island** | F0 → F1 → F2 → F3 (owner) → F4 → F5 | F2 needs the WASM build (Q12) |
| **Climate** | M0 → M1 → M2 → M3 → M4 | M1 needs nothing (pure); M2 needs F1; M3/M4 need M2 |
| **Forest** | L0 → L1 → L2 (owner) | L1 can start with stand-ins; T0 trees make it better |
| **Assets** | T0 → T1 → T2 → T3 → T4 → T5 | T1 needs L2; T3 needs M3 for trunks |
| **Sky** | H0 → H1 → H2 → H3 → H4 | none on the island; H2 should land before night-sky NS2 |
| **Ground** | G0 → G1 → G2 → G3 | G2 needs M2 |
| **Build** | B1 → B2 → B3 → R | B1 needs F4; B2 needs L2, T1, M3, M4 |
| **Clouds** | V0 → V1 → V2 → V3 | V1 needs H3 and M2 |
| **Opening** | O0 → O1 → O2 | H2 / H4 / V2 |
| **Weather** | W1+ | after R |

**Proposed waves (3 agents at a time), following A97's order (freeze → forest study → Godot build → loop re-tune) and A98's ingredient order:**
1. P0 + F0 + H0. Owner-free; small risk.
2. F1 + M1 + H1. L0 runs in parallel with the art-lane model.
3. F2 + M0/M2 + L1 (T0 as the L1 helper).
4. Owner: F3 tuning, then the L2 pick. Meanwhile H2 + T0 finish.
5. F4 + M3 + H3.
6. B1 + T1 + G0/G1.
7. B2 + M4 + G2, then **R (loop re-tune)**.
8. T2/T4/T5 + B3; V0–V3; O0–O2; W after R.

The current focus (creature loop, STATUS) is not displaced: waves 1–3 touch nothing in flight. B1 waits for the loop-tune branch to merge, because both move the loop baselines.

**Snapshot marks:** no step bumps the snapshot version except **W1 [SNAP]**.
- B1, M3 and M4 change the **field hash** (old saves and scenarios stop restoring; scenarios are re-recorded in B1).
- M3 bumps `CP_STAGE_VERSION` 3 → 4 (behaviour).
- If a later tree-climbing brief adds per-creature climb state, it is **[SNAP]** too.

**Tracker tests to add** (owner confirms):
- **I1** "The island shapes are as I want them" (F3);
- **I2** "The rain shadow reads: wet NE forest, dry SW canyon" (M4/F5);
- **I3** "The jungle study pick" (L2);
- **I4** "The new sky beats the old" (H3, blind sheet);
- **I5** "Each biome looks like itself" (B3);
- **I6** "Clouds pick" (V0);
- **I7** "The opening shot" (O2);
- **I8** "Same seed, same island and climate" (automatic, the F/M goldens).

## 15. Risks
1. **The parity proof could fail for small reasons.** F0's identical-hash gate requires that the desc evaluator does the exact float ops of `layout_height()`, including `× 1/LSCALE` and the `LSCALE` multiply on the regions. Mitigation: F0 converts the data in *design units with LSCALE kept as a desc field* if needed; only after parity does F1 move to world units, re-baselining once.
2. **The climate needs scaling.** True-scale SB04 gives a 5 km island almost no rain shadow (§4.1); the `scale_h`/`scale_z` factors are a deliberate stylisation. If the owner rejects them (Q4), the fallback is a simpler upwind advection model:
   - march along the wind, deplete moisture by `max(0, U·∇h)`, refill over the sea;
   - this is deterministic and cheap, but has no airflow dynamics.
3. **Compatibility limits.** The HDR SubViewport, 3D cloud noise sampling and the impostor fades are unverified in GL3 on this build. H0 and T0 are spikes for that reason. The fallbacks are written into §7.3 and §6.4.
4. **Every look baseline moves at H3.** The aerial perspective moves from display space to linear space. The scorecard numbers shift for physical reasons, not regressions. Mitigation: H3 re-baselines with the owner's blind-sheet pick (Q9), in one merge.
5. **Gameplay trees in C** change nav, steer and the loop (forest crossings are slower). M3 ships the cover multiplier at 1.0 (off) until R tunes it on the loop score.
6. **Generation time.** n 1536 takes 9 s native (more in WASM). The W13 budget is "up to ~10 s"; the shipped island is pre-baked and cached, so only new seeds pay. Climate + trunks add ≤ 0.2 s.
7. **Canon drift.** The map contradicts F7 (height 2,050 m, top 3.6 km) and F18 (westerlies, wet west). If the lore is not updated, every lore check (flora habitats "western fog forest", snow at 1,750 m) fights the map. Q2/Q3 resolve it through the lore council.
8. **Asset volume.** Ten species with LODs and impostors is a lot of agent time. T0 proves one species end to end before T1 spends on the rest; T1 is ordered by the L2 pick.
9. **Blender determinism.** Cycles CPU bakes are noisy unless the seed and sample counts are fixed. Impostor bakes use fixed seeds and denoising off; T0 checks byte stability.
10. **Phone editor performance.** WASM erosion at 512² may be slow on a phone. The shape preview (256², no erosion) is the live mode; erosion runs on release in a worker, cancellable.

## 16. Owner questions (each with a recommended default)

| Q | Question | Recommended default |
|---|---|---|
| Q1 | **What does the seed do on the frozen island?** | The macro shape never changes. The shipped game uses seed 1. A new-game seed varies only the micro relief, erosion, flora and spawns, so every player gets the same Star massif with different detail. The generator for other worlds stays (A97 (2)) |
| Q2 | **Wind and wet side:** canon F18 says westerlies wet the west; the picked map is wet on the NE (trade winds, like Tenerife) | The lore follows the map. The lore council rewrites F18 to "NE trades; wet NE cloud forest under the trade-wind cloud belt; dry SW lee", and the flora habitats "western fog forest" become "windward (NE) fog forest" |
| Q3 | **Height:** canon F7 says ~2,050 m, the island generates 824 m | Keep the generated heights for play. The climate uses `scale_z` = 2.5, so canon numbers (F15 lapse 6.2 K/km, snow from 1,750 m) map onto game heights (snow from ~700 m game). The lore council changes F7's height to "~830 m" *or* keeps 2,050 m as the in-world figure with the compression noted. Prefer changing F7 to the true number |
| Q4 | **Climate scale factor:** run the rain model as if the island were ~40 km across (`scale_h` = 8)? | Yes. Otherwise a 5 km island makes no rain shadow (§4.1). The factor is in the island file, and the editor shows the result live |
| Q5 | **Jungle character:** humid subtropical cloud forest (laurisilva, Hawaiian windward), or lowland tropical rainforest? | Cloud forest. It fits 14 °C at sea level (F15), the Nieblón lore and the trade-wind cloud belt. The L1 versions vary density and light within that character; version C adds tropical-style emergents if the owner wants more drama |
| Q6 | **New jungle species:** a 3-layer jungle needs an emergent giant and an understory tree, which FLORA lacks | Ask the lore council for 2 species with A22 chains: an emergent buttressed tree 25–35 m (climbable, epiphyte host) and an understory tree-fern 3–6 m. Until then, use Madre de agua's model for the emergents |
| Q7 | **Gameplay trees in C** (trunks block and are climbable; undergrowth slows; trails are faster): accept the move of big-tree placement from GDScript to C? | Yes. Only trunks ≥ 0.3 m and climbable or landmark trees; small flora stays visual |
| Q8 | **Sky parameters:** Rayleigh ×1.6 (F17), Mie ×1.5, ozone as Earth, ground albedo 0.12, planet radius 6614 km | Yes, as starting values. Physics gives the copper sunsets; one tilt knob for extra off-Earth violet if wanted |
| Q9 | **Aerial perspective moves to linear space** (physically correct; every look baseline moves once) | Yes, judged by a blind sheet of old vs new at the 10 OG shots × 4 times |
| Q10 | **Neighbouring islands for the orbit shot:** an empty ocean, or a seeded hotspot chain of small islets (F7 hotspot)? | A small chain: 3–5 islets along a line, unreachable in v1, visible from orbit and from the summit |
| Q11 | **Editor saves from the phone:** file download + git commit by an agent, or an artifact with a shared store? | Both. The editor is published as a private artifact whose saves land in its shared store; Claude pulls the latest JSON into `data/islands/` and commits it on the owner's "freeze" |
| Q12 | **Emscripten:** the editor's faithful preview needs `emcc`, and it is not on PATH | Allow installing emsdk in `~/emsdk` (the path the Makefile already looks for). Without it, the editor can use the owner's existing `build/wasm/cpore_terrain.wasm` only until F1 changes the API |
| Q13 | **Opening shot placement:** every new game, or only the first; skippable? | First new game always, skippable with any key; later new games show a 6 s short version (12 km → nest) |
| Q14 | **Who measures high-tier fps?** | The owner runs `make godot-terrain-bench TIER=high` (after `sudo systemctl enable --now nvidia-powerd`) at H3, T3 and V2; agents use only software-GL ratios |
| Q15 | **Order vs the creature-loop focus:** start waves 1–3 (P0, F0–F2, M0–M2, H0–H1, L0–L1) now, since they touch nothing in flight, and do B1 only after `sim/loop-tune-1` merges? | Yes |
| Q16 | **Volumetric clouds on medium tier** (Compatibility on a discrete GPU)? | Try quarter res; if it misses 2.5 ms, medium uses the weather-driven 2D clouds like low |

## 17. Sources (fetched for this plan)
- S. Hillaire, "A Scalable and Production Ready Sky and Atmosphere Rendering Technique", EGSR 2020. https://sebh.github.io/publications/egsr2020.pdf. Equations 1–11, Table 1 and Table 2 are quoted in §7.1.
- R. B. Smith, I. Barstad, "A Linear Theory of Orographic Precipitation", *J. Atmos. Sci.* 61 (2004) 1377–1391, doi:10.1175/1520-0469(2004)061<1377:ALTOOP>2.0.CO;2. Equations as given in the authors' extended abstract: https://ams.confex.com/ams/pdfpapers/62756.pdf (§4.1). The implementer reads the JAS paper's §2 for the m-branch and P∞ details flagged above. The evaluation paper, Barstad & Smith 2005: https://webarchive.library.unt.edu/eot2008/20080916123113/http://www.nssl.noaa.gov/projects/ipex/pubs/barstadandsmith2005.pdf
- A. Schneider, N. Vos, "The Real-time Volumetric Cloudscapes of Horizon Zero Dawn", SIGGRAPH 2015. https://www.guerrilla-games.com/read/the-real-time-volumetric-cloudscapes-of-horizon-zero-dawn, slides https://d3d3g8mu99pzk9.cloudfront.net/AndrewSchneider/The-Real-time-Volumetric-Cloudscapes-of-Horizon-Zero-Dawn.pdf (§9).
- S. Hillaire, "Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite", SIGGRAPH 2016 course notes. https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/s2016-pbs-frostbite-sky-clouds-new.pdf (§9: integration, Wrenninge octaves, timings, cloud σ_t).
- M. Mikkelsen, "Practical Real-Time Hex-Tiling", JCGT 11(2), 2022. https://jcgt.org/published/0011/03/05/ (§8: Listing 1 and the weight code).
- Cited, not fetched (implementers read them at their step):
  - Heitz & Neyret 2018 (HPG, histogram-preserving blending);
  - Bruneton & Neyret 2008 (transmittance parameterisation);
  - Wrenninge, Kulla & Lundqvist 2013 ("Oz: The Great and Volumetric", multiple-scattering octaves);
  - Weber & Penn 1995; Runions, Lane & Prusinkiewicz 2007;
  - R. Brucks, "Octahedral Impostors" (2018, shaderbits.com);
  - Whittaker 1975 (biome diagram);
  - Jennings, Brown & Sheil 1999 (canopy closure);
  - Chazdon & Pearcy 1991 (understory light).
- Godot impostor plugins (reference for our own shader): https://github.com/zhangjt93/godot-imposter (MIT), https://godotengine.org/asset-library/asset/5528 (hdrsniped, custom licence), https://github.com/SIsilicon/Godot-Octahedral-Impostors.
