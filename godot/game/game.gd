extends Node
# Autoload "Game": island data, settings, the active StageWorld, scene switching.
# Public surface is documented in docs/godot/M0.md.

signal island_ready
## Shared game events for the creature loop and the owner questions: quest_done:<id>, first_evolve, island_ready {ms}; T1 adds the rest.
signal loop_event(name: String, data: Dictionary)
var evolved_once := false
signal world_ticked(state: Dictionary)
signal combat_events(events: Array)
signal creature_clicked(id: int, world_pos: Vector3)

const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const SETTINGS_PATH := "user://settings.cfg"

# controls/strafe_latch: WASD is relative to the camera as it was when the keys changed (a held S or A runs
# straight); off = the live camera (a held S circles). controls/tank: Spore-style steering, A/D turn the
# creature, W forward, S reverse (overrides the latch).
var settings: Dictionary = {"seed": 1, "grass": 252000, "flora_density": -1.0, "flora_lod_scale": 1.0, "quality": "auto", "sun_shadows": false, "wild": true,
	"controls/strafe_latch": true, "controls/tank": false, "camera/kick": false,
	"ui_scale": 1.0, "language": "", "names_always": false, "numbers": false, "strong_outlines": false, "reduced_motion": false,
	"onboarding": 0, "minimap": true, "edit_anywhere": true,
	"renderer": "auto"}   # auto | forward_plus | compatibility, read at launch by RenderChoice (relaunches into Forward+ on discrete GPUs)
var terrain: Dictionary = {}
var data = null          # TerrainData
var stage = null         # StageWorld while the island runs
var camera: Camera3D = null
var modal_open := false  # set by UI modules (radial, pause)
var radial_open := false # set with modal_open by StageUI, for the key legend context
var paused_ui := false
var journal_open := false # the field journal is open (key legend context "journal")
var options_open := false # the F10 option HUD (devtools/tuning/options_hud.gd): game keys are suspended while it is open
var console_open := false # the dev console (devtools/console) sets this while it has the keyboard
var zoo_args: Dictionary = {}           # {morphs, course} for the locomotion zoo (devtools/zoo), set by the `zoo` console command
var pending_scenario: Dictionary = {}   # a read() scenario (devtools/scenario.gd) the island applies once it is built
var startup_error := ""                 # set when a --scenario could not be loaded (read by the agent server and tests)
var studio_dir := "user://studio"   # where the studio saves and Play looks for the newest creature (tests point it elsewhere)

func _ready() -> void:
	load_settings()
	if RenderChoice.maybe_relaunch():
		get_tree().quit()
		return

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		if cfg.has_section_key("game", key):
			settings[key] = cfg.get_value("game", key)

## Tests and evidence set this false so they never write the player's settings file.
var persist_settings := true

func save_settings() -> void:
	if not persist_settings:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections (audio)
	for key in settings.keys():
		cfg.set_value("game", key, settings[key])
	cfg.save(SETTINGS_PATH)

func set_island(entry: Dictionary) -> void:
	terrain = entry
	data = TerrainData.new()
	data.setup(entry)

func ground(x: float, z: float) -> float:
	return data.ground(x, z) if data != null else 0.0

# The surface the player sees (terrain v5 visual heightfield): creature feet and bodies, the camera and the pointer use it; the C sim keeps ground().
func visual_ground(x: float, z: float) -> float:
	return data.visual_ground(x, z) if data != null else 0.0

func movement_blocked() -> bool:
	if modal_open or console_open or options_open:
		return true
	var vp := get_viewport()
	return vp != null and vp.gui_get_focus_owner() != null

# Which key context is active (first match wins), for the key legend (devtools/legend.gd).
func legend_context() -> StringName:
	if console_open:
		return &"console"
	if journal_open:
		return &"journal"
	if radial_open:
		return &"radial"
	if paused_ui:
		return &"paused"
	if stage != null and stage.cur is Dictionary and int(stage.cur.get("active", -1)) >= 0:
		return &"fight"
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.scene_file_path.contains("/studio/"):
		return &"studio"
	return &"walk"

var entry_t0 := 0                          # ticks (ms) when the last goto_island began
var entry_log: Array = []                  # [{from, ms (scene change + build), phases}] of every island entry (tests read it)
var entry_from := ""

# The island prints its per-phase build times here (brief creature-fixes 5).
func report_entry(phases: Dictionary) -> void:
	var total := Time.get_ticks_msec() - entry_t0 if entry_t0 > 0 else int(phases.get("total", 0))
	var row := {"from": entry_from, "ms": total, "phases": phases.duplicate()}
	entry_log.append(row)
	var parts: PackedStringArray = []
	for k in phases:
		parts.append("%s %d" % [k, int(phases[k])])
	print("island entry (%s): %d ms since goto_island; build %s" % [entry_from, total, ", ".join(parts)])
	if phases.has("kit_reused"):
		last_kit_entry_ms = total
	_entry_finished()

# The island from a place with no loading screen (the studio): the terrain in memory, else the cache, else generated now.
func enter_island_now(from: String = "") -> void:
	enter_island(from)

# --- the island kit (brief creature-fixes 5) ---------------------------------------------------------------
# The built island pieces that depend only on the terrain and the quality settings (terrain meshes and materials, water,
# rivers, grass, the flora and rock batches) are kept in memory when the island scene goes away, and handed back to the next
# island, so entering again from the menu, the studio or a load does not rebuild them. They wait outside the tree.
var _kit: Dictionary = {}            # {key: Array, nodes: {name: Node}}
var kit_hits := 0                    # how many islands were built from the kit (tests read it)

func kit_key() -> Array:
	return [data.get_instance_id() if data != null else 0, int(settings.get("grass", 0)), str(settings.get("quality", "auto")),
		bool(settings.get("sun_shadows", false)), float(settings.get("flora_density", -1.0)), float(settings.get("flora_lod_scale", 1.0)),
		bool(settings.get("wild", true))]

# Called before any scene change: if the running scene is an island, its kit nodes move out of it.
func park_island() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null or not scene.has_method("kit_nodes") or data == null:
		return
	drop_kit()
	var nodes: Dictionary = scene.kit_nodes()
	for n in nodes.values():
		if n != null and n.get_parent() != null:
			n.get_parent().remove_child(n)
	_kit = {"key": kit_key(), "nodes": nodes}

# The parked pieces when they fit the current settings and terrain, else {} (and they are freed).
func take_kit() -> Dictionary:
	if _kit.is_empty():
		return {}
	if _kit.key != kit_key():
		drop_kit()
		return {}
	var nodes: Dictionary = _kit.nodes
	_kit = {}
	kit_hits += 1
	return nodes

func drop_kit() -> void:
	if _kit.is_empty():
		return
	for n in _kit.nodes.values():
		if n != null and is_instance_valid(n):
			n.free()
	_kit = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		drop_kit()

# What the cell stage passes on (docs/CELL-STAGE.md): {} when the player has not finished the cell yet.
const CellLegacy := preload("res://cell/cell_legacy.gd")
var legacy_path := CellLegacy.PATH

func cell_legacy() -> Dictionary:
	return CellLegacy.read(legacy_path)

func save_cell_legacy(d: Dictionary) -> bool:
	if not persist_settings:
		return false
	return CellLegacy.save(d, legacy_path)

## The bridge (docs/godot/CELL-BRIDGE.md): the legacy the NEXT new creature game consumes ({} = a plain hatchling). The island reads it
## when it builds a game that is not a loaded scenario and moves it to applied_legacy, which the journal's family tree shows as the root.
var creature_legacy: Dictionary = {}
var applied_legacy: Dictionary = {}

## Starts a new creature game from the saved legacy (plain = ignore it).
func begin_creature(plain := false) -> void:
	creature_legacy = {} if plain else cell_legacy()


## The island entry of a NEW game started away from the menu (the cell bridge): the terrain cache or the loading screen, then the island.
## `host` is the control the loading screen is added to.
func enter_island_new(_host: Control = null) -> void:
	enter_island("cell")

func goto_menu() -> void:
	park_island()
	get_tree().change_scene_to_file("res://game/menu/main_menu.tscn")

# --- the island entry loading screen (game/loading/entry_veil.gd) ---------------------------------------------------------
const EntryVeil := preload("res://game/loading/entry_veil.gd")
const FAST_ENTRY_MS := 500                 # an entry that took less than this with the kit does not show the screen again
var veil: CanvasLayer = null               # the screen of the entry in progress (null: none, the build runs in one go)
var last_kit_entry_ms := -1                # how long the last entry took that reused the kit
var entry_screens: Array = []              # [{from, shown: bool, kit: bool}] one row per entry (tests read it)

func peek_kit() -> bool:
	return not _kit.is_empty() and _kit.key == kit_key()

## Does this entry get the screen? Yes, unless the kit is parked and the last kit entry was fast.
func entry_screen_wanted() -> bool:
	return not (peek_kit() and last_kit_entry_ms >= 0 and last_kit_entry_ms < FAST_ENTRY_MS)

func entry_plan(phases: Array) -> void:
	if veil != null and is_instance_valid(veil):
		veil.set_plan(phases)

func entry_phase(name: String) -> void:
	if veil != null and is_instance_valid(veil):
		veil.phase_done(name)

func _entry_finished() -> void:
	if veil != null and is_instance_valid(veil):
		veil.island_ready()
	veil = null

## Starts the screen (terrain generation inside it when the terrain is not in memory yet) and then changes to the island.
## Every way into the island goes through here (menu, cell bridge, studio, load, --play).
func enter_island(from: String = "") -> void:
	var params := {"seed": int(settings.seed)}
	var have := data != null and int(terrain.get("seed", settings.seed)) == int(settings.seed)
	if not have:
		var cached := TerrainCache.load_entry(params)
		if not cached.is_empty():
			set_island(cached)
			have = true
	if have:
		goto_island(from)
		return
	entry_screens.append({"from": from if from != "" else "menu", "shown": true, "kit": false})
	_open_veil(from, params, true)

func _open_veil(from: String, params: Dictionary, need_terrain: bool) -> void:
	if veil != null and is_instance_valid(veil):
		return
	veil = EntryVeil.new()
	get_tree().root.add_child.call_deferred(veil)      # the root may be busy setting up (a scene's _ready)
	veil.begin.call_deferred(from if from != "" else "menu", params, need_terrain)
	if need_terrain:
		veil.terrain_done.connect(func(e: Dictionary) -> void:
			if e.get("error", -1) != 0:
				push_error("terrain generation failed: %s" % [e.get("error")])
				get_tree().quit(1)
				return
			set_island(e)
			_change_to_island(from))
	else:
		_change_to_island(from)

func _change_to_island(from: String) -> void:
	entry_t0 = Time.get_ticks_msec()
	entry_from = from if from != "" else "menu"
	# two frames so the screen is on the display before the build starts
	await get_tree().process_frame
	await get_tree().process_frame
	# the island scene (and the scripts it preloads) loads on a worker thread so the screen keeps animating
	const PATH := "res://game/island/island.tscn"
	if ResourceLoader.load_threaded_request(PATH) == OK:
		while ResourceLoader.load_threaded_get_status(PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var packed = ResourceLoader.load_threaded_get(PATH)
		if packed is PackedScene:
			get_tree().change_scene_to_packed(packed)
			return
	get_tree().change_scene_to_file(PATH)

func goto_island(from: String = "") -> void:
	park_island()           # the kit leaves the running island first: it decides whether this entry needs the screen
	var f := from if from != "" else ("studio" if get_tree().current_scene != null and get_tree().current_scene.scene_file_path.contains("/studio/") else "menu")
	var wanted := entry_screen_wanted()
	entry_screens.append({"from": f, "shown": wanted, "kit": peek_kit()})
	if wanted:
		_open_veil(f, {}, false)
		return
	entry_t0 = Time.get_ticks_msec()
	entry_from = f
	get_tree().change_scene_to_file("res://game/island/island.tscn")

var cell_jump_end: Dictionary = {}   # dev (`cell finish`): the cell stage opens straight on its end card with this legacy

func goto_cell() -> void:
	park_island()
	get_tree().change_scene_to_file("res://cell/cell_stage.tscn")

func goto_zoo(morphs: Array = [], course: String = "all", run: float = 1.0) -> void:
	park_island()
	zoo_args = {"morphs": morphs, "course": course} if not morphs.is_empty() else {"course": course}
	zoo_args["run"] = run
	get_tree().change_scene_to_file("res://devtools/zoo/zoo.tscn")

func goto_studio() -> void:
	park_island()
	var path := "res://studio/ui/studio.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("studio module not present")

# The starter body: ONE LINE to switch it (docs/evidence/godot/starter/README.md). Values: hatchling (today), a_grazer, b_runner, c_sprawler, d_knuckle.
const STARTER := "b_runner"
var starter_override := ""   # tests: the combat flow of play_test.gd is written for the hatchling's pico/pata/ojo loadout
const STARTER_FILES := {"hatchling": "res://game/data/hatchling.json", "a_grazer": "res://game/data/starters/a_grazer.json", "b_runner": "res://game/data/starters/b_runner.json", "c_sprawler": "res://game/data/starters/c_sprawler.json", "d_knuckle": "res://game/data/starters/d_knuckle.json"}

# Player genome source: --genome=<path> after "--", else the newest studio_dir/*.json (user://studio) that
# parses, else the bundled starter hatchling (G78/A29; Merodeador is the adult form and a wild species).
func player_genome() -> Dictionary:
	var sc_genome: Dictionary = pending_scenario.get("dict", {}).get("genome", {})
	if not sc_genome.is_empty():
		return sc_genome
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--genome="):
			var g := _read_genome(arg.substr(9))
			if not g.is_empty():
				return g
	var newest := ""
	var newest_time := 0
	var dir := DirAccess.open(studio_dir)
	if dir != null:
		for f in dir.get_files():
			if f.get_extension() == "json":
				var t := FileAccess.get_modified_time(studio_dir.path_join(f))
				if t > newest_time and not _read_genome(studio_dir.path_join(f)).is_empty():
					newest = studio_dir.path_join(f)
					newest_time = t
	if newest != "":
		return _read_genome(newest)
	return _read_genome(STARTER_FILES[starter_override if starter_override != "" else STARTER])

func _read_genome(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var v = JSON.parse_string(text)
	if typeof(v) != TYPE_DICTIONARY:
		push_warning("genome %s: not a JSON object" % path)
		return {}
	var creature_script := "res://creature/creature.gd"
	if ResourceLoader.exists(creature_script):
		var script = load(creature_script)
		if script != null and script.has_method("parse_genome"):
			var parsed = script.parse_genome(text)
			if typeof(parsed) == TYPE_DICTIONARY and parsed.get("ok", false):
				return parsed.get("genome", v)
			push_warning("genome %s rejected by the creature module" % path)
			return {}
	if v.get("schema", "") not in ["cpore.creature/4", "cpore.creature/5"] or typeof(v.get("nodes")) != TYPE_ARRAY or v.nodes.size() < 2 \
			or typeof(v.get("parts")) != TYPE_ARRAY or v.parts.size() > 256:
		push_warning("genome %s: failed the minimal checks" % path)
		return {}
	for n in v.nodes:
		if typeof(n) != TYPE_DICTIONARY or not (n.has("y") and n.has("z") and n.has("r")):
			return {}
		for k in ["y", "z", "r"]:
			if not is_finite(float(n[k])):
				return {}
	return v
