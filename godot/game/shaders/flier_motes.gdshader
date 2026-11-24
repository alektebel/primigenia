shader_type spatial;
// Insect swarms at dusk (docs/godot/AMBIENT-FLIERS.md): the whole swarm is this shader. One instance per swarm; every mote is a
// small view-facing quad whose position is a closed-form drifting Lissajous cloud, so the CPU does nothing per mote.
//   INSTANCE_CUSTOM.x = swarm presence 0..1 (motes beyond that fraction are collapsed), .y = swarm seed
//   COLOR.r = mote id 0..1, UV = quad corner -1..1
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
global uniform float moon_k;
global uniform vec3 sun_color;
uniform float radius = 2.4;
uniform float mote_size = 0.045;
uniform float min_px = 0.0032;     // never thinner than this fraction of the distance: a mote stays a visible speck far off
uniform vec3 tint = vec3(0.95, 0.86, 0.55);
varying float v_a;

float h11(float p) { return fract(sin(p * 127.1 + 311.7) * 43758.5453); }

void vertex() {
	float id = COLOR.r;
	float seed = INSTANCE_CUSTOM.y;
	float present = step(id, INSTANCE_CUSTOM.x);
	float r1 = h11(id * 91.7 + seed), r2 = h11(id * 17.3 + seed * 1.7), r3 = h11(id * 53.1 + seed * 3.1);
	float w = TIME * (0.35 + 0.9 * r1);
	vec3 c = vec3(sin(w * 1.00 + r2 * 6.28) * (0.4 + 0.6 * r1), 0.5 * sin(w * 1.31 + r3 * 6.28) * (0.3 + 0.7 * r2), cos(w * 0.83 + r1 * 6.28) * (0.4 + 0.6 * r3)) * radius;
	c += vec3(sin(TIME * 0.11 + seed), 0.0, cos(TIME * 0.09 + seed * 2.0)) * radius * 0.5;   // the whole cloud drifts
	vec3 wp = (MODEL_MATRIX * vec4(c, 1.0)).xyz;
	float dist = length(wp - INV_VIEW_MATRIX[3].xyz);
	float size = max(mote_size, dist * min_px) * present;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	wp += (right * UV.x + up * UV.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	v_a = (0.55 + 0.45 * sin(TIME * (6.0 + 9.0 * r2) + r3 * 20.0)) * present;      // wingbeat flicker
}

void fragment() {
	float d = length(UV);
	float a = smoothstep(1.0, 0.25, d) * v_a;
	ALBEDO = tint * mix(0.9, 0.5, moon_k);
	ALPHA = a * 0.9;
}
