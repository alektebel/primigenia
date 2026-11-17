extends RefCounted
# The baked detail textures (PLAN-rock step 2): deterministic, tileable, sane histogram and normals, mipmapped lossless imports.

const Bake := preload("res://game/tools/bake_rock_detail.gd")

func _wrap_ratio(img: Image) -> float:
	var n := img.get_width()
	var edge := 0.0
	var inner := 0.0
	var cnt := 0
	for y in range(0, n, 2):
		for ch in 3:
			edge += absf(img.get_pixel(0, y)[ch] - img.get_pixel(n - 1, y)[ch]) + absf(img.get_pixel(y, 0)[ch] - img.get_pixel(y, n - 1)[ch])
			var x := (y * 7) % (n - 2) + 1
			inner += absf(img.get_pixel(x, y)[ch] - img.get_pixel(x + 1, y)[ch]) + absf(img.get_pixel(y, x)[ch] - img.get_pixel(y, x + 1)[ch])
		cnt += 1
	return edge / maxf(inner, 1e-9)

func run(t) -> void:
	var rock := Image.load_from_file(ProjectSettings.globalize_path(Bake.ROCK_PATH))
	var scree := Image.load_from_file(ProjectSettings.globalize_path(Bake.SCREE_PATH))
	t.check(rock != null and scree != null, "baked PNGs exist")
	if rock == null or scree == null:
		return
	t.eq(rock.get_size(), Vector2i(512, 512), "rock_detail is 512x512")
	t.eq(scree.get_size(), Vector2i(256, 256), "scree_detail is 256x256")
	t.eq(rock.get_format(), Image.FORMAT_RGBA8, "rock_detail is RGBA8")
	var names := {"rock": rock, "scree": scree}
	for k in names:
		var img: Image = names[k]
		t.check(_wrap_ratio(img) <= 1.5, "%s tiles: wrap-edge difference <= 1.5x the interior neighbour difference (got %.2f)" % [k, _wrap_ratio(img)])
		var hist := PackedInt32Array()
		hist.resize(100)
		var max_len := 0.0
		var n := img.get_width()
		for y in n:
			for x in n:
				var c := img.get_pixel(x, y)
				hist[mini(99, int(c.b * 100.0))] += 1
				max_len = maxf(max_len, Vector2(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0).length())
		var total := 0
		var lo := -1
		var hi := -1
		for b in 100:
			total += hist[b]
			if lo < 0 and total >= n * n / 50:
				lo = b
			if hi < 0 and total >= n * n * 49 / 50:
				hi = b
		t.check(lo <= 10 and hi >= 89, "%s height spans 0.1..0.9 (2nd..98th percentile bins %d..%d)" % [k, lo, hi])
		t.check(max_len <= 1.02, "%s decoded normals have |d| <= 1 (max %.3f)" % [k, max_len])
	# Determinism: baking again reproduces the committed pixels exactly.
	t.check(Bake.bake_rock().get_data() == rock.get_data(), "rock_detail re-bakes byte-identically")
	t.check(Bake.bake_scree().get_data() == scree.get_data(), "scree_detail re-bakes byte-identically")
	for path in [Bake.ROCK_PATH, Bake.SCREE_PATH]:
		var imp := FileAccess.get_file_as_string(path + ".import")
		t.check(imp.contains("mipmaps/generate=true"), path.get_file() + " imports with mipmaps")
		t.check(imp.contains("compress/mode=0"), path.get_file() + " imports lossless")
		t.check(imp.contains("compress/normal_map=2"), path.get_file() + " is not imported as a normal map")
