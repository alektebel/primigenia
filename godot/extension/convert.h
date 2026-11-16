// Shared Variant helpers: strict numeric conversion and hash text.
#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <cinttypes>
#include <cmath>
#include <cstdint>
#include <cstdio>

namespace cpore {

inline godot::String hash_text(uint64_t h) {
    char text[17];
    std::snprintf(text, sizeof text, "%016" PRIx64, h);
    return godot::String(text);
}

// An integer field accepts TYPE_INT, or TYPE_FLOAT whose value is finite and integral.
// The value must lie in [lo, hi]. Returns false and leaves `out` untouched otherwise.
inline bool to_int(const godot::Variant &v, int64_t lo, int64_t hi, int64_t &out) {
    int64_t value;
    if (v.get_type() == godot::Variant::INT) {
        value = int64_t(v);
    } else if (v.get_type() == godot::Variant::FLOAT) {
        const double d = double(v);
        if (!std::isfinite(d) || d != std::floor(d) || std::fabs(d) > 9.0e15) return false;
        value = int64_t(d);
    } else {
        return false;
    }
    if (value < lo || value > hi) return false;
    out = value;
    return true;
}

// A float field accepts INT or FLOAT, finite, converted with (float)double.
inline bool to_float(const godot::Variant &v, float &out) {
    double d;
    if (v.get_type() == godot::Variant::INT) d = double(int64_t(v));
    else if (v.get_type() == godot::Variant::FLOAT) d = double(v);
    else return false;
    if (!std::isfinite(d) || std::fabs(d) > 3.0e38) return false;
    out = float(d);
    return true;
}

inline bool to_bool_int(const godot::Variant &v, int &out) {
    if (v.get_type() == godot::Variant::BOOL) { out = bool(v) ? 1 : 0; return true; }
    int64_t i;
    if (!to_int(v, 0, 1, i)) return false;
    out = int(i);
    return true;
}

}  // namespace cpore
