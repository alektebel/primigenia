extends SceneTree
# Bakes the tileable rock and scree detail textures (docs/godot/PLAN-rock.md step 2, section 3):
#   godot --headless --path godot --script res://game/tools/bake_rock_detail.gd [-- <preview sheet path>]
# Deterministic (integer lattice hash, no FastNoiseLite) and exactly tileable (every lattice index wraps modulo its period).
#
# Layout of both PNGs (RGBA8, linear data, never imported as a normal map because the channels are packed):
#   R, G  detail normal as -grad(h) in image (u, v) coordinates, v increasing down the rows: 0.5 + 0.5 * d
#   B     height 0..1
#   A     crack / cavity occlusion, 1 = open, 0 = deep crack
# The rock sheet is painted for side faces: u is horizontal, v is vertical, bedding runs along u.

const ROCK_SIZE := 512
const SCREE_SIZE := 256
const ROCK_PATH := "res://game/textures/rock_detail.png"
const SCREE_PATH := "res://game/textures/scree_detail.png"
const SHEET_PATH := "res://../docs/evidence/godot/rock/detail_sheet.png"

# ---- integer lattice hash -> [0, 1) -------------------------------------------------------------------------------------
static func hash2(ix: int, iy: int, seed_: int) -> float:
	var h: int = (ix * 374761393 + iy * 668265263 + seed_ * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h) / 4294967296.0

static func wrapi_(i: int, p: int) -> int:
	return ((i % p) + p) % p

# Periodic value noise at tile coordinates (u, v) in [0, 1), with pu x pv lattice cells.
static func vnoise(u: float, v: float, pu: int, pv: int, seed_: int) -> float:
	var x := u * pu
	var y := v * pv
	var ix := int(floor(x))
	var iy := int(floor(y))
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := hash2(wrapi_(ix, pu), wrapi_(iy, pv), seed_)
	var b := hash2(wrapi_(ix + 1, pu), wrapi_(iy, pv), seed_)
	var c := hash2(wrapi_(ix, pu), wrapi_(iy + 1, pv), seed_)
	var d := hash2(wrapi_(ix + 1, pu), wrapi_(iy + 1, pv), seed_)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

static func fbm(u: float, v: float, pu: int, pv: int, octaves: int, seed_: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var norm := 0.0
	for o in octaves:
		sum += amp * vnoise(u, v, pu << o, pv << o, seed_ + o * 31)
		norm += amp
		amp *= 0.5
	return sum / norm

# Periodic Voronoi with cu x cv cells. Returns (F1, F2, id of the nearest feature point in 0..1, metric in cell units).
static func voronoi(u: float, v: float, cu: int, cv: int, seed_: int, jitter: float) -> Vector4:
	var x := u * cu
	var y := v * cv
	var ix := int(floor(x))
	var iy := int(floor(y))
	var f1 := 1e9
	var f2 := 1e9
	var id := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cx := ix + dx
			var cy := iy + dy
			var wx := wrapi_(cx, cu)
			var wy := wrapi_(cy, cv)
			var px := cx + 0.5 + (hash2(wx, wy, seed_) - 0.5) * jitter
			var py := cy + 0.5 + (hash2(wx, wy, seed_ + 77) - 0.5) * jitter
			var d := Vector2(px - x, py - y).length()
			if d < f1:
				f2 = f1
				f1 = d
				id = hash2(wx, wy, seed_ + 191)
			elif d < f2:
				f2 = d
	return Vector4(f1, f2, id, 0.0)

static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# Maps the 1st..99th percentile of a field to ~0.04..0.96 (so the histogram spans at least 0.1..0.9) and clamps.
static func normalise(f: PackedFloat32Array) -> void:
	var s := f.duplicate()
	s.sort()
	var lo: float = s[int(s.size() * 0.01)]
	var hi: float = s[int(s.size() * 0.99)]
	for i in f.size():
		f[i] = clampf(0.04 + 0.92 * (f[i] - lo) / maxf(hi - lo, 1e-6), 0.0, 1.0)

# Wrapped box blur (radius r, separable).
static func blur(f: PackedFloat32Array, n: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n * n)
	var out := PackedFloat32Array()
	out.resize(n * n)
	var inv := 1.0 / float(2 * r + 1)
	for y in n:
		for x in n:
			var s := 0.0
			for k in range(-r, r + 1):
				s += f[y * n + wrapi_(x + k, n)]
			tmp[y * n + x] = s * inv
	for y in n:
		for x in n:
			var s := 0.0
			for k in range(-r, r + 1):
				s += tmp[wrapi_(y + k, n) * n + x]
			out[y * n + x] = s * inv
	return out

# Packs height (0..1), occlusion (0..1) and a gradient gain into the RGBA8 layout.
static func pack(h: PackedFloat32Array, ao: PackedFloat32Array, n: int, gain: float) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var gx := (h[y * n + wrapi_(x + 1, n)] - h[y * n + wrapi_(x - 1, n)]) * 0.5
			var gy := (h[wrapi_(y + 1, n) * n + x] - h[wrapi_(y - 1, n) * n + x]) * 0.5
			var d := Vector2(-gx, -gy) * gain      # -grad(h) per texel, v down the rows
			if d.length() > 1.0:
				d = d.normalized()
			img.set_pixel(x, y, Color(0.5 + 0.5 * d.x, 0.5 + 0.5 * d.y, h[y * n + x], ao[y * n + x]))
	return img

static func bake_rock() -> Image:
	var n := ROCK_SIZE
	var h := PackedFloat32Array()
	h.resize(n * n)
	var crack := PackedFloat32Array()
	crack.resize(n * n)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			# Plates: wider than tall, cracks where F2 - F1 is small. Slight domain warp so edges are not straight.
			var wu := u + (vnoise(u, v, 6, 6, 5) - 0.5) * 0.03
			var wv := v + (vnoise(u, v, 6, 6, 6) - 0.5) * 0.03
			var vo := voronoi(wu, wv, 9, 15, 11, 0.9)
			var edge := vo.y - vo.x
			var cr := 1.0 - smooth(0.0, 0.16, edge)
			var plate := vo.z * 0.6 + smooth(0.0, 0.5, edge) * 0.4
			# Bedding: anisotropic fbm, 3 periods across and 14 down (long along u).
			var bed := fbm(u, v, 3, 14, 3, 21)
			var ledge := smooth(0.35, 0.65, vnoise(u, v, 2, 28, 33))      # sharp-ish horizontal ledges
			var bedding := bed * 0.6 + ledge * 0.4
			var grain := fbm(u, v, 48, 48, 2, 41)
			h[y * n + x] = 0.55 * plate + 0.30 * bedding + 0.15 * grain - 0.35 * cr
			crack[y * n + x] = cr
	normalise(h)
	var soft := blur(h, n, 6)
	var ao := PackedFloat32Array()
	ao.resize(n * n)
	for i in n * n:
		var cav := clampf((soft[i] - h[i]) * 3.0, 0.0, 1.0)
		ao[i] = clampf(1.0 - 0.75 * crack[i] - 0.5 * cav, 0.0, 1.0)
	return pack(h, ao, n, 6.0)

static func bake_scree() -> Image:
	var n := SCREE_SIZE
	var h := PackedFloat32Array()
	h.resize(n * n)
	var ao := PackedFloat32Array()
	ao.resize(n * n)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var big := voronoi(u, v, 6, 6, 101, 0.85)
			var small := voronoi(u, v, 17, 17, 202, 0.85)
			# Rounded stones: dome profile from F1; the gaps between them are sand (low).
			var stone_b := 1.0 - smooth(0.12, 0.62, big.x)
			var stone_s := 1.0 - smooth(0.15, 0.62, small.x)
			var gap_b := smooth(0.0, 0.2, big.y - big.x)
			var gap_s := smooth(0.0, 0.2, small.y - small.x)
			var height := 0.65 * stone_b * (0.55 + 0.45 * big.z) * gap_b + 0.3 * stone_s * (0.6 + 0.4 * small.z) * gap_s
			height += 0.05 * fbm(u, v, 24, 24, 2, 303)
			h[y * n + x] = height
			ao[y * n + x] = 0.35 + 0.65 * minf(gap_b, 1.0) * (0.4 + 0.6 * minf(1.0, gap_s + 0.3))
	normalise(h)
	return pack(h, ao, n, 5.0)

func _initialize() -> void:
	var rock := bake_rock()
	var scree := bake_scree()
	rock.save_png(ProjectSettings.globalize_path(ROCK_PATH))
	scree.save_png(ProjectSettings.globalize_path(SCREE_PATH))
	var args := OS.get_cmdline_user_args()
	var sheet_path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(SHEET_PATH)
	_sheet(rock, scree).save_png(sheet_path)
	print("baked ", ROCK_PATH, " and ", SCREE_PATH)
	quit()

# Preview: height, decoded normal-lit, occlusion, for each texture, tiled 2x2 for the rock to show seams.
static func _sheet(rock: Image, scree: Image) -> Image:
	var cell := 256
	var sheet := Image.create(cell * 4, cell * 2, false, Image.FORMAT_RGB8)
	var imgs := [rock, scree]
	for row in 2:
		var src: Image = imgs[row]
		var sn := src.get_width()
		for x in cell * 4:
			for y in cell:
				var col := x / cell
				var u := (x % cell) * 2   # 2x2 tiles per panel for a seam check
				var sx := (u % sn) if sn == ROCK_SIZE else (((x % cell) * 1) % sn)
				var sy := ((y * 2) % sn) if sn == ROCK_SIZE else (y % sn)
				var c := src.get_pixel(sx, sy)
				var out := Color.BLACK
				if col == 0:
					out = Color(c.b, c.b, c.b)
				elif col == 1:
					var d := Vector2(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0)
					var l := clampf(0.55 + 0.9 * (d.x * -0.6 + d.y * -0.8), 0.0, 1.0)
					out = Color(l, l, l)
				elif col == 2:
					out = Color(c.a, c.a, c.a)
				else:
					out = Color(c.r, c.g, 0.5)
				sheet.set_pixel(x, row * cell + y, out)
	return sheet
