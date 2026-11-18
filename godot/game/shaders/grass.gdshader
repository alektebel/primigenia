shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;
// World-anchored wind grass (hero GRASS_V9): each blade has a fixed world position found by
// wrapping its stored offset into the torus of side 2R around `center`.
#include "res://game/shaders/land.gdshaderinc"
#include "res://game/shaders/terrain_maps.gdshaderinc"

uniform vec3 center = vec3(0.0);
uniform sampler2D relief_tex : filter_linear, repeat_disable;   // A: baked sun visibility (PLAN-rock step 9)
uniform float rock_shadows = 0.0;                               // 0 off (the default), 1 on

varying vec3 v_base;     // x, ground y, z of the blade root
varying float v_h;       // 0 root .. 1 tip
varying float v_clump;
varying float v_light;
varying float v_sh;
varying vec3 wp;

void vertex() {
	vec4 cu = INSTANCE_CUSTOM;
	float lod = cu.w;
	float R = lod > 0.5 ? 140.0 : 44.0;
	vec2 o = cu.xy;
	vec2 base = o + floor((center.xz - o) / (2.0 * R) + 0.5) * 2.0 * R;
	float d = distance(base, center.xz);
	float fade = lod > 0.5 ? (1.0 - smoothstep(110.0, 140.0, d)) * smoothstep(30.0, 48.0, d) : 1.0 - smoothstep(30.0, 44.0, d);
	float clump = COLOR.r;
	float rolling = 0.65 + 0.55 * sin(base.x * 0.033 + sin(base.y * 0.027)) * 0.5 + tone(base) * 0.4;
	float mask = surface_bilinear(base).g;
	float hg = mix(0.48 + 0.75 * clump, 0.3 + 0.4 * clump, lod) * rolling * mask * fade;
	float ground = vground_tri(base) - 0.025;
	vec3 gn = ground_normal(base);
	float light = max(dot(gn, SUN_DIR), 0.0);
	float vis = mix(1.0, texture(relief_tex, (base + MAP_HALF) / (MAP_CELL * float(MAP_N))).a, rock_shadows);
	light *= vis;
	float sh = vis;
	vec2 push = vec2(0.0);
	if (lod < 0.5) {
		sh = occluder_shadow(vec3(base.x, ground, base.y));
		for (int i = 0; i < 12; i++) {
			vec4 oc = occ[i];
			if (oc.w <= 0.0) {
				continue;
			}
			vec2 dv = base - oc.xz;
			float dd = length(dv);
			float reach = oc.w * 1.3;
			if (dd < reach) {
				push += dv / max(dd, 0.001) * (1.0 - dd / reach);
			}
		}
	}
	float wave = meadowWave(base, TIME);
	float gust = sin(base.x * 0.12 + base.y * 0.09 + TIME * 1.6);
	vec3 p = VERTEX;
	float bend = (0.1 + 0.15 * gust + 0.3 * wave) * p.y * p.y * hg;
	float ang = cu.z * 44.0;
	float wd = mix(0.12, 0.25, lod) * (0.65 + cu.z * 0.6) * fade * step(0.008, hg);
	vec3 w = vec3(base.x + p.x * cos(ang) * wd + bend * 0.85, ground + p.y * hg, base.y + p.x * sin(ang) * wd + bend * 0.5);
	w.xz += push * p.y * hg * 0.9;
	VERTEX = w;
	wp = w;
	v_base = vec3(base.x, ground, base.y);
	v_h = p.y;
	v_clump = clump;
	v_light = light;
	v_sh = sh;
}

void fragment() {
	vec2 xz = v_base.xz;
	float wave = meadowWave(xz, TIME);
	vec3 c = meadowColor(tone(xz), 1.0, v_light, wave, xz) * mix(TUFT0, TUFT1, v_clump) * mix(BLADE_LO, BLADE_HI, smoothstep(0.0, 1.0, v_h)) * mix(SH_K, 1.0, v_sh);
	c *= mix(S_TINT, vec3(1.0), v_sh);
	float back = pow(max(dot(normalize(wp - CAMERA_POSITION_WORLD), SUN_DIR), 0.0), 4.0);
	c += vec3(0.14, 0.2, 0.035) * v_h * v_h * back * v_sh;
	ALBEDO = scene_out(c, wp, CAMERA_POSITION_WORLD);
}
