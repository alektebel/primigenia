shader_type spatial;
render_mode unshaded, cull_back;
// GPU-displaced geomipmapped terrain: flat grid chunks, heights from height_tex.
#include "res://game/shaders/land.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"

uniform vec3 lod_color = vec3(0.0);
uniform float lod_debug : hint_range(0.0, 1.0) = 0.0;

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
	float light = max(dot(gn, SUN_DIR), 0.0);
	float wave = meadowWave(xz, TIME);
	float msh = occluder_shadow(wp);
	vec2 jitter = (vec2(landNoise(xz * 0.11), landNoise(xz * 0.11 + 17.0)) - 0.5) * MAP_CELL * 0.8;
	vec4 sb = surface_bilinear(xz);   // G grass, B cavity, A wetness
	float cavity = sb.b;
	float wet = sb.a;
	float w[6];
	material_weights(xz + jitter, w);

	vec3 meadow = meadowColor(tone(xz), 1.0, light, wave, xz) * vec3(0.6, 0.68, 0.54) * mix(SH_K, 1.0, msh);
	meadow *= mix(S_TINT, vec3(1.0), msh);
	float steep = 1.0 - smoothstep(0.48, 0.76, gn.y);
	vec3 rock_c = rock_color(R0, R1, xz, wp, light, steep, cavity) * GRASS;
	float rock_light = 0.36 + 0.56 * smoothstep(0.12, 0.22, light) + 0.48 * smoothstep(0.5, 0.6, light);
	vec3 scree_c = mix(rock_c, SCREE * rock_light * GRASS, 0.85);
	vec3 volc_c = rock_color(VOLCANIC_R0, VOLCANIC_R1, xz, wp, light, steep, cavity) * GRASS;
	vec3 sand_c = SAND * landRamp(light) * GRASS;
	vec3 snow_c = SNOW * landRamp(light) * GRASS;

	float turf_slope = smoothstep(0.74, 0.94, gn.y);
	float w_meadow = w[0] * turf_slope;
	float w_rock = w[1] + w[0] * (1.0 - turf_slope);
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
