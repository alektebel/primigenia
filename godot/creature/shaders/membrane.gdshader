shader_type spatial;
// Frill/fan membrane: opacity .82, depth write on, roughness .94.
render_mode cull_disabled, depth_draw_always;
#define MEMBRANE
#define MEMBRANE_STYLE 0
#include "res://creature/shaders/skin_common.gdshaderinc"
