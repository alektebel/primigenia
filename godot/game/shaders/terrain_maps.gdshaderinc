// Terrain textures and exact ground sampling shared by the terrain, water and grass shaders.
// height_tex / level_tex are FORMAT_RF, surface_tex RGBA8 (R material, G grass, B cavity, A wet).
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D level_tex : filter_nearest, repeat_disable;
uniform sampler2D surface_tex : filter_nearest, repeat_disable;
uniform int MAP_N = 1024;
uniform float MAP_CELL = 3.515625;
uniform float MAP_HALF = 1800.0;

float map_h(ivec2 ij) {
	return texelFetch(height_tex, clamp(ij, ivec2(0), ivec2(MAP_N - 1)), 0).r;
}

// Exact LOD0 surface (same triangle diagonal as TerrainData.ground in GDScript).
float ground_tri(vec2 xz) {
	vec2 uv = (xz + MAP_HALF) / MAP_CELL - 0.5;
	ivec2 i = clamp(ivec2(floor(uv)), ivec2(0), ivec2(MAP_N - 2));
	vec2 f = clamp(uv - vec2(i), 0.0, 1.0);
	float h00 = map_h(i);
	float h10 = map_h(i + ivec2(1, 0));
	float h01 = map_h(i + ivec2(0, 1));
	float h11 = map_h(i + ivec2(1, 1));
	return f.x >= f.y ? h00 + f.x * (h10 - h00) + f.y * (h11 - h10) : h00 + f.y * (h01 - h00) + f.x * (h11 - h01);
}

vec3 ground_normal(vec2 xz) {
	float dx = ground_tri(xz + vec2(MAP_CELL, 0.0)) - ground_tri(xz - vec2(MAP_CELL, 0.0));
	float dz = ground_tri(xz + vec2(0.0, MAP_CELL)) - ground_tri(xz - vec2(0.0, MAP_CELL));
	return normalize(vec3(-dx, 2.0 * MAP_CELL, -dz));
}

// Bilinear blend of the surface texels around xz; also returns the 4 cells for id blending.
vec4 surface_bilinear(vec2 xz) {
	vec2 uv = (xz + MAP_HALF) / MAP_CELL - 0.5;
	ivec2 i = ivec2(floor(uv));
	vec2 f = uv - vec2(i);
	ivec2 hi = ivec2(MAP_N - 1);
	vec4 a = texelFetch(surface_tex, clamp(i, ivec2(0), hi), 0);
	vec4 b = texelFetch(surface_tex, clamp(i + ivec2(1, 0), ivec2(0), hi), 0);
	vec4 c = texelFetch(surface_tex, clamp(i + ivec2(0, 1), ivec2(0), hi), 0);
	vec4 d = texelFetch(surface_tex, clamp(i + ivec2(1, 1), ivec2(0), hi), 0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Material weights (0 meadow, 1 rock, 2 scree, 3 volcanic, 4 sand, 5 snow) from the one-hot ids
// of the 4 nearest cells, bilinearly blended.
void material_weights(vec2 xz, out float w[6]) {
	for (int k = 0; k < 6; k++) {
		w[k] = 0.0;
	}
	vec2 uv = (xz + MAP_HALF) / MAP_CELL - 0.5;
	ivec2 i = ivec2(floor(uv));
	vec2 f = uv - vec2(i);
	ivec2 hi = ivec2(MAP_N - 1);
	for (int q = 0; q < 4; q++) {
		ivec2 o = ivec2(q & 1, q >> 1);
		float wt = (o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y);
		int id = int(round(texelFetch(surface_tex, clamp(i + o, ivec2(0), hi), 0).r * 255.0));
		w[clamp(id, 0, 5)] += wt;
	}
}
