shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, blend_mix, depth_draw_opaque, cull_disabled;
#define WORLD_LIT
// River ribbons (rivers.gd): flowing water along the channel, rapids and white water where the bed drops (waterfalls),
// soft edges, the same aerial haze as the sea. COLOR.r class/3, COLOR.g bed drop per metre, COLOR.b drainage 0..1.
#include "res://game/shaders/look.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"
#include "res://game/shaders/world_light.gdshaderinc"

varying vec3 wp;
varying vec2 st;
varying vec3 cls;

float rnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Drape: where the terrain falls away sideways the strip follows it (water on a slope or a fall) instead of hanging in the air.
	VERTEX.y = min(VERTEX.y, ground_tri(VERTEX.xz) + 0.2);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	st = UV;
	cls = COLOR.rgb;
}

void fragment() {
	float drop = cls.y;
	float rapid = smoothstep(0.10, 0.35, drop);
	float fall = smoothstep(0.55, 1.2, drop);
	float speed = 0.5 + 1.6 * clamp(drop * 3.0, 0.0, 1.0) + 0.5 * cls.z;
	vec2 q = vec2(st.x * 1.5 - TIME * speed, st.y * (1.5 + 3.0 * cls.z));
	float ripple = rnoise(q * 3.0) * 0.6 + rnoise(q * 7.0 + 3.1) * 0.4;
	vec3 n = normalize(vec3((rnoise(q * 4.0) - 0.5) * 0.35, 1.0, (rnoise(q * 4.0 + 9.0) - 0.5) * 0.35));
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	// Depth over the real bed: shallow water is pale and clear, the main channel deeper blue.
	float bed = wp.y - ground_tri(wp.xz);
	float shallow = 1.0 - smoothstep(0.0, 0.5 + 0.5 * cls.x, bed);
	vec3 c = mix(vec3(0.07, 0.30, 0.50), vec3(0.30, 0.64, 0.68), shallow * 0.8 + 0.2 * ripple);
	float fr = pow(1.0 - max(dot(V, n), 0.0), 4.0);
	c = mix(c, vec3(0.78, 0.9, 0.97), fr * 0.5);
	c += vec3(1.0, 0.95, 0.8) * pow(max(dot(n, normalize(V + SUN_DIR)), 0.0), 120.0) * 0.8;
	float foam = max(rapid * smoothstep(0.45, 0.8, ripple), fall * 0.9);
	foam = max(foam, smoothstep(0.78, 1.0, abs(st.y)) * 0.35);
	c = mix(c, vec3(0.95, 0.98, 1.0), clamp(foam, 0.0, 1.0));
	float edge = 1.0 - smoothstep(0.62, 1.0, abs(st.y));
	float alpha = clamp(edge * 0.92, 0.0, 1.0);
	if (bed < -0.4) {
		discard;
	}
	alpha *= 1.0 - smoothstep(0.5 + 0.4 * cls.x, 1.1 + 0.4 * cls.x, bed);   // never a floating edge
	vec3 disp = aerial(srgb_encode(tm(c)), wp, CAMERA_POSITION_WORLD);
	ALBEDO = display_out(disp);
	ALPHA = alpha;
}
