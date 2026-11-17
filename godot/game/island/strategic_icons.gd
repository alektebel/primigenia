extends CanvasLayer
# Strategic-zoom icon layer (docs/godot/CAMERA-ZOOM.md section 2): above z = 0.7 the models fade into icons
# drawn over the 3D view: your nest, species dens and creatures, `?` for undiscovered places, you.
#
# Hooks (the island wires them; the upcoming sites registry D2 of docs/godot/DEVTOOLS.md plugs into the first one):
#   pois_fn: Callable() -> Array of {id, kind, pos: Vector2 (x, z), discovered: bool, label: String}
#            kind: "nest" | "den" | "site" | "shard"; discovered == false draws a `?`.
#   actors_fn: Callable() -> Array of {id, kind: "player" | "creature", pos: Vector3, yaw: float}
# Clicking an icon selects it (island.gd sends creature_clicked); double-clicking zooms back down.

const COL_NEST := Color(1.0, 0.82, 0.3)
const COL_CREATURE := Color(0.95, 0.38, 0.28)
const COL_PLAYER := Color(0.96, 0.98, 1.0)
const COL_UNKNOWN := Color(0.85, 0.9, 1.0)
const COL_SHARD := Color(0.55, 0.9, 1.0)
const COL_DARK := Color(0.05, 0.07, 0.1, 0.85)
const PICK_RADIUS := 18.0

var camera: Camera3D
var pois_fn: Callable
var actors_fn: Callable
var ground_fn: Callable
var alpha := 0.0
var _canvas: Control
var _items: Array = []        # last frame's drawn icons: {kind, id, screen: Vector2}

func _init() -> void:
	layer = 0
	name = "StrategicIcons"
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_icons)
	add_child(_canvas)
	visible = false

# Called every frame by the island with the zoom's icon alpha (0 below z = 0.7).
func update_alpha(a: float) -> void:
	alpha = a
	visible = a > 0.0
	if visible:
		_canvas.queue_redraw()
	else:
		_items.clear()

# Nearest selectable icon (creatures) within PICK_RADIUS px of `screen`; {} when none. Only while visible.
func pick(screen: Vector2) -> Dictionary:
	if alpha < 0.3:
		return {}
	var best := {}
	var best_d := PICK_RADIUS
	for it in _items:
		if it.kind != "creature":
			continue
		var d: float = (it.screen as Vector2).distance_to(screen)
		if d < best_d:
			best_d = d
			best = it
	return best

func icon_count() -> int:
	return _items.size()

func _draw_icons() -> void:
	_items.clear()
	if camera == null or alpha <= 0.0:
		return
	var a := alpha
	if pois_fn.is_valid():
		for p in pois_fn.call():
			var w := Vector3(p.pos.x, ground_fn.call(p.pos.x, p.pos.y) if ground_fn.is_valid() else 0.0, p.pos.y)
			var s := _screen(w)
			if s.x < -50.0:
				continue
			_draw_poi(s, p, a)
	var player = null
	if actors_fn.is_valid():
		for ac in actors_fn.call():
			var s2 := _screen(ac.pos)
			if s2.x < -50.0:
				continue
			if ac.kind == "player":
				player = [s2, ac]
			else:
				_draw_creature(s2, a)
				_items.append({"kind": "creature", "id": ac.id, "screen": s2, "pos": ac.pos})
	if player != null:
		_draw_player(player[0], player[1].pos, float(player[1].yaw), a)
		_items.append({"kind": "player", "id": 0, "screen": player[0], "pos": player[1].pos})

func _screen(w: Vector3) -> Vector2:
	if camera.is_position_behind(w):
		return Vector2(-100, -100)
	return camera.unproject_position(w)

func _draw_poi(s: Vector2, p: Dictionary, a: float) -> void:
	var kind: String = p.get("kind", "site")
	if not bool(p.get("discovered", true)):
		_canvas.draw_circle(s, 11.0, Color(COL_DARK, 0.8 * a))
		_canvas.draw_arc(s, 11.0, 0.0, TAU, 20, Color(COL_UNKNOWN, a), 2.0)
		var f := ThemeDB.fallback_font
		_canvas.draw_string(f, s + Vector2(-5.0, 6.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(COL_UNKNOWN, a))
		_items.append({"kind": "unknown", "id": p.get("id", ""), "screen": s})
		return
	match kind:
		"nest":
			var roof := PackedVector2Array([s + Vector2(-13, 1), s + Vector2(0, -12), s + Vector2(13, 1)])
			_canvas.draw_colored_polygon(roof, Color(COL_DARK, a))
			_canvas.draw_rect(Rect2(s + Vector2(-9, 0), Vector2(18, 10)), Color(COL_DARK, a))
			var roof2 := PackedVector2Array([s + Vector2(-10, 0), s + Vector2(0, -9), s + Vector2(10, 0)])
			_canvas.draw_colored_polygon(roof2, Color(COL_NEST, a))
			_canvas.draw_rect(Rect2(s + Vector2(-7, 0), Vector2(14, 8)), Color(COL_NEST, a))
		"shard":
			var d := PackedVector2Array([s + Vector2(0, -10), s + Vector2(7, 0), s + Vector2(0, 10), s + Vector2(-7, 0)])
			_canvas.draw_colored_polygon(d, Color(COL_SHARD, a))
			_canvas.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color(COL_DARK, a), 1.5)
		_:
			_canvas.draw_circle(s, 9.0, Color(COL_DARK, a))
			_canvas.draw_circle(s, 6.0, Color(COL_CREATURE, a))
	_items.append({"kind": kind, "id": p.get("id", ""), "screen": s})

func _draw_creature(s: Vector2, a: float) -> void:
	var d := PackedVector2Array([s + Vector2(0, -10), s + Vector2(9, 0), s + Vector2(0, 10), s + Vector2(-9, 0)])
	_canvas.draw_colored_polygon(d, Color(COL_DARK, a))
	var d2 := PackedVector2Array([s + Vector2(0, -7), s + Vector2(6, 0), s + Vector2(0, 7), s + Vector2(-6, 0)])
	_canvas.draw_colored_polygon(d2, Color(COL_CREATURE, a))

# An arrow pointing the way the creature faces: the heading is projected through the camera, so it is right at any orbit.
func _draw_player(s: Vector2, pos: Vector3, yaw: float, a: float) -> void:
	var ahead := _screen(pos + Vector3(sin(yaw), 0.0, cos(yaw)) * 40.0)
	var h := (ahead - s).normalized() if ahead.x > -50.0 and ahead.distance_to(s) > 0.5 else Vector2.UP
	var tip := s + h * 13.0
	var l := s + h.rotated(2.5) * 10.0
	var r := s + h.rotated(-2.5) * 10.0
	_canvas.draw_arc(s, 17.0, 0.0, TAU, 28, Color(COL_PLAYER, 0.55 * a), 1.5)
	_canvas.draw_colored_polygon(PackedVector2Array([tip + h * 2.0, l + (l - s).normalized() * 2.0, s - h * 2.0, r + (r - s).normalized() * 2.0]), Color(COL_DARK, a))
	_canvas.draw_colored_polygon(PackedVector2Array([tip, l, s, r]), Color(COL_PLAYER, a))
