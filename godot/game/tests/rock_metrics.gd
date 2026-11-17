extends SceneTree
# Image metrics for the rock evidence (PLAN-rock steps 3 to 7), headless:
#   godot --headless --path godot --script res://game/tests/rock_metrics.gd -- <command> <args>
#   autocorr <png>...                    ratio of the vertical to the horizontal autocorrelation length (luminance, 64x64 crop
#                                        at the centre, where the cliff views look)
#   rockdiff <before> <after> <mask>     mean RGB over the mask's rock pixels (R > 0.5): before, after, difference in 1/255
#   steepsnow <mask>...                  share of snow pixels (G) lying on faces steeper than 55 degrees (B)
#   bands <png>                          peaks of the luminance profile along a vertical line at the centre (strata check)

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("usage: see the header of rock_metrics.gd")
		quit(2)
		return
	match a[0]:
		"autocorr":
			for f in a.slice(1):
				var r := autocorr(f)
				print("%s autocorr length v %.2f h %.2f ratio %.2f" % [f.get_file(), r[0], r[1], r[0] / maxf(r[1], 0.01)])
		"rockdiff":
			rockdiff(a[1], a[2], a[3])
		"steepsnow":
			for f in a.slice(1):
				var m := Image.load_from_file(f)
				var snow := 0
				var steep := 0
				for y in m.get_height():
					for x in m.get_width():
						var c := m.get_pixel(x, y)
						if c.g > 0.5:
							snow += 1
							if c.b > 0.5:
								steep += 1
				print("%s snow px %d, on steep faces %d (%.1f%%)" % [f.get_file(), snow, steep, 100.0 * steep / maxf(snow, 1)])
		"bands":
			print("%s peaks %d" % [a[1].get_file(), bands(a[1])])
	quit()

static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

# The luminance is high-passed first (minus its 17x17 box mean), so a gully shadow or a lit/shade edge crossing the crop does
# not count as texture; what is measured is the fine structure (streaks, plates, pebbles).
static func autocorr(path: String, size: int = 64) -> Array:
	var img := Image.load_from_file(path)
	var x0 := img.get_width() / 2 - size / 2
	var y0 := img.get_height() / 2 - size / 2
	var pad := 8
	var big := size + 2 * pad
	var lum := PackedFloat32Array()
	for y in big:
		for x in big:
			lum.append(luma(img.get_pixel(x0 - pad + x, y0 - pad + y)))
	var v := PackedFloat32Array()
	var mean := 0.0
	for y in size:
		for x in size:
			var s := 0.0
			for dy in range(-pad, pad + 1):
				for dx in range(-pad, pad + 1):
					s += lum[(y + pad + dy) * big + x + pad + dx]
			var l := lum[(y + pad) * big + x + pad] - s / float((2 * pad + 1) * (2 * pad + 1))
			v.append(l)
			mean += l
	mean /= size * size
	for i in v.size():
		v[i] -= mean
	var var0 := 0.0
	for i in v.size():
		var0 += v[i] * v[i]
	var0 = maxf(var0, 1e-9)
	var out := []
	for vertical in [true, false]:
		var length := float(size / 2)
		var prev := 1.0
		for lag in range(1, size / 2):
			var s := 0.0
			var cnt := 0
			for y in size:
				for x in size:
					var yy := y + lag if vertical else y
					var xx := x if vertical else x + lag
					if yy < size and xx < size:
						s += v[y * size + x] * v[yy * size + xx]
						cnt += 1
			var ac := s / var0 * float(size * size) / maxf(cnt, 1)
			if ac < 0.5:
				length = lag - 1 + (prev - 0.5) / maxf(prev - ac, 1e-6)
				break
			prev = ac
		out.append(length)
	return out

static func rockdiff(before: String, after: String, mask: String) -> void:
	var b := Image.load_from_file(before)
	var a := Image.load_from_file(after)
	var m := Image.load_from_file(mask)
	var sb := Vector3.ZERO
	var sa := Vector3.ZERO
	var n := 0
	for y in m.get_height():
		for x in m.get_width():
			if m.get_pixel(x, y).r > 0.5:
				var cb := b.get_pixel(x, y)
				var ca := a.get_pixel(x, y)
				sb += Vector3(cb.r, cb.g, cb.b)
				sa += Vector3(ca.r, ca.g, ca.b)
				n += 1
	sb /= maxf(n, 1)
	sa /= maxf(n, 1)
	var d := (sa - sb) * 255.0
	print("rock px %d  before %s  after %s  diff(/255) %.1f %.1f %.1f" % [n, str((sb * 255).round()), str((sa * 255).round()), d.x, d.y, d.z])

static func bands(path: String) -> int:
	var img := Image.load_from_file(path)
	var x := img.get_width() / 2
	var prof := []
	for y in img.get_height():
		var s := 0.0
		for dx in range(-2, 3):
			s += luma(img.get_pixel(x + dx, y))
		prof.append(s / 5.0)
	var sm := []
	for y in prof.size():
		var s := 0.0
		var c := 0
		for k in range(-3, 4):
			if y + k >= 0 and y + k < prof.size():
				s += prof[y + k]
				c += 1
		sm.append(s / c)
	var peaks := 0
	for y in range(8, sm.size() - 8):
		if sm[y] > sm[y - 6] + 0.012 and sm[y] > sm[y + 6] + 0.012 and sm[y] >= sm[y - 1] and sm[y] > sm[y + 1]:
			peaks += 1
	return peaks
