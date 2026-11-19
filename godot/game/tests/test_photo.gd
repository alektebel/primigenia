extends RefCounted
# The photographic ground materials (rock_photo.gdshaderinc, textures/photo, textures/CREDITS.md): the two atlases are there and import as
# 8-layer Texture2DArrays, the mean-albedo constants of the shader are the means of the atlas tiles, every asset is credited, and the
# texture set stays small.

const DIR := "res://game/textures/photo/"
const LAYERS := ["ANDESITE", "STRATA", "BASALT", "TUFF", "SCREE", "TALUS", "SOIL", "SEDIMENT"]
const ASSETS := ["Rock048", "Rock022", "Rock050", "Rock061", "Gravel040", "Ground108", "Ground039", "Ground079S"]
const BUDGET_BYTES := 25 * 1024 * 1024

static func srgb_to_lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)

func run(t) -> void:
	for n in ["rock_albedo", "rock_pack"]:
		var tex = load(DIR + n + ".jpg")
		t.check(tex is TextureLayered, "%s imports as a layered texture (2D array)" % n)
		if tex is TextureLayered:
			t.eq(tex.get_layers(), 8, "%s has 8 layers" % n)
			t.eq(tex.get_width(), 1024, "%s layers are 1024 px" % n)
	# Mean linear albedo of each atlas tile against the constants the shader divides out.
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(DIR + "rock_albedo.jpg"))
	t.check(atlas != null and atlas.get_size() == Vector2i(4096, 2048), "the albedo atlas is 4096x2048")
	if atlas == null:
		return
	atlas.convert(Image.FORMAT_RGB8)
	var shader := FileAccess.get_file_as_string("res://game/shaders/rock_photo.gdshaderinc")
	var re := RegEx.new()
	for k in 8:
		re.compile("PH_MEAN_%s = vec3\\(([0-9.]+), ([0-9.]+), ([0-9.]+)\\)" % LAYERS[k])
		var m := re.search(shader)
		t.check(m != null, "PH_MEAN_%s is declared" % LAYERS[k])
		if m == null:
			continue
		var sum := Vector3.ZERO
		var cnt := 0
		var ox := (k % 4) * 1024
		var oy := (k / 4) * 1024
		for y in range(0, 1024, 4):
			for x in range(0, 1024, 4):
				var c := atlas.get_pixel(ox + x, oy + y)
				sum += Vector3(srgb_to_lin(c.r), srgb_to_lin(c.g), srgb_to_lin(c.b))
				cnt += 1
		sum /= float(cnt)
		var want := Vector3(m.get_string(1).to_float(), m.get_string(2).to_float(), m.get_string(3).to_float())
		t.check(maxf(absf(sum.x - want.x), maxf(absf(sum.y - want.y), absf(sum.z - want.z))) < 0.01, "PH_MEAN_%s matches its tile (%s vs %s)" % [LAYERS[k], sum, want])
	var credits := FileAccess.get_file_as_string("res://game/textures/CREDITS.md")
	for a in ASSETS:
		t.check(credits.contains(a) and credits.contains("ambientcg.com/a/" + a), "%s is credited with its URL" % a)
	t.check(credits.contains("CC0"), "CREDITS.md states the CC0 licence")
	var total := 0
	for f in ["rock_albedo.jpg", "rock_pack.jpg"]:
		total += FileAccess.get_file_as_bytes(DIR + f).size()
	t.check(total < BUDGET_BYTES, "the photographic textures weigh %.1f MB (< 25 MB)" % (total / 1048576.0))
