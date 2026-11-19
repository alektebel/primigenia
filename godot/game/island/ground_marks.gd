extends Node3D
# The ground marks of the diegetic UI (docs/godot/UI-DIEGETIC.md sections 7.1, 7.2, 8): the white circle where you click
# to walk, the soft one while you hold to follow, the ring under the selected creature and the rest. One GroundMark mesh
# per ring; this node owns them and their animation. Created by the island, driven by island.gd (clicks) and
# stage_ui.gd (selection, trust, beat, health, wind-up).

const GroundMark := preload("res://game/island/ground_mark.gd")
const Style := preload("res://ui/style.gd")
const Palette := preload("res://ui/palette.gd")

const STYLE_SMOOTH := 0
const STYLE_TEETH := 1
const STYLE_DOTS := 2
const STYLE_DOUBLE := 3
const STYLE_CUT := 4
const MIN_MOVE_RADIUS := 0.35
const ARRIVE_RADIUS := 1.4

var island
var player_radius := 0.6                 # the player's footprint radius (m), set by the island
var move_mark                            # the solid move marker (7.1)
var follow_mark                          # the soft hold-to-follow marker
var _move_pos := Vector3.ZERO
var _follow_goal := Vector3.ZERO
var _follow_pos := Vector3.ZERO
var _follow_on := false
var _blocked_mark
var _blocked_hold := 0.0
# the selection ring (7.2)
var sel_mark
var sel_id := -1
var sel_radius_m := 0.6              # the ring's radius (m): max(1.25 x the body footprint radius, 0.6)
var sel_mode: StringName = &""
var value_target := 1.0               # the arc length the ring is growing to (trust, health, observe progress)
var _value := 1.0
var _value_dir := 1.0

func _ready() -> void:
	move_mark = _new_mark(0.0)
	move_mark.breathe = true
	follow_mark = _new_mark(0.0)
	follow_mark.base_alpha = 0.6
	_blocked_mark = _new_mark(0.0)
	sel_mark = _new_mark(1.0)

func _new_mark(base_alpha := 1.0) -> Node:
	var m := GroundMark.new()
	m.base_alpha = base_alpha
	add_child(m)
	return m

func _with_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, GroundMark.visual_ground(p.x, p.z), p.z)

func move_radius() -> float:
	return maxf(0.45 * player_radius, MIN_MOVE_RADIUS)

# --- 7.1 the move marker -----------------------------------------------------------------------------------------

## A click on walkable ground: the solid bone ring contracts from 1.6x to 1x while it fades in, then breathes.
func move_marker(pos: Vector3) -> void:
	_hide_follow(0.12)
	_blocked_mark.fade_out(0.12)
	var r := move_radius()
	_move_pos = _with_ground(pos)
	var m = move_mark
	m.radius_m = r
	m.width_px = 2.6
	m.thick_px = 0.0
	m.base_alpha = 0.85
	m.place(_move_pos, r * 2.6)
	m.set_style(STYLE_SMOOTH, Palette.BONE)
	m.set_param("wash", 0.10)
	m.set_param("dot_r", 0.14 * r / m.extent)
	m.set_param("cross_r", 0.0)
	m.set_param("lit", -1.0)
	m.set_param("frac", 1.0)
	m.alpha = 0.0
	m.fade_in(Style.IN)
	m.scale_to(1.0, Style.IN, 1.0 if Style.reduced_motion() else 1.6)

## Hold to follow: four short arcs, softer, gliding to the pointer's ground point; no dot, no contraction.
func follow_marker(pos: Vector3) -> void:
	if move_mark.is_shown():
		move_mark.fade_out(0.12)
	_blocked_mark.fade_out(0.12)
	_follow_goal = _with_ground(pos)
	var r := move_radius()
	var m = follow_mark
	if not _follow_on:
		_follow_pos = _follow_goal
		m.radius_m = r
		m.width_px = 2.4
		m.thick_px = 0.0
		m.base_alpha = 0.6
		m.place(_follow_pos, r * 2.6)
		m.set_style(STYLE_CUT, Palette.BONE, 4)
		m.set_param("gap_deg", 60.0)
		m.set_param("wash", 0.0)
		m.set_param("dot_r", 0.0)
		m.set_param("cross_r", 0.0)
		m.set_param("lit", -1.0)
		m.scale_mul = 1.0
		m._scale_t = 1.0
		m.fade_in(Style.IN)
	_follow_on = true

func follow_active() -> bool:
	return _follow_on

## The pointer was released after a hold: the soft marker becomes the solid one (with the IN contraction).
func follow_release() -> void:
	if _follow_on:
		move_marker(_follow_goal)

func _hide_follow(secs: float) -> void:
	if _follow_on or follow_mark.is_shown():
		follow_mark.fade_out(secs)
	_follow_on = false

## Cannot go there (deep water, a cliff): the ring drawn cut in four with a small cross, shaking twice, gone in 0.5 s.
func move_blocked(pos: Vector3) -> void:
	_hide_follow(0.12)
	move_mark.fade_out(0.12)
	var r := move_radius()
	var m = _blocked_mark
	m.radius_m = r
	m.width_px = 2.6
	m.base_alpha = 0.9
	m.place(_with_ground(pos), r * 2.6)
	m.set_style(STYLE_CUT, Palette.BONE, 4)
	m.set_param("gap_deg", 40.0)
	m.set_param("wash", 0.0)
	m.set_param("dot_r", 0.0)
	m.set_param("cross_r", 0.3 * r / m.extent)
	m.set_param("lit", -1.0)
	m.scale_mul = 1.0
	m._scale_t = 1.0
	m.alpha = 0.9
	m.fade_to(0.9, 0.04)
	m.shake(0.1)
	_blocked_hold = 0.25

## The destination was reached (arrived: the ring expands to 1.3x and fades) or cancelled (it fades quickly).
func clear_move(arrived: bool) -> void:
	_hide_follow(Style.OUT if arrived else 0.12)
	if not move_mark.is_shown():
		return
	if arrived:
		move_mark.scale_to(1.3, Style.OUT, -1.0, &"out")
		move_mark.fade_out(Style.OUT)
	else:
		move_mark.fade_out(0.12)

func move_visible() -> bool:
	return move_mark.is_shown()

func follow_visible() -> bool:
	return follow_mark.is_shown()

func destination() -> Vector3:
	return _move_pos

func _process(dt: float) -> void:
	_process_selection(dt)
	_process_fx(dt)
	if _blocked_hold > 0.0:
		_blocked_hold -= dt
		if _blocked_hold <= 0.0:
			_blocked_mark.fade_out(0.5)
	if _follow_on:
		var k := 1.0 - exp(-dt / 0.08)
		_follow_pos = _follow_pos.lerp(_follow_goal, k)
		_follow_pos.y = GroundMark.visual_ground(_follow_pos.x, _follow_pos.z)
		follow_mark.place(_follow_pos)

# --- 7.2 the selection ring --------------------------------------------------------------------------------------

## The entity radius is max(0.6, radius_cm / 100) as in Pointer.pick_entity; the ring is 1.25 x that (at least 0.6 m).
func select(id: int, body_radius_m: float) -> void:
	sel_id = id
	sel_radius_m = maxf(1.25 * body_radius_m, 0.6)
	var m = sel_mark
	m.radius_m = sel_radius_m
	m.width_px = 2.4
	m.base_alpha = 1.0
	m.scale_mul = 1.0
	m._scale_t = 1.0
	m.place(_entity_pos(id), sel_radius_m * 2.0)
	_apply_mode_style(&"", true)
	m.alpha = 0.0
	m.fade_in(Style.IN)
	m.scale_to(1.0, Style.IN, 1.0 if Style.reduced_motion() else 1.08)

func deselect() -> void:
	sel_id = -1
	sel_mark.fade_out(Style.OUT)

func is_selected() -> bool:
	return sel_id >= 0 and sel_mark.is_shown()

## The ring takes the style of the mode (table of 7.2); `&""` is "none yet": bone, smooth, a full circle.
func set_mode_style(mode: StringName) -> void:
	_apply_mode_style(mode, false)

func _apply_mode_style(mode: StringName, instant: bool) -> void:
	sel_mode = mode
	var m = sel_mark
	m.set_param("wash", 0.0)
	m.set_param("dot_r", 0.0)
	m.set_param("lit", -1.0)
	m.set_param("track", Style.TRACK_ALPHA)
	m.set_param("dir", 1.0)
	_value_dir = 1.0
	match mode:
		&"befriend":
			m.set_style(STYLE_SMOOTH, Palette.LICHEN)
			value_target = 0.0
		&"attack":
			m.set_style(STYLE_TEETH, Palette.EMBER_HOT, 16)
			m.set_param("dir", -1.0)
			_value_dir = -1.0
			value_target = 1.0
		&"observe":
			m.set_style(STYLE_DOTS, Palette.OCHRE, 36)
			value_target = 0.0
		&"intimidate":
			m.set_style(STYLE_DOUBLE, Palette.DUSK)
			value_target = 1.0
		&"eat":
			m.set_style(STYLE_CUT, Palette.OCHRE, 4)
			m.set_param("gap_deg", 14.0)
			value_target = 1.0
		_:
			m.set_style(STYLE_SMOOTH, Palette.BONE)
			value_target = 1.0
	if instant:
		_value = value_target
		m.set_param("frac", _value)
	elif not Style.reduced_motion():
		m.alpha = minf(m.alpha, 0.35)
		m.fade_in(Style.SWAP)

## Arc length 0..1: trust (befriend), the target's health (attack), observe progress (observe).
func set_value(frac: float) -> void:
	value_target = clampf(frac, 0.0, 1.0)

## The carcass ring: `total` bites, `lit` left.
func set_segments(total: int, lit: int) -> void:
	sel_mark.set_param("count", float(maxi(total, 1)))
	sel_mark.set_param("lit", float(lit))

func value() -> float:
	return _value

func _entity_pos(id: int) -> Vector3:
	var p := Vector3.ZERO
	if island != null and island.hosts.has(id):
		p = island.hosts[id].global_position
	elif Game.stage != null and id < Game.stage.cur.entities.size():
		var e: Dictionary = Game.stage.cur.entities[id]
		p = Vector3(e.x, 0.0, e.z)
	p.y = GroundMark.visual_ground(p.x, p.z)
	return p

func _front_of(id: int) -> float:
	if Game.stage != null and id < Game.stage.cur.entities.size():
		var e: Dictionary = Game.stage.cur.entities[id]
		return atan2(float(e.fx), -float(e.fz))
	return 0.0

func _process_selection(dt: float) -> void:
	if sel_id < 0:
		return
	sel_mark.place(_entity_pos(sel_id))
	sel_mark.set_param("start", _front_of(sel_id))
	_value = Style.follow(_value, value_target, dt)
	sel_mark.set_param("frac", _value)

# --- 7.5 / 7.6 the beat ring and the wind-up disc ---------------------------------------------------------------------

const BEAT_TICKS := 12
const WINDOW := 2          # ticks either side of the beat that count as "in rhythm"

## True while the beat is inside the rhythm window (the +-2 ticks of a 12 tick beat).
static func in_window(ticks_to_beat: int) -> bool:
	return ticks_to_beat <= WINDOW or ticks_to_beat >= BEAT_TICKS - WINDOW

## Befriending: a second ring closes in from 1.75x to 1.0x of the trust ring during each beat; in the window the trust
## ring itself thickens (so "now" is read by thickness, not by colour). `beat_in` < 0 hides it.
func set_beat(beat_in: int, in_win: bool) -> void:
	var m = sel_mark
	if beat_in < 0 or sel_id < 0:
		m.set_param("ring2", 0.0)
		m.thick_px = 0.0
		return
	var p := float(beat_in) / BEAT_TICKS          # 1 just after a beat, 0 on the beat
	if _ripple_t >= 0.0:
		return
	var jitter := 1.0 + (0.04 * sin(Time.get_ticks_msec() * 0.05) if _wobble_t > 0.0 else 0.0)
	m.set_param("ring2", 0.5 * lerpf(1.0, 1.75, p) * jitter)
	m.set_param("ring2_alpha", 0.55 if not in_win else 0.95)
	m.thick_px = 2.1 if in_win else 0.0

## The attacker's wind-up: an ember disc grows inside the ring; negative hides it.
func set_windup(progress: float) -> void:
	_windup_val = progress
	if progress < 0.0:
		sel_mark.set_param("disc", 0.0)
	else:
		sel_mark.set_param("disc", clampf(progress, 0.02, 1.0))
		sel_mark.set_param("disc_color", Palette.EMBER_HOT)

# --- 7.5 / 7.6 / 7.8 / 7.16 feedback: ripple, wobble, pearls, hits, threats, hover, shock ----------------------------

var pearls := 0                       # the combo: one bone dot per step on the ring, up to 5 (drawn by ring_fx.gd)
var _ripple_t := -1.0
var _wobble_t := 0.0
var _hit_t := 0.0
var _flash_t := 0.0                   # the white disc flash at a hit
var _flash_kind: StringName = &"ember"
var _ember_t := 0.0                   # the ring turns to ember teeth for a second (it stood its ground)
var _windup_val := -1.0
var _flash_was := false
var threat_marks := {}                # id -> GroundMark, thin toothed ember rings under who is hunting you
var hover_mark
var hover_id := -1

## One ripple leaves the ring outwards (1x to 1.5x, OUT).
func ripple() -> void:
	_ripple_t = 0.0

func wobble() -> void:
	_wobble_t = 0.2

func set_pearls(n: int) -> void:
	pearls = clampi(n, 0, 5)

## World positions of the pearls: on the ring at the creature's front-left, 14 degrees apart.
func pearl_points() -> Array:
	var out: Array = []
	if sel_id < 0:
		return out
	var c := _entity_pos(sel_id)
	var front := _front_of(sel_id)
	for k in pearls:
		var a := front - deg_to_rad(28.0 + 14.0 * k)
		var p := c + Vector3(sin(a), 0, -cos(a)) * sel_radius_m
		p.y = GroundMark.visual_ground(p.x, p.z) + 0.05
		out.append(p)
	return out

## You dealt a hit (lost_frac of its health): the ring thickens for a breath; the arc follows through set_value.
func hit(_lost_frac: float = 0.0) -> void:
	_hit_t = 0.15

## The wind-up ends in a hit on you: the disc snaps to a 0.1 s bone flash.
func windup_hit() -> void:
	_flash_t = 0.1

## The enemy fell: the ring breaks (swells and fades in 0.5 s); the carcass can be selected next.
func break_ring() -> void:
	sel_mark.scale_to(1.2, 0.5)
	sel_mark.fade_out(0.5)
	sel_id = -1

## It stood its ground (intimidate failed, a refused befriend): the ring shows ember teeth for a second.
func flash_ember() -> void:
	_ember_t = 1.0
	_flash_kind = &"ember"

## It saw you (observe): the dots fall away and the ring fades to plain bone for a moment.
func flash_bone() -> void:
	_ember_t = 1.2
	_flash_kind = &"bone"

func _process_fx(dt: float) -> void:
	var m = sel_mark
	if _ripple_t >= 0.0:
		_ripple_t += dt / 0.5
		if _ripple_t >= 1.0:
			_ripple_t = -1.0
			m.set_param("ring2", 0.0)
		else:
			m.set_param("ring2", 0.5 * (1.0 + 0.5 * Style.ease_out(_ripple_t)))
			m.set_param("ring2_alpha", 0.7 * (1.0 - _ripple_t))
	if _wobble_t > 0.0:
		_wobble_t = maxf(_wobble_t - dt, 0.0)
	if _hit_t > 0.0:
		_hit_t = maxf(_hit_t - dt, 0.0)
		m.thick_px = maxf(m.thick_px, 3.0 * (_hit_t / 0.15))
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - dt, 0.0)
		_flash_was = true
		m.set_param("disc", 1.0)
		m.set_param("disc_color", Palette.BONE)
	elif _flash_was:
		_flash_was = false
		set_windup(_windup_val)
	if _ember_t > 0.0:
		_ember_t = maxf(_ember_t - dt, 0.0)
		if _flash_kind == &"ember":
			m.set_style(STYLE_TEETH, Palette.EMBER_HOT, 16)
			m.set_param("frac", 1.0)
		else:
			m.set_style(STYLE_SMOOTH, Palette.BONE)
			m.set_param("frac", 1.0)
		if _ember_t <= 0.0:
			_apply_mode_style(sel_mode, true)
	if hover_mark != null and hover_id >= 0 and sel_id != hover_id:
		hover_mark.place(_entity_pos(hover_id))

## Thin toothed ember rings (0.5) under the creatures that hunt you, whether or not one of them is selected.
func set_threats(ids: Array) -> void:
	for id in threat_marks.keys():
		if not ids.has(id):
			threat_marks[id].fade_out(Style.OUT, true)
			threat_marks.erase(id)
	for id in ids:
		if sel_id == id:
			continue
		if not threat_marks.has(id):
			var m = _new_mark(0.5)
			var rad := 0.6
			if Game.stage != null and id < Game.stage.cur.entities.size():
				rad = maxf(0.6, float(Game.stage.cur.entities[id].get("radius_cm", 60)) * 0.01)
			m.radius_m = maxf(1.25 * rad, 0.6)
			m.width_px = 1.8
			m.place(_entity_pos(id), m.radius_m * 2.0)
			m.set_style(STYLE_TEETH, Palette.EMBER_HOT, 14)
			m.set_param("lit", -1.0)
			m.set_param("frac", 1.0)
			m.fade_in(Style.IN)
			threat_marks[id] = m
		threat_marks[id].place(_entity_pos(id))

## The pointer rests on a creature (0.25 s): its ring shows at 0.4 in its relationship style: stranger bone smooth,
## trusted or ally lichen, hostile ember teeth. -1 hides it (0.5 s later).
func set_hover(id: int, relationship: int = 0, hostile: bool = false) -> void:
	if id == hover_id:
		return
	hover_id = id
	if id < 0 or id == sel_id:
		if hover_mark != null:
			hover_mark.fade_out(0.5)
		return
	if hover_mark == null:
		hover_mark = _new_mark(0.4)
	var rad := 0.6
	if Game.stage != null and id < Game.stage.cur.entities.size():
		rad = maxf(0.6, float(Game.stage.cur.entities[id].get("radius_cm", 60)) * 0.01)
	hover_mark.radius_m = maxf(1.25 * rad, 0.6)
	hover_mark.width_px = 1.8
	hover_mark.place(_entity_pos(id), hover_mark.radius_m * 2.0)
	hover_mark.set_param("lit", -1.0)
	hover_mark.set_param("frac", 1.0)
	if hostile:
		hover_mark.set_style(STYLE_TEETH, Palette.EMBER_HOT, 14)
	elif relationship >= 2:
		hover_mark.set_style(STYLE_SMOOTH, Palette.LICHEN)
	else:
		hover_mark.set_style(STYLE_SMOOTH, Palette.BONE)
	hover_mark.fade_to(0.4, Style.IN)

## Intimidate: a dusk arc of 80 degrees leaves your feet towards the target, growing to the distance between you in 0.4 s.
func shock(from_pos: Vector3, to_pos: Vector3, _ok: bool) -> void:
	var d := Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z)
	var dist := maxf(d.length(), 1.0)
	var m = _new_mark(0.9)
	m.radius_m = dist
	m.width_px = 3.0
	m.place(_with_ground(from_pos), dist * 1.15)
	m.set_style(STYLE_SMOOTH, Palette.DUSK)
	m.set_param("frac", 80.0 / 360.0)
	m.set_param("start", atan2(d.x, -d.y) - deg_to_rad(40.0))
	m.set_param("track", 0.0)
	m.set_param("lit", -1.0)
	m.alpha = 0.0
	m.fade_to(0.9, 0.1)
	m.scale_to(1.0, 0.4, 0.1)
	var timer := get_tree().create_timer(0.45) if is_inside_tree() else null
	if timer != null:
		timer.timeout.connect(func() -> void:
			if is_instance_valid(m):
				m.fade_out(0.2, true))
