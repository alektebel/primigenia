extends Control
## Health lines over the creatures that matter (docs/godot/UI-DIEGETIC.md 7.2 and 7.7: a hairline, bone on a quiet track,
## EMBER for whoever is hostile; the toothed ring on the ground stays the fight's own mark). A creature gets one while it is
## hostile, in the fight, or selected, and the line fades with distance so a far herd draws nothing. The value follows
## damage with an ease-out of 200 ms and leaves a lighter "lost" segment that waits a moment and then closes.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")

const TICK := 0.2                   # s: how long the value takes to go down (ease-out)
const LOST_HOLD := 0.35             # s: the lost segment waits before it closes
const NEAR := 28.0                  # m: full strength up to here ...
const FAR := 55.0                   # m: ... and gone from here (selected and fighting ones ignore this)
const MAX_BARS := 8

## The animated value of one bar. Pure: the tests drive it with fixed steps.
class BarState extends RefCounted:
	var target := 1.0
	var shown := 1.0                # what the line draws
	var lost := 1.0                 # end of the lighter segment (>= shown)
	var _from := 1.0
	var _t := 1.0                   # 0..1 progress of the current tick-down
	var _hold := 0.0
	var alpha := 0.0

	func set_value(frac: float) -> void:
		frac = clampf(frac, 0.0, 1.0)
		if is_equal_approx(frac, target):
			return
		if frac < target:
			lost = maxf(lost, shown)                  # the part that just went stays as the lighter segment
			_hold = LOST_HOLD
			_from = shown
			_t = 0.0
		else:
			_from = shown
			_t = 0.0
			lost = frac
		target = frac
		if Style.reduced_motion():
			shown = frac
			lost = frac
			_t = 1.0

	func tick(dt: float) -> void:
		if _t < 1.0:
			_t = minf(_t + dt / TICK, 1.0)
			shown = lerpf(_from, target, Style.ease_out(_t))
		else:
			shown = target
		if lost > shown:
			if _hold > 0.0:
				_hold -= dt
			else:
				lost = move_toward(lost, shown, dt / TICK * maxf(lost - shown, 0.05))
		else:
			lost = shown

var camera: Camera3D
var anchor_fn := Callable()         # (id) -> {pos: Vector3 feet, height: float}
var _bars := {}                     # id -> {state: BarState, hostile: bool, focus: bool, dist: float, name: String}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## One row per candidate creature: {id, hp, hp_max, hostile, focus (fighting or selected), dist (m from the player)}.
func set_creatures(rows: Array) -> void:
	var keep := {}
	var wanted: Array = []
	for r in rows:
		if int(r.id) <= 0 or float(r.hp_max) <= 0.0:
			continue
		if not (bool(r.hostile) or bool(r.focus)):
			continue
		if not bool(r.focus) and float(r.dist) >= FAR:
			continue
		wanted.append(r)
	wanted.sort_custom(func(a, b) -> bool:
		if bool(a.focus) != bool(b.focus):
			return bool(a.focus)
		return float(a.dist) < float(b.dist))
	if wanted.size() > MAX_BARS:
		var extra := 0
		for i in range(wanted.size() - 1, MAX_BARS - 1, -1):
			if not bool(wanted[i].focus):
				wanted.remove_at(i)
	for r in wanted:
		var id := int(r.id)
		keep[id] = true
		if not _bars.has(id):
			var b := BarState.new()
			var f := clampf(float(r.hp) / float(r.hp_max), 0.0, 1.0)
			b.target = f
			b.shown = f
			b.lost = f
			_bars[id] = {"state": b}
		var e: Dictionary = _bars[id]
		e.hostile = bool(r.hostile)
		e.focus = bool(r.focus)
		e.dist = float(r.dist)
		e.want = true
		(e.state as BarState).set_value(float(r.hp) / float(r.hp_max))
	for id in _bars:
		if not keep.has(id):
			_bars[id].want = false

## Opacity from distance: 1 up to NEAR, 0 at FAR; the creatures in focus keep a floor of 0.8.
static func distance_alpha(dist: float, focus: bool) -> float:
	var a := 1.0 - smoothstep(NEAR, FAR, dist)
	return maxf(a, 0.8) if focus else a

func _process(dt: float) -> void:
	for id in _bars.keys():
		var e: Dictionary = _bars[id]
		var b: BarState = e.state
		b.tick(dt)
		var goal := distance_alpha(float(e.get("dist", 0.0)), bool(e.get("focus", false))) if bool(e.get("want", false)) else 0.0
		b.alpha = Style.approach(b.alpha, goal, dt, Style.IN if goal > b.alpha else Style.OUT)
		if not bool(e.get("want", false)) and b.alpha <= 0.0:
			_bars.erase(id)
	queue_redraw()

## Number of bars that would draw now (alpha above 0): for tests.
func visible_count() -> int:
	var n := 0
	for id in _bars:
		if (_bars[id].state as BarState).alpha > 0.01:
			n += 1
	return n

func _draw() -> void:
	if camera == null or not anchor_fn.is_valid():
		return
	for id in _bars:
		var e: Dictionary = _bars[id]
		var b: BarState = e.state
		if b.alpha <= 0.01:
			continue
		var a: Dictionary = anchor_fn.call(int(id))
		if a.is_empty():
			continue
		var head: Vector3 = a.pos + Vector3(0, float(a.height) * 1.12 + 0.25, 0)
		if camera.is_position_behind(head):
			continue
		var foot := camera.unproject_position(a.pos)
		var top := camera.unproject_position(a.pos + Vector3(0, float(a.height), 0))
		var half := clampf(absf(foot.y - top.y) * 0.7, Style.u(26.0), Style.u(64.0))
		var c := camera.unproject_position(head)
		var hostile: bool = e.hostile
		var col: Color = Palette.EMBER_HOT if hostile else Palette.BONE
		var left := c - Vector2(half, 0)
		var full := half * 2.0
		var th := Style.u(3.6)
		var k := b.alpha
		draw_line(left, left + Vector2(full, 0), Color(Palette.INK, 0.55 * k), th + 3.0, true)
		draw_line(left, left + Vector2(full, 0), Color(Palette.BONE, Style.TRACK_ALPHA * k), Style.u(1.2), true)
		if b.lost > b.shown + 0.002:
			draw_line(left + Vector2(full * b.shown, 0), left + Vector2(full * b.lost, 0), Color(Palette.BONE, 0.7 * k), th, true)
		if b.shown > 0.002:
			draw_line(left, left + Vector2(full * b.shown, 0), Color(col, k), th, true)
		draw_line(left + Vector2(full, -Style.u(3.0)), left + Vector2(full, Style.u(3.0)), Color(Palette.BONE, 0.6 * k), Style.u(1.2), true)
