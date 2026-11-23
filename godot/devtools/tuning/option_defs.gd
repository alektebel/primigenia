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
	_speed(reg)

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
	reg.add_choice("style", "movement", ["a42 port", "longer-lower", "froude default"], "a42 port",
		func(): return {"a42": "a42 port", "longer": "longer-lower", "froude": "froude default"}[Gait.style_mode],
		func(v): Gait.style_mode = {"a42 port": "a42", "longer-lower": "longer", "froude default": "froude"}[v], false,
		{"desc": "move styles (A42/A43): diagonal sprawl walk, slinky stalk (starter B), canter, rotary gallop; bipeds bouncier; longer-lower lengthens and lowers; froude default = the Froude gaits alone."})
	reg.add_choice("gait", "movement", ["today", "froude"], "froude",
		func(): return "froude" if Gait.froude_mode else "today",
		func(v): Gait.froude_mode = (v == "froude"), false,
		{"desc": "gait rules: froude = the gait lab's 9 rules (gait from Fr, duty curves, stride law, footfalls, bob, blends); today = the pre-port rules. Creatures already built keep their gait state, the new rules apply to every step."})
	reg.add_choice("gallop look", "movement", ["bold (default for now)", "natural", "subtle"], "bold (default for now)",
		func(): return {"bold": "bold (default for now)", "natural": "natural", "subtle": "subtle"}[Gait.gallop_look],
		func(v): Gait.gallop_look = str(v).split(" ")[0], false,
		{"desc": "quadruped gallop and canter: bold = 34% of the cycle in the air, two clear leg pairs, body rock x2, spine gather/extend, bigger bob, head counter-motion (canter milder); natural = the A42 table; subtle = calmer. Applies when the style next changes."})

## Speed knobs (owner 2026-11-22, "the creature moves too slow"): C motion parameters walk_fr (walk Froude number, default .24) and
## sprint_k (run Froude number, default 2.2 since A54; it was 1.5); both go through the logged PARAM debug op, so a session with them replays bit for bit.
## v = sqrt(Fr g h) with h = 0.56 * body radius (core/src/stage_world.c gait_speed). The choice description shows the m/s of the
## current player body.
const DBG_PARAM := 7
const HIP_PER_RADIUS := 0.56
const WALK_CHOICES := {"physics 0.24 (B ~1.1 m/s)": 0.24, "brisk 0.45 (B ~1.4 m/s)": 0.45, "fast 0.8 (B ~1.9 m/s)": 0.8, "2 m/s for B (~0.86)": 0.86}
const RUN_CHOICES := {"1.5": 1.5, "2.2 (default)": 2.2, "3.0": 3.0}

## Speed in m/s of a body of radius r (m) at Froude number fr.
static func speed_ms(fr: float, radius: float) -> float:
	return sqrt(fr * 9.81 * HIP_PER_RADIUS * radius)

static func _player_radius() -> float:
	var st = Game.stage
	if st == null or st.cur == null or st.cur.entities.is_empty():
		return 0.85
	return maxf(0.6, float(st.cur.entities[0].get("radius_cm", 60)) * 0.01)

static func _param_index(name: String) -> int:
	for p in CporeWorld.params():
		if p.name == name:
			return int(p.index)
	return -1

static func _set_param(name: String, v: float) -> void:
	var st = Game.stage
	var idx := _param_index(name)
	if st != null and idx >= 0:
		st.debug_now({"op": DBG_PARAM, "a": idx, "v": v})

static func _speed_desc(walk_fr: float, run_fr: float) -> String:
	var r := _player_radius()
	return "your creature (r %.2f m): walks %.1f m/s, runs %.1f m/s. " % [r, speed_ms(walk_fr, r), speed_ms(run_fr, r)]

static func _speed(reg) -> void:
	var cur_walk := [0.24]
	var cur_run := [2.2]
	reg.add_choice("walk speed", "movement", WALK_CHOICES.keys(), WALK_CHOICES.keys()[0], Callable(), func(v):
		cur_walk[0] = float(WALK_CHOICES[v])
		_set_param("walk_fr", cur_walk[0])
		reg.choices["walk speed"].desc = _speed_desc(cur_walk[0], cur_run[0]) + "walk Froude number (motion parameter walk_fr); player and wild walkers; the legs follow the speed.",
		true, {"desc": _speed_desc(0.24, 2.2) + "walk Froude number (motion parameter walk_fr); player and wild walkers; the legs follow the speed."})
	reg.add_choice("run speed", "movement", RUN_CHOICES.keys(), "2.2 (default)", Callable(), func(v):
		cur_run[0] = float(RUN_CHOICES[v])
		_set_param("sprint_k", cur_run[0])
		reg.choices["run speed"].desc = _speed_desc(cur_walk[0], cur_run[0]) + "run Froude number (motion parameter sprint_k), Shift or Ctrl.",
		true, {"desc": _speed_desc(0.24, 2.2) + "run Froude number (motion parameter sprint_k), Shift or Ctrl."})
