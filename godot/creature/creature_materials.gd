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

## The realism pilot (docs/godot/CREATURE-REALISM.md): false (env CPORE_REALISM=0, or set before building) renders the
## pre-pilot look, for before/after pictures and as a quality escape hatch.
static var realism := OS.get_environment("CPORE_REALISM") != "0"

var skin: ShaderMaterial
var skin_body: ShaderMaterial       ## the skinned body tube: same shader, UV-mapped pattern and actuation on
var limb_mats: Array = []           ## per-leg-segment copies of skin (flex uniform), rebuilt with each creature
var bio: Dictionary = {}
var skin2: ShaderMaterial
var membrane: ShaderMaterial
var glider: ShaderMaterial
var insect: ShaderMaterial
var sac: ShaderMaterial
var bone: ShaderMaterial          ## keratin.gdshader kinds: horn / bone, tooth, beak
var tooth: ShaderMaterial
var beak: ShaderMaterial
var eye_white: StandardMaterial3D
var iris: ShaderMaterial          ## eye_iris.gdshader, default pupil of the creature; iris_for() gives the other shapes
var cornea: StandardMaterial3D     ## wet transparent bulge over the iris
var _iris_by_kind := {}
var pupil: StandardMaterial3D
var dark: ShaderMaterial
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
	skin_body = _skin_mat("skin", 1.0, .94)
	skin_body.set_shader_parameter("use_uv", 1.0)
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
	bone = _keratin(0.0, "#bfae8a", "#4a3822", "#cdbf9c", .5)
	tooth = _keratin(1.0, "#f7f1df", "#6d5a3a", "#e6dcc0", .8)
	beak = _keratin(2.0, "#d9952f", "#5a3512", "#d6a04a", .9)
	# Wet, specular eyes: veined cream sclera, a radial iris (own shader), a glossy cornea bulge over it.
	if realism:
		eye_white = phys("#cdbf9f", .12, 1)
		eye_white.clearcoat_roughness = .03
		pupil = phys("#030303", .05, 1)
		pupil.clearcoat_roughness = .02
	else:
		eye_white = phys("#f4efe6", .08, 1)
		pupil = phys("#050505", .05, 1)
	iris = _iris("round")
	cornea = StandardMaterial3D.new()
	cornea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cornea.albedo_color = Color(1, 1, 1, .07)
	cornea.roughness = .02
	cornea.metallic_specular = 1.0
	cornea.clearcoat_enabled = true
	cornea.clearcoat = 1.0
	cornea.clearcoat_roughness = .01
	cornea.render_priority = 3
	dark = _keratin(0.0, "#1a1210", "#150e0a", "#4a392b", .7)   # chitin / dark horn: keratin shader, dark palette
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


func _keratin(kind: float, flat_hex: String, root_hex: String, tip_hex: String, gloss: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("keratin")
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("flat_col", Color(flat_hex))
	m.set_shader_parameter("root_col", Color(root_hex))
	m.set_shader_parameter("tip_col", Color(tip_hex))
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("realism", 1.0 if realism else 0.0)
	return m


func _iris(kind: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("eye_iris")
	m.set_shader_parameter("pupil_kind", {"round": 0.0, "slit": 1.0, "bar": 2.0}[kind])
	m.set_shader_parameter("realism", 1.0 if realism else 0.0)
	return m


## Iris material of a pupil shape ("round", "slit", "bar"), shared by the eyes of one creature.
func iris_for(kind: String) -> ShaderMaterial:
	if not _iris_by_kind.has(kind):
		var m := _iris(kind)
		m.set_shader_parameter("col_in", iris.get_shader_parameter("col_in"))
		m.set_shader_parameter("col_out", iris.get_shader_parameter("col_out"))
		m.set_shader_parameter("seed", iris.get_shader_parameter("seed"))
		_iris_by_kind[kind] = m
	return _iris_by_kind[kind]


func skin_materials() -> Array:
	return [skin, skin_body, skin2, membrane, glider, insect, sac] + limb_mats


## A copy of the skin for one limb segment: part 1 upper leg, 2 lower leg. Carries its own flex uniform.
func limb_material(part: int, seg_len: float, mode: float = 1.0) -> ShaderMaterial:
	var m: ShaderMaterial = skin.duplicate()
	m.set_shader_parameter("leg_mode", mode)
	m.set_shader_parameter("leg_part", float(part))
	m.set_shader_parameter("seg_len", seg_len)
	limb_mats.append(m)
	return m


## rig.js load(): palette, pattern, wetness. Clearcoat follows wetness. With the realism pilot the palette is graded
## (CreatureBio.palette returns the player colours untouched).
func set_skin(s: Dictionary) -> void:
	var pal := {"cA": Color(s["cA"]), "cB": Color(s["cB"]), "cC": Color(s["cC"])}
	if realism and not bio.is_empty():
		pal = CreatureBio.palette(s, float(bio["toxic"]), String(bio["diet"]), float(s["wet"]))
	for m in skin_materials():
		m.set_shader_parameter("cA", pal["cA"])
		m.set_shader_parameter("cB", pal["cB"])
		m.set_shader_parameter("cC", pal["cC"])
		m.set_shader_parameter("uPat", float(s["pat"]))
		m.set_shader_parameter("uWet", float(s["wet"]))
		m.set_shader_parameter("uScale", float(s["scale"]))
		m.set_shader_parameter("realism", 1.0 if realism else 0.0)
	# Creator controls (optional genome keys): countershading, pattern scale / contrast, rosettes.
	var kind := int(s["pat"])
	var br := float(bio.get("body_r", .6)) if not bio.is_empty() else .6
	var sd: int = int(bio.get("seed", 0)) if not bio.is_empty() else 0
	var wl: float = br * [0.0, .5, .42, 1.3][kind] * (.85 + .3 * float(sd % 7) / 6.0) * float(s.get("ps", 1.0))
	for m in skin_materials():
		m.set_shader_parameter("cs", float(s.get("cs", .5)))
		m.set_shader_parameter("pc", float(s.get("pc", 1.0)))
		m.set_shader_parameter("tur_ros", float(s.get("ros", 0)))
		m.set_shader_parameter("tur_tile", maxf(wl * 6.0, .05))
	var wet_cc := float(s["wet"]) * .8
	for m in [skin, skin_body, skin2] + limb_mats:
		m.set_shader_parameter("clearcoat_amount", wet_cc)
	membrane.set_shader_parameter("clearcoat_amount", float(s["wet"]) * .12)
	# Horns and claws take a trace of the skin so they belong to the animal.
	var a: Color = pal["cA"]
	for m in [bone, tooth, beak, dark]:
		m.set_shader_parameter("realism", 1.0 if realism else 0.0)
	var tint := Color(a.r, a.g, a.b)
	bone.set_shader_parameter("root_col", Color("#4a3822").lerp(tint, .18))
	bone.set_shader_parameter("tip_col", Color("#cdbf9c").lerp(tint, .06))
	beak.set_shader_parameter("root_col", Color("#5a3512").lerp(tint, .1))


## Per-creature biology (CreatureBio.derive): pattern texture and scale, actuation, detail relative to body size.
func configure(b: Dictionary, genome_skin: Dictionary) -> void:
	bio = b
	limb_mats.clear()
	_iris_by_kind.clear()
	var tints := [[Color(.78, .5, .1), Color(.45, .26, .05)], [Color(.72, .72, .2), Color(.3, .38, .06)], [Color(.85, .38, .06), Color(.42, .14, .03)], [Color(.5, .32, .14), Color(.22, .12, .05)]]
	var tint: Array = tints[int(b["seed"]) % 4]
	iris.set_shader_parameter("col_in", tint[0])
	iris.set_shader_parameter("col_out", tint[1])
	iris.set_shader_parameter("seed", float(int(b["seed"]) % 97))
	iris.set_shader_parameter("pupil_kind", {"round": 0.0, "slit": 1.0, "bar": 2.0}[b["pupil"]])
	var mode: float = {"muscle": 1.0, "hydraulic": 2.0, "exo": 3.0, "hydrostatic": 4.0}[b["actuation"]]
	var kind := int(b["pat"])
	var seed_: int = b["seed"]
	var tex: Texture2D = null
	if realism and kind >= 1 and kind <= 3:
		tex = CreatureTuring.texture(seed_, kind)
	var br: float = b["body_r"]
	# Wavelength in metres from the body size (stripes finer than blotches), a little seed jitter; one texture tile is
	# 6 wavelengths because the field holds about that many.
	var wr: float = {"muscle": .35, "hydraulic": .12, "exo": 0.0, "hydrostatic": .9}[b["actuation"]]
	var scales: float = {"muscle": 1.0, "hydraulic": .8, "exo": .35, "hydrostatic": .25}[b["actuation"]]
	for m in skin_materials():
		m.set_shader_parameter("turing", tex)
		m.set_shader_parameter("tur_kind", float(kind) if tex != null else 0.0)
		m.set_shader_parameter("body_r", br)
		m.set_shader_parameter("act_mode", mode)
		m.set_shader_parameter("wrinkle", wr)
		m.set_shader_parameter("scale_amt", scales)
		m.set_shader_parameter("act_phase", float(seed_ % 628) / 100.0)
	set_skin(genome_skin)


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
