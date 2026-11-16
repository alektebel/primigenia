extends RefCounted
# look.gd and the shader constants are the same numbers (a drift here changes the look silently).

const Look := preload("res://game/island/look.gd")

func _consts(path: String) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile("const (?:vec3|float) (\\w+) = (?:vec3\\()?([-0-9.,\\s]+)\\)?;")
	for m in re.search_all(FileAccess.get_file_as_string(path)):
		var nums := []
		for part in m.get_string(2).split(","):
			nums.append(part.strip_edges().to_float())
		out[m.get_string(1)] = nums
	return out

func _near(a: Array, v: Vector3) -> bool:
	return absf(a[0] - v.x) < 1e-6 and absf(a[1] - v.y) < 1e-6 and absf(a[2] - v.z) < 1e-6

func run(t) -> void:
	var inc := _consts("res://game/shaders/look.gdshaderinc")
	var sky := _consts("res://game/shaders/sky.gdshader")
	var sd := Look.sun_dir()
	t.check(absf(inc.SUN_DIR[0] - sd.x) < 1e-6 and absf(inc.SUN_DIR[1] - sd.y) < 1e-6 and absf(inc.SUN_DIR[2] - sd.z) < 1e-6, "SUN_DIR matches")
	var pairs := {"AIR_COOL": Look.AIR_COOL, "AIR_WARM": Look.AIR_WARM}
	for k in pairs:
		var v: Vector3 = pairs[k]
		t.check(_near(inc[k], v), k + " matches")
	t.eq(inc.AIR_DENSITY[0], Look.AIR_DENSITY, "AIR_DENSITY")
	t.eq(inc.AIR_START[0], Look.AIR_START, "AIR_START")
	t.eq(inc.AIR_FALLOFF[0], Look.AIR_FALLOFF, "AIR_FALLOFF")
	var skies := {"SKY_HZ": Look.SKY_HZ, "SKY_MID": Look.SKY_MID, "SKY_TOP": Look.SKY_TOP, "SKY_GLOW": Look.SKY_GLOW}
	for k in skies:
		var v: Vector3 = skies[k]
		t.check(_near(sky[k], v), k + " matches")
	t.check(_near(inc.HORIZON_HZ, Look.SKY_HZ) and _near(inc.HORIZON_GLOW, Look.SKY_GLOW), "the horizon colour of the sea fade equals the sky's")
	t.check(absf(sd.length() - 1.0) < 1e-9, "sun direction is normalised")
	t.check(absf(Look.TONEMAP_EXPOSURE - 0.926) < 1e-9 and absf(Look.TONEMAP_WHITE - 15.4) < 1e-9, "calibrated tone-map constants")
