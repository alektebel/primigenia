shader_type spatial;
render_mode unshaded, cull_back;
// Terrain, rock tier 1 (low). Compile-time tier: only the variant in use is compiled.
#define ROCK_TIER 1
#include "res://game/shaders/terrain_body.gdshaderinc"
