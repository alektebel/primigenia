class_name CreatureMaterials
extends RefCounted
## One set of materials per creature (the skin palette is per creature).
## Mirrors the materials in web/creature/rig.js:
##   skin / skin2 (double-sided)  -> skin.gdshader / skin_double.gdshader
##   membrane, glider, insect, sac -> membrane*.gdshader (backlit thin tissue)
##   bone (keratin), tooth, beak, eye_white, iris, pupil, dark -> StandardMaterial3D
##   glow -> unshadowed emissive StandardMaterial3D
## Region names used by parts: skin, keratin, membrane, glow, eye, iris, dark.

const SHADER_DIR := "res://creature/shaders/"

var skin: ShaderMaterial
var skin2: ShaderMaterial
var membrane: ShaderMaterial
var glider: ShaderMaterial
var insect: ShaderMaterial
var sac: ShaderMaterial
var bone: StandardMaterial3D
var tooth: StandardMaterial3D
var beak: StandardMaterial3D
var eye_white: StandardMaterial3D
var iris: StandardMaterial3D
var pupil: StandardMaterial3D
var dark: StandardMaterial3D
var glow: StandardMaterial3D

static var _shaders := {}


static func _shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load(SHADER_DIR + name + ".gdshader")
	return _shaders[name]


static func phys(hex: String, rough: float, cc: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = 0.0
	m.clearcoat_enabled = cc > 0
	m.clearcoat = cc
	m.clearcoat_roughness = .2
	return m


func _init() -> void:
	skin = _skin_mat("skin", 1.0, .94)
	skin2 = _skin_mat("skin_double", 1.0, .94)
	membrane = _skin_mat("membrane", .82, .94)
	membrane.set_shader_parameter("clearcoat_amount", 0.0)
	membrane.set_shader_parameter("clearcoat_rough", 1.0)
	glider = _skin_mat("membrane_glider", .9, .8)
	insect = _skin_mat("membrane_insect", .48, .42)
	insect.set_shader_parameter("clearcoat_amount", .65)
	sac = _skin_mat("membrane_sac", .74, .48)
	for m in [glider, sac]:
		m.set_shader_parameter("clearcoat_amount", .3)
	# Transparent membranes draw after the opaque body.
	membrane.render_priority = 1
	glider.render_priority = 1
	sac.render_priority = 1
	insect.render_priority = 2
	bone = phys("#bfae8a", .5, .25)
	tooth = phys("#f7f1df", .28, .5)
	beak = phys("#d9952f", .35, .6)
	eye_white = phys("#f4efe6", .08, 1)
	iris = phys("#e8a41c", .2, 1)
	iris.emission_enabled = true
	iris.emission = Color("#6a3a00")
	pupil = phys("#050505", .05, 1)
	dark = phys("#1a1210", .5, .2)
	glow = StandardMaterial3D.new()
	glow.albedo_color = Color("#7fe8ff")
	glow.emission_enabled = true
	glow.emission = Color("#35c8ff")
	glow.emission_energy_multiplier = 2.2
	glow.roughness = .3


func _skin_mat(shader: String, opacity: float, rough: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(shader)
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("membrane_roughness", rough)
	return m


func skin_materials() -> Array:
	return [skin, skin2, membrane, glider, insect, sac]


## rig.js load(): palette, pattern, wetness. Clearcoat follows wetness.
func set_skin(s: Dictionary) -> void:
	for m in skin_materials():
		m.set_shader_parameter("cA", Color(s["cA"]))
		m.set_shader_parameter("cB", Color(s["cB"]))
		m.set_shader_parameter("cC", Color(s["cC"]))
		m.set_shader_parameter("uPat", float(s["pat"]))
		m.set_shader_parameter("uWet", float(s["wet"]))
		m.set_shader_parameter("uScale", float(s["scale"]))
	skin.set_shader_parameter("clearcoat_amount", float(s["wet"]) * .8)
	skin2.set_shader_parameter("clearcoat_amount", float(s["wet"]) * .8)
	membrane.set_shader_parameter("clearcoat_amount", float(s["wet"]) * .12)


## World direction towards the sun, used by the membrane backlight.
func set_sun_direction(dir: Vector3) -> void:
	for m in skin_materials():
		m.set_shader_parameter("sun_dir", dir.normalized())


## rig.js tissue(): region -> material.
func for_region(region: String) -> Material:
	match region:
		"skin": return skin
		"keratin": return bone
		"membrane": return membrane
		"glow": return glow
		"eye": return pupil
		"iris": return iris
		"dark": return dark
	return skin


func by_name(name: String) -> Material:
	return get(name)
