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
	vec3 c = mix(SKY_HZ, SKY_MID, smoothstep(0.0, 0.28, h));
	c = mix(c, SKY_TOP, smoothstep(0.2, 0.95, h));
	// Below the horizon the sea (cut by the far plane) has faded into the horizon colour: same glow, no gradient.
	vec3 nd = n.y < 0.0 ? normalize(vec3(n.x, 0.0, n.z) + vec3(1e-6, 0.0, 0.0)) : n;
	float s = max(dot(nd, SUN_DIR), 0.0);
	c += SKY_GLOW * pow(s, 7.0) * 0.55 + vec3(1.0, 0.97, 0.9) * smoothstep(0.9988, 0.9995, s) * 3.0;
	COLOR = display_out(min(c, vec3(1.0)));
}
