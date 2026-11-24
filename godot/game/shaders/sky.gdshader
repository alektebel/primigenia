shader_type sky;
// Hero sky dome (palette C): written in display space, so it goes through display_out().
#include "res://game/shaders/look.gdshaderinc"
const vec3 SKY_HZ = vec3(0.95, 0.84, 0.70);
const vec3 SKY_MID = vec3(0.52, 0.70, 0.93);
const vec3 SKY_TOP = vec3(0.13, 0.39, 0.84);
const vec3 SKY_GLOW = vec3(1.0, 0.62, 0.3);
void sky() {
	vec3 n = EYEDIR;
	float h = max(n.y, 0.0);
	vec3 c = mix(sky_horizon, sky_mid, smoothstep(0.0, 0.28, h));
	c = mix(c, sky_zenith, smoothstep(0.2, 0.95, h));
	// Below the horizon the sea (cut by the far plane) has faded into the horizon colour: same glow, no gradient.
	vec3 nd = n.y < 0.0 ? normalize(vec3(n.x, 0.0, n.z) + vec3(1e-6, 0.0, 0.0)) : n;
	float s = max(dot(nd, sun_dir), 0.0);
	c += sky_glow * pow(s, 7.0) * 0.55 + vec3(1.0, 0.97, 0.9) * smoothstep(0.9988, 0.9995, s) * 3.0 * sun_vis;
	// Clouds (not in the reflection cube pass: nothing there reads them). Intersect the view ray with the layer from the camera, so the
	// clouds hold still in the world, move with the wind and show perspective.
	if (!AT_CUBEMAP_PASS && n.y > 0.01) {
		float horizon_fade = smoothstep(0.01, 0.16, n.y);
		float t = (CLOUD_ALT - POSITION.y) / n.y;
		if (t > 0.0) {
			vec2 xz = POSITION.xz + n.xz * t;
			float cov = cloud_cov(xz, true);
			float cov2 = cloud_cov(xz + sun_dir.xz / max(sun_dir.y, 0.1) * 160.0, false);   // thickness toward the sun
			float lit = clamp(0.62 + (cov2 - cov) * 1.8 + (1.0 - cov) * 0.25, 0.0, 1.0);
			vec3 cc = mix(cloud_shade_color(), cloud_lit_color(), lit);
			cc += sky_glow * pow(s, 5.0) * 0.35 * (1.0 - cov * 0.5);   // silver lining toward the sun
			float a = cov * horizon_fade;
			cc *= mix(vec3(0.10, 0.14, 0.24), vec3(1.0), sun_vis);   // moonlit clouds
			c = mix(c, min(cc, vec3(1.0)), a * 0.94);
		}
		float t2 = (CIRRUS_ALT - POSITION.y) / n.y;
		if (t2 > 0.0) {
			vec2 xz2 = (POSITION.xz + n.xz * t2 - CLOUD_WIND * 2.0 * cloud_time) / vec2(5200.0, 1500.0);
			float ci = smoothstep(0.55, 0.9, cl_noise(xz2) * 0.6 + cl_noise(xz2 * 2.7 + 4.0) * 0.4) * mix(0.15, 0.6, clamp(cloud_cover, 0.0, 1.0));
			c = mix(c, cloud_lit_color() * mix(vec3(0.10, 0.14, 0.24), vec3(1.0), sun_vis), ci * horizon_fade * 0.5);
		}
	}
	COLOR = display_out(min(c, vec3(1.0)));
}
