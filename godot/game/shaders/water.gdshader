shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;
// Sea and lakes: hero water (valle-primigenio.html) with depth from the exact ground.
#include "res://game/shaders/look.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = wp.xz;
	bool inside = abs(q.x) < MAP_HALF && abs(q.y) < MAP_HALF;
	float depth = inside ? wp.y - ground_tri(q) : 60.0;
	vec3 c = mix(vec3(0.36, 0.8, 0.76), vec3(0.07, 0.32, 0.56), smoothstep(0.0, 7.0, depth));
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float t = TIME;
	vec3 n = normalize(vec3(sin(q.x * 0.6 + t * 1.3) * 0.07 + sin(q.y * 1.7 - t) * 0.04, 1.0,
			cos(q.y * 0.5 + t * 1.1) * 0.07 + sin(q.x * 1.3 + t * 0.7) * 0.04));
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(120.0, 450.0, distance(wp, CAMERA_POSITION_WORLD))));   // calm far water: no moire
	float fr = pow(1.0 - max(dot(V, n), 0.0), 4.0);
	c = mix(c, vec3(0.8, 0.91, 0.97), fr * 0.5);
	c += vec3(1.0, 0.95, 0.8) * pow(max(dot(n, normalize(V + SUN_DIR)), 0.0), 160.0);
	float foam = 1.0 - smoothstep(0.0, 0.22, depth + sin(t * 1.4 + q.x * 0.8 + q.y * 0.6) * 0.06);
	c = mix(c, vec3(1.0), foam * 0.85);
	float alpha = max(mix(0.6, 0.96, smoothstep(0.0, 3.0, depth)), foam);
	if (distance(wp, CAMERA_POSITION_WORLD) > 600.0) {
		alpha = 1.0;
	}
	if (depth < -0.3) {
		discard;   // water surface below the ground: never draw it over land
	}
	// Far sea fades into the sky's horizon colour: the plane is cut at the camera far plane (12 km) and the
	// sky below the horizon is that colour, so no hard line shows in the far view.
	vec3 ray = wp - CAMERA_POSITION_WORLD;
	float far_t = smoothstep(5000.0, 11500.0, length(ray));
	vec3 disp = aerial(srgb_encode(tm(c)), wp, CAMERA_POSITION_WORLD);
	disp = mix(disp, horizon_color(normalize(ray)), far_t);
	ALBEDO = display_out(disp);
	ALPHA = alpha;
}
