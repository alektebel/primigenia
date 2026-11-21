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
var force_hour := -1.0    # tests and evidence: >= 0 overrides the C clock's hour (sun position)
var _hour := 12.5

# The world's light (LOOK 3, D-25). Every world shader reads these globals (project.godot [shader_globals]); this node is the one
# source. All keys are STARTING VALUES checked by the visual scorecard (docs/evidence/look/world-light.md); references to match:
# Wikimedia Commons volcanic-island photos (Galapagos, Hawai'i: warm low sun with long shadows, pale neutral noon, blue-grey moonlit dusk).
const SUNRISE := 6.0     # the C clock: light 0.5 at 06:00 and 19:00 (stage_secrets.c), noon at 12:30
const SUNSET := 19.0
const SUN_MAX_DEG := 52.0
const MID_AZ := Vector3(-0.6259115, 0.0, -0.7268649)   # horizontal direction of the sun at noon (the old fixed sun's azimuth)
# key colours: low sun (dawn, dusk), full day, night. sun_color is the multiplier on the world's linear colour.
const K_SUN := {"low": Vector3(1.32, 0.80, 0.46), "day": Vector3(1.0, 1.0, 1.0), "night": Vector3(0.30, 0.40, 0.64)}
const K_ZENITH := {"low": Vector3(0.24, 0.27, 0.55), "day": Vector3(0.13, 0.39, 0.84), "night": Vector3(0.03, 0.05, 0.12)}   # low: slight off-Earth violet
const K_MID := {"low": Vector3(0.62, 0.50, 0.66), "day": Vector3(0.52, 0.70, 0.93), "night": Vector3(0.05, 0.08, 0.17)}
const K_HORIZON := {"low": Vector3(1.0, 0.66, 0.48), "day": Vector3(0.95, 0.84, 0.70), "night": Vector3(0.08, 0.11, 0.20)}
const K_GLOW := {"low": Vector3(1.0, 0.48, 0.22), "day": Vector3(1.0, 0.62, 0.30), "night": Vector3(0.0, 0.0, 0.0)}
const K_FOG := {"low": Vector3(0.72, 0.60, 0.66), "day": Vector3(0.34, 0.58, 0.88), "night": Vector3(0.06, 0.09, 0.17)}
const K_AMBIENT := {"low": Vector3(0.0, 0.0, 0.0), "day": Vector3(0.0, 0.0, 0.0), "night": Vector3(0.0035, 0.0055, 0.011)}

## Sun elevation in degrees for an hour 0..24 (negative below the horizon).
static func sun_elevation(hour: float) -> float:
	var u := (hour - SUNRISE) / (SUNSET - SUNRISE)
	return SUN_MAX_DEG * cos((u - 0.5) * PI)

## Direction towards the light (sun, or the moon when the sun is well below the horizon) for an hour.
static func light_dir(hour: float) -> Vector3:
	var e := sun_elevation(hour)
	var u := (hour - SUNRISE) / (SUNSET - SUNRISE)
	var az := (u - 0.5) * PI           # -90 deg at sunrise (east of noon), +90 at sunset
	var horiz := MID_AZ.rotated(Vector3.UP, -az)
	if e < -6.0:                        # the moon mirrors the sun across the sky
		horiz = -horiz
		e = clampf(-e, 14.0, 44.0)
	else:
		e = maxf(e, 5.0)
	var er := deg_to_rad(e)
	return (horiz * cos(er) + Vector3.UP * sin(er)).normalized()

static func _mix3(key: Dictionary, t_day: float, w_night: float) -> Vector3:
	var v: Vector3 = (key.low as Vector3).lerp(key.day, t_day)
	return v.lerp(key.night, w_night)

## The palette for an hour: Dictionary of the shader globals.
static func palette(hour: float) -> Dictionary:
	var e := sun_elevation(hour)
	var w_night := 1.0 - smoothstep(-6.0, 3.0, e)
	var t_day := smoothstep(4.0, 32.0, e)
	return {
		"sun_dir": light_dir(hour),
		"sun_color": _mix3(K_SUN, t_day, w_night),
		"sun_vis": 1.0 - w_night,
		"sky_zenith": _mix3(K_ZENITH, t_day, w_night),
		"sky_mid": _mix3(K_MID, t_day, w_night),
		"sky_horizon": _mix3(K_HORIZON, t_day, w_night),
		"sky_glow": _mix3(K_GLOW, t_day, w_night),
		"ambient_color": _mix3(K_AMBIENT, t_day, w_night),
		"fog_color": _mix3(K_FOG, t_day, w_night),
		"sky_tod": clampf((hour - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0),
	}

func apply_state(state: Dictionary) -> void:
	_light = float(state.get("day", {}).get("light", 1000)) / 1000.0
	_inside = 1.0 if int(state.get("cave", {}).get("inside", 0)) > 0 else 0.0
	_hour = float(state.get("day", {}).get("hour", 12.5))

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
	var pal := palette(force_hour if force_hour >= 0.0 else _hour)
	for key in pal:
		RenderingServer.global_shader_parameter_set(key, pal[key])
	sun.transform = Transform3D(Basis.looking_at(-(pal.sun_dir as Vector3), Vector3.UP), Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("moon_k", 1.0 - day)   # creature skins: moonlight fill and rim (skin v1)
	sun.light_color = warm
	sun.light_energy = Look.CREATURE_SUN_ENERGY * lerpf(0.12, 1.0, day) * (1.0 - inside)
	env.ambient_light_color = NIGHT_AMBIENT.lerp(Look.CREATURE_AMBIENT_COLOR, day)
	env.ambient_light_energy = Look.CREATURE_AMBIENT_ENERGY * lerpf(0.55, 1.0, day) * lerpf(1.0, 0.3, inside)
	env.tonemap_exposure = Look.TONEMAP_EXPOSURE * lerpf(0.50, 1.0, day) * lerpf(1.0, 0.8, inside)
