extends Control
## The full-screen veils of the diegetic UI: menu (flat tint 0.62), loadout (0.42), low health and hit (an ember vignette
## that closes in, breathing with the pulse), death (fog-coloured vignette). Each is one ColorRect with veil.gdshader.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const SHADER := preload("res://ui/veil.gdshader")

var flat_amount := 0.0              # target tint amount of the flat veil (0.62 menu, 0.42 loadout)
var low_health := 0.0               # 0..1, how low the health is (drives the ember vignette)
var hit := 0.0                      # 0..1, decays in 0.25 s
var death := 0.0                    # 0..1 fog closing in
var _flat_rect: ColorRect
var _edge_rect: ColorRect
var _fog_rect: ColorRect
var _flat := 0.0
var _clock := 0.0
var _pulse_period := Style.PULSE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flat_rect = _rect(Color("18221F"), Color("18221F"))
	_edge_rect = _rect(Color("18221F"), Color("2A0F0A"))
	_fog_rect = _rect(Color("E7E4DA"), Color("E7E4DA"))

func _rect(tint: Color, edge: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("edge", edge)
	r.material = m
	r.visible = false
	add_child(r)
	return r

func set_flat(amount: float) -> void:
	flat_amount = amount

func trigger_hit() -> void:
	hit = 1.0

func flat_now() -> float:
	return _flat

## Strength of the ember vignette right now (low health breathing + a hit), 0..1.
func edge_now() -> float:
	var base := 0.0
	if low_health > 0.0:
		var p := 1.0 if Style.reduced_motion() else 0.8 + 0.2 * sin(TAU * _clock / _pulse_period)
		base = low_health * p
	return clampf(maxf(base * 0.95, hit * 0.25), 0.0, 1.0)

func _process(dt: float) -> void:
	_clock += dt
	_flat = Style.approach(_flat, flat_amount, dt, Style.OUT)
	hit = maxf(hit - dt / 0.25, 0.0)
	_pulse_period = 0.8 if low_health > 0.99 else Style.PULSE
	var e := edge_now()
	_flat_rect.visible = _flat > 0.003
	_flat_rect.material.set_shader_parameter("tint_amount", _flat)
	_edge_rect.visible = e > 0.003
	_edge_rect.material.set_shader_parameter("edge_amount", e)
	_edge_rect.material.set_shader_parameter("inner", 0.42)
	_fog_rect.visible = death > 0.003
	_fog_rect.material.set_shader_parameter("tint_amount", 0.0)
	_fog_rect.material.set_shader_parameter("edge_amount", death * 0.9)
	_fog_rect.material.set_shader_parameter("inner", 0.3 if death < 0.99 else 0.0)
