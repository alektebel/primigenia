#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <atomic>

class CporeTerrain : public godot::RefCounted {
    GDCLASS(CporeTerrain, godot::RefCounted)
    std::atomic<int> stage{0}, done{0}, total{1};
    std::atomic<bool> busy{false};
    static void notify(int s, int d, int t, void *user);

protected:
    static void _bind_methods();

public:
    static int version();
    static godot::Dictionary defaults();
    static int validate(const godot::Dictionary &params);
    godot::Dictionary generate(const godot::Dictionary &params);
    godot::Dictionary progress() const;
    static godot::String hash(const godot::Dictionary &data);
    // Derived render maps (see docs/godot/M0.md): {surface: RGBA8 n*n*4, chunk_bounds: min/max per 64-cell chunk}.
    static godot::Dictionary surface_maps(const godot::Dictionary &data);
};
