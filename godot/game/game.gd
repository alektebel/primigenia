extends Node
# Autoload "Game": island data, settings, the active StageWorld, scene switching.
# Public surface is documented in docs/godot/M0.md.

signal island_ready
signal world_ticked(state: Dictionary)
signal combat_events(events: Array)
signal creature_clicked(id: int, world_pos: Vector3)

const TerrainData := preload("res://game/island/terrain_data.gd")
const SETTINGS_PATH := "user://settings.cfg"

# controls/strafe_latch: WASD is relative to the camera as it was when the keys changed (a held S or A runs
# straight); off = the live camera (a held S circles). controls/tank: Spore-style steering, A/D turn the
# creature, W forward, S reverse (overrides the latch).
var settings: Dictionary = {"seed": 1, "grass": 252000, "flora_density": -1.0, "flora_lod_scale": 1.0, "quality": "auto", "sun_shadows": false, "wild": true,
	"controls/strafe_latch": true, "controls/tank": false, "camera/kick": false,
	"ui_scale": 1.0, "language": "", "names_always": false, "numbers": false, "strong_outlines": false, "reduced_motion": false,
	"onboarding": 0, "minimap": true,
	"renderer": "auto"}   # auto | forward_plus | compatibility, read at launch by RenderChoice (relaunches into Forward+ on discrete GPUs)
var terrain: Dictionary = {}
var data = null          # TerrainData
var stage = null         # StageWorld while the island runs
var camera: Camera3D = null
var modal_open := false  # set by UI modules (radial, pause)
var radial_open := false # set with modal_open by StageUI, for the key legend context
var paused_ui := false
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
	if modal_open or console_open:
		return true
	var vp := get_viewport()
	return vp != null and vp.gui_get_focus_owner() != null

# Which key context is active (first match wins), for the key legend (devtools/legend.gd).
func legend_context() -> StringName:
	if console_open:
		return &"console"
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

func goto_menu() -> void:
	get_tree().change_scene_to_file("res://game/menu/main_menu.tscn")

func goto_island() -> void:
	get_tree().change_scene_to_file("res://game/island/island.tscn")

func goto_zoo(morphs: Array = [], course: String = "all") -> void:
	zoo_args = {"morphs": morphs, "course": course} if not morphs.is_empty() else {"course": course}
	get_tree().change_scene_to_file("res://devtools/zoo/zoo.tscn")

func goto_studio() -> void:
	var path := "res://studio/ui/studio.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("studio module not present")

# Player genome source: --genome=<path> after "--", else the newest studio_dir/*.json (user://studio) that
# parses, else the bundled Merodeador.
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
	return _read_genome("res://game/data/merodeador.json")

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
