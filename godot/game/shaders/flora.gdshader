shader_type spatial;
render_mode cull_disabled;
// UV2.x encodes solid tissue, a single blade, or the leaf count on a compound card.
uniform vec4 glow : source_color = vec4(0.0);
varying vec3 local;
void vertex() {
	local = VERTEX;
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.27, 0.19));
	VERTEX.x += 1.6 * UV2.y * (0.012 * sin(TIME * 1.7 + phase) + 0.005 * sin(3.7 * TIME + phase + VERTEX.y * 5.0));
}
void fragment() {
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y;
	float grain = 0.94 + 0.06 * sin(local.y * 44.0 + local.x * 131.0 + sin(local.z * 92.0));
	if (UV2.x > 1.5) {
		// A woody spray has lateral twigs bearing small, paired elliptic leaves.
		// Fern pinnae carry a second rank of fine pinnules along the same axes.
		bool fern = UV2.x > 31.0;
		float count = fern ? 9.0 : UV2.x;
		float envelope = sqrt(max(0.0, 1.0 - v));
		float across = u / max(envelope, 0.01);
		float axis = fract(v * (fern ? 9.0 : 4.0) - across * 0.6) - 0.5;
		float along = fract(across * count - abs(axis) * 0.9) * 2.0 - 1.0;
		vec2 leaf = vec2(along, abs(axis) * (fern ? 2.5 : 2.15) - 0.32);
		if (u > 0.018 && (across > 1.0 || (abs(axis) > 0.03 && dot(leaf, leaf) > 0.77))) { discard; }
	} else if (UV2.x > 0.5 && u > 0.09 + 0.91 * sin(pow(v, 0.78) * 3.14159)) { discard; }
	ALBEDO = COLOR.rgb * grain;
	ROUGHNESS = UV2.x > 0.5 ? 0.72 : 0.96;
	EMISSION = glow.rgb * 0.06 * grain;
	BACKLIGHT = UV2.x > 0.5 ? COLOR.rgb * 0.28 : vec3(0.0);
}
