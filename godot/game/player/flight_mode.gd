extends RefCounted
## Flight test mode (motion-flight plan 3c, slice F1): the glue between the island, the flight model (flight_test.gd), the wing
## kinematics (loco_wing.gd), the camera and the C world. Dev builds only (Dev.enabled); the model is Godot-side until F2 moves it to C.
##
## While the player flies, the island feeds the C world a WAIT order and a debug teleport to the flyer's ground point every tick
## (logged like every debug op, so the session replays and wild AI keeps seeing the player). Landing hands the creature back to C.
##
## Controls (decision D6): Space tap = one beat, hold = flap, release = glide; Ctrl = dive; S / W = pitch (slower and floatier /
## faster); A / D = roll left / right (the bank builds while held, the
## heading follows from the tilted lift, release rolls out); the mouse does the same (sideways = bank, up / down = pitch). Space on the ground takes off (a run helps; the HUD says why a body cannot).

const FlightTest := preload("res://game/player/flight_test.gd")
const LocoWing := preload("res://locomotion/loco_wing.gd")
const Strings := preload("res://ui/strings.gd")
## Owner picks (A56 starter B, A57 hatchling; lab web/gaitlab/flight.html): cruise = flap-glide (hold Space: bursts until fast, glide
## until slow); turn = wingover (double-tap A or D at speed: dive in, zoom climb, roll over the top, dive away on the reverse
## heading; Ctrl or the opposite key cuts it short); landing = flare + stall touchdown (starter B, default) or running landing
## (hatchling). Takeoff keeps today's behaviour (Space on the ground).
const LANDING_BY_BODY := {"Hatchling": "run"}     # genome name -> landing style; everything else flares
const DOUBLE_TAP_S := 0.35
const DBG_TELEPORT := 1
const HUD_FADE := 4.0

var island
var stage
var model: FlightTest = null
var wing: LocoWing = null
var enabled := true            # `fly off` or flight/enabled = 0 turns the test mode off
var keys_override: Variant = null   # tests: {flap, dive, pitch (-1..1), turn (-1 left .. 1 right)}
var last_landing: Dictionary = {}
var landings := 0
var teleports_rejected := 0
var teleports_sent := 0
var message := ""
var message_t := 0.0
var cruise_style := "flapglide"     # "flapglide" (A56 default) or "continuous" (hold Space = flap all the time)
var landing_override := ""          # "" = by body (LANDING_BY_BODY), or "flare" / "run" (console `fly landing`, tests, clips)
var _tap_dir := 0                   # double-tap detector of A / D
var _tap_t := -1.0
var _turn_prev := 0.0
var _clock := 0.0
var _space_edge := false
var _mouse_dx := 0.0           # pixels moved since the last tick (flying, no button held)
var _mouse_dy := 0.0
var _mouse_turn := 0.0         # smoothed mouse commands, -1..1
var _mouse_pitch := 0.0
const MOUSE_FULL := 700.0      # px/s of sideways movement that commands the full roll rate
var _hud: Label = null
var _canvas: CanvasLayer = null
var _spec_key := ""
var _wing_active := false
var _wing_pose_pending: Dictionary = {}
var _release_pending := false
var _lift_mul := 1.0
var _power_mul := 1.0
var _cd0_mul := 1.0

func setup(isl, stg) -> void:
	island = isl
	stage = stg
	stage.ticked.connect(_on_tick)
	stage.debug_applied.connect(_on_debug)
	_canvas = CanvasLayer.new()
	_canvas.layer = 30
	_hud = Label.new()
	_hud.position = Vector2(18, 18)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud.add_theme_constant_override("outline_size", 4)
	_canvas.add_child(_hud)
	island.add_child(_canvas)


func available() -> bool:
	return enabled and Engine.get_main_loop() != null and _dev_on()

## A31: `lift_mul` is a dev-only knob (D4, the global fun gain). Outside dev builds the gain is always 1: physics decides who flies.
## Dev builds are `Dev.enabled` (debug build by default, `--dev` / `--no-dev` override; devtools/dev.gd compute_enabled).
func lift_gain() -> float:
	return _lift_mul if _dev_on() else 1.0

static func _dev_on() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var dev = tree.root.get_node_or_null("Dev")
	return dev != null and bool(dev.enabled)


func _driver():
	return island.hosts[0].driver if island.hosts.has(0) else null


## (Re)builds the model from the player's creature. Cached by the creature instance and its wing meta.
func _ensure_model() -> bool:
	var host = island.hosts.get(0)
	if host == null or not host.uses_module:
		return false
	var drv = host.driver
	if drv == null or drv.controller == null or not ("morph" in drv.controller):
		return false
	var body = host.body
	var key := str(body.get_instance_id())
	if key == _spec_key and model != null:
		return model.valid()
	_spec_key = key
	var infos: Array = []
	for e in body.parts:
		var n: Node = e.node
		if n != null and n.has_meta("wing_info"):
			infos.append(n.get_meta("wing_info"))
	var morph = drv.controller.morph
	var spec := FlightTest.make_spec(float(morph.mass), infos, float(morph.body_length), float(morph.com.y)) if not infos.is_empty() else {}
	var keep := model
	model = FlightTest.new(spec)
	if keep != null:
		model.lift_mul = keep.lift_mul
		model.power_mul = keep.power_mul
		model.cd0_mul = keep.cd0_mul
	model.lift_mul = lift_gain()
	model.power_mul = _power_mul
	model.cd0_mul = _cd0_mul
	model.cruise_style = cruise_style
	model.landing_style = landing_style()
	wing = LocoWing.new(float(morph.mass), infos[0] if not infos.is_empty() else {})
	return model.valid()


## The landing style of the player's body (A56 flare for starter B, A57 running landing for the hatchling).
func landing_style() -> String:
	if landing_override != "":
		return landing_override
	return str(LANDING_BY_BODY.get(str(Game.player_genome().get("name", "")), "flare"))

## Wingbeat rate now (Hz) of the player's wings, by the scaling option (LocoWing.scaling).
func beat_hz() -> float:
	return wing.hz if wing != null else 0.0

## F10 option "wingbeat": the beat rate follows the new law at once.
func rescale_wingbeat() -> void:
	if wing != null and model != null and model.valid():
		wing.set_mass(float(model.spec.mass))

func has_wings() -> bool:
	return _ensure_model()

func active() -> bool:
	return model != null and model.active()


# ---- input ------------------------------------------------------------------------------------------------------------------
## Called from the island's _unhandled_input: returns true when the event was a flight key.
func handle_input(event: InputEvent) -> bool:
	if not available() or not has_wings():
		return false
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_space_edge = true
		return true
	if event is InputEventMouseMotion and model != null and model.airborne() and event.button_mask == 0:
		_mouse_dx += event.relative.x
		_mouse_dy += event.relative.y
	return false

func press_space() -> void:
	_space_edge = true

func _keys() -> Dictionary:
	if keys_override != null:
		return keys_override
	var turn := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	return {"flap": Input.is_physical_key_pressed(KEY_SPACE), "dive": Input.is_key_pressed(KEY_CTRL),
		"pitch": float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)), "turn": turn}


# ---- per frame --------------------------------------------------------------------------------------------------------------
func tick(dt: float) -> void:
	message_t = maxf(0.0, message_t - dt)
	if not available() or not has_wings():
		if _hud != null:
			_hud.visible = false
		_space_edge = false
		return
	_clock += dt
	var k := _keys()
	var base: Dictionary = stage.sample(0)
	model.cruise_style = cruise_style
	model.landing_style = landing_style()
	if model.mode == "ground":
		if _space_edge and stage.cur.active < 0 and not Game.movement_blocked():
			var yaw := float(base.yaw)
			var r := model.takeoff(base.pos, base.vel, Vector2(sin(yaw), cos(yaw)))
			if r.ok:
				_begin_flight(" (burst)" if r.burst else "")
			else:
				_say(r.reason)
	else:
		if stage.cur.active >= 0:
			_abort("a fight started: flight ended")
		else:
			if _space_edge:
				model.press_flap()
			var turn := float(k.get("turn", 0.0))
			_wingover_trigger(turn, int(k.get("wingover", 0)))
			var pitch := float(k.get("pitch", 0.0))
			if keys_override == null and dt > 0.0:
				# the mouse commands like the keys: sideways movement is the roll rate (right = D), up / down is the pitch (up = W)
				var gain := 1.0 - exp(-dt / 0.12)
				_mouse_turn = lerpf(_mouse_turn, clampf(_mouse_dx / dt / MOUSE_FULL, -1.0, 1.0), gain)
				_mouse_pitch = lerpf(_mouse_pitch, clampf(_mouse_dy / dt / MOUSE_FULL, -1.0, 1.0), gain)
				turn = clampf(turn + _mouse_turn, -1.0, 1.0)
				pitch = clampf(pitch + _mouse_pitch, -1.0, 1.0)
			_mouse_dx = 0.0
			_mouse_dy = 0.0
			var ev := model.step(dt, {"flap": bool(k.get("flap", false)), "dive": bool(k.get("dive", false)), "pitch": pitch, "roll": -turn}, Callable(Game, "visual_ground"))
			if ev.landed:
				_touchdown(ev)
			if ev.ended:
				_end_flight()
	_space_edge = false
	_update_wing(dt, k)
	_update_hud()


## Double-tap A / D (or `wingover` in the test keys) starts the wingover over that wing.
func _wingover_trigger(turn: float, forced: int) -> void:
	var dir := forced
	var key_dir := 0 if absf(turn) < 0.5 else (1 if turn > 0.0 else -1)
	var prev_dir := 0 if absf(_turn_prev) < 0.5 else (1 if _turn_prev > 0.0 else -1)
	if dir == 0 and key_dir != 0 and prev_dir == 0:
		if key_dir == _tap_dir and _clock - _tap_t <= DOUBLE_TAP_S:
			dir = key_dir
			_tap_dir = 0
		else:
			_tap_dir = key_dir
			_tap_t = _clock
	_turn_prev = turn
	if dir == 0 or model.wo_phase != "":
		return
	var r := model.start_wingover(dir, Callable(Game, "visual_ground"))
	if r.ok:
		_say("wingover to the %s" % ("right" if dir > 0 else "left"))
		print("flight: wingover to the %s" % ("right" if dir > 0 else "left"))
	else:
		_say(r.reason)


func _begin_flight(note: String) -> void:
	island.player_input.suspended = true
	island.player_input.clear_destination()
	wing.deploy = maxf(wing.deploy, 0.0)
	model.fg_on = true
	model.wo_phase = ""
	_say("take off%s: stall %.1f m/s, loading %.0f N/m2" % [note, model.stall_speed(), model.wing_loading()])
	print("flight: take off%s" % note)
	_wing_active = true
	_send_teleport()


func _touchdown(ev: Dictionary) -> void:
	landings += 1
	last_landing = {"vy": ev.impact_vy, "h_eq": ev.h_eq, "damage": ev.damage, "speed": ev.speed, "tick": int(stage.cur.tick)}
	var line := "%s landing: " % model.landing_style + "landed at %.1f m/s, sink %.1f m/s (equivalent drop %.1f m): %s" % [ev.speed, -ev.impact_vy, ev.h_eq, "no damage" if ev.damage <= 0.0 else "%.0f damage" % ev.damage]
	_say(line)
	print("flight: " + line)


func _end_flight() -> void:
	var rc := _send_teleport(true)
	if rc != 0:
		# the touchdown spot is inside a rock or tree, or in deep water: the nearest spot the world accepts (rings of 1.5 m up to 9 m)
		var base := Vector2(model.pos.x, model.pos.z)
		var found := false
		for ring in range(1, 7):
			for k in 8:
				var a := TAU * float(k) / 8.0
				var q := base + Vector2(cos(a), sin(a)) * 1.5 * float(ring)
				if stage.debug_now({"op": DBG_TELEPORT, "id": 0, "x": q.x, "z": q.y}) == 0:
					model.pos.x = q.x
					model.pos.z = q.y
					found = true
					break
			if found:
				break
		print("flight: the landing spot was refused by the world (%s); %s" % [CporeWorld.debug_error(rc), "moved to the nearest accepted spot" if found else "back to the last accepted spot"])
	island.player_input.suspended = false
	var drv = _driver()
	if drv != null:
		drv.rebase()
	model.mode = "ground"


func _abort(why: String) -> void:
	model.mode = "ground"
	model.vel = Vector3.ZERO
	island.player_input.suspended = false
	var drv = _driver()
	if drv != null:
		drv.rebase()
	_say(why)


func _update_wing(dt: float, k: Dictionary) -> void:
	if wing == null:
		return
	var m := "ground"
	if model.mode in ["glide", "flap", "dive", "flare"]:
		m = model.mode
	wing.step(dt, {"mode": m, "power": 1.0, "pitch": -float(k.get("pitch", 0.0)) if m != "ground" else 0.0, "bank": clampf(model.bank_t / FlightTest.BANK_MAX_T, -1.0, 1.0) if m != "ground" else 0.0})
	if m != "ground" or wing.deploy > 0.01 or wing.amp > 0.01:
		_wing_pose_pending = wing.channels()      # written in post_update, after the action layer's own hinge values
		_wing_active = true
	elif _wing_active:
		_release_pending = true
		_wing_active = false


# ---- the C world ----------------------------------------------------------------------------------------------------------
func _on_tick(_state: Dictionary) -> void:
	if model != null and model.mode in ["glide", "flap", "dive", "flare", "skid"]:
		_send_teleport()

func _send_teleport(now := false) -> int:
	if model == null:
		return 0
	var op := {"op": DBG_TELEPORT, "id": 0, "x": model.pos.x, "z": model.pos.z}
	teleports_sent += 1
	if now:
		return stage.debug_now(op)
	stage.queue_debug(op)
	return 0

func _on_debug(op: Dictionary, rc: int) -> void:
	if int(op.get("op", -1)) == DBG_TELEPORT and int(op.get("id", -1)) == 0 and rc != 0 and model != null and model.active():
		teleports_rejected += 1


## After the actors were updated this frame: the wings are written over the action layer's hinge values.
func post_update(_dt: float) -> void:
	if model == null or wing == null or not available():
		return
	if not _wing_pose_pending.is_empty():
		LocoWing.apply(island.hosts[0].body, _wing_pose_pending)
		_wing_pose_pending = {}
	elif _release_pending:
		LocoWing.release(island.hosts[0].body)
		_release_pending = false


# ---- what the island and the camera read ---------------------------------------------------------------------------------
## The player's sample while flying (replaces stage.sample(0)); `base` otherwise.
func sample(base: Dictionary) -> Dictionary:
	if model == null or not model.active():
		return base
	var drv = _driver()
	var com_local: Vector3 = drv.controller.morph.com if drv != null and drv.controller != null else Vector3(0, 0.5, 0)
	var yaw := atan2(model.yaw_dir.x, model.yaw_dir.y)
	if model.mode == "skid":
		var origin := model.pos - Vector3(0.0, float(model.spec.com_h), 0.0)
		var hv := Vector3(model.vel.x, 0.0, model.vel.z)
		return {"pos": origin, "yaw": yaw, "speed": hv.length(), "speed_c": hv.length(), "vel": hv}
	var r := model.orientation()
	var bob := Vector3(0.0, wing.bob() if wing != null else 0.0, 0.0)      # visual only: the body rises on the downstroke
	var origin2 := model.pos + bob - r * com_local
	return {"pos": origin2, "yaw": yaw, "speed": model.vel.length(), "speed_c": model.vel.length(), "vel": model.vel,
		"flight": {"basis": r, "com": model.pos + bob, "mode": model.mode, "bank": model.bank_t, "head_roll": model.head_roll(),
		"legs_tuck": model.legs_tuck, "legs_fwd": model.legs_fwd}}

## Altitude of the flyer above the ground below it (0 on the ground), for the chase camera.
func altitude() -> float:
	if model == null or not model.airborne():
		return 0.0
	return maxf(0.0, model.altitude(Callable(Game, "visual_ground")))


# ---- HUD, messages -------------------------------------------------------------------------------------------------------
func _say(text: String) -> void:
	message = text
	message_t = HUD_FADE

func _update_hud() -> void:
	if _hud == null:
		return
	_hud.visible = true
	var lines := PackedStringArray()
	if model.active():
		var ground: Callable = Callable(Game, "visual_ground")
		lines.append("%s  %s   %s" % [Strings.t("fl_flight"), model.mode, Strings.t("fl_speed", ["%.1f" % model.vel.length(), "%.1f" % model.altitude(ground), "%+.1f" % model.vel.y, int(model.stamina * 100.0)])])
		lines.append("L/D %.1f   %s %.1f m/s%s   %s" % [model.glide_ratio(), Strings.t("stall"), model.stall_speed(), "  " + Strings.t("fl_stalling") if model.stalled else ("  " + Strings.t("fl_overbank") if model.overbank else ""), Strings.t("fl_controls")])
	else:
		var r := model.report()
		lines.append("%s  %s.  %s" % [Strings.t("fl_test"), str(r.capability).to_upper(), Strings.t("fl_report", ["%.0f" % r.wing_loading, "%.1f" % r.stall, "%.1f" % r.ld, "%.0f" % r.power, "%.0f" % (r.p_req if r.p_req < INF else -1.0)])])
	if message_t > 0.0 and message != "":
		lines.append(message)
	_hud.text = "\n".join(lines)


# ---- tuning and console ---------------------------------------------------------------------------------------------------
func bind_tuning(t) -> void:
	t.add("flight/lift_mul", "flight", 0.1, 100.0, 0.1, 1.0, func(): return _lift_mul, func(v): _set_mul("lift", v))
	t.add("flight/power_mul", "flight", 0.1, 20.0, 0.1, 1.0, func(): return _power_mul, func(v): _set_mul("power", v))
	t.add("flight/cd0_mul", "flight", 0.2, 3.0, 0.05, 1.0, func(): return _cd0_mul, func(v): _set_mul("cd0", v))
	t.add("flight/enabled", "flight", 0.0, 1.0, 1.0, 1.0, func(): return 1.0 if enabled else 0.0, func(v): enabled = v >= 0.5)

func _set_mul(which: String, v: float) -> void:
	match which:
		"lift": _lift_mul = v
		"power": _power_mul = v
		"cd0": _cd0_mul = v
	if model != null:
		model.lift_mul = lift_gain()
		model.power_mul = _power_mul
		model.cd0_mul = _cd0_mul

func register_console(r) -> void:
	r.register("fly", "[on|off|report|land|wingover [l|r]|cruise flapglide|continuous|landing flare|run|auto]", "flight test: toggle it, print the wing numbers, or end a flight", func(a):
		var sub: String = a[0] if a.size() > 0 else ""
		if sub == "off":
			if active():
				_abort("flight test off")
			enabled = false
			return r.ok("flight test off")
		if sub == "on" or sub == "":
			enabled = true
			if not has_wings():
				return r.ok("flight test on, but the player has no wings (add wing_glider, wing_vane, wing_insect or wing_flap in the creator)")
			sub = "report"
		if sub == "land" and active():
			_abort("flight ended")
			return r.ok("landed")
		if sub == "wingover" and active():
			var dir := -1 if a.size() > 1 and str(a[1]) == "l" else 1
			var wr := model.start_wingover(dir, Callable(Game, "visual_ground"))
			return r.ok("wingover started") if wr.ok else r.fail(wr.reason)
		if sub == "cruise" and a.size() > 1 and a[1] in ["flapglide", "continuous"]:
			cruise_style = a[1]
			return r.ok("cruise style: " + cruise_style)
		if sub == "landing" and a.size() > 1 and a[1] in ["flare", "run", "auto"]:
			landing_override = "" if a[1] == "auto" else a[1]
			return r.ok("landing style: " + landing_style())
		if sub == "report":
			if not has_wings():
				return r.fail("the player has no wings")
			var rep := model.report()
			return r.ok("mass %.1f kg, wings %.2f m2 (span %.2f m, AR %.1f), loading %.0f N/m2, stall %.1f m/s, best L/D %.1f, power %.0f W (needs %.0f W), beat %.1f Hz (%s), cruise %s, landing %s: %s" %
				[float(model.spec.mass), rep.area, rep.span, rep.ar, rep.wing_loading, rep.stall, rep.ld, rep.power, rep.p_req if rep.p_req < INF else -1.0, model.beat_hz(), LocoWing.scaling, cruise_style, landing_style(), str(rep.capability).to_upper()])
		return r.fail("usage: fly [on|off|report|land]"),
		{"changes_sim": true})
