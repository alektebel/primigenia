shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;
// Wind grass blades (port of the instanced grass in web/studio/studio.js), hero look output.
#include "res://game/shaders/look.gdshaderinc"
varying float vH;
varying float vR;
varying vec3 wp;
void vertex() {
	vec4 cu = INSTANCE_CUSTOM;
	vec2 b = cu.xy;
	float rnd = cu.z;
	float hg = cu.w;
	float ang = rnd * 44.0;
	float gust = sin(b.x * 0.14 + b.y * 0.1 + TIME * 1.5) + sin(b.x * 0.33 - b.y * 0.29 + TIME * 2.2) * 0.5;
	vec3 p = VERTEX;
	float bend = (0.1 + 0.16 * gust) * p.y * p.y * hg;
	float wd = 0.1 * (0.6 + rnd);
	vec3 w = vec3(b.x + p.x * cos(ang) * wd + bend * 0.85, p.y * hg, b.y + p.x * sin(ang) * wd + bend * 0.5);
	VERTEX = w;
	wp = w;
	vH = p.y;
	vR = rnd + gust * 0.15;
}
void fragment() {
	vec3 c = mix(vec3(0.10, 0.19, 0.05), mix(vec3(0.50, 0.56, 0.17), vec3(0.78, 0.66, 0.26), vR * 0.6), vH * vH);
	float d = distance(wp, CAMERA_POSITION_WORLD);
	c = mix(c, vec3(0.93, 0.74, 0.56), smoothstep(35.0, 140.0, d));
	ALBEDO = display_out(c);
}
