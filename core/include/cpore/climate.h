/* cpore - moisture climate kernel (docs/plans/island-realism.md section 4, step M1).
 *
 * Pure C, no malloc, no libm trig: + - * / and sqrtf only, so native and WASM
 * give the same bytes (the terrain's float rules, plan section 0).  The caller
 * owns every buffer, scratch included.
 *
 * Smith & Barstad (2004) linear theory of orographic precipitation: the height
 * map is zero-padded to 2n x 2n, transformed with an own radix-2 FFT (twiddles
 * from a polynomial table, not libm), multiplied by the transfer function
 *
 *   Phat = Cw i sigma hhat / ([1 - i m Hw][1 + i sigma tau_c][1 + i sigma tau_f])
 *
 * and transformed back.  Reference: tools/climate/lt_ref.py (plain Python),
 * paper quotes in tools/climate/README.md.  The kernel is exercised by
 * tests/test_climate.c against fixtures written by the reference.
 *
 * On top of the precipitation: temperature (lapse rate, aspect, foehn),
 * fog, snow, a Whittaker biome lookup (climate_biomes.inc) and vegetation
 * densities.  All of it runs at generation time only.
 */
#ifndef CPORE_CLIMATE_H
#define CPORE_CLIMATE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Bump when the bytes for the same input change. */
#define CP_CLIMATE_VERSION 1

#define CP_CLIMATE_N_MIN 8
#define CP_CLIMATE_N_MAX 512

enum {
    CP_CLIM_OK = 0,
    CP_CLIM_ERR_NULL = -1,
    CP_CLIM_ERR_N = -2,       /* n not a power of two in [8, 512] */
    CP_CLIM_ERR_PARAM = -3
};

/* ---- the linear theory alone (what the tests compare with the reference) ---- */
typedef struct {
    float dx;        /* cell size in metres (climate coordinates) */
    float U, V;      /* wind in m/s along +x and +y of the grid (direction of travel) */
    float Cw;        /* uplift sensitivity, kg m^-3 (eq. 4); 0.00829 for the abstract's values */
    float Nm;        /* moist stability frequency, 1/s */
    float Hw;        /* water vapour scale height, m */
    float tau_c;     /* cloud water conversion time, s */
    float tau_f;     /* hydrometeor fall-out time, s */
    float P0;        /* background rate P_inf, mm/h (added before truncation) */
    int   truncate;  /* 1: P = max(P, 0) */
} CpLtParams;

/* floats of scratch cp_lt_precip needs for an n x n map (n a power of two). */
size_t cp_lt_scratch_floats(int n);

/* h: n*n heights in metres, row-major (y major).  P: n*n precipitation in mm/h.
 * qc (nullable): n*n cloud water in kg m^-2, derived from eq. (1a):
 *   qchat = tau_c Shat_dyn / (1 + i sigma tau_c).
 * The Nyquist row and column of the spectrum are zeroed (see lt_ref.py). */
int cp_lt_precip(const float *h, int n, const CpLtParams *p, float *P, float *qc, float *scratch);

/* ---- the climate pipeline ---- */
enum {
    CP_BIOME_SEA = 0, CP_BIOME_REEF, CP_BIOME_BEACH, CP_BIOME_MEADOW, CP_BIOME_JUNGLE,
    CP_BIOME_DRY_FOREST, CP_BIOME_SCRUB, CP_BIOME_DESERT, CP_BIOME_BADLANDS,
    CP_BIOME_ALPINE, CP_BIOME_TUNDRA, CP_BIOME_SNOW, CP_BIOME_CLIFF,
    CP_BIOME_COUNT
};

typedef struct {
    int   n;                 /* climate grid, power of two (256) */
    float cell_m;            /* game metres per climate cell (8000/256 = 31.25) */
    float scale_h;           /* horizontal climate scale (8: plan Q4, DESIGN A99 (4)) */
    float scale_z;           /* vertical climate scale (2.5: A99 (3)) */
    float wind_x, wind_y;    /* unit vector of the trade wind's direction of travel (x east, y = map y, south positive) */
    float trade_speed;       /* m/s (8) */
    float trade_w;           /* share of the year (0.75) */
    float storm_speed;       /* m/s (15), blows the opposite way */
    float storm_w;           /* share of the year (0.25) */
    float Cw, Nm, Hw, tau_c, tau_f;
    float p_inf_mm_yr;       /* background precipitation P_inf, mm/yr (enters the LT before truncation, as eq. 3 of Barstad & Smith 2005) */
    float rain_scale;        /* calibration: fraction of 8760 h the regimes produce rain (starting value, plan 4.2 step 3) */
    float t_sea_C;           /* sea-level mean temperature, C (canon F15: 14) */
    float lapse_K_km;        /* K per km of climate height (canon F15: 6.2) */
    float aspect_C;          /* cooling on slopes facing away from the sun (1.5) */
    float foehn_C;           /* warming on lee slopes (1) */
    float snow_C;            /* snow where T < this and P > 400 mm (canon snowline 1750 m: 14 - 6.2*1.75 = 3.15) */
    float qc_ref;            /* cloud water (kg m^-2) that counts as 1.0 in the qc map */
} CpClimateParams;

/* Starting values from the plan (each is a starting value, plan section 4). */
void cp_climate_defaults(CpClimateParams *p, int n, float cell_m);

/* caller-owned outputs, each n*n */
typedef struct {
    float   *precip;   /* annual precipitation, mm/yr */
    float   *temp;     /* mean annual temperature, C */
    float   *qc;       /* cloud water, 0..1 (trade regime, normalised by qc_ref) */
    float   *fog;      /* fog frequency 0..1 */
    uint8_t *biome;    /* CP_BIOME_* */
    uint8_t *veg;      /* 4 bytes per cell: canopy, undergrowth, grass, litter/moss wetness */
} CpClimateOut;

size_t cp_climate_scratch_floats(int n);

/* height: n*n game metres (sea floor negative, sea level 0), row-major.
 * canopy_mask, bias_mask: nullable u8 maps at n*n (128 = neutral; canopy 0 = no forest). */
int cp_climate_run(const CpClimateParams *p, const float *height, const uint8_t *canopy_mask,
                   const uint8_t *bias_mask, CpClimateOut *out, float *scratch);

/* FNV-1a 64 over the precip, temp, qc, fog (float bits), biome and veg planes. */
uint64_t cp_climate_hash(const CpClimateOut *out, int n);
uint64_t cp_lt_hash(const float *a, size_t count);

#ifdef __cplusplus
}
#endif
#endif
