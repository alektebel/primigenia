#pragma once
// CPU atmosphere LUTs for the Hillaire 2020 sky (docs/plans/island-realism.md part V, step H1).
//
// Model: Hillaire, "A Scalable and Production Ready Sky and Atmosphere Rendering Technique", EGSR 2020,
// eqs. 1-11. This file builds the two LUTs that are computed once (at load, or when the parameters change):
//   * transmittance, 256 x 64, 40 steps (Bruneton & Neyret 2008 parameterisation);
//   * multiple scattering Psi_ms, 32 x 32, 64 directions x 20 steps per texel.
// Both come back as FORMAT_RGBAF images (NOT RGBAH: half-float uploads flush values under 6.1e-5 to zero, see
// docs/evidence/sky/h0-spike.md). Alpha is 1.
//
// Units: kilometres and 1/km. The reference is tools/atmo/ref.py; keep the two in step.
//
// Texel -> parameter convention (the consumer remaps with the usual half-texel shift, uv = (0.5 + u*(n-1))/n):
//   transmittance: x = i/255 is x_mu, y = j/63 is x_r. With H = sqrt(Rt^2 - Rg^2), rho = H*x_r, r = sqrt(rho^2 + Rg^2),
//                  d_min = Rt - r, d_max = rho + H, d = d_min + x_mu*(d_max - d_min), mu = (H^2 - rho^2 - d^2)/(2 r d).
//   multiscatter:  x = i/31 is u = 0.5 + 0.5 cos(theta_sun), y = j/31 is v = (h - Rg)/(Rt - Rg).
// The multiscatter texel is Psi_ms for unit sun illuminance, WITHOUT the sigma_s factor of eq. 11.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace cpore_atmo {

constexpr int TRANS_W = 256, TRANS_H = 64, TRANS_STEPS = 40;
constexpr int MS_W = 32, MS_H = 32, MS_DIRS_SIDE = 8, MS_STEPS = 20;  // 8 x 8 = 64 directions

struct Params {
    double ground_radius_km = 6360.0, top_radius_km = 6460.0;
    double rayleigh_scattering[3] = {5.802e-3, 13.558e-3, 33.1e-3};
    double rayleigh_scale_height_km = 8.0;
    double mie_scattering = 3.996e-3, mie_absorption = 4.40e-3, mie_scale_height_km = 1.2, mie_g = 0.8;
    double ozone_absorption[3] = {0.650e-3, 1.881e-3, 0.085e-3};
    double ozone_center_km = 25.0, ozone_half_width_km = 15.0;
    double ground_albedo = 0.3;
};

Params earth_params();  // Table 1 of the paper
Params canon_params();  // our planet (plan 7.2): R 6614 km, Rayleigh x1.6, Mie x1.5, H_R 7.6 km, albedo 0.12

// out: TRANS_W*TRANS_H*4 floats (rgb, a = 1). threads <= 1 runs on the calling thread. Result does not depend on threads.
void build_transmittance(const Params &p, float *out, int threads);
// trans: the transmittance LUT above. out: MS_W*MS_H*4 floats.
void build_multiscatter(const Params &p, const float *trans, float *out, int threads);
// Bilinear lookup of T(r, mu) in the LUT (rgb).
void lookup_transmittance(const Params &p, const float *trans, double r, double mu, double out[3]);

}  // namespace cpore_atmo

class CporeAtmosphere : public godot::RefCounted {
    GDCLASS(CporeAtmosphere, godot::RefCounted)
protected:
    static void _bind_methods();

public:
    // Parameter dictionaries (keys listed in atmosphere.cpp, units km and 1/km). Missing keys in build() take canon values.
    static godot::Dictionary params_canon();
    static godot::Dictionary params_earth();
    // {transmittance: Image RGBAF 256x64, multiscatter: Image RGBAF 32x32, ms_total: float ms, ms_transmittance, ms_multiscatter, threads}
    // threads = 0 picks min(hardware, 8).
    static godot::Dictionary build(const godot::Dictionary &params, int threads = 0);
};
