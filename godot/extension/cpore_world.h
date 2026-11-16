#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <memory>
#include <vector>
extern "C" {
#include "cpore/world.h"
}

class CporeWorld : public godot::RefCounted {
    GDCLASS(CporeWorld, godot::RefCounted)
    std::unique_ptr<CpStageWorld> world;
    std::vector<char> observe_buffer;

protected:
    static void _bind_methods();

public:
    CporeWorld();
    static int version();
    static godot::Dictionary default_setup(int64_t seed);
    static godot::Dictionary default_profile();
    static godot::Array species();
    int reset(const godot::Dictionary &setup);
    godot::Dictionary get_setup() const;
    godot::String step(const godot::Dictionary &input);
    int command(const godot::String &text);
    int order(const godot::Dictionary &input);
    static godot::String order_error(int code);
    godot::Dictionary state() const;
    godot::String observe();
    godot::String hash() const;
    double height(double x, double z) const;
    double ground(double x, double z) const;
    bool can_walk(double x, double z, double nx, double nz, double radius) const;
};
