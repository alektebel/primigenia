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
// 6 = masks (R rock, G snow, B steeper than 55 degrees), 7 = the same with the pre-blend snow, 10 / 11 = material weights after / before the height blend, 8 = ramp bands of the rock light (flicker test), 9 = relief channels.
uniform int rock_debug = 0;

varying vec3 wp;

// Geomorph (terrain_chunks.gd): this LOD's grid step in cells and the distance T at which the chunk drops to the next LOD
// (0 for the coarsest). Vertices slide onto the coarser lattice between 0.6 T and 0.9 T, so a switch (at 0.9 T down, 1.1 T up)
// happens between identical surfaces and does not pop.
uniform int lod_step = 1;
uniform float morph_range = 0.0;

void vertex() {
	// UV2.x = 1 marks skirt vertices; UV2.y carries the skirt depth in metres.
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ivec2 ij = clamp(ivec2(round((xz + MAP_HALF) / MAP_CELL - 0.5)), ivec2(0), ivec2(MAP_N - 1));
	float hv = texelFetch(height_tex, ij, 0).r;
	if (morph_range > 0.0) {
		float d = distance(vec3(xz.x, hv, xz.y), CAMERA_POSITION_WORLD);
		float t = smoothstep(0.6 * morph_range, 0.9 * morph_range, d);
		if (t > 0.0) {
			hv = mix(hv, ground_coarse(xz, lod_step * 2), t);
		}
	}
	VERTEX.y = hv - UV2.x * UV2.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Material weights of the fragment: the generator's bilinear cell weights, the height blend and the snow gate when a rock
// sample is taken (any rock, scree, volcanic or snow weight, or a steep meadow face). `rt` is valid when it returns true.
bool terrain_weights(vec3 gn, float steep, float wet, float grass, float dist, MapCtx mc, vec2 xz, bool blend, out float w[6], out RockTex rt) {
	material_weights(xz, w);
	float turf_slope = smoothstep(0.74, 0.94, gn.y);
	rt = RockTex(0.0, 0.5, 0.5, 1.0, vec3(0.0));
	if (w[1] + w[2] + w[3] + w[5] + w[0] * (1.0 - turf_slope) <= 0.001) {
		return false;
	}
	rt = rock_sample(mc, dist, wet, steep);
	rock_blend(w, rt.plate, grass, normalize(gn + rt.tilt), gn, wp, blend);
	return true;
}

void fragment() {
	vec2 xz = wp.xz;
	vec3 gn = ground_normal(xz);
	if (rock_debug > 0) {
		vec3 dbg = vec3(0.0);
		if (rock_debug == 1) {
			dbg = map_checker(map_ctx(wp, gn), 4.0);
		} else if (rock_debug == 2) {
			dbg = map_weights(gn);
		} else if (rock_debug == 3) {
			// Strata: R cap rock, G bedding visibility (faces the mask leaves bare are 0), B fract(bedding phase).
			RockTex rt3 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0);
			dbg = vec3(rock_cap(wp), rock_bed_faces(wp), fract(rock_bed_phase(wp, rt3, 1.0)));
		} else if (rock_debug == 4) {
			RockTex rt4 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0);
			dbg = vec3(dot(normalize(gn + rt4.tilt), SUN_DIR) * 0.5 + 0.5);
		} else if (rock_debug == 9) {
			dbg = texture(relief_tex, (xz + MAP_HALF) / (MAP_CELL * float(MAP_N))).rgb;   // R fine, G broad curvature, B sediment
		} else if (rock_debug == 8) {
			// Ramp bands of the rock light (the toon steps), for the flicker test: R above 0.17, G above 0.55, B lit mask.
			RockTex rt8 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0);
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
			float steep6 = 1.0 - smoothstep(0.48, 0.76, gn.y);
			terrain_weights(gn, steep6, 0.0, surface_bilinear(xz).g, distance(wp, CAMERA_POSITION_WORLD), map_ctx(wp, gn), xz, true, wt, rtd);
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
			float steepb = 1.0 - smoothstep(0.48, 0.76, gn.y);
			terrain_weights(gn, steepb, 0.0, surface_bilinear(xz).g, distance(wp, CAMERA_POSITION_WORLD), map_ctx(wp, gn), xz, rock_debug == 10, wb, rtb);
			float ts = smoothstep(0.74, 0.94, gn.y);
			dbg = vec3(wb[1] + wb[0] * (1.0 - ts), wb[2], wb[0] * ts);
		} else if (rock_debug == 9) {
			dbg = texture(relief_tex, (xz + MAP_HALF) / (MAP_CELL * float(MAP_N))).rgb;   // R fine, G broad curvature, B sediment
		} else if (rock_debug == 8) {
			// Ramp bands of the rock light (the toon steps), for the flicker test: R above 0.17, G above 0.55, B lit mask.
			RockTex rt8 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD), 0.0, 0.0);
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
		float dist = distance(wp, CAMERA_POSITION_WORLD);
		MapCtx mc = map_ctx(wp, gn);
		float steep = 1.0 - smoothstep(0.48, 0.76, gn.y);
		float w[6];
		RockTex rt;
		bool have_rock = terrain_weights(gn, steep, wet, sb.g, dist, mc, xz, true, w, rt);
		// Meadow colour only where something reads it (the meadow weight, the grass mask or a fan toe): far mountains skip it.
		vec3 meadow = vec3(0.0);
		if (w[0] + sb.g > 0.001) {
			meadow = meadowColor(tone(xz), 1.0, light, wave, xz) * vec3(0.6, 0.68, 0.54) * mix(SH_K, 1.0, msh);
			meadow *= mix(S_TINT, vec3(1.0), msh);
		}
		float turf_slope = smoothstep(0.74, 0.94, gn.y);
		float w_meadow = w[0] * turf_slope;
		float w_rock = w[1] + w[0] * (1.0 - turf_slope);
		vec3 rock_c = vec3(0.0);
		vec3 scree_c = vec3(0.0);
		vec3 volc_c = vec3(0.0);
		float fan = smoothstep(0.25, 0.75, rl.b);
		float snow_light = light;
		if (have_rock) {
			float fw;
			float rlight = rock_light(gn, rt.tilt, fw) * vis;
			snow_light = rlight;
			rock_c = rock_shade(R0, R1, rt, rlight, fw, steep, cavity, wp, 1.0, true, rl, wet) * GRASS;
			if (w[2] > 0.001) {
				ScreeTex st = scree_sample(mc, rt, dist, fan);
				float sfw;
				float sl = rock_light(gn, st.tilt, sfw) * vis;
				scree_c = scree_shade(rock_c, st, sl, sfw, fan);
			}
			if (w[3] > 0.001) {
				volc_c = rock_shade(VOLCANIC_R0, VOLCANIC_R1, rt, rlight, fw, steep, cavity, wp, 2.0, false, rl, wet) * GRASS;
			}
		}
		vec3 sand_c = SAND * landRamp(light) * GRASS;
		vec3 snow_c = SNOW * landRamp(snow_light) * GRASS;

		vec3 land = w_meadow * meadow + w_rock * rock_c + w[2] * scree_c + w[3] * volc_c + w[4] * sand_c + w[5] * snow_c;
		// Sparse turf creeping onto the toe of a scree fan, only where meadow borders it.
		float toe = fan * smoothstep(SCREE_TOE_SLOPE - 0.05, SCREE_TOE_SLOPE + 0.04, gn.y) * smoothstep(0.55, 0.7, landNoise(xz * 0.21)) * smoothstep(0.0, 0.25, w[0]) * w[2];
		land = mix(land, meadow, max(sb.g, toe * 0.7));
		land *= mix(vec3(1.0), WET_TINT, smoothstep(0.0, 0.4, wet) * 0.6);
		// River channels: only a faint dark-green trace through the meadow (the hero shows none), not a blue strip.
		land = mix(land, CHANNEL * landRamp(light), smoothstep(0.4, 0.6, wet) * 0.1);
		ALBEDO = scene_out(land, wp, CAMERA_POSITION_WORLD);
		if (lod_debug > 0.5) {
			ALBEDO = godot_albedo(mix(land, lod_color, 0.7));   // no haze: LOD colours stay readable
		}
	}
}
