// Photographic ground materials (docs/godot/ROCK.md, "Photographic materials"): eight CC0 ambientCG materials in two 2D arrays,
// read through the rock mapping (rock_mapping.gdshaderinc: biplanar by default, triplanar in the High tier), with no visible repetition
// (two taps per fetch that blend two random shifts of the sheet, Quilez's "virtual pattern"; two scales; a distance fade), and turned into
// a colour RATIO (texel / the sheet's mean), so the island's palette keeps its colour mood and the photograph only supplies the local
// variation (flecks, cracks, grain). Include after rock_mapping.gdshaderinc and rockNoise (rock.gdshaderinc).
//
// ph_alb: sRGB albedo (decoded in ph_tap: the sampler's own conversion is not relied on), ph_pk: R,G tangent-space normal xy (OpenGL, +y up in the image), B height (1st..99th percentile stretch).
// The arrays are sliced from 4x2 atlases of 1024 tiles (tools/bake_photo_textures.py); layer = row * 4 + column.

// Anisotropic in every tier: the ground is mostly seen at a grazing angle, where trilinear blurs the photograph into streaks.
uniform sampler2DArray ph_alb : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ph_pk : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int ph_synth = 0;   // tests: 1 = every tap returns a synthetic horizontal ridge (one per tile, v = 0.5) instead of the sheets

const float PH_ANDESITE = 0.0;
const float PH_STRATA = 1.0;
const float PH_BASALT = 2.0;
const float PH_TUFF = 3.0;
const float PH_SCREE = 4.0;
const float PH_TALUS = 5.0;
const float PH_SOIL = 6.0;
const float PH_SEDIMENT = 7.0;

// Mean linear albedo of each sheet (tools/bake_photo_textures.py prints them).
const vec3 PH_MEAN_ANDESITE = vec3(0.2713, 0.2714, 0.2503);
const vec3 PH_MEAN_STRATA = vec3(0.1334, 0.1320, 0.1260);
const vec3 PH_MEAN_BASALT = vec3(0.1073, 0.1054, 0.0995);
const vec3 PH_MEAN_TUFF = vec3(0.1101, 0.0810, 0.0681);
const vec3 PH_MEAN_SCREE = vec3(0.1329, 0.1325, 0.1117);
const vec3 PH_MEAN_TALUS = vec3(0.2113, 0.1667, 0.1072);
const vec3 PH_MEAN_SOIL = vec3(0.2601, 0.1956, 0.1804);
const vec3 PH_MEAN_SEDIMENT = vec3(0.4616, 0.3181, 0.1725);

// World metres per tile of the close scale (a sheet shows roughly 1 to 1.5 m of real rock). The macro scale is PH_MACRO_K times larger and is the only one beyond PH_NEAR_FAR.
const float PH_TILE_ANDESITE = 1.7;
const float PH_TILE_STRATA = 2.4;
const float PH_TILE_BASALT = 2.0;
const float PH_TILE_TUFF = 3.0;
const float PH_TILE_SCREE = 1.0;
const float PH_TILE_TALUS = 1.4;
const float PH_TILE_SOIL = 1.2;
const float PH_TILE_SEDIMENT = 1.3;
const float PH_MACRO_K = 7.0;
const float PH_NEAR_START = 30.0;       // the close scale fades out between these distances (m)
const float PH_NEAR_FAR = 110.0;
const float PH_MACRO_START = 700.0;     // the macro scale fades to "no variation" between these; beyond the far one no fetch is made
const float PH_MACRO_FAR = 1500.0;
const float PH_NEAR_COLOR = 0.7;        // share of the close scale in the colour ratio where it is present
const float PH_N_NEAR = 0.6;            // detail normal strength per scale (tilt added to the face normal)
const float PH_N_MACRO = 0.5;
const float PH_CHROMA = 0.75;           // how much of the texel's hue variation survives the palette
const float PH_RATIO_MIN = 0.3;
const float PH_RATIO_MAX = 2.4;
const float PH_AO_DEPTH = 0.4;          // darkest occlusion in the lowest parts of the height map
const float PH_SOFT = 0.75;             // share of the smooth light ramp against the toon steps on photographic materials

struct PhMat {
	vec3 ratio;   // albedo / mean, about 1
	float h;      // 0..1, 0.5 where nothing is sampled
	vec3 tilt;    // -grad h as a world vector, strengths applied
};

// One stochastic fetch: albedo (linear) and pack at uv, from two random shifts of the sheet blended by a low-frequency noise.
void ph_tap(float layer, vec2 uv, vec2 dx, vec2 dy, out vec3 a, out vec3 p) {
	if (ph_synth > 0) {
		float v = fract(uv.y) - 0.5;
		float hh = exp(-pow(v / 0.06, 2.0));
		float g = -2.0 * v / (0.06 * 0.06) * hh * 0.06;   // slope of the ridge per unit v, scaled to about 1 at its flanks
		a = vec3(0.5);
		p = vec3(0.5, 0.5 + 0.5 * clamp(g * 0.5, -1.0, 1.0), hh);   // green = +dh/dv (see ph_layer)
		return;
	}
	float idx = rockNoise(uv * 0.19 + layer * 5.1) * 6.0;
	float i = floor(idx);
	float f = fract(idx);
	vec2 oa = sin(vec2(3.0, 7.0) * (i + layer * 1.7));
	vec2 ob = sin(vec2(3.0, 7.0) * (i + 1.0 + layer * 1.7));
	vec3 a0 = textureGrad(ph_alb, vec3(uv + oa, layer), dx, dy).rgb;
	vec3 a1 = textureGrad(ph_alb, vec3(uv + ob, layer), dx, dy).rgb;
	vec3 p0 = textureGrad(ph_pk, vec3(uv + oa, layer), dx, dy).rgb;
	vec3 p1 = textureGrad(ph_pk, vec3(uv + ob, layer), dx, dy).rgb;
	float t = smoothstep(0.36, 0.64, f - 0.06 * (a0.r + a0.g + a0.b - a1.r - a1.g - a1.b));
	a = mix(a0, a1, t);
	a = a * (a * (a * 0.305306011 + 0.682171111) + 0.012522878);   // sRGB -> linear (Godot's own polynomial)
	p = mix(p0, p1, t);
}

// All projections of one layer at one scale: albedo, height and world tilt of the detail normal.
void ph_layer(float layer, MapCtx c, float inv_tile, vec2 off, out vec3 a, out float h, out vec3 tilt) {
	a = vec3(0.0);
	h = 0.0;
	tilt = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		if (c.w[k] > 0.0005) {
			vec3 ak;
			vec3 pk;
			ph_tap(layer, map_uv(c.p, k) * inv_tile + off, map_uv(c.dpx, k) * inv_tile, map_uv(c.dpy, k) * inv_tile, ak, pk);
			vec2 n = pk.rg * 2.0 - 1.0;
			float nz = sqrt(max(1.0 - dot(n, n), 0.09));
			vec2 d = vec2(n.x, -n.y) / nz;   // (-dh/du, -dh/dv): the image's green is +y up, v runs down
			vec3 tl = k == 0 ? vec3(0.0, -d.y, d.x) : (k == 1 ? vec3(d.x, 0.0, d.y) : vec3(d.x, -d.y, 0.0));
			a += c.w[k] * ak;
			h += c.w[k] * pk.b;
			tilt += c.w[k] * tl;
		}
	}
}

// One material at both scales. `mean` normalises the albedo into a ratio. Cheap exit (ratio 1, h 0.5, no tilt) far away.
PhMat ph_material(float layer, vec3 mean, MapCtx mc, float tile, float dist, vec2 off) {
	PhMat m;
	m.ratio = vec3(1.0);
	m.h = 0.5;
	m.tilt = vec3(0.0);
	if (dist >= PH_MACRO_FAR) {
		return m;
	}
	float fm = 1.0 - smoothstep(PH_MACRO_START, PH_MACRO_FAR, dist);
	vec3 a;
	float h;
	vec3 t;
	ph_layer(layer, mc, 1.0 / (tile * PH_MACRO_K), off, a, h, t);
	vec3 r = clamp(a / mean, vec3(PH_RATIO_MIN), vec3(PH_RATIO_MAX));
	m.ratio = mix(vec3(1.0), r, fm);
	m.h = h;
	m.tilt = t * PH_N_MACRO;
#if ROCK_TIER >= 2
	if (dist < PH_NEAR_FAR && ph_synth == 0) {
		float fa = 1.0 - smoothstep(PH_NEAR_START, PH_NEAR_FAR, dist);
		ph_layer(layer, mc, 1.0 / tile, off + vec2(0.37, 0.61), a, h, t);
		vec3 r2 = clamp(a / mean, vec3(PH_RATIO_MIN), vec3(PH_RATIO_MAX));
		m.ratio = mix(m.ratio, r2, fa * PH_NEAR_COLOR);
		m.h = mix(m.h, h, fa * 0.75);
		m.tilt += t * PH_N_NEAR * fa;
	}
#endif
	return m;
}

// The palette colour carrying the photograph's local variation: the ratio's brightness in full, its hue by PH_CHROMA.
vec3 ph_tint(vec3 pal, vec3 ratio) {
	float l = dot(ratio, vec3(0.2126, 0.7152, 0.0722));
	return pal * mix(vec3(l), ratio, PH_CHROMA);
}

// Smooth light ramp that replaces most of the toon steps on photographic materials (same 0.36 floor, same 1.4 at full light).
float ph_ramp(float light, float toon) {
	return mix(toon, 0.36 + 1.12 * (1.0 - exp(-3.0 * light)), PH_SOFT);
}

// Cavity occlusion from a 0..1 height: the lowest texels darken (the bottom of cracks and pits).
float ph_ao(float h) {
	return mix(1.0 - PH_AO_DEPTH, 1.12, smoothstep(0.05, 0.75, h));
}

const float PH_SOIL_SHARE = 0.6;                     // of the steep-meadow weight that shows soil rather than rock (on gentle faces)
const vec3 PH_SOIL_PAL = vec3(0.19, 0.135, 0.095);   // volcanic soil, a warm dark brown between R2 and VOLCANIC_R1
const vec3 PH_BANK_GRAVEL = vec3(0.17, 0.155, 0.13);   // wet river gravel (the wet tint is applied after)
const vec3 PH_BANK_SILT = vec3(0.26, 0.21, 0.15);     // fine sediment between the bars
