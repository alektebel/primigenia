extends SceneTree
# Image metrics for the rock evidence (PLAN-rock steps 3 to 7), headless:
#   godot --headless --path godot --script res://game/tests/rock_metrics.gd -- <command> <args>
#   autocorr <png>...                    ratio of the vertical to the horizontal autocorrelation length (luminance, 64x64 crop
#                                        at the centre, where the cliff views look)
#   rockdiff <before> <after> <mask>     mean RGB over the mask's rock pixels (R > 0.5): before, after, difference in 1/255
#   steepsnow <mask>...                  share of snow pixels (G) lying on faces steeper than 55 degrees (B)
#   cells <relief_cells.json> <png>...   luminance at the gully and ridge cells (9x9) against the 81x81 area around them
#   reliefstat <mode9> <mask> <png>...   mean luminance of rock pixels on concave, convex and flat relief (curvature maps from mode 9)
#   flicker <bandsA> <bandsB> <mask>     share of rock pixels (whole 11x11 neighbourhood in the mask) whose ramp band has no match
#                                        within 5 px in the frame taken after a 0.25 m camera move (mode 8 images)
#   bands <png> [x0 w y0 y1]             peaks of the row-averaged luminance profile inside a box (strata check)

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
		"cells":
			var js = JSON.parse_string(FileAccess.get_file_as_string(a[1]))
			for f in a.slice(2):
				var img := Image.load_from_file(f)
				var line := f.get_base_dir().get_file() + "/" + f.get_file()
				for key in ["gully", "ridge"]:
					line += "  %s lum %.3f (area mean %.3f, ratio %.2f)" % [key, cell_lum(img, js[key], 4), cell_lum(img, js[key], 40), cell_lum(img, js[key], 4) / maxf(cell_lum(img, js[key], 40), 1e-4)]
				print(line)
		"reliefstat":
			var m9 := Image.load_from_file(a[1])
			var mk := Image.load_from_file(a[2])
			for f in a.slice(3):
				var img := Image.load_from_file(f)
				var sums := [0.0, 0.0, 0.0]
				var cnt := [0, 0, 0]
				for y in img.get_height():
					for x in img.get_width():
						if mk.get_pixel(x, y).r < 0.5:
							continue
						var r9 := m9.get_pixel(x, y)
						var l := luma(img.get_pixel(x, y))
						var k := 0
						if r9.r > 0.62 or r9.g > 0.62:
							k = 1
						elif r9.r < 0.38 or r9.g < 0.38:
							k = 2
						sums[k] += l
						cnt[k] += 1
				print("%s rock px lum: flat %.3f (%d)  concave %.3f (%d)  convex %.3f (%d)  concave/flat %.2f  convex/flat %.2f" % [f.get_base_dir().get_file(), sums[0] / maxf(cnt[0], 1), cnt[0], sums[1] / maxf(cnt[1], 1), cnt[1], sums[2] / maxf(cnt[2], 1), cnt[2], sums[1] / maxf(cnt[1], 1) / (sums[0] / maxf(cnt[0], 1)), sums[2] / maxf(cnt[2], 1) / (sums[0] / maxf(cnt[0], 1))])
		"flicker":
			flicker(a[1], a[2], a[3])
		"bands":
			var box := [440, 600, 100, 620]
			if a.size() >= 6:
				box = [int(a[2]), int(a[3]), int(a[4]), int(a[5])]
			print("%s peaks %d" % [a[1].get_file(), bands(a[1], box[0], box[1], box[2], box[3])])
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

# Luminance averaged over the box columns (so facets and cracks cancel and only horizontal structure stays), 5 row smoothing, then
# local maxima that stand 0.008 above the profile 20 rows up and down. Counts the bands crossing a 40 m tall window.
static func bands(path: String, x0: int, wid: int, y_lo: int, y_hi: int) -> int:
	var img := Image.load_from_file(path)
	var prof := []
	for y in img.get_height():
		var s := 0.0
		for x in range(x0, x0 + wid, 3):
			s += luma(img.get_pixel(x, y))
		prof.append(s / float(wid / 3))
	var sm := []
	for y in prof.size():
		var s := 0.0
		var c := 0
		for k in range(-2, 3):
			if y + k >= 0 and y + k < prof.size():
				s += prof[y + k]
				c += 1
		sm.append(s / c)
	# High-pass: minus the 61-row mean, so the slow lit/shade and patch gradients drop out and only band-sized structure stays.
	var hp := []
	for y in sm.size():
		var s := 0.0
		var c := 0
		for k in range(-30, 31):
			if y + k >= 0 and y + k < sm.size():
				s += sm[y + k]
				c += 1
		hp.append(sm[y] - s / c)
	var peaks := 0
	var y := y_lo + 10
	while y < y_hi - 10:
		if hp[y] > 0.006 and hp[y] >= hp[y - 1] and hp[y] > hp[y + 1] and hp[y] > hp[y - 8] and hp[y] > hp[y + 8]:
			peaks += 1
			y += 12
		y += 1
	return peaks

static func flicker(pa: String, pb: String, pm: String) -> void:
	var a := Image.load_from_file(pa)
	var b := Image.load_from_file(pb)
	var m := Image.load_from_file(pm)
	var w := a.get_width()
	var h := a.get_height()
	var tested := 0
	var bad := 0
	var r := 5
	for y in range(r, h - r, 2):
		for x in range(r, w - r, 2):
			var inside := true
			for dy in [-r, 0, r]:
				for dx in [-r, 0, r]:
					if m.get_pixel(x + dx, y + dy).r < 0.5:
						inside = false
			if not inside:
				continue
			var ca := a.get_pixel(x, y)
			var key := Vector3(roundf(ca.r), roundf(ca.g), roundf(ca.b))
			var found := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cb := b.get_pixel(x + dx, y + dy)
					if Vector3(roundf(cb.r), roundf(cb.g), roundf(cb.b)) == key:
						found = true
						break
				if found:
					break
			tested += 1
			if not found:
				bad += 1
	print("flicker: %d of %d rock pixels (%.2f%%) changed ramp band beyond a 5 px shift" % [bad, tested, 100.0 * bad / maxf(tested, 1)])

static func cell_lum(img: Image, c: Dictionary, r: int) -> float:
	var s := 0.0
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := clampi(int(c.sx) + dx, 0, img.get_width() - 1)
			var y := clampi(int(c.sy) + dy, 0, img.get_height() - 1)
			s += luma(img.get_pixel(x, y))
			n += 1
	return s / n
