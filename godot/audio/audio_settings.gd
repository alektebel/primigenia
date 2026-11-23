extends RefCounted
## Volumes and mute persisted in the user settings file (ConfigFile, section [audio]).

const DEFAULTS := {"master": 0.7, "music": 0.4, "sfx": 0.75, "ambience": 0.5, "mute": false}
const BUSES: Array[String] = ["master", "music", "sfx", "ambience"]

const TestIsolation := preload("res://devtools/test_isolation.gd")
var path := TestIsolation.user("settings.cfg")
var values: Dictionary = DEFAULTS.duplicate()

func _init(p: String = "") -> void:
	path = p if p != "" else TestIsolation.user("settings.cfg")
	load_file()

func load_file() -> void:
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in DEFAULTS:
		if cf.has_section_key("audio", k):
			set_value(k, cf.get_value("audio", k), false)

func set_value(key: String, v, save_now: bool = true) -> void:
	if key == "mute":
		values[key] = bool(v)
	elif key in BUSES:
		values[key] = clampf(float(v), 0.0, 1.0)
	else:
		return
	if save_now:
		save_file()

func save_file() -> int:
	# Keep other sections of the shared settings file untouched.
	var cf := ConfigFile.new()
	cf.load(path)
	for k in values:
		cf.set_value("audio", k, values[k])
	return cf.save(path)
