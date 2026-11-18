# Clouds, cloud shadows and morning fog (S5)

Global shader uniforms (`project.godot` `[shader_globals]`, set by `game/island/clouds.gd`): `cloud_cover` 0..1, `cloud_time` (seconds, the wind;
the island advances it every frame), `sky_tod` 0 dawn .. 0.5 midday .. 1 evening, `fog_amount` 0..1. All code is in `shaders/clouds.gdshaderinc`, included
through `look.gdshaderinc`, so sky, terrain, water and grass share one weather.

* **Sky** (`sky.gdshader`): the view ray is intersected with a cumulus layer at 1,800 m from the camera position, so the clouds hold still in the world,
  drift with a 6 m/s wind, and show perspective; 5-octave value noise, a second tap toward the sun for thickness (lit side, shaded base), a silver lining toward
  the sun, fade into the horizon. A faint cirrus layer at 7,000 m. Skipped in the reflection-cube pass (`AT_CUBEMAP_PASS`) so the radiance map is not re-rendered.
* **Cloud shadows**: `terrain_body.gdshaderinc` multiplies the terrain's light by `cloud_shadow()`, the cumulus coverage at the point where the sun ray meets the layer
  (3 octaves, up to 60% darker). The sun is low (16 degrees) so the shadow pattern lies 6 km sunward of the cloud it belongs to; the patterns are consistent, not aligned with the visible clouds.
* **Fog**: `ground_fog()` in `aerial()`: opacity from the length of the view ray inside a slab below 100 m, thickest east of x = 0 (the valley the river leaves through), broken into banks that drift. Off (`fog_amount` 0) except in the dawn preset.
* **Presets** (`Clouds.PRESETS`, `Game.settings.weather`): dawn (pink clouds, fog), midday, evening (gold), clear, overcast. The hero's sun direction is fixed, so the time of day only tints clouds and fog.
* Cost: the sky is a screen-space pass over the sky pixels only; the cloud-shadow term is 12 hash taps per terrain fragment.
  Evidence: `docs/evidence/godot/look/s5/{dawn,midday,evening}/`.
