extends RefCounted
## The choice options that exist today (F10 option mode). Called once the island is ready (dev.gd); every setter is
## presentation or goes through an existing debug op, none touches core/. TODO list: docs/godot/DEVTOOLS.md.

const DBG_CLOCK := 5
const TICKS_PER_HOUR := 500.0      # a day is 12000 ticks (console `time`)
## hour of day of each light value; live = no jump
const LIGHT_HOURS := {"dawn": 6.8, "day": 12.5, "dusk": 18.2, "night": 0.0}
const CAMERA_Z := {"close": 0.0, "mid": 0.15, "far": 0.40, "tactical": 0.70}
const STARTERS := ["hatchling", "a_grazer", "b_runner", "c_sprawler", "d_knuckle"]
const Gait := preload("res://locomotion/loco_gait.gd")

static func register(reg, island, console_registry = null) -> void:
	_creature(reg, island)
	_look(reg)
	_light(reg)
	_camera(reg, island)
	_world(reg)
	_overlays(reg, console_registry)
	_movement(reg)

## Starter body: respawns the player with that genome through the existing evolve path (lineage_form, logged by the stage).
static func _creature(reg, island) -> void:
	var files: Dictionary = Game.STARTER_FILES
	reg.add_choice("starter", "creature", STARTERS, Game.STARTER, Callable(), func(v):
		if island != null and island.get("stage") != null:
			var err: String = preload("res://game/stage/lineage_session.gd").evolve_file(island, files[v])
			if err != "":
				push_warning("option starter %s: %s" % [v, err]),
		true, {"desc": "respawns the player body with that genome (a debug path: the old body stays as a cousin)."})

static func _look(reg) -> void:
	reg.add_choice("skin", "look", ["v1", "pre-v1"], "v1",
		func(): return "v1" if CreatureMaterials.realism else "pre-v1",
		func(v): CreatureMaterials.realism = (v == "v1"), false,
		{"desc": "realism pilot skin or the pre-pilot look; applies to creatures built after the change (change the starter)."})

static func _light(reg) -> void:
	reg.add_choice("light", "light", ["live", "dawn", "day", "dusk", "night"], "live", Callable(), func(v):
		var st = Game.stage
		if v != "live" and st != null:
			st.debug_now({"op": DBG_CLOCK, "a": int(LIGHT_HOURS[v] * TICKS_PER_HOUR)}),
		true, {"desc": "jumps the clock: dawn 6:48, day 12:30, dusk 18:12, night 0:00 (a logged debug op)."})

static func _camera(reg, island) -> void:
	reg.add_choice("view", "camera", ["default", "close", "mid", "far", "tactical"], "default", Callable(), func(v):
		var ch = island.get("chase") if island != null else null
		if ch == null:
			return
		if v == "default":
			ch.reset_behind()
		else:
			ch.set_zoom(CAMERA_Z[v], true),
		false, {"desc": "zoom presets of the chase camera (z 0, 0.15, 0.40, 0.70)."})

static func _world(reg) -> void:
	var cur := str(Game.settings.get("quality", "auto"))     # the default is what the player's settings file says
	reg.add_choice("quality", "world", ["auto", "low", "medium", "high"], cur,
		func(): return str(Game.settings.get("quality", "auto")),
		func(v): Game.settings["quality"] = v, false,
		{"desc": "render tier; it is read when the island is built, so it applies at the next island start."})

static func _overlays(reg, console_registry) -> void:
	reg.add_choice("path", "overlays", ["off", "on"], "off",
		func():
			var o = console_registry.services.get("path_overlay") if console_registry != null else null
			return "on" if o != null and o.enabled else "off",
		func(v):
			var o = console_registry.services.get("path_overlay") if console_registry != null else null
			if o != null:
				o.set_enabled(v == "on"), false,
		{"desc": "the planned GO route drawn on the ground."})
	reg.add_choice("notes", "overlays", ["off", "on"], "off",
		func(): return "on" if Dev.flag != null and Dev.flag.pins_overlay else "off",
		func(v): if Dev.flag != null: Dev.flag.set_pins_overlay(v == "on"), false,
		{"desc": "pins on every open note (always shown in flag mode, Shift+F8)."})
	reg.add_choice("legend", "overlays", ["off", "on"], "off",
		func(): return "on" if Dev.legend != null and Dev.legend.corner_visible else "off",
		func(v): if Dev.legend != null: Dev.legend.corner_visible = (v == "on"), false,
		{"desc": "the creature legend corner hint (key list)."})

static func _movement(reg) -> void:
	reg.add_choice("gait", "movement", ["today", "froude"], "froude",
		func(): return "froude" if Gait.froude_mode else "today",
		func(v): Gait.froude_mode = (v == "froude"), false,
		{"desc": "gait rules: froude = the gait lab's 9 rules (gait from Fr, duty curves, stride law, footfalls, bob, blends); today = the pre-port rules. Creatures already built keep their gait state, the new rules apply to every step."})
