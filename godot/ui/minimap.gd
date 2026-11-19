extends Control
## The small round map, top-right (the owner's answer 3; replaces the design's compass strip). North-up, centred on you,
## about 420 m from its centre to its edge: the coastline as a thin bone line, the nest, the selected creature, your heading, and
## discovered `?` places when the game has any. Quiet: a thin bone ring with a halo and low opacity at rest. The zoomed-out
## strategic camera stays the big map, and this one fades out when it takes over.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")

const RADIUS_U := 52.0
const WORLD_RADIUS := 420.0        # metres from the centre to the edge of the map
const PX := 64                     # sampled image size
const REDRAW_M := 24.0

var enabled := true
var data                           # TerrainData (Game.data)
var player := Vector2.ZERO         # x, z
var heading := 0.0                 # radians, bearing from -z clockwise (north = 0)
var nest := Vector2.INF
var target := Vector2.INF
var target_hostile := false
var quest_ping := Vector2.INF      # where the current task points (a quiet copper pulse, never an arrow); INF = none
var _ping_t := 0.0
var places: Array = []             # [Vector2] discovered places (drawn as `?`)
var fade := 0.0                    # 1 = hidden (the strategic camera is on)
var _tex: ImageTexture
var _centre := Vector2(INF, INF)
var _bright := 0.0
var _act := 99.0
var _last_yaw := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func map_centre() -> Vector2:
	return Vector2(size.x - Style.u(28.0 + RADIUS_U), Style.u(28.0 + RADIUS_U))

func world_to_map(p: Vector2) -> Vector2:
	return (p - player) / WORLD_RADIUS * Style.u(RADIUS_U)

## Re-render the land mask around the player (a coarse sample of the terrain); only when the player moved enough.
func refresh(force := false) -> void:
	if data == null:
		return
	if not force and _centre.distance_to(player) < REDRAW_M:
		return
	_centre = player
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var h: Array = []
	h.resize(PX * PX)
	for j in PX:
		for i in PX:
			var wx := player.x + (float(i) / (PX - 1) * 2.0 - 1.0) * WORLD_RADIUS
			var wz := player.y + (float(j) / (PX - 1) * 2.0 - 1.0) * WORLD_RADIUS
			h[j * PX + i] = data.ground(wx, wz) > 0.4
	for j in PX:
		for i in PX:
			var land: bool = h[j * PX + i]
			var coast := false
			var wx2 := player.x + (float(i) / (PX - 1) * 2.0 - 1.0) * WORLD_RADIUS
			var wz2 := player.y + (float(j) / (PX - 1) * 2.0 - 1.0) * WORLD_RADIUS
			var river: bool = land and data.river_class(data.cell_index(wx2, wz2)) > 0
			if land:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ni: int = i + d.x
					var nj: int = j + d.y
					if ni < 0 or nj < 0 or ni >= PX or nj >= PX or not h[nj * PX + ni]:
						coast = true
						break
			img.set_pixel(i, j, Color(1, 1, 1, 1.0) if coast else (Color(0.8, 0.9, 1.0, 0.7) if river else (Color(1, 1, 1, 0.22) if land else Color(1, 1, 1, 0.0))))
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)

func poke() -> void:
	_bright = 1.0
	_act = 0.0

func _process(dt: float) -> void:
	_act += dt
	_ping_t += dt
	if _act > Style.REST:
		_bright = move_toward(_bright, 0.0, dt / Style.REST_FADE)
	queue_redraw()

func _draw() -> void:
	if not enabled or fade >= 0.999:
		return
	var c := map_centre()
	var r := Style.u(RADIUS_U)
	var a := lerpf(Style.rest_alpha(), 1.0, _bright) * (1.0 - fade) * 0.85
	draw_circle(c, r, Color(Palette.INK, 0.22 * (1.0 - fade)))
	if _tex != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in 48:
			var ang := TAU * k / 48.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
			uvs.append(Vector2(0.5, 0.5) + Vector2(cos(ang), sin(ang)) * 0.5)
		draw_polygon(pts, PackedColorArray([Color(Palette.BONE, a)]), uvs, _tex)
	Style.circle_outline(self, c, r, Color(Palette.BONE, a * 0.9), Style.u(1.3))
	# north tick
	Style.line(self, c + Vector2(0, -r), c + Vector2(0, -r - Style.u(5.0)), Color(Palette.BONE, a), Style.u(1.3))
	Style.text(self, Style.font_sans(true), c + Vector2(-Style.u(4.0), -r - Style.u(8.0)), "N", Style.u(11.0), Color(Palette.FOG, a))
	# the nest: a glyph, or a tick at the edge when it is out of range
	if nest.x < 1e8:
		_mark(c, r, nest, a, "nest", Palette.COPPER)
	for p in places:
		_mark_text(c, r, p, a, "?")
	if target.x < 1e8:
		_target(c, r, target, a)
	if quest_ping.x < 1e8:
		_ping(c, r, quest_ping, a)
	# you: a small arrow pointing along your heading
	var fwd := Vector2(sin(heading), -cos(heading))
	var side := Vector2(-fwd.y, fwd.x)
	var tip := c + fwd * Style.u(7.0)
	var pl := PackedVector2Array([tip, c - fwd * Style.u(4.0) + side * Style.u(4.2), c - fwd * Style.u(1.5), c - fwd * Style.u(4.0) - side * Style.u(4.2)])
	draw_colored_polygon(PackedVector2Array([pl[0] + (pl[0] - c).normalized() * 1.2, pl[1], pl[2], pl[3]]), Color(Palette.INK, 0.6 * a))
	draw_colored_polygon(pl, Color(Palette.BONE, a))

func _edge(c: Vector2, r: float, wp: Vector2) -> Array:
	var m := world_to_map(wp)
	var inside := m.length() <= r - Style.u(5.0)
	if not inside:
		m = m.normalized() * (r - Style.u(1.0))
	return [c + m, inside]

func _mark(c: Vector2, r: float, wp: Vector2, a: float, glyph: String, col: Color) -> void:
	var e := _edge(c, r, wp)
	if e[1]:
		Glyphs.draw(self, glyph, e[0], 14.0, Color(col, a))
	else:
		var d: Vector2 = (e[0] - c).normalized()
		Style.line(self, e[0] - d * Style.u(3.0), e[0] + d * Style.u(2.0), Color(col, a), Style.u(2.4))

func _mark_text(c: Vector2, r: float, wp: Vector2, a: float, s: String) -> void:
	var e := _edge(c, r, wp)
	if e[1]:
		Style.text(self, Style.font_sans(true), e[0] + Vector2(-Style.u(3.0), Style.u(4.0)), s, Style.u(13.0), Color(Palette.OCHRE, a))

func _target(c: Vector2, r: float, wp: Vector2, a: float) -> void:
	var e := _edge(c, r, wp)
	var col := Palette.EMBER_HOT if target_hostile else Palette.BONE
	var p: Vector2 = e[0]
	var s := Style.u(4.2)
	var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0), p + Vector2(0, -s)])
	Style.polyline(self, pts, Color(col, a), Style.u(1.6))

## The task's ping: a copper dot with a ring that opens and fades once per PULSE seconds (ease-out), a tick on the rim when it is
## out of range. A hint toward the place, not a route.
func _ping(c: Vector2, r: float, wp: Vector2, a: float) -> void:
	var e := _edge(c, r, wp)
	var k := fposmod(_ping_t, Style.PULSE) / Style.PULSE
	var col := Palette.COPPER
	if e[1]:
		draw_circle(e[0], Style.u(2.4), Color(col, a))
		draw_arc(e[0], Style.u(3.0 + 7.0 * Style.ease_out(k)), 0.0, TAU, 24, Color(col, a * (1.0 - k)), Style.u(1.3), true)
	else:
		var d: Vector2 = (e[0] - c).normalized()
		Style.line(self, e[0] - d * Style.u(4.0), e[0] + d * Style.u(1.0), Color(col, a * (0.55 + 0.45 * (1.0 - k))), Style.u(2.4))
