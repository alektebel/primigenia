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
	# Rock constants (rock.gdshaderinc) mirror look.gd.
	var rock := _consts("res://game/shaders/rock.gdshaderinc")
	var script: GDScript = Look
	var seen := 0
	t.check(_near(rock.ROCK_RIM_TINT, Look.SKY_MID), "ROCK_RIM_TINT is the sky's SKY_MID")
	rock.erase("ROCK_RIM_TINT")
	for k in rock:
		if script.get_script_constant_map().has(k):
			seen += 1
			t.check(absf(float(rock[k][0]) - float(script.get_script_constant_map()[k])) < 1e-6, k + " matches look.gd")
		else:
			t.check(false, k + " is missing from look.gd")
	t.check(seen >= 20, "the rock constants were compared (%d)" % seen)
	# The rock ceiling is 1.2 x the brightest channel of the lit snow (no new HDR maximum).
	var snow_lit: Vector3 = Look.SNOW * (0.6 + 0.25 + 0.23) * Look.GRASS
	t.check(Look.ROCK_MAX <= 1.2 * maxf(snow_lit.x, maxf(snow_lit.y, snow_lit.z)) + 1e-6, "ROCK_MAX <= 1.2 x lit snow (%.3f)" % Look.ROCK_MAX)
	_world_light(t)

# One light for the whole world (WL1): the lit tiers keep the shadow-receiving shaders, low falls back to unshaded, and the shadow
# colour of the real shadow map is the fake one it replaces (SH_K * S_TINT, land.gdshaderinc).
func _world_light(t) -> void:
	var WorldLight := preload("res://game/island/world_light.gd")
	var land := _consts("res://game/shaders/land.gdshaderinc")
	var wl := FileAccess.get_file_as_string("res://game/shaders/world_light.gdshaderinc")
	var m := RegEx.create_from_string("vec3\\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\\)").search(wl.substr(wl.find("WORLD_SHADOW_TINT")))
	var k: float = land.SH_K[0]
	var st: Array = land.S_TINT
	t.check(m != null and absf(m.get_string(1).to_float() - k * st[0]) < 1e-4 and absf(m.get_string(2).to_float() - k * st[1]) < 1e-4 and absf(m.get_string(3).to_float() - k * st[2]) < 1e-4, "WORLD_SHADOW_TINT = SH_K * S_TINT")
	for name in ["terrain_medium", "terrain_high", "grass", "water", "river"]:
		var base: Shader = load("res://game/shaders/%s.gdshader" % name)
		t.check(base.code.contains("ambient_light_disabled") and base.code.contains("#define WORLD_LIT") and not base.code.contains("unshaded"), name + " is written lit")
		t.check(WorldLight.shader_for(base, 2) == base and WorldLight.shader_for(base, 3) == base, name + ": medium and high use it as is")
		var low: Shader = WorldLight.shader_for(base, 1)
		t.check(low.code.contains("unshaded") and not low.code.contains("WORLD_LIT") and not low.code.contains("ambient_light_disabled"), name + ": low is unshaded")
	t.check(load("res://game/shaders/terrain_low.gdshader").code.contains("unshaded"), "terrain_low stays unshaded")
	var sun := DirectionalLight3D.new()
	WorldLight.configure_sun(sun, 3)
	t.check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and sun.directional_shadow_max_distance == 200.0, "high: 4 cascades to 200 m")
	WorldLight.configure_sun(sun, 2)
	t.check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and sun.directional_shadow_max_distance == 120.0, "medium: 2 cascades to 120 m")
	t.check(not WorldLight.lit(1) and WorldLight.lit(2) and WorldLight.lit(3), "only low is unlit")
	sun.free()
