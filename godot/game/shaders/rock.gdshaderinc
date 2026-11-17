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

struct RockTex {
	float mineral;   // broad grey/tan patches
	float plate;     // macro height: plate tops high, cracks low
	float ao;        // 1 open .. 0 deep crack (macro and meso)
};

float rock_light_step(float light) {
	return 0.36 + 0.56 * smoothstep(0.12, 0.22, light) + 0.48 * smoothstep(0.5, 0.6, light);
}

RockTex rock_sample(MapCtx mc, float dist) {
	RockTex r;
	float m = map_tex_blur(rock_tex, mc, 1.0 / ROCK_TILE_MINERAL, vec2(0.0), ROCK_MINERAL_BLUR).b;
	r.mineral = clamp(0.5 + (m - 0.5) * ROCK_MINERAL_GAIN + ROCK_MINERAL_BIAS, 0.0, 1.0);
	vec4 mac = map_tex(rock_tex, mc, 1.0 / ROCK_TILE_MACRO, vec2(ROCK_MACRO_SHIFT * r.mineral, 0.0));
	r.plate = mac.b;
	r.ao = mac.a;
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
		vec4 meso = map_tex(rock_tex, mc, 1.0 / ROCK_TILE_MESO, vec2(0.21, 0.53));
		r.ao = min(r.ao, mix(1.0, meso.a, f));
	}
#endif
	return r;
}

// Rock albedo and light. a0/a1 are the two palette stops (R0/R1, or the volcanic pair); `cavity` is the generator's
// concave map (the hero's 0.64 factor).
vec3 rock_shade(vec3 a0, vec3 a1, RockTex r, float light, float steep, float cavity) {
	vec3 c = mix(a0, a1, smoothstep(0.25, 0.78, r.mineral));
	c = mix(c, R2, smoothstep(0.57, 0.87, r.plate) * 0.4);
	c *= 1.0 + (r.plate - 0.5) * ROCK_PLATE_VALUE;
	float open = 1.0 - r.ao;
	float ao = 1.0 - ROCK_AO_MID * smoothstep(0.40, 0.50, open) - ROCK_AO_DEEP * smoothstep(0.72, 0.80, open);
	c = mix(c, c * ROCK_SHADE * ROCK_AO_TINT, 1.0 - ao);
	float lit = smoothstep(0.18, 0.52, light);
	c *= 1.0 + ROCK_TOP_LIGHT * smoothstep(0.62, 0.70, r.plate) * lit;
	c *= mix(ROCK_SHADE, ROCK_LIT, lit) * rock_light_step(light);
	return c * mix(1.0, 0.64, cavity);
}

// Scree: a flat colour in the hero, pebbles and sand-filled gaps here (Medium and High), the rock sheet's plates at Low.
vec3 scree_shade(vec3 rock_c, RockTex r, MapCtx mc, float light, float dist) {
	vec3 base = SCREE * rock_light_step(light) * GRASS;
	float h = 0.5;
	float open = 1.0;
#if ROCK_TIER >= 2
	if (dist < SCREE_FAR) {
		float f = 1.0 - smoothstep(SCREE_NEAR, SCREE_FAR, dist);
		vec4 s = map_tex(scree_tex, mc, 1.0 / SCREE_TILE, vec2(0.13, 0.41));
		h = mix(0.5, s.b, f);
		open = mix(1.0, s.a, f);
	}
#else
	h = r.plate;
#endif
	base *= (1.0 + (h - 0.5) * SCREE_VALUE) * mix(1.0 - SCREE_GAP_DARK, 1.0, open);
	return mix(rock_c, base, SCREE_ROCK_MIX);
}
