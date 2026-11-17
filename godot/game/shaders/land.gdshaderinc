// Stylised land shading of palette C ("Current+"), ported from the hero's V8 land shader.
// Constant names equal game/island/look.gd; a test keeps them in sync.
#include "res://game/shaders/look.gdshaderinc"

const vec3 GRASS = vec3(1.03, 0.96, 0.86);
const float SH_K = 0.42;
const vec3 G0 = vec3(0.09, 0.225, 0.04);
const vec3 G1 = vec3(0.185, 0.335, 0.075);
const vec3 LIT = vec3(1.1, 1.03, 0.9);
const vec3 SHADE = vec3(0.86, 0.92, 1.1);
const vec3 S_TINT = vec3(0.8, 0.86, 1.14);
const vec3 TUFT0 = vec3(0.82, 0.9, 0.78);
const vec3 TUFT1 = vec3(1.04, 1.02, 0.98);
const float BLADE_LO = 0.52;
const float BLADE_HI = 1.28;
const vec3 R0 = vec3(0.15, 0.165, 0.19);
const vec3 R1 = vec3(0.28, 0.215, 0.14);
const vec3 R2 = vec3(0.19, 0.135, 0.085);
const vec3 SCREE = vec3(0.27, 0.23, 0.16);
const vec3 SNOW = vec3(0.78, 0.88, 0.95);
const vec3 ROCK_SHADE = vec3(0.68, 0.84, 1.2);
const vec3 ROCK_LIT = vec3(1.3, 1.1, 0.84);
// Proposed by the implementer, pending owner approval (see docs/godot/M0.md).
const vec3 SAND = vec3(0.42, 0.37, 0.25);
const vec3 VOLCANIC_R0 = vec3(0.075, 0.07, 0.075);
const vec3 VOLCANIC_R1 = vec3(0.13, 0.1, 0.085);
const vec3 WET_TINT = vec3(0.82, 0.9, 0.84);
const vec3 CHANNEL = vec3(0.035, 0.09, 0.13);

uniform vec4 occ[12];      // creature occluder spheres (x, y, z, r); unused: (0, -999, 0, 0)
uniform vec3 occ_center = vec3(0.0, -999.0, 0.0);

float landHash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float landNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(landHash(i), landHash(i + vec2(1.0, 0.0)), f.x), mix(landHash(i + vec2(0.0, 1.0)), landHash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float meadowWave(vec2 p, float t) {
	return smoothstep(0.45, 0.98, sin(dot(p, vec2(0.8, 0.6)) * 0.085 - t * 1.1));
}

float landRamp(float l) {
	return 0.6 + 0.25 * smoothstep(0.18, 0.25, l) + 0.23 * smoothstep(0.53, 0.61, l);
}

// Replaces the hero's CPU fbm(x * .03, z * .03, 3) field.
float tone(vec2 xz) {
	return landNoise(xz * 0.03) * 0.5714 + landNoise(xz * 0.06) * 0.2857 + landNoise(xz * 0.12) * 0.1429;
}

vec3 meadowColor(float t_b, float t_a, float light, float wave, vec2 xz) {
	vec3 c = mix(G0, G1, smoothstep(0.22, 0.8, t_b));
	c *= mix(0.56, 1.0, t_a) * landRamp(light) * GRASS;
	c *= mix(SHADE, LIT, smoothstep(0.15, 0.6, light));
	return c * (0.78 + 0.3 * landNoise(xz * 0.19) + 0.14 * landNoise(xz * 0.63)) * (1.0 + wave * 0.12);
}

// 1 = lit, < 1 = under a creature (contact shadow from the occluder spheres, near centre only).
float occluder_shadow(vec3 wp) {
	if (distance(wp.xz, occ_center.xz) > 24.0) {
		return 1.0;
	}
	float sh = 1.0;
	for (int i = 0; i < 12; i++) {
		vec4 o = occ[i];
		if (o.w <= 0.0) {
			continue;
		}
		vec3 oc = o.xyz - wp;
		float tca = dot(oc, SUN_DIR);
		float d2 = dot(oc, oc) - tca * tca;
		float r2 = o.w * o.w;
		sh *= mix(1.0, smoothstep(r2 * 0.5, r2 * 1.4, d2), step(0.0, tca));
	}
	return sh;
}
