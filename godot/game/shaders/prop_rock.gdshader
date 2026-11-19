shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray atlas : filter_linear_mipmap, repeat_enable;
uniform float layer = 0.0;
varying vec3 p;
varying vec3 n;
void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / 1.7;
	n = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
	vec3 w = pow(abs(normalize(n)), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.001);
	vec3 a = texture(atlas, vec3(p.zy, layer)).rgb * w.x + texture(atlas, vec3(p.xz, layer)).rgb * w.y + texture(atlas, vec3(p.xy, layer)).rgb * w.z;
	ALBEDO = a * (a * (a * 0.305306011 + 0.682171111) + 0.012522878);   // sRGB atlas, decoded as the terrain does
	ROUGHNESS = 0.95;
}
