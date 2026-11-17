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
var settings: Dictionary = {"seed": 1, "grass": 252000, "quality": "auto", "sun_shadows": false, "wild": true,
	"controls/strafe_latch": true, "controls/tank": false, "camera/kick": false}
var terrain: Dictionary = {}
var data = null          # TerrainData
var stage = null         # StageWorld while the island runs
var camera: Camera3D = null
var modal_open := false  # set by UI modules (radial, pause)
var studio_dir := "user://studio"   # where the studio saves and Play looks for the newest creature (tests point it elsewhere)

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		if cfg.has_section_key("game", key):
			settings[key] = cfg.get_value("game", key)

func save_settings() -> void:
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

func movement_blocked() -> bool:
	if modal_open:
		return true
	var vp := get_viewport()
	return vp != null and vp.gui_get_focus_owner() != null

func goto_menu() -> void:
	get_tree().change_scene_to_file("res://game/menu/main_menu.tscn")

func goto_island() -> void:
	get_tree().change_scene_to_file("res://game/island/island.tscn")

func goto_studio() -> void:
	var path := "res://studio/ui/studio.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("studio module not present")

# Player genome source: --genome=<path> after "--", else the newest studio_dir/*.json (user://studio) that
# parses, else the bundled Merodeador.
func player_genome() -> Dictionary:
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
	if v.get("schema", "") != "cpore.creature/4" or typeof(v.get("nodes")) != TYPE_ARRAY or v.nodes.size() < 2 \
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
