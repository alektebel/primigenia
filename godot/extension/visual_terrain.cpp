// Visual erosion (terrain v5, docs/TERRAIN.md "Version 5"). Presentation only: it derives a 4x finer heightfield from the sim heights,
// adds rills, ridgelets and talus on it with droplet + thermal erosion, and exports the erosion maps that drive the materials.
// The sim stays authoritative: the result is S + clamp(bicubic - S + erosion, budget) where S is the exact triangle surface of the sim
// (TerrainData.ground) and the budget is small on walkable ground and zero-ish near rivers, lakes and the coast.
// Deterministic for a given input and options, independent of the thread count (disjoint tile phases, per-tile RNG).
#pragma GCC optimize("O2")
#include "cpore_terrain.h"
#include "convert.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <chrono>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <thread>
#include <vector>
extern "C" {
#include "cpore/terrain.h"
}

using namespace godot;

namespace {

float clampf(float v, float a, float b) { return v < a ? a : (v > b ? b : v); }
float smooth(float a, float b, float x) {
    const float t = clampf((x - a) / (b - a), 0.f, 1.f);
    return t * t * (3.f - 2.f * t);
}
uint8_t byte01(float v) { return uint8_t(std::floor(clampf(v, 0.f, 1.f) * 255.f + 0.5f)); }

struct Rng {
    uint32_t s;
    explicit Rng(uint32_t seed) : s(seed * 2654435761u + 0x9E3779B9u) { if (!s) s = 1; for (int i = 0; i < 4; ++i) next(); }
    uint32_t next() { s ^= s << 13; s ^= s >> 17; s ^= s << 5; return s; }
    float uni() { return float(next() >> 8) * (1.0f / 16777216.0f); }
};

void parallel_rows(int count, int threads, const std::function<void(int, int)> &fn) {
    threads = std::max(1, std::min(threads, count));
    if (threads == 1) { fn(0, count); return; }
    std::vector<std::thread> pool;
    for (int t = 0; t < threads; ++t) {
        const int a = int(int64_t(count) * t / threads), b = int(int64_t(count) * (t + 1) / threads);
        pool.emplace_back([&fn, a, b] { fn(a, b); });
    }
    for (auto &th : pool) th.join();
}

struct Sim {
    int N = 0;
    float cell = 0.f, half = 0.f;
    const float *H = nullptr;
    float at(int i, int j) const { i = i < 0 ? 0 : (i >= N ? N - 1 : i); j = j < 0 ? 0 : (j >= N ? N - 1 : j); return H[size_t(j) * N + i]; }
    // The exact LOD0 triangle surface (TerrainData.ground): diagonal (i+1, j) - (i, j+1).
    float tri(float u, float v) const {
        int i = int(std::floor(u)), j = int(std::floor(v));
        i = std::max(0, std::min(N - 2, i));
        j = std::max(0, std::min(N - 2, j));
        const float fu = clampf(u - float(i), 0.f, 1.f), fv = clampf(v - float(j), 0.f, 1.f);
        const float h00 = at(i, j), h10 = at(i + 1, j), h01 = at(i, j + 1), h11 = at(i + 1, j + 1);
        return fu >= fv ? h00 + fu * (h10 - h00) + fv * (h11 - h10) : h00 + fv * (h01 - h00) + fu * (h11 - h01);
    }
    // Catmull-Rom bicubic height.
    float cubic(float u, float v) const {
        const int i = int(std::floor(u)), j = int(std::floor(v));
        const float fx = u - float(i), fy = v - float(j);
        auto w = [](float f, float *o) {
            const float f2 = f * f, f3 = f2 * f;
            o[0] = (-f3 + 2.f * f2 - f) * 0.5f; o[1] = (3.f * f3 - 5.f * f2 + 2.f) * 0.5f;
            o[2] = (-3.f * f3 + 4.f * f2 + f) * 0.5f; o[3] = (f3 - f2) * 0.5f;
        };
        float wx[4], wy[4];
        w(fx, wx); w(fy, wy);
        float s = 0.f;
        for (int b = 0; b < 4; ++b) {
            float row = 0.f;
            for (int a = 0; a < 4; ++a) row += wx[a] * at(i + a - 1, j + b - 1);
            s += row * wy[b];
        }
        return s;
    }
};

struct Opt {
    int factor = 4;
    float droplets = 0.12f;     // droplets per visual cell
    int lifetime = 90;
    float inertia = 0.1f, capacity = 4.f, erode = 0.3f, deposit = 0.3f, evaporate = 0.012f, gravity = 4.f, min_slope = 0.008f;
    int brush = 2;
    float strength = 3.0f;      // multiplies the droplet height change before the budget clamp
    int thermal = 6;
    float talus_deg = 36.f;
    float walk_budget = 0.4f;   // metres of |visual - sim| allowed on gentle ground
    float water_budget = 0.06f; // next to rivers, lakes and the coast
    float cliff_budget = 10.f;  // on steep rock
    int seed = 1;
    int threads = 0;
};

}  // namespace

// Options (all optional): factor 2..8 (default 4), droplets, lifetime, strength, thermal, talus_deg, walk_budget, water_budget, cliff_budget, seed, threads.
// Returns {} on invalid input, else {vn, factor, vheight (uint16 LE, vn*vn), vh_min, vh_range, vmaps (RGBA8, (vn/2)^2: R flow/wetness,
// G droplet deposition, B thermal talus apron, A exposure 0.5 flat, > 0.5 convex), vhash, stats}.
Dictionary CporeTerrain::visual_maps(const Dictionary &data, const Dictionary &options) {
    Dictionary out;
    int64_t n;
    float size_m;
    if (!data.has("n") || !data.has("size_m") || !data.has("height") || !data.has("water_level") || !data.has("river")) return out;
    if (!cpore::to_int(data["n"], CP_TERRAIN_N_MIN, CP_TERRAIN_N_MAX, n) || !cpore::to_float(data["size_m"], size_m)) return out;
    if (data["height"].get_type() != Variant::PACKED_FLOAT32_ARRAY || data["water_level"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
        data["river"].get_type() != Variant::PACKED_BYTE_ARRAY)
        return out;
    const PackedFloat32Array height = data["height"], level = data["water_level"];
    const PackedByteArray river = data["river"];
    if (height.size() != n * n || level.size() != n * n || river.size() != n * n) return out;

    Opt o;
    auto geti = [&](const char *k, int &v, int lo, int hi) { if (options.has(k)) { int64_t x; if (cpore::to_int(options[k], lo, hi, x)) v = int(x); } };
    auto getf = [&](const char *k, float &v) { if (options.has(k)) { float x; if (cpore::to_float(options[k], x)) v = x; } };
    geti("factor", o.factor, 2, 8); geti("lifetime", o.lifetime, 4, 400); geti("thermal", o.thermal, 0, 64); geti("seed", o.seed, 0, 2147483647);
    geti("threads", o.threads, 0, 64); geti("brush", o.brush, 1, 4);
    getf("droplets", o.droplets); getf("strength", o.strength); getf("talus_deg", o.talus_deg); getf("walk_budget", o.walk_budget);
    getf("water_budget", o.water_budget); getf("cliff_budget", o.cliff_budget); getf("inertia", o.inertia); getf("erode", o.erode);
    getf("deposit", o.deposit);
    if (o.threads <= 0) o.threads = int(std::max(1u, std::min(8u, std::thread::hardware_concurrency())));
    const auto t0 = std::chrono::steady_clock::now();

    Sim sim;
    sim.N = int(n);
    sim.cell = size_m / float(sim.N);
    sim.half = size_m * 0.5f;
    sim.H = height.ptr();
    const int N = sim.N, F = o.factor, VN = N * F, MN = VN / 2;
    const float vcell = sim.cell / float(F);
    const size_t VC = size_t(VN) * VN;

    // Sim-resolution masks: slope (tan) and protection (rivers, ponds, coast; 1 on the feature, fading over ~3 cells).
    std::vector<float> slope(size_t(N) * N), protect(size_t(N) * N, 0.f);
    {
        const float *L = level.ptr();
        const uint8_t *RV = river.ptr();
        std::vector<uint8_t> core(size_t(N) * N, 0);
        for (int j = 0; j < N; ++j)
            for (int i = 0; i < N; ++i) {
                const size_t k = size_t(j) * N + i;
                const float gx = (sim.at(i + 1, j) - sim.at(i - 1, j)) / (2.f * sim.cell);
                const float gy = (sim.at(i, j + 1) - sim.at(i, j - 1)) / (2.f * sim.cell);
                slope[k] = std::sqrt(gx * gx + gy * gy);
                const float h = sim.H[k];
                core[k] = (RV[k] & 3) != 0 || (L[k] - h > 0.5f && h > 0.f) || h < 1.5f;
            }
        for (int j = 0; j < N; ++j)
            for (int i = 0; i < N; ++i) {
                float p = 0.f;
                for (int dj = -3; dj <= 3; ++dj)
                    for (int di = -3; di <= 3; ++di) {
                        const int ii = i + di, jj = j + dj;
                        if (ii < 0 || jj < 0 || ii >= N || jj >= N || !core[size_t(jj) * N + ii]) continue;
                        p = std::max(p, 1.f - std::sqrt(float(di * di + dj * dj)) / 3.5f);
                    }
                const float h = sim.H[size_t(j) * N + i];
                protect[size_t(j) * N + i] = std::max(p, 1.f - smooth(0.5f, 3.5f, h));
            }
    }
    auto bil = [&](const std::vector<float> &m, float u, float v) {   // bilinear at sim cell coords
        u = clampf(u, 0.f, float(N - 1)); v = clampf(v, 0.f, float(N - 1));
        const int i = std::min(int(u), N - 2), j = std::min(int(v), N - 2);
        const float fu = u - float(i), fv = v - float(j);
        const float *r = &m[size_t(j) * N + i];
        const float a = r[0] + (r[1] - r[0]) * fu, b = r[N] + (r[N + 1] - r[N]) * fu;
        return a + (b - a) * fv;
    };

    // 1. Bicubic base (the smooth surface the sim would be if it were not piecewise linear).
    std::vector<float> V(VC);
    auto cubic_at = [&](int i, int j) { return sim.cubic((float(i) + 0.5f) / float(F) - 0.5f, (float(j) + 0.5f) / float(F) - 0.5f); };
    parallel_rows(VN, o.threads, [&](int a, int b) {
        for (int j = a; j < b; ++j)
            for (int i = 0; i < VN; ++i) V[size_t(j) * VN + i] = cubic_at(i, j);
    });

    // 2. Droplet erosion, tiles of BS cells in four checkerboard phases; same-phase tiles are at least BS cells apart, further than a
    // droplet travels, so they never touch the same texel and the result does not depend on the thread count.
    const int BS = std::max(64, std::min(512, VN));
    const int tiles = (VN + BS - 1) / BS;
    std::vector<float> flow(size_t(MN) * MN, 0.f), dep(size_t(MN) * MN, 0.f), apron(size_t(MN) * MN, 0.f);
    std::vector<float> E0 = V;   // before erosion, to measure the delta
    const int R = o.brush;
    std::vector<float> bw;       // brush weights (2R+1)^2
    {
        float sum = 0.f;
        for (int y = -R; y <= R; ++y)
            for (int x = -R; x <= R; ++x) {
                const float d = std::sqrt(float(x * x + y * y));
                const float w = std::max(0.f, float(R) + 0.5f - d);
                bw.push_back(w); sum += w;
            }
        for (float &w : bw) w /= sum;
    }
    const float vc = vcell;
    auto droplet_tile = [&](int tx, int ty) {
        Rng rng(uint32_t(o.seed) * 7919u + uint32_t(ty * tiles + tx) * 104729u + 13u);
        const int x0 = tx * BS, y0 = ty * BS, x1 = std::min(VN, x0 + BS), y1 = std::min(VN, y0 + BS);
        const int count = int(o.droplets * float(x1 - x0) * float(y1 - y0));
        for (int d = 0; d < count; ++d) {
            float px = float(x0) + rng.uni() * float(x1 - x0), py = float(y0) + rng.uni() * float(y1 - y0);
            float dx = 0.f, dy = 0.f, speed = 1.f, water = 1.f, sed = 0.f;
            for (int life = 0; life < o.lifetime; ++life) {
                const int ix = int(px), iy = int(py);
                if (ix < 2 || iy < 2 || ix >= VN - 3 || iy >= VN - 3) break;
                const float fx = px - float(ix), fy = py - float(iy);
                float *c = &V[size_t(iy) * VN + ix];
                const float h00 = c[0], h10 = c[1], h01 = c[VN], h11 = c[VN + 1];
                const float gx = ((h10 - h00) * (1.f - fy) + (h11 - h01) * fy) / vc;
                const float gy = ((h01 - h00) * (1.f - fx) + (h11 - h10) * fx) / vc;
                const float hcur = h00 * (1.f - fx) * (1.f - fy) + h10 * fx * (1.f - fy) + h01 * (1.f - fx) * fy + h11 * fx * fy;
                dx = dx * o.inertia - gx * (1.f - o.inertia);
                dy = dy * o.inertia - gy * (1.f - o.inertia);
                const float len = std::sqrt(dx * dx + dy * dy);
                if (len < 1e-5f) { const float a = rng.uni() * 6.2831853f; dx = std::cos(a); dy = std::sin(a); }
                else { dx /= len; dy /= len; }
                const float nx = px + dx, ny = py + dy;
                const int jx = int(nx), jy = int(ny);
                if (jx < 1 || jy < 1 || jx >= VN - 2 || jy >= VN - 2 || hcur < 0.4f) break;
                const float *cn = &V[size_t(jy) * VN + jx];
                const float gx2 = nx - float(jx), gy2 = ny - float(jy);
                const float hnew = cn[0] * (1.f - gx2) * (1.f - gy2) + cn[1] * gx2 * (1.f - gy2) + cn[VN] * (1.f - gx2) * gy2 + cn[VN + 1] * gx2 * gy2;
                const float dh = hnew - hcur;
                const float cap = std::max(-dh / vc, o.min_slope) * speed * water * o.capacity * vc;
                float *cc = &V[size_t(iy) * VN + ix];
                if (sed > cap || dh > 0.f) {
                    const float amt = dh > 0.f ? std::min(dh, sed) : (sed - cap) * o.deposit;
                    sed -= amt;
                    cc[0] += amt * (1.f - fx) * (1.f - fy); cc[1] += amt * fx * (1.f - fy);
                    cc[VN] += amt * (1.f - fx) * fy; cc[VN + 1] += amt * fx * fy;
                    dep[size_t(iy / 2) * MN + ix / 2] += amt;
                } else {
                    const float amt = std::min((cap - sed) * o.erode, -dh);
                    int q = 0;
                    for (int y = -R; y <= R; ++y)
                        for (int x = -R; x <= R; ++x, ++q) V[size_t(iy + y) * VN + ix + x] -= amt * bw[q];
                    sed += amt;
                }
                flow[size_t(iy / 2) * MN + ix / 2] += water;
                speed = std::sqrt(std::max(0.f, speed * speed + dh / vc * o.gravity * vc));
                water *= 1.f - o.evaporate;
                px = nx; py = ny;
                if (water < 0.02f) break;
            }
        }
    };
    for (int phase = 0; phase < 4; ++phase) {
        std::vector<std::pair<int, int>> work;
        for (int ty = 0; ty < tiles; ++ty)
            for (int tx = 0; tx < tiles; ++tx)
                if ((tx & 1) + 2 * (ty & 1) == phase) work.push_back({tx, ty});
        parallel_rows(int(work.size()), o.threads, [&](int a, int b) { for (int k = a; k < b; ++k) droplet_tile(work[k].first, work[k].second); });
    }

    // 3. Amplify and bound the droplet delta, then thermal talus on the result.
    //    The delta is soft-limited later by the budget; here only the strength.
    parallel_rows(VN, o.threads, [&](int a, int b) {
        for (int j = a; j < b; ++j)
            for (int i = 0; i < VN; ++i) {
                const size_t k = size_t(j) * VN + i;
                V[k] = E0[k] + (V[k] - E0[k]) * o.strength;
            }
    });
    {
        std::vector<float> tmp(VC);
        const float T = std::tan(o.talus_deg * 0.0174532925f) * vcell;
        for (int it = 0; it < o.thermal; ++it) {
            parallel_rows(MN, o.threads, [&](int a, int b) {   // row pairs: each half-res cell belongs to one thread
                for (int j2 = a; j2 < b; ++j2)
                    for (int jj = 0; jj < 2; ++jj) {
                        const int j = j2 * 2 + jj;
                        for (int i = 0; i < VN; ++i) {
                            const size_t k = size_t(j) * VN + i;
                            const float h = V[k];
                            float net = 0.f;
                            const int off[4][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
                            for (auto &d : off) {
                                const int ii = i + d[0], jn = j + d[1];
                                if (ii < 0 || jn < 0 || ii >= VN || jn >= VN) continue;
                                const float hn = V[size_t(jn) * VN + ii];
                                const float diff = h - hn;
                                if (diff > T) net -= (diff - T) * 0.2f;       // outflow
                                else if (-diff > T) net += (-diff - T) * 0.2f; // inflow from the higher neighbour
                            }
                            tmp[k] = h + net;
                            if (net > 0.f) apron[size_t(j2) * MN + i / 2] += net;
                        }
                    }
            });
            V.swap(tmp);
        }
    }

    // 4. Bound against the sim: visual = S + soft-clamp(V - S, budget).
    float vmin = 1e30f, vmax = -1e30f;
    std::vector<float> mins(o.threads, 1e30f), maxs(o.threads, -1e30f);
    PackedByteArray vh;
    vh.resize(int64_t(VC) * 2);
    uint8_t *VH = vh.ptrw();
    std::vector<float> fin(VC);
    {
        std::atomic<int> slot{0};
        parallel_rows(VN, o.threads, [&](int a, int b) {
            const int me = slot.fetch_add(1);
            float lo = 1e30f, hi = -1e30f;
            for (int j = a; j < b; ++j)
                for (int i = 0; i < VN; ++i) {
                    const size_t k = size_t(j) * VN + i;
                    const float u = (float(i) + 0.5f) / float(F) - 0.5f, v = (float(j) + 0.5f) / float(F) - 0.5f;
                    const float S = sim.tri(u, v);
                    const float g = bil(slope, u, v), p = bil(protect, u, v);
                    float budget = o.walk_budget + (o.cliff_budget - o.walk_budget) * smooth(0.9f, 1.8f, g);
                    budget = o.water_budget + (budget - o.water_budget) * (1.f - smooth(0.0f, 0.5f, p));
                    const float dlt = V[k] - S;
                    const float h = S + budget * std::tanh(dlt / budget);
                    fin[k] = h;
                    lo = std::min(lo, h); hi = std::max(hi, h);
                }
            mins[me] = lo; maxs[me] = hi;
        });
        for (int t = 0; t < o.threads; ++t) { vmin = std::min(vmin, mins[t]); vmax = std::max(vmax, maxs[t]); }
    }
    const float vrange = std::max(vmax - vmin, 1e-3f);
    parallel_rows(VN, o.threads, [&](int a, int b) {
        for (int j = a; j < b; ++j)
            for (int i = 0; i < VN; ++i) {
                const size_t k = size_t(j) * VN + i;
                const int q = int(std::floor((fin[k] - vmin) / vrange * 65535.f + 0.5f));
                const uint16_t w = uint16_t(q < 0 ? 0 : (q > 65535 ? 65535 : q));
                VH[k * 2] = uint8_t(w & 255); VH[k * 2 + 1] = uint8_t(w >> 8);
            }
    });

    // 5. Maps at half the visual resolution: R flow (log), G deposition, B talus apron, A exposure (convexity).
    auto pct = [&](std::vector<float> v, float q) {
        std::vector<float> s;
        for (float x : v) if (x > 0.f) s.push_back(x);
        if (s.empty()) return 1.f;
        const size_t idx = std::min(s.size() - 1, size_t(float(s.size()) * q));
        std::nth_element(s.begin(), s.begin() + idx, s.end());
        return std::max(s[idx], 1e-6f);
    };
    const float flow_ref = pct(flow, 0.995f), dep_ref = pct(dep, 0.99f), apron_ref = pct(apron, 0.99f);
    PackedByteArray maps;
    maps.resize(int64_t(MN) * MN * 4);
    uint8_t *MP = maps.ptrw();
    auto fh = [&](int i, int j) { i = i < 0 ? 0 : (i >= VN ? VN - 1 : i); j = j < 0 ? 0 : (j >= VN ? VN - 1 : j); return fin[size_t(j) * VN + i]; };
    parallel_rows(MN, o.threads, [&](int a, int b) {
        for (int j = a; j < b; ++j)
            for (int i = 0; i < MN; ++i) {
                const size_t k = size_t(j) * MN + i;
                const int ci = i * 2, cj = j * 2;
                float lap = 0.f;
                const int rr[2] = {3, 7};
                for (int r : rr) {
                    const float rm = float(r) * vcell;
                    lap += (fh(ci - r, cj) + fh(ci + r, cj) + fh(ci, cj - r) + fh(ci, cj + r) - 4.f * fh(ci, cj)) / (rm * rm) * rm * 0.5f;
                }
                const float fl = clampf(std::log(1.f + flow[k] / flow_ref * 8.f) / std::log(9.f), 0.f, 1.f);
                uint8_t *px = MP + k * 4;
                px[0] = byte01(fl);
                px[1] = byte01(dep[k] / dep_ref);
                px[2] = byte01(apron[k] / apron_ref);
                px[3] = byte01(0.5f - 0.5f * clampf(lap / 0.26f, -1.f, 1.f));
            }
    });

    uint64_t h = 1469598103934665603ULL;
    for (int64_t k = 0; k < vh.size(); k += 17) h = (h ^ VH[k]) * 1099511628211ULL;
    for (int64_t k = 0; k < maps.size(); k += 7) h = (h ^ MP[k]) * 1099511628211ULL;

    Dictionary stats;
    stats["ms"] = int64_t(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - t0).count());
    stats["threads"] = o.threads;
    stats["droplets"] = int64_t(o.droplets * float(VC));
    stats["flow_ref"] = flow_ref;
    out["vn"] = VN;
    out["factor"] = F;
    out["vheight"] = vh;
    out["vh_min"] = vmin;
    out["vh_range"] = vrange;
    out["vmaps"] = maps;
    out["vhash"] = cpore::hash_text(h);
    out["vstats"] = stats;
    return out;
}
