// Terrain generator glue. All generation stays in libcpore.a; this file only
// validates Variants, owns buffers and writes straight into the Packed arrays.
#include "cpore_terrain.h"
#include "convert.h"
#include "cave_mesher.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <algorithm>
#include <vector>
extern "C" {
#include "cpore/terrain.h"
#include "cpore/island.h"
#include "cpore/climate.h"
}
#include <memory>
#include <cinttypes>
#include <cstdio>
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
        // island keys belong to the cache key and the desc (see generate); they are not terrain parameters
        if (keys[i] == Variant("island") || keys[i] == Variant("island_hash") || keys[i] == Variant("island_blob")) continue;
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
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("cave_mesh", "params"), &CporeTerrain::cave_mesh);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("version"), &CporeTerrain::version);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("defaults"), &CporeTerrain::defaults);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("validate", "params"), &CporeTerrain::validate);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("hash", "data"), &CporeTerrain::hash);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("island_info", "blob"), &CporeTerrain::island_info);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("climate_hash", "data"), &CporeTerrain::climate_hash);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("climate_version"), &CporeTerrain::climate_version);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("surface_maps", "data"), &CporeTerrain::surface_maps);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("visual_maps", "data", "options"), &CporeTerrain::visual_maps);
    ClassDB::bind_static_method("CporeTerrain", D_METHOD("sun_visibility", "data", "sun"), &CporeTerrain::sun_visibility);
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
    PackedByteArray material, river;
    river.resize(count);
    height.resize(count); flow.resize(count); sediment.resize(count);
    level.resize(count); material.resize(count);
    std::vector<int32_t> recv(count), ups(count), queue(count);
    CpTerrain t{};
    t.height = height.ptrw(); t.flow = flow.ptrw(); t.sediment = sediment.ptrw(); t.material = material.ptrw(); t.river = river.ptrw();
    CpTerrainWorkspace ws{level.ptrw(), recv.data(), ups.data(), queue.data()};
    // An authored island (island.h): options["island_blob"] is its ISL1 blob. Then the climate maps (part II, M2) come with it:
    // climate (RGBA8 climate_n^2), biome (n*n) and veg (n*n*4), and the result carries "island" and "island_hash" for the cache key.
    std::unique_ptr<CpIslandDesc> desc;
    PackedByteArray climate, biome, veg;
    std::vector<float> climate_work;
    if (options.has("island_blob")) {
        if (options["island_blob"].get_type() != Variant::PACKED_BYTE_ARRAY) { busy.store(false); result["error"] = int(CP_TERR_ERR_RANGE); return result; }
        PackedByteArray blob = options["island_blob"];
        desc.reset(new CpIslandDesc);
        rc = cp_island_parse(blob.ptr(), size_t(blob.size()), desc.get());
        if (rc) { busy.store(false); result["error"] = rc; return result; }
        if (p.n >= 64) {
            climate.resize(CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N * 4);
            biome.resize(count); veg.resize(int64_t(count) * 4);
            climate_work.resize(cp_terrain_climate_work_floats());
            t.climate = climate.ptrw(); t.biome = biome.ptrw(); t.veg = veg.ptrw();
            ws.climate_work = climate_work.data();
        }
    }
    stage.store(0); done.store(0); total.store(1);
    rc = desc ? cp_terrain_generate_desc(&p, desc.get(), &t, &ws, notify, this) : cp_terrain_generate(&p, &t, &ws, notify, this);
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
    if (desc) {
        resolved["island"] = String(desc->id);
        resolved["island_hash"] = cpore::hash_text(cp_island_hash(desc.get()));
        result["island"] = resolved["island"]; result["island_hash"] = resolved["island_hash"];
        if (t.climate_n > 0) {
            result["climate_n"] = t.climate_n;
            result["climate"] = climate; result["biome"] = biome; result["veg"] = veg;
            result["climate_hash"] = cpore::hash_text(cp_terrain_climate_hash(&t));
        }
    }
    result["params"] = resolved;
    result["hash"] = cpore::hash_text(cp_terrain_hash(&t));
    result["height"] = height; result["flow"] = flow; result["sediment"] = sediment;
    result["water_level"] = level; result["material"] = material; result["river"] = river;
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

// {error, id, hash (hex, cp_island_hash), n, size_m} of an ISL1 blob: what the cache key and the callers need before generating.
Dictionary CporeTerrain::island_info(const PackedByteArray &blob) {
    Dictionary r;
    std::unique_ptr<CpIslandDesc> d(new CpIslandDesc);
    const int rc = cp_island_parse(blob.ptr(), size_t(blob.size()), d.get());
    r["error"] = rc;
    if (rc) return r;
    r["id"] = String(d->id);
    r["hash"] = cpore::hash_text(cp_island_hash(d.get()));
    r["n"] = d->n;
    r["size_m"] = double(d->size_dm) / 10.0;
    return r;
}

int CporeTerrain::climate_version() { return CP_CLIMATE_VERSION; }

// cp_terrain_climate_hash of a generate() result that carries climate, biome and veg ("" otherwise).
String CporeTerrain::climate_hash(const Dictionary &data) {
    if (!data.has("n") || !data.has("climate") || !data.has("biome") || !data.has("veg") || !data.has("climate_n")) return String();
    int64_t n, cn;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_int(data["climate_n"], 1, CP_TERRAIN_CLIMATE_N, cn)) return String();
    if (data["climate"].get_type() != Variant::PACKED_BYTE_ARRAY || data["biome"].get_type() != Variant::PACKED_BYTE_ARRAY || data["veg"].get_type() != Variant::PACKED_BYTE_ARRAY) return String();
    PackedByteArray climate = data["climate"], biome = data["biome"], veg = data["veg"];
    if (climate.size() != CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N * 4 || biome.size() != n * n || veg.size() != n * n * 4) return String();
    CpTerrain t{};
    t.n = int(n); t.climate_n = int(cn);
    t.climate = const_cast<uint8_t *>(climate.ptr()); t.biome = const_cast<uint8_t *>(biome.ptr()); t.veg = const_cast<uint8_t *>(veg.ptr());
    return cpore::hash_text(cp_terrain_climate_hash(&t));
}

String CporeTerrain::hash(const Dictionary &data) {
    if (!data.has("n") || !data.has("size_m") || !data.has("height") || !data.has("flow") ||
        !data.has("sediment") || !data.has("material") || !data.has("river") || !data.has("caves") || !data.has("volcano"))
        return String();
    int64_t n;
    float size_m;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return String();
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["flow"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        data["sediment"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["material"].get_type() != Variant::PACKED_BYTE_ARRAY ||
        data["river"].get_type() != Variant::PACKED_BYTE_ARRAY || data["caves"].get_type() != Variant::ARRAY || data["volcano"].get_type() != Variant::VECTOR4)
        return String();
    PackedFloat32Array height = data["height"], flow = data["flow"], sediment = data["sediment"];
    PackedByteArray material = data["material"], river = data["river"];
    const int64_t count = n * n;
    if (!bytes_ok(height, count) || !bytes_ok(flow, count) || !bytes_ok(sediment, count) || material.size() != count || river.size() != count) return String();
    Array caves = data["caves"];
    if (caves.size() > CP_TERRAIN_CAVES_MAX) return String();
    CpTerrain t{};
    t.n = int(n); t.size_m = size_m;
    // Read-only use: const_cast avoids a copy-on-write detach of 4 MB arrays.
    t.height = const_cast<float *>(height.ptr()); t.flow = const_cast<float *>(flow.ptr());
    t.sediment = const_cast<float *>(sediment.ptr()); t.material = const_cast<uint8_t *>(material.ptr());
    t.river = const_cast<uint8_t *>(river.ptr());
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
    if (data.has("island_hash")) {   // an authored island: the desc hash is part of the terrain hash (terrain v5)
        if (data["island_hash"].get_type() != Variant::STRING) return String();
        const String text = data["island_hash"];
        if (text.length() != 16 || !text.is_valid_hex_number(false)) return String();
        t.island_hash = (uint64_t(text.substr(0, 8).hex_to_int()) << 32) | uint64_t(text.substr(8, 8).hex_to_int());   // halves: hex_to_int is signed 64-bit
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
// cavity and wetness packed as RGBA8 ("surface"), per-chunk height bounds for culling boxes ("chunk_bounds"), and
// "relief" (RGBA8, PLAN-rock section 4): R fine signed curvature (laplacian at 1 and 2 cells), G broad signed curvature
// (5 and 10 cells), both 0.5 + 0.5 * clamp(k / 0.26, -1, 1) with > 0.5 concave (gullies) and < 0.5 convex (ridges);
// B sediment, clamp(log10(1 + sed) / log10(201), 0, 1); A sun visibility, 255 (lit) until the baked shadows (step 9).
// Presentation only: it adds nothing to the terrain hash.
Dictionary CporeTerrain::surface_maps(const Dictionary &data) {
    Dictionary out;
    int64_t n;
    float size_m;
    if (!data.has("n") || !data.has("size_m") || !data.has("height") || !data.has("flow") || !data.has("material") || !data.has("water_level") || !data.has("sediment")) return out;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return out;
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["flow"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        data["water_level"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["material"].get_type() != Variant::PACKED_BYTE_ARRAY ||
        data["sediment"].get_type() != Variant::PACKED_FLOAT32_ARRAY)
        return out;
    const PackedFloat32Array height = data["height"], flow = data["flow"], level = data["water_level"], sediment = data["sediment"];
    const PackedByteArray material = data["material"];
    const int64_t count = n * n;
    if (height.size() != count || flow.size() != count || level.size() != count || material.size() != count || sediment.size() != count) return out;
    const float *H = height.ptr();
    const float *F = flow.ptr();
    const float *L = level.ptr();
    const float *SD = sediment.ptr();
    const uint8_t *M = material.ptr();
    PackedByteArray river_arr;
    if (data.has("river") && data["river"].get_type() == Variant::PACKED_BYTE_ARRAY) river_arr = data["river"];
    const uint8_t *RV = river_arr.size() == count ? river_arr.ptr() : nullptr;
    const int N = int(n);
    const float cell = size_m / float(N);
    auto at = [&](int i, int j) { i = i < 0 ? 0 : (i >= N ? N - 1 : i); j = j < 0 ? 0 : (j >= N ? N - 1 : j); return H[j * N + i]; };
    PackedByteArray surface;
    surface.resize(count * 4);
    uint8_t *S = surface.ptrw();
    PackedByteArray relief;
    relief.resize(count * 4);
    uint8_t *RL = relief.ptrw();
    const float sed_scale = 1.f / std::log10(201.f);
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
            float kf = 0.f, kb = 0.f;     // signed curvature, fine (1, 2 cells) and broad (5, 10 cells)
            const int fine_r[2] = {1, 2}, broad_r[2] = {5, 10};
            for (int r : fine_r) {
                const float rm = float(r) * cell;
                kf += (at(i - r, j) + at(i + r, j) + at(i, j - r) + at(i, j + r) - 4.f * h) / (rm * rm) * rm * 0.5f;
            }
            for (int r : broad_r) {
                const float rm = float(r) * cell;
                kb += (at(i - r, j) + at(i + r, j) + at(i, j - r) + at(i, j + r) - 4.f * h) / (rm * rm) * rm * 0.5f;
            }
            kf = std::max(-1.f, std::min(1.f, kf / .26f));
            kb = std::max(-1.f, std::min(1.f, kb / .26f));
            const float sed = std::max(0.f, SD[k]);
            const float area = F[k] * size_m * size_m;
            float wet = (std::log10(std::max(area, 1.f)) - lo) / (hi - lo);
            wet = wet < 0.f ? 0.f : (wet > 1.f ? 1.f : wet);
            if (RV) {   // wet banks: 1 on the channel, fading over three cells (rock shows it darker, meadow greener)
                float bank = 0.f;
                for (int dj = -3; dj <= 3; ++dj) for (int di = -3; di <= 3; ++di) {
                    const int ii = i + di, jj = j + dj;
                    if (ii < 0 || jj < 0 || ii >= N || jj >= N || (RV[jj * N + ii] & 3) == 0) continue;
                    const float d = std::sqrt(float(di * di + dj * dj));
                    bank = std::max(bank, ((RV[jj * N + ii] & 3) >= 2 ? 1.f : 0.75f) * (1.f - d / 3.5f));
                }
                wet = std::max(wet, bank);
            }
            uint8_t *px = S + size_t(k) * 4;
            px[0] = M[k]; px[1] = byte01(grass); px[2] = byte01(cavity); px[3] = byte01(wet);
            uint8_t *rp = RL + size_t(k) * 4;
            rp[0] = byte01(0.5f + 0.5f * kf); rp[1] = byte01(0.5f + 0.5f * kb);
            rp[2] = byte01(std::log10(1.f + sed) * sed_scale); rp[3] = 255;
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
    out["relief"] = relief;
    out["chunk_bounds"] = bounds;
    out["chunks_per_side"] = cps;
    return out;
}

// Sun visibility (PLAN-rock step 9). A ray from every second cell towards the sun, stepped at a growing stride; the visibility is
// the smallest clearance over the terrain relative to a penumbra that widens with distance (soft shadows), 0 inside a shadow.
PackedByteArray CporeTerrain::sun_visibility(const Dictionary &data, const Vector3 &sun) {
    PackedByteArray out;
    int64_t n;
    float size_m;
    if (!data.has("n") || !data.has("size_m") || !data.has("height")) return out;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return out;
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY) return out;
    const PackedFloat32Array height = data["height"];
    if (height.size() != n * n) return out;
    const int N = int(n);
    const float cell = size_m / float(N);
    out.resize(n * n);
    uint8_t *O = out.ptrw();
    const float hl = std::sqrt(sun.x * sun.x + sun.z * sun.z);
    if (hl < 1e-4f || sun.y <= 0.f || N < 8) {
        for (int64_t k = 0; k < n * n; ++k) O[k] = 255;
        return out;
    }
    const float dx = sun.x / hl, dz = sun.z / hl, slope = sun.y / hl;
    const float *H = height.ptr();
    float max_h = -1e30f;
    for (int64_t k = 0; k < n * n; ++k) max_h = std::max(max_h, H[k]);
    auto sample = [&](float fx, float fz) {   // bilinear height at cell indices (fractional)
        fx = std::max(0.f, std::min(float(N - 1), fx));
        fz = std::max(0.f, std::min(float(N - 1), fz));
        const int i = std::min(int(fx), N - 2), j = std::min(int(fz), N - 2);
        const float u = fx - float(i), v = fz - float(j);
        const float *r = H + size_t(j) * N + i;
        const float a = r[0] + (r[1] - r[0]) * u;
        const float b = r[N] + (r[N + 1] - r[N]) * u;
        return a + (b - a) * v;
    };
    const int M = N / 2;
    std::vector<float> coarse(size_t(M) * M, 1.f), tmp(size_t(M) * M, 1.f);
    for (int b = 0; b < M; ++b) {
        for (int a = 0; a < M; ++a) {
            const float fx = float(a * 2), fz = float(b * 2);   // cell indices of the ray origin
            const float h0 = sample(fx, fz) + 0.3f;
            float vis = 1.f;
            float d = cell;   // metres along the horizontal sun direction
            while (vis > 0.f) {
                const float px = fx + dx * d / cell, pz = fz + dz * d / cell;
                if (px < 0.f || pz < 0.f || px > float(N - 1) || pz > float(N - 1)) break;
                const float ray = h0 + slope * d;
                if (ray > max_h) break;
                const float clear = ray - sample(px, pz);
                const float pen = 0.5f + 0.08f * d;
                const float c = clear / pen;
                vis = std::min(vis, c < 0.f ? 0.f : (c > 1.f ? 1.f : c));
                d += cell * (1.f + d / 600.f);
            }
            coarse[size_t(b) * M + a] = vis;
        }
    }
    for (int b = 0; b < M; ++b) {   // 3x3 box blur
        for (int a = 0; a < M; ++a) {
            float s = 0.f;
            for (int q = -1; q <= 1; ++q)
                for (int p = -1; p <= 1; ++p) s += coarse[size_t(std::max(0, std::min(M - 1, b + q))) * M + std::max(0, std::min(M - 1, a + p))];
            tmp[size_t(b) * M + a] = s / 9.f;
        }
    }
    for (int j = 0; j < N; ++j) {   // bilinear upsample to the full grid
        const float v = std::max(0.f, std::min(float(M - 1), float(j) * 0.5f));
        const int j0 = std::min(int(v), M - 2);
        const float fv = v - float(j0);
        for (int i = 0; i < N; ++i) {
            const float u = std::max(0.f, std::min(float(M - 1), float(i) * 0.5f));
            const int i0 = std::min(int(u), M - 2);
            const float fu = u - float(i0);
            const float *r = &tmp[size_t(j0) * M + i0];
            const float top = r[0] + (r[1] - r[0]) * fu, bot = r[M] + (r[M + 1] - r[M]) * fu;
            O[size_t(j) * N + i] = byte01(top + (bot - top) * fv);
        }
    }
    return out;
}

Dictionary CporeTerrain::cave_mesh(const Dictionary &params) { return cpore::build_cave_mesh(params); }
