// Terrain generator glue. All generation stays in libcpore.a; this file only
// validates Variants, owns buffers and writes straight into the Packed arrays.
#include "cpore_terrain.h"
#include "convert.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <vector>
extern "C" {
#include "cpore/terrain.h"
}
#include "terrain_fields.inc"

using namespace godot;

namespace {
// Fills p from the dictionary over the defaults. Returns 0 or CP_TERR_ERR_RANGE.
int fill_params(const Dictionary &options, CpTerrainParams &p) {
    cp_terrain_params_default(&p);
    const Dictionary known = CporeTerrain::defaults();
    const Array keys = options.keys();
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].get_type() != Variant::STRING && keys[i].get_type() != Variant::STRING_NAME) return CP_TERR_ERR_RANGE;
        if (!known.has(keys[i])) return CP_TERR_ERR_RANGE;
    }
    int bad = 0;
#define U32(name) if (options.has(#name)) { int64_t v; if (cpore::to_int(options[#name], 0, 4294967295LL, v)) p.name = uint32_t(v); else bad = 1; }
#define I32(name) if (options.has(#name)) { int64_t v; if (cpore::to_int(options[#name], -2147483648LL, 2147483647LL, v)) p.name = int(v); else bad = 1; }
#define F32(name) if (options.has(#name)) { float v; if (cpore::to_float(options[#name], v)) p.name = v; else bad = 1; }
    TERRAIN_FIELDS(U32, I32, F32)
#undef U32
#undef I32
#undef F32
    return bad ? CP_TERR_ERR_RANGE : 0;
}

bool bytes_ok(const PackedFloat32Array &a, int64_t count) { return a.size() == count; }
}  // namespace

void CporeTerrain::notify(int s, int d, int t, void *user) {
    auto *self = static_cast<CporeTerrain *>(user);
    self->done.store(d);
    self->total.store(t);
    self->stage.store(s);
}

void CporeTerrain::_bind_methods() {
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("version"), &CporeTerrain::version);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("defaults"), &CporeTerrain::defaults);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("validate", "params"), &CporeTerrain::validate);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("hash", "data"), &CporeTerrain::hash);
    ClassDB::bind_method(D_METHOD("generate", "params"), &CporeTerrain::generate);
    ClassDB::bind_method(D_METHOD("progress"), &CporeTerrain::progress);
}

int CporeTerrain::version() { return CP_TERRAIN_VERSION; }

Dictionary CporeTerrain::defaults() {
    CpTerrainParams p;
    cp_terrain_params_default(&p);
    Dictionary d;
#define U32(name) d[#name] = int64_t(p.name);
#define I32(name) d[#name] = int64_t(p.name);
#define F32(name) d[#name] = double(p.name);
    TERRAIN_FIELDS(U32, I32, F32)
#undef U32
#undef I32
#undef F32
    return d;
}

int CporeTerrain::validate(const Dictionary &params) {
    CpTerrainParams p;
    const int rc = fill_params(params, p);
    if (rc) return rc;
    return cp_terrain_validate(&p);
}

Dictionary CporeTerrain::progress() const {
    Dictionary d;
    const int s = stage.load();
    d["stage"] = s;
    d["done"] = done.load();
    d["total"] = total.load();
    d["running"] = busy.load();
    return d;
}

Dictionary CporeTerrain::generate(const Dictionary &options) {
    Dictionary result;
    CpTerrainParams p;
    int rc = fill_params(options, p);
    if (!rc) rc = cp_terrain_validate(&p);
    if (rc) { result["error"] = rc; return result; }
    bool expected = false;
    if (!busy.compare_exchange_strong(expected, true)) {
        result["error"] = int(CP_TERR_ERR_BUFFER);
        return result;
    }
    const int count = p.n * p.n;
    PackedFloat32Array height, flow, sediment, level;
    PackedByteArray material;
    height.resize(count); flow.resize(count); sediment.resize(count);
    level.resize(count); material.resize(count);
    std::vector<int32_t> recv(count), ups(count), queue(count);
    CpTerrain t{};
    t.height = height.ptrw(); t.flow = flow.ptrw(); t.sediment = sediment.ptrw(); t.material = material.ptrw();
    CpTerrainWorkspace ws{level.ptrw(), recv.data(), ups.data(), queue.data()};
    stage.store(0); done.store(0); total.store(1);
    rc = cp_terrain_generate(&p, &t, &ws, notify, this);
    busy.store(false);
    result["error"] = rc;
    if (rc) return result;
    Dictionary resolved = defaults();
#define U32(name) resolved[#name] = int64_t(p.name);
#define I32(name) resolved[#name] = int64_t(p.name);
#define F32(name) resolved[#name] = double(p.name);
    TERRAIN_FIELDS(U32, I32, F32)
#undef U32
#undef I32
#undef F32
    result["version"] = CP_TERRAIN_VERSION;
    result["seed"] = int64_t(p.seed);
    result["n"] = t.n;
    result["size_m"] = double(t.size_m);
    result["params"] = resolved;
    result["hash"] = cpore::hash_text(cp_terrain_hash(&t));
    result["height"] = height; result["flow"] = flow; result["sediment"] = sediment;
    result["water_level"] = level; result["material"] = material;
    Array caves;
    for (int i = 0; i < t.cave_count; ++i) {
        const CpTerrainCave &c = t.caves[i];
        Dictionary cave;
        cave["position"] = Vector3(c.x_m, c.z_m, c.y_m);
        cave["facing"] = Vector3(c.facing_x, 0, c.facing_y);
        cave["size"] = Vector3(c.width_m, c.height_m, c.depth_m);
        cave["waterfall"] = bool(c.waterfall);
        caves.append(cave);
    }
    result["caves"] = caves;
    result["volcano"] = Vector4(t.volcano_x_m, t.volcano_y_m, t.volcano_radius_m, t.crater_radius_m);
    return result;
}

String CporeTerrain::hash(const Dictionary &data) {
    if (!data.has("n") || !data.has("size_m") || !data.has("height") || !data.has("flow") ||
        !data.has("sediment") || !data.has("material") || !data.has("caves") || !data.has("volcano"))
        return String();
    int64_t n;
    float size_m;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return String();
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["flow"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        data["sediment"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["material"].get_type() != Variant::PACKED_BYTE_ARRAY ||
        data["caves"].get_type() != Variant::ARRAY || data["volcano"].get_type() != Variant::VECTOR4)
        return String();
    PackedFloat32Array height = data["height"], flow = data["flow"], sediment = data["sediment"];
    PackedByteArray material = data["material"];
    const int64_t count = n * n;
    if (!bytes_ok(height, count) || !bytes_ok(flow, count) || !bytes_ok(sediment, count) || material.size() != count) return String();
    Array caves = data["caves"];
    if (caves.size() > CP_TERRAIN_CAVES_MAX) return String();
    CpTerrain t{};
    t.n = int(n); t.size_m = size_m;
    // Read-only use: const_cast avoids a copy-on-write detach of 4 MB arrays.
    t.height = const_cast<float *>(height.ptr()); t.flow = const_cast<float *>(flow.ptr());
    t.sediment = const_cast<float *>(sediment.ptr()); t.material = const_cast<uint8_t *>(material.ptr());
    t.cave_count = caves.size();
    for (int i = 0; i < caves.size(); ++i) {
        if (caves[i].get_type() != Variant::DICTIONARY) return String();
        Dictionary c = caves[i];
        if (c.get("position", Variant()).get_type() != Variant::VECTOR3 || c.get("facing", Variant()).get_type() != Variant::VECTOR3 ||
            c.get("size", Variant()).get_type() != Variant::VECTOR3 || c.get("waterfall", Variant()).get_type() != Variant::BOOL)
            return String();
        Vector3 pos = c["position"], facing = c["facing"], size = c["size"];
        CpTerrainCave &o = t.caves[i];
        o.x_m = pos.x; o.y_m = pos.z; o.z_m = pos.y;
        o.facing_x = facing.x; o.facing_y = facing.z;
        o.width_m = size.x; o.height_m = size.y; o.depth_m = size.z;
        o.waterfall = bool(c["waterfall"]) ? 1 : 0;
    }
    Vector4 v = data["volcano"];
    t.volcano_x_m = v.x; t.volcano_y_m = v.y; t.volcano_radius_m = v.z; t.crater_radius_m = v.w;
    return cpore::hash_text(cp_terrain_hash(&t));
}
