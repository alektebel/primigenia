# PLAN — M0, the Godot foundation (G76)

Written by the planning agent for the implementing agent. Branch `godot-m0`,
worktree `/home/diego/Desarrollo/cpore-wt/godot-m0`. Read
`/home/diego/Desarrollo/cpore-wt/_agent/briefs/godot-m0.md`, `godot-common.md` and
`common.md` first; they win over this plan if anything conflicts.

You may edit: everything under `godot/` **except** the folders other agents own
(`godot/ui`, `godot/audio`, `godot/studio`, `godot/creature`, `godot/locomotion`,
`godot/tests` from g-ui), plus `docs/godot/M0.md`, `docs/godot/PLAN-m0.md`,
`docs/evidence/godot/m0/` and the Godot block of the root `Makefile`. Never touch
`core/` (algorithms or headers), `art/reference/`, `web/`, `apps/`. Sign commits
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or the model line the
coordinator gives you). Commit after every step below.

Notation: **C map coordinates** `(x_m, y_m)` are metres with the origin at the map
centre and map +y = south. **Godot world**: `X = x_m`, `Z = y_m`, `Y = altitude`.
The C stage world uses the same `(x, z)` = Godot `(X, Z)`; its heading 0 is +Z,
90° is +X, so `yaw = atan2(fx, fz)` and a body faces `Basis(Vector3.UP, yaw) * +Z`.
This matches g-loco's and g-creature's conventions (+Z forward, +Y up).

---

## 1. Assessment of the Codex WIP (commit `0170204`)

Checked on 2026-11-16 by building and running it (nothing in the repo was changed):

| What | Result |
|---|---|
| godot-cpp | Already fetched: `/home/diego/Desarrollo/cpore-wt/_agent/godot-cpp`, `master` at `2a4c066e1e8c121046e9d35fe91cc8e726861c48` ("Sync with upstream 4.8-beta3"). It ships `gdextension/extension_api-4-7.json` and accepts `api_version=4.7` (`tools/godotcpp.py: supported_api_versions`). godot-cpp has no `4.7` branch; master + `api_version=4.7` is the supported route. The generated `gen/include/godot_cpp/core/version.hpp` says minor 7. **No fetch needed.** |
| SCons venv | Present: `_agent/godot-venv/bin/scons`, SCons 4.11.1, Python 3.14. |
| `libcpore.a` | Already compiled with `-fPIC` by the Makefile (`$(BUILD)/%.o` rule), so it links into a shared object. Includes `apps/combat_bots.o` (needed by the stage world). |
| `make godot` as committed | **Fails**: `godot-cpp/src/core/print_string.cpp: fatal error: godot_cpp/classes/os.hpp` — `build_profile.json` enables only `RefCounted`, but godot-cpp itself needs `OS`. With `{"enabled_classes": ["RefCounted", "OS"]}` it builds in ~5 s. |
| Library name | **Wrong**: `SharedLibrary("../bin/libcpore" + env["suffix"])` produces `libcpore.linux.template_debug.x86_64` with no `.so` (SCons sees a suffix already), so the path in `cpore.gdextension` never matches and Godot would not load it. Use `env["suffix"] + env["SHLIBSUFFIX"]`. |
| Tests | With the two fixes above (and the `.so` name), `godot --headless --path godot --script res://tests/test_extension.gd` → **`PASS (0 failures)`** in 0.34 s. The n=64, seed 42 hash `931815d90f8a90ac` equals `build/terrain_cli hash --seed 42 --n 64`. |
| Full size | In a probe (scratch copy), `generate(defaults)` at N=1024, seed 1, on a `Thread` with `progress()` polled from the main thread: **3303 ms**, hash `281193d8ad044e09` = `terrain_cli hash --seed 1 --n 1024` (3.31 s natively), 4 caves. Cache file via `store_var`: 13.6 MB, write 27 ms, read 6 ms; with `FileAccess.open_compressed(..., COMPRESSION_ZSTD)`: 5.4 MB, write 38 ms, read 15 ms. |
| Import | `godot --headless --path godot --import` **aborts (SIGSEGV → abort, rc 134) on the very first import** of any project containing a GDExtension — reproduced with a trivial one-class extension too, so it is an engine/godot-cpp issue, not `cpore.cpp`. A second import exits 0. **Writing `.godot/extension_list.cfg` (one line `res://cpore.gdextension`) before the first import avoids it** (rc 0). Without that file `--script` runs do not load the extension at all (`ClassDB.class_exists` is false). |
| Missing main scene | `run/main_scene="res://scenes/island.tscn"` does not exist → error during import. |
| Makefile | **Bug**: the Godot block was inserted before `all:`, so `godot` became the default goal (`make -n` with no target now runs SCons). `--editor --import --quit` is redundant; use `--import`. `make test` itself is still green (24 s). |

Verdict per file:

| File | Decision | Reasons |
|---|---|---|
| `godot/extension/SConstruct` | **Keep, fix** | Correct pattern (godot-cpp as SConscript, `api_version` exported, links the prebuilt `libcpore.a`, no core sources recompiled). Fix the output name; keep the determinism flags (harmless in glue). |
| `godot/extension/build_profile.json` | **Fix** | Add `"OS"`. Keep the trimmed profile (fast builds); the glue needs nothing else. |
| `godot/extension/cpore.cpp` | **Keep the approach, restructure** | Good: C writes straight into `Packed*Array.ptrw()`, atomics for progress, no simulation logic in C++, hash text matches the CLI. Problems: one class mixes terrain and world; the **routing water level** (workspace `scratch`, needed for lakes, `ct_map(3)` on the web) is dropped; parameter validation casts doubles to `uint32_t`/`int` without type or integrality checks (negative → `uint32_t` is undefined behaviour, `64.5` truncates silently); `world_reset` exposes only seed/terrain/flat height/wild count and silently forces FLAT, `flat_height` 42, `water_radius` 0 (no player profile, spawns, nest, water, obstacles → cannot replay goldens); `world_observe` uses a 64 KiB stack buffer (WASM uses 256 KiB); `world_state` lacks acceleration, returning, home/goal, started/respawn/cooldown, order, accepted, arena and fighter positions; no species table. Split into `CporeTerrain` and `CporeWorld` (§3). |
| `godot/extension/terrain_fields.inc` | **Keep, extend** | All 46 `CpTerrainParams` fields in header order (checked). Add a type tag per field (§3.3). |
| `godot/cpore.gdextension` | **Keep** | Linux debug/release entries are what we build; Windows/macOS lines are harmless placeholders (not built in M0; say so in README). |
| `godot/project.godot` | **Replace** | Missing main scene; `physics/common/physics_ticks_per_second=10` is wrong (the 10 Hz C world runs on its own accumulator; physics, UI and locomotion need the default 60); no autoload, input map, bus layout or user dir. |
| `godot/scripts/terrain_cache.gd` | **Keep logic, move and fix** | Good: parameter digest in the key, temp file + rename, `get_var(false)` (no objects), structural validation, corrupt file regenerates. Move to `godot/game/island/terrain_cache.gd`; use zstd; add a format version, the water level and the derived render maps; verify the recomputed hash on load; do not instantiate the native class inside `cache_path()`. |
| `godot/tests/test_extension.gd` | **Keep, move and extend** | It passes and checks the right things (hash = CLI, rejection, two-world determinism, cache hit/corruption/invalidation). Move to `godot/game/tests/` (g-ui owns `godot/tests/`), split by topic, add the goldens. |
| `godot/.gitignore` | **Keep, extend** | Add `extension/*.os`, `extension/*.o`, `extension/.sconsign*.dblite`. Do **not** ignore `*.uid` or `*.import` (Godot 4.4+ wants `.uid` committed; g-ui commits `.import` for its audio). |
| `Makefile` Godot block | **Fix** | Move to the end of the file; seed `extension_list.cfg`; add `godot-test`, `godot-evidence`. |

---

## 2. Project layout

### 2.1 Folders and ownership

```
godot/
  project.godot            M0 (final; replaces every branch's minimal one)
  cpore.gdextension        M0
  .gitignore               M0
  README.md                M0: build and run
  bin/                     build output, ignored
  extension/               M0: C++ glue (SConstruct, build_profile.json, *.cpp, *.h, terrain_fields.inc)
  game/                    M0: everything else of the foundation
    game.gd                autoload "Game"
    main.tscn, main.gd     boot: settings → cache or loading → island
    loading/               loading_screen.tscn/.gd
    island/                island.tscn/.gd, terrain_cache.gd, terrain_data.gd, terrain_chunks.gd,
                           water.gd, grass.gd, environment.gd, occluders.gd, look.gd (palette constants)
    shaders/               look.gdshaderinc, land.gdshaderinc, terrain.gdshader, water.gdshader,
                           grass.gdshader, sky.gdshader, calibrate.gdshader
    stage/                 stage_world.gd (10 Hz bridge), stage_setup.gd, world_log.gd, profile.gd
    player/                player_input.gd, pointer.gd, chase_camera.gd
    actors/                actor_host.gd, placeholder_creature.gd, actor_driver.gd
    data/                  merodeador.json, garfio.json, garfio-combat.json, parts.json (copies, see S14)
    tests/                 run_m0_tests.gd + test_*.gd, render_tests.gd, m0_evidence.gd, fixtures/
  ui/, audio/              g-ui (HUD, G75 radial, card, pause; AudioManager, buses)
  tests/                   g-ui's tests (ui_test.gd, evidence.gd, gen_bus_layout.gd) — not M0's
  studio/                  g-studio (creator, placeholder view)
  creature/                g-creature (Creature builder and rig)
  locomotion/              g-loco (G73 controller)
```

Rules that keep the merges painless:
- M0 scripts use **no `class_name`** (g-creature already owns `Creature`, `CreatureGenome`,
  `CreatureGeo`, `CreatureGrowth`, `CreatureLegChain`, `CreatureMaterials`, `CreatureParts`,
  `CreaturePreview`). M0 code finds its own scripts with `preload("res://game/...")`.
- M0 code must **run with and without** the other modules present. It references them only
  through `ResourceLoader.exists(path)` + `load(path)` at runtime, never `preload` or a class name.
- At the merge of g-studio, `godot/studio/project.godot` and `godot/studio/.gitignore` (`*.uid`)
  are deleted and its test/scene paths become `res://studio/...` (STUDIO.md already plans this).
  Every other branch's `godot/project.godot` is replaced by M0's. Write this in `docs/godot/M0.md`.

### 2.2 `godot/project.godot` (complete)

```ini
; Primigenia desktop (G76). The single project for every module.
config_version=5

[application]
config/name="Primigenia"
config/features=PackedStringArray("4.7", "GL Compatibility")
run/main_scene="res://game/main.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="primigenia"

[autoload]
Game="*res://game/game.gd"

[audio]
buses/default_bus_layout="res://audio/default_bus_layout.tres"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]
; see 2.4

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
lights_and_shadows/directional_shadow/size=4096
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=2
environment/defaults/default_clear_color=Color(0.52, 0.7, 0.93, 1)
```

Notes:
- **GL Compatibility** everywhere: g-ui, g-studio, g-creature and g-loco all use it, and it is the
  renderer that `--rendering-driver opengl3` + llvmpipe captures. Do not switch to Forward+.
- The bus layout path is g-ui's (`godot/audio/default_bus_layout.tres`). Verified: when the file
  is absent (M0 branch alone) Godot starts with one bus and prints no error.
- `use_custom_user_dir` → `user://` = `~/.local/share/primigenia/` (G76 "user data folder").
  Cache: `user://terrain/`, studio saves: `user://studio/` (g-studio), settings:
  `user://settings.cfg` (g-ui audio + M0 `[game]` section). Tests use `user://m0-tests/` and delete it.
- Leave physics at the default 60 Hz. Leave GDScript warning settings at their defaults.

### 2.3 Autoloads

| Name | Script | Owner | Purpose |
|---|---|---|---|
| `Game` | `res://game/game.gd` | M0 | Island data (the loaded terrain dictionary + `TerrainData`), settings (seed, quality), the active `StageWorld`, scene switching (`goto_island()`, `goto_studio()`), the player genome source, signals for UI. |
| `Audio` | `res://audio/audio_manager.gd` | g-ui | **Reserved name; added at the g-ui merge, not on this branch** (an autoload pointing to a missing file is a startup error). Until then the island creates no audio. |

`game.gd` public surface (document in `docs/godot/M0.md`):

```gdscript
signal island_ready
signal world_ticked(state: Dictionary)          # once per C tick, after the step
signal combat_events(events: Array)             # state.combat.events, when non-empty
signal creature_clicked(id: int, world_pos: Vector3)
var settings: Dictionary   # {seed:int=1, grass:int=252000, quality:"high"}; [game] in user://settings.cfg
var terrain: Dictionary    # CporeTerrain.generate() result (+ derived maps), from cache or fresh
var data                   # TerrainData (game/island/terrain_data.gd): ground(), textures, masks
var stage                  # StageWorld node while the island runs, else null
var camera: Camera3D       # active chase camera
func ground(x: float, z: float) -> float       # forwards to data.ground
func player_genome() -> Dictionary             # 2.6
func movement_blocked() -> bool                # true while a GUI control has focus or a modal/radial is open
```

### 2.4 Input map

Movement and camera are actions (rebindable). Combat keys are **not** actions: g-ui reads raw
keys in `GameUI._unhandled_input` (1–4 abilities, Space guard, Q/E dodge, Esc pause, Tab radial,
and A/B/O/I inside the open radial). M0 must not consume those keys.

| Action | Events |
|---|---|
| `move_forward` | W, Up |
| `move_back` | S, Down |
| `move_left` | A, Left |
| `move_right` | D, Right |
| `sprint` | Shift (left or right) |
| `walk_to` | Mouse left button |
| `camera_orbit` | Mouse right button, mouse middle button |
| `zoom_in` | Mouse wheel up |
| `zoom_out` | Mouse wheel down |

Write them in `project.godot` `[input]` in Godot's serialized format (create them once in the
editor-free way: a tiny `godot --headless --script` that calls `InputMap`/`ProjectSettings.set`
and `ProjectSettings.save()` is acceptable, then commit the text). Movement polling must return
zero while `Game.movement_blocked()` (the radial uses A for Attack).

### 2.5 How the other modules plug in

| Module | M0 looks for | M0 calls / connects |
|---|---|---|
| g-creature | `res://creature/creature.gd` | `var c = load(path).new()`; `c.load_genome(doc)` → `{ok, genome, warnings, error}`; on ok it builds (`build`). Node: origin on the ground, +Z forward, +Y up, metres (web rig unit = 1 m, as `web/stage`). Height for the camera = `c.rest_aabb().size.y` (min 0.5). Without locomotion: each frame set node transform, `pose_legs_rest()`, set each `leg.foot_target` to the ground point under its rest sole (`leg.home` → global, `y = Game.ground()`), `c.solve_legs()`. `c.set_sun_direction(look.SUN_DIR)`. |
| g-loco | `res://locomotion/loco_controller.gd`, `loco_morphology.gd`, `loco_rig_adapter.gd` | `ctl = Controller.new(Morphology.analyse(Adapter.loco_describe(c)), Callable(Game, "ground"))`; per frame `ctl.step(dt, pos, yaw, vel)` then `Adapter.loco_apply(c, ctl.pose)`. Connect `ctl.footfall(leg, pos)` → `Audio.footstep(pos, speed, radius_cm)` when Audio exists. |
| g-ui | `res://ui/game_ui.gd` | Island adds `GameUI.new()` (CanvasLayer 10); `set_camera(Game.camera)`; per tick `set_player(name, hp, hp_max, stamina, stamina_max)` from the player entity; on `Game.creature_clicked` → `select(info)` with `info` built from the entity + `CporeWorld.species()`; `HIT` events → `show_damage(world_pos, amount, b == 0)`. Ability/guard/dodge signals → C inputs are **M3**, not M0; only list the mapping in M0.md: `ability_pressed(i, a)` → `command("attack #%d %s" % [id, a.id])`, `guard_pressed` → verb GUARD, `dodge_pressed(dir)` → verb DODGE with `dir`. |
| g-ui audio | autoload `Audio` (after merge) | `Audio.update_ambience(pos, height, slope, speed)` per frame; `Audio.combat_event(type, pos, radius_cm)` per event; `Audio.start_ambience()` after the first input. |
| g-studio | `res://studio/ui/studio.tscn` | `Game.goto_studio()` switches scene; the studio saves to `user://studio/<slug>.json`; on return `Game.player_genome()` picks the newest file there (2.6). The studio's `creature_view.gd` interface is g-creature's business. |

### 2.6 Player genome source (`Game.player_genome()`)

1. A user argument `--genome=<path>` after `--` (`OS.get_cmdline_user_args()`), for tests and evidence.
2. Else the newest `*.json` in `user://studio/` that parses.
3. Else `res://game/data/merodeador.json` (copy of rig.js `SEEDS.Merodeador` with
   `schema: "cpore.creature/4"`, `regions: []`, exactly as `web/creature/rig.js:370-379` builds it).

Parsing: if `res://creature/creature.gd` exists use its static `parse_genome(text)`; else minimal
checks (`schema == "cpore.creature/4"`, `nodes` array of ≥ 2 finite `{y,z,r}`, `parts` array ≤ 256).
On failure log the error and fall back to the next source.

### 2.7 `godot/.gitignore`

```
.godot/
bin/
extension/*.os
extension/*.o
extension/.sconsign*.dblite
*.tmp
```

---

## 3. The GDExtension

### 3.1 godot-cpp and SCons (outside the repo)

Already in place (§1). If `/home/diego/Desarrollo/cpore-wt/_agent/godot-cpp` is ever missing:

```sh
git clone https://github.com/godotengine/godot-cpp.git /home/diego/Desarrollo/cpore-wt/_agent/godot-cpp
git -C /home/diego/Desarrollo/cpore-wt/_agent/godot-cpp checkout 2a4c066e1e8c121046e9d35fe91cc8e726861c48
python3 -m venv /home/diego/Desarrollo/cpore-wt/_agent/godot-venv
/home/diego/Desarrollo/cpore-wt/_agent/godot-venv/bin/pip install scons==4.11.1
```

Record the pinned commit in `godot/README.md`. The generated bindings live in the shared
checkout (`gen/`); a different `build_profile` regenerates them — only M0 builds against it.

### 3.2 Build files

`godot/extension/SConstruct`:

```python
import os
cpp = os.environ.get("GODOT_CPP", "/home/diego/Desarrollo/cpore-wt/_agent/godot-cpp")
env = SConscript(os.path.join(cpp, "SConstruct"), {"api_version": "4.7"})
env.Append(CPPPATH=["../../core/include"])
# Glue only. The simulation is the prebuilt build/libcpore.a (C99, -fno-fast-math
# -ffp-contract=off from the Makefile); these flags keep the glue honest too.
env.Append(CCFLAGS=["-fno-fast-math", "-ffp-contract=off"])
env.Append(LIBS=[env.File("../../build/libcpore.a"), "m"])
library = env.SharedLibrary(
    "../bin/libcpore{}{}".format(env["suffix"], env["SHLIBSUFFIX"]), Glob("*.cpp"))
Default(library)
```

`godot/extension/build_profile.json`: `{"enabled_classes": ["RefCounted", "OS"]}`.

Root `Makefile`: delete the block Codex inserted near the top and append at the **end**:

```make
# ---- Godot desktop frontend (G76). Dependencies live outside the repository. ----
GODOT ?= godot
GODOT_CPP ?= /home/diego/Desarrollo/cpore-wt/_agent/godot-cpp
SCONS ?= /home/diego/Desarrollo/cpore-wt/_agent/godot-venv/bin/scons
GODOT_JOBS ?= 4
GODOT_TARGET ?= template_debug
.PHONY: godot godot-test godot-render-test godot-evidence
godot: $(BUILD)/libcpore.a
	GODOT_CPP=$(GODOT_CPP) nice -n 10 $(SCONS) -C godot/extension -j$(GODOT_JOBS) \
	  target=$(GODOT_TARGET) build_profile=$(CURDIR)/godot/extension/build_profile.json
	@mkdir -p godot/.godot
	@test -s godot/.godot/extension_list.cfg || echo 'res://cpore.gdextension' > godot/.godot/extension_list.cfg
	nice -n 10 timeout 600 $(GODOT) --headless --path godot --import
godot-test: godot $(BUILD)/terrain_cli $(BUILD)/world_cli
	nice -n 10 timeout 900 $(GODOT) --headless --path godot --script res://game/tests/run_m0_tests.gd
godot-render-test: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/render_tests.gd
godot-evidence: godot
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" \
	  $(GODOT) --rendering-driver opengl3 --max-fps 15 --resolution 1280x720 --path godot \
	  --script res://game/tests/m0_evidence.gd -- $(CURDIR)/docs/evidence/godot/m0
```

(Other branches append `GODOT ?= godot` and their own targets; at merge keep one `GODOT ?=` line.)

### 3.3 Classes exposed to GDScript

Files: `register_types.cpp` (init/terminate, registers both classes at
`MODULE_INITIALIZATION_LEVEL_SCENE`, entry symbol `cpore_library_init` as now),
`cpore_terrain.h/.cpp`, `cpore_world.h/.cpp`, `convert.h` (shared Variant helpers),
`terrain_fields.inc`. C headers included inside `extern "C" {}`; do **not** include `cpore/cpore.h`
(its `CpWorld` typedef is unrelated). Hash strings are `"%016" PRIx64` (as the CLIs print).

Common validation rule (`convert.h`): an **int field** accepts `TYPE_INT`, or `TYPE_FLOAT` whose
value is finite and integral; it must fit the C field (`uint32_t` 0..4294967295, `int32_t`
−2147483648..2147483647, `uint8_t`/`uint16_t` ranges); a **float field** accepts INT or FLOAT,
finite, and is converted with `(float)double`. Any violation → the method returns its error
without touching state. Unknown keys → error.

#### `CporeTerrain` (RefCounted)

| Method | Returns / behaviour |
|---|---|
| `static int version()` | `CP_TERRAIN_VERSION` (3). |
| `static Dictionary defaults()` | All 46 params from `cp_terrain_params_default` (W20: `gentle_bases 0, layout_variety 0, volcano 0, cliff_bands 1, sea_cliffs 1, hard_rock 1, caves 1`, `n 1024`, `size_m 3600`, `seed 1`). Ints as int, floats as float. |
| `static int validate(params: Dictionary)` | 0 or a `CP_TERR_ERR_*` code. Defaults fill missing keys; type rule above (`CP_TERR_ERR_RANGE`); then `cp_terrain_validate`. |
| `Dictionary generate(params: Dictionary)` | On error `{error: code}`. On success `{error: 0, version, seed, n, size_m, params (resolved, full), hash, height, flow, sediment, water_level: PackedFloat32Array, material: PackedByteArray, caves: Array, volcano: Vector4}`. `water_level` = the workspace `scratch` after generation (routing level; above ground in lakes). `caves[i] = {position: Vector3(x_m, z_m, y_m), facing: Vector3(facing_x, 0, facing_y), size: Vector3(width_m, height_m, depth_m), waterfall: bool}` (Godot axes). `volcano = Vector4(volcano_x_m, volcano_y_m, volcano_radius_m, crater_radius_m)` (map axes). Synchronous; meant to run on a worker `Thread`. A second concurrent call on the same instance returns `{error: CP_TERR_ERR_BUFFER}` (atomic busy flag). Workspace vectors are allocated per call and freed on return. |
| `Dictionary progress()` | `{stage: 0..4, done, total, running: bool}`; lock-free atomics written by the C callback; safe from any thread. |
| `static String hash(data: Dictionary)` | Rebuilds a `CpTerrain` view over `data`'s arrays (sizes must be `n*n`, caves ≤ 6, types exact) and returns `cp_terrain_hash`; `""` if anything is malformed. Used by the cache to verify a hit. |

Type tags in `terrain_fields.inc`: `F_U32(seed)`, `F_I32(n, octaves, stream_iters, droplets,
lifetime, radius, thermal_iters)`, `F_F32(...)` for the other 38 (header order unchanged).

#### `CporeWorld` (RefCounted) — one `CpStageWorld`

| Method | Returns / behaviour |
|---|---|
| `static int version()` | `CP_STAGE_VERSION` (1). |
| `static Dictionary default_setup(seed: int)` | Setup dictionary from `cp_stage_setup_default`. |
| `static Dictionary default_profile()` | `cp_combat_profile_default`. |
| `static Array species()` | 4 × `{id, name, speed, sight, roam, hostile, temperament, profile}` from `CP_STAGE_SPECIES` (0 Rondo, 1 Zanco, 2 Espinodo, 3 Garfio). |
| `int reset(setup: Dictionary)` | Fills missing keys from `default_setup(setup.get("seed", 42))`, validates types, calls `cp_stage_reset`; returns its code (0 or −1). On −1 the previous world is untouched (reset into a temporary first). |
| `Dictionary get_setup()` | The resolved setup, same schema (for logs). |
| `String step(input: Dictionary)` | Builds `CpStageInput` (`verb, target, move, dir, sprint, hx, hz, x, z`; missing = 0, so `{}` = CONTINUE), calls `cp_stage_step`, returns the hash. If `hx`/`hz` are outside −32768..32767 or a type is wrong it returns `""` and does **not** step (as `cw_step`). |
| `int command(text: String)`, `int order(input: Dictionary)` | `cp_stage_command` / `cp_stage_order`. |
| `static String order_error(code: int)` | `cp_stage_order_error`. |
| `Dictionary state()` | See schema below. |
| `String observe()` | `cp_stage_observe` into a 256 KiB member buffer; `""` on −1. |
| `String hash()` | `cp_stage_hash`. |
| `float height(x, z)`, `float ground(x, z)`, `bool can_walk(x, z, nx, nz, radius)` | Direct wrappers. |

Setup schema: `{seed: int, terrain_seed: int, terrain: int (0 analytic, 1 flat), nest: Vector2(x, z),
flat_height: float, water: Vector3(x, z, radius), player: Profile, wild: Array[{x, z, home_x, home_z,
species, bot, profile: Profile}] (≤ 24), obstacles: Array[{x, z, r, type}] (≤ 1024)}`.
Profile: `{mouth, charge, spit, tail, guard: int 0..5, hp, stamina, speed: float, radius_cm: int 0..65535}`.

State schema (keep names stable; g-ui and tests read them):

```
{tick, clock, hash, active, started, outcome, respawn_ticks, cooldown_ticks, error (last_error),
 arena: Vector2(arena_x, arena_z),
 order: {verb, target, move, dir, sprint, hx, hz, x, z},
 accepted: [int, int],
 entities: [ {id (0 = player, i+1 = wild[i]), x, z, fx, fz, hp, stamina, speed, acceleration,
              turn_rate, home_x, home_z, goal_x, goal_z, species (-1 player), dead, pivot,
              returning, roam_ticks, hp_max, stamina_max, radius_cm (profile)} ... ],
 combat: {tick, fighters: [ {world_id (0 player, active+1 wild), x, z (world: arena + c.x/y − 20),
                             fx, fz, hp, stamina, move, phase, phase_tick, phase_length} ],  // only while active ≥ 0
          events: [ {type, a, b, move, amount} ]}}
```

Combat is exposed only through the world (events, fighters, verbs ATTACK/GUARD/DODGE and
`command("attack #1 bite")`); no separate combat class in M0.

### 3.4 Determinism

- The simulation code is only `build/libcpore.a` from the Makefile (flags unchanged). SCons never
  compiles `core/src`. Keep `-fno-fast-math -ffp-contract=off` on the glue as well.
- No float maths in the glue except `double → float` conversion of inputs (exact rounding).
- Godot side never advances the simulation except through `CporeWorld.step` at 10 Hz.
- Proof by tests (§7): the committed native goldens `tests/golden/world-{1,42,987654321}.log/.hashes`
  replay through `CporeWorld` with identical per-tick hashes, and a Godot play session's log replays
  identically with `build/world_cli --replay`.

---

## 4. Island

### 4.1 Generation, cache and loading screen

- Params: `CporeTerrain.defaults()` with `seed = Game.settings.seed` (default 1). Nothing else changed (W20).
- Cache key (`terrain_cache.gd`): `user://terrain/island-<seed>-t<CP_TERRAIN_VERSION>-r<RENDER_PREP_VERSION>-<sha256(canonical params)[0:16]>.bin`.
  Canonical params = sorted `[key, value]` pairs, JSON. `RENDER_PREP_VERSION` is a constant in
  `terrain_data.gd`, bumped whenever the derived maps (4.2) change.
- File: `FileAccess.open_compressed(tmp, WRITE, COMPRESSION_ZSTD)`; `store_32(0x30304D43)` ("CM00"),
  `store_32(FORMAT_VERSION=1)`, `store_var(entry, false)`; close; `DirAccess.rename_absolute(tmp, final)`.
  `entry` = the generate dictionary + `{surface: PackedByteArray, chunk_bounds: PackedFloat32Array,
  render_prep: RENDER_PREP_VERSION}`.
- Hit = file exists, magic and format match, structure valid (sizes `n*n`, types), `version`,
  `seed`, `params` equal the request, and `CporeTerrain.hash(entry) == entry.hash`. Anything else →
  regenerate and overwrite. Log `terrain cache: hit|miss (<ms> ms)`.
- Loading flow (`main.gd` → `loading_screen.gd`): on a miss, show the loading screen, run
  `generate` on a `Thread`, poll `progress()` every frame, then compute the derived maps (4.2) on
  the same thread, save the cache, `wait_to_finish()`, switch to `island.tscn`. On a hit, go straight
  to the island (no loading screen frame longer than one frame). Never touch nodes from the thread.
  On window close during generation, wait for the thread (≤ ~4 s) before quitting.
- Loading screen: full-screen Control, palette-C sky gradient background (`sky.hz` → `sky.top`), a
  title line (W13: the panspermia story; use a placeholder sentence and list it as owner copy to
  approve), a progress bar and the stage text from `web/terrain-lab/lab.mjs`: `Raising the range and
  cutting its valleys`, `Rain is carving the gullies`, `Loose stone is settling into scree`, `Tracing
  the drainage network`, `Landscape ready`, plus `Building the island` for the derived maps.
  Overall fraction = `(w_0..w_{s-1} + w_s · done/total)`, weights measured once at N=1024 (record
  them as constants; must be monotonic). Do not fabricate the weights: time each stage once.
- The curated pre-baked seed (W13) is **not** in M0 (5 MB binary in the repo is an owner decision); note it.

### 4.2 `TerrainData` (`game/island/terrain_data.gd`)

Holds the arrays and builds everything the renderers and gameplay need. Constants:
`N = 1024`, `SIZE = 3600.0`, `CELL = SIZE / N` (3.515625 m), `HALF = 1800.0`.
Cell `(i, j)` centre: `x = (i + 0.5) * CELL − HALF`, `z = (j + 0.5) * CELL − HALF`; index `j*N + i`.

- `ground(x, z) -> float`: **exact** surface of the LOD0 mesh. `u = (x + HALF)/CELL − 0.5`,
  `v = (z + HALF)/CELL − 0.5`, `i = clampi(floori(u), 0, N−2)`, `j` likewise, `fu = clampf(u − i, 0, 1)`,
  `fv` likewise; `h00 = H[j*N+i]`, `h10 = H[j*N+i+1]`, `h01 = H[(j+1)*N+i]`, `h11 = H[(j+1)*N+i+1]`;
  if `fu >= fv`: `h00 + fu*(h10−h00) + fv*(h11−h10)` else `h00 + fv*(h01−h00) + fu*(h11−h01)`.
  Outside the square return the edge value clamped (sea floor). One function, used by the creature
  placement, the camera collision, the pointer ray-march, the grass and the C stage setup.
- `normal(x, z)`: central differences of `ground` at ±CELL.
- `is_pond(k)`: `water_level[k] − height[k] > 0.5 and height[k] > 0` (lab rule). `is_sea(k)`: `height[k] <= 0`.
- **Surface map** (`surface`, RGBA8, `N*N*4`), computed once per cache entry:
  - R = material id (`CP_TERR_MAT_*`, 0..5);
  - G = grass mask = `[mat == MEADOW] * smoothstep(.72, .86, ny) * smoothstep(1.2, 2.2, h) * [not pond]`
    (hero's mask, `valle-primigenio.html:458`, with the material map replacing its height window),
    `ny = 1/sqrt(1 + gx² + gy²)`, gradients by central differences in metres;
  - B = cavity: `curv = Σ_{r ∈ {2·CELL, 5·CELL}} max(0, (h(x−r)+h(x+r)+h(z−r)+h(z+r) − 4h)/r²) · r · 0.5`,
    `cavity = smoothstep(.025, .26, curv)` (hero `build_hero.py` cavity; radii scaled to the island cell);
  - A = wetness = `clamp((log10(max(area,1)) − log10(1500)) / (log10(2e5) − log10(1500)), 0, 1)`,
    `area = flow · SIZE²` (lab channel rule: 1500 m² wet, 8000 m² channel).
  Bytes = `round(v * 255)` except R (raw id).
- `chunk_bounds`: 16×16 chunks of 64 cells; per chunk `min(h)`, `max(h)` over its 65×65 vertex
  lattice (clamped indices) → `PackedFloat32Array(512)`.
- If this GDScript pass takes more than ~4 s at N=1024 (measure; it runs only on a cache miss), move
  the loops into `CporeTerrain.surface_maps(data) -> Dictionary` (C++ glue, still no core change).
- Textures (built on every load, cheap): `height_tex` = `Image.create_from_data(N, N, false,
  FORMAT_RF, height.to_byte_array())` → `ImageTexture`; `level_tex` same from `water_level`;
  `surface_tex` = `FORMAT_RGBA8`. Shaders sample them with `texelFetch` (no filtering, no mipmaps).

### 4.3 Chunked terrain mesh with LOD (`terrain_chunks.gd`, `terrain.gdshader`)

Approach: **GPU-displaced geomipmapping**. Five shared flat grid `ArrayMesh`es, one per LOD
(`step = 1, 2, 4, 8, 16` cells → 65, 33, 17, 9, 5 vertices per side, spanning 64 cells); 256
`MeshInstance3D` (16×16), each placed at its chunk's first cell centre
`((c*64 + .5)*CELL − HALF, 0, (r*64 + .5)*CELL − HALF)`; the vertex shader reads the height.

- Local vertex `(a, b)` at `(a*step*CELL, 0, b*step*CELL)`. Triangles per quad, indices in this
  order: `(p00, p10, p11)` and `(p00, p11, p01)` where `p10` is +X, `p01` is +Z. With Godot's
  clockwise front faces this is front-facing from above ((b−a)×(c−a) points −Y) and it is the same
  diagonal as `ground()`.
- Skirts: a second surface on each LOD mesh, a ring of vertical quads along the 4 edges whose bottom
  vertices carry `UV2.x = 1`; the shader lowers them by `skirt = 4 * step` metres; material variant
  with `cull_disabled`. Hides LOD cracks.
- Vertex shader: world xz from `MODEL_MATRIX * VERTEX`; `ivec2 ij = clamp(ivec2(round((xz + HALF)/CELL − 0.5)), 0, N−1)`;
  `VERTEX.y = texelFetch(height_tex, ij, 0).r − skirt * UV2.x`. Pass world position to the fragment.
- `custom_aabb` per instance: `AABB(Vector3(0, min − 64, 0), Vector3(64*CELL, max − min + 64, 64*CELL))`
  from `chunk_bounds` (mandatory: displaced meshes are otherwise culled wrongly).
- LOD choice (GDScript, every 0.25 s or when the camera moved > 20 m): distance from the camera to the
  chunk AABB; thresholds `250, 550, 1200, 2600` m → LOD 0..4; switch up only when the distance is
  10 % past a threshold, down when 10 % inside (hysteresis). Expose `lod_for(distance, current)` as a
  pure static function for the tests.
- Camera `far = 12000`, `near = 0.25`, vertical `fov = 48`.
- Terrain does not cast Godot shadows in M0 (`cast_shadow = OFF`); creature contact shadows come from
  occluders (4.7).

### 4.4 Material shading, palette C (`look.gdshaderinc`, `land.gdshaderinc`, `terrain.gdshader`)

Source of truth: `tools/hero/build_hero.py` — the `golden` preset deep-merged with `PAL.C`
(G63), the `LAND0` defaults overridden by `PAL.C.land`, and the V8 land shader. Put every constant
in `game/island/look.gd` (GDScript) **and** pass them as shader uniforms without `source_color`
(three.js used these numbers raw).

Resolved palette C "Current+" (golden):

| Name | Value |
|---|---|
| `SUN_DIR` (towards the sun) | `normalize(-0.62, 0.28, -0.72)` |
| sun colour / intensity | `#ffd6a0` / 3.2 (for Godot-lit creatures) |
| hemisphere sky / ground / intensity | `#a8ccf8` / `#6a6a5c` / 0.5 |
| exposure | 1.0 (three `toneMappingExposure`) |
| toon ramp (props, later) | `[46, 46, 82, 82, 112, 112]` / 255, nearest, 6 texels |
| `grass` tint | `(1.03, 0.96, 0.86)` |
| `shK` | `1 − 0.58 · 1 = 0.42` |
| air: density, start, falloff | `0.00052`, `140.0`, `240.0` |
| air cool / warm | `(0.34, 0.58, 0.88)` / `(0.96, 0.74, 0.46)` |
| sky hz / mid / top / glow / disc | `(.95,.84,.70)` / `(.52,.70,.93)` / `(.13,.39,.84)` / `(1,.62,.3)` / 3 |
| land `g0` / `g1` | `(.090,.225,.040)` / `(.185,.335,.075)` |
| `lit` / `shade` / `sTint` | `(1.10,1.03,.90)` / `(.86,.92,1.10)` / `(.80,.86,1.14)` |
| `tuft0` / `tuft1` | `(.82,.90,.78)` / `(1.04,1.02,.98)` |
| `bladeLo` / `bladeHi` | `.52` / `1.28` |
| `r0` / `r1` / `r2` | `(.15,.165,.19)` / `(.28,.215,.14)` / `(.19,.135,.085)` (r2 from LAND0) |
| `scree` | `(.27,.23,.16)` (LAND0) |
| `snow` | `(.78,.88,.95)` |
| `rockShade` / `rockLit` | `(.68,.84,1.20)` / `(1.30,1.10,.84)` |

Not in PAL.C (the hero had no such surfaces). Use these **proposed** values and list them in
M0.md for the owner: `sand = (.42,.37,.25)`, `volcanic r0/r1 = (.075,.07,.075)/(.13,.10,.085)`,
`wet tint = (.82,.90,.84)`, `channel = (.035,.09,.13)`.

Hero helper functions, ported verbatim to `land.gdshaderinc` (GLSL → Godot shading language):

```glsl
float landHash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float landNoise(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0 - 2.0*f);
  return mix(mix(landHash(i), landHash(i + vec2(1,0)), f.x), mix(landHash(i + vec2(0,1)), landHash(i + vec2(1)), f.x), f.y); }
float meadowWave(vec2 p, float t){ return smoothstep(.45, .98, sin(dot(p, vec2(.8,.6))*.085 - t*1.1)); }
float landRamp(float l){ return .60 + .25*smoothstep(.18,.25,l) + .23*smoothstep(.53,.61,l); }
float tone(vec2 xz){ // replaces the hero's CPU fbm(x*.03, z*.03, 3) field (t.b)
  return (landNoise(xz*.03)*.5714 + landNoise(xz*.06)*.2857 + landNoise(xz*.12)*.1429); }
vec3 meadowColor(float t_b, float t_a, float light, float wave, vec2 xz){
  vec3 c = mix(G0, G1, smoothstep(.22, .80, t_b));
  c *= mix(.56, 1., t_a) * landRamp(light) * GRASS;
  c *= mix(SHADE, LIT, smoothstep(.15, .6, light));
  return c * (.78 + .30*landNoise(xz*.19) + .14*landNoise(xz*.63)) * (1. + wave*.12); }
```

Terrain fragment (`render_mode unshaded, cull_back`; `t_a = 1` in M0, no trees):

```glsl
vec3 gn = normal from bilinear height at ±CELL (same at every LOD → no lighting pops);
float light = max(dot(gn, SUN_DIR), 0.);
vec2 xz = wp.xz; float wave = meadowWave(xz, TIME), msh = occluder_shadow(wp);  // 4.7; 1 if none
vec3 meadow = meadowColor(tone(xz), 1., light, wave, xz) * vec3(.60,.68,.54) * mix(SHK, 1., msh);
meadow *= mix(STINT, vec3(1.), msh);
float grain = landNoise(xz*.17), mineral = landNoise(xz*.023), erosion = landNoise(xz*.081);
float steep = 1. - smoothstep(.48, .76, gn.y);
float strata = sin(wp.y*(.075 + .035*landNoise(xz*.012)) + erosion*6. + mineral*8.) * steep * smoothstep(.40,.72, landNoise(xz*.044));
float rockLight = .36 + .56*smoothstep(.12,.22,light) + .48*smoothstep(.50,.60,light);
vec3 rock(vec3 a0, vec3 a1) = mix(a0, a1, smoothstep(.25,.78,mineral)), then mix(.., R2, smoothstep(.57,.87,erosion)*.4),
     *= 1. + strata*.045 + (grain-.5)*.16 + (landNoise(xz*.63 + wp.y*.04)-.5)*.10,
     *= mix(ROCK_SHADE, ROCK_LIT, smoothstep(.18,.52,light)) * rockLight,
     *= mix(1., .64, cavity);
vec3 rockC  = rock(R0, R1) * GRASS;
vec3 screeC = mix(rockC, SCREE * rockLight * GRASS, .85);
vec3 volcC  = rock(VR0, VR1) * GRASS;
vec3 sandC  = SAND * landRamp(light) * GRASS;
vec3 snowC  = SNOW * landRamp(light) * GRASS;
// material weights: bilinear blend of one-hot ids of the 4 nearest cells, sampled at
// xz + (landNoise(xz*.11) − .5, landNoise(xz*.11 + 17.) − .5) * CELL * .8 to break the grid
float turfSlope = smoothstep(.74, .94, gn.y);           // hero's turf slope term
w_rock += w_meadow * (1. − turfSlope); w_meadow *= turfSlope;
vec3 land = w_meadow*meadow + w_rock*rockC + w_scree*screeC + w_volc*volcC + w_sand*sandC + w_snow*snowC;
land = mix(land, meadow, grass_mask_bilinear);          // hero: meadow under the blades
land *= mix(vec3(1.), WET_TINT, smoothstep(0., .4, wet) * .6);
land = mix(land, CHANNEL * landRamp(light), smoothstep(.4, .6, wet) * .55);
ALBEDO = scene_out(land, wp);                           // look.gdshaderinc, 4.5
```

### 4.5 Tone mapping, aerial perspective, sky and fog (`look.gdshaderinc`, `environment.gd`)

The hero (three.js r128) applies, per fragment: ACESFilmic tone mapping → sRGB encoding →
**then** the aerial haze (`fog_fragment` comes after `encodings_fragment` in r128), with haze colours
in display (sRGB-encoded) space. The sky dome and the grass `ShaderMaterial`s write display values
directly. Godot instead tone-maps everything after the shader. To match exactly:

1. **Calibrate Godot's ACES to three's** (`render_tests.gd`, S7). Reference (three r128):
   ```glsl
   const mat3 ACES_IN  = mat3(vec3(.59719,.07600,.02840), vec3(.35458,.90834,.13383), vec3(.04823,.01566,.83777));
   const mat3 ACES_OUT = mat3(vec3(1.60475,-.10208,-.00327), vec3(-.53108,1.10813,-.07276), vec3(-.07367,-.00605,1.07602));
   vec3 rrt(vec3 v){ return (v*(v + .0245786) − .000090537) / (v*(.983729*v + .4329510) + .238081); }
   vec3 three_aces(vec3 c){ return clamp(ACES_OUT * rrt(ACES_IN * (c / .6)), 0., 1.); }   // exposure 1
   ```
   Godot 4's ACES uses the same fit with an exposure bias of 1.8 and a division by the white point's
   tone-mapped value, so start from `tonemap_mode = ACES`, `tonemap_exposure = (1/0.6)/1.8 ≈ 0.926`,
   `tonemap_white ≈ 14.3` (where the curve reaches 1.0). **Do not trust this from memory**: fetch
   `drivers/gles3/shaders/tonemap_inc.glsl` of tag `4.7.2-stable` from GitHub (read-only, for
   reference) and fit `exposure`/`white` by rendering unshaded patches of known linear values
   `{.02,.05,.1,.2,.4,.8,1.6,3.2}` (grey and three tints) and reading the viewport back. Gate: max
   error ≤ 3/255 against `srgb_encode(three_aces(L))`. Store the result in `look.gd` and
   `docs/evidence/godot/m0/calibration.json`.
2. `look.gdshaderinc` provides `tm(c)` (the calibrated curve = `three_aces`), `tm_inv(d)` (exact
   inverse: `ACES_OUT⁻¹`, per-channel root of the rational fit
   `x = (−(A−Dy) + sqrt((A−Dy)² + 4(1−Cy)(B+Ey))) / (2(1−Cy))` with `A=.0245786, B=.000090537,
   C=.983729, D=.4329510, E=.238081`, `ACES_IN⁻¹`, `·0.6`; paste the inverse matrices as numeric
   constants; clamp `d` to `[0, .985]`), `srgb_encode/decode`, and
   ```glsl
   vec3 aerial(vec3 disp, vec3 wp)   // display-space haze, verbatim from build_hero.py AERIAL
   vec3 scene_out(vec3 lin, vec3 wp){ return tm_inv(srgb_decode(aerial(srgb_encode(tm(lin)), wp))); }
   vec3 display_out(vec3 disp){ return tm_inv(srgb_decode(disp)); }
   ```
   `aerial()`: `ray = wp − CAMERA_POSITION_WORLD; d = length(ray); heights = max(vec3(cam.y, mix(cam.y, wp.y, .5), wp.y), 0);
   rho = exp(−heights/240); path = max(d − 140, 0); optical = path*(1 − exp(−path/240))*.00052*dot(rho, vec3(.1667,.6666,.1667));
   sunward = pow(max(dot(ray/d, SUN_DIR), 0), 3); haze = mix(COOL, WARM, sunward); return mix(c, haze, 1 − exp(−optical));`
   Gate (render test): `display_out(d)` rendered unshaded reads back `d` within 2/255 on a 5×5×5 grid.
3. **Fallback** if the fit cannot reach the gate: `tonemap_mode = LINEAR`, exposure 1, white 1, and
   `scene_out()` / `display_out()` return `srgb_decode(...)` of the display value computed with
   `three_aces` in-shader. The world then matches the hero exactly, but Godot-lit creatures lose their
   tone mapping — record it as an open issue for g-creature. Choose one, document which in M0.md.
4. `WorldEnvironment` (`environment.gd`): background = `Sky` with `sky.gdshader`; fog **off**
   (aerial replaces it; the hero's linear fog `(.86,.88,.88)` 110–760 m is not used after V8);
   glow, SSAO, SSR, adjustments off (they would move tone mapping to a post pass); ambient light
   source = Color `#a8ccf8`, energy 0.5 (the hemisphere's sky half — Godot has no hemisphere
   light); reflected light = sky.
5. `sky.gdshader` (`shader_type sky;`): `n = EYEDIR; h = max(n.y, 0)`;
   `c = mix(HZ, MID, smoothstep(0., .28, h)); c = mix(c, TOP, smoothstep(.2, .95, h));
   s = max(dot(n, SUN_DIR), 0.); c += GLOW*pow(s, 7.)*.55 + vec3(1., .97, .9)*smoothstep(.9988, .9995, s)*3.;`
   `COLOR = display_out(c)` (the hero dome writes display values). Clouds: M1 TODO.
6. `DirectionalLight3D` "Sun": points along `−SUN_DIR`; `light_color = Color(1.0, 0.839, 0.627)`
   **as linear** (three r128 used hex values unconverted: set `Color(...).linear_to_srgb()` so
   Godot's sRGB→linear gives the raw numbers back), energy 3.2, shadows on (creatures). These affect
   only Godot-lit materials (creatures); g-creature tunes their look on top.

### 4.6 Sea, lakes and shoreline (`water.gd`, `water.gdshader`)

- **Sea**: one `PlaneMesh` 40 km × 40 km at `y = 0`, subdivided 1×1, `custom_aabb` large. Fragment
  depth `= 0 − ground_bilinear(wp.xz)` from `height_tex` inside the square, `60` outside it.
- **Lakes**: one `ArrayMesh` built on the CPU from pond cells (`is_pond`), one quad per pond cell
  plus a one-cell dilation, at `y = max(level of the 3×3 neighbourhood's pond cells)`; depth in the
  shader `= level − ground`. Rivers stay a colour (4.4 wet/channel) in M0.
- Shader (`render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled`), from the reference
  water (`valle-primigenio.html:413-420`, hero-patched):
  ```glsl
  vec3 c = mix(vec3(.36,.80,.76), vec3(.07,.32,.56), smoothstep(0., 7., depth));
  vec3 V = normalize(CAMERA_POSITION_WORLD − wp); vec2 q = wp.xz; float t = TIME;
  vec3 n = normalize(vec3(sin(q.x*.6 + t*1.3)*.07 + sin(q.y*1.7 − t)*.04, 1.,
                          cos(q.y*.5 + t*1.1)*.07 + sin(q.x*1.3 + t*.7)*.04));
  float fr = pow(1. − max(dot(V, n), 0.), 4.); c = mix(c, vec3(.80,.91,.97), fr*.5);
  c += vec3(1., .95, .8) * pow(max(dot(n, normalize(V + SUN_DIR)), 0.), 160.);
  float foam = 1. − smoothstep(0., .22, depth + sin(t*1.4 + q.x*.8 + q.y*.6)*.06); c = mix(c, vec3(1.), foam*.85);
  ALPHA = max(mix(.6, .96, smoothstep(0., 3., depth)), foam);
  ALBEDO = scene_out(c, wp);
  ```
  Beyond ~600 m force `ALPHA = 1` (avoids seeing the sea floor through far water and z-fighting).
- The C stage world knows only one water circle (4.9). Lakes outside the ±195 m area are purely visual.

### 4.7 World-anchored grass with wind (`grass.gd`, `grass.gdshader`)

Port of the hero's final meadow (`build_hero.py` `GRASS_V9`):

- One `MultiMesh` (`TRANSFORM_3D`, `use_custom_data = true`, `use_colors = true`), all transforms
  identity, `instance_count = near + far` with `near = 200000`, `far = 52000` (setting
  `Game.settings.grass`; tests use 20000 + 5200). `MultiMeshInstance3D` at the origin with
  `custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 900, 4000))`, `cast_shadow = OFF`.
- Blade mesh: 5 vertices `(-.5,0,0) (.5,0,0) (-.23,.55,0) (.23,.55,0) (0,1,0)`, indices
  `0,1,2, 2,1,3, 2,3,4`; `cull_disabled`.
- Offsets (CPU, `RandomNumberGenerator` seeded 8808; visuals only): for instance `i`, `lod = i ≥ near`,
  clump size `8` (near) / `4` (far); at each clump start draw `a ∈ [0, 2π)`, `u`, radius
  `r = lod ? sqrt(34² + u(140² − 34²)) : 44·u^0.72`, centre `(cos a·r, sin a·r)`, clump value `ch`;
  per blade `a2`, `r2 = sqrt(rand) · (lod ? .52 : .25)`. `INSTANCE_CUSTOM = (cx + cos a2·r2,
  cz + sin a2·r2, rand, lod)`; instance colour `r = ch`.
- Vertex shader (verbatim logic): `R = lod ? 140 : 44; base = o + floor((center.xz − o)/(2R) + .5)·2R`
  (toroidal wrap → each blade has a fixed world position); `fade = lod ? (1 − smoothstep(110,140,d))·smoothstep(30,48,d) : 1 − smoothstep(30,44,d)`;
  `rolling = .65 + .55·sin(base.x·.033 + sin(base.y·.027))·.5 + tone(base)·.4`;
  `hg = mix(.48 + .75·clump, .30 + .40·clump, lod)·rolling·mask(base)·fade` with `mask` = bilinear
  G of `surface_tex`; base height = **`ground_tri(base)`** in the shader (same diagonal rule as
  `ground()`, 4 `texelFetch`) − .025; light from the height-texture normal; creature occluders (shadow
  and push, near LOD only, 12 entries); `wave = meadowWave(base, TIME)`, `gust = sin(base.x·.12 + base.y·.09 + TIME·1.6)`;
  `bend = (.10 + .15·gust + .3·wave)·p.y²·hg`; `ang = rand·44`; `wd = mix(.12,.25,lod)·(.65 + rand·.6)·fade·step(.008,hg)`;
  `wp = (base.x + p.x cos(ang) wd + bend·.85, ground − .025 + p.y·hg, base.y + p.x sin(ang) wd + bend·.5)`,
  `wp.xz += push_dir·p.y·hg·.9`. Write `VERTEX` in world space with `render_mode world_vertex_coords`
  (identity transforms, so model = world).
- Fragment: `c = meadowColor(tone, 1, light, wave, xz) · mix(TUFT0, TUFT1, clump) · mix(BLADE_LO, BLADE_HI, smoothstep(0,1,h)) · mix(SHK, 1, sh)`;
  `c *= mix(STINT, vec3(1), sh)`; `c += vec3(.14,.20,.035)·h²·back·sh` (`back = pow(max(dot(normalize(wp − cam), SUN_DIR), 0), 4)`);
  `ALBEDO = scene_out(c, wp)`; `render_mode unshaded`.
- `center` uniform = the player creature's interpolated position each frame.

### 4.8 Creature contact shadows (`occluders.gd`)

The hero darkens ground and grass under the creature with 12 sphere occluders (`meadowShadow`):
8 spine samples (radius × 1.05) + up to 4 feet (radius `leg.w × 2.2`, or 0.25 for the placeholder),
unused entries `(0, −999, 0, 0)`. Update `uniform vec4 occ[12]` and `center` on the terrain and
grass materials every frame. Shadow test as in the hero (`tca = dot(oc, SUN_DIR); d2 = |oc|² − tca²;
sh *= mix(1, smoothstep(r²·.5, r²·1.4, d2), step(0, tca))`, only within 24 m of `center`).

### 4.9 C stage setup on the island (`stage_setup.gd`)

The C world (`stage_world.c`) has only analytic and flat height sources and a hard ±195 m bound
(`docs/WORLD.md`); wiring the generated heightfield into C is BACKLOG item 6 (a core change, **not
M0**). So in M0:

- `terrain = 1` (FLAT), `flat_height = 42.0` (`valley_floor_m`), nest `(0, 0)` (the valley centre;
  assert `ground(0,0) > 1` and not pond).
- Water circle: centroid and equivalent radius `sqrt(cells·CELL²/π)` of pond cells inside
  `|x|, |z| ≤ 195`; radius 0 if none. The player cannot walk into it (C: ground < −0.7 blocks).
- One wild Garfio (species 3, bot −1, profile `CP_STAGE_SPECIES[3]` via `species()`): home = the
  first of 64 directions `k·2π/64` at 60 m from the nest whose straight path (21 samples) is dry,
  not pond and `normal.y > 0.8`. Aggressive creatures approach inside 28 m, so this keeps spawn quiet.
  `Game.settings.wild = false` (tests/evidence) removes it.
- Player profile = `profile.gd` (port of `web/engine/profile.js`, `profileFromStudio`, using
  `game/data/parts.json`) of the player genome.
- Rendering: creatures are drawn at `Y = Game.ground(x, z)` of the island; C ignores island slope.
  The playable area is the ±195 m valley (an invisible wall at the bound). State both in M0.md.

---

## 5. Chase camera and controls

### 5.1 `chase_camera.gd` (port of `web/stage/camera.js` on branch `feel-camera`, the G72 camera)

Read it with `git show feel-camera:web/stage/camera.js`. Numbers (all exact):

| Item | Value |
|---|---|
| `h` (creature height) | `max(.5, rest AABB height)` (placeholder: its own AABB) |
| distance | default `6h`, min `2.8h`, max `12h` (G72: 5–7× at default) |
| base pitch (boom elevation = view pitch below horizontal) | `.24` rad (13.75°; G72 12–18°) |
| pitch with zoom | `wide = clamp((distance/h − 6)/6, 0, 1)`; `pitch = clamp(.24 + wide·.6 + orbitPitch, .04, 1.15)` |
| look-at target | `(x, ground + 1.5h, z)`, eased with τ = .25 s (`1 − exp(−dt/.25)`); then `target.y = max(target.y, ground(target) + .8)` **unsmoothed** |
| auto-follow | when `speed > .4` and no manual grace: `yaw += wrap(player_yaw + π − yaw)·(1 − exp(−dt/.4))` (G72 ~0.4 s) |
| orbit | right or middle drag: `yaw −= dx·.006`, `viewYaw −= dx·.006`, `orbitPitch = clamp(orbitPitch + dy·.004, −.2, .5)`, `manual = .15` s grace |
| zoom | wheel: `distance = clamp(distance + delta, min, max)` with `delta = ±1` m per notch (web `deltaY·.01`) |
| boom | eased τ .3 s towards the desired distance |
| fight framing | `fightBlend` τ .25 s; `viewYaw = yaw + fightBlend·.85`; target = midpoint, `y` = mean ground + 1.5h; desired = `max(d + sep·.6, (sep/2 + 1.5h)/sin(halfFov·.85))`, `halfFov = atan(tan(24°)·min(1, aspect))`; fighting = `state.active ≥ 0` |
| collision | march the boom from the target in .2 m steps; first sample below `ground + .65` → length = sample − .25; finally `position.y = max(position.y, ground(position) + .65)` |
| projection | vertical `fov = 48°`, near .25, far 12000; `look_at(target)` |
| narrow windows | `distance × 1.25` when `aspect < .7` |

Camera position: `target + (sin(viewYaw)·cos(pitch), sin(pitch), cos(viewYaw)·cos(pitch))·length`.
With pitch .24 and fov 48 the horizon sits ~22 % from the top (upper third, G72). Initial yaw: from
the Garfio home towards the nest, as the web (`atan2(nest.x − home.x, nest.z − home.z)`).

### 5.2 Controls (`player_input.gd`, `pointer.gd`)

Each C tick (not each frame) `player_input.sample()` returns the `CpStageInput` dictionary, porting
`web/stage/simulation.js action()` and `stage.js input()`:

1. WASD/arrows: `x = right − left`, `z = back − forward`; camera-relative
   `w = (x·cos(viewYaw) + z·sin(viewYaw), −x·sin(viewYaw) + z·cos(viewYaw))`. Non-zero → clear the
   destination; verb HEADING (3) with `hx, hz = heading(w)`, `sprint` = Shift.
2. `heading(v)`: `s = max(|v.x|, |v.y|)`; `hx = floor(v.x/s·32767 + .5)`, `hz = floor(v.y/s·32767 + .5)`
   (`floor(+.5)` reproduces JS `Math.round`; GDScript `round()` differs on negative halves).
3. Click/hold (`walk_to`): on press, ray-march the ground (below); if it hits, set the destination
   (clamped to ±194.9) and remember the pointer; while held, resample every frame (web `update()`).
   Clicking a creature (ray within its radius of a living entity, entities before ground) emits
   `Game.creature_clicked(id, pos)` and clears the destination instead.
   Destination set → verb GO (2) with `x, z`, `sprint` = Shift.
4. Nothing → verb WAIT (1). Clear the destination when `state.order.verb != GO` after a tick (web).
5. While `Game.movement_blocked()` treat movement keys as released.

Ray-march (`pointer.gd`, port of `web/stage/pointer.js groundHit`): from `camera.project_ray_origin`
along `project_ray_normal`, `t = 1..900` m step 1; first `p.y <= ground(p)` → bisect 14 times between
the previous and current `t`. Return `null` if nothing is hit.

### 5.3 The 10 Hz bridge (`stage_world.gd`, Node in the island)

- Owns one `CporeWorld`; `reset(stage_setup)` on ready; keeps `prev` and `cur` state dictionaries.
- `_process(delta)`: `acc += min(delta, .25)`; `while acc + 1e-9 >= .1`: `input = player_input.sample()`;
  `prev = cur`; `world.step(input)`; `cur = world.state()`; append `{tick, input}` to the log;
  emit `Game.world_ticked(cur)` (and `combat_events` if any); `acc = max(0, acc − .1)`.
  `alpha = acc / .1`.
- `sample(id) -> {pos: Vector3, yaw: float, speed: float, vel: Vector3}`: lerp `x, z` between `prev`
  and `cur` by `alpha`; yaw = shortest-arc lerp of `atan2(fx, fz)`; `pos.y = Game.ground(x, z)`;
  `vel = (cur − prev)/.1` in xz.
- `export_log() -> String`: `CPORE_WORLD_LOG 1` exactly as `apps/world_cli.c replay()` parses it
  (`world_log.gd`, shared with the tests): setup line `seed terrain_seed terrain nest_x nest_z
  flat_height water_x water_z water_radius n n_obstacles`, player profile line `mouth charge spit
  tail guard hp stamina speed radius_cm`, one line per wild `x z home_x home_z species bot` +
  profile, one per obstacle `x z r type`, tick count, then `verb target move dir sprint hx hz x z`
  per tick. Floats written from their float32 value (`String.num(v, 17)` of a value that came from
  C is exact; for values made in GDScript, store what C will parse — WORLD.md warns about decimal
  midpoints).
- Actors: the player and each wild entity get an `actor_host.gd` node (6.); every frame set
  `driver.update(dt, sample(id))`.

---

## 6. Creatures: g-creature integration and the placeholder

`actor_host.gd` (Node3D), created per entity:

```gdscript
func setup(genome: Dictionary, entity_id: int, profile: Dictionary) -> void
func height() -> float            # for the camera; ≥ 0.5
func update(dt: float, s: Dictionary) -> void   # s from StageWorld.sample()
func occluders() -> Array         # up to 12 Vector4 for 4.8
```

- If `res://creature/creature.gd` exists: instantiate it, `load_genome(genome)`; on `ok == false`
  fall back to the placeholder and log the error. Else the placeholder.
- `actor_driver.gd` chooses the motion: g-loco present → controller + adapter (2.5); else rest
  pose glide: node at `s.pos`, `Basis(UP, s.yaw)`, feet targets on the ground under the rest soles,
  `solve_legs()` (real rig) — or nothing (placeholder).
- **Placeholder** (`placeholder_creature.gd`, M0-only, deliberately simple): a swept tube through
  the genome nodes `(0, y, z)` with radius `r` (12 sides, Catmull-Rom in z with 6 samples per span,
  `SurfaceTool`), the skin colour `skin.cA` in a `StandardMaterial3D`, two dark spheres as eyes at the
  front node, and for each `pata` part a straight capsule from its spine anchor (`t` along the node
  chain, side by `ang`) down to the ground. Origin on the ground, +Z forward. It is a stand-in until
  the g-creature merge; do **not** port rig.js beyond this (g-creature owns it).
- Wild Garfio: genome `game/data/garfio.json` (copy of `web/stage/species/garfio.json`), same host.
- Player name for the HUD: `genome.name`.

---

## 7. Implementation steps

Run every Godot command with `timeout` and `nice -n 10`; send output to a file and read it
(a GDScript parse error never quits). Syntax-check new scripts first:
`godot --headless --path godot --check-only --script res://game/<file>.gd`. Commit after each step.
`make test` must stay green throughout (baseline: PASS, 24 s).

**S1 — Make the WIP build and load.**
Files: `godot/extension/SConstruct`, `build_profile.json`, `Makefile` (block moved to the end, §3.2),
`godot/.gitignore`. Temporarily keep `cpore.cpp` as is.
Accept: `make -n | head -1` starts with the `world_cli`/core build (default goal restored);
`rm -rf godot/.godot && make godot` exits 0 (no abort) and `ls godot/bin/libcpore.linux.template_debug.x86_64.so`;
`make godot` again exits 0; the old test (moved path is fine) prints `PASS (0 failures)`.

**S2 — `CporeTerrain`.**
Files: `godot/extension/{register_types.cpp, cpore_terrain.h, cpore_terrain.cpp, convert.h, terrain_fields.inc}`;
remove `cpore.cpp` once both classes exist (S3). Tests: `godot/game/tests/run_m0_tests.gd` (runner:
checks `ClassDB.class_exists` for both classes first, then runs each `test_*.gd`, prints
`M0 tests: <checks> checks, <failures> failures`, `quit(1 if failures else 0)`), `test_terrain.gd`.
Accept (`make godot-test`): defaults equal the W20 values listed in 3.3; hashes equal
`build/terrain_cli hash --seed S --n N` for (42, 64), (7, 128), (1234, 128) and (1, 1024) once;
`water_level` present, size `n*n`, and ≥ the height on every cell; `validate` rejects
`{n: 64.5}`, `{seed: -1}`, `{seed: 4294967296}`, `{not_a_param: 1}`, `{n: "64"}`, `{erosion: NAN}`;
a threaded generate reports `progress().stage` 0→4 monotonically and `running` false at the end;
a concurrent second `generate` on the same instance returns `CP_TERR_ERR_BUFFER`;
`CporeTerrain.hash(result) == result.hash`, and flipping one height byte changes it.

**S3 — `CporeWorld`.**
Files: `godot/extension/{cpore_world.h, cpore_world.cpp}`; `godot/game/stage/world_log.gd`
(parse/write `CPORE_WORLD_LOG 1`); `godot/game/tests/test_world.gd`.
Accept: for each of `tests/golden/world-{1,42,987654321}.log`, `reset(parsed setup)` then 3000 ×
`step(row)` gives **every** hash equal to the matching `.hashes` line; two worlds stepped with the same
180 random inputs (fixed `RandomNumberGenerator` seed) stay hash-equal; `observe()` parses as JSON with
`world-1` schema; `command("invalid verb") != 0` and leaves `hash()` unchanged; `reset` with a bad
profile (`mouth: 6`) returns −1 and keeps the old state; `step({hx: 40000})` returns `""` and
does not advance `state().tick`; `species()` has 4 entries with Garfio aggressive.

**S4 — Project skeleton.**
Files: `godot/project.godot` (§2.2, with the input map), `godot/game/game.gd`, `game/main.tscn`,
`main.gd`, `game/island/island.tscn` (empty Node3D for now), `godot/README.md` (build/run stub).
Delete `godot/scripts/` and `godot/tests/test_extension.gd` (moved).
Accept: `make godot` exits 0 with no `ERROR` lines in the import log;
`timeout 60 godot --headless --path godot --quit-after 30` exits 0, log has no `ERROR`/`SCRIPT ERROR`;
the input actions of 2.4 exist (`InputMap.has_action`) — test in `test_project.gd`.

**S5 — Cache and loading screen.**
Files: `game/island/terrain_cache.gd`, `game/loading/loading_screen.tscn/.gd`, `main.gd` flow.
Test `test_cache.gd` (n = 128 params, directory `user://m0-tests/`): first load `hit == false`,
second `hit == true` with equal hash and maps; truncated file, wrong magic, wrong format version and a
modified height byte (hash mismatch) each regenerate; `erosion` changed → different path; the key
contains the generator version and `RENDER_PREP_VERSION`; directory removed at the end.
Accept: `make godot-test` passes; a manual
`godot --headless --path godot --quit-after 600` run twice with an empty `user://terrain/` logs
`terrain cache: miss` then `terrain cache: hit` (record the two times in M0.md).

**S6 — TerrainData.**
Files: `game/island/terrain_data.gd`. Test `test_ground.gd` (n = 128 terrain, but with `CELL` from
its own `size_m/n`): `ground()` at every 7th cell centre equals `height[k]` exactly (float32
compare); at 1000 random points equals the triangle formula recomputed independently and lies within
`[min, max]` of the 4 corners; the surface map has `material` in 0..5, grass 0 on sea/pond/non-meadow
cells; `chunk_bounds` contain every lattice height of their chunk; pond and sea classification
match the lab rule on 200 cells. Time the N=1024 derived-map pass and log it.

**S7 — Look calibration, environment and sky.**
Files: `game/island/look.gd`, `game/shaders/look.gdshaderinc`, `calibrate.gdshader`,
`sky.gdshader`, `game/island/environment.gd`, `game/tests/render_tests.gd`.
Accept (`make godot-render-test`, software GL): the ACES fit gate (≤ 3/255) and the `display_out`
round-trip gate (≤ 2/255) of 4.5 pass, or the fallback is selected and documented; the sky renders
with the sun disc at `SUN_DIR` (read back the pixel at the sun's projected position: brightest in
the frame). `calibration.json` written.

**S8 — Terrain chunks, LOD and material shading.**
Files: `game/island/terrain_chunks.gd`, `game/shaders/land.gdshaderinc`, `terrain.gdshader`,
`island.gd` (adds terrain + environment), `island.tscn`.
Tests: `test_lod.gd` — `lod_for` thresholds and hysteresis (e.g. 260 m from LOD0 stays 0, 276 m → 1;
1.0 km → 2), the LOD meshes' vertex counts (65², 33², 17², 9², 5² + skirts), every chunk's
`custom_aabb` contains its heights; index order of the first quad gives a −Y cross product.
Render check (in `render_tests.gd`): a top-down frame of the island has no background (sky) pixels
inside the square's land area at LOD4 (no cracks); a debug mode `lod_debug` colours chunks by LOD.
Evidence (manual, viewed with Read): far view from `(0, 900, 2600)` looking at `(0, 150, 0)`.

**S9 — Sea, lakes, shoreline.**
Files: `game/island/water.gd`, `game/shaders/water.gdshader`.
Accept: test — lake mesh quads exist only on pond cells (+ dilation) and their `y` equals the level;
render — a frame looking at the coast has foam-white pixels along the waterline and no sea drawn
above land (sample a known land pixel).

**S10 — Grass.**
Files: `game/island/grass.gd`, `game/shaders/grass.gdshader`.
Accept: test — offsets reproducible for the seed (first 5 custom-data rows fixed), the wrap formula
maps a blade to the same world base for two centres 2R apart; render — frame at the spawn shows
blades (green-yellow pixels above the ground line) and none on sand/rock (aim a frame at a beach).

**S11 — The 10 Hz bridge and stage setup.**
Files: `game/stage/stage_world.gd`, `stage_setup.gd`, `profile.gd`, `game/data/*.json`
(copies: `web/studio/parts.json` → `parts.json`, `web/stage/species/garfio.json`, `garfio-combat.json`,
and `merodeador.json` from rig.js `SEEDS`), `game/tests/fixtures/profile_expected.json`, a node
script `game/tests/fixtures/gen_profile_expected.mjs` that imports `web/engine/profile.js` and
writes the expected profiles for Merodeador, Garfio and `tests/fixtures/studio/v{1..4}` (after
migration where needed — if a v1–v3 fixture needs the studio migrator, limit to v4 and the seeds).
Tests: `test_profile.gd` (Godot profile == expected JSON, field by field; data copies byte-equal to
their `web/` sources); `test_session.gd` — drive `StageWorld` headless with a scripted input
provider for 300 ticks (heading, sprint, GO destination, WAIT), export the log, run
`build/world_cli --replay <file>` via `OS.execute`, and compare all 300 hashes; interpolation:
`sample()` at `alpha` 0, .5, 1 equals prev, midpoint, cur; nest dry, water circle inside ±195,
Garfio home ≥ 50 m from the nest.

**S12 — Input and pointer.**
Files: `game/player/player_input.gd`, `pointer.gd`.
Test `test_input.gd`: `heading()` equals the JS rule on 30 vectors including negative halves
(e.g. `(−0.5/32767, 1)`); camera-relative mapping at `viewYaw` 0, π/2, π gives W → (0,−1)/(−1,0)/(0,1);
WASD clears a destination; release with no destination → WAIT; `movement_blocked` zeroes movement;
ray-march hits a synthetic `ground` (plane at y=42 and a slope) within 1 cm; destinations are clamped
to ±194.9.

**S13 — Chase camera.**
File: `game/player/chase_camera.gd`.
Test `test_camera.gd` (pure maths with a synthetic ground): at default distance pitch = .24 and
distance = 6h; target height = ground + 1.5h after settling; after 0.4 s of steady motion with a 90°
heading offset the yaw has closed 1 − e⁻¹ ≈ 63 % (±2 %); zooming to 12h raises pitch to `.24 + .6`;
a ridge between target and camera shortens the boom and the camera stays ≥ ground + .65; the
projected horizon (a far point at camera height straight ahead) is above 1/3 of the screen height
for a 1280×720 viewport; fight framing keeps both fighters inside the frustum.

**S14 — Actors.**
Files: `game/actors/actor_host.gd`, `placeholder_creature.gd`, `actor_driver.gd`; `island.gd`
spawns player + wild, the camera, and wires `StageWorld`.
Test `test_actors.gd`: with the creature module absent the placeholder is used; its AABB height
from Merodeador's nodes is within [1.5, 4] m; placed on `ground()` (min Y of the mesh within 5 cm of
the ground under it); with a fake module object (a script exposing `load_genome`, `rest_aabb`,
`legs`, `solve_legs`) the host uses it — this proves the dynamic hook without g-creature.

**S15 — Contact shadows.**
File: `game/island/occluders.gd`; terrain and grass shaders read `occ[12]`.
Accept: render — the ground directly below the creature on the sun-opposite side is darker than
3 m away on the sun side (two pixel reads).

**S16 — Evidence, docs, final run.**
Files: `game/tests/m0_evidence.gd`, `docs/evidence/godot/m0/*`, `godot/README.md`, `docs/godot/M0.md`.
`make godot-evidence` writes (1280×720): `loading.png` (forced miss), `chase.png` (spawn, default
camera), `far.png` (whole island, far mountains), `close.png` (distance 2.8h, creature large),
`shore.png` (coast with foam), `lod_debug.png`, `timings.json` (generation ms, cache-hit load ms,
island build ms, triangle count via `RenderingServer.get_rendering_info`), `calibration.json`.
Evidence uses `--genome=res://game/data/merodeador.json` and `wild = false`. Look at every PNG
(Read) and compare it with `docs/evidence/hero/palettes/C/golden-mid.png` and `golden-vista.png`;
write the real differences in M0.md. README: `make godot && godot --path godot`, the pin, the
targets, the controls. M0.md: interfaces (2.3–2.6, 3.3, 5.3, 6), what is verified, what is not,
proposed colours, the open issues of §8. Final: `make test`, `make godot-test`,
`make godot-render-test`, `make godot-evidence` all exit 0; report the outputs honestly.

---

## 8. Risks and pitfalls

1. **First import abort** with any GDExtension (engine/godot-cpp issue, §1). Always seed
   `godot/.godot/extension_list.cfg` before importing (the Makefile does). Without it, `--script`
   runs silently lack the extension — the test runner must fail loudly on `class_exists == false`.
2. **godot-cpp master targets 4.8**: always pass `api_version=4.7` (exported in `SConstruct`);
   `compatibility_minimum = "4.7"`. Never `git pull` the shared checkout; it is pinned.
3. **Build profile**: godot-cpp needs `OS`. If you call any other engine class from C++, add it.
4. **Makefile default goal**: keep the Godot block at the end.
5. **Hanging Godot**: a parse error in a `--script` never quits; under xvfb it then spins at full
   CPU. Always `timeout`, `--check-only` first. Kill only your own PIDs (other agents run Godot).
6. **GDScript typing**: `var x := max(a, b)` fails to infer; use `maxf/minf/clampf/maxi`; dictionary
   reads are Variant (type them). JS `Math.round` ≠ GDScript `round` on negative halves.
7. **Float widths**: GDScript floats are doubles, packed arrays and C are float32. Compare heights
   as float32 (`PackedFloat32Array` element vs element), never against recomputed doubles.
8. **Thread safety**: only `generate` and the derived-map pass run on the worker; no node access,
   no `ResourceLoader` there. Wait for the thread on exit.
9. **Tone mapping**: the hero mixes the haze after tone mapping in sRGB space; ignoring that gives
   washed-out or too-dark distance. Calibrate (4.5) before judging colours; never tweak palette
   numbers to compensate.
10. **Post-processing**: enabling glow/adjustments/SSAO in the Environment moves tone mapping to a
    post pass and changes how transparent water blends. Keep them off in M0.
11. **Displaced meshes**: set `custom_aabb` on every chunk and on the grass MultiMesh, or they vanish
    when their undisplaced bounds leave the frustum.
12. **Texture sampling**: height/level textures are `FORMAT_RF`; sample with `texelFetch` and
    `filter_nearest, repeat_disable`; never rely on hardware filtering of 32-bit floats.
13. **Depth precision**: far 12 km with near .25 can z-fight at distant shorelines; mitigated by
    opaque far water (4.6). Do not lower `near` below .25.
14. **Software GL is slow**: 252k grass blades and MSAA at 1280×720 on llvmpipe take seconds per
    frame. Evidence uses `--max-fps 15`, waits a fixed number of frames, renders few images, `nice`.
    Never use the GPU, never open windows on the desktop.
15. **C world limits (known gap)**: flat C terrain, ±195 m bound, one water circle; the island
    heights are visual only. Fix belongs to BACKLOG 6 (C heightfield source), not M0.
16. **Aggressive Garfio**: spawning it < 28 m from the nest starts a fight at once; keep the 60 m rule.
17. **Module coupling**: no `preload`/class names of g-creature, g-loco, g-ui, g-studio in M0; only
    `ResourceLoader.exists` + `load`. M0 must pass its tests on a branch without them.
18. **Nested project**: `godot/studio/project.godot` makes the editor skip that folder; it must be
    deleted at the g-studio merge (M0.md tells the integrator).
19. **Creature lighting**: g-creature tuned its preview with ACES exposure 1.4; the calibrated world
    exposure is lower. Expect a retune at integration; do not change world exposure for creatures.
20. **Cache growth**: one ~5 MB file per seed/version in `user://terrain/`; no eviction in M0 (note it).
21. **Determinism claims**: only the C world is deterministic. Interpolation, camera, grass and the
    loco controller are presentation; never feed them back into C inputs except the player's intent.
