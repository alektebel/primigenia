shader_type spatial;
// Insect wing: opacity .48 without depth write, iridescent sheen.
render_mode cull_disabled, depth_draw_never;
#define MEMBRANE
#define MEMBRANE_STYLE 2
#include "res://creature/shaders/skin_common.gdshaderinc"
