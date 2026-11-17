shader_type spatial;
render_mode unshaded, cull_back;
// Terrain, rock tier 3 (high). Compile-time tier: only the variant in use is compiled.
#define ROCK_TIER 3
#define MAP_TRIPLANAR
#include "res://game/shaders/terrain_body.gdshaderinc"
