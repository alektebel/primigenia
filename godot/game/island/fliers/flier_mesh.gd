extends RefCounted
## Procedural bodies of the ambient fliers (docs/godot/AMBIENT-FLIERS.md). Metres at scale 1, +Z forward, +Y up, wings along X.
## Same recipe as the flight lab bodies (web/gaitlab/flight.html, docs/evidence/loco/flight.md): a lofted torso, a head with a
## beak, a tail, a wing planform whose vertices carry a span weight (COLOR.a) that game/shaders/flier.gdshader flaps.
## Vertex layout: COLOR.rgb colour, COLOR.a wing weight 0..1, UV.x hip height and UV.y = 1 on a leg (legs fold up in cruise).

const Species := preload("res://game/island/fliers/flier_species.gd")

static var _cache := {}

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nor: Vector3, col: Color, w: float = 0.0, u: Vector2 = Vector2.ZERO) -> int:
		v.append(p)
		n.append(nor)
		c.append(Color(col.r, col.g, col.b, w))
		uv.append(u)
		return v.size() - 1

	## Godot's front face is clockwise: make the geometric normal point against `front` (the side that must read as the front).
	func tri(a: int, b: int, d: int, front: Vector3) -> void:
		var g := (v[b] - v[a]).cross(v[d] - v[a])
		if g.dot(front) > 0.0:
			idx.append_array([a, d, b])
		else:
			idx.append_array([a, b, d])

	## A tube along z through `stations` [[z, rx, ry, y_off], ...]; closed at both ends (the first and last radius are small).
	func loft_z(stations: Array, segs: int, top: Color, bot: Color, x_off: float = 0.0, mid_col: Color = Color(0, 0, 0, 0)) -> void:
		var rings: Array = []
		for s in stations:
			var ring: Array = []
			for k in segs:
				var a := TAU * float(k) / float(segs)
				var cx := cos(a)
				var sy := sin(a)
				var p := Vector3(x_off + cx * float(s[1]), float(s[3]) + sy * float(s[2]), float(s[0]))
				var nor := Vector3(cx / maxf(float(s[1]), 0.001), sy / maxf(float(s[2]), 0.001), 0.0).normalized()
				var t := smoothstep(-0.55, 0.55, nor.y)
				var col := bot.lerp(top, t)
				if mid_col.a > 0.0:
					col = col.lerp(mid_col, 0.6 * (1.0 - absf(nor.y * 1.6)))
				ring.append(vert(p, nor, col))
			rings.append(ring)
		for i in rings.size() - 1:
			var cz := (float(stations[i][0]) + float(stations[i + 1][0])) * 0.5
			for k in segs:
				var k2 := (k + 1) % segs
				var a0: int = rings[i][k]
				var a1: int = rings[i][k2]
				var b0: int = rings[i + 1][k]
				var b1: int = rings[i + 1][k2]
				var out := Vector3(cos(TAU * (float(k) + 0.5) / float(segs)), sin(TAU * (float(k) + 0.5) / float(segs)), 0.0)
				tri(a0, a1, b0, out)
				tri(a1, b1, b0, out)
		# end caps
		for end in [0, rings.size() - 1]:
			var z := float(stations[end][0])
			var cen := vert(Vector3(x_off, float(stations[end][3]), z), Vector3(0, 0, -1.0 if end == 0 else 1.0), bot.lerp(top, 0.5))
			var dirz := Vector3(0, 0, -1.0 if end == 0 else 1.0)
			for k in segs:
				tri(cen, rings[end][k], rings[end][(k + 1) % segs], dirz)

	## A straight tapered tube (a leg, a streamer).
	func tube(p0: Vector3, p1: Vector3, r0: float, r1: float, segs: int, col: Color, leg: bool = false) -> void:
		var axis := (p1 - p0)
		var ax := axis.normalized()
		var ref := Vector3.RIGHT if absf(ax.dot(Vector3.RIGHT)) < 0.9 else Vector3.UP
		var s1 := ax.cross(ref).normalized()
		var s2 := ax.cross(s1).normalized()
		var hip := Vector2(p0.y, 1.0) if leg else Vector2.ZERO
		var r0i: Array = []
		var r1i: Array = []
		for k in segs:
			var a := TAU * float(k) / float(segs)
			var dir := s1 * cos(a) + s2 * sin(a)
			r0i.append(vert(p0 + dir * r0, dir, col, 0.0, hip))
			r1i.append(vert(p1 + dir * r1, dir, col, 0.0, hip))
		for k in segs:
			var k2 := (k + 1) % segs
			var dir := s1 * cos(TAU * (float(k) + 0.5) / float(segs)) + s2 * sin(TAU * (float(k) + 0.5) / float(segs))
			tri(r0i[k], r0i[k2], r1i[k], dir)
			tri(r0i[k2], r1i[k2], r1i[k], dir)

	## A flat strip (a wing, a tail): stations [[x, z_le, z_te, y], ...] root to tip along +x (mirrored by `side`).
	## `w0` weight at the root station .. 1 at the tip; colour root -> tip, trailing edge lighter by `te_lite`.
	func strip(stations: Array, side: float, c_root: Color, c_tip: Color, te_lite: float, weighted: bool = true, tail: bool = false, w0: float = 0.02, w1: float = 1.0) -> void:
		var m := stations.size()
		var le: Array = []
		var te: Array = []
		for i in m:
			var s: Array = stations[i]
			var t := float(i) / float(maxi(m - 1, 1))
			var w := lerpf(w0, w1, t) if weighted else 0.0
			if tail:
				w = 0.0
			var col := c_root.lerp(c_tip, smoothstep(0.1, 1.0, t))
			var colte := col.lerp(Color.WHITE, te_lite).lerp(col, 0.2)
			var x := float(s[0]) * side
			le.append(vert(Vector3(x, float(s[3]), float(s[1])), Vector3.UP, col, w))
			te.append(vert(Vector3(x, float(s[3]) - 0.004, float(s[2])), Vector3.UP, colte, w))
		for i in m - 1:
			tri(le[i], le[i + 1], te[i], Vector3.UP)
			tri(le[i + 1], te[i + 1], te[i], Vector3.UP)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## Wing planform stations from a profile: [[t, le_z, te_z, y]] with t along the half span (m): chord from `c0` (root) to `c1` (tip),
## the leading edge swept back `sweep` m at the tip, a dihedral `dih` m and a drooped tip `droop` m.
static func _stations(half: float, c0: float, c1: float, sweep: float, dih: float, droop: float, n: int, root_z: float, scallop: float = 0.0) -> Array:
	var out: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		var chord := lerpf(c0, c1, pow(t, 0.8))
		var le := root_z + 0.35 * c0 - sweep * t * t
		var te := le - chord
		if scallop > 0.0:
			te += scallop * sin(t * PI * float(n) * 0.5) * t
		var y := dih * t - droop * t * t * t
		out.append([half * (0.04 + 0.96 * t), le, te, y])
	return out


static func mesh_for(species_id: int) -> ArrayMesh:
	if _cache.has(species_id):
		return _cache[species_id]
	var b := MB.new()
	match species_id:
		Species.ALARIZ:
			_alariz(b)
		Species.PICO:
			_pico(b)
		Species.ZANCUILLA:
			_zancuilla(b)
		Species.ALASUCENA:
			_alasucena(b)
	var m := b.mesh()
	_cache[species_id] = m
	return m


# Alariz: the soaring scavenger (lore: 2.4 m, 85 kg, broad high-aspect wings with feather fingers, bare head, hooked beak).
static func _alariz(b: MB) -> void:
	var dark := Color(0.115, 0.095, 0.085)
	var mid := Color(0.19, 0.145, 0.105)
	var belly := Color(0.34, 0.29, 0.25)
	var skin := Color(0.50, 0.34, 0.30)
	b.loft_z([[-0.55, 0.03, 0.03, 0.02], [-0.3, 0.17, 0.15, 0.02], [0.05, 0.25, 0.22, 0.03], [0.4, 0.22, 0.2, 0.05], [0.68, 0.14, 0.14, 0.09], [0.82, 0.06, 0.07, 0.11]], 10, dark, belly)
	# neck and bare head
	b.loft_z([[0.62, 0.09, 0.09, 0.1], [0.82, 0.07, 0.075, 0.15], [1.0, 0.075, 0.08, 0.17], [1.14, 0.08, 0.085, 0.16], [1.3, 0.035, 0.04, 0.14]], 8, skin, skin.lerp(belly, 0.3))
	b.loft_z([[1.2, 0.03, 0.045, 0.145], [1.34, 0.02, 0.04, 0.13], [1.42, 0.004, 0.012, 0.1]], 6, Color(0.30, 0.26, 0.22), Color(0.22, 0.2, 0.18))   # hooked beak
	# wedge tail
	for s in [-1.0, 1.0]:
		b.strip([[0.02, -0.5, -0.55, 0.0], [0.2, -0.52, -1.05, 0.0], [0.34, -0.55, -1.2, 0.0]], s, dark, dark.lerp(mid, 0.5), 0.1, false, true)
	# legs, tucked
	for s in [-1.0, 1.0]:
		b.tube(Vector3(0.1 * s, -0.12, 0.05), Vector3(0.1 * s, -0.5, 0.1), 0.03, 0.02, 5, skin.darkened(0.2), true)
	# wings: broad, long, with six feather fingers at the tip
	for s in [-1.0, 1.0]:
		var st := _stations(2.3, 0.95, 0.5, 0.5, 0.0, 0.0, 6, 0.1)
		var inner := st.slice(0, 5)
		b.strip(inner, s, mid, dark.lerp(mid, 0.4), 0.12, true, false, 0.02, 0.67)
		var tipst: Array = st.slice(4, 7)
		var x0: float = float(st[4][0])
		var le0: float = float(st[4][1])
		var te0: float = float(st[4][2])
		for f in 6:
			var u := float(f) / 5.0
			var zle: float = lerpf(le0, le0 - 0.12, u)
			var zte: float = lerpf(te0 + 0.05, te0 - 0.18, u) - 0.05 * float(f)
			var spread := 0.32 * (u - 0.3)
			var fing: Array = []
			for k in 4:
				var t := float(k) / 3.0
				var xx: float = x0 + (float(st[6][0]) - x0) * t
				fing.append([xx + 0.14 * t, zle - 0.24 * t - 0.25 * t * t * (1.0 - u), zle - 0.24 * t - 0.25 * t * t * (1.0 - u) - lerpf(zle - zte, 0.12, t) * 0.95, 0.04 * t * (float(f) * 0.5 - 1.0) + spread * t * 0.0 - 0.06 * t * t])
			b.strip(fing, s, dark.lerp(mid, 0.5), dark, 0.0, true, false, 0.67, 1.0)
	_weight_fix(b)


# Bello-pico: a gull-sized cleaner of the meadow and the shore (25 cm, 150 g), cream below, slate above, long coral beak.
static func _pico(b: MB) -> void:
	var back := Color(0.30, 0.34, 0.43)
	var cream := Color(0.86, 0.83, 0.74)
	var coral := Color(0.86, 0.34, 0.24)
	b.loft_z([[-0.1, 0.012, 0.012, 0.0], [-0.04, 0.05, 0.045, 0.0], [0.04, 0.065, 0.06, 0.005], [0.1, 0.05, 0.05, 0.015], [0.14, 0.03, 0.032, 0.025]], 8, back, cream)
	b.loft_z([[0.11, 0.025, 0.028, 0.03], [0.15, 0.032, 0.034, 0.035], [0.18, 0.026, 0.028, 0.034], [0.2, 0.01, 0.012, 0.03]], 7, back.lightened(0.15), cream)
	b.loft_z([[0.19, 0.012, 0.013, 0.03], [0.26, 0.009, 0.01, 0.027], [0.32, 0.002, 0.003, 0.022]], 5, coral, coral.darkened(0.15))   # the long bright beak
	for s in [-1.0, 1.0]:
		b.strip([[0.015, -0.1, -0.17, 0.0], [0.05, -0.12, -0.26, 0.0]], s, back.darkened(0.2), back.darkened(0.1), 0.15, false, true)
		b.tube(Vector3(0.025 * s, -0.04, 0.0), Vector3(0.02 * s, -0.11, -0.01), 0.008, 0.005, 4, coral.darkened(0.2), true)
		var st := _stations(0.26, 0.11, 0.045, 0.1, 0.02, 0.0, 5, 0.04)
		b.strip(st, s, back.lightened(0.05), Color(0.08, 0.09, 0.12), 0.25)


# Zancuilla: a green dart (25 cm, 280 g) with patagial (bat-like) wings and long trailing legs, active at dawn and dusk.
static func _zancuilla(b: MB) -> void:
	var green := Color(0.16, 0.38, 0.19)
	var pale := Color(0.55, 0.68, 0.38)
	var mem := Color(0.21, 0.36, 0.17)
	b.loft_z([[-0.09, 0.01, 0.01, 0.0], [-0.04, 0.04, 0.04, 0.0], [0.04, 0.06, 0.055, 0.0], [0.1, 0.045, 0.045, 0.01], [0.13, 0.025, 0.03, 0.02]], 8, green, pale)
	b.loft_z([[0.1, 0.022, 0.026, 0.02], [0.14, 0.03, 0.032, 0.03], [0.18, 0.024, 0.026, 0.028], [0.215, 0.008, 0.01, 0.024]], 7, green.lightened(0.1), pale)
	b.loft_z([[0.2, 0.006, 0.007, 0.024], [0.26, 0.004, 0.005, 0.02], [0.3, 0.001, 0.002, 0.017]], 5, Color(0.2, 0.17, 0.12), Color(0.2, 0.17, 0.12))
	for s in [-1.0, 1.0]:
		# the long stilt legs: down when perched, tucked back and short in cruise (the shader scales them)
		b.tube(Vector3(0.02 * s, -0.02, -0.06), Vector3(0.025 * s, -0.2, -0.16), 0.008, 0.004, 4, Color(0.55, 0.42, 0.25), true)
		# patagium: four finger rays carry a scalloped membrane
		var st := _stations(0.33, 0.2, 0.08, 0.12, 0.015, 0.0, 6, 0.05, 0.035)
		b.strip(st, s, green.lightened(0.04), mem.darkened(0.2), 0.2)
	b.strip([[0.0, -0.12, -0.2, 0.0], [0.04, -0.12, -0.24, 0.0]], 1.0, green, mem, 0.1, false, true)
	b.strip([[0.0, -0.12, -0.2, 0.0], [0.04, -0.12, -0.24, 0.0]], -1.0, green, mem, 0.1, false, true)


# Alasuncena (lore: alasucena): a 12 cm feathered biped with membranous wings that hovers at flowers and perches upright on reeds.
static func _alasucena(b: MB) -> void:
	var body := Color(0.52, 0.46, 0.60)
	var throat := Color(0.92, 0.52, 0.22)
	var wingc := Color(0.82, 0.76, 0.88)
	b.loft_z([[-0.05, 0.008, 0.008, 0.0], [-0.02, 0.026, 0.028, 0.0], [0.03, 0.034, 0.036, 0.005], [0.07, 0.03, 0.03, 0.012], [0.095, 0.014, 0.016, 0.02]], 7, body, throat.lerp(body, 0.35))
	b.loft_z([[0.07, 0.012, 0.014, 0.018], [0.095, 0.02, 0.022, 0.024], [0.12, 0.016, 0.018, 0.024], [0.135, 0.005, 0.006, 0.022]], 6, body.lightened(0.1), throat)
	b.loft_z([[0.13, 0.004, 0.005, 0.022], [0.17, 0.003, 0.003, 0.02], [0.2, 0.001, 0.001, 0.018]], 4, Color(0.15, 0.12, 0.1), Color(0.15, 0.12, 0.1))
	# long twin tail streamers
	for s in [-1.0, 1.0]:
		b.tube(Vector3(0.006 * s, 0.0, -0.05), Vector3(0.025 * s, -0.015, -0.27), 0.004, 0.0015, 4, throat.darkened(0.1))
		b.tube(Vector3(0.012 * s, -0.025, 0.0), Vector3(0.012 * s, -0.075, -0.01), 0.005, 0.003, 4, Color(0.3, 0.22, 0.2), true)
		var st := _stations(0.15, 0.085, 0.045, 0.03, 0.01, 0.0, 5, 0.03, 0.01)
		b.strip(st, s, wingc, wingc.darkened(0.25), 0.1)


# Wing vertices never sit exactly on x = 0 (the shader tells the left wing from the right by the sign of x).
static func _weight_fix(_b: MB) -> void:
	pass
