// Look of the approved hero (palette C "Current+", G63) ported to Godot's pipeline.
// The hero (three.js r128) tone-maps with ACESFilmic, sRGB-encodes, and only then applies the
// aerial haze in display space. Godot tone-maps after the shader, so every world material writes
//   ALBEDO = scene_out(lin, world_pos, camera_pos)
// which pre-inverts Godot's (calibrated) ACES: Godot then reproduces the hero's display colour.
// All constants mirror game/island/look.gd (a test compares them).

const vec3 SUN_DIR = vec3(-0.6259115, 0.2826697, -0.7268649);
const vec3 AIR_COOL = vec3(0.34, 0.58, 0.88);
const vec3 AIR_WARM = vec3(0.96, 0.74, 0.46);
const float AIR_DENSITY = 0.00052;
const float AIR_START = 140.0;
const float AIR_FALLOFF = 240.0;

const mat3 ACES_IN = mat3(vec3(0.59719, 0.076, 0.0284), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
const mat3 ACES_OUT = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
const mat3 ACES_IN_INV = mat3(vec3(1.764740972, -0.147027852, -0.036336830), vec3(-0.675777678, 1.160251512, -0.162436437), vec3(-0.088963294, -0.013223660, 1.198773267));
const mat3 ACES_OUT_INV = mat3(vec3(0.643038249, 0.059268690, 0.005961901), vec3(0.311186752, 0.931436487, 0.063929016), vec3(0.045775457, 0.009294916, 0.930118384));

vec3 aces_rrt(vec3 v) {
	return (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.432951) + 0.238081);
}

// three.js r128 ACESFilmicToneMapping at exposure 1.
vec3 tm(vec3 c) {
	return clamp(ACES_OUT * aces_rrt(ACES_IN * (c / 0.6)), 0.0, 1.0);
}

// Exact inverse of tm() on [0, .985] per channel.
vec3 tm_inv(vec3 t) {
	vec3 y = ACES_OUT_INV * clamp(t, 0.0, 0.985);
	y = clamp(y, vec3(0.0), vec3(0.99));
	// Solve y = (x(x+A) - B) / (x(Cx+D) + E) for x >= 0.
	vec3 p = 0.0245786 - 0.432951 * y;
	vec3 q = 1.0 - 0.983729 * y;
	vec3 x = (-p + sqrt(p * p + 4.0 * q * (0.000090537 + 0.238081 * y))) / (2.0 * q);
	return ACES_IN_INV * x * 0.6;
}

vec3 srgb_encode(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(0.41666666)) - 0.055, step(0.0031308, c));
}

vec3 srgb_decode(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Height-aware aerial perspective, verbatim from tools/hero/build_hero.py AERIAL (display space).
vec3 aerial(vec3 c, vec3 wp, vec3 cam) {
	vec3 ray = wp - cam;
	float d = length(ray);
	vec3 dir = ray / max(d, 0.001);
	vec3 heights = max(vec3(cam.y, mix(cam.y, wp.y, 0.5), wp.y), vec3(0.0));
	vec3 rho = exp(-heights / AIR_FALLOFF);
	float path = max(d - AIR_START, 0.0);
	float optical = path * (1.0 - exp(-path / 240.0)) * AIR_DENSITY * dot(rho, vec3(0.1667, 0.6666, 0.1667));
	float sunward = pow(max(dot(dir, SUN_DIR), 0.0), 3.0);
	vec3 haze = mix(AIR_COOL, AIR_WARM, sunward);
	return mix(c, haze, 1.0 - exp(-optical));
}

// Horizon colour of the sky dome (same numbers as SKY_HZ / SKY_GLOW in sky.gdshader, a test compares them), in
// display space, for a world direction. The sky shows it below the horizon and the far sea fades into it,
// so there is no seam where the sea plane is cut by the far plane.
const vec3 HORIZON_HZ = vec3(0.95, 0.84, 0.70);
const vec3 HORIZON_GLOW = vec3(1.0, 0.62, 0.3);
vec3 horizon_color(vec3 dir) {
	vec3 n0 = normalize(vec3(dir.x, 0.0, dir.z) + vec3(1e-6, 0.0, 0.0));
	float s = max(dot(n0, SUN_DIR), 0.0);
	return min(HORIZON_HZ + HORIZON_GLOW * pow(s, 7.0) * 0.55, vec3(1.0));
}

// The Compatibility renderer converts what a shader writes to ALBEDO/COLOR with its own
// srgb_to_linear polynomial (as if it were an sRGB colour) before it tone-maps. Find the value
// that this polynomial maps back to the linear colour we want the tone mapper to see.
vec3 godot_albedo(vec3 lin) {
	// Start from the unclamped sRGB curve (lin may exceed 1 for bright HDR values).
	vec3 c = 1.055 * pow(max(lin, vec3(0.0)), vec3(0.41666666)) - 0.055;
	c = max(c, vec3(0.0));
	for (int i = 0; i < 4; i++) {
		vec3 f = c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878) - lin;
		vec3 d = c * (c * 0.915918033 + 1.364342222) + 0.012522878;
		c = max(c - f / max(d, 0.01), vec3(0.0));
	}
	return c;
}

// Linear scene colour -> value to write to ALBEDO so the screen shows the hero's display colour.
vec3 scene_out(vec3 lin, vec3 wp, vec3 cam) {
	return godot_albedo(tm_inv(srgb_decode(aerial(srgb_encode(tm(lin)), wp, cam))));
}

// A colour already in display space (sky dome, hero ShaderMaterials) -> ALBEDO/COLOR.
vec3 display_out(vec3 disp) {
	return godot_albedo(tm_inv(srgb_decode(disp)));
}
