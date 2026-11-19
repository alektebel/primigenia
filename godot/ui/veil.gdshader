shader_type canvas_item;
// A full-screen veil (docs/godot/UI-DIEGETIC.md 2, 7.7, 7.12): a flat tint plus a radial vignette with an inner and an
// outer radius. Menu and loadout use the flat tint (the fog closing in), low health and a hit use the ember vignette,
// death uses the fog-coloured one. No border, no rounded shape, never a panel.

uniform vec4 tint : source_color = vec4(0.094, 0.133, 0.122, 1.0);
uniform float tint_amount = 0.0;
uniform vec4 edge : source_color = vec4(0.165, 0.059, 0.039, 1.0);
uniform float edge_amount = 0.0;
uniform float inner = 0.55;
uniform float outer = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p) / 1.41421356;
	float v = smoothstep(inner, outer, d);
	float ta = tint.a * tint_amount;
	float ea = edge.a * edge_amount * v;
	float a = ta + ea * (1.0 - ta);
	vec3 rgb = (tint.rgb * ta + edge.rgb * ea * (1.0 - ta)) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
