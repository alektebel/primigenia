shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
// UV2.x selects bark (-1), solid tissue (0), a blade (1), or a compound spray.
varying float pigment_shift;
varying vec3 wood_tangent;

void vertex() {
	float phase = dot(MODEL_MATRIX[3].xz, vec2(0.27, 0.19));
	pigment_shift = sin(phase * 1.73);
	wood_tangent = mat3(MODELVIEW_MATRIX) * cross(vec3(0.0, 1.0, 0.0), NORMAL);
	VERTEX.x += 1.6 * UV2.y * (0.012 * sin(TIME * 1.7 + phase) + 0.005 * sin(3.7 * TIME + phase + VERTEX.y * 5.0));
}

float edge_coverage(float distance_inside) {
	float pixel = max(fwidth(distance_inside), 0.002);
	return smoothstep(-pixel, pixel, distance_inside);
}

void fragment() {
	float style = UV2.x;
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y;
	vec3 pigment = COLOR.rgb;
	float coverage = 1.0;
	if (style < -0.5) {
		// Periodic around the shaft so the UV seam has continuous furrows.
		float around = UV.x * 6.2831853;
		float drift = 0.75 * sin(v * 29.0 + 3.0 * around) + 0.35 * sin(7.0 * around - 48.0 * v);
		float phase = around * 17.0 + drift;
		float resolved = 1.0 - smoothstep(0.7, 3.14, fwidth(phase));
		float fissure = smoothstep(0.35, 0.99, cos(phase)) * resolved;
		float lichen = smoothstep(0.6, 1.5, sin(4.0 * around + v * 19.0) + 0.64 * sin(9.0 * around - v * 43.0));
		pigment = mix(pigment * (1.08 - 0.43 * fissure), vec3(0.20, 0.22, 0.15), 0.40 * lichen);
		NORMAL = normalize(NORMAL + wood_tangent / max(length(wood_tangent), 0.001) * (0.19 * sin(phase) * resolved));
	} else if (style > 1.5) {
		bool fern = style > 31.0;
		float count = fern ? 9.0 : style;
		float across = u / max(sqrt(max(0.0, 1.0 - v)), 0.01);
		float axis = fract(v * (fern ? 9.0 : 4.0) - across * 0.6) - 0.5;
		float along = fract(across * count - abs(axis) * 0.9) * 2.0 - 1.0;
		vec2 leaf = vec2(along, abs(axis) * (fern ? 2.5 : 2.15) - 0.32);
		float leaflet = max(0.77 - dot(leaf, leaf), 0.03 - abs(axis));
		coverage = edge_coverage(max(0.018 - u, min(1.0 - across, leaflet)));
		pigment *= vec3(1.0 + 0.09 * pigment_shift, 1.0, 1.0 - 0.07 * pigment_shift) * (0.92 + 0.14 * v);
		// A crown carries a continuous lighting normal through both faces.
		if (!fern && !FRONT_FACING) { NORMAL = -NORMAL; }
	} else if (style > 0.5) {
		coverage = edge_coverage(0.09 + 0.91 * sin(pow(v, 0.78) * 3.14159) - u);
	}
	ALPHA = coverage;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ALPHA_TEXTURE_COORDINATE = UV * 256.0;
	ALBEDO = OUTPUT_IS_SRGB ? pow(pigment, vec3(0.64)) : pigment;
	ROUGHNESS = style > 0.5 ? 0.85 : 0.96;
	SPECULAR = 0.12;
	BACKLIGHT = style > 0.5 ? ALBEDO * 0.22 : vec3(0.0);
}
