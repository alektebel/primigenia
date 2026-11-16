extends Node
# Autoload "Game": island data, settings, the active StageWorld, scene switching.
# Public surface is documented in docs/godot/M0.md.

signal island_ready
signal world_ticked(state: Dictionary)
signal combat_events(events: Array)
signal creature_clicked(id: int, world_pos: Vector3)

const SETTINGS_PATH := "user://settings.cfg"

var settings: Dictionary = {"seed": 1, "grass": 252000, "quality": "high", "wild": true}
var terrain: Dictionary = {}
var data = null          # TerrainData
var stage = null         # StageWorld while the island runs
var camera: Camera3D = null
var modal_open := false  # set by UI modules (radial, pause)

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

func ground(x: float, z: float) -> float:
	return data.ground(x, z) if data != null else 0.0

func movement_blocked() -> bool:
	if modal_open:
		return true
	var vp := get_viewport()
	return vp != null and vp.gui_get_focus_owner() != null

func goto_island() -> void:
	get_tree().change_scene_to_file("res://game/island/island.tscn")

func goto_studio() -> void:
	var path := "res://studio/ui/studio.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("studio module not present")
