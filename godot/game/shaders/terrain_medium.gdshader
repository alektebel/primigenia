shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;
#define WORLD_LIT
// Terrain, rock tier 2 (medium). Compile-time tier: only the variant in use is compiled.
#define ROCK_TIER 2
#include "res://game/shaders/terrain_body.gdshaderinc"
