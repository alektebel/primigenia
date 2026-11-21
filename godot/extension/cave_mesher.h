#pragma once
#include <godot_cpp/variant/dictionary.hpp>

namespace cpore {
// Accepts state().cave plus seed, mouth_half and mouth_height (metres).
// Positions and inward-facing normals are returned in Godot world axes.
godot::Dictionary build_cave_mesh(const godot::Dictionary &params);
}
