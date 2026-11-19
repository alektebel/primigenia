#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <memory>
#include <vector>
extern "C" {
#include "cpore/world.h"
}

class CporeWorld : public godot::RefCounted {
    GDCLASS(CporeWorld, godot::RefCounted)
    std::unique_ptr<CpStageWorld> world;
    std::vector<char> observe_buffer;
    // The island heights the C world reads (PLAN-heights H1/H4): held here so the buffers outlive the world's pointer.
    godot::PackedFloat32Array field_height, field_level;
    CpStageField field;
    bool field_attached = false;
    godot::Dictionary field_meta;
    godot::String error_text;
    mutable uint32_t social_events_seen = 0;   // CpStageWorld.ev_total at the last state(): social events newer than this are reported once

protected:
    static void _bind_methods();

public:
    CporeWorld();
    static int version();
    static godot::Dictionary default_setup(int64_t seed);
    static godot::Dictionary default_profile();
    static godot::Array species();
    static godot::Array moves();
    static godot::Array chains();   // the A22 observe chain of each species: {id, trait, move, observe: [3 clues]}
    int reset(const godot::Dictionary &setup);
    godot::Dictionary get_setup() const;
    godot::String step(const godot::Dictionary &input);
    int command(const godot::String &text);
    // Parses a command text into the input it would order, without touching the world: {rc, input}.
    godot::Dictionary command_input(const godot::String &text) const;
    int order(const godot::Dictionary &input);
    static godot::String order_error(int code);
    godot::Dictionary state() const;
    godot::String observe();
    godot::String lineage() const;
    int lineage_begin();
    int lineage_perk(int kind,int serial,int amount);
    int lineage_form(const godot::String &body,const godot::Dictionary &profile,const godot::Array &parts,const godot::String &name,bool evolve);
    int lineage_award(int deed,int amount,int cause);
    godot::String hash() const;
    double height(double x, double z) const;
    double ground(double x, double z) const;
    bool can_walk(double x, double z, double nx, double nz, double radius) const;
    // Snapshot / restore, debug ops and the motion parameter table (PLAN-devtools step 5).
    godot::PackedByteArray snapshot() const;
    int restore(const godot::PackedByteArray &bytes);
    static godot::String snapshot_error(int code);
    int debug(const godot::Dictionary &op);
    static godot::String debug_error(int code);
    static godot::Array params();
    double param(int index) const;
    godot::String layout() const;
    // The island field (PLAN-heights H4).
    int set_field(const godot::Dictionary &entry);
    void clear_field();
    bool has_field() const { return field_attached; }
    godot::Dictionary field_info() const;
    double water_depth(double x, double z) const;
    double bound() const;
    // C1-nav: the running GO path as (x,z) points, nearest first (empty without one); the nav grid; event bookkeeping.
    godot::PackedVector2Array path() const;
    int nav_warm() const;
    double nav_cell() const;
    void ack_events();
    godot::String last_error() const { return error_text; }
};
