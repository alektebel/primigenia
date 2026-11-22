extends Control
## The target marker of the verb-first flow (docs/briefs/verb-target.md, Spore style): chevrons pointing DOWN at the locked
## creature, RED for Attack and GREEN for Befriend (ochre for Eat and Observe, dusk for Intimidate), in two places: a ring of four
## chevrons around its feet and a stack of three bobbing over its head, with its name and relation (prey, hostile, friendly,
## neutral) beside them. It follows the creature every frame (the rendered position, not the 10 Hz sim) and has no outline
## around the body (LOOK 5). A lighter single chevron marks the creature under the cursor while a verb is armed.
## Drawn in screen space from the camera projection, so it is the same size and shape from any camera pitch.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const Modes := preload("res://ui/modes.gd")

var camera: Camera3D
## Callable(id) -> {pos: Vector3 (feet), height: float, radius: float?} or {} (the stage gives the rendered position).
var anchor_fn := Callable()
var locked_id := -1
var lock_mode: StringName = Modes.NONE
var lock_label := ""                # "Rondo"
var lock_relation := ""             # "prey"
var lock_hint := ""                 # "1-4 on the beat"
var hover_id := -1
var hover_mode: StringName = Modes.NONE
var hover_label := ""
var label_dx := 22.0                 # how far (u) the name sits to the side of the head: the stage clears the hotbar petals
var _a := 0.0                        # fade of the lock, 0..1
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The colour of a verb's arrows: red Attack, green Befriend.
static func color_of(mode: StringName) -> Color:
	if mode == Modes.ATTACK:
		return Palette.EMBER_HOT
	if mode == Modes.BEFRIEND:
		return Palette.LICHEN
	return Palette.MODE_COLORS.get(mode, Palette.BONE)

func set_lock(id: int, mode: StringName, label: String, relation: String, hint: String = "") -> void:
	if id != locked_id:
		_a = 0.0
	locked_id = id
	lock_mode = mode
	lock_label = label
	lock_relation = relation
	lock_hint = hint
	queue_redraw()

func clear_lock() -> void:
	locked_id = -1
	lock_mode = Modes.NONE
	queue_redraw()

func set_hover(id: int, mode: StringName, label: String) -> void:
	hover_id = id
	hover_mode = mode
	hover_label = label

## Screen position of the top of a creature (over its head), or Vector2.INF when it is not on screen.
func head_point(id: int) -> Vector2:
	var a := _anchor(id)
	if a.is_empty() or camera == null:
		return Vector2.INF
	var p: Vector3 = a.pos + Vector3(0, float(a.height), 0)
	return Vector2.INF if camera.is_position_behind(p) else camera.unproject_position(p)

func _anchor(id: int) -> Dictionary:
	return anchor_fn.call(id) if anchor_fn.is_valid() and id >= 0 else {}

func _process(dt: float) -> void:
	_clock += dt
	_a = Style.approach(_a, 1.0 if locked_id >= 0 else 0.0, dt, 0.18)
	if locked_id >= 0 or hover_id >= 0 or _a > 0.01:
		queue_redraw()

# A chevron pointing along `dir` (screen space) with its tip at `tip`.
func _chevron(tip: Vector2, dir: Vector2, col: Color, w: float, h: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var back := tip - dir * h
	Style.polyline(self, PackedVector2Array([back + perp * w, tip, back - perp * w]), col, Style.u(3.2))

func _draw() -> void:
	if camera == null:
		return
	if hover_id >= 0 and hover_id != locked_id and hover_mode != Modes.NONE:
		var hp := head_point(hover_id)
		if hp != Vector2.INF:
			var col := color_of(hover_mode)
			_chevron(hp + Vector2(0, -Style.u(10.0)), Vector2.DOWN, Color(col, 0.7), Style.u(9.0), Style.u(8.0))
			if hover_label != "":
				var f := Style.font_sans(true)
				Style.text(self, f, hp + Vector2(Style.u(14.0), -Style.u(16.0)), hover_label, Style.u(15.0), Color(Palette.BONE, 0.8))
	if locked_id < 0 or _a <= 0.01:
		return
	var a := _anchor(locked_id)
	if a.is_empty():
		return
	var k := Style.ease_out(_a)
	var col := color_of(lock_mode)
	var feet: Vector3 = a.pos
	var h := float(a.height)
	var bob := 0.0 if Style.reduced_motion() else sin(_clock * 5.0) * Style.u(3.5)
	if not camera.is_position_behind(feet):
		var centre := camera.unproject_position(feet)
		var rad := float(a.get("radius", clampf(h * 0.45, 0.7, 3.0)))
		var spin := 0.0 if Style.reduced_motion() else _clock * 0.5
		for i in 4:
			var ang := spin + TAU * float(i) / 4.0 + PI * 0.25
			var wp := feet + Vector3(cos(ang), 0, sin(ang)) * rad
			if camera.is_position_behind(wp):
				continue
			var sp := camera.unproject_position(wp)
			var inward := (centre - sp).normalized() if sp.distance_to(centre) > 1.0 else Vector2.DOWN
			_chevron(sp, inward, Color(col, 0.9 * k), Style.u(10.0), Style.u(10.0))
	var hp := head_point(locked_id)
	if hp == Vector2.INF:
		return
	var feet_s := camera.unproject_position(feet) if not camera.is_position_behind(feet) else hp + Vector2(0, 80)
	var sc := clampf(absf(feet_s.y - hp.y) / 90.0, 1.0, 1.8)      # bigger arrows on a bigger (nearer) creature
	for i in 3:
		var tip := hp + Vector2(0, -Style.u(8.0) - Style.u(15.0) * sc * i + bob)
		_chevron(tip, Vector2.DOWN, Color(col, (1.0 - 0.28 * i) * k), Style.u(15.0) * sc, Style.u(12.0) * sc)
	var f := Style.font_sans(true)
	var x := hp.x + Style.u(label_dx)
	var y := hp.y - Style.u(36.0)
	var name_size := Style.u(18.0)
	var w := Style.text_width(f, lock_label, name_size)
	if x + w > size.x - Style.u(20.0):
		x = hp.x - Style.u(label_dx) - w                     # flips to the left near the right edge
	Style.text(self, f, Vector2(x, y), lock_label, name_size, Color(Palette.BONE, k))
	if lock_relation != "":
		Style.text(self, f, Vector2(x, y + Style.u(18.0)), lock_relation, Style.u(14.0), Color(col, k))
	if lock_hint != "":
		Style.text(self, f, Vector2(x, y + Style.u(35.0)), lock_hint, Style.u(13.0), Color(Palette.FOG, 0.9 * k))
