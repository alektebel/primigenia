shader_type spatial;
render_mode unshaded, cull_back;
// GPU-displaced geomipmapped terrain: flat grid chunks, heights from height_tex.
#include "res://game/shaders/land.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"
#include "res://game/shaders/rock_mapping.gdshaderinc"
#include "res://game/shaders/rock.gdshaderinc"

uniform vec3 lod_color = vec3(0.0);
uniform float lod_debug : hint_range(0.0, 1.0) = 0.0;
// 0 off, 1 = 4 m grid through the active mapping (R, G sawtooth of u, v; B checker), 2 = mapping weights,
// 3 = relief channels, 4 = rock light with the detail normal (unclamped), 5 = legacy planar xz grid (the old mapping, for the stretch test),
// 6 = masks (R rock, G snow, B steeper than 55 degrees), 8 = ramp bands of the rock light (flicker test).
uniform int rock_debug = 0;

varying vec3 wp;

void vertex() {
	// UV2.x = 1 marks skirt vertices; UV2.y carries the skirt depth in metres.
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ivec2 ij = clamp(ivec2(round((xz + MAP_HALF) / MAP_CELL - 0.5)), ivec2(0), ivec2(MAP_N - 1));
	VERTEX.y = texelFetch(height_tex, ij, 0).r - UV2.x * UV2.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
			dbg = surface_bilinear(xz).rgb;
		} else if (rock_debug == 4) {
			RockTex rt4 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD));
			dbg = vec3(dot(normalize(gn + rt4.tilt), SUN_DIR) * 0.5 + 0.5);
		} else if (rock_debug == 8) {
			// Ramp bands of the rock light (the toon steps), for the flicker test: R above 0.17, G above 0.55, B lit mask.
			RockTex rt8 = rock_sample(map_ctx(wp, gn), distance(wp, CAMERA_POSITION_WORLD));
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
		float light = max(dot(gn, SUN_DIR), 0.0);
		float wave = meadowWave(xz, TIME);
		float msh = occluder_shadow(wp);
		vec4 sb = surface_bilinear(xz);   // G grass, B cavity, A wetness
		float cavity = sb.b;
		float wet = sb.a;
		float w[6];
		material_weights(xz, w);

		float dist = distance(wp, CAMERA_POSITION_WORLD);
		MapCtx mc = map_ctx(wp, gn);
		vec3 meadow = meadowColor(tone(xz), 1.0, light, wave, xz) * vec3(0.6, 0.68, 0.54) * mix(SH_K, 1.0, msh);
		meadow *= mix(S_TINT, vec3(1.0), msh);
		float steep = 1.0 - smoothstep(0.48, 0.76, gn.y);
		float turf_slope = smoothstep(0.74, 0.94, gn.y);
		float w_meadow = w[0] * turf_slope;
		float w_rock = w[1] + w[0] * (1.0 - turf_slope);
		vec3 rock_c = vec3(0.0);
		vec3 scree_c = vec3(0.0);
		vec3 volc_c = vec3(0.0);
		if (w_rock + w[2] + w[3] > 0.001) {
			RockTex rt = rock_sample(mc, dist);
			float fw;
			float rl = rock_light(gn, rt.tilt, fw);
			rock_c = rock_shade(R0, R1, rt, rl, fw, steep, cavity) * GRASS;
			if (w[2] > 0.001) {
				ScreeTex st = scree_sample(mc, rt, dist);
				float sfw;
				float sl = rock_light(gn, st.tilt, sfw);
				scree_c = scree_shade(rock_c, st, sl, sfw);
			}
			if (w[3] > 0.001) {
				volc_c = rock_shade(VOLCANIC_R0, VOLCANIC_R1, rt, rl, fw, steep, cavity) * GRASS;
			}
		}
		vec3 sand_c = SAND * landRamp(light) * GRASS;
		vec3 snow_c = SNOW * landRamp(light) * GRASS;

		vec3 land = w_meadow * meadow + w_rock * rock_c + w[2] * scree_c + w[3] * volc_c + w[4] * sand_c + w[5] * snow_c;
		land = mix(land, meadow, sb.g);
		land *= mix(vec3(1.0), WET_TINT, smoothstep(0.0, 0.4, wet) * 0.6);
		// River channels: only a faint dark-green trace through the meadow (the hero shows none), not a blue strip.
		land = mix(land, CHANNEL * landRamp(light), smoothstep(0.4, 0.6, wet) * 0.1);
		ALBEDO = scene_out(land, wp, CAMERA_POSITION_WORLD);
		if (lod_debug > 0.5) {
			ALBEDO = godot_albedo(mix(land, lod_color, 0.7));   // no haze: LOD colours stay readable
		}
	}
}
