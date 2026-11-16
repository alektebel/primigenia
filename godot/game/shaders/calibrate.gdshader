shader_type spatial;
render_mode unshaded, cull_disabled;
// Calibration patches. mode 0: make the tone mapper see the linear `value` (probes Godot's ACES).
// mode 1: write display_out(value) (round trip: the screen must show `value`).
#include "res://game/shaders/look.gdshaderinc"
uniform vec3 value = vec3(0.5);
uniform int mode = 0;
void fragment() {
	ALBEDO = mode == 0 ? godot_albedo(value) : display_out(value);
}
