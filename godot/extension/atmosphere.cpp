#include "atmosphere.h"
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <thread>
#include <vector>

using namespace godot;

namespace cpore_atmo {

static constexpr double PI = 3.14159265358979323846;

Params earth_params() { return Params(); }

Params canon_params() {
    Params p;
    p.ground_radius_km = 6614.0;
    p.top_radius_km = 6714.0;
    for (int c = 0; c < 3; c++) p.rayleigh_scattering[c] *= 1.6;
    p.rayleigh_scale_height_km = 7.6;
    p.mie_scattering *= 1.5;
    p.mie_absorption *= 1.5;
    p.ground_albedo = 0.12;
    return p;
}

static inline double clamp01(double x) { return x < 0.0 ? 0.0 : (x > 1.0 ? 1.0 : x); }

static inline double ozone_density(const Params &p, double h) {
    double t = 1.0 - std::fabs(h - p.ozone_center_km) / p.ozone_half_width_km;
    return t > 0.0 ? t : 0.0;
}

// Run job(index) for index in [0, n) on up to `threads` threads. Each job writes its own output, so the result is thread independent.
template <typename F>
static void parallel_for(int n, int threads, F job) {
#ifdef __EMSCRIPTEN__
    threads = 1;
#endif
    if (threads <= 1 || n <= 1) {
        for (int i = 0; i < n; i++) job(i);
        return;
    }
    std::atomic<int> next{0};
    auto worker = [&]() {
        for (int i = next.fetch_add(1); i < n; i = next.fetch_add(1)) job(i);
    };
    std::vector<std::thread> pool;
    int count = std::min(threads, n);
    for (int t = 1; t < count; t++) pool.emplace_back(worker);
    worker();
    for (auto &t : pool) t.join();
}

void build_transmittance(const Params &p, float *out, int threads) {
    const double rg = p.ground_radius_km, rt = p.top_radius_km;
    const double H = std::sqrt(rt * rt - rg * rg);
    const double mie_ext = p.mie_scattering + p.mie_absorption;
    parallel_for(TRANS_H, threads, [&](int j) {
        const double xr = j / double(TRANS_H - 1);
        const double rho = H * xr;
        const double r = std::sqrt(rho * rho + rg * rg);
        for (int i = 0; i < TRANS_W; i++) {
            const double xmu = i / double(TRANS_W - 1);
            const double dmin = rt - r, dmax = rho + H;
            const double d = dmin + xmu * (dmax - dmin);
            const double mu = d > 0.0 ? std::max(-1.0, std::min(1.0, (H * H - rho * rho - d * d) / (2.0 * r * d))) : 1.0;
            const double dt = d / TRANS_STEPS;
            double ir = 0.0, im = 0.0, io = 0.0;  // integrals of the three densities (per step sum)
            for (int s = 0; s < TRANS_STEPS; s++) {
                const double t = (s + 0.5) * dt;
                const double rs = std::sqrt(r * r + 2.0 * r * mu * t + t * t);
                const double h = std::max(rs - rg, 0.0);
                ir += std::exp(-h / p.rayleigh_scale_height_km);
                im += std::exp(-h / p.mie_scale_height_km);
                io += ozone_density(p, h);
            }
            float *o = out + (size_t(j) * TRANS_W + i) * 4;
            for (int c = 0; c < 3; c++) {
                const double tau = dt * (p.rayleigh_scattering[c] * ir + mie_ext * im + p.ozone_absorption[c] * io);
                o[c] = float(std::exp(-tau));
            }
            o[3] = 1.0f;
        }
    });
}

void lookup_transmittance(const Params &p, const float *trans, double r, double mu, double out[3]) {
    const double rg = p.ground_radius_km, rt = p.top_radius_km;
    const double H = std::sqrt(rt * rt - rg * rg);
    const double rho = std::sqrt(std::max(r * r - rg * rg, 0.0));
    const double disc = r * r * mu * mu - r * r + rt * rt;
    const double d = -r * mu + std::sqrt(std::max(disc, 0.0));
    const double dmin = rt - r, dmax = rho + H;
    const double xmu = clamp01(dmax > dmin ? (d - dmin) / (dmax - dmin) : 0.0);
    const double xr = clamp01(rho / H);
    const double fx = xmu * (TRANS_W - 1), fy = xr * (TRANS_H - 1);
    const int ix = std::min(int(fx), TRANS_W - 2), iy = std::min(int(fy), TRANS_H - 2);
    const double ax = fx - ix, ay = fy - iy;
    const float *a = trans + (size_t(iy) * TRANS_W + ix) * 4;
    const float *b = a + 4, *c = a + TRANS_W * 4, *e = c + 4;
    for (int k = 0; k < 3; k++)
        out[k] = (a[k] * (1.0 - ax) + b[k] * ax) * (1.0 - ay) + (c[k] * (1.0 - ax) + e[k] * ax) * ay;
}

namespace {
// One ray-march sample of the multiple-scattering integral that does not depend on the sun angle.
struct Sample {
    double px, pz, r;      // position relative to the planet centre, x and z only (the sun lies in the x-z plane)
    double w[3];           // throughput * (1 - step transmittance) / extinction
    double ray_sc[3];      // Rayleigh scattering coefficient at the sample
    double mie_sc;         // Mie scattering coefficient at the sample
};
struct Dir { double x, z; bool hits_ground; double gx, gy, gz; double thr[3]; };  // direction and ground-hit data
}  // namespace

void build_multiscatter(const Params &p, const float *trans, float *out, int threads) {
    const double rg = p.ground_radius_km, rt = p.top_radius_km;
    constexpr int ND = MS_DIRS_SIDE * MS_DIRS_SIDE;
    // Direction set: 8 x 8 stratified over the sphere, equal solid angle cells.
    std::vector<double> dx(ND), dy(ND), dz(ND);
    for (int a = 0; a < MS_DIRS_SIDE; a++)
        for (int b = 0; b < MS_DIRS_SIDE; b++) {
            const double az = 2.0 * PI * (a + 0.5) / MS_DIRS_SIDE;
            const double z = 1.0 - 2.0 * (b + 0.5) / MS_DIRS_SIDE;
            const double s = std::sqrt(std::max(0.0, 1.0 - z * z));
            const int k = a * MS_DIRS_SIDE + b;
            dx[k] = s * std::cos(az);
            dy[k] = s * std::sin(az);
            dz[k] = z;
        }
    const double mie_ext = p.mie_scattering + p.mie_absorption;
    const double g = p.mie_g;

    parallel_for(MS_H, threads, [&](int j) {
        const double v = j / double(MS_H - 1);
        const double r0 = rg + v * (rt - rg);
        std::vector<Sample> samples(size_t(ND) * MS_STEPS);
        std::vector<Dir> dirs(ND);
        double fms[3] = {0, 0, 0};  // eq. 7-8: independent of the sun
        for (int k = 0; k < ND; k++) {
            const double mu = dz[k];
            double tmax = -r0 * mu + std::sqrt(std::max(r0 * r0 * mu * mu - r0 * r0 + rt * rt, 0.0));
            Dir &dr = dirs[k];
            dr.x = dx[k];
            dr.z = dz[k];
            dr.hits_ground = false;
            const double gd = r0 * r0 * mu * mu - r0 * r0 + rg * rg;
            if (mu < 0.0 && gd >= 0.0) {
                dr.hits_ground = true;
                tmax = std::max(0.0, -r0 * mu - std::sqrt(gd));
            }
            const double dt = tmax / MS_STEPS;
            double thr[3] = {1, 1, 1};
            for (int s = 0; s < MS_STEPS; s++) {
                const double t = (s + 0.5) * dt;
                Sample &sm = samples[size_t(k) * MS_STEPS + s];
                sm.px = dx[k] * t;
                sm.pz = r0 + dz[k] * t;
                const double py = dy[k] * t;
                sm.r = std::sqrt(sm.px * sm.px + py * py + sm.pz * sm.pz);
                const double h = std::max(sm.r - rg, 0.0);
                const double dR = std::exp(-h / p.rayleigh_scale_height_km), dM = std::exp(-h / p.mie_scale_height_km);
                const double dO = ozone_density(p, h);
                sm.mie_sc = p.mie_scattering * dM;
                for (int c = 0; c < 3; c++) {
                    sm.ray_sc[c] = p.rayleigh_scattering[c] * dR;
                    const double sc = sm.ray_sc[c] + sm.mie_sc;
                    const double ext = sm.ray_sc[c] + mie_ext * dM + p.ozone_absorption[c] * dO;
                    const double st = std::exp(-ext * dt);
                    sm.w[c] = ext > 0.0 ? thr[c] * (1.0 - st) / ext : thr[c] * dt;
                    fms[c] += sm.w[c] * sc / ND;
                    thr[c] *= st;
                }
            }
            for (int c = 0; c < 3; c++) dr.thr[c] = thr[c];
            dr.gx = dx[k] * tmax;
            dr.gy = dy[k] * tmax;
            dr.gz = r0 + dz[k] * tmax;
        }
        for (int i = 0; i < MS_W; i++) {
            const double cs = 2.0 * (i / double(MS_W - 1)) - 1.0;  // cos(theta_sun) = 2u - 1
            const double sx = std::sqrt(std::max(0.0, 1.0 - cs * cs));
            double l2[3] = {0, 0, 0};
            for (int k = 0; k < ND; k++) {
                const double cphase = dirs[k].x * sx + dirs[k].z * cs;
                const double phr = 3.0 / (16.0 * PI) * (1.0 + cphase * cphase);
                const double phm = 3.0 / (8.0 * PI) * (1.0 - g * g) * (1.0 + cphase * cphase) /
                                   ((2.0 + g * g) * std::pow(1.0 + g * g - 2.0 * g * cphase, 1.5));
                for (int s = 0; s < MS_STEPS; s++) {
                    const Sample &sm = samples[size_t(k) * MS_STEPS + s];
                    const double mus = (sm.px * sx + sm.pz * cs) / sm.r;
                    if (mus < 0.0 && sm.r * sm.r * mus * mus - sm.r * sm.r + rg * rg >= 0.0) continue;  // planet shadow
                    double ts[3];
                    lookup_transmittance(p, trans, sm.r, mus, ts);
                    for (int c = 0; c < 3; c++) l2[c] += sm.w[c] * ts[c] * (sm.ray_sc[c] * phr + sm.mie_sc * phm);
                }
                if (dirs[k].hits_ground) {
                    const double rgr = std::sqrt(dirs[k].gx * dirs[k].gx + dirs[k].gy * dirs[k].gy + dirs[k].gz * dirs[k].gz);
                    const double mus = (dirs[k].gx * sx + dirs[k].gz * cs) / rgr;
                    if (mus > 0.0) {
                        double ts[3];
                        lookup_transmittance(p, trans, rgr, mus, ts);
                        for (int c = 0; c < 3; c++) l2[c] += dirs[k].thr[c] * ts[c] * mus * p.ground_albedo / PI;
                    }
                }
            }
            float *o = out + (size_t(j) * MS_W + i) * 4;
            for (int c = 0; c < 3; c++) o[c] = float((l2[c] / ND) / (1.0 - fms[c]));  // eq. 5, 9, 10
            o[3] = 1.0f;
        }
    });
}

}  // namespace cpore_atmo

// ---------------------------------------------------------------------------------------------------------------------
// Godot glue
// ---------------------------------------------------------------------------------------------------------------------

static Vector3 v3(const double *a) { return Vector3(float(a[0]), float(a[1]), float(a[2])); }
// Vector3 is float32: the coefficients round by 6e-8 relative, far below the 1% checks.

static Dictionary params_to_dict(const cpore_atmo::Params &p) {
    Dictionary d;
    d["ground_radius_km"] = p.ground_radius_km;
    d["top_radius_km"] = p.top_radius_km;
    d["rayleigh_scattering"] = v3(p.rayleigh_scattering);
    d["rayleigh_scale_height_km"] = p.rayleigh_scale_height_km;
    d["mie_scattering"] = p.mie_scattering;
    d["mie_absorption"] = p.mie_absorption;
    d["mie_scale_height_km"] = p.mie_scale_height_km;
    d["mie_g"] = p.mie_g;
    d["ozone_absorption"] = v3(p.ozone_absorption);
    d["ozone_center_km"] = p.ozone_center_km;
    d["ozone_half_width_km"] = p.ozone_half_width_km;
    d["ground_albedo"] = p.ground_albedo;
    return d;
}

static cpore_atmo::Params params_from_dict(const Dictionary &d) {
    cpore_atmo::Params p = cpore_atmo::canon_params();
    auto num = [&](const char *k, double &dst) {
        if (d.has(k)) dst = double(d[k]);
    };
    auto vec = [&](const char *k, double *dst) {
        if (d.has(k)) {
            Vector3 v = d[k];
            dst[0] = v.x;
            dst[1] = v.y;
            dst[2] = v.z;
        }
    };
    num("ground_radius_km", p.ground_radius_km);
    num("top_radius_km", p.top_radius_km);
    vec("rayleigh_scattering", p.rayleigh_scattering);
    num("rayleigh_scale_height_km", p.rayleigh_scale_height_km);
    num("mie_scattering", p.mie_scattering);
    num("mie_absorption", p.mie_absorption);
    num("mie_scale_height_km", p.mie_scale_height_km);
    num("mie_g", p.mie_g);
    vec("ozone_absorption", p.ozone_absorption);
    num("ozone_center_km", p.ozone_center_km);
    num("ozone_half_width_km", p.ozone_half_width_km);
    num("ground_albedo", p.ground_albedo);
    return p;
}

void CporeAtmosphere::_bind_methods() {
    ClassDB::bind_static_method("CporeAtmosphere", D_METHOD("params_canon"), &CporeAtmosphere::params_canon);
    ClassDB::bind_static_method("CporeAtmosphere", D_METHOD("params_earth"), &CporeAtmosphere::params_earth);
    ClassDB::bind_static_method("CporeAtmosphere", D_METHOD("build", "params", "threads"), &CporeAtmosphere::build, DEFVAL(0));
}

Dictionary CporeAtmosphere::params_canon() { return params_to_dict(cpore_atmo::canon_params()); }
Dictionary CporeAtmosphere::params_earth() { return params_to_dict(cpore_atmo::earth_params()); }

Dictionary CporeAtmosphere::build(const Dictionary &params, int threads) {
    using namespace cpore_atmo;
    using clock = std::chrono::steady_clock;
    const Params p = params_from_dict(params);
    if (threads <= 0) threads = int(std::min(8u, std::max(1u, std::thread::hardware_concurrency())));
    PackedByteArray tb, mb;
    tb.resize(TRANS_W * TRANS_H * 4 * sizeof(float));
    mb.resize(MS_W * MS_H * 4 * sizeof(float));
    float *tf = reinterpret_cast<float *>(tb.ptrw());
    float *mf = reinterpret_cast<float *>(mb.ptrw());
    const auto t0 = clock::now();
    build_transmittance(p, tf, threads);
    const auto t1 = clock::now();
    build_multiscatter(p, tf, mf, threads);
    const auto t2 = clock::now();
    auto ms = [](clock::time_point a, clock::time_point b) { return std::chrono::duration<double, std::milli>(b - a).count(); };
    Dictionary r;
    r["transmittance"] = Image::create_from_data(TRANS_W, TRANS_H, false, Image::FORMAT_RGBAF, tb);
    r["multiscatter"] = Image::create_from_data(MS_W, MS_H, false, Image::FORMAT_RGBAF, mb);
    r["ms_transmittance"] = ms(t0, t1);
    r["ms_multiscatter"] = ms(t1, t2);
    r["ms_total"] = ms(t0, t2);
    r["threads"] = threads;
    return r;
}
