// Rock and scree material (docs/godot/PLAN-rock.md sections 3 to 5, ROCK.md "Photographic materials"): the colour variation, the relief
// normals and the heights come from CC0 photographic materials (rock_photo.gdshaderinc) read through the mapping of rock_mapping.gdshaderinc;
// the base colours stay palette C (R0/R1/R2, SCREE, ROCK_SHADE/LIT: no new hues). The Voronoi plate sheets of the first version are gone,
// so the ROCK_TILE_*, ROCK_MESO/MICRO_*, SCREE_NEAR/FAR and sheet-strength constants below are no longer read (kept in step with look.gd until the owner retires them).
// Constants named here are mirrored in game/island/look.gd and compared by test_look.gd.
// Include after land.gdshaderinc, terrain_maps.gdshaderinc and rock_mapping.gdshaderinc.

// Quality tier: 1 Low, 2 Medium (default), 3 High. The terrain_*.gdshader variants define it before including the body.
#ifndef ROCK_TIER
#define ROCK_TIER 2
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
	float plate;     // photographic height of the rock, 0..1 (ridges of the surface high, cracks low)
	float ao;        // cavity occlusion, 1 open .. 0.58 in the deepest cracks
	vec3 tilt;       // detail tilt (strengths and distance fade applied), added to the macro normal
	vec3 col;        // unlit rock albedo: palette x photograph (andesite, bedded strata, tuff patches)
	vec3 col_v;      // unlit volcanic albedo (basalt)
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

#include "res://game/shaders/rock_photo.gdshaderinc"

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

// Rock sample. wr / wv are the (pre-blend) weights of rock-like cover (rock, steep meadow, snow that falls back) and of volcanic rock:
// a material is only fetched where its weight is present. `steep` is 0 flat .. 1 cliff.
RockTex rock_sample(MapCtx mc, float dist, float wet, float steep, float wr, float wv) {
	RockTex r;
	r.tilt = vec3(0.0);
	r.streak = 0.0;
	r.col = R0;
	r.col_v = VOLCANIC_R0;
	r.plate = 0.5;
	r.ao = 1.0;
	// Broad mineral patches: two octaves of noise in a sheared frame (no texture, no tiling).
	vec2 q = vec2(mc.p.x + 0.6 * mc.p.y, mc.p.z - 0.4 * mc.p.y);
	float m = rockNoise(q / 150.0) * 0.65 + rockNoise(q / 41.0 + 3.1) * 0.35;
	r.mineral = clamp(0.5 + (m - 0.5) * ROCK_MINERAL_GAIN + ROCK_MINERAL_BIAS, 0.0, 1.0);
	float wsum = max(wr + wv, 1e-4);
	if (wr > 0.001) {
		// Bedded faces and the generator's cap rock read as layered strata, patches of tuff as warm, cracked brown; the rest is andesite.
		// Each sheet is fetched only where its share is present (a sheet costs two scales x projections x four taps).
		float ms = ph_synth > 0 ? 0.0 : clamp(steep * rock_bed_faces(mc.p) * 0.75 + rock_cap(mc.p) * 0.6, 0.0, 1.0);
		float mt = ph_synth > 0 ? 0.0 : smoothstep(0.62, 0.8, r.mineral) * (1.0 - 0.5 * steep);
		float wa = (1.0 - ms) * (1.0 - mt);
		float ws = ms * (1.0 - mt);
		float wsum_r = 0.0;
		vec3 c = vec3(0.0);
		float h = 0.0;
		vec3 t = vec3(0.0);
		if (wa > 0.02) {
			PhMat a = ph_material(PH_ANDESITE, PH_MEAN_ANDESITE, mc, PH_TILE_ANDESITE, dist, vec2(0.0), true);
			c += wa * ph_tint(mix(R0, R1, smoothstep(0.25, 0.78, r.mineral)), a.ratio);
			h += wa * a.h;
			t += wa * a.tilt;
			wsum_r += wa;
		}
		if (ws > 0.02) {
			PhMat s = ph_material(PH_STRATA, PH_MEAN_STRATA, mc, PH_TILE_STRATA, dist, vec2(0.17, 0.43), true);
			c += ws * ph_tint(mix(R0, R1, 0.5), s.ratio);
			h += ws * s.h;
			t += ws * s.tilt;
			wsum_r += ws;
		}
		if (mt > 0.02) {
			PhMat f = ph_material(PH_TUFF, PH_MEAN_TUFF, mc, PH_TILE_TUFF, dist, vec2(0.71, 0.29), true);
			c += mt * ph_tint(R2 * 1.3, f.ratio);
			h += mt * f.h;
			t += mt * f.tilt;
			wsum_r += mt;
		}
		r.col = c / max(wsum_r, 1e-4);
		r.plate = h / max(wsum_r, 1e-4);
		r.tilt = t / max(wsum_r, 1e-4) * (wr / wsum);
	}
	if (wv > 0.001) {
		PhMat b = ph_material(PH_BASALT, PH_MEAN_BASALT, mc, PH_TILE_BASALT, dist, vec2(0.53, 0.07), true);
		r.col_v = ph_tint(mix(VOLCANIC_R0, VOLCANIC_R1, smoothstep(0.25, 0.78, r.mineral)), b.ratio);
		r.plate = mix(r.plate, b.h, wv / wsum);
		r.tilt += b.tilt * (wv / wsum);
	}
	r.ao = ph_ao(r.plate);
	if (wet > ROCK_WET_MIN && steep > 0.3) {
		// Water streaks: stretched noise running down the face.
		float sn = rockNoise(vec2((mc.p.x + mc.p.z) * 1.1, mc.p.y * 0.12)) * 0.6 + rockNoise(vec2((mc.p.x - mc.p.z) * 2.3 + 5.0, mc.p.y * 0.3)) * 0.4;
		r.streak = smoothstep(ROCK_WET_MIN, 0.6, wet) * steep * smoothstep(0.35, 0.7, 1.0 - sn);
	}
	return r;
}

// Rock albedo and light. `base` is r.col or r.col_v; `cavity` is the generator's concave map (the hero's 0.64 factor).
// `thick` is the strata thickness factor (1 rock, 2 volcanic).
vec3 rock_shade(vec3 base, RockTex r, float light, float fw, float steep, float cavity, vec3 wp, float thick, vec4 rl, float wet) {
	vec3 c = base * r.ao;
	float lit = rock_lit_mask(light, fw);
	// Bedding: the photographs carry the real layering; these are the 7.3 m geological bands (a share of the old +-14 % tint), an
	// under-ledge line and an upper lip, faded out when a band is under about 4 pixels, and on the faces the 263 m mask leaves bare.
	float ph = rock_bed_phase(wp, r, thick);
	float pfw = fwidth(ph);
	float vis = steep * rock_bed_faces(wp) * (1.0 - smoothstep(0.12, 0.25, pfw)) * 0.5;
	float band = floor(ph);
	float lvl = floor(rockHash(vec2(band, 3.0)) * 2.999);
	vec3 tint = lvl < 0.5 ? R0 : (lvl < 1.5 ? R2 : R1);
	vec3 rel = tint / ((R0 + R1 + R2) / 3.0);
	c *= mix(vec3(1.0), (1.0 + ROCK_BED_VALUE * (lvl - 1.0)) * mix(vec3(1.0), rel, 0.3), vis);
	float b = fract(ph);
	c *= 1.0 - 0.28 * vis * (1.0 - smoothstep(0.0, ROCK_BED_LEDGE, b));
	c *= 1.0 + 0.12 * vis * lit * smoothstep(1.0 - ROCK_BED_LEDGE, 1.0, b);
	c *= 1.0 + ROCK_TOP_LIGHT * smoothstep(0.62, 0.70, r.plate) * lit;
	c *= mix(ROCK_SHADE, ROCK_LIT, lit) * ph_ramp(light, rock_light_step(light, fw));
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

// Scree: gravel sheet, and the coarser debris sheet where a deposition fan lies (a fixed crossfade, a continuously scaled tile would swim).
struct ScreeTex {
	float height;
	float open;
	vec3 tilt;
	vec3 col;
};

ScreeTex scree_sample(MapCtx mc, RockTex r, float dist, float fan) {
	ScreeTex s;
	PhMat g = ph_material(PH_SCREE, PH_MEAN_SCREE, mc, PH_TILE_SCREE, dist, vec2(0.13, 0.41), false);
	s.col = ph_tint(SCREE, g.ratio);
	s.height = g.h;
	s.tilt = g.tilt;
	if (fan > 0.02) {
		PhMat t = ph_material(PH_TALUS, PH_MEAN_TALUS, mc, PH_TILE_TALUS, dist, vec2(0.57, 0.29), false);
		float f = fan * 0.85;
		s.col = mix(s.col, ph_tint(SCREE * vec3(1.12, 1.0, 0.82), t.ratio), f);
		s.height = mix(s.height, t.h, f);
		s.tilt = mix(s.tilt, t.tilt, f);
	}
	s.open = ph_ao(s.height);
	return s;
}

vec3 scree_shade(vec3 rock_c, ScreeTex s, float light, float fw, float fan) {
	vec3 base = s.col * s.open * ph_ramp(light, rock_light_step(light, fw)) * GRASS * mix(1.0, SCREE_FAN_LIGHT, fan);
	return min(mix(rock_c, base, SCREE_ROCK_MIX), vec3(ROCK_MAX));
}

// Height blend of the six material weights (meadow, rock, scree, volcanic, sand, snow): w' = max(w + 0.5 H - max(w + 0.5 H) +
// 0.18, 0), so rock pokes through scree and scree fills cracks, with boundaries as sharp as the sheet's cracks instead of a
// 3.5 m ramp. Only materials present in the cell take part. Then the snow gate: snow only rests where the DETAIL normal is
// flatter than about 55 degrees, the rest falls back to rock, and rock near the classifier's line is dusted on up-facing
// ledges. `plate` is the macro height 0..1, `grass` the grass mask.
void rock_blend(inout float w[6], float plate, float scree_h, float grass, vec3 nd, vec3 gn, vec3 wp, float dist, bool blend) {
	if (blend) {
		// The sheets' heights decide the borders only where a texel is bigger than a pixel: beyond a few hundred metres they would break every border into noise.
		float bias = ROCK_BLEND_BIAS * (1.0 - smoothstep(PH_BLEND_NEAR, PH_BLEND_FAR, dist));
		float hh[6];
		hh[0] = 0.5 + 0.5 * grass;
		hh[1] = plate;
		hh[2] = scree_h;
		hh[3] = 0.5;
		hh[4] = 0.5;
		hh[5] = 0.5;
		float hw[6];
		float m = -10.0;
		for (int i = 0; i < 6; i++) {
			hw[i] = w[i] > 0.001 ? w[i] + bias * hh[i] : -10.0;
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
