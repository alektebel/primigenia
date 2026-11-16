// Terrain generator glue. All generation stays in libcpore.a; this file only
// validates Variants, owns buffers and writes straight into the Packed arrays.
#include "cpore_terrain.h"
#include "convert.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <algorithm>
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
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("surface_maps", "data"), &CporeTerrain::surface_maps);
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

namespace {
float smoothstep(float a, float b, float x) {
    float t = (x - a) / (b - a);
    t = t < 0.f ? 0.f : (t > 1.f ? 1.f : t);
    return t * t * (3.f - 2.f * t);
}
uint8_t byte01(float v) {
    v = v < 0.f ? 0.f : (v > 1.f ? 1.f : v);
    return uint8_t(std::floor(v * 255.f + 0.5f));
}
}  // namespace

// Presentation maps only (not part of the deterministic simulation): material id, grass mask,
// cavity and wetness packed as RGBA8, plus per-chunk height bounds for culling boxes.
Dictionary CporeTerrain::surface_maps(const Dictionary &data) {
    Dictionary out;
    int64_t n;
    float size_m;
    if (!data.has("n") || !data.has("size_m") || !data.has("height") || !data.has("flow") || !data.has("material") || !data.has("water_level")) return out;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return out;
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["flow"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        data["water_level"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["material"].get_type() != Variant::PACKED_BYTE_ARRAY)
        return out;
    const PackedFloat32Array height = data["height"], flow = data["flow"], level = data["water_level"];
    const PackedByteArray material = data["material"];
    const int64_t count = n * n;
    if (height.size() != count || flow.size() != count || level.size() != count || material.size() != count) return out;
    const float *H = height.ptr();
    const float *F = flow.ptr();
    const float *L = level.ptr();
    const uint8_t *M = material.ptr();
    const int N = int(n);
    const float cell = size_m / float(N);
    auto at = [&](int i, int j) { i = i < 0 ? 0 : (i >= N ? N - 1 : i); j = j < 0 ? 0 : (j >= N ? N - 1 : j); return H[j * N + i]; };
    PackedByteArray surface;
    surface.resize(count * 4);
    uint8_t *S = surface.ptrw();
    const float lo = std::log10(1500.f), hi = std::log10(2.0e5f);
    for (int j = 0; j < N; ++j) {
        for (int i = 0; i < N; ++i) {
            const int k = j * N + i;
            const float h = H[k];
            const float gx = (at(i + 1, j) - at(i - 1, j)) / (2.f * cell);
            const float gy = (at(i, j + 1) - at(i, j - 1)) / (2.f * cell);
            const float ny = 1.f / std::sqrt(1.f + gx * gx + gy * gy);
            const bool pond = (L[k] - h > 0.5f) && h > 0.f;
            float grass = 0.f;
            if (M[k] == CP_TERR_MAT_MEADOW && !pond) grass = smoothstep(.72f, .86f, ny) * smoothstep(1.2f, 2.2f, h);
            float curv = 0.f;
            const int radii[2] = {2, 5};
            for (int r : radii) {
                const float rm = float(r) * cell;
                const float lap = (at(i - r, j) + at(i + r, j) + at(i, j - r) + at(i, j + r) - 4.f * h) / (rm * rm);
                curv += std::max(0.f, lap) * rm * 0.5f;
            }
            const float cavity = smoothstep(.025f, .26f, curv);
            const float area = F[k] * size_m * size_m;
            float wet = (std::log10(std::max(area, 1.f)) - lo) / (hi - lo);
            wet = wet < 0.f ? 0.f : (wet > 1.f ? 1.f : wet);
            uint8_t *px = S + size_t(k) * 4;
            px[0] = M[k]; px[1] = byte01(grass); px[2] = byte01(cavity); px[3] = byte01(wet);
        }
    }
    const int chunk = 64;
    const int cps = (N + chunk - 1) / chunk;
    PackedFloat32Array bounds;
    bounds.resize(cps * cps * 2);
    float *B = bounds.ptrw();
    for (int cj = 0; cj < cps; ++cj) {
        for (int ci = 0; ci < cps; ++ci) {
            float mn = 1e30f, mx = -1e30f;
            for (int b = 0; b <= chunk; ++b) {
                for (int a = 0; a <= chunk; ++a) {
                    const float v = at(ci * chunk + a, cj * chunk + b);
                    mn = std::min(mn, v); mx = std::max(mx, v);
                }
            }
            B[(cj * cps + ci) * 2] = mn;
            B[(cj * cps + ci) * 2 + 1] = mx;
        }
    }
    out["surface"] = surface;
    out["chunk_bounds"] = bounds;
    out["chunks_per_side"] = cps;
    return out;
}
