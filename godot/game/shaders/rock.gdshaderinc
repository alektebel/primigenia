// Rock and scree material (docs/godot/PLAN-rock.md sections 3 to 5): colour from two baked detail textures read through the
// biplanar mapping of rock_mapping.gdshaderinc, in palette C only (R0/R1/R2, SCREE, ROCK_SHADE/LIT: no new hues).
// Constants named here are mirrored in game/island/look.gd and compared by test_look.gd.
// Include after land.gdshaderinc, terrain_maps.gdshaderinc and rock_mapping.gdshaderinc.

// Quality tier: 1 Low, 2 Medium (default), 3 High. The terrain_*.gdshader variants define it before including the body.
#ifndef ROCK_TIER
#define ROCK_TIER 2
#endif

uniform sampler2D rock_tex : filter_linear_mipmap_anisotropic, repeat_enable;    // RG -grad h, B height, A crack occlusion
uniform sampler2D scree_tex : filter_linear_mipmap_anisotropic, repeat_enable;

// World metres per texture tile. Non-integer ratios, so layers never line up.
const float ROCK_TILE_MINERAL = 263.0;
const float ROCK_TILE_MACRO = 41.0;
const float ROCK_TILE_MESO = 9.7;
const float ROCK_TILE_MICRO = 2.3;
const float SCREE_TILE = 6.1;
// Distance fades (m). Beyond the far value the fetch is skipped.
const float ROCK_MESO_NEAR = 120.0;
const float ROCK_MESO_FAR = 380.0;
const float ROCK_MESO_FAR_HIGH = 500.0;
const float ROCK_MICRO_NEAR = 25.0;
const float ROCK_MICRO_FAR = 70.0;
const float SCREE_NEAR = 150.0;
const float SCREE_FAR = 450.0;
// Mineral patches come from the macro sheet read many mips up (broad, low contrast), stretched back around 0.5.
const float ROCK_MINERAL_BLUR = 14.0;
const float ROCK_MINERAL_GAIN = 2.2;
const float ROCK_MINERAL_BIAS = -0.06;
const float ROCK_MACRO_SHIFT = 0.37;     // u offset of the macro layer per unit of mineral, to break tiling
// Albedo modulation (posterized like landRamp).
const float ROCK_PLATE_VALUE = 0.22;
const float ROCK_AO_MID = 0.22;
const float ROCK_AO_DEEP = 0.16;
const float ROCK_AO_TINT = 0.62;
const float ROCK_TOP_LIGHT = 0.10;
const float SCREE_VALUE = 0.35;
const float SCREE_GAP_DARK = 0.28;
const float SCREE_ROCK_MIX = 0.85;
// Detail normal strength per layer (UDN blend), and the ceiling of any rock colour (1.2 x the lit snow's brightest channel).
const float ROCK_N_MACRO = 0.55;
const float ROCK_N_MESO = 0.45;
const float ROCK_N_MICRO = 0.35;
const float SCREE_N = 0.5;
const float ROCK_MAX = 1.09;

uniform vec3 rock_normal_gain = vec3(1.0);   // per layer (macro, meso, micro) multiplier of the normal strengths; tests set it

struct RockTex {
	float mineral;   // broad grey/tan patches
	float plate;     // macro height: plate tops high, cracks low
	float ao;        // 1 open .. 0 deep crack (macro and meso)
	vec3 tilt;       // summed detail tilt (strength and distance fade applied), added to the macro normal
};

// The ramps, widened by fw (the screen-space change of `light`) so detail normals do not crawl on the toon thresholds.
float rock_light_step(float light, float fw) {
	return 0.36 + 0.56 * smoothstep(0.12 - fw, 0.22 + fw, light) + 0.48 * smoothstep(0.5 - fw, 0.6 + fw, light);
}

float rock_lit_mask(float light, float fw) {
	return smoothstep(0.18 - fw, 0.52 + fw, light);
}

// Light of a detail normal: n = normalize(gn + tilt). Returns the light and its fwidth (clamped).
float rock_light(vec3 gn, vec3 tilt, out float fw) {
	float l = max(dot(normalize(gn + tilt), SUN_DIR), 0.0);
	fw = min(fwidth(l), 0.25);
	return l;
}

RockTex rock_sample(MapCtx mc, float dist) {
	RockTex r;
	r.tilt = vec3(0.0);
	float m = map_tex_blur(rock_tex, mc, 1.0 / ROCK_TILE_MINERAL, vec2(0.0), ROCK_MINERAL_BLUR).b;
	r.mineral = clamp(0.5 + (m - 0.5) * ROCK_MINERAL_GAIN + ROCK_MINERAL_BIAS, 0.0, 1.0);
	vec3 t;
	vec4 mac = map_tex_tilt(rock_tex, mc, 1.0 / ROCK_TILE_MACRO, vec2(ROCK_MACRO_SHIFT * r.mineral, 0.0), t);
	r.plate = mac.b;
	r.ao = mac.a;
	r.tilt = t * ROCK_N_MACRO * rock_normal_gain.x;
#if ROCK_TIER >= 2
#if ROCK_TIER >= 3
	float meso_far = ROCK_MESO_FAR_HIGH;
	float meso_near = ROCK_MESO_NEAR + 80.0;
#else
	float meso_far = ROCK_MESO_FAR;
	float meso_near = ROCK_MESO_NEAR;
#endif
	if (dist < meso_far) {
		float f = 1.0 - smoothstep(meso_near, meso_far, dist);
		vec4 meso = map_tex_tilt(rock_tex, mc, 1.0 / ROCK_TILE_MESO, vec2(0.21, 0.53), t);
		r.ao = min(r.ao, mix(1.0, meso.a, f));
		r.tilt += t * ROCK_N_MESO * rock_normal_gain.y * f;
	}
#endif
#if ROCK_TIER >= 3
	if (dist < ROCK_MICRO_FAR) {
		float f = 1.0 - smoothstep(ROCK_MICRO_NEAR, ROCK_MICRO_FAR, dist);
		vec4 micro = map_tex_tilt(rock_tex, mc, 1.0 / ROCK_TILE_MICRO, vec2(0.67, 0.19), t);
		r.tilt += t * ROCK_N_MICRO * rock_normal_gain.z * f;
	}
#endif
	return r;
}

// Rock albedo and light. a0/a1 are the two palette stops (R0/R1, or the volcanic pair); `cavity` is the generator's
// concave map (the hero's 0.64 factor).
vec3 rock_shade(vec3 a0, vec3 a1, RockTex r, float light, float fw, float steep, float cavity) {
	vec3 c = mix(a0, a1, smoothstep(0.25, 0.78, r.mineral));
	c = mix(c, R2, smoothstep(0.57, 0.87, r.plate) * 0.4);
	c *= 1.0 + (r.plate - 0.5) * ROCK_PLATE_VALUE;
	float open = 1.0 - r.ao;
	float ao = 1.0 - ROCK_AO_MID * smoothstep(0.40, 0.50, open) - ROCK_AO_DEEP * smoothstep(0.72, 0.80, open);
	c = mix(c, c * ROCK_SHADE * ROCK_AO_TINT, 1.0 - ao);
	float lit = rock_lit_mask(light, fw);
	c *= 1.0 + ROCK_TOP_LIGHT * smoothstep(0.62, 0.70, r.plate) * lit;
	c *= mix(ROCK_SHADE, ROCK_LIT, lit) * rock_light_step(light, fw);
	return min(c * mix(1.0, 0.64, cavity), vec3(ROCK_MAX));
}

// Scree sheet sample: pebble height, gap occlusion and the pebble tilt (Medium and High; Low has no scree sheet).
struct ScreeTex {
	float height;
	float open;
	vec3 tilt;
};

ScreeTex scree_sample(MapCtx mc, RockTex r, float dist) {
	ScreeTex s;
	s.height = 0.5;
	s.open = 1.0;
	s.tilt = vec3(0.0);
#if ROCK_TIER >= 2
	if (dist < SCREE_FAR) {
		float f = 1.0 - smoothstep(SCREE_NEAR, SCREE_FAR, dist);
		vec3 t;
		vec4 v = map_tex_tilt(scree_tex, mc, 1.0 / SCREE_TILE, vec2(0.13, 0.41), t);
		s.height = mix(0.5, v.b, f);
		s.open = mix(1.0, v.a, f);
		s.tilt = t * SCREE_N * f * rock_normal_gain.y;
	}
#else
	s.height = r.plate;
#endif
	return s;
}

// Scree: a flat colour in the hero, pebbles and sand-filled gaps here (Medium and High), the rock sheet's plates at Low.
vec3 scree_shade(vec3 rock_c, ScreeTex s, float light, float fw) {
	vec3 base = SCREE * rock_light_step(light, fw) * GRASS;
	base *= (1.0 + (s.height - 0.5) * SCREE_VALUE) * mix(1.0 - SCREE_GAP_DARK, 1.0, s.open);
	return min(mix(rock_c, base, SCREE_ROCK_MIX), vec3(ROCK_MAX));
}
