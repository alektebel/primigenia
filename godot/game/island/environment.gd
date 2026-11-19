extends RefCounted
# WorldEnvironment resource + sun for the island look (see 4.5 of the M0 plan).

const Look := preload("res://game/island/look.gd")
const SKY_SHADER := preload("res://game/shaders/sky.gdshader")

static func make_environment(exposure: float = Look.TONEMAP_EXPOSURE, white: float = Look.TONEMAP_WHITE) -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.CREATURE_AMBIENT_COLOR
	env.ambient_light_energy = Look.CREATURE_AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = exposure
	env.tonemap_white = white
	env.fog_enabled = false
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.adjustment_enabled = false
	RenderTier.apply_environment(env)   # no-op unless launched with --rendering-method forward_plus
	return env

static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Light travels along -SUN_DIR; Godot lights point along their -Z axis.
	sun.transform = Transform3D(Basis.looking_at(-Look.sun_dir(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Look.CREATURE_SUN_COLOR
	sun.light_energy = Look.CREATURE_SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.03          # creature_preview.gd values: low bodies (Babosa) must not float above their shadow
	sun.shadow_normal_bias = 0.6
	RenderTier.apply_sun(sun)
	return sun
