shader_type spatial;
// Ambient fliers (docs/godot/AMBIENT-FLIERS.md): one multimesh per species, wings animated here so the CPU only writes the
// instance transform. Matte skin look as the creatures (no gloss, backlit thin wings, night moon fill, countershaded underside).
//   INSTANCE_CUSTOM: x wingbeat phase (rad), y stroke amplitude 0..1 (0 = held open, a glide), z fold 0..1 (1 = wings tucked),
//                    w leg extension 0..1 (tucked in cruise, down and forward in the flare)
//   COLOR.rgb vertex colour, COLOR.a wing weight (0 body .. 1 tip; > 0 marks a wing vertex), UV.x hip height and UV.y 1 for a leg
render_mode cull_disabled, specular_disabled;
global uniform float moon_k;
uniform vec3 under_tint = vec3(0.7, 0.68, 0.64);   // underside of the wings: paler (countershading)
uniform float under_mix = 0.55;
uniform float stroke = 0.9;        // half stroke amplitude at amplitude 1 (rad)
uniform float lag = 0.9;           // spanwise phase lag: the tip follows the root (rad)
uniform float flex = 0.45;         // wrist flexion on the upstroke (share of the half span pulled in)
uniform float wing_light = 0.35;   // backlight (thin tissue / vane)
uniform float rough = 0.92;
varying vec3 v_col;
varying float v_wing;

void vertex() {
	float t = COLOR.a;
	vec3 v = VERTEX;
	v_wing = t;
	v_col = COLOR.rgb;
	if (t > 0.0) {
		float side = v.x >= 0.0 ? 1.0 : -1.0;
		float ph = INSTANCE_CUSTOM.x - t * lag;
		float amp = INSTANCE_CUSTOM.y * stroke;
		float ang = amp * sin(ph) * (1.0 + 0.7 * t) + 0.12 * (1.0 - INSTANCE_CUSTOM.y);
		float upk = max(cos(ph), 0.0) * INSTANCE_CUSTOM.y;
		float ax = abs(v.x);
		ax *= 1.0 - flex * upk * smoothstep(0.2, 0.7, t);        // wrist flexes on the up-stroke
		float fold = INSTANCE_CUSTOM.z;
		ax *= mix(1.0, 0.16, fold * smoothstep(0.0, 0.35, t));      // tucked against the body
		float dy = v.y - 0.0;
		float s = sin(ang * side);
		float c = cos(ang * side);
		float x = ax * side;
		v.x = x * c - dy * s;
		v.y = x * s + dy * c - fold * ax * 0.35;
		v.z -= fold * t * 0.25 * abs(VERTEX.x);
	}
	if (UV.y > 0.5) {
		float e = INSTANCE_CUSTOM.w;
		v.y = UV.x + (v.y - UV.x) * mix(0.2, 1.0, e);
		v.z += e * 0.35 * (UV.x - v.y);
	}
	VERTEX = v;
}

void fragment() {
	vec3 col = v_col;
	if (v_wing > 0.0 && !FRONT_FACING) col = mix(col, under_tint, under_mix);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.0;
	if (v_wing > 0.0) BACKLIGHT = col * wing_light;
	float nv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	EMISSION = col * moon_k * (0.16 + 0.5 * pow(1.0 - nv, 2.5));   // moonlight fill and rim, always the skin's own colour
}
