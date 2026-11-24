// One light for the whole world (WL1). Ground, grass, rivers and water keep their own toon ramp, baked into ALBEDO exactly as before
// (so the far palette is the same), and now also receive the sun's shadow map: a tree, a rock or a creature darkens the ground
// under it. Only when the including shader defines WORLD_LIT (the medium and high tiers); the low tier stays `unshaded` and keeps the
// baked terrain sun visibility (relief.a) instead.
//
// The including shader sets `render_mode ambient_light_disabled, specular_disabled` so the environment's ambient does not add to the
// pre-lit colour; the shadow factor below is the whole contribution of the light. Unshadowed it is 1, so colours are unchanged.
#ifdef WORLD_LIT
#ifndef WORLD_SHADOW_TINT
#define WORLD_SHADOW_TINT vec3(0.336, 0.3612, 0.4788)   // SH_K * S_TINT of land.gdshaderinc: the fake shadow's colour, now for real shadows
#endif
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// At night the shadow is the moon's, soft and ambient-filled: a much lighter tint keeps the near ground readable (round 2).
		DIFFUSE_LIGHT += mix(mix(vec3(0.78, 0.82, 0.94), WORLD_SHADOW_TINT, sun_vis), vec3(1.0), ATTENUATION);
	}
}
#endif
