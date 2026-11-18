// Clouds, cloud shadows and the east-valley morning fog (docs/godot/CLOUDS.md). Included through look.gdshaderinc, so the sky,
// terrain, water and grass all see the same weather. Global shader uniforms (project.godot [shader_globals], driven by
// game/island/clouds.gd): cloud_cover 0 clear .. 1 overcast, cloud_time seconds (the wind), sky_tod 0 dawn .. 0.5 midday .. 1 evening
// (tints clouds and fog; the sun direction is fixed by the hero look), fog_amount 0 .. 1 (low fog banks).
global uniform float cloud_cover;
global uniform float cloud_time;
global uniform float sky_tod;
global uniform float fog_amount;

const float CLOUD_ALT = 1800.0;        // base of the cumulus layer, metres
const float CIRRUS_ALT = 7000.0;
const vec2 CLOUD_WIND = vec2(4.8, 3.6); // m/s

float cl_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float cl_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cl_hash(i), cl_hash(i + vec2(1.0, 0.0)), f.x), mix(cl_hash(i + vec2(0.0, 1.0)), cl_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cl_fbm3(vec2 p) {
	return cl_noise(p) * 0.5 + cl_noise(p * 2.03 + 7.1) * 0.3 + cl_noise(p * 4.1 + 3.7) * 0.2;
}

float cl_fbm5(vec2 p) {
	return cl_noise(p) * 0.4 + cl_noise(p * 2.03 + 7.1) * 0.27 + cl_noise(p * 4.1 + 3.7) * 0.18 + cl_noise(p * 8.3 + 1.3) * 0.1 + cl_noise(p * 16.7 + 5.9) * 0.05;
}

// Cumulus coverage 0..1 at a world xz point of the cloud layer.
float cloud_cov(vec2 xz, bool detail) {
	vec2 q = (xz - CLOUD_WIND * cloud_time) / 1300.0;
	float d = detail ? cl_fbm5(q) : cl_fbm3(q);
	float th = mix(0.72, 0.30, clamp(cloud_cover, 0.0, 1.0));
	return smoothstep(th, th + 0.2, d);
}

// Colours of the lit and shaded side of a cloud (display space) for sky_tod: dawn pink, midday white, evening gold.
vec3 cloud_lit_color() {
	vec3 dawn = vec3(1.0, 0.74, 0.62);
	vec3 noon = vec3(1.0, 0.99, 0.97);
	vec3 eve = vec3(1.0, 0.70, 0.42);
	float t = clamp(sky_tod, 0.0, 1.0);
	return t < 0.5 ? mix(dawn, noon, t * 2.0) : mix(noon, eve, t * 2.0 - 1.0);
}

vec3 cloud_shade_color() {
	vec3 dawn = vec3(0.50, 0.46, 0.64);
	vec3 noon = vec3(0.60, 0.67, 0.80);
	vec3 eve = vec3(0.52, 0.42, 0.52);
	float t = clamp(sky_tod, 0.0, 1.0);
	return t < 0.5 ? mix(dawn, noon, t * 2.0) : mix(noon, eve, t * 2.0 - 1.0);
}

// Sunlight left at a ground point after the cumulus layer: the point is projected along the sun ray to the layer.
float cloud_shadow(vec3 wp, vec3 sun) {
	if (cloud_cover < 0.02) {
		return 1.0;
	}
	vec2 hit = wp.xz + sun.xz / sun.y * (CLOUD_ALT - wp.y);
	return 1.0 - 0.6 * cloud_cov(hit, false);
}

// Low fog banks (lore: fog on ~180 mornings a year, thickest over the east valley). Density along a view ray, folded into aerial().
// Returns the fog opacity 0..1 between the camera and the point.
float ground_fog(vec3 wp, vec3 cam) {
	if (fog_amount < 0.01) {
		return 0.0;
	}
	vec3 ray = wp - cam;
	float d = length(ray);
	// Fog fills hollows up to FOG_TOP; the part of the ray inside that slab is what counts, so a bird's-eye view still sees the bank.
	const float FOG_TOP = 100.0;
	float lo = min(cam.y, wp.y);
	float hi = max(cam.y, wp.y);
	float inside = hi <= FOG_TOP ? 1.0 : (lo >= FOG_TOP ? 0.0 : (FOG_TOP - lo) / max(hi - lo, 1e-3));
	vec3 mid = cam + ray * 0.5;
	float east = smoothstep(-200.0, 500.0, wp.x);
	float banks = 0.5 + 0.5 * cl_noise((wp.xz - CLOUD_WIND * 0.4 * cloud_time) / 240.0);
	float dens = fog_amount * east * banks;
	return 1.0 - exp(-dens * min(d * inside, 1500.0) * 0.006);
}
