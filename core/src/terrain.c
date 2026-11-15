#include "cpore/terrain.h"
#include "cpore/cpore.h"

#include <math.h>
#include <string.h>

/* Mountains are a mask plus erosion, not a height painted by hand (W11).
 * The mask places the walkable valley, the lake, a lobed range around them,
 * the river gap, a high col and the coast. A stream-power pass at N/4, N/2
 * and N then cuts the valley network (large valleys need large drainage
 * areas, which droplets never gather), droplets add gullies and fans, and
 * thermal passes pull cliffs back to talus and leave scree. D8 flow over an
 * epsilon-filled surface is what materials and the drainage checks read.
 *
 * Float work is + - * / sqrtf only. Noise is a hashed gradient table with
 * a polynomial fade. Trig for the mask would not match across libm, so the
 * pass is a corridor (dot products) and the talus angle is a rational Taylor approximation
 * up front. Work limits depend only on params; droplets may stop on slopes/boundaries.
 */

static const float GRAD[12][2] = {
    { 1.f,  0.f},
    {-1.f,  0.f},
    { 0.f,  1.f},
    { 0.f, -1.f},
    { 0.707106769f,  0.707106769f},
    {-0.707106769f,  0.707106769f},
    { 0.707106769f, -0.707106769f},
    {-0.707106769f, -0.707106769f},
    { 0.923879504f,  0.382683426f},
    {-0.923879504f,  0.382683426f},
    { 0.382683426f,  0.923879504f},
    {-0.382683426f,  0.923879504f}
};

static const int DX[8] = { 1, 1, 0, -1, -1, -1, 0, 1 };
static const int DY[8] = { 0, 1, 1,  1,  0, -1, -1, -1 };

static int finite_f(float x)
{
    return x == x && x < 1.0e20f && x > -1.0e20f;
}

static float clampf(float x, float a, float b)
{
    if (x < a) return a;
    if (x > b) return b;
    return x;
}

static float absf(float x) { return x < 0.f ? -x : x; }

static float minf(float a, float b) { return a < b ? a : b; }
static float maxf(float a, float b) { return a > b ? a : b; }

static int ifloor(float x)
{
    int i = (int)x;
    return (x < (float)i) ? i - 1 : i;
}

static float smoothstep(float e0, float e1, float x)
{
    float t;
    if (!(e1 > e0)) return x < e0 ? 0.f : 1.f;
    t = (x - e0) / (e1 - e0);
    t = clampf(t, 0.f, 1.f);
    return t * t * (3.f - 2.f * t);
}

/* tan = sin/cos polynomials, evaluated once. Error < 2e-6 on 5..55 deg.
 * No platform libm transcendental feeds the canonical maps. */
static float tan_deg(float deg)
{
    float x = deg * 0.01745329252f, z = x*x;
    float sn = x * (1.f + z * (-1.f/6.f + z * (1.f/120.f + z *
        (-1.f/5040.f + z * (1.f/362880.f + z * (-1.f/39916800.f))))));
    float cs = 1.f + z * (-1.f/2.f + z * (1.f/24.f + z *
        (-1.f/720.f + z * (1.f/40320.f + z * (-1.f/3628800.f)))));
    return sn/cs;
}

static uint32_t hash2(int ix, int iy, uint32_t seed)
{
    uint32_t h = seed ^ 0xA3B19535u;
    h ^= (uint32_t)ix * 0x27D4EB2Du;
    h ^= (uint32_t)iy * 0x165667B1u;
    h *= 0x85EBCA6Bu;
    h ^= h >> 13;
    h *= 0xC2B2AE35u;
    h ^= h >> 16;
    return h;
}

static float grad_dot(uint32_t h, float x, float y)
{
    const float *g = GRAD[h % 12u];
    return g[0] * x + g[1] * y;
}

static float fade(float t)
{
    return t * t * t * (t * (t * 6.f - 15.f) + 10.f);
}

/* Gradient noise with its analytic gradient, for slope-damped octaves. */
static float noise2d(float x, float y, uint32_t seed, float *dx, float *dy)
{
    int x0 = ifloor(x);
    int y0 = ifloor(y);
    float fx = x - (float)x0;
    float fy = y - (float)y0;
    float u = fade(fx);
    float v = fade(fy);
    float du = 30.f * fx * fx * (fx - 1.f) * (fx - 1.f);
    float dv = 30.f * fy * fy * (fy - 1.f) * (fy - 1.f);
    const float *g00 = GRAD[hash2(x0,     y0,     seed) % 12u];
    const float *g10 = GRAD[hash2(x0 + 1, y0,     seed) % 12u];
    const float *g01 = GRAD[hash2(x0,     y0 + 1, seed) % 12u];
    const float *g11 = GRAD[hash2(x0 + 1, y0 + 1, seed) % 12u];
    float n00 = g00[0] * fx + g00[1] * fy;
    float n10 = g10[0] * (fx - 1.f) + g10[1] * fy;
    float n01 = g01[0] * fx + g01[1] * (fy - 1.f);
    float n11 = g11[0] * (fx - 1.f) + g11[1] * (fy - 1.f);
    float a = n00 + (n10 - n00) * u;
    float b = n01 + (n11 - n01) * u;
    float ax = g00[0] + (g10[0] - g00[0]) * u;
    float bx = g01[0] + (g11[0] - g01[0]) * u;
    float ay = g00[1] + (g10[1] - g00[1]) * u;
    float by = g01[1] + (g11[1] - g01[1]) * u;
    *dx = ax + (bx - ax) * v + du * ((n10 - n00) + ((n11 - n01) - (n10 - n00)) * v);
    *dy = ay + (by - ay) * v + dv * (b - a);
    return a + (b - a) * v;
}

static float noise2(float x, float y, uint32_t seed)
{
    int x0 = ifloor(x);
    int y0 = ifloor(y);
    float fx = x - (float)x0;
    float fy = y - (float)y0;
    float u = fade(fx);
    float v = fade(fy);
    float n00 = grad_dot(hash2(x0,     y0,     seed), fx,       fy);
    float n10 = grad_dot(hash2(x0 + 1, y0,     seed), fx - 1.f, fy);
    float n01 = grad_dot(hash2(x0,     y0 + 1, seed), fx,       fy - 1.f);
    float n11 = grad_dot(hash2(x0 + 1, y0 + 1, seed), fx - 1.f, fy - 1.f);
    float a = n00 + (n10 - n00) * u;
    float b = n01 + (n11 - n01) * u;
    return a + (b - a) * v;
}

static uint32_t octave_seed(uint32_t seed, int octave, uint32_t salt)
{
    return seed ^ salt ^ (0x9E3779B9u * (uint32_t)(octave + 1));
}

static float fbm(float x, float y, int oct, uint32_t seed)
{
    float sum = 0.f, amp = 0.5f, freq = 1.f, norm = 0.f;
    for (int o = 0; o < oct; o++) {
        sum += amp * noise2(x * freq, y * freq, octave_seed(seed, o, 0x6C8E9CF5u));
        norm += amp;
        amp *= 0.5f;
        freq *= 2.f;
    }
    return sum / norm;
}

/* Ridged multifractal with slope-damped octaves (Musgrave's fold, Quilez's
 * derivative trick). Each octave folds the noise into a ridge and squares it.
 * The running gradient of what has been summed so far damps the next octaves,
 * so detail gathers on crests and valley floors and the flanks between stay
 * clean: the shape erosion would leave, before any erosion has run.
 * Octaves are rotated so lattice axes never line up. Returns about 0..1. */
static float ridged(float x, float y, int oct, uint32_t seed)
{
    float sum = 0.f, amp = 1.f, norm = 0.f;
    float gxs = 0.f, gys = 0.f;
    float rc = 1.f, rs = 0.f;          /* accumulated rotation of the octave frame */
    float px = x, py = y;
    for (int o = 0; o < oct; o++) {
        float gx, gy, wx, wy, s, sg, damp, t;
        float n = noise2d(px, py, octave_seed(seed, o, 0xB5297A4Du), &gx, &gy) * 1.6f;
        sg = n < 0.f ? 1.6f : -1.6f;
        s = 1.f - absf(n);
        if (s < 0.f) { s = 0.f; sg = 0.f; }
        /* World-frame gradient of s*s, per octave wavelength. */
        wx = (rc * gx + rs * gy) * sg * 2.f * s;
        wy = (-rs * gx + rc * gy) * sg * 2.f * s;
        gxs += wx * amp;
        gys += wy * amp;
        damp = 1.f / (1.f + 0.4f * (gxs * gxs + gys * gys));
        sum += amp * s * s * damp;
        norm += amp;
        amp *= 0.5f;
        t = 2.f * (0.8f * px - 0.6f * py);
        py = 2.f * (0.6f * px + 0.8f * py);
        px = t;
        t = rc * 0.8f - rs * 0.6f;
        rs = rs * 0.8f + rc * 0.6f;
        rc = t;
    }
    return sum / norm;
}

void cp_terrain_params_default(CpTerrainParams *p)
{
    if (!p) return;
    memset(p, 0, sizeof *p);
    p->seed = 1u;
    p->n = 1024;
    p->octaves = 5;
    /* Fixed counts, not a time budget. stream_iters is the N/4 count; N/2 runs
     * a third of it and N an eighth. About a quarter droplet per cell at 1024². */
    p->stream_iters = 48;
    p->droplets = 80000;
    p->lifetime = 64;
    p->radius = 2;
    p->thermal_iters = 8;
    p->size_m = 3600.f;
    p->frequency = 1.f / 760.f;
    p->warp_m = 240.f;
    p->ridge_weight = 0.60f;
    p->valley_radius_m = 300.f;
    p->valley_floor_m = 42.f;
    p->ring_inner_m = 340.f;
    p->ring_outer_m = 1500.f;
    p->ring_height_m = 470.f;
    p->pass_x = 1.f;
    p->pass_y = 0.15f;
    p->pass_half_m = 90.f;
    p->pass_height_m = 26.f;
    p->col_x = -0.55f;
    p->col_y = -0.83f;
    p->col_height_m = 230.f;
    p->island_radius_m = 1600.f;
    p->lake_x_m = -150.f;
    p->lake_y_m = 70.f;
    p->lake_radius_m = 68.f;
    p->lake_depth_m = 34.f;
    p->stream_k = 0.07f;
    p->cliff_deg = 62.f;
    p->inertia = 0.30f;
    p->capacity = 2.5f;
    p->deposition = 0.25f;
    p->erosion = 0.30f;
    p->evaporation = 0.045f;
    p->gravity = 4.f;
    p->min_slope = 0.01f;
    p->talus_deg = 38.f;
}

static int in_range(float x, float a, float b)
{
    return finite_f(x) && x >= a && x <= b;
}

int cp_terrain_validate(const CpTerrainParams *p)
{
    if (!p) return CP_TERR_ERR_NULL;
    if (p->n < CP_TERRAIN_N_MIN || p->n > CP_TERRAIN_N_MAX) return CP_TERR_ERR_N;
    if (!in_range(p->size_m, 16.f, 100000.f)) return CP_TERR_ERR_SIZE;
    if (p->octaves < 1 || p->octaves > 8) return CP_TERR_ERR_OCTAVES;
    if (p->droplets < 0 || p->droplets > 2000000) return CP_TERR_ERR_DROPLETS;
    if (p->lifetime < 1 || p->lifetime > 128) return CP_TERR_ERR_DROPLETS;
    if (p->radius < 1 || p->radius > 8) return CP_TERR_ERR_DROPLETS;
    if (p->thermal_iters < 0 || p->thermal_iters > 48) return CP_TERR_ERR_RANGE;
    if (p->stream_iters < 0 || p->stream_iters > 256) return CP_TERR_ERR_RANGE;
    if (!in_range(p->stream_k, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->frequency, 1.0e-6f, 0.5f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->warp_m, 0.f, p->size_m * 2.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->ridge_weight, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->valley_radius_m, 1.f, p->size_m)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->valley_floor_m, -8000.f, 8000.f)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->ring_inner_m, 1.f, p->size_m)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->ring_outer_m, 1.f, p->size_m * 1.5f)) return CP_TERR_ERR_RANGE;
    if (!(p->ring_outer_m > p->ring_inner_m)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->ring_height_m, 1.f, 8000.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->pass_x, -10000.f, 10000.f) || !in_range(p->pass_y, -10000.f, 10000.f)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->pass_half_m, 1.f, p->size_m)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->pass_height_m, -8000.f, 8000.f)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->col_x, -10000.f, 10000.f) || !in_range(p->col_y, -10000.f, 10000.f)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->col_height_m, -8000.f, 8000.f)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->island_radius_m, 1.f, p->size_m * 4.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->lake_x_m, -p->size_m, p->size_m) || !in_range(p->lake_y_m, -p->size_m, p->size_m)) return CP_TERR_ERR_FINITE;
    if (!in_range(p->lake_radius_m, 1.f, p->size_m)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->lake_depth_m, 0.f, 2000.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->inertia, 0.f, 0.95f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->capacity, 0.01f, 64.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->deposition, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->erosion, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->evaporation, 0.f, 0.5f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->gravity, 0.f, 64.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->min_slope, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->talus_deg, 5.f, 55.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->cliff_deg, 5.f, 75.f)) return CP_TERR_ERR_RANGE;
    return CP_TERR_OK;
}

static void notify(CpTerrainProgressFn fn, void *user, int stage, int done, int total)
{
    if (fn) fn(stage, done, total, user);
}

/* A stage that spans several passes. Stage 0 is every level's base fill and
 * the coarse stream-power passes, one unit per base chunk and per step.
 * Stage 2 is the fine stream-power pass and the scree sweeps after it. */
typedef struct {
    CpTerrainProgressFn fn;
    void *user;
    int stage, done, total;
} Shape;

static void shape_tick(Shape *s)
{
    if (s->done < s->total) s->done++;
    notify(s->fn, s->user, s->stage, s->done, s->total);
}

/* ---- base ---------------------------------------------------------------- */

/* A narrow fold of angular noise: 1 on a spur line, 0 between spurs. */
static float spur(float qx, float qy, uint32_t seed)
{
    float s = 1.f - absf(noise2(qx, qy, seed)) * 2.2f;
    if (s < 0.f) s = 0.f;
    return s * s;
}

static void unit_dir(float x, float y, float *ux, float *uy)
{
    float len = sqrtf(x * x + y * y);
    if (len < 1.0e-6f) { *ux = 1.f; *uy = 0.f; }
    else { *ux = x / len; *uy = y / len; }
}

/* A massif: a peak with a long axis, so the range is a chain of separate
 * mountains with saddles between them rather than one wall of even height. */
#define MASSIFS 7
typedef struct { float x, y, ax, ay, inv_w, inv_l, h; } Massif;

typedef struct {
    float px, py, cx, cy;       /* river-gap and col directions, unit */
    float crest0;               /* mean crest radius */
    float ox, oy;               /* island centre, off the valley centre */
    Massif m[MASSIFS];
} BaseCtx;

static float hash01(int a, int b, uint32_t seed)
{
    return (float)(hash2(a, b, seed) >> 8) * (1.f / 16777216.f);
}

/* Seven slots around the valley, measured from the river gap so the gap
 * always falls between two massifs. cos/sin of (k + 0.5) * 360/7 degrees are
 * literals; the jitter is a rotation by a normalised (1, j), so no trig. */
static void base_ctx(const CpTerrainParams *p, BaseCtx *c)
{
    static const float CS[MASSIFS][2] = {
        { 0.90096885f,  0.43388376f}, { 0.22252093f,  0.97492790f},
        {-0.62348980f,  0.78183150f}, {-1.f,          0.f},
        {-0.62348980f, -0.78183150f}, { 0.22252093f, -0.97492790f},
        { 0.90096885f, -0.43388376f}
    };
    uint32_t s = p->seed ^ 0x3956C25Bu;
    unit_dir(p->pass_x, p->pass_y, &c->px, &c->py);
    unit_dir(p->col_x, p->col_y, &c->cx, &c->cy);
    c->crest0 = p->ring_inner_m + 0.46f * (p->ring_outer_m - p->ring_inner_m);
    c->ox = (hash01(90, 1, s) - 0.5f) * 0.14f * p->island_radius_m - c->px * 0.05f * p->island_radius_m;
    c->oy = (hash01(90, 2, s) - 0.5f) * 0.14f * p->island_radius_m - c->py * 0.05f * p->island_radius_m;
    for (int k = 0; k < MASSIFS; k++) {
        Massif *m = &c->m[k];
        float dx = c->px * CS[k][0] - c->py * CS[k][1];
        float dy = c->px * CS[k][1] + c->py * CS[k][0];
        float jc, js, t, rad, w, stretch;
        unit_dir(1.f, (hash01(k, 1, s) - 0.5f) * 0.40f, &jc, &js);
        t = dx * jc - dy * js;
        dy = dx * js + dy * jc;
        dx = t;
        rad = c->crest0 * (0.94f + 0.22f * hash01(k, 2, s));
        m->x = dx * rad;
        m->y = dy * rad;
        unit_dir(hash01(k, 3, s) - 0.5f, hash01(k, 4, s) - 0.5f, &m->ax, &m->ay);
        stretch = 1.1f + 0.9f * hash01(k, 5, s);
        w = (p->ring_outer_m - p->ring_inner_m) * (0.36f + 0.14f * hash01(k, 6, s));
        m->inv_w = 1.f / maxf(w, 1.f);
        m->inv_l = 1.f / maxf(w * stretch, 1.f);
        m->h = 0.60f + 0.40f * hash01(k, 7, s);
    }
}

/* The shape before any erosion, in metres above the sea (sea level is 0).
 *
 * Angle around the valley is never computed. The unit vector to a point,
 * scaled, samples 2D noise on a circle, which is a smooth periodic function
 * of angle with no trig. Those angular fields move the crest in and out
 * (lobes), raise and lower it (massifs and saddles), and widen or narrow the
 * flanks (spurs with cirques between them). The spur fields drift with
 * radius so spurs bend and fork instead of running straight to the centre. */
static float base_height(const CpTerrainParams *p, const BaseCtx *c, float x, float y)
{
    const float F = p->frequency;
    const float vr = p->valley_radius_m;
    const float vf = p->valley_floor_m;
    float r0 = sqrtf(x * x + y * y);
    float nx = (x + 8192.f) * F;
    float ny = (y + 8192.f) * F;
    int woct = p->octaves > 3 ? 3 : p->octaves;
    /* The start floor stays unwarped; the range and coast bend freely. */
    float wfade = smoothstep(vr * 0.4f, p->ring_inner_m * 1.3f, r0) * p->warp_m * 2.f;
    float X = x + fbm(nx * 0.55f, ny * 0.55f, woct, p->seed ^ 0xA341316Cu) * wfade;
    float Y = y + fbm(nx * 0.55f + 4.2f, ny * 0.55f + 1.7f, woct, p->seed ^ 0xC8013EA4u) * wfade;
    float r = sqrtf(X * X + Y * Y);
    float ir = 1.f / maxf(r, 1.f);
    float ux = X * ir, uy = Y * ir;
    float a_lobe  = noise2(ux * 1.15f + 17.3f, uy * 1.15f + 5.1f, p->seed ^ 0x19B39A21u);
    float a_lobe2 = noise2(ux * 2.70f + 3.9f,  uy * 2.70f + 11.7f, p->seed ^ 0x2545F491u);
    float a_mass  = noise2(ux * 1.60f + 9.4f,  uy * 1.60f + 23.2f, p->seed ^ 0x3C6EF372u);
    float a_mass2 = noise2(ux * 3.70f + 31.1f, uy * 3.70f + 2.6f,  p->seed ^ 0x4F1BBCDCu);
    float a_coast = noise2(ux * 1.40f + 7.7f,  uy * 1.40f + 13.3f, p->seed ^ 0x5BE0CD19u);
    float a_coast2= noise2(ux * 3.30f + 1.2f,  uy * 3.30f + 19.9f, p->seed ^ 0x6A09E667u);
    float rc = c->crest0 * (1.f + 0.30f * a_lobe + 0.12f * a_lobe2);
    float massif = clampf(0.74f + 0.62f * a_mass + 0.30f * a_mass2, 0.40f, 1.12f);
    float crest_h, peaks = 0.f;
    float d = r - rc;
    float drift_x = X * (1.f / 1500.f), drift_y = Y * (1.f / 1500.f);
    float t, env, ground, gfloor, h;
    float along = X * c->px + Y * c->py;
    float across = absf(-X * c->py + Y * c->px);
    float cut, shore, coast_r, edge;


    if (d < 0.f) {
        float s = spur(ux * 3.1f + drift_x + 40.f, uy * 3.1f + drift_y + 40.f, p->seed ^ 0x7F4A7C15u);
        float w = (rc - p->ring_inner_m) * (0.46f + 0.66f * s);
        t = -d / maxf(w, 1.f);
    } else {
        float s = spur(ux * 4.3f + drift_x + 80.f, uy * 4.3f + drift_y + 80.f, p->seed ^ 0x8D2A4C8Au);
        float w = (p->ring_outer_m - rc) * (0.50f + 0.66f * s);
        t = d / maxf(w, 1.f);
    }
    /* A broad crown, not a tent: the ridged field inside it decides where
     * the crests run, so they wander, double up and leave peaks off the line. */
    env = t < 1.f ? (1.f - t * t) * (1.f - 0.35f * t) : 0.f;
    for (int k = 0; k < MASSIFS; k++) {
        const Massif *m = &c->m[k];
        float ex = X - m->x, ey = Y - m->y;
        float a = (ex * m->ax + ey * m->ay) * m->inv_l;
        float b = (-ex * m->ay + ey * m->ax) * m->inv_w;
        float q = sqrtf(a * a + b * b);
        /* Arêtes: the flanks reach further along a few directions from the
         * summit and fall short between them, which leaves cirque hollows. */
        if (q < 1.6f && q > 1.0e-4f) {
            float iq = 2.1f / q;
            q *= 1.20f - 0.34f * spur(a * iq + 13.f * (float)k, b * iq + 7.f, p->seed ^ 0x62A9D9EDu);
        }
        /* Concave flanks that steepen to the summit and meet the ground
         * without a kink. */
        if (q < 1.f) peaks = maxf(peaks, m->h * (1.f - q) * (1.f - q) * (1.f + 0.5f * q));
    }
    /* A low connecting ridge under the massifs keeps the valley enclosed. */
    crest_h = p->ring_height_m * (0.36f * massif * env + 0.64f * peaks);
    /* The col: one saddle the generator promises, besides those the massifs leave. */
    {
        float notch = smoothstep(0.90f, 0.985f, ux * c->cx + uy * c->cy);
        float col = maxf(p->col_height_m - vf - 26.f, 0.f) * 0.9f;
        crest_h = crest_h * (1.f - notch) + minf(crest_h, col) * notch;
    }
    /* Nothing of the range stands on the start floor. Its edge is not a
     * circle: spurs come down to the floor and bays reach back between them. */
    {
        float s = spur(ux * 2.6f + 60.f, uy * 2.6f + 60.f, p->seed ^ 0x7F4A7C15u);
        crest_h *= smoothstep(vr * 0.85f, vr * (1.35f + 1.0f * (1.f - s)), r0);
    }

    /* Ground the range stands on: a shallow bowl tilted to the river gap,
     * an apron under the mountains, then a fall to the coast. */
    {
        float u = clampf(r0 / vr, 0.f, 1.f);
        float tilt = clampf((x * c->px + y * c->py) / vr, -1.f, 1.f);
        ground = vf + 11.f * u * u - 5.f * tilt * u;
        ground += smoothstep(vr, c->crest0, r) * 26.f;
        ground -= smoothstep(c->crest0, p->island_radius_m, r) * (ground - 4.f);
    }
    /* River gap floor: from just under the valley floor, through the crest
     * line at pass_height, down to the coast. */
    {
        float g0 = vf - 3.f;
        float a = clampf((r - vr * 0.3f) / maxf(c->crest0 - vr * 0.3f, 1.f), 0.f, 1.f);
        float b = clampf((r - c->crest0) / maxf(p->island_radius_m - c->crest0, 1.f), 0.f, 1.f);
        gfloor = g0 + (p->pass_height_m - g0) * a;
        gfloor += (1.f - gfloor) * b;
        cut = 1.f - smoothstep(p->pass_half_m * 0.15f, p->pass_half_m * 2.8f, across);
        cut *= smoothstep(0.f, vr * 0.6f, along);
    }

    {
        float sx = nx + fbm(nx * 1.9f + 7.1f, ny * 1.9f + 3.3f, woct, p->seed ^ 0x1F83D9ABu) * 0.22f;
        float sy = ny + fbm(nx * 1.9f + 1.4f, ny * 1.9f + 8.8f, woct, p->seed ^ 0x9B05688Cu) * 0.22f;
        float rd = ridged(sx, sy, p->octaves, p->seed ^ 0x510E527Fu);
        float hills = fbm(sx * 2.3f, sy * 2.3f, p->octaves, p->seed ^ 0x51F0EDE5u);
        float quiet = smoothstep(vr * 0.3f, vr * 1.1f, r0);
        float detail = 0.42f + 1.35f * rd;
        float outer = smoothstep(0.35f, 1.0f, d > 0.f ? t : 0.f);
        float rd2 = ridged(sx * 1.7f + 5.3f, sy * 1.7f + 9.1f, p->octaves, p->seed ^ 0xBB67AE85u);
        h = ground;
        h += crest_h * (1.f - p->ridge_weight + p->ridge_weight * detail);
        /* Ribs on the faces, where the damped octaves above leave them bare. */
        h += clampf(crest_h * (1.f / 220.f), 0.f, 1.f) * 45.f * rd2;
        /* Lower ranges and hills beyond the main one, so the outer land is
         * not a plain. They fade to the coast with the ground. */
        h += outer * (30.f + 190.f * rd2 * rd2 * (0.6f + 0.8f * massif));
        h += hills * (3.f + 26.f * quiet);
        h -= p->lake_depth_m * (1.f - smoothstep(p->lake_radius_m * 0.2f, p->lake_radius_m,
              sqrtf((x - p->lake_x_m) * (x - p->lake_x_m) + (y - p->lake_y_m) * (y - p->lake_y_m))));
        h = h * (1.f - cut) + (gfloor + hills * 2.f) * cut;
    }

    /* Coast: a noisy outline, and the square edge is always sea. */
    coast_r = p->island_radius_m * (1.f + 0.16f * a_coast + 0.08f * a_coast2);
    shore = smoothstep(coast_r - 260.f, coast_r + 40.f,
                       sqrtf((X - c->ox) * (X - c->ox) + (Y - c->oy) * (Y - c->oy)));
    edge = maxf(absf(x), absf(y)) / (p->size_m * 0.5f);
    shore = maxf(shore, smoothstep(0.80f, 0.97f, edge));
    h = h * (1.f - shore) + (-24.f) * shore;
    return h;
}

static void fill_base(const CpTerrainParams *p, int n, float *height, Shape *shape)
{
    const float cell = p->size_m / (float)n;
    const float half = p->size_m * 0.5f;
    BaseCtx c;
    int row_step = n >= 8 ? n / 8 : 1;
    base_ctx(p, &c);

    for (int j = 0; j < n; j++) {
        for (int i = 0; i < n; i++) {
            float x = ((float)i + 0.5f) * cell - half;
            float y = ((float)j + 0.5f) * cell - half;
            height[(size_t)j * (size_t)n + (size_t)i] = base_height(p, &c, x, y);
        }
        if (((j + 1) % row_step) == 0 && (j + 1) / row_step <= 8) shape_tick(shape);
    }
}

/* Bilinear resample of a coarse map onto a finer grid over the same world. */
static float upsample(const float *src, int nc, int n, int i, int j)
{
    float fx = ((float)i + 0.5f) * (float)nc / (float)n - 0.5f;
    float fy = ((float)j + 0.5f) * (float)nc / (float)n - 0.5f;
    int x0, y0, x1, y1;
    float a, b;
    fx = clampf(fx, 0.f, (float)(nc - 1));
    fy = clampf(fy, 0.f, (float)(nc - 1));
    x0 = (int)fx; y0 = (int)fy;
    x1 = x0 + 1 < nc ? x0 + 1 : x0;
    y1 = y0 + 1 < nc ? y0 + 1 : y0;
    fx -= (float)x0; fy -= (float)y0;
    a = src[y0 * nc + x0] + (src[y0 * nc + x1] - src[y0 * nc + x0]) * fx;
    b = src[y1 * nc + x0] + (src[y1 * nc + x1] - src[y1 * nc + x0]) * fx;
    return a + (b - a) * fy;
}

/* ---- protection ---------------------------------------------------------- */

/* 0 on the start floor and in the lake bowl, 1 on open ground. Squared
 * distances, so no sqrt per call. Gullies belong on the range, and the basin
 * has to hold water after everything has run. Deposition is never scaled. */
static float erode_scale_at(const CpTerrainParams *p, float cell, int x, int y)
{
    float half = p->size_m * 0.5f;
    float wx = ((float)x + 0.5f) * cell - half;
    float wy = ((float)y + 0.5f) * cell - half;
    float r2 = wx * wx + wy * wy;
    float vr0 = p->valley_radius_m * 0.34f;
    float vr1 = p->valley_radius_m * 0.80f;
    float valley = 1.f - smoothstep(vr0 * vr0, vr1 * vr1, r2);
    float lx = wx - p->lake_x_m;
    float ly = wy - p->lake_y_m;
    float lr0 = p->lake_radius_m * 1.25f;
    float lr1 = p->lake_radius_m * 1.9f;
    float lake = 1.f - smoothstep(lr0 * lr0, lr1 * lr1, lx * lx + ly * ly);
    float hold = valley > lake ? valley : lake;
    return 1.f - hold;
}

/* ---- thermal ------------------------------------------------------------- */

/* One in-place sweep: a quarter of the largest excess over the talus drop
 * moves to the steepest D8 neighbour. What arrives is recorded as sediment,
 * so scree shows up in the material map. Alternate sweeps run backwards to
 * keep the row-major order from leaning the slopes one way. */
static void thermal_sweep(int n, float cell, float diag, float talus,
                          float *height, float *sed, int backwards,
                          const CpTerrainParams *rock)
{
    int nn = n * n;
    float half = rock ? rock->size_m * 0.5f : 0.f;
    float rf = rock ? rock->frequency * 3.1f : 0.f;
    for (int k = 0; k < nn; k++) {
        int i = backwards ? nn - 1 - k : k;
        int x = i % n, y = i / n;
        float h = height[i];
        float best = 0.f;
        float tal = talus;
        int bi = -1;
        /* Rock strength varies from place to place: hard bands hold cliffs,
         * soft ones lie back. Without it every wall rests at one angle. */
        if (rock) {
            float wx = ((float)x + 0.5f) * cell - half, wy = ((float)y + 0.5f) * cell - half;
            tal *= 1.f + 0.85f * noise2(wx * rf + 91.3f, wy * rf + 47.9f, rock->seed ^ 0x0F1E2D3Cu);
        }
        for (int d = 0; d < 8; d++) {
            int nx = x + DX[d];
            int ny = y + DY[d];
            float excess;
            if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
            excess = (h - height[ny * n + nx]) - tal * ((d & 1) ? diag : cell);
            if (excess > best) { best = excess; bi = ny * n + nx; }
        }
        if (bi >= 0) {
            float move = best * 0.25f;
            height[i] -= move;
            height[bi] += move;
            sed[bi] += move;
        }
    }
}

static void thermal(const CpTerrainParams *p, float *height, float *sed, Shape *shape)
{
    const int n = p->n;
    const float cell = p->size_m / (float)n;
    const float diag = cell * sqrtf(2.f);
    const float talus = tan_deg(p->talus_deg);
    for (int iter = 0; iter < p->thermal_iters; iter++) {
        thermal_sweep(n, cell, diag, talus, height, sed, iter & 1, NULL);
        shape_tick(shape);
    }
}

/* ---- flow ---------------------------------------------------------------- */

static int steepest(const float *h, int n, float cell, float diag, int x, int y)
{
    float hc = h[y * n + x];
    float best = 0.f;
    int bd = -1;
    for (int d = 0; d < 8; d++) {
        int nx = x + DX[d];
        int ny = y + DY[d];
        float slope;
        if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
        slope = (hc - h[ny * n + nx]) / ((d & 1) ? diag : cell);
        if (slope > best) { best = slope; bd = d; }
    }
    return bd;
}

void cp_terrain_directions(const float *height, int n, float size_m, int8_t *dir)
{
    float cell = size_m / (float)n;
    float diag = cell * sqrtf(2.f);
    for (int y = 0; y < n; y++)
        for (int x = 0; x < n; x++)
            dir[y * n + x] = (int8_t)steepest(height, n, cell, diag, x, y);
}

/* Routing reads height plus a hashed jitter of up to 4% of a cell. On a slope
 * it changes nothing. On a floor too flat for D8 to choose, it breaks the
 * tie differently in every cell, so channels wander and join instead of
 * running in parallel lines along a grid axis. */
#define FLAT_EPS 1.0e-3f
static float route_jitter(int i, uint32_t seed, float cell)
{
    uint32_t h = hash2(i, 0x5DEECE6, seed ^ 0x243F6A88u);
    return (float)(h >> 8) * (1.f / 16777216.f) * cell * 0.04f;
}

/* Priority-flood depression routing with an epsilon gradient (Barnes et al.,
 * "Priority-Flood", the improved +epsilon variant). The physical surface is
 * untouched. Water levels live in `level`: each cell is at least FLAT_EPS
 * above the cell that flooded it, so every cell except an outlet has a
 * strictly lower neighbour and steepest descent on `level` cannot stall or
 * cycle. Outlets are the map edge and every cell at or under the sea.
 * Heap ties use the cell index. After the call `queue` holds all cells in
 * topological order, sources first. */
static int heap_less(int a, int b, const float *level)
{
    return level[a] < level[b] || (level[a] == level[b] && a < b);
}
static void heap_push(int *heap, int *count, int cell, const float *level)
{
    int j = (*count)++;
    while (j > 0) {
        int parent = (j - 1) / 2;
        if (!heap_less(cell, heap[parent], level)) break;
        heap[j] = heap[parent];
        j = parent;
    }
    heap[j] = cell;
}
static int heap_pop(int *heap, int *count, const float *level)
{
    int result = heap[0], last = heap[--*count], j = 0;
    while (j * 2 + 1 < *count) {
        int child = j * 2 + 1;
        if (child + 1 < *count && heap_less(heap[child + 1], heap[child], level)) child++;
        if (!heap_less(heap[child], last, level)) break;
        heap[j] = heap[child];
        j = child;
    }
    if (*count) heap[j] = last;
    return result;
}
static void flow_accum(const float *height, int n, float size_m, uint32_t seed,
                       float *flow, float *level, int32_t *recv, int32_t *ups, int32_t *queue,
                       CpTerrainProgressFn fn, void *user)
{
    float cell = size_m / (float)n, diag = cell * sqrtf(2.f);
    int nn = n * n, heap_count = 0, qn = 0, popped = 0;
    memset(ups, 0, (size_t)nn * sizeof *ups);
    notify(fn, user, CP_TERR_STAGE_FLOW, 0, 2 * nn);
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        int i = y * n + x;
        recv[i] = -1;
        flow[i] = 1.f;
        if (x == 0 || y == 0 || x == n - 1 || y == n - 1 || !(height[i] > 0.f)) {
            level[i] = height[i];
            ups[i] = 1;
            heap_push(queue, &heap_count, i, level);
        }
    }
    while (heap_count) {
        int i = heap_pop(queue, &heap_count, level), x = i % n, y = i / n;
        for (int d = 0; d < 8; d++) {
            int nx = x + DX[d], ny = y + DY[d], j;
            if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
            j = ny * n + nx;
            if (ups[j]) continue;
            ups[j] = 1;
            recv[j] = i;
            level[j] = maxf(height[j] + route_jitter(j, seed, cell), level[i] + FLAT_EPS);
            heap_push(queue, &heap_count, j, level);
        }
        if ((++popped % 8192) == 0) notify(fn, user, CP_TERR_STAGE_FLOW, popped, 2 * nn);
    }
    memset(ups, 0, (size_t)nn * sizeof *ups);
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        int i = y * n + x;
        if (recv[i] >= 0) {
            int d = steepest(level, n, cell, diag, x, y);
            if (d >= 0) recv[i] = (y + DY[d]) * n + x + DX[d];
            ups[recv[i]]++;
        }
    }
    for (int i = 0; i < nn; i++) if (ups[i] == 0) queue[qn++] = i;
    for (int qh = 0; qh < qn; qh++) {
        int i = queue[qh], r = recv[i];
        if (r >= 0) {
            flow[r] += flow[i];
            if (--ups[r] == 0) queue[qn++] = r;
        }
        if ((qh % 8192) == 0) notify(fn, user, CP_TERR_STAGE_FLOW, nn + qh, 2 * nn);
    }
    {
        float inv = 1.f / (float)nn;
        for (int i = 0; i < nn; i++) flow[i] *= inv;
    }
    notify(fn, user, CP_TERR_STAGE_FLOW, 2 * nn, 2 * nn);
}

/* ---- stream power -------------------------------------------------------- */

/* Detachment-limited stream power, dh/dt = -K sqrt(A) S, solved implicitly
 * from the outlets upstream (Braun & Willett 2013), so one step is stable at
 * any K. It is what gathers a valley network: incision grows with drainage
 * area, so trunks deepen, capture their neighbours and branch headward,
 * which droplets with a 32-step life cannot do. Run coarse first, where a
 * whole catchment is a few thousand cells, then refine (see generate).
 *
 * Closed pits are half filled each step and recorded as sediment: basins
 * silt up into flat floors instead of staying as noise holes. The start
 * floor and the lake bowl are exempt from both. A talus sweep follows each
 * step so walls undercut by incision fall back and ridges stay sharp. */
static void stream_power(const CpTerrainParams *p, int n, float *h, float *sed,
                         float *flow, float *level, const CpTerrainWorkspace *ws,
                         int iters, Shape *shape)
{
    const float cell = p->size_m / (float)n;
    const float diag = cell * sqrtf(2.f);
    const float talus = tan_deg(p->cliff_deg);
    const float area = p->size_m * p->size_m;
    const int nn = n * n;
    for (int it = 0; it < iters; it++) {
        flow_accum(h, n, p->size_m, p->seed, flow, level, ws->recv, ws->ups, ws->queue, NULL, NULL);
        for (int q = nn - 1; q >= 0; q--) {
            int i = ws->queue[q], r = ws->recv[i], di;
            float hi, hr, f, scale, pond, sa;
            if (r < 0) continue;
            scale = erode_scale_at(p, cell, i % n, i / n);
            if (!(scale > 0.f)) continue;
            hi = h[i];
            pond = level[i] - (hi + route_jitter(i, p->seed, cell));
            if (pond > 0.f) {
                float dep = pond * 0.5f * scale;
                h[i] = hi + dep;
                sed[i] += dep;
                continue;
            }
            hr = h[r];
            if (!(hr < hi)) continue;
            di = r - i;
            /* Below about 1600 m2 of catchment the ground is hillslope, not
             * channel: it wears at a fraction of the rate, or every ridge
             * would melt at the speed its gullies cut. */
            sa = sqrtf(flow[i] * area);
            sa = sa > 40.f ? sa - 39.f : sa * 0.025f;
            f = p->stream_k * sa * scale /
                ((di == 1 || di == -1 || di == n || di == -n) ? cell : diag);
            h[i] = (hi + f * hr) / (1.f + f);
        }
        thermal_sweep(n, cell, diag, talus, h, sed, it & 1, p);
        shape_tick(shape);
    }
}

/* ---- hydraulic (Beyer / Lague) ------------------------------------------ */

typedef struct { int dx, dy; float w; } Brush;

static int make_brush(Brush *b, int radius)
{
    int n = 0;
    float sum = 0.f;
    float r2 = (float)(radius * radius);
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            float d2 = (float)(x * x + y * y);
            if (d2 <= r2) {
                float w = 1.f - d2 / (r2 + 1.f);
                b[n].dx = x;
                b[n].dy = y;
                b[n].w = w;
                sum += w;
                n++;
            }
        }
    }
    if (sum > 0.f) {
        float inv = 1.f / sum;
        for (int i = 0; i < n; i++) b[i].w *= inv;
    }
    return n;
}

static float bilerp(const float *h, int n, float x, float y, float *gx, float *gy)
{
    int x0 = (int)x;
    int y0 = (int)y;
    float fx = x - (float)x0;
    float fy = y - (float)y0;
    int i = y0 * n + x0;
    float h00 = h[i];
    float h10 = h[i + 1];
    float h01 = h[i + n];
    float h11 = h[i + n + 1];
    float a = h00 + (h10 - h00) * fx;
    float b = h01 + (h11 - h01) * fx;
    *gx = (h10 - h00) * (1.f - fy) + (h11 - h01) * fy;
    *gy = (h01 - h00) * (1.f - fx) + (h11 - h10) * fx;
    return a + (b - a) * fy;
}

static void deposit_at(float *h, float *sed, int n, float x, float y, float amount)
{
    int x0 = (int)x;
    int y0 = (int)y;
    float fx = x - (float)x0;
    float fy = y - (float)y0;
    float w00 = (1.f - fx) * (1.f - fy);
    float w10 = fx * (1.f - fy);
    float w01 = (1.f - fx) * fy;
    float w11 = fx * fy;
    int i = y0 * n + x0;
    h[i] += amount * w00;         sed[i] += amount * w00;
    h[i + 1] += amount * w10;     sed[i + 1] += amount * w10;
    h[i + n] += amount * w01;     sed[i + n] += amount * w01;
    h[i + n + 1] += amount * w11; sed[i + n + 1] += amount * w11;
}

static float erode_brush(float *h, int n, const float *guard,
                         int cx, int cy, float amount, const Brush *b, int nb)
{
    float sum = 0.f;
    if (!(amount > 0.f)) return 0.f;
    for (int k = 0; k < nb; k++) {
        int x = cx + b[k].dx;
        int y = cy + b[k].dy;
        if ((unsigned)x < (unsigned)n && (unsigned)y < (unsigned)n) sum += b[k].w;
    }
    if (!(sum > 0.f)) return 0.f;
    {
        float scale = amount / sum;
        float removed = 0.f;
        for (int k = 0; k < nb; k++) {
            int x = cx + b[k].dx;
            int y = cy + b[k].dy;
            if ((unsigned)x < (unsigned)n && (unsigned)y < (unsigned)n) {
                float d = b[k].w * scale * guard[y * n + x];
                h[y * n + x] -= d;
                removed += d;
            }
        }
        return removed;
    }
}

static void deposit_brush(float *h, float *sed, int n, int cx, int cy, float amount,
                          const Brush *b, int nb)
{
    float sum = 0.f;
    for (int k = 0; k < nb; k++) {
        int x = cx + b[k].dx, y = cy + b[k].dy;
        if ((unsigned)x < (unsigned)n && (unsigned)y < (unsigned)n) sum += b[k].w;
    }
    if (!(sum > 0.f)) return;
    for (int k = 0; k < nb; k++) {
        int x = cx + b[k].dx, y = cy + b[k].dy;
        if ((unsigned)x < (unsigned)n && (unsigned)y < (unsigned)n) {
            float d = amount * b[k].w / sum;
            h[y * n + x] += d;
            sed[y * n + x] += d;
        }
    }
}

/* Droplets work on the valleys the stream-power pass left: they cut the
 * gullies too small for it, and drop their load where the slope eases, at
 * slope feet and valley mouths. A droplet that reaches the sea stops and
 * leaves its load at the shore. `guard` is the protection map, built once. */
static void hydraulic(const CpTerrainParams *p, float *height, float *sed, float *guard,
                      CpTerrainProgressFn fn, void *user)
{
    const int n = p->n;
    const float cell = p->size_m / (float)n;
    const float limit = (float)(n - 2);
    Brush brush[17 * 17];
    int nb = make_brush(brush, p->radius);
    CpRng rng;
    int step;
    cp_rng_seed(&rng, p->seed ^ 0xE501D35Du);
    step = p->droplets > 32 ? p->droplets / 32 : 1;
    for (int y = 0; y < n; y++)
        for (int x = 0; x < n; x++)
            guard[y * n + x] = erode_scale_at(p, cell, x, y);

    for (int d = 0; d < p->droplets; d++) {
        float x = 1.f + cp_rng_f(&rng) * (limit - 1.f);
        float y = 1.f + cp_rng_f(&rng) * (limit - 1.f);
        float dx = 0.f, dy = 0.f;
        float speed = 1.f;
        float water = 1.f;
        float sediment = 0.f;

        for (int life = 0; life < p->lifetime; life++) {
            float gx, gy, h0, h1, delta, drop, cap, nx, ny, len2;
            h0 = bilerp(height, n, x, y, &gx, &gy);
            if (!(h0 > 0.f)) break;
            dx = dx * p->inertia - gx * (1.f - p->inertia);
            dy = dy * p->inertia - gy * (1.f - p->inertia);
            len2 = dx * dx + dy * dy;
            if (!(len2 > 1.0e-12f)) break;
            {
                float inv = 1.f / sqrtf(len2);
                dx *= inv;
                dy *= inv;
            }
            nx = x + dx;
            ny = y + dy;
            if (!(nx >= 1.f && ny >= 1.f && nx < limit && ny < limit)) {
                break;
            }
            h1 = bilerp(height, n, nx, ny, &gx, &gy);
            delta = h1 - h0;
            drop = -delta;
            cap = maxf(drop, p->min_slope * cell) * speed * water * p->capacity;

            if (delta > 0.f || sediment > cap) {
                float dep = delta > 0.f ? minf(sediment, delta) : (sediment - cap) * p->deposition;
                if (dep < 0.f) dep = 0.f;
                if (dep > sediment) dep = sediment;
                if (dep > 0.f) deposit_at(height, sed, n, x, y, dep);
                sediment -= dep;
            } else {
                float amount = (cap - sediment) * p->erosion;
                float taken;
                if (amount > drop) amount = drop;
                if (amount < 0.f) amount = 0.f;
                taken = erode_brush(height, n, guard, (int)x, (int)y, amount, brush, nb);
                sediment += taken;
            }

            {
                float v2 = speed * speed + drop * p->gravity;
                speed = sqrtf(v2 > 0.f ? v2 : 0.f);
            }
            water *= 1.f - p->evaporation;
            if (!(water > 0.01f)) break;
            x = nx;
            y = ny;
        }
        /* Settle the remaining load on termination, including lifetime expiry.
         * Spread it over the brush: one cell's worth of dump is a pimple. */
        if (sediment > 0.f) deposit_brush(height, sed, n, (int)x, (int)y, sediment, brush, nb);
        if ((d % step) == 0)
            notify(fn, user, CP_TERR_STAGE_HYDRAULIC, d + 1, p->droplets);
    }
    notify(fn, user, CP_TERR_STAGE_HYDRAULIC, p->droplets, p->droplets > 0 ? p->droplets : 1);
}

void cp_terrain_slope(const float *height, int n, float size_m, float *slope)
{
    float cell = size_m / (float)n;
    float inv = 1.f / cell;
    float inv2 = 1.f / (2.f * cell);
    for (int y = 0; y < n; y++) {
        for (int x = 0; x < n; x++) {
            float dx, dy;
            if (x == 0) dx = (height[y * n + 1] - height[y * n]) * inv;
            else if (x == n - 1) dx = (height[y * n + x] - height[y * n + x - 1]) * inv;
            else dx = (height[y * n + x + 1] - height[y * n + x - 1]) * inv2;
            if (y == 0) dy = (height[n + x] - height[x]) * inv;
            else if (y == n - 1) dy = (height[y * n + x] - height[(y - 1) * n + x]) * inv;
            else dy = (height[(y + 1) * n + x] - height[(y - 1) * n + x]) * inv2;
            slope[y * n + x] = sqrtf(dx * dx + dy * dy);
        }
    }
}

/* ---- hash ---------------------------------------------------------------- */

static void fnv_byte(uint64_t *h, uint8_t b)
{
    *h ^= b;
    *h *= 1099511628211ull;
}

static void fnv_u32(uint64_t *h, uint32_t v)
{
    for (int i = 0; i < 4; i++) fnv_byte(h, (uint8_t)(v >> (8 * i)));
}

static void fnv_f(uint64_t *h, float x)
{
    uint32_t b = 0;
    if (x != 0.0f) memcpy(&b, &x, 4);
    fnv_u32(h, b);
}

uint64_t cp_terrain_hash(const CpTerrain *t)
{
    uint64_t h = 14695981039346656037ull;
    int nn;
    if (!t || !t->height || !t->flow || !t->sediment || t->n < 1 || t->n > CP_TERRAIN_N_MAX) return 0;
    nn = t->n * t->n;
    fnv_u32(&h, (uint32_t)CP_TERRAIN_VERSION);
    fnv_u32(&h, (uint32_t)t->n);
    fnv_f(&h, t->size_m);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->height[i]);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->flow[i]);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->sediment[i]);
    return h;
}

/* Stream-power iterations for a grid of side n. The count is set for N/4;
 * finer grids cost more per step and only have to sharpen what is there. */
static int level_iters(const CpTerrainParams *p, int level)
{
    return level == 2 ? p->stream_iters : level == 1 ? p->stream_iters / 3 : p->stream_iters / 8;
}

/* Multi-scale: the base is analytic, so each level samples it afresh at its
 * own resolution and adds the erosion the coarser level produced, resampled
 * (height change and sediment). Fine noise is never lost to a blurry upsample.
 * Coarse grids live inside the caller's N² buffers; nothing is allocated.
 *
 *   N/4: height, flow, level, sediment, base   in out->flow
 *   N/2: height, flow, level, sediment         in out->sediment, base in scratch
 *        then (height - base) and sediment move to out->flow
 *   N:   the real maps
 */
int cp_terrain_generate(const CpTerrainParams *p, CpTerrain *out,
                        const CpTerrainWorkspace *ws,
                        CpTerrainProgressFn fn, void *user)
{
    int rc = cp_terrain_validate(p);
    int n, n1, n2, use1, use2, nn;
    const float *prev_delta = NULL, *prev_sed = NULL;
    int prev_n = 0;
    Shape shape, settle;
    if (rc != CP_TERR_OK) return rc;
    if (!out || !out->height || !out->flow || !out->sediment) return CP_TERR_ERR_BUFFER;
    if (!ws || !ws->scratch || !ws->recv || !ws->ups || !ws->queue) return CP_TERR_ERR_BUFFER;

    n = p->n;
    nn = n * n;
    n1 = n / 2;
    n2 = n / 4;
    use1 = p->stream_iters > 0 && n1 >= 16;
    use2 = p->stream_iters > 0 && n2 >= 16;
    out->n = n;
    out->size_m = p->size_m;
    shape.fn = fn;
    shape.user = user;
    shape.stage = CP_TERR_STAGE_BASE;
    shape.done = 0;
    shape.total = 8;
    settle = shape;
    settle.stage = CP_TERR_STAGE_THERMAL;
    settle.total = level_iters(p, 0) + p->thermal_iters;
    if (use1) shape.total += 8 + level_iters(p, 1);
    if (use2) shape.total += 8 + level_iters(p, 2);

    if (use2) {
        int a = n2 * n2;
        float *h = out->flow, *fl = h + a, *lv = fl + a, *sd = lv + a, *base = sd + a;
        fill_base(p, n2, base, &shape);
        for (int i = 0; i < a; i++) { h[i] = base[i]; sd[i] = 0.f; }
        stream_power(p, n2, h, sd, fl, lv, ws, level_iters(p, 2), &shape);
        for (int i = 0; i < a; i++) base[i] = h[i] - base[i];
        prev_delta = base;
        prev_sed = sd;
        prev_n = n2;
    }
    if (use1) {
        int b = n1 * n1;
        float *h = out->sediment, *fl = h + b, *lv = fl + b, *sd = lv + b, *base = ws->scratch;
        fill_base(p, n1, base, &shape);
        for (int j = 0; j < n1; j++) for (int i = 0; i < n1; i++) {
            int k = j * n1 + i;
            h[k] = base[k] + (prev_n ? upsample(prev_delta, prev_n, n1, i, j) : 0.f);
            sd[k] = prev_n ? upsample(prev_sed, prev_n, n1, i, j) : 0.f;
        }
        stream_power(p, n1, h, sd, fl, lv, ws, level_iters(p, 1), &shape);
        for (int i = 0; i < b; i++) {
            out->flow[i] = h[i] - base[i];
            out->flow[b + i] = sd[i];
        }
        prev_delta = out->flow;
        prev_sed = out->flow + b;
        prev_n = n1;
    }
    fill_base(p, n, out->height, &shape);
    if (prev_n) {
        for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) {
            int k = j * n + i;
            out->height[k] += upsample(prev_delta, prev_n, n, i, j);
            out->sediment[k] = upsample(prev_sed, prev_n, n, i, j);
        }
    } else {
        memset(out->sediment, 0, sizeof(float) * (size_t)nn);
    }
    shape.done = shape.total - 1;
    shape_tick(&shape);
    /* Droplets go before the fine stream pass, not after: they leave dams
     * of dumped load in the valleys, and the rivers have to cut them. */
    if (p->droplets > 0)
        hydraulic(p, out->height, out->sediment, ws->scratch, fn, user);
    stream_power(p, n, out->height, out->sediment, out->flow, ws->scratch, ws,
                 level_iters(p, 0), &settle);
    thermal(p, out->height, out->sediment, &settle);
    flow_accum(out->height, n, p->size_m, p->seed, out->flow, ws->scratch,
               ws->recv, ws->ups, ws->queue, fn, user);
    notify(fn, user, CP_TERR_STAGE_DONE, 1, 1);
    return CP_TERR_OK;
}
