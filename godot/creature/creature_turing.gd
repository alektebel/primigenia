class_name CreatureTuring
extends RefCounted
## Turing pattern from a genome seed, built in a few ms on the CPU: a tileable N x N activator-inhibitor field
## (Young 1984: short-range activation, long-range inhibition, wrapped box blurs, saturating update), the
## discrete cousin of a Gierer-Meinhardt reaction-diffusion system. It settles into spots, stripes or labyrinths
## with a wavelength fixed in cells; the skin shader maps the texture at a physical scale relative to body size.
## Deterministic: the same seed and kind give the same bytes. Textures are cached per (seed, kind).
##
## Kinds: 1 stripes, 2 spots, 3 blotches. Anything else is a soft mottle (no hard pattern).

const N := 48

static var _cache := {}
static var last_ms := 0.0           ## time of the last uncached build (evidence/tests)

## Cells per wavelength of each kind is about 2 * inhibitor radius; used by the shader scale.
const WAVELENGTH_CELLS := 9.0


static func texture(seed_: int, kind: int) -> ImageTexture:
	var key := "%d:%d" % [seed_, kind]
	if _cache.has(key):
		return _cache[key]
	var t0 := Time.get_ticks_usec()
	var tex := ImageTexture.create_from_image(image(seed_, kind))
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_cache[key] = tex
	return tex


static func image(seed_: int, kind: int) -> Image:
	var f := field(seed_, kind)
	var bytes := PackedByteArray()
	bytes.resize(N * N)
	for i in N * N:
		bytes[i] = clampi(int((f[i] * .5 + .5) * 255.0), 0, 255)
	var img := Image.create_from_data(N, N, false, Image.FORMAT_L8, bytes)
	img.generate_mipmaps()
	return img


## Field in [-1, 1].
static func field(seed_: int, kind: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 2654435761 + kind * 40503 + 17
	var x := PackedFloat32Array()
	x.resize(N * N)
	for i in N * N:
		x[i] = rng.randf() - .5
	var tmp := PackedFloat32Array()
	tmp.resize(N * N)
	var b := PackedFloat32Array()
	b.resize(N * N)
	# Short-range activation (box blur radius ra) against long-range inhibition (radius rix along u, riy along v).
	# riy > rix elongates the pattern along v, which the shader maps around the body: stripes are rings, not
	# lengthwise lines. `drift` pushes the background down so the minority phase grows isolated spots; 0 gives the
	# balanced labyrinth.
	var ra := 2
	var rix := 5
	var riy := 5
	var drift := 0.0
	var iters := 16
	var rate := .5
	match kind:
		1:
			ra = 1
			rix = 3
			riy = 10
		2:
			ra = 1
			rix = 4
			riy = 4
			drift = .14
		3:
			ra = 3
			rix = 8
			riy = 8
			drift = .05
	var a := PackedFloat32Array()
	a.resize(N * N)
	for it in iters:
		_blur(x, tmp, a, ra, ra)
		_blur(x, tmp, b, rix, riy)
		for i in N * N:
			var v: float = x[i] + rate * (a[i] - b[i]) - drift * (1.0 - x[i] * x[i])
			if v > 1.0:
				v = 1.0
			elif v < -1.0:
				v = -1.0
			x[i] = v
	# Stretch the contrast so the thresholds of the shader are stable across seeds.
	var lo := 1.0
	var hi := -1.0
	for i in N * N:
		lo = minf(lo, x[i])
		hi = maxf(hi, x[i])
	var span := maxf(hi - lo, 1e-4)
	for i in N * N:
		x[i] = (x[i] - lo) / span * 2.0 - 1.0
	return x


## Wrapped separable box blur of radius r (running sums, wrap by compare instead of modulo).
static func _blur(src: PackedFloat32Array, tmp: PackedFloat32Array, dst: PackedFloat32Array, rx: int, ry: int) -> void:
	var r := rx
	var inv := 1.0 / (2 * r + 1)
	for y in N:
		var row := y * N
		var s := 0.0
		for k in range(-r, r + 1):
			s += src[row + (k + N if k < 0 else k)]
		for xx in N:
			tmp[row + xx] = s * inv
			var hi := xx + r + 1
			var lo := xx - r
			s += src[row + (hi - N if hi >= N else hi)] - src[row + (lo + N if lo < 0 else lo)]
	r = ry
	inv = 1.0 / (2 * r + 1)
	for xx in N:
		var s := 0.0
		for k in range(-r, r + 1):
			s += tmp[(k + N if k < 0 else k) * N + xx]
		for y in N:
			dst[y * N + xx] = s * inv
			var hi := y + r + 1
			var lo := y - r
			s += tmp[(hi - N if hi >= N else hi) * N + xx] - tmp[(lo + N if lo < 0 else lo) * N + xx]
