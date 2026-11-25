#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <atomic>

class CporeTerrain : public godot::RefCounted {
    GDCLASS(CporeTerrain, godot::RefCounted)
    std::atomic<int> stage{0}, done{0}, total{1};
    std::atomic<bool> busy{false};
    static void notify(int s, int d, int t, void *user);

protected:
    static void _bind_methods();

public:
    static godot::Dictionary cave_mesh(const godot::Dictionary &params);
    static int version();
    static godot::Dictionary defaults();
    static int validate(const godot::Dictionary &params);
    godot::Dictionary generate(const godot::Dictionary &params);
    godot::Dictionary progress() const;
    static godot::String hash(const godot::Dictionary &data);
    // Authored islands (island.h) and their climate maps (part II, M2): generate({..., island_blob: PackedByteArray}) also returns
    // climate (RGBA8 climate_n^2), biome (n*n), veg (n*n*4), climate_n, climate_hash, island and island_hash (the cache key parts).
    static godot::Dictionary island_info(const godot::PackedByteArray &blob);
    static godot::String climate_hash(const godot::Dictionary &data);
    static int climate_version();
    // Island-realism M3 (core/src/flora_place.c): the sim's trunks, 5 floats per record (x, z, radius, height, species id), and a clearance query.
    static int flora_version();
    static godot::PackedFloat32Array trunks(const godot::Dictionary &data);
    static bool trunk_clear(const godot::PackedFloat32Array &trunks, double x, double z, double margin);
    // Derived render maps (see docs/godot/M0.md): {surface: RGBA8 n*n*4, chunk_bounds: min/max per 64-cell chunk}.
    static godot::Dictionary surface_maps(const godot::Dictionary &data);
    // Optional baked sun visibility (PLAN-rock step 9, off by default): n*n bytes, 255 lit .. 0 shadowed, for a sun direction given as
    // the vector towards the sun in Godot world axes (x east, y up, z south). Ray-marched at half resolution, blurred 3x3, upsampled.
    // Presentation only: not part of the terrain hash, not cached. Returns an empty array for invalid input.
    // Visual erosion (terrain v5, visual_terrain.cpp): a 4x finer heightfield (uint16) bounded against the sim plus erosion maps.
    static godot::Dictionary visual_maps(const godot::Dictionary &data, const godot::Dictionary &options);
    static godot::PackedByteArray sun_visibility(const godot::Dictionary &data, const godot::Vector3 &sun);
};
