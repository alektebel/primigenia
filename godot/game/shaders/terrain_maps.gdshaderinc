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

// Smooth shading normal: Catmull-Rom (C1) bicubic gradient of the height texels. The geometry stays the exact triangle surface
// (so the C world and GDScript ground() agree to the millimetre); only the shading is smoothed, which removes the facets.
vec3 ground_normal(vec2 xz) {
	vec2 uv = (xz + MAP_HALF) / MAP_CELL - 0.5;
	ivec2 i = ivec2(floor(uv));
	vec2 f = uv - vec2(i);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec4 wx = vec4(-f3.x + 2.0 * f2.x - f.x, 3.0 * f3.x - 5.0 * f2.x + 2.0, -3.0 * f3.x + 4.0 * f2.x + f.x, f3.x - f2.x) * 0.5;
	vec4 wy = vec4(-f3.y + 2.0 * f2.y - f.y, 3.0 * f3.y - 5.0 * f2.y + 2.0, -3.0 * f3.y + 4.0 * f2.y + f.y, f3.y - f2.y) * 0.5;
	vec4 dx = vec4(-3.0 * f2.x + 4.0 * f.x - 1.0, 9.0 * f2.x - 10.0 * f.x, -9.0 * f2.x + 8.0 * f.x + 1.0, 3.0 * f2.x - 2.0 * f.x) * 0.5;
	vec4 dy = vec4(-3.0 * f2.y + 4.0 * f.y - 1.0, 9.0 * f2.y - 10.0 * f.y, -9.0 * f2.y + 8.0 * f.y + 1.0, 3.0 * f2.y - 2.0 * f.y) * 0.5;
	float gx = 0.0;
	float gz = 0.0;
	for (int b = 0; b < 4; b++) {
		vec4 row = vec4(map_h(i + ivec2(-1, b - 1)), map_h(i + ivec2(0, b - 1)), map_h(i + ivec2(1, b - 1)), map_h(i + ivec2(2, b - 1)));
		gx += dot(dx, row) * wy[b];
		gz += dot(wx, row) * dy[b];
	}
	return normalize(vec3(-gx / MAP_CELL, 1.0, -gz / MAP_CELL));
}

// Height at xz of the coarse lattice of `step` cells (same diagonal as ground_tri): the target of the vertex geomorph.
float ground_coarse(vec2 xz, int step) {
	vec2 uv = (xz + MAP_HALF) / MAP_CELL - 0.5;
	float fs = float(step);
	ivec2 i0 = clamp(ivec2(floor(uv / fs)) * step, ivec2(0), ivec2(MAP_N - 1));
	vec2 f = clamp((uv - vec2(i0)) / fs, 0.0, 1.0);
	ivec2 i1 = min(i0 + ivec2(step), ivec2(MAP_N - 1));
	float h00 = map_h(i0);
	float h10 = map_h(ivec2(i1.x, i0.y));
	float h01 = map_h(ivec2(i0.x, i1.y));
	float h11 = map_h(i1);
	return f.x >= f.y ? h00 + f.x * (h10 - h00) + f.y * (h11 - h10) : h00 + f.y * (h01 - h00) + f.x * (h11 - h01);
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
