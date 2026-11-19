extends Node
## Day and night (W8). The C world owns the clock (state().day.light, 0 night .. 1000 full day; 500 ticks an hour); this only
## dresses it: the sun's energy and colour, the ambient light and the exposure follow the light, smoothly. Inside the hidden
## cave the sun is off and the ambient nearly so; the cave's own cold lights do the rest.
const Look := preload("res://game/island/look.gd")
const DUSK := Color(1.0, 0.52, 0.30)
const MOON := Color(0.55, 0.68, 1.0)
const NIGHT_AMBIENT := Color(0.28, 0.36, 0.72)
var env: Environment
var sun: DirectionalLight3D
var k := 1.0           # smoothed light 0..1
var inside := 0.0      # smoothed 0..1, 1 inside the cave
var _light := 1.0
var _inside := 0.0
var force_light := -1.0   # tests and evidence: >= 0 overrides the C clock

func apply_state(state: Dictionary) -> void:
	_light = float(state.get("day", {}).get("light", 1000)) / 1000.0
	_inside = 1.0 if int(state.get("cave", {}).get("inside", 0)) > 0 else 0.0

func _process(delta: float) -> void:
	var target := _light if force_light < 0.0 else force_light
	k = lerpf(k, target, clampf(delta * 3.0, 0.0, 1.0))
	inside = lerpf(inside, _inside, clampf(delta * 5.0, 0.0, 1.0))
	update_now()

func update_now() -> void:
	if env == null or sun == null:
		return
	var warm: Color = Look.CREATURE_SUN_COLOR.lerp(DUSK, (1.0 - k) / 0.65) if k > 0.35 else DUSK.lerp(MOON, 1.0 - k / 0.35)
	var day := smoothstep(0.0, 0.8, k)
	sun.light_color = warm
	sun.light_energy = Look.CREATURE_SUN_ENERGY * lerpf(0.07, 1.0, day) * (1.0 - inside)
	env.ambient_light_color = NIGHT_AMBIENT.lerp(Look.CREATURE_AMBIENT_COLOR, day)
	env.ambient_light_energy = Look.CREATURE_AMBIENT_ENERGY * lerpf(0.30, 1.0, day) * lerpf(1.0, 0.3, inside)
	env.tonemap_exposure = Look.TONEMAP_EXPOSURE * lerpf(0.42, 1.0, day) * lerpf(1.0, 0.8, inside)
