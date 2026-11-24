/* cpore - moisture climate kernel (plan section 4, step M1).  See climate.h.
 * Float rules: + - * / and sqrtf only; no libm trig; compiled
 * -fno-fast-math -ffp-contract=off (Makefile). */
#include "cpore/climate.h"
#include <math.h>
#include <string.h>

/* ---------------------------------------------------------------------- */
/* small helpers                                                           */
/* ---------------------------------------------------------------------- */
static float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
static float smoothstep(float e0, float e1, float x)
{
    float t = clampf((x - e0) / (e1 - e0), 0.f, 1.f);
    return t * t * (3.f - 2.f * t);
}
static int is_pow2(int n) { return n > 0 && (n & (n - 1)) == 0; }

/* ---------------------------------------------------------------------- */
/* twiddles: sin/cos by Taylor polynomial in double, octant reduction on   */
/* integers.  + - * / only.                                                */
/* ---------------------------------------------------------------------- */
static void sincos_small(double a, double *s, double *c)
{   /* a in [0, pi/4]; terms to a^23, error < 1e-19 */
    double a2 = a * a, t;
    t = 1.0 - a2 / (22.0 * 23.0);
    t = 1.0 - a2 / (20.0 * 21.0) * t;
    t = 1.0 - a2 / (18.0 * 19.0) * t;
    t = 1.0 - a2 / (16.0 * 17.0) * t;
    t = 1.0 - a2 / (14.0 * 15.0) * t;
    t = 1.0 - a2 / (12.0 * 13.0) * t;
    t = 1.0 - a2 / (10.0 * 11.0) * t;
    t = 1.0 - a2 / (8.0 * 9.0) * t;
    t = 1.0 - a2 / (6.0 * 7.0) * t;
    t = 1.0 - a2 / (4.0 * 5.0) * t;
    t = 1.0 - a2 / (2.0 * 3.0) * t;
    *s = a * t;
    t = 1.0 - a2 / (21.0 * 22.0);
    t = 1.0 - a2 / (19.0 * 20.0) * t;
    t = 1.0 - a2 / (17.0 * 18.0) * t;
    t = 1.0 - a2 / (15.0 * 16.0) * t;
    t = 1.0 - a2 / (13.0 * 14.0) * t;
    t = 1.0 - a2 / (11.0 * 12.0) * t;
    t = 1.0 - a2 / (9.0 * 10.0) * t;
    t = 1.0 - a2 / (7.0 * 8.0) * t;
    t = 1.0 - a2 / (5.0 * 6.0) * t;
    t = 1.0 - a2 / (3.0 * 4.0) * t;
    t = 1.0 - a2 / (1.0 * 2.0) * t;
    *c = t;
}

#define TWO_PI_D 6.283185307179586476925286766559

/* cos and sin of 2 pi j / N for 0 <= j <= N/2, N a multiple of 8 */
static void cs_index(int j, int N, double *c, double *s)
{
    double a, sn, cn;
    if (8 * j <= N) {
        a = TWO_PI_D * (double)j / (double)N;
        sincos_small(a, &sn, &cn);
        *c = cn; *s = sn;
    } else if (4 * j <= N) {
        a = TWO_PI_D * (double)(N / 4 - j) / (double)N;
        sincos_small(a, &sn, &cn);
        *c = sn; *s = cn;
    } else if (8 * j <= 3 * N) {
        a = TWO_PI_D * (double)(j - N / 4) / (double)N;
        sincos_small(a, &sn, &cn);
        *c = -sn; *s = cn;
    } else {
        a = TWO_PI_D * (double)(N / 2 - j) / (double)N;
        sincos_small(a, &sn, &cn);
        *c = -cn; *s = sn;
    }
}

/* tw[2j], tw[2j+1] = cos, -sin of 2 pi j / N, j < N/2 (forward transform e^{-i}) */
static void make_twiddles(float *tw, int N)
{
    int j;
    for (j = 0; j < N / 2; j++) {
        double c, s;
        cs_index(j, N, &c, &s);
        tw[2 * j] = (float)c;
        tw[2 * j + 1] = (float)(-s);
    }
}

/* ---------------------------------------------------------------------- */
/* FFT: iterative radix-2, interleaved re/im, in place, unnormalised.      */
/* tw has size NT/2 entries; this transform has m points (m divides NT).   */
/* ---------------------------------------------------------------------- */
static void fft(float *a, int m, const float *tw, int NT, int inverse)
{
    int i, j, len, half, step, k;
    float sg = inverse ? -1.f : 1.f;
    for (i = 1, j = 0; i < m; i++) {
        int bit = m >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            float tr = a[2 * i], ti = a[2 * i + 1];
            a[2 * i] = a[2 * j]; a[2 * i + 1] = a[2 * j + 1];
            a[2 * j] = tr; a[2 * j + 1] = ti;
        }
    }
    /* len = 2: w = 1 */
    for (i = 0; i < m; i += 2) {
        float ur = a[2 * i], ui = a[2 * i + 1], vr = a[2 * i + 2], vi = a[2 * i + 3];
        a[2 * i] = ur + vr; a[2 * i + 1] = ui + vi;
        a[2 * i + 2] = ur - vr; a[2 * i + 3] = ui - vi;
    }
    /* len = 4: w = 1, -i (forward) / +i (inverse) */
    if (m >= 4) {
        for (i = 0; i < m; i += 4) {
            float *p = a + 2 * i;
            float ur = p[0], ui = p[1], vr = p[4], vi = p[5];
            float tr, ti;
            p[0] = ur + vr; p[1] = ui + vi; p[4] = ur - vr; p[5] = ui - vi;
            ur = p[2]; ui = p[3];
            /* v * (0, -sg) = (sg*vi, -sg*vr) with v = p[6],p[7] */
            tr = sg * p[7]; ti = -sg * p[6];
            p[2] = ur + tr; p[3] = ui + ti; p[6] = ur - tr; p[7] = ui - ti;
        }
    }
    for (len = 8; len <= m; len <<= 1) {
        half = len >> 1;
        step = NT / len;
        for (i = 0; i < m; i += len) {
            float *p = a + 2 * i, *q = a + 2 * (i + half);
            for (k = 0; k < half; k++) {
                float wr = tw[2 * k * step], wi = sg * tw[2 * k * step + 1];
                float vr = q[2 * k] * wr - q[2 * k + 1] * wi;
                float vi = q[2 * k] * wi + q[2 * k + 1] * wr;
                float ur = p[2 * k], ui = p[2 * k + 1];
                p[2 * k] = ur + vr; p[2 * k + 1] = ui + vi;
                q[2 * k] = ur - vr; q[2 * k + 1] = ui - vi;
            }
        }
    }
}

/* ---------------------------------------------------------------------- */
/* linear theory                                                           */
/* ---------------------------------------------------------------------- */
/* scratch layout (floats), N = 2n, C = N/2 + 1 columns of N complex:
 *   H   [C * 2N]   forward spectrum, column kx contiguous over ky
 *   W   [C * 2N]   transfer-function product, then inverse over ky
 *   row [2N]       one row buffer
 *   tw  [N]        twiddles (N/2 complex)
 *   lv  [N]        l (wavenumber along y) per ky index
 */
size_t cp_lt_scratch_floats(int n)
{
    size_t N = (size_t)2 * (size_t)n, C = N / 2 + 1;
    return 2 * C * 2 * N + 2 * N + N + N;
}

/* transfer function Phat/hhat (real part tr, imag part ti); cloud != 0 gives
 * the cloud-water transfer function instead */
static void transfer(float k, float l, const CpLtParams *p, int cloud, float *tr, float *ti)
{
    float sigma = p->U * k + p->V * l;
    float s2, K2, m2, dr, di, cr, ci, Dr, Di, A, den;
    if (sigma > -1e-12f && sigma < 1e-12f) { *tr = 0.f; *ti = 0.f; return; }
    s2 = sigma * sigma;
    K2 = k * k + l * l;
    m2 = (p->Nm * p->Nm - s2) / s2 * K2;
    if (m2 >= 0.f) {
        float m = sqrtf(m2);
        if (sigma < 0.f) m = -m;
        dr = 1.f; di = -m * p->Hw;                 /* 1 - i m Hw */
    } else {
        dr = 1.f + sqrtf(-m2) * p->Hw; di = 0.f;   /* m = + i sqrt(-m2): 1 - i m Hw = 1 + r Hw */
    }
    if (cloud) {   /* (1 + i sigma tau_c) only */
        cr = 1.f; ci = sigma * p->tau_c;
        A = p->Cw * sigma * p->tau_c;
    } else {       /* (1 + i sigma tau_c)(1 + i sigma tau_f) */
        cr = 1.f - s2 * p->tau_c * p->tau_f;
        ci = sigma * (p->tau_c + p->tau_f);
        A = p->Cw * sigma;
    }
    Dr = dr * cr - di * ci;
    Di = dr * ci + di * cr;
    den = Dr * Dr + Di * Di;
    /* (i A) / (Dr + i Di) = A (Di + i Dr) / den */
    *tr = A * Di / den;
    *ti = A * Dr / den;
}

static void apply_transfer(const float *H, float *W, int N, const CpLtParams *p, const float *lv, int cloud)
{
    int kx, ky;
    float kscale = 6.2831853071795864769f / ((float)N * p->dx);
    for (kx = 0; kx <= N / 2; kx++) {
        const float *h = H + (size_t)kx * 2 * N;
        float *w = W + (size_t)kx * 2 * N;
        float k = kscale * (float)kx;
        if (kx == N / 2) { memset(w, 0, sizeof(float) * 2 * (size_t)N); continue; }
        for (ky = 0; ky < N; ky++) {
            float tr, ti, hr, hi;
            if (ky == N / 2) { w[2 * ky] = 0.f; w[2 * ky + 1] = 0.f; continue; }
            transfer(k, lv[ky], p, cloud, &tr, &ti);
            hr = h[2 * ky]; hi = h[2 * ky + 1];
            w[2 * ky] = tr * hr - ti * hi;
            w[2 * ky + 1] = tr * hi + ti * hr;
        }
    }
}

/* inverse transform of W (columns over ky, then rows over kx), real output
 * into out (n*n), scaled by scale */
static void inverse_to_real(float *W, int n, int N, const float *tw, float *row, float *out, float scale)
{
    int kx, y, x, off = (N - n) / 2;
    for (kx = 0; kx <= N / 2; kx++) fft(W + (size_t)kx * 2 * N, N, tw, N, 1);
    for (y = 0; y < n; y += 2) {
        int ya = off + y, yb = ya + 1;
        for (kx = 0; kx < N; kx++) {
            float gar, gai, gbr, gbi;
            if (kx <= N / 2) {
                const float *c = W + (size_t)kx * 2 * N;
                gar = c[2 * ya]; gai = c[2 * ya + 1]; gbr = c[2 * yb]; gbi = c[2 * yb + 1];
            } else {
                const float *c = W + (size_t)(N - kx) * 2 * N;   /* Hermitian mirror */
                gar = c[2 * ya]; gai = -c[2 * ya + 1]; gbr = c[2 * yb]; gbi = -c[2 * yb + 1];
            }
            /* Z = Ga + i Gb */
            row[2 * kx] = gar - gbi;
            row[2 * kx + 1] = gai + gbr;
        }
        fft(row, N, tw, N, 1);
        for (x = 0; x < n; x++) {
            out[y * n + x] = row[2 * (off + x)] * scale;
            out[(y + 1) * n + x] = row[2 * (off + x) + 1] * scale;
        }
    }
}

int cp_lt_precip(const float *h, int n, const CpLtParams *p, float *P, float *qc, float *scratch)
{
    int N, C, y, x, kx, ky, off;
    float *H, *W, *row, *tw, *lv, kscale, invN2;
    if (!h || !p || !P || !scratch) return CP_CLIM_ERR_NULL;
    if (n < CP_CLIMATE_N_MIN || n > CP_CLIMATE_N_MAX || !is_pow2(n)) return CP_CLIM_ERR_N;
    if (!(p->dx > 0.f)) return CP_CLIM_ERR_PARAM;
    N = 2 * n; C = N / 2 + 1; off = (N - n) / 2;
    H = scratch;
    W = H + (size_t)C * 2 * N;
    row = W + (size_t)C * 2 * N;
    tw = row + 2 * N;
    lv = tw + N;
    make_twiddles(tw, N);
    kscale = 6.2831853071795864769f / ((float)N * p->dx);
    for (ky = 0; ky < N; ky++) lv[ky] = kscale * (float)(ky < N / 2 ? ky : ky - N);

    /* forward: rows in real pairs, kept columns kx = 0..N/2 */
    memset(H, 0, sizeof(float) * (size_t)C * 2 * N);
    for (y = 0; y < n; y += 2) {
        memset(row, 0, sizeof(float) * 2 * (size_t)N);
        for (x = 0; x < n; x++) {
            row[2 * (off + x)] = h[y * n + x];
            row[2 * (off + x) + 1] = h[(y + 1) * n + x];
        }
        fft(row, N, tw, N, 0);
        for (kx = 0; kx <= N / 2; kx++) {
            int km = (N - kx) & (N - 1);
            float zr = row[2 * kx], zi = row[2 * kx + 1], mr = row[2 * km], mi = row[2 * km + 1];
            /* A = (Z + conj Zm)/2, B = (Z - conj Zm)/(2i) */
            float ar = .5f * (zr + mr), ai = .5f * (zi - mi);
            float br = .5f * (zi + mi), bi = -.5f * (zr - mr);
            float *c = H + (size_t)kx * 2 * N;
            c[2 * (off + y)] = ar; c[2 * (off + y) + 1] = ai;
            c[2 * (off + y + 1)] = br; c[2 * (off + y + 1) + 1] = bi;
        }
    }
    for (kx = 0; kx <= N / 2; kx++) fft(H + (size_t)kx * 2 * N, N, tw, N, 0);

    invN2 = 1.f / ((float)N * (float)N);
    apply_transfer(H, W, N, p, lv, 0);
    inverse_to_real(W, n, N, tw, row, P, 3600.f * invN2);
    for (y = 0; y < n * n; y++) {
        float v = P[y] + p->P0;
        P[y] = (p->truncate && v < 0.f) ? 0.f : v;
    }
    if (qc) {
        apply_transfer(H, W, N, p, lv, 1);
        inverse_to_real(W, n, N, tw, row, qc, invN2);
    }
    return CP_CLIM_OK;
}

/* ---------------------------------------------------------------------- */
/* hash                                                                    */
/* ---------------------------------------------------------------------- */
static uint64_t fnv_bytes(uint64_t h, const void *data, size_t len)
{
    const uint8_t *b = (const uint8_t *)data;
    size_t i;
    for (i = 0; i < len; i++) { h ^= b[i]; h *= 0x100000001b3ULL; }
    return h;
}
uint64_t cp_lt_hash(const float *a, size_t count)
{
    uint64_t h = 0xcbf29ce484222325ULL;
    size_t i;
    for (i = 0; i < count; i++) {
        uint32_t u;
        memcpy(&u, &a[i], 4);
        h = fnv_bytes(h, &u, 4);   /* byte order of the host; the cores run little-endian */
    }
    return h;
}
uint64_t cp_climate_hash(const CpClimateOut *o, int n)
{
    size_t c = (size_t)n * (size_t)n;
    uint64_t h = 0xcbf29ce484222325ULL;
    h ^= cp_lt_hash(o->precip, c); h *= 0x100000001b3ULL;
    h ^= cp_lt_hash(o->temp, c);   h *= 0x100000001b3ULL;
    h ^= cp_lt_hash(o->qc, c);     h *= 0x100000001b3ULL;
    h ^= cp_lt_hash(o->fog, c);    h *= 0x100000001b3ULL;
    h = fnv_bytes(h, o->biome, c);
    h = fnv_bytes(h, o->veg, 4 * c);
    return h;
}

/* ---------------------------------------------------------------------- */
/* climate pipeline                                                        */
/* ---------------------------------------------------------------------- */
#include "climate_biomes.inc"

/* Row bounds of CP_BIOME_TABLE with the island's thresholds patched in (rows: 0 tundra, 1 alpine, 2 desert, 3 scrub,
 * 4 meadow, 5 dry forest, 6 cloud forest). */
static void row_bounds(const CpClimateParams *p, int r, float *t_lo, float *t_hi, float *p_lo, float *p_hi)
{
    *t_lo = CP_BIOME_TABLE[r].t_lo; *t_hi = CP_BIOME_TABLE[r].t_hi; *p_lo = CP_BIOME_TABLE[r].p_lo; *p_hi = CP_BIOME_TABLE[r].p_hi;
    if (r == 0) *t_hi = p->t_tundra_C;
    else if (r == 1) { *t_lo = p->t_tundra_C; *t_hi = p->t_treeline_C; }
    else { *t_lo = p->t_treeline_C; }
    if (r == 2) *p_hi = p->p_scrub;
    if (r == 3) { *p_lo = p->p_scrub; *p_hi = p->p_meadow; }
    if (r == 4) { *p_lo = p->p_meadow; *p_hi = p->p_dry_forest; }
    if (r == 5) { *p_lo = p->p_dry_forest; *p_hi = p->p_jungle; }
    if (r == 6) *p_lo = p->p_jungle;
}

int cp_climate_biome(const CpClimateParams *p, float T, float P, float slope, float h, int canopy_ok)
{
    int biome, r;
    if (h <= 0.f) return CP_BIOME_SEA;
    if (slope > 1.05f) return CP_BIOME_CLIFF;
    if (h < 2.f && slope < 0.3f) return CP_BIOME_BEACH;
    if (T < p->snow_C && P > 400.f) return CP_BIOME_SNOW;
    biome = CP_BIOME_MEADOW;
    for (r = 0; r < CP_BIOME_ROWS; r++) {
        float tl, th, pl, ph;
        row_bounds(p, r, &tl, &th, &pl, &ph);
        if (T >= tl && T < th && P >= pl && P < ph) { biome = CP_BIOME_TABLE[r].biome; break; }
    }
    if (biome == CP_BIOME_DESERT && slope > 0.45f) biome = CP_BIOME_BADLANDS;
    if (canopy_ok == 0 && (biome == CP_BIOME_JUNGLE || biome == CP_BIOME_DRY_FOREST)) biome = CP_BIOME_MEADOW;
    return biome;
}

void cp_climate_defaults(CpClimateParams *p, int n, float cell_m)
{
    memset(p, 0, sizeof *p);
    p->n = n;
    p->cell_m = cell_m;
    p->scale_h = 8.f;
    p->scale_z = 2.5f;
    p->wind_x = -0.70710678f;      /* from the NE (LAYOUT_ROW wind (-0.7, 0.7)) */
    p->wind_y = 0.70710678f;
    p->trade_speed = 8.f;
    p->trade_w = 0.75f;
    p->storm_speed = 15.f;
    p->storm_w = 0.25f;
    p->Cw = 7.4e-3f * 6.5f / 5.8f;  /* eq. (4) with the abstract's values */
    p->Nm = 0.005f;
    p->Hw = 2500.f;
    p->tau_c = 1000.f;
    p->tau_f = 1000.f;
    p->p_inf_mm_yr = 200.f;
    p->rain_scale = 0.11f;
    p->t_sea_C = 14.f;
    p->lapse_K_km = 6.2f;
    p->aspect_C = 1.5f;
    p->foehn_C = 1.f;
    p->snow_C = 3.15f;
    p->qc_ref = 1.f;
    p->t_tundra_C = 4.5f;
    p->t_treeline_C = 7.f;
    p->p_scrub = 250.f;
    p->p_meadow = 450.f;
    p->p_dry_forest = 900.f;
    p->p_jungle = 1700.f;
    p->canopy_p_full = 1800.f;
}

size_t cp_climate_scratch_floats(int n)
{
    return cp_lt_scratch_floats(n) + 3 * (size_t)n * (size_t)n;
}

int cp_climate_run(const CpClimateParams *p, const float *height, const uint8_t *canopy_mask,
                   const uint8_t *bias_mask, CpClimateOut *out, float *scratch)
{
    int n, x, y, rg, rc;
    size_t cnt, i;
    float *hc, *pr, *qr, *lt;
    CpLtParams lp;
    float dxg;
    if (!p || !height || !out || !scratch || !out->precip || !out->temp || !out->qc || !out->fog || !out->biome || !out->veg)
        return CP_CLIM_ERR_NULL;
    n = p->n;
    if (n < CP_CLIMATE_N_MIN || n > CP_CLIMATE_N_MAX || !is_pow2(n)) return CP_CLIM_ERR_N;
    if (!(p->cell_m > 0.f) || !(p->scale_h > 0.f) || !(p->scale_z > 0.f)) return CP_CLIM_ERR_PARAM;
    cnt = (size_t)n * (size_t)n;
    lt = scratch;
    hc = lt + cp_lt_scratch_floats(n);
    pr = hc + cnt;
    qr = pr + cnt;
    dxg = p->cell_m;

    /* 1. heights in climate coordinates: sea clamped to 0, x scale_z */
    for (i = 0; i < cnt; i++) hc[i] = (height[i] > 0.f ? height[i] : 0.f) * p->scale_z;

    /* 2-3. two wind regimes, weighted into one year */
    memset(out->precip, 0, sizeof(float) * cnt);
    memset(out->qc, 0, sizeof(float) * cnt);
    lp.dx = p->cell_m * p->scale_h;
    lp.Cw = p->Cw; lp.Nm = p->Nm; lp.Hw = p->Hw; lp.tau_c = p->tau_c; lp.tau_f = p->tau_f;
    lp.P0 = p->p_inf_mm_yr / (8760.f * p->rain_scale);   /* annual mm/yr after the 8760 h x rain_scale below */
    lp.truncate = 1;
    for (rg = 0; rg < 2; rg++) {
        float speed = rg == 0 ? p->trade_speed : p->storm_speed;
        float w = rg == 0 ? p->trade_w : p->storm_w;
        float dirx = rg == 0 ? p->wind_x : -p->wind_x, diry = rg == 0 ? p->wind_y : -p->wind_y;
        lp.U = speed * dirx; lp.V = speed * diry;
        rc = cp_lt_precip(hc, n, &lp, pr, rg == 0 ? qr : (float *)0, lt);
        if (rc != CP_CLIM_OK) return rc;
        for (i = 0; i < cnt; i++) out->precip[i] += w * pr[i];
    }
    for (i = 0; i < cnt; i++) {
        float f = bias_mask ? (float)bias_mask[i] / 128.f : 1.f;
        out->precip[i] = out->precip[i] * 8760.f * p->rain_scale * f;
        out->qc[i] = clampf(qr[i] / p->qc_ref, 0.f, 1.f);
    }

    /* 4-8. per-cell: slope, temperature, fog, snow, biome, vegetation */
    for (y = 0; y < n; y++) {
        for (x = 0; x < n; x++) {
            int x0 = x > 0 ? x - 1 : x, x1 = x < n - 1 ? x + 1 : x;
            int y0 = y > 0 ? y - 1 : y, y1 = y < n - 1 ? y + 1 : y;
            size_t c = (size_t)y * (size_t)n + (size_t)x;
            float h = height[c];
            float gx = (height[(size_t)y * n + x1] - height[(size_t)y * n + x0]) / ((float)(x1 - x0) * dxg);
            float gy = (height[(size_t)y1 * n + x] - height[(size_t)y0 * n + x]) / ((float)(y1 - y0) * dxg);
            float slope = sqrtf(gx * gx + gy * gy);
            float along = gx * p->wind_x + gy * p->wind_y;      /* > 0: climbing with the wind */
            float hz = (h > 0.f ? h : 0.f) * p->scale_z;
            float T, P = out->precip[c], fog, wet, soil, canopy, under, grass, litter, forest_t;
            int land = h > 0.f, biome;

            /* temperature */
            T = p->t_sea_C - p->lapse_K_km * hz * 0.001f;
            if (gy > 0.f) T -= p->aspect_C * clampf(gy, 0.f, 1.f);        /* facing away from the sun (north-facing) */
            T += p->foehn_C * clampf(-along / 0.15f, 0.f, 1.f);          /* lee warming */
            out->temp[c] = T;

            /* fog: trade-wind inversion belt (canon 900-1500 m) x cloud water, plus valley trap (F8) */
            {
                float belt = smoothstep(800.f, 900.f, hz) * (1.f - smoothstep(1500.f, 1650.f, hz));
                float up = smoothstep(-0.02f, 0.05f, along);
                float trap = 0.f;
                if (land && h < 100.f) {
                    int k, cnt8 = 0;
                    float mean = 0.f;
                    for (k = 0; k < 8; k++) {
                        static const int dx8[8] = {-3, 0, 3, -3, 3, -3, 0, 3}, dy8[8] = {-3, -3, -3, 0, 0, 3, 3, 3};
                        int xx = x + dx8[k], yy = y + dy8[k];
                        if (xx < 0 || yy < 0 || xx >= n || yy >= n) continue;
                        mean += height[(size_t)yy * n + xx];
                        cnt8++;
                    }
                    if (cnt8) trap = clampf((mean / (float)cnt8 - h) / 8.f, 0.f, 1.f) * 0.5f;
                }
                fog = belt * out->qc[c] * (0.5f + 0.5f * up);
                if (trap > fog) fog = trap;
                out->fog[c] = clampf(fog, 0.f, 1.f);
            }

            /* biome */
            if (!land) {
                biome = CP_BIOME_SEA;
                if (h > -15.f) {                         /* shallow: reef only on a sheltered coast */
                    int k, sheltered = 0;
                    for (k = 1; k <= 40 && !sheltered; k++) {     /* look upwind for land (<= 1.25 km at 31 m cells) */
                        int xx = x - (int)(p->wind_x * (float)k + (p->wind_x < 0.f ? -0.5f : 0.5f));
                        int yy = y - (int)(p->wind_y * (float)k + (p->wind_y < 0.f ? -0.5f : 0.5f));
                        if (xx < 0 || yy < 0 || xx >= n || yy >= n) break;
                        if (height[(size_t)yy * n + xx] > 0.f) sheltered = 1;
                    }
                    if (sheltered) biome = CP_BIOME_REEF;
                }
            } else {
                biome = cp_climate_biome(p, T, P, slope, h, canopy_mask ? canopy_mask[c] : 255);
            }
            out->biome[c] = (uint8_t)biome;

            /* vegetation */
            wet = clampf(0.5f * P / 2500.f + 0.5f * out->fog[c], 0.f, 1.f);
            soil = land ? 1.f - smoothstep(0.6f, 1.05f, slope) : 0.f;
            forest_t = smoothstep(p->t_tundra_C, p->t_treeline_C, T);                 /* treeline */
            canopy = smoothstep(p->canopy_p_full * (1.f / 3.f), p->canopy_p_full, P) * soil * forest_t * (canopy_mask ? (float)canopy_mask[c] / 255.f : 1.f);
            if (biome == CP_BIOME_BEACH || biome == CP_BIOME_SNOW || biome == CP_BIOME_CLIFF || !land) canopy = 0.f;
            under = canopy * (0.6f + 0.4f * wet);
            grass = (1.f - canopy) * smoothstep(250.f, 800.f, P) * soil * (biome == CP_BIOME_SNOW || biome == CP_BIOME_BEACH ? 0.f : 1.f);
            litter = land ? wet * (0.4f + 0.6f * canopy) : 0.f;
            out->veg[4 * c] = (uint8_t)(canopy * 255.f + 0.5f);
            out->veg[4 * c + 1] = (uint8_t)(under * 255.f + 0.5f);
            out->veg[4 * c + 2] = (uint8_t)(grass * 255.f + 0.5f);
            out->veg[4 * c + 3] = (uint8_t)(litter * 255.f + 0.5f);
        }
    }
    return CP_CLIM_OK;
}
