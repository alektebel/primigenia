// Body of the terrain shaders (included by terrain_low/medium/high.gdshader, which set shader_type, render_mode and ROCK_TIER).
// GPU-displaced geomipmapped terrain: flat grid chunks, heights from height_tex.
#include "res://game/shaders/land.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"
#include "res://game/shaders/rock_mapping.gdshaderinc"
#include "res://game/shaders/rock.gdshaderinc"

uniform vec3 lod_color = vec3(0.0);
uniform float lod_debug : hint_range(0.0, 1.0) = 0.0;
// 0 off, 1 = 4 m grid through the active mapping (R, G sawtooth of u, v; B checker), 2 = mapping weights,
// 3 = strata (R cap rock, G bedding faces, B bedding phase), 4 = rock light with the detail normal (unclamped), 5 = legacy planar xz grid (the old mapping, for the stretch test),
// 12 = erosion maps (R flow, G deposition, B talus apron), 13 = exposure, 6 = masks (R rock, G snow, B steeper than 55 degrees), 7 = the same with the pre-blend snow, 10 / 11 = material weights after / before the height blend, 8 = ramp bands of the rock light (flicker test), 9 = relief channels.
uniform int rock_debug = 0;

varying vec3 wp;

// Geomorph (terrain_chunks.gd): this LOD's grid step in visual cells and the distance T at which the chunk drops to the next LOD
// (0 for the coarsest). Vertices slide onto the coarser lattice between 0.6 T and 0.9 T, so a switch (at 0.9 T down, 1.1 T up)
// happens between identical surfaces and does not pop.
uniform int lod_step = 1;
uniform float morph_range = 0.0;
uniform float fbm_gain = 1.0;   // tuning: scale of the eroded-fBm normal

void vertex() {
	// UV2.x = 1 marks skirt vertices; UV2.y carries the skirt depth in metres.
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ivec2 ij = clamp(ivec2(round((xz + MAP_HALF) / VIS_CELL - 0.5)), ivec2(0), ivec2(VIS_N - 1));
	float hv = vis_h(ij);
	if (morph_range > 0.0) {
		float d = distance(vec3(xz.x, hv, xz.y), CAMERA_POSITION_WORLD);
		float t = smoothstep(0.6 * morph_range, 0.9 * morph_range, d);
		if (t > 0.0) {
			hv = mix(hv, vground_coarse(xz, lod_step * 2), t);
		}
	}
	VERTEX.y = hv - UV2.x * UV2.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ---- Visual erosion (terrain v5) ----
// Erosion maps: R flow/wetness (gully water), G droplet deposition (sediment fans), B talus apron (scree), A exposure (> 0.5 convex).
const float EROSION_FADE_NEAR = 500.0;   // the maps are 1.8 m texels: their effect fades out between these distances
const float EROSION_FADE_FAR = 1500.0;
// Eroded fBm (derivative-damped fractal noise, I. Quilez): fine rock relief for the normal only, near the camera.
const float FBM_AMP = 0.4;              // metres of height of the first octave
const float FBM_WAVELENGTH = 2.4;
const float FBM_NEAR = 22.0;
const float FBM_FAR = 85.0;

vec4 erosion_maps(vec2 xz, float dist) {
	float f = 1.0 - smoothstep(EROSION_FADE_NEAR, EROSION_FADE_FAR, dist);
	vec4 e = texture(vmaps_tex, (xz + MAP_HALF) / (VIS_CELL * float(VIS_N)));
	return vec4(e.rgb * f, mix(0.5, e.a, f));
}

vec3 fbm_noised(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	float a = rockHash(i);
	float b = rockHash(i + vec2(1.0, 0.0));
	float c = rockHash(i + vec2(0.0, 1.0));
	float d = rockHash(i + vec2(1.0, 1.0));
	return vec3(a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y, du * (vec2(b - a, c - a) + (a - b - c + d) * u.yx));
}

// Gradient (per metre) of the eroded fBm over a plane: each octave's slope is damped by the slope already accumulated, so gullies
// keep smooth floors and ridges stay sharp.
vec2 fbm_eroded_grad(vec2 p) {
	vec2 d = vec2(0.0);
	vec2 g = vec2(0.0);
	float a = FBM_AMP;
	float fr = 1.0 / FBM_WAVELENGTH;
	p *= fr;
	for (int o = 0; o < 3; o++) {
		vec3 n = fbm_noised(p);
		d += (n.yz - vec2(0.0));
		g += a * fr * (n.yz - 0.0) / (1.0 + dot(d, d));
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.0 + vec2(3.7, 1.3);
		a *= 0.5;
		fr *= 2.0;
	}
	return g;
}

// Tilt to add to the macro normal (triplanar on the face normal gn, faded with distance); zero beyond FBM_FAR.
vec3 fbm_tilt(vec3 wpos, vec3 gn, float dist) {
	float f = 1.0 - smoothstep(FBM_NEAR, FBM_FAR, dist);
	if (f <= 0.0) {
		return vec3(0.0);
	}
	vec3 w = pow(abs(gn), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 t = vec3(0.0);
	if (w.y > 0.02) {
		vec2 g = fbm_eroded_grad(wpos.xz);
		t += w.y * vec3(-g.x, 0.0, -g.y);
	}
	if (w.x > 0.02) {
		vec2 g = fbm_eroded_grad(wpos.zy + vec2(17.3, 5.1));
		t += w.x * vec3(0.0, -g.y, -g.x);
	}
	if (w.z > 0.02) {
		vec2 g = fbm_eroded_grad(wpos.xy + vec2(41.7, 23.9));
		t += w.z * vec3(-g.x, -g.y, 0.0);
	}
	return t * f;
}

// Material weights of the fragment: the generator's bilinear cell weights, the height blend and the snow gate when a rock
// sample is taken (any rock, scree, volcanic or snow weight, or a steep meadow face). `rt` / `st` are valid when it returns true
// (`st` only where the scree weight is present).
bool terrain_weights(vec3 gn, float steep, float wet, float grass, float dist, MapCtx mc, vec2 xz, bool blend, vec4 em, float fan, out float w[6], out RockTex rt, out ScreeTex st) {
	// Soften the classification borders (3.5 m cell edges): the lookup is warped by a few metres of low-frequency noise.
	vec2 warp = vec2(landNoise(xz * 0.17), landNoise(xz * 0.17 + 31.7)) - 0.5;
	material_weights(xz + warp * 5.0, w);
	// Scree aprons from the thermal pass: rock below cliffs on stable slopes turns to scree.
	float apron = smoothstep(0.3, 0.7, em.b) * smoothstep(0.55, 0.7, gn.y);
	w[2] += w[1] * apron;
	w[1] -= w[1] * apron;
	float turf_slope = smoothstep(0.74, 0.94, gn.y);
	rt = RockTex(0.0, 0.5, 0.5, 1.0, vec3(0.0), R0, VOLCANIC_R0);
	st = ScreeTex(0.5, 1.0, vec3(0.0), SCREE);
	if (w[1] + w[2] + w[3] + w[5] + w[0] * (1.0 - turf_slope) <= 0.001) {
		return false;
	}
	rt = rock_sample(mc, dist, wet, steep, w[1] + w[5] + w[0] * (1.0 - turf_slope), w[3]);
	if (w[2] > 0.001) {
		st = scree_sample(mc, rt, dist, fan);
	}
#if ROCK_TIER >= 2
	rt.tilt += fbm_gain * fbm_tilt(wp, gn, dist) * (w[1] + w[2] + w[3] + w[0] * (1.0 - turf_slope));
#endif
	rock_blend(w, rt.plate, st.height, grass, normalize(gn + rt.tilt), gn, wp, blend);
	return true;
}

void fragment() {
	vec2 xz = wp.xz;
	float dist0 = distance(wp, CAMERA_POSITION_WORLD);
	vec3 gn = terrain_normal(xz, dist0);
	if (rock_debug > 0) {
		vec3 dbg = vec3(0.0);
		if (rock_debug == 1) {
			dbg = map_checker(map_ctx(wp, gn), 4.0);
		} else if (rock_debug == 2) {
			dbg = map_weights(gn);
		} else if (rock_debug == 3) {
			// Strata: R cap rock, G bedding visibility (faces the mask leaves bare are 0), B fract(bedding phase).
			RockTex rt3 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0, 1.0, 0.0);
			dbg = vec3(rock_cap(wp), rock_bed_faces(wp), fract(rock_bed_phase(wp, rt3, 1.0)));
		} else if (rock_debug == 4) {
			RockTex rt4 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0, 1.0, 0.0);
			dbg = vec3(dot(normalize(gn + rt4.tilt), SUN_DIR) * 0.5 + 0.5);
		} else if (rock_debug == 12) {
			dbg = erosion_maps(xz, 0.0).rgb;   // R flow, G deposition, B talus apron
		} else if (rock_debug == 13) {
			dbg = vec3(erosion_maps(xz, 0.0).a);   // exposure (> 0.5 convex)
		} else if (rock_debug == 9) {
			dbg = texture(relief_tex, (xz + MAP_HALF) / (MAP_CELL * float(MAP_N))).rgb;   // R fine, G broad curvature, B sediment
		} else if (rock_debug == 8) {
			// Ramp bands of the rock light (the toon steps), for the flicker test: R above 0.17, G above 0.55, B lit mask.
			RockTex rt8 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0, 1.0, 0.0);
			float l8 = max(dot(normalize(gn + rt8.tilt), SUN_DIR), 0.0);
			dbg = vec3(step(0.17, l8), step(0.55, l8), step(0.35, l8));
		} else if (rock_debug == 6) {
			// Masks for the evidence metrics: R rock cell (the generator's, unblended), G snow actually drawn, B face steeper than
			// 55 degrees.
			float w6[6];
			material_weights(xz, w6);
			float r6 = step(0.5, w6[1]);
			float wt[6];
			RockTex rtd;
			ScreeTex std_;
			float steep6 = 1.0 - smoothstep(0.48, 0.76, gn.y);
			terrain_weights(gn, steep6, 0.0, surface_bilinear(xz).g, distance(wp, CAMERA_POSITION_WORLD), map_ctx(wp, gn), xz, true, vec4(0.0, 0.0, 0.0, 0.5), 0.0, wt, rtd, std_);
			dbg = vec3(r6, step(0.5, wt[5]), step(gn.y, 0.5736));
		} else if (rock_debug == 7) {
			// Same masks with the pre-step-7 snow (the cell weight, no gate), for the before/after comparison.
			float w7[6];
			material_weights(xz, w7);
			dbg = vec3(step(0.5, w7[1]), step(0.5, w7[5]), step(gn.y, 0.5736));
		} else if (rock_debug == 10 || rock_debug == 11) {
			// Material weights after (10) and before (11) the height blend: R rock (with steep meadow), G scree, B meadow.
			float wb[6];
			RockTex rtb;
			ScreeTex stb;
			float steepb = 1.0 - smoothstep(0.48, 0.76, gn.y);
			terrain_weights(gn, steepb, 0.0, surface_bilinear(xz).g, distance(wp, CAMERA_POSITION_WORLD), map_ctx(wp, gn), xz, rock_debug == 10, vec4(0.0, 0.0, 0.0, 0.5), 0.0, wb, rtb, stb);
			float ts = smoothstep(0.74, 0.94, gn.y);
			dbg = vec3(wb[1] + wb[0] * (1.0 - ts), wb[2], wb[0] * ts);
		} else if (rock_debug == 9) {
			dbg = texture(relief_tex, (xz + MAP_HALF) / (MAP_CELL * float(MAP_N))).rgb;   // R fine, G broad curvature, B sediment
		} else if (rock_debug == 8) {
			// Ramp bands of the rock light (the toon steps), for the flicker test: R above 0.17, G above 0.55, B lit mask.
			RockTex rt8 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0, 1.0, 0.0);
			float l8 = max(dot(normalize(gn + rt8.tilt), SUN_DIR), 0.0);
			dbg = vec3(step(0.17, l8), step(0.55, l8), step(0.35, l8));
		} else if (rock_debug == 6) {
			// Masks for the evidence metrics: R rock cell, G snow, B face steeper than 55 degrees.
			float w6[6];
			material_weights(xz, w6);
			dbg = vec3(step(0.5, w6[1]), step(0.5, w6[5]), step(gn.y, 0.5736));
		} else {
			vec2 g = xz / 4.0;
			dbg = vec3(fract(g.x), fract(g.y), mod(floor(g.x) + floor(g.y), 2.0));
		}
		ALBEDO = min(dbg * 0.97, vec3(0.97));   // raw: read it under a linear tone map (the stretch test does)
	} else {
		vec4 rl = texture(relief_tex, (xz + MAP_HALF) / (MAP_CELL * float(MAP_N)));
		float vis = mix(1.0, rl.a, rock_shadows) * cloud_shadow(wp, SUN_DIR);   // baked terrain shadow (step 9) and the cloud layer's shadow
		float light = max(dot(gn, SUN_DIR), 0.0) * vis;
		float wave = meadowWave(xz, TIME);
		float msh = min(occluder_shadow(wp), vis);
		vec4 sb = surface_bilinear(xz);   // G grass, B cavity, A wetness
		float cavity = sb.b;
		float wet = sb.a;
		float dist = dist0;
		vec4 em = erosion_maps(xz, dist);
		float exposed = smoothstep(0.56, 0.78, em.a) * (1.0 - smoothstep(0.8, 0.95, gn.y));   // convex, not flat: clean rock on ridges
		sb.g *= 1.0 - exposed * 0.7;
		rl.r = clamp(rl.r - (em.a - 0.5) * 0.8, 0.0, 1.0);   // the erosion pass's curvature sharpens the relief cue at 1.8 m
		float wet_rock = max(wet, em.r * 0.85 * smoothstep(0.35, 0.75, 1.0 - gn.y) * (1.0 - exposed));   // gully water on steep ground
		MapCtx mc = map_ctx(wp, gn);
		float steep = 1.0 - smoothstep(0.48, 0.76, gn.y);
		float w[6];
		RockTex rt;
		ScreeTex st;
		float fan = max(smoothstep(0.25, 0.75, rl.b), smoothstep(0.35, 0.85, em.g) * smoothstep(0.7, 0.9, gn.y));
		bool have_rock = terrain_weights(gn, steep, wet_rock, sb.g, dist, mc, xz, true, em, fan, w, rt, st);
		// Meadow colour only where something reads it (the meadow weight, the grass mask or a fan toe): far mountains skip it.
		vec3 meadow = vec3(0.0);
		if (w[0] + sb.g > 0.001) {
			meadow = meadowColor(tone(xz), 1.0, light, wave, xz) * vec3(0.6, 0.68, 0.54) * mix(SH_K, 1.0, msh);
			meadow *= mix(S_TINT, vec3(1.0), msh);
		}
		float turf_slope = smoothstep(0.74, 0.94, gn.y);
		float w_meadow = w[0] * turf_slope;
		// Where the turf gives out on a slope, bare volcanic soil shows before the rock does.
		float w_soil = w[0] * (1.0 - turf_slope) * PH_SOIL_SHARE * (1.0 - steep);
		float w_rock = w[1] + w[0] * (1.0 - turf_slope) - w_soil;
		vec3 rock_c = vec3(0.0);
		vec3 scree_c = vec3(0.0);
		vec3 volc_c = vec3(0.0);
		vec3 soil_c = vec3(0.0);
		float snow_light = light;
		if (have_rock) {
			float fw;
			float rlight = rock_light(gn, rt.tilt, fw) * vis;
			snow_light = rlight;
			rock_c = rock_shade(rt.col, rt, rlight, fw, steep, cavity, wp, 1.0, rl, wet_rock) * GRASS;
			if (w[2] > 0.001) {
				float sfw;
				float sl = rock_light(gn, st.tilt, sfw) * vis;
				scree_c = scree_shade(rock_c, st, sl, sfw, fan);
			}
			if (w[3] > 0.001) {
				volc_c = rock_shade(rt.col_v, rt, rlight, fw, steep, cavity, wp, 2.0, rl, wet_rock) * GRASS;
			}
			if (w_soil > 0.001) {
				PhMat sm = ph_material(PH_SOIL, PH_MEAN_SOIL, mc, PH_TILE_SOIL, dist, vec2(0.29, 0.83));
				float sfw2;
				float sl2 = rock_light(gn, sm.tilt, sfw2) * vis;
				soil_c = ph_tint(PH_SOIL_PAL, sm.ratio) * ph_ao(sm.h) * mix(ROCK_SHADE, ROCK_LIT, rock_lit_mask(sl2, sfw2)) * ph_ramp(sl2, rock_light_step(sl2, sfw2)) * GRASS * mix(1.0, WET_TINT.g * 0.8, smoothstep(0.1, 0.5, wet));
			}
		}
		// Sand: the sediment sheet under the palette's sand.
		vec3 sand_c = vec3(0.0);
		if (w[4] > 0.001) {
			PhMat sd = ph_material(PH_SEDIMENT, PH_MEAN_SEDIMENT, mc, PH_TILE_SEDIMENT, dist, vec2(0.91, 0.13));
			float dfw;
			float dl = rock_light(gn, sd.tilt, dfw) * vis;
			sand_c = ph_tint(SAND, sd.ratio) * ph_ao(sd.h) * ph_ramp(dl, 0.6 + 0.25 * smoothstep(0.18, 0.25, dl) + 0.23 * smoothstep(0.53, 0.61, dl)) * GRASS;
		}
		vec3 snow_c = SNOW * landRamp(snow_light) * GRASS;

		vec3 land = w_meadow * meadow + w_rock * rock_c + w_soil * soil_c + w[2] * scree_c + w[3] * volc_c + w[4] * sand_c + w[5] * snow_c;
		// Sparse turf creeping onto the toe of a scree fan, only where meadow borders it.
		float toe = fan * smoothstep(SCREE_TOE_SLOPE - 0.05, SCREE_TOE_SLOPE + 0.04, gn.y) * smoothstep(0.55, 0.7, landNoise(xz * 0.21)) * smoothstep(0.0, 0.25, w[0]) * w[2];
		land = mix(land, meadow, max(sb.g, toe * 0.7));
		// River and lake banks: wet gravel and sediment instead of a meadow colour fading into the channel (the textures also carry the shore up close).
		float bank = smoothstep(0.22, 0.5, wet) * (1.0 - w[5]) * (1.0 - steep);
		if (bank > 0.01) {
			PhMat bg = ph_material(PH_SCREE, PH_MEAN_SCREE, mc, PH_TILE_SCREE * 1.3, dist, vec2(0.47, 0.77));
			PhMat bs = ph_material(PH_SEDIMENT, PH_MEAN_SEDIMENT, mc, PH_TILE_SEDIMENT, dist, vec2(0.23, 0.59));
			float silt = smoothstep(0.35, 0.65, landNoise(xz * 0.35));   // patches of fine sediment between the gravel bars
			vec3 bt = mix(bg.tilt, bs.tilt, silt);
			float bfw;
			float bl = rock_light(gn, bt, bfw) * vis;
			vec3 bank_c = mix(ph_tint(PH_BANK_GRAVEL, bg.ratio) * ph_ao(bg.h), ph_tint(PH_BANK_SILT, bs.ratio) * ph_ao(bs.h), silt);
			bank_c *= mix(ROCK_SHADE, ROCK_LIT, rock_lit_mask(bl, bfw)) * ph_ramp(bl, rock_light_step(bl, bfw)) * GRASS * 0.8;
			land = mix(land, bank_c, bank * 0.9);
		}
		land *= mix(vec3(1.0), WET_TINT, smoothstep(0.0, 0.4, wet) * 0.6);
		// River channels: only a faint dark-green trace through the meadow (the hero shows none), not a blue strip.
		land = mix(land, CHANNEL * landRamp(light), smoothstep(0.4, 0.6, wet) * 0.1);
		ALBEDO = scene_out(land, wp, CAMERA_POSITION_WORLD);
		if (lod_debug > 0.5) {
			ALBEDO = godot_albedo(mix(land, lod_color, 0.7));   // no haze: LOD colours stay readable
		}
	}
}
