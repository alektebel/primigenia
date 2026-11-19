shader_type spatial;
render_mode cull_disabled;

// UV spans one colony. Its low dome follows the placement facet and carries
// no opaque skirt. Transparent gaps expose the actual underlying substrate.
uniform bool moss = false;
uniform vec4 glow : source_color = vec4(0.0);
varying vec2 offset;

float hash2(vec2 p) {
	vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1,0)), f.x),
		mix(hash2(cell + vec2(0,1)), hash2(cell + vec2(1,1)), f.x), f.y);
}
void vertex() {
	offset = mod(MODEL_MATRIX[3].xz, vec2(61.0));
}
void fragment() {
	vec2 p = UV + offset;
	float islands = noise2(p * 4.0);
	float grain = noise2(p * (moss ? 35.0 : 21.0));
	float margin = 0.77 - length(UV) + 0.38 * (islands - 0.5);
	float mask = smoothstep(0.0, 0.15, margin) * smoothstep(0.18, 0.60, islands + 0.28 * grain);
	ALPHA = mask * (moss ? 0.94 : 0.78);
	vec3 pigment = COLOR.rgb * (0.69 + 0.56 * islands + 0.28 * grain);
	ALBEDO = OUTPUT_IS_SRGB ? pow(pigment, vec3(0.9)) : pigment;
	ROUGHNESS = 0.98;
	SPECULAR = 0.05;
	EMISSION = glow.rgb * grain * 0.045;
}
