// Mapping of rock and scree detail (docs/godot/PLAN-rock.md section 2): biplanar (default) or triplanar (High tier,
// `#define MAP_TRIPLANAR`), driven by the macro normal. Planar xz stretched every feature 2x down a 60 degree face.
//
// Conventions, written once here. Axis 0 (x) uses uv = (p.z, -p.y), axis 1 (y) uses (p.x, p.z), axis 2 (z) uses (p.x, -p.y).
// On both side projections image v points down, as world y does, so a texture painted with horizontal layers is horizontal
// on every cliff. Detail textures hold -grad(h) in (u, v), so a texel's RG converts to a world-space tilt with map_tilt().
//
// Include this file after the uniforms it needs; it declares none.

const float MAP_SHARP = 8.0;    // Quilez's k: weights are ((|n| - 0.5773) / 0.4227) ^ (k / 8)
const float MAP_ORTHO = 0.5773; // 1 / sqrt(3): below it an axis gets no weight

struct MapCtx {
	vec3 p;
	vec3 dpx;
	vec3 dpy;
	vec3 w;      // weight per projection axis; at most two are non-zero in biplanar mode
};

vec2 map_uv(vec3 p, int axis) {
	if (axis == 0) {
		return vec2(p.z, -p.y);
	}
	if (axis == 1) {
		return vec2(p.x, p.z);
	}
	return vec2(p.x, -p.y);
}

// Weights from the MACRO normal (never from a detail normal, so they cannot flicker).
vec3 map_weights(vec3 n) {
	vec3 a = abs(n);
#ifdef MAP_TRIPLANAR
	vec3 w = pow(a, vec3(MAP_SHARP * 0.5));
#else
	// Only the two largest components can exceed 1/sqrt(3), so this is the biplanar pair without sorting.
	vec3 w = pow(clamp((a - MAP_ORTHO) / (1.0 - MAP_ORTHO), 0.0, 1.0), vec3(MAP_SHARP / 8.0));
#endif
	return w / max(w.x + w.y + w.z, 1e-5);
}

MapCtx map_ctx(vec3 p, vec3 n) {
	MapCtx c;
	c.p = p;
	c.dpx = dFdx(p);
	c.dpy = dFdy(p);
	c.w = map_weights(n);
	return c;
}

// Blended sample of one layer. Derivatives come from the continuous world position, so there is no mip seam where the
// dominant axis changes, and the call is safe inside non-uniform branches (distance fades).
// `blur` scales the gradients (a higher mip, for broad low-contrast patches); 1 is the exact footprint.
vec4 map_tex_blur(sampler2D t, MapCtx c, float inv_tile, vec2 off, float blur) {
	vec4 s = vec4(0.0);
	for (int k = 0; k < 3; k++) {
		if (c.w[k] > 0.0005) {
			s += c.w[k] * textureGrad(t, map_uv(c.p, k) * inv_tile + off, map_uv(c.dpx, k) * inv_tile * blur, map_uv(c.dpy, k) * inv_tile * blur);
		}
	}
	return s;
}

vec4 map_tex(sampler2D t, MapCtx c, float inv_tile, vec2 off) {
	return map_tex_blur(t, c, inv_tile, off, 1.0);
}

// Colour sample and tilt in one pass (one fetch per projection). `tilt` is the blended world-space -grad h.
vec4 map_tex_tilt(sampler2D t, MapCtx c, float inv_tile, vec2 off, out vec3 tilt) {
	vec4 s = vec4(0.0);
	tilt = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		if (c.w[k] > 0.0005) {
			vec4 v = textureGrad(t, map_uv(c.p, k) * inv_tile + off, map_uv(c.dpx, k) * inv_tile, map_uv(c.dpy, k) * inv_tile);
			vec2 d = v.rg * 2.0 - 1.0;
			vec3 tl = k == 0 ? vec3(0.0, -d.y, d.x) : (k == 1 ? vec3(d.x, 0.0, d.y) : vec3(d.x, -d.y, 0.0));
			s += c.w[k] * v;
			tilt += c.w[k] * tl;
		}
	}
	return s;
}

// World-space tilt (-grad h) from a decoded detail normal d = (-dh/du, -dh/dv), per projection, blended.
// Height h is displacement along the face normal, so the same formula holds on both faces of an axis.
vec3 map_tilt(sampler2D t, MapCtx c, float inv_tile, vec2 off) {
	vec3 sum = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		if (c.w[k] > 0.0005) {
			vec2 d = textureGrad(t, map_uv(c.p, k) * inv_tile + off, map_uv(c.dpx, k) * inv_tile, map_uv(c.dpy, k) * inv_tile).rg * 2.0 - 1.0;
			vec3 tilt = k == 0 ? vec3(0.0, -d.y, d.x) : (k == 1 ? vec3(d.x, 0.0, d.y) : vec3(d.x, -d.y, 0.0));
			sum += c.w[k] * tilt;
		}
	}
	return sum;
}

// UDN blend: add the tilt to the macro normal.
vec3 map_apply_tilt(vec3 n, vec3 tilt, float strength) {
	return normalize(n + strength * tilt);
}

// Debug: R = fract(u / size), G = fract(v / size), B = checker, blended through the active mapping.
vec3 map_checker(MapCtx c, float size) {
	vec3 s = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		if (c.w[k] > 0.0005) {
			vec2 uv = map_uv(c.p, k) / size;
			s += c.w[k] * vec3(fract(uv.x), fract(uv.y), mod(floor(uv.x) + floor(uv.y), 2.0));
		}
	}
	return s;
}
