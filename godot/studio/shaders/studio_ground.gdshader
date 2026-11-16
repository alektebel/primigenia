shader_type spatial;
// Studio ground: grass colour with the circular dirt path (port of the ground shader in web/studio/studio.js).
varying vec3 wpos;
float hsh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float r = length(wpos.xz - vec2(-7.0, 0.0));
	float n = vn(wpos.xz * 0.6) * 0.6 + vn(wpos.xz * 2.9) * 0.4;
	float tr = smoothstep(5.3, 6.1, r + n * 0.8) * (1.0 - smoothstep(7.9, 8.7, r - n * 0.8));
	vec3 dirt = mix(vec3(0.13, 0.085, 0.05), vec3(0.26, 0.18, 0.11), n) * (0.8 + 0.4 * vn(wpos.xz * 11.0));
	vec3 gr = mix(vec3(0.035, 0.085, 0.02), vec3(0.08, 0.15, 0.035), n);
	ALBEDO = mix(gr, dirt, tr);
	ROUGHNESS = 1.0;
}
