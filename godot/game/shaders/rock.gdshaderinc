// Rock and scree material (docs/godot/PLAN-rock.md sections 3 to 5): colour from two baked detail textures read through the
// biplanar mapping of rock_mapping.gdshaderinc, in palette C only (R0/R1/R2, SCREE, ROCK_SHADE/LIT: no new hues).
// Constants named here are mirrored in game/island/look.gd and compared by test_look.gd.
// Include after land.gdshaderinc, terrain_maps.gdshaderinc and rock_mapping.gdshaderinc.

// Quality tier: 1 Low, 2 Medium (default), 3 High. The terrain_*.gdshader variants define it before including the body.
#ifndef ROCK_TIER
#define ROCK_TIER 2
#endif

// Anisotropic filtering only in the High tier (it is the costly part of a textureGrad on a grazing face).
#if ROCK_TIER >= 3
uniform sampler2D rock_tex : filter_linear_mipmap_anisotropic, repeat_enable;    // RG -grad h, B height, A crack occlusion
uniform sampler2D scree_tex : filter_linear_mipmap_anisotropic, repeat_enable;
#else
uniform sampler2D rock_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D scree_tex : filter_linear_mipmap, repeat_enable;
#endif
uniform sampler2D relief_tex : filter_linear, repeat_disable;   // R fine curvature, G broad curvature (> 0.5 concave), B sediment, A sun

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
const float ROCK_MINERAL_BIAS = -0.10;
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

// Strata (section 4). The cap rock follows the generator's hard layers (core/src/terrain.c: period 47 m, dip +.025x -.018z);
// the bedding is cosmetic, on every steep face.
const float ROCK_CAP_PERIOD = 47.0;
const float ROCK_CAP_DIP_X = 0.025;
const float ROCK_CAP_DIP_Z = -0.018;
const float ROCK_CAP_WOBBLE = 10.0;
const float ROCK_CAP_Y0 = 342.0;
const float ROCK_CAP_Y1 = 375.0;
const float ROCK_CAP_MIX = 0.35;
const float ROCK_CAP_AO = 0.5;
const float ROCK_BED_PERIOD = 7.3;
const float ROCK_BED_VALUE = 0.14;
const float ROCK_BED_WOBBLE = 0.5;
const float ROCK_BED_PLATE = 2.5;
const float ROCK_BED_LEDGE = 0.06;
const float ROCK_BED_FACES = 0.3;

// Relief cues (section 4): gullies darken, ridges catch light, wet streaks, scree fans.
const float ROCK_GULLY_DARK = 0.64;
const float ROCK_RIDGE_LIGHT = 0.07;
const float ROCK_RIM = 0.025;
const vec3 ROCK_RIM_TINT = vec3(0.52, 0.70, 0.93);   // the sky's SKY_MID
const float ROCK_WET_DARK = 0.72;
const float ROCK_WET_MIN = 0.35;
const float ROCK_STREAK_STRETCH = 8.0;
const float ROCK_FLOOR_DARK = 0.15;
const float SCREE_FAN_LIGHT = 1.08;
const float SCREE_FINE_TILE = 2.65;
const float SCREE_TOE_SLOPE = 0.866;

// Height blend and snow placement (section 4).
const float ROCK_BLEND_BIAS = 0.5;       // weight of the texture heights against the generator's cell weights
const float ROCK_BLEND_DEPTH = 0.18;
const float SNOW_FACE_LO = 0.55;         // detail normal y: snow rests on facets flatter than about 55 degrees
const float SNOW_FACE_HI = 0.75;
const float SNOW_MACRO_LO = 0.54;       // and the macro face itself must be flatter than about 55 degrees (cos 55 = 0.574)
const float SNOW_MACRO_HI = 0.58;
const float SNOW_LINE_Y = 365.0;         // the classifier's snow line (core/src/terrain.c): 365 - 45 * aspect
const float SNOW_LINE_ASPECT = 45.0;
const float SNOW_DUST = 0.8;

uniform float rock_shadows = 0.0;   // 1 = apply the baked sun visibility in relief.A (step 9, off by default)

uniform vec3 rock_normal_gain = vec3(1.0);   // per layer (macro, meso, micro) multiplier of the normal strengths; tests set it

struct RockTex {
	float streak;    // wet streak mask: vertical dark lines on steep wet faces
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

// Hash without sin() (Hoskins), stable across GPUs; the strata use it instead of landHash.
float rockHash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rockNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rockHash(i), rockHash(i + vec2(1.0, 0.0)), f.x), mix(rockHash(i + vec2(0.0, 1.0)), rockHash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Generator-aligned cap rock: 1 on the resistant layer, above about 342 m (full from 375 m).
float rock_cap(vec3 wp) {
	float phase = (wp.y + ROCK_CAP_DIP_X * wp.x + ROCK_CAP_DIP_Z * wp.z + ROCK_CAP_WOBBLE * rockNoise(wp.xz / 400.0)) / ROCK_CAP_PERIOD;
	float t = fract(phase);
	return smoothstep(0.10, 0.14, t) * (1.0 - smoothstep(0.60, 0.64, t)) * smoothstep(ROCK_CAP_Y0, ROCK_CAP_Y1, wp.y);
}

// Cosmetic bedding phase (in bands) and the share of faces that show it.
float rock_bed_phase(vec3 wp, RockTex r, float thick) {
	float y = wp.y + ROCK_CAP_DIP_X * wp.x + ROCK_CAP_DIP_Z * wp.z;
	return (y + ROCK_BED_PLATE * (r.plate - 0.5) * thick) / (ROCK_BED_PERIOD * thick) + ROCK_BED_WOBBLE * (r.mineral - 0.5);
}

float rock_bed_faces(vec3 wp) {
	return smoothstep(ROCK_BED_FACES, ROCK_BED_FACES + 0.15, rockNoise(wp.xz / ROCK_TILE_MINERAL + 7.7));
}

RockTex rock_sample(MapCtx mc, float dist, float wet, float steep) {
	RockTex r;
	r.tilt = vec3(0.0);
	r.streak = 0.0;
	float m = map_tex_blur(rock_tex, mc, 1.0 / ROCK_TILE_MINERAL, vec2(0.0), ROCK_MINERAL_BLUR).b;
	r.mineral = clamp(0.5 + (m - 0.5) * ROCK_MINERAL_GAIN + ROCK_MINERAL_BIAS, 0.0, 1.0);
	vec3 t;
	vec4 mac = map_tex_tilt(rock_tex, mc, 1.0 / ROCK_TILE_MACRO, vec2(ROCK_MACRO_SHIFT * r.mineral, 0.0), t);
	r.plate = mac.b;
	r.ao = mac.a;
	r.tilt = t * ROCK_N_MACRO * rock_normal_gain.x;
#if ROCK_TIER >= 2
	if (wet > ROCK_WET_MIN && steep > 0.3) {
		float sa = map_tex_aniso(rock_tex, mc, vec2(1.0, 1.0 / ROCK_STREAK_STRETCH) / ROCK_TILE_MACRO, vec2(0.61, 0.0)).a;
		r.streak = smoothstep(ROCK_WET_MIN, 0.6, wet) * steep * smoothstep(0.35, 0.7, 1.0 - sa);
	}
#endif
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
// `thick` is the strata thickness factor (1 rock, 2 volcanic); `cap_on` enables the generator-aligned cap rock.
vec3 rock_shade(vec3 a0, vec3 a1, RockTex r, float light, float fw, float steep, float cavity, vec3 wp, float thick, bool cap_on, vec4 rl, float wet) {
	vec3 c = mix(a0, a1, smoothstep(0.25, 0.78, r.mineral));
	c = mix(c, R2, smoothstep(0.57, 0.87, r.plate) * 0.4);
	c *= 1.0 + (r.plate - 0.5) * ROCK_PLATE_VALUE;
	float cap = cap_on ? rock_cap(wp) : 0.0;
	c = mix(c, R1 * 1.1, cap * ROCK_CAP_MIX);
	float open = 1.0 - r.ao;
	float ao = 1.0 - ROCK_AO_MID * smoothstep(0.40, 0.50, open) - ROCK_AO_DEEP * smoothstep(0.72, 0.80, open);
	c = mix(c, c * ROCK_SHADE * ROCK_AO_TINT, (1.0 - ao) * mix(1.0, ROCK_CAP_AO, cap));
	float lit = rock_lit_mask(light, fw);
	// Bedding: three posterized tints of +-14 % value, an under-ledge line and an upper lip, faded out when a band is under
	// about 4 pixels, and on the faces the 263 m mask leaves bare.
	float ph = rock_bed_phase(wp, r, thick);
	float pfw = fwidth(ph);
	float vis = steep * rock_bed_faces(wp) * (1.0 - smoothstep(0.12, 0.25, pfw));
	float band = floor(ph);
	float lvl = floor(rockHash(vec2(band, 3.0)) * 2.999);
	vec3 tint = lvl < 0.5 ? R0 : (lvl < 1.5 ? R2 : R1);
	vec3 rel = tint / ((R0 + R1 + R2) / 3.0);
	c *= mix(vec3(1.0), (1.0 + ROCK_BED_VALUE * (lvl - 1.0)) * mix(vec3(1.0), rel, 0.3), vis);
	float b = fract(ph);
	c *= 1.0 - 0.28 * vis * (1.0 - smoothstep(0.0, ROCK_BED_LEDGE, b));
	c *= 1.0 + 0.12 * vis * lit * smoothstep(1.0 - ROCK_BED_LEDGE, 1.0, b);
	c *= 1.0 + ROCK_TOP_LIGHT * smoothstep(0.62, 0.70, r.plate) * lit;
	c *= mix(ROCK_SHADE, ROCK_LIT, lit) * rock_light_step(light, fw);
	// Relief: concave gullies darken (the hero's 0.64 cavity factor, now at four scales), convex ridges catch light on the lit
	// side and rim the shade side with sky. R fine and G broad signed curvature, > 0.5 concave.
	float conc_f = max(0.0, 2.0 * rl.r - 1.0);
	float conc_b = max(0.0, 2.0 * rl.g - 1.0);
	float conv = max(max(0.0, 1.0 - 2.0 * rl.r), max(0.0, 1.0 - 2.0 * rl.g));
	float gully = max(cavity, smoothstep(0.15, 0.55, max(conc_f, conc_b)));
	float ridge = smoothstep(0.30, 0.70, conv);
	c *= mix(1.0, ROCK_GULLY_DARK, gully);
	c *= 1.0 + ROCK_RIDGE_LIGHT * ridge * lit * (ROCK_LIT / ROCK_LIT.y);
	c += ROCK_RIM * ridge * (1.0 - lit) * ROCK_RIM_TINT * 0.5;
	// Water streaks down steep faces, and a darker floor where a wet gully collects them.
	c = mix(c, c * WET_TINT, r.streak);
	c *= mix(1.0, ROCK_WET_DARK, r.streak);
	c *= 1.0 - ROCK_FLOOR_DARK * smoothstep(0.4, 0.7, conc_b) * smoothstep(0.3, 0.6, wet);
	return min(c, vec3(ROCK_MAX));
}

// Scree sheet sample: pebble height, gap occlusion and the pebble tilt (Medium and High; Low has no scree sheet).
struct ScreeTex {
	float height;
	float open;
	vec3 tilt;
};

ScreeTex scree_sample(MapCtx mc, RockTex r, float dist, float fan) {
	ScreeTex s;
	s.height = 0.5;
	s.open = 1.0;
	s.tilt = vec3(0.0);
#if ROCK_TIER >= 2
	if (dist < SCREE_FAR) {
		float f = 1.0 - smoothstep(SCREE_NEAR, SCREE_FAR, dist);
		vec3 t;
		vec4 v = map_tex_tilt(scree_tex, mc, 1.0 / SCREE_TILE, vec2(0.13, 0.41), t);
		// Thick deposits are finer: crossfade to a second fixed tile (a continuously scaled tile would swim).
		if (fan > 0.02) {
			vec3 t2;
			vec4 v2 = map_tex_tilt(scree_tex, mc, 1.0 / SCREE_FINE_TILE, vec2(0.57, 0.29), t2);
			v = mix(v, v2, fan);
			t = mix(t, t2, fan);
		}
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
vec3 scree_shade(vec3 rock_c, ScreeTex s, float light, float fw, float fan) {
	vec3 base = SCREE * rock_light_step(light, fw) * GRASS * mix(1.0, SCREE_FAN_LIGHT, fan);
	base *= (1.0 + (s.height - 0.5) * SCREE_VALUE) * mix(1.0 - SCREE_GAP_DARK, 1.0, s.open);
	return min(mix(rock_c, base, SCREE_ROCK_MIX), vec3(ROCK_MAX));
}

// Height blend of the six material weights (meadow, rock, scree, volcanic, sand, snow): w' = max(w + 0.5 H - max(w + 0.5 H) +
// 0.18, 0), so rock pokes through scree and scree fills cracks, with boundaries as sharp as the sheet's cracks instead of a
// 3.5 m ramp. Only materials present in the cell take part. Then the snow gate: snow only rests where the DETAIL normal is
// flatter than about 55 degrees, the rest falls back to rock, and rock near the classifier's line is dusted on up-facing
// ledges. `plate` is the macro height 0..1, `grass` the grass mask.
void rock_blend(inout float w[6], float plate, float grass, vec3 nd, vec3 gn, vec3 wp, bool blend) {
	if (blend) {
		float hh[6];
		hh[0] = 0.5 + 0.5 * grass;
		hh[1] = plate;
		hh[2] = 1.0 - plate;
		hh[3] = 0.5;
		hh[4] = 0.5;
		hh[5] = 0.5;
		float hw[6];
		float m = -10.0;
		for (int i = 0; i < 6; i++) {
			hw[i] = w[i] > 0.001 ? w[i] + ROCK_BLEND_BIAS * hh[i] : -10.0;
			m = max(m, hw[i]);
		}
		float sum = 0.0;
		for (int i = 0; i < 6; i++) {
			w[i] = max(hw[i] - m + ROCK_BLEND_DEPTH, 0.0);
			sum += w[i];
		}
		for (int i = 0; i < 6; i++) {
			w[i] /= max(sum, 1e-4);
		}
	}
	float gate = smoothstep(SNOW_FACE_LO, SNOW_FACE_HI, nd.y) * smoothstep(SNOW_MACRO_LO, SNOW_MACRO_HI, gn.y);
	float fall = w[5] * (1.0 - gate);
	w[5] -= fall;
	w[1] += fall;
	float gy = clamp(-gn.z / max(gn.y, 0.05), -1.0, 1.0);
	float line = SNOW_LINE_Y - gy * SNOW_LINE_ASPECT;
	float dust = w[1] * smoothstep(line - 30.0, line + 5.0, wp.y + 20.0 * (plate - 0.5)) * smoothstep(0.80, 0.92, nd.y) * SNOW_DUST;
	w[1] -= dust;
	w[5] += dust;
}
