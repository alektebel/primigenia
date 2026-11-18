extends RefCounted
## Sizes, motion, fonts and the few line-drawing helpers of the diegetic UI (docs/godot/UI-DIEGETIC.md sections 3-5).
##
## One design unit (u) is one pixel of the 1280 x 720 reference. The project uses the canvas_items stretch mode, so the
## canvas already scales with the window height: `u()` only applies the player's "size of the signs" setting.
## (PLAN-ui-diegetic.md wrote `u = x * viewport_h / 720 * ui_scale`; that would scale twice under this stretch mode.)

const Palette := preload("res://ui/palette.gd")

# Motion (section 5), seconds.
const IN := 0.18
const OUT := 0.35
const SWAP := 0.16
const GROW := 0.6
const REST := 2.5
const REST_FADE := 0.8
const MOTE := 0.7
const PULSE := 1.2
const BREATH := 2.4
const REST_ALPHA := 0.74
const TRACK_ALPHA := 0.24
const DISABLED_ALPHA := 0.40
const REDUCED := 0.08

static var _sans
static var _sans_medium
static var _italic

# --- settings (Game.settings, read through the autoload so the pure helpers stay testable) -------------------------

static func _settings() -> Dictionary:
	var tree = Engine.get_main_loop()
	if tree is SceneTree and (tree as SceneTree).root.has_node("Game"):
		return (tree as SceneTree).root.get_node("Game").settings
	return {}

static func setting(key: String, default: Variant) -> Variant:
	return _settings().get(key, default)

static func ui_scale() -> float:
	return clampf(float(setting("ui_scale", 1.0)), 0.85, 1.5)

static func u(x: float) -> float:
	return x * ui_scale()

static func reduced_motion() -> bool:
	return bool(setting("reduced_motion", false))

static func strong_outlines() -> bool:
	return bool(setting("strong_outlines", false))

static func names_always() -> bool:
	return bool(setting("names_always", false))

static func numbers() -> bool:
	return bool(setting("numbers", false))

static func rest_alpha() -> float:
	return 0.9 if strong_outlines() else REST_ALPHA

# --- fonts -------------------------------------------------------------------------------------------------------

static func font_sans(medium: bool = false) -> Font:
	if _sans == null:
		_sans = load("res://ui/fonts/AlegreyaSans-Regular.ttf")
		_sans_medium = load("res://ui/fonts/AlegreyaSans-Medium.ttf")
	return _sans_medium if medium else _sans

static func font_italic() -> Font:
	if _italic == null:
		_italic = load("res://ui/fonts/Alegreya-Italic.ttf")
	return _italic

# --- motion ------------------------------------------------------------------------------------------------------

## Time of a transition: the named duration, or 0.08 s with Less motion.
static func dur(seconds: float) -> float:
	return minf(seconds, REDUCED) if reduced_motion() else seconds

## Move `cur` towards `target` so that a full 0..1 change takes `seconds` (linear; callers shape it with ease_*).
static func approach(cur: float, target: float, dt: float, seconds: float) -> float:
	var step := dt / maxf(dur(seconds), 0.001)
	return move_toward(cur, target, step)

static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)

static func ease_in(t: float) -> float:
	return pow(clampf(t, 0.0, 1.0), 3.0)

static func ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## A value that follows a target with the GROW time and an ease-out: ring lengths, vitals lines.
static func follow(cur: float, target: float, dt: float) -> float:
	if reduced_motion():
		return target
	var k := 1.0 - exp(-dt / (GROW * 0.35))
	return lerpf(cur, target, k)

# --- drawing (screen space) --------------------------------------------------------------------------------------

## Position on a circle; angle in degrees clockwise from north.
static func on_circle(centre: Vector2, radius: float, deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return centre + Vector2(sin(a), -cos(a)) * radius

static func halo_alpha() -> float:
	return 0.7 if strong_outlines() else 0.5

## A line with a dark halo under it.
static func line(c: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	c.draw_line(a, b, Color(Palette.INK, halo_alpha() * color.a), width + u(2.4), true)
	c.draw_line(a, b, color, width, true)

static func polyline(c: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() < 2:
		return
	c.draw_polyline(pts, Color(Palette.INK, halo_alpha() * color.a), width + u(2.4), true)
	c.draw_polyline(pts, color, width, true)

static func circle_outline(c: CanvasItem, centre: Vector2, radius: float, color: Color, width: float, fill: Color = Color(0, 0, 0, 0)) -> void:
	if fill.a > 0.0:
		c.draw_circle(centre, radius, fill)
	c.draw_arc(centre, radius, 0.0, TAU, 48, Color(Palette.INK, halo_alpha() * color.a), width + u(2.4), true)
	c.draw_arc(centre, radius, 0.0, TAU, 48, color, width, true)

## Arc of a circle with a halo; degrees clockwise from north, a0 < a1.
static func arc(c: CanvasItem, centre: Vector2, radius: float, a0: float, a1: float, color: Color, width: float, cap_round := true) -> void:
	var n := maxi(int(ceil(absf(a1 - a0) / 6.0)), 2)
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(on_circle(centre, radius, lerpf(a0, a1, float(i) / n)))
	c.draw_polyline(pts, Color(Palette.INK, halo_alpha() * color.a), width + u(2.4), true)
	c.draw_polyline(pts, color, width, true)
	if cap_round:
		c.draw_circle(pts[0], width * 0.5, color)
		c.draw_circle(pts[n], width * 0.5, color)

## The line styles of section 4 as arcs: smooth, teeth, dots, double, cut. `count` is teeth or segments.
static func arc_styled(c: CanvasItem, centre: Vector2, radius: float, a0: float, a1: float, style: StringName, color: Color,
		width: float, count: int = 0, lit: int = -1) -> void:
	match style:
		&"teeth":
			arc(c, centre, radius, a0, a1, color, width, false)
			var n := count if count > 0 else maxi(3, int(round((a1 - a0) / 18.0)))
			for i in n:
				var a := a0 + (a1 - a0) * (i + 0.5) / n
				var hw := 3.2
				var p0 := on_circle(centre, radius, a - hw)
				var p1 := on_circle(centre, radius + u(7.0), a)
				var p2 := on_circle(centre, radius, a + hw)
				c.draw_colored_polygon(PackedVector2Array([p0, p1, p2]), color)
		&"dots":
			var gap := 10.0
			var a := a0
			while a <= a1 + 0.01:
				var p := on_circle(centre, radius, a)
				c.draw_circle(p, width * 1.0 + u(1.2), Color(Palette.INK, halo_alpha() * color.a))
				c.draw_circle(p, width * 0.75, color)
				a += gap
		&"double":
			arc(c, centre, radius, a0, a1, color, width)
			arc(c, centre, radius + u(5.5), a0 + 4.0, a1 - 4.0, Color(color, color.a * 0.8), width * 0.7)
		&"cut":
			var n := maxi(count, 1)
			var seg := (a1 - a0) / n
			for i in n:
				var col := color if (lit < 0 or i < lit) else Color(color, color.a * TRACK_ALPHA)
				arc(c, centre, radius, a0 + i * seg + 7.0, a0 + (i + 1) * seg - 7.0, col, width)
		_:
			arc(c, centre, radius, a0, a1, color, width)

static func text(c: CanvasItem, font: Font, pos: Vector2, s: String, size: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var sz := int(round(size))
	c.draw_string_outline(font, pos, s, align, width, sz, int(u(4.0)), Color(Palette.INK, 0.55 * color.a))
	c.draw_string(font, pos, s, align, width, sz, color)

static func text_width(font: Font, s: String, size: float) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x
