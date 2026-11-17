shader_type spatial;
render_mode unshaded, cull_back;
// Terrain, rock tier 2 (medium). Compile-time tier: only the variant in use is compiled.
#define ROCK_TIER 2
#include "res://game/shaders/terrain_body.gdshaderinc"
