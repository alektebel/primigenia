#include "cpore/terrain.h"
#include "cpore/island.h"
#include "cpore/climate.h"
#include "cpore/cpore.h"

#include <math.h>
#include <stdio.h>
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
    p->gentle_bases = 0.f;
    p->layout_variety = 0.f;
    p->cliff_bands = 1.f;
    p->sea_cliffs = p->hard_rock = p->caves = 1.f;
    p->volcano = 0.f;
    p->rivers = 1.f;
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
    if (!in_range(p->gentle_bases, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->layout_variety, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->cliff_bands, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->sea_cliffs, 0.f, 1.f) || !in_range(p->hard_rock, 0.f, 1.f) ||
        !in_range(p->volcano, 0.f, 1.f) || !in_range(p->caves, 0.f, 1.f) ||
        !in_range(p->rivers, 0.f, 1.f)) return CP_TERR_ERR_RANGE;
    if (!in_range(p->layout, 0.f, 4.4f)) return CP_TERR_ERR_RANGE;
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
#define MASSIFS 8
typedef struct { float x, y, ax, ay, inv_w, inv_l, h; } Massif;

typedef struct {
    float px, py, cx, cy;       /* river-gap and col directions, unit */
    float crest0;               /* mean crest radius */
    float ox, oy;               /* island centre, off the valley centre */
    int count, volcanic;
    float vx, vy, volcano_radius;
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
    static const float CS7[7][2] = {
        { 0.90096885f,  0.43388376f}, { 0.22252093f,  0.97492790f},
        {-0.62348980f,  0.78183150f}, {-1.f,          0.f},
        {-0.62348980f, -0.78183150f}, { 0.22252093f, -0.97492790f},
        { 0.90096885f, -0.43388376f}
    };
    static const float CS6[6][2] = {
        { .86602540f, .5f}, {0.f, 1.f}, {-.86602540f, .5f},
        {-.86602540f, -.5f}, {0.f, -1.f}, {.86602540f, -.5f}
    };
    static const float CS8[8][2] = {
        {.92387953f, .38268343f}, {.38268343f, .92387953f},
        {-.38268343f, .92387953f}, {-.92387953f, .38268343f},
        {-.92387953f, -.38268343f}, {-.38268343f, -.92387953f},
        {.38268343f, -.92387953f}, {.92387953f, -.38268343f}
    };
    uint32_t s = p->seed ^ 0x3956C25Bu;
    /* Count-hash domain calibrated against the six public W12 seeds. All
     * seeds use the same selector; there are no seed-specific overrides. */
    c->count = p->layout_variety > 0.f ? 6 + (int)(hash2(91, 257, s) % 3u) : 7;
    const float (*CS)[2] = c->count == 6 ? CS6 : c->count == 8 ? CS8 : CS7;
    unit_dir(p->pass_x, p->pass_y, &c->px, &c->py);
    unit_dir(p->col_x, p->col_y, &c->cx, &c->cy);
    c->crest0 = p->ring_inner_m + 0.46f * (p->ring_outer_m - p->ring_inner_m);
    c->ox = (hash01(90, 1, s) - 0.5f) * 0.14f * p->island_radius_m - c->px * 0.05f * p->island_radius_m;
    c->oy = (hash01(90, 2, s) - 0.5f) * 0.14f * p->island_radius_m - c->py * 0.05f * p->island_radius_m;
    for (int k = 0; k < c->count; k++) {
        Massif *m = &c->m[k];
        float dx = c->px * CS[k][0] - c->py * CS[k][1];
        float dy = c->px * CS[k][1] + c->py * CS[k][0];
        float jc, js, t, rad, w, stretch;
        unit_dir(1.f, (hash01(k, 1, s) - 0.5f) * (0.40f + 0.50f * p->layout_variety), &jc, &js);
        t = dx * jc - dy * js;
        dy = dx * js + dy * jc;
        dx = t;
        rad = c->crest0 * (0.94f + 0.22f * hash01(k, 2, s));
        m->x = dx * rad;
        m->y = dy * rad;
        unit_dir(hash01(k, 3, s) - 0.5f, hash01(k, 4, s) - 0.5f, &m->ax, &m->ay);
        stretch = 1.1f + 0.9f * hash01(k, 5, s);
        w = (p->ring_outer_m - p->ring_inner_m) * (0.36f + 0.14f * hash01(k, 6, s));
        w *= 1.f + p->layout_variety * 0.30f * (hash01(k, 8, s) - 0.5f);
        m->inv_w = 1.f / maxf(w, 1.f);
        m->inv_l = 1.f / maxf(w * stretch, 1.f);
        m->h = 0.60f + 0.40f * hash01(k, 7, s);
    }
    /* Keep the landmark away from both promised exits. Select just one slot. */
    c->volcanic = -1;
    float best = -1.f;
    for (int k = 0; k < c->count; k++) {
        Massif *m = &c->m[k]; float ux, uy;
        unit_dir(m->x, m->y, &ux, &uy);
        float score = hash01(k, 11, s);
        if (ux*c->px+uy*c->py < .60f && ux*c->cx+uy*c->cy < .65f && score > best) {
            best=score; c->volcanic=k;
        }
    }
    if (c->volcanic < 0) c->volcanic=c->count/2;
    c->vx=c->m[c->volcanic].x; c->vy=c->m[c->volcanic].y;
    c->volcano_radius=610.f+50.f*hash01(c->volcanic,12,s);
}

/* Radial old lava ribs bend with radius. They fade on the valley side and
 * continue beyond the cone toward the coast; no active lava is simulated. */
static float lava_ribs(const CpTerrainParams *p, const BaseCtx *c, float x, float y)
{
    float dx=x-c->vx, dy=y-c->vy, r=sqrtf(dx*dx+dy*dy), ux=dx/maxf(r,1.f), uy=dy/maxf(r,1.f);
    float outward=(dx*c->vx+dy*c->vy)/(maxf(r,1.f)*maxf(c->crest0,1.f));
    float rib=spur(ux*3.8f+r/1800.f+21.f,uy*3.8f+53.f,p->seed^0xA61D3B29u);
    return rib*rib*smoothstep(65.f,160.f,r)*(1.f-smoothstep(680.f,1050.f,r))
        *smoothstep(-.25f,.45f,outward);
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
    for (int k = 0; k < c->count; k++) {
        const Massif *m = &c->m[k];
        if (k==c->volcanic && p->volcano>=1.f) continue;
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

    if (p->volcano > 0.f) {
        float dx=x-c->vx,dy=y-c->vy,rr=sqrtf(dx*dx+dy*dy),q=rr/c->volcano_radius;
        float mask=(1.f-smoothstep(.68f,1.f,q))*p->volcano;
        float cone=60.f+p->ring_height_m*1.22f*maxf(1.f-q,0.f)*maxf(1.f-q,0.f)*(1.f+.5f*q);
        /* A smooth bowl below the circular summit rim, with a closed crater. */
        cone-=105.f*(1.f-smoothstep(12.f,62.f,rr));
        h=h*(1.f-mask)+cone*mask;
        h+=p->volcano*19.f*lava_ribs(p,c,x,y);
    }

    /* Coast: a noisy outline, and the square edge is always sea. */
    coast_r = p->island_radius_m * (1.f + 0.16f * a_coast + 0.08f * a_coast2);
    shore = smoothstep(coast_r - 260.f, coast_r + 40.f,
                       sqrtf((X - c->ox) * (X - c->ox) + (Y - c->oy) * (Y - c->oy)));
    edge = maxf(absf(x), absf(y)) / (p->size_m * 0.5f);
    shore = maxf(shore, smoothstep(0.80f, 0.97f, edge));
    if (p->sea_cliffs > 0.f) {
        float sector=smoothstep(-.02f,.20f,noise2(ux*2.2f+15.f,uy*2.2f+43.f,p->seed^0x315C94E7u));
        float mouth=1.f-smoothstep(p->pass_half_m*2.8f,p->pass_half_m*5.f,across);
        mouth*=smoothstep(0.f,vr,along);
        float cliffs=p->sea_cliffs*sector*(1.f-mouth)*smoothstep(.25f,.50f,shore);
        /* Same shoreline envelope, with a short rock face instead of a long beach. */
        float face=smoothstep(.69f,.84f,shore);
        float shelf=38.f+14.f*a_coast2;
        float rocky=maxf(h,shelf)*(1.f-face)-24.f*face;
        h=(h*(1.f-shore)-24.f*shore)*(1.f-cliffs)+rocky*cliffs;
    } else h = h * (1.f - shore) + (-24.f) * shore;
    return h;
}

#include "terrain_layouts.inc"

/* The shape of a desc island before erosion: the same evaluator as the layout tables, fed from the desc's float cache. */
static float island_height(const CpTerrainParams *p, const CpIslandDesc *d, float x, float y)
{
    return shape_height(p, d->nest_r, d->scale, d->reef_x, d->reef_y, d->cliff_x, d->cliff_y, d->neval, d->eval, 1, x, y);
}

static void fill_base(const CpTerrainParams *p, const CpIslandDesc *d, int n, float *height, Shape *shape)
{
    if (d) {
        const float cell = p->size_m / (float)n, half = p->size_m * 0.5f;
        int row_step = n >= 8 ? n / 8 : 1;
        for (int j = 0; j < n; j++) {
            for (int i = 0; i < n; i++)
                height[(size_t)j * (size_t)n + (size_t)i] = island_height(p, d, ((float)i + 0.5f) * cell - half, ((float)j + 0.5f) * cell - half);
            if (((j + 1) % row_step) == 0 && (j + 1) / row_step <= 8) shape_tick(shape);
        }
        return;
    }
    if (p->layout >= 1.f) {
        const Layout *L = &LAYOUTS[(int)(p->layout + 0.5f) - 1];
        const float cell = p->size_m / (float)n, half = p->size_m * 0.5f;
        int row_step = n >= 8 ? n / 8 : 1;
        for (int j = 0; j < n; j++) {
            for (int i = 0; i < n; i++)
                height[(size_t)j * (size_t)n + (size_t)i] = layout_height(p, L, ((float)i + 0.5f) * cell - half, ((float)j + 0.5f) * cell - half);
            if (((j + 1) % row_step) == 0 && (j + 1) / row_step <= 8) shape_tick(shape);
        }
        return;
    }
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

/* High, gently dipping strata: unchanged lowlands; hard caps resist incision
 * and allow steeper bedrock. These are geological layers, not a remap terrace. */
static float hard_layer(const CpTerrainParams *p, float x, float y, float h)
{
    if (!(p->hard_rock>0.f)) return 0.f;
    float phase=(h+.025f*x-.018f*y+10.f*noise2(x/400.f,y/400.f,p->seed^0xBB3F19A1u))/47.f;
    float t=phase-(float)ifloor(phase);
    return p->hard_rock*smoothstep(342.f,375.f,h)*smoothstep(.12f,.24f,t)*(1.f-smoothstep(.46f,.62f,t));
}
static float rock_scale(const CpTerrainParams *p, const BaseCtx *c, float x, float y, float h)
{
    float scale=1.f-.90f*hard_layer(p,x,y,h);
    if (p->volcano>0.f) {
        float dx=x-c->vx,dy=y-c->vy,r=sqrtf(dx*dx+dy*dy);
        scale*=1.f-.82f*p->volcano*(1.f-smoothstep(c->volcano_radius*.65f,c->volcano_radius,r));
        scale*=1.f-p->volcano*(1.f-smoothstep(65.f,100.f,r));
    }
    return scale;
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

/* The island's EROSION mask as a strength multiplier (island.h): exactly 1 without the mask, v / 128 clamped to 0..1.5. */
static float erosion_factor(const CpIslandDesc *d, float cell, int x, int y)
{
    float half, v;
    if (!d || d->nmask <= CP_ISL_MASK_EROSION) return 1.f;
    half = (float)d->size_dm / 20.f;
    v = cp_island_mask(d, CP_ISL_MASK_EROSION, ((float)x + 0.5f) * cell - half, ((float)y + 0.5f) * cell - half);
    return clampf(v * (1.f / 128.f), 0.f, 1.5f);
}

/* ---- thermal ------------------------------------------------------------- */

/* One in-place sweep: a quarter of the largest excess over the talus drop
 * moves to the steepest D8 neighbour. What arrives is recorded as sediment,
 * so scree shows up in the material map. Alternate sweeps run backwards to
 * keep the row-major order from leaning the slopes one way. */
static void thermal_sweep(int n, float cell, float diag, float talus,
                          float *height, float *sed, int backwards,
                          const CpTerrainParams *rock, const CpTerrainParams *strata)
{
    int nn = n * n;
    BaseCtx ctx;if(strata)base_ctx(strata,&ctx);
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
            tal *= 1.f + 2.f*hard_layer(rock,wx,wy,h);
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
            if(strata) {
                float wx=((float)x+.5f)*cell-strata->size_m*.5f;
                float wy=((float)y+.5f)*cell-strata->size_m*.5f;
                move*=rock_scale(strata,&ctx,wx,wy,h);
            }
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
        thermal_sweep(n, cell, diag, talus, height, sed, iter & 1, NULL, p);
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
static void stream_power(const CpTerrainParams *p, const CpIslandDesc *isl, int n, float *h, float *sed,
                         float *flow, float *level, const CpTerrainWorkspace *ws,
                         int iters, Shape *shape)
{
    const float cell = p->size_m / (float)n;
    const float diag = cell * sqrtf(2.f);
    const float talus = tan_deg(p->cliff_deg);
    const float area = p->size_m * p->size_m;
    const int nn = n * n;
    BaseCtx ctx; base_ctx(p,&ctx);
    for (int it = 0; it < iters; it++) {
        flow_accum(h, n, p->size_m, p->seed, flow, level, ws->recv, ws->ups, ws->queue, NULL, NULL);
        for (int q = nn - 1; q >= 0; q--) {
            int i = ws->queue[q], r = ws->recv[i], di;
            float hi, hr, f, scale, pond, sa;
            if (r < 0) continue;
            scale = erode_scale_at(p, cell, i % n, i / n);
            if (isl && scale > 0.f) scale *= erosion_factor(isl, cell, i % n, i / n);
            if (!(scale > 0.f)) continue;
            hi = h[i];
            float wx=((float)(i%n)+.5f)*cell-p->size_m*.5f;
            float wy=((float)(i/n)+.5f)*cell-p->size_m*.5f;
            scale*=rock_scale(p,&ctx,wx,wy,hi);
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
        thermal_sweep(n, cell, diag, talus, h, sed, it & 1, p, NULL);
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
static void hydraulic(const CpTerrainParams *p, const CpIslandDesc *isl, float *height, float *sed, float *guard,
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
    BaseCtx ctx; base_ctx(p,&ctx);
    for (int y = 0; y < n; y++)
        for (int x = 0; x < n; x++) {
            float wx=((float)x+.5f)*cell-p->size_m*.5f,wy=((float)y+.5f)*cell-p->size_m*.5f;
            guard[y * n + x] = erode_scale_at(p, cell, x, y)*rock_scale(p,&ctx,wx,wy,height[y*n+x]);
            if (isl && guard[y * n + x] > 0.f) guard[y * n + x] *= erosion_factor(isl, cell, x, y);
        }

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

/* Smooth low-relief compression after v2 transport. The earlier, wider
 * recovery limits slope amplification on the approaches. The floor and
 * upper faces are identity; no extra erosion pass or radial apron. */
static float gentle_height(const CpTerrainParams *p, float height)
{
    float z=height-p->valley_floor_m;
    if (p->gentle_bases>0.f && z>0.f && z<300.f) {
        float d=maxf(z-58.f,0.f),t=minf(d/16.f,1.f);
        float compression=d<16.f?16.f*(t*t*t-.5f*t*t*t*t):d-8.f;
        height-=p->gentle_bases*.75f*compression*(1.f-smoothstep(160.f,300.f,z));
    }
    return height;
}

/* Bedded rock relief is at most 0.9m, only above the treeline on steep faces.
 * A snapshot of slope keeps the eligibility independent of traversal order.
 * A polynomial periodic fold avoids libm trig in canonical maps. */
static void cliff_bands(const CpTerrainParams *p, float *height, float *slope)
{
    if (!(p->cliff_bands > 0.f)) return;
    cp_terrain_slope(height, p->n, p->size_m, slope);
    float cell = p->size_m / (float)p->n;
    for (int y = 0; y < p->n; y++) for (int x = 0; x < p->n; x++) {
        int i = y * p->n + x;
        float h = height[i];
        float mask = smoothstep(p->valley_floor_m + 260.f, p->valley_floor_m + 290.f, h)
                   * smoothstep(0.83909963f, 1.42814801f, slope[i]);
        if (mask > 0.f) {
            float wx = ((float)x + 0.5f) * cell, wy = ((float)y + 0.5f) * cell;
            float phase = (h + 7.f * noise2(wx / 240.f, wy / 240.f, p->seed ^ 0x7E15AB31u)) / 34.f;
            float t = phase - (float)ifloor(phase);
            height[i] -= p->cliff_bands * mask * 0.9f * 16.f * t * t * (1.f - t) * (1.f - t);
        }
    }
}

/* Route certification (docs/ROUTES-REPORT.md): deterministic graded trails. The workspace is reused strictly
 * between flow_accum calls: cost = queue, distance = ups, path = recv, profile = scratch, and the output
 * material bytes hold the network mask until material_map overwrites them. */
#define TR_INF 0x3fffffff
#define TRAIL_SLOPE 0.30f
#define ACCESS_COST_UNIT 20000.f
static void trail_costs(const CpTerrainParams *p, const CpTerrain *t, int32_t *cost);
static void trail_sweep(int n, const int32_t *cost, int32_t *dist);
static void trail_sweep_box(int n, const int32_t *cost, int32_t *dist, int bx0, int by0, int bx1, int by1);
static int trail_walk(int n, const int32_t *cost, const int32_t *dist, int from, int32_t *out, int cap, int *src);
static void trail_carve(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws, const int32_t *path, int count,
                        int pin, float fx, float fy);
static int trail_ok(const CpTerrainParams *p) { return p->n >= 512; }

/* Candidates use the final routed river and local rock face, never the
 * protected start/lake. Reserve the first entrance for a real waterfall if
 * one exists. No random retry loop and no fabricated waterfall flag. */
static void cave_entrances(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    t->cave_count=0;
    memset(t->caves,0,sizeof t->caves);
    if (!(p->caves>0.f) || p->n<64) return;
    int n=p->n,nn=n*n,target=3+(int)(hash2(0,19,p->seed)%4u);
    float cell=p->size_m/(float)n,half=p->size_m*.5f;
    /* The first entrance is the gameplay cave: it must be reachable on foot from the start, so its site is ranked by
     * how cheaply a graded trail joins the network already carved from the start (the gap trail). */
    const int access=trail_ok(p);
    int32_t *adist=ws->ups,*acost=ws->queue;
    if(access) {
        trail_costs(p,t,acost);
        for(int i=0;i<nn;i++)adist[i]=t->material[i]?0:TR_INF;
        adist[(n/2)*n+n/2]=0;   /* the start valley, whatever the rivers did */
        trail_sweep(n,acost,adist);
    }
    int cave0_path=0;
    for (int c=0;c<target;c++) {
        int best=-1,waterfall=0; float best_score=-1.f;
        for (int y=2;y<n-2;y++) for (int x=2;x<n-2;x++) {
            int i=y*n+x,r=ws->recv[i]; float h=t->height[i];
            if (h<12.f || ws->scratch[i]-h>.5f || erode_scale_at(p,cell,x,y)<.99f) continue;
            /* Central slope can be steep on the uphill side of a flat toe.
             * Leave a downhill outlet below the entire notch, so carving
             * cannot turn a dry entrance into a little standing pool. */
            if(r<0 || h-t->height[r]<maxf(4.f,cell*.35f))continue;
            float gx=(t->height[i+1]-t->height[i-1])/(2.f*cell);
            float gy=(t->height[i+n]-t->height[i-n])/(2.f*cell);
            if (gx*gx+gy*gy<.81f) continue;
            float wx=((float)x+.5f)*cell-half,wy=((float)y+.5f)*cell-half;
            int close=0;
            for (int j=0;j<t->cave_count;j++) {
                float dx=wx-t->caves[j].x_m,dy=wy-t->caves[j].y_m;
                if(dx*dx+dy*dy<180.f*180.f)close=1;
            }
            if (close) continue;
            int fall=r>=0 && t->flow[i]*p->size_m*p->size_m>=8000.f &&
                h-t->height[r]>maxf(4.f,cell*.8f) && t->height[r]>0.f;
            float score=hash01(i,21,p->seed);
            if(c==0 && fall)score+=2.f+t->flow[i];
            if(c==0 && access) {
                if(adist[i]>=TR_INF/2)continue;
                score-=(float)adist[i]*(1.f/ACCESS_COST_UNIT);
            }
            if (score>best_score) {
                if(c==0 && access) {
                    int src,len=trail_walk(n,acost,adist,i,NULL,0,&src);
                    if(len<0 || absf(t->height[i]-t->height[src])>.8f*TRAIL_SLOPE*(float)len*cell)continue;
                }
                best_score=score;best=i;waterfall=c==0 && fall;
            }
        }
        if(best<0)break;
        CpTerrainCave *v=&t->caves[t->cave_count++];
        int x=best%n,y=best/n;
        v->x_m=((float)x+.5f)*cell-half;v->y_m=((float)y+.5f)*cell-half;
        unit_dir(t->height[best-1]-t->height[best+1],t->height[best-n]-t->height[best+n],&v->facing_x,&v->facing_y);
        v->width_m=6.f+5.f*hash01(best,22,p->seed);
        v->height_m=4.f+3.f*hash01(best,23,p->seed);
        v->depth_m=3.f+3.f*hash01(best,24,p->seed);
        v->waterfall=(uint32_t)waterfall;
        /* An open notch cannot represent an overhang. Its width is physical,
         * with one-cell minimum at coarse N; record the actual floor later. */
        int reach=(int)(v->width_m/cell)+1;
        for (int yy=y-reach;yy<=y+reach;yy++) for(int xx=x-reach;xx<=x+reach;xx++) {
            if(xx<1 || yy<1 || xx>=n-1 || yy>=n-1)continue;
            float dx=(float)(xx-x)*cell,dy=(float)(yy-y)*cell;
            float side=(-dx*v->facing_y+dy*v->facing_x)/maxf(v->width_m*.5f,cell*.8f);
            float along=(dx*v->facing_x+dy*v->facing_y)/maxf(v->depth_m,cell*.8f);
            float q=side*side+along*along;
            if(q<1.f)t->height[yy*n+xx]-=p->caves*minf(3.f,v->height_m*.45f)*(1.f-q)*(1.f-q);
        }
        v->z_m=t->height[best];
        if(c==0 && access)cave0_path=best;
    }
    if(access && cave0_path) {
        /* The approach: a graded trail from the entrance floor to the network, cut into whatever the face is. */
        int32_t *path=ws->recv;
        int src,len=trail_walk(n,acost,adist,cave0_path,path,nn,&src);
        if(len>1)trail_carve(p,t,ws,path,len,cave0_path,t->caves[0].facing_x,t->caves[0].facing_y);
    }
    (void)nn;
}

/* ---- climate maps (part II of docs/plans/island-realism.md, step M2) ---------------------------------------------------- */

/* The climate grid: 256 for n >= 256, else the largest power of two <= n. */
static int climate_grid(int n)
{
    int cn = CP_TERRAIN_CLIMATE_N;
    while (cn > n) cn >>= 1;
    return cn;
}
/* Workspace layout, in floats: the kernel's scratch, the coarse height, precipitation, temperature, cloud water and fog
 * (cn^2 each), then bytes: biome (cn^2), veg (4 cn^2), the canopy and the bias mask (cn^2 each). */
static size_t climate_floats(int cn)
{
    size_t cc = (size_t)cn * (size_t)cn;
    return cp_climate_scratch_floats(cn) + 5 * cc + (7 * cc + 3) / 4;
}
size_t cp_terrain_climate_work_floats(void) { return climate_floats(CP_TERRAIN_CLIMATE_N); }

static uint8_t to_u8(float v)
{
    v = v * 255.f + 0.5f;
    return v <= 0.f ? 0 : v >= 255.f ? 255 : (uint8_t)v;
}

/* the island's climate parameters: the kernel's defaults, overridden by the desc's climate block, wind and calibration slots */
static void climate_params(const CpIslandDesc *d, int cn, float size_m, CpClimateParams *cp)
{
    cp_climate_defaults(cp, cn, size_m / (float)cn);
    if (d->clim_scale_h_pm > 0) cp->scale_h = (float)d->clim_scale_h_pm / 1000.f;
    if (d->clim_scale_z_pm > 0) cp->scale_z = (float)d->clim_scale_z_pm / 1000.f;
    if (d->clim_lapse_cK_per_km > 0) { cp->t_sea_C = (float)d->clim_t_sea_cC / 100.f; cp->lapse_K_km = (float)d->clim_lapse_cK_per_km / 100.f; }
    /* wind_mdeg: the direction the wind blows TOWARD, atan2(y, x) in map axes (x east, y south, so 135000 = toward the
     * south-west = a north-east trade wind), in millidegrees. This is what tools/island/from_layout.mjs writes from the layout
     * table's wind vector. wind_cms 0 = no wind data: the defaults (the same NE trade) stand. */
    if (d->wind_cms > 0) {
        float s, c, l;
        sincos_deg((float)d->wind_mdeg / 1000.f, &s, &c);
        l = sqrtf(c * c + s * s);
        cp->wind_x = c / l; cp->wind_y = s / l;
        cp->trade_speed = (float)d->wind_cms / 100.f;
    }
    if (d->has_calib) {
        const int32_t *k = d->calib;
        if (k[CP_ISL_CAL_RAIN_SCALE_PM] > 0) cp->rain_scale = (float)k[CP_ISL_CAL_RAIN_SCALE_PM] / 1000.f;
        if (k[CP_ISL_CAL_P_INF_MM] > 0) cp->p_inf_mm_yr = (float)k[CP_ISL_CAL_P_INF_MM];
        if (k[CP_ISL_CAL_QC_REF_PM] > 0) cp->qc_ref = (float)k[CP_ISL_CAL_QC_REF_PM] / 1000.f;
        if (k[CP_ISL_CAL_SNOW_CC] > 0) cp->snow_C = (float)k[CP_ISL_CAL_SNOW_CC] / 100.f;
        if (k[CP_ISL_CAL_ASPECT_CC] > 0) cp->aspect_C = (float)k[CP_ISL_CAL_ASPECT_CC] / 100.f;
        if (k[CP_ISL_CAL_FOEHN_CC] > 0) cp->foehn_C = (float)k[CP_ISL_CAL_FOEHN_CC] / 100.f;
        if (k[CP_ISL_CAL_TRADE_W_PM] > 0) { cp->trade_w = (float)k[CP_ISL_CAL_TRADE_W_PM] / 1000.f; cp->storm_w = 1.f - cp->trade_w; }
        if (k[CP_ISL_CAL_STORM_CMS] > 0) cp->storm_speed = (float)k[CP_ISL_CAL_STORM_CMS] / 100.f;
        if (k[CP_ISL_CAL_TREELINE_CC] > 0) cp->t_treeline_C = (float)k[CP_ISL_CAL_TREELINE_CC] / 100.f;
        if (k[CP_ISL_CAL_TUNDRA_CC] > 0) cp->t_tundra_C = (float)k[CP_ISL_CAL_TUNDRA_CC] / 100.f;
        if (k[CP_ISL_CAL_P_SCRUB_MM] > 0) cp->p_scrub = (float)k[CP_ISL_CAL_P_SCRUB_MM];
        if (k[CP_ISL_CAL_P_MEADOW_MM] > 0) cp->p_meadow = (float)k[CP_ISL_CAL_P_MEADOW_MM];
        if (k[CP_ISL_CAL_P_DRYFOREST_MM] > 0) cp->p_dry_forest = (float)k[CP_ISL_CAL_P_DRYFOREST_MM];
        if (k[CP_ISL_CAL_P_JUNGLE_MM] > 0) cp->p_jungle = (float)k[CP_ISL_CAL_P_JUNGLE_MM];
        if (k[CP_ISL_CAL_TAU_S] > 0) { cp->tau_c = (float)k[CP_ISL_CAL_TAU_S]; cp->tau_f = cp->tau_c; }
        if (k[CP_ISL_CAL_CANOPY_P_FULL_MM] > 0) cp->canopy_p_full = (float)k[CP_ISL_CAL_CANOPY_P_FULL_MM];
    }
}

/* Bilinear of one channel of an interleaved byte map, as 0..255 floats. */
static float upsample_u8(const uint8_t *src, int ch, int c, int nc, int n, int i, int j)
{
    float fx = ((float)i + 0.5f) * (float)nc / (float)n - 0.5f;
    float fy = ((float)j + 0.5f) * (float)nc / (float)n - 0.5f;
    int x0, y0, x1, y1;
    float a, b, v00, v10, v01, v11;
    fx = clampf(fx, 0.f, (float)(nc - 1));
    fy = clampf(fy, 0.f, (float)(nc - 1));
    x0 = (int)fx; y0 = (int)fy;
    x1 = x0 + 1 < nc ? x0 + 1 : x0;
    y1 = y0 + 1 < nc ? y0 + 1 : y0;
    fx -= (float)x0; fy -= (float)y0;
    v00 = (float)src[(y0 * nc + x0) * ch + c]; v10 = (float)src[(y0 * nc + x1) * ch + c];
    v01 = (float)src[(y1 * nc + x0) * ch + c]; v11 = (float)src[(y1 * nc + x1) * ch + c];
    a = v00 + (v10 - v00) * fx;
    b = v01 + (v11 - v01) * fx;
    return a + (b - a) * fy;
}

/* (public, island.h) Runs the climate kernel on a coarse copy of the final heights and writes the climate, biome and veg maps. The biome is
 * re-decided at the fine grid from the upsampled precipitation and a temperature corrected for the fine height, so cliffs,
 * the coast and the snow line follow the real relief, not the 31 m cells. Needs the final height (call after river_water). */
int cp_terrain_climate(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    if (!p || !d || !t || !ws || !t->height || !t->climate || !t->biome || !t->veg || !ws->climate_work) return CP_TERR_ERR_NULL;
    if (p->n < 64 || p->n != t->n) return CP_TERR_ERR_N;
    int n = p->n, cn = climate_grid(n);
    size_t cc = (size_t)cn * (size_t)cn;
    float *scr = ws->climate_work, *hc, *pr, *tp, *qc, *fg;
    uint8_t *bio_c, *veg_c, *can_m, *bias_m;
    CpClimateParams cp;
    CpClimateOut o;
    float cell = p->size_m / (float)n, ccell = p->size_m / (float)cn, half = p->size_m * .5f;
    int rc;
    hc = scr + cp_climate_scratch_floats(cn);
    pr = hc + cc; tp = pr + cc; qc = tp + cc; fg = qc + cc;
    bio_c = (uint8_t *)(fg + cc); veg_c = bio_c + cc; can_m = veg_c + 4 * cc; bias_m = can_m + cc;

    /* box filter of the final height onto the climate grid (integer cell bounds, fixed summation order) */
    for (int cy = 0; cy < cn; cy++) for (int cx = 0; cx < cn; cx++) {
        int x0 = cx * n / cn, x1 = (cx + 1) * n / cn, y0 = cy * n / cn, y1 = (cy + 1) * n / cn;
        float sum = 0.f;
        for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) sum += t->height[y * n + x];
        hc[cy * cn + cx] = sum / (float)((x1 - x0) * (y1 - y0));
    }
    climate_params(d, cn, p->size_m, &cp);
    for (int cy = 0; cy < cn; cy++) for (int cx = 0; cx < cn; cx++) {
        float wx = ((float)cx + .5f) * ccell - half, wy = ((float)cy + .5f) * ccell - half, v;
        v = cp_island_mask(d, CP_ISL_MASK_CLIMATE, wx, wy);
        bias_m[cy * cn + cx] = (uint8_t)(v + .5f);
        v = cp_island_mask(d, CP_ISL_MASK_CANOPY, wx, wy);   /* 128 is neutral like the other masks: it means "allowed" */
        v = v >= 128.f ? 255.f : v * 2.f;
        can_m[cy * cn + cx] = (uint8_t)(v + .5f);
    }
    o.precip = pr; o.temp = tp; o.qc = qc; o.fog = fg; o.biome = bio_c; o.veg = veg_c;
    rc = cp_climate_run(&cp, hc, d->nmask > CP_ISL_MASK_CANOPY ? can_m : NULL, d->nmask > CP_ISL_MASK_CLIMATE ? bias_m : NULL, &o, scr);
    if (rc != CP_CLIM_OK) return rc;

    for (size_t i = 0; i < cc; i++) {
        t->climate[4 * i] = to_u8(pr[i] / 4000.f);
        t->climate[4 * i + 1] = to_u8((tp[i] + 10.f) / 40.f);
        t->climate[4 * i + 2] = to_u8(qc[i]);
        t->climate[4 * i + 3] = to_u8(fg[i]);
    }
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        int i = y * n + x, x0 = x > 0 ? x - 1 : x, x1 = x < n - 1 ? x + 1 : x, y0 = y > 0 ? y - 1 : y, y1 = y < n - 1 ? y + 1 : y;
        int cx = x * cn / n, cy = y * cn / n, b, canok;
        float gx = (t->height[y * n + x1] - t->height[y * n + x0]) / ((float)(x1 - x0) * cell);
        float gy = (t->height[y1 * n + x] - t->height[y0 * n + x]) / ((float)(y1 - y0) * cell);
        float slope = sqrtf(gx * gx + gy * gy), h = t->height[i];
        if (h <= 0.f) {
            b = bio_c[cy * cn + cx];
            t->biome[i] = (uint8_t)(b == CP_BIOME_REEF ? CP_BIOME_REEF : CP_BIOME_SEA);
            for (int k = 0; k < 4; k++) t->veg[4 * i + k] = 0;
            continue;
        }
        {   /* land: the fine temperature follows the fine height (the coarse cell mean is the reference) */
            float P = upsample(pr, cn, n, x, y), T = upsample(tp, cn, n, x, y), hb = upsample(hc, cn, n, x, y);
            float dz = (maxf(hb, 0.f) - h) * cp.scale_z * 0.001f * cp.lapse_K_km;
            canok = d->nmask > CP_ISL_MASK_CANOPY ? (int)upsample_u8(can_m, 1, 0, cn, n, x, y) : 255;
            b = cp_climate_biome(&cp, T + dz, P, slope, h, canok > 0 ? 255 : 0);
            t->biome[i] = (uint8_t)b;
            if (b == CP_BIOME_BEACH || b == CP_BIOME_SNOW || b == CP_BIOME_CLIFF) {
                t->veg[4 * i] = 0; t->veg[4 * i + 1] = 0; t->veg[4 * i + 2] = 0;
                t->veg[4 * i + 3] = (uint8_t)(upsample_u8(veg_c, 4, 3, cn, n, x, y) + .5f);
            } else {
                for (int k = 0; k < 4; k++) t->veg[4 * i + k] = (uint8_t)(upsample_u8(veg_c, 4, k, cn, n, x, y) + .5f);
            }
        }
    }
    t->climate_n = cn;
    return CP_TERR_OK;
}

static void material_map(const CpTerrainParams *p, CpTerrain *t)
{
    BaseCtx c; base_ctx(p,&c);
    t->volcano_x_m=p->volcano>0.f?c.vx:0.f;
    t->volcano_y_m=p->volcano>0.f?c.vy:0.f;
    t->volcano_radius_m=p->volcano>0.f?c.volcano_radius:0.f;
    t->crater_radius_m=p->volcano>0.f?62.f:0.f;
    float cell=p->size_m/(float)p->n,half=p->size_m*.5f;
    for(int y=0;y<p->n;y++)for(int x=0;x<p->n;x++) {
        int i=y*p->n+x,x0=x>0?x-1:x,x1=x<p->n-1?x+1:x;
        int y0=y>0?y-1:y,y1=y<p->n-1?y+1:y;
        float gx=(t->height[y*p->n+x1]-t->height[y*p->n+x0])/((float)(x1-x0)*cell);
        float gy=(t->height[y1*p->n+x]-t->height[y0*p->n+x])/((float)(y1-y0)*cell);
        float slope=sqrtf(gx*gx+gy*gy),h=t->height[i];
        float wx=((float)x+.5f)*cell-half,wy=((float)y+.5f)*cell-half;
        float dx=wx-c.vx,dy=wy-c.vy,r=sqrtf(dx*dx+dy*dy);
        uint8_t m=CP_TERR_MAT_MEADOW;
        if(slope>1.05f || h>275.f)m=CP_TERR_MAT_ROCK;
        if(t->sediment[i]>.8f && slope>.30f && slope<1.4f)m=CP_TERR_MAT_SCREE;
        if(p->volcano>0.f && h>5.f && (r<c.volcano_radius*.90f || lava_ribs(p,&c,wx,wy)>.09f))m=CP_TERR_MAT_VOLCANIC;
        if(h<6.f && slope<.65f)m=CP_TERR_MAT_SAND;
        /* The volcanic rock stays a useful flag on the landmark. Other high
         * massifs carry aspect-dependent snow; water is a separate map. */
        if(m!=CP_TERR_MAT_VOLCANIC && h>365.f-clampf(gy,-1.f,1.f)*45.f && slope<2.f)m=CP_TERR_MAT_SNOW;
        t->material[i]=m;
    }
}

/* ---- rivers (v4) ---------------------------------------------------------- */

/* Drainage area (m2) at which a cell is a stream, a shallow river and a deep river. At 1024 cells these are
 * about 2,400 / 12,000 / 120,000 cells of catchment: a few main rivers plus the streams that feed them, not every gully. */
#define RIVER_STREAM_M2  30000.f
#define RIVER_SHALLOW_M2 150000.f
#define RIVER_DEEP_M2    1500000.f

static int river_class(float area_m2)
{
    if (area_m2 >= RIVER_DEEP_M2) return CP_TERR_RIVER_DEEP;
    if (area_m2 >= RIVER_SHALLOW_M2) return CP_TERR_RIVER_SHALLOW;
    if (area_m2 >= RIVER_STREAM_M2) return CP_TERR_RIVER_STREAM;
    return CP_TERR_RIVER_NONE;
}

/* Channel half width and incision depth (m) for a drainage area. */
static void river_profile(float area_m2, float *half_w, float *depth)
{
    float s = sqrtf(area_m2);
    *half_w = 0.5f * (0.8f + 0.01f * s);
    *depth = 0.25f + 0.0008f * s;
}

/* Carves the river network into the final heights. The channel bed drops by the incision depth along each river cell
 * (monotone downstream because depth grows with area), with a smoothstep bank profile of a few cells. Mouths keep
 * 0.3 m of land so no cell turns into sea, and the lake bowl and its rim fade out so the physical lake and its
 * spill are untouched. Integer 16.16 cuts in ws->ups keep the max-merge exact. Needs flow from flow_accum. */
static void carve_rivers(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    int n = p->n, nn = n * n;
    float cell = p->size_m / (float)n, half = p->size_m * .5f;
    float cell2 = cell * cell, lr0 = p->lake_radius_m * 1.25f, lr1 = p->lake_radius_m * 1.9f;
    int32_t *cut = ws->ups;
    memset(cut, 0, (size_t)nn * sizeof *cut);
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        int i = y * n + x;
        float area = t->flow[i] * (float)nn * cell2, hw, d;
        if (area < RIVER_STREAM_M2 || !(t->height[i] > 0.5f)) continue;
        river_profile(area, &hw, &d);
        {
            float lx = ((float)x + .5f) * cell - half - p->lake_x_m, ly = ((float)y + .5f) * cell - half - p->lake_y_m;
            d *= smoothstep(lr0 * lr0, lr1 * lr1, lx * lx + ly * ly);
        }
        if (d < 0.02f) continue;
        {
            int rc = (int)((hw + cell) / cell) + 1;
            if (rc > 6) rc = 6;
            for (int dy = -rc; dy <= rc; dy++) for (int dx = -rc; dx <= rc; dx++) {
                int xx = x + dx, yy = y + dy, j;
                float r, w;
                int32_t v;
                if ((unsigned)xx >= (unsigned)n || (unsigned)yy >= (unsigned)n) continue;
                j = yy * n + xx;
                r = sqrtf((float)(dx * dx + dy * dy)) * cell;
                w = 1.f - smoothstep(0.5f * hw, hw + 0.9f * cell, r);
                v = (int32_t)(d * w * 65536.f);
                if (v > cut[j]) cut[j] = v;
            }
        }
    }
    for (int i = 0; i < nn; i++) if (cut[i] > 0) {
        float lx = ((float)(i % n) + .5f) * cell - half - p->lake_x_m, ly = ((float)(i / n) + .5f) * cell - half - p->lake_y_m;
        float fade = smoothstep(lr0 * lr0, lr1 * lr1, lx * lx + ly * ly);   /* banks too: the bowl and its rim stay as they were */
        float h = t->height[i], hn = h - (float)cut[i] * (1.f / 65536.f) * fade, keep = minf(h, 0.3f);
        t->height[i] = maxf(hn, keep);
    }
}

/* After the final routing: classes, and the water the world sees (ws->scratch is the water level map). */
static void river_water(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    int n = p->n, nn = n * n;
    float cell = p->size_m / (float)n, cell2 = cell * cell;
    if (t->river) memset(t->river, 0, (size_t)nn);
    for (int i = 0; i < nn; i++) {
        int c = river_class(t->flow[i] * (float)nn * cell2);
        float h = t->height[i], wd;
        /* A trail that crosses a deep river fords it: inside the corridor core the class is shallow. */
        if (c == CP_TERR_RIVER_DEEP && t->material[i] == 1) c = CP_TERR_RIVER_SHALLOW;
        if (c == CP_TERR_RIVER_NONE || !(h > 0.5f) || ws->scratch[i] - h > 0.3f) continue;
        wd = c == CP_TERR_RIVER_DEEP ? 1.2f : c == CP_TERR_RIVER_SHALLOW ? 0.6f : 0.35f;
        if (t->river) {
            int d = 0, r = ws->recv[i];
            if (r >= 0) for (d = 0; d < 8; d++) if (r == i + DY[d] * n + DX[d]) break;
            t->river[i] = (uint8_t)(c | ((d < 8 && r >= 0 ? d + 1 : 0) << 2));   /* bits 2..5: receiver direction + 1, 0 = outlet */
        }
        ws->scratch[i] = h + wd;
    }
    /* Fords: where a trail corridor meets standing or deep water (pits in the bed, ponds at a sill) its bed rises to a
     * shoal 0.55 m below the surface, so the crossing is wet but always wadeable. */
    for (int i = 0; i < nn; i++)
        if (t->material[i] == 1 && t->height[i] > .5f && ws->scratch[i] - t->height[i] > .6f)
            t->height[i] = ws->scratch[i] - .55f;
}

/* ---- trails (route certification) ----------------------------------------------------------------------- */

static float trail_grad(const float *h, int n, int x, int y, float cell)
{
    int x0 = x > 0 ? x - 1 : x, x1 = x < n - 1 ? x + 1 : x, y0 = y > 0 ? y - 1 : y, y1 = y < n - 1 ? y + 1 : y;
    float gx = (h[y * n + x1] - h[y * n + x0]) / ((float)(x1 - x0) * cell);
    float gy = (h[y1 * n + x] - h[y0 * n + x]) / ((float)(y1 - y0) * cell);
    return sqrtf(gx * gx + gy * gy);
}

/* Per-cell cost of walking (integer, 10 = flat dry land): steep ground is dear, deep river and the protected lake bowl
 * are nearly forbidden, rivers are dear along their length (a crossing is fine) and the sea is closed. */
static void trail_costs(const CpTerrainParams *p, const CpTerrain *t, int32_t *cost)
{
    int n = p->n, nn = n * n;
    float cell = p->size_m / (float)n, half = p->size_m * .5f, cell2 = cell * cell, lr = p->lake_radius_m * 1.25f;
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        int i = y * n + x, c = 10;
        float q = trail_grad(t->height, n, x, y, cell) - .35f, area = t->flow[i] * (float)nn * cell2;
        if (q > 0.f) c += (int)(q * q * 400.f + q * 40.f);
        if (area >= RIVER_DEEP_M2) c += 4000;
        else if (area >= RIVER_SHALLOW_M2) c += 200;
        else if (area >= RIVER_STREAM_M2) c += 20;
        if (!(t->height[i] > .5f)) c += 100000;
        /* keep clear of real rivers: the corridor around a trail cannot be graded next to a channel it must not touch */
        if (x >= 2 && y >= 2 && x < n - 2 && y < n - 2) {
            int near_river = 0;
            for (int dy = -2; dy <= 2 && !near_river; dy++) for (int dx = -2; dx <= 2; dx++)
                if (t->flow[i + dy * n + dx] * (float)nn * cell2 >= RIVER_SHALLOW_M2) { near_river = 1; break; }
            if (near_river) c += 120;
        }
        {
            float lx = ((float)x + .5f) * cell - half - p->lake_x_m, ly = ((float)y + .5f) * cell - half - p->lake_y_m;
            if (lx * lx + ly * ly < lr * lr) c += 4000;
        }
        cost[i] = c;
    }
}

static int trail_step(const int32_t *cost, int a, int b, int diag)
{
    int base = (cost[a] + cost[b]) / 2;
    return diag ? base * 7 / 5 : base;
}

/* Cost-to-network by raster sweeps (no heap: the workspace is all there is). dist is 0 on sources, TR_INF elsewhere. */
static void trail_sweep_box(int n, const int32_t *cost, int32_t *dist, int bx0, int by0, int bx1, int by1)
{
    for (int pass = 0; pass < 600; pass++) {
        int changed = 0;
        for (int s = 0; s < 4; s++) {
            int y0 = s & 1 ? by1 : by0, y1 = s & 1 ? by0 - 1 : by1 + 1, dy = s & 1 ? -1 : 1;
            int x0 = s & 2 ? bx1 : bx0, x1 = s & 2 ? bx0 - 1 : bx1 + 1, dx = s & 2 ? -1 : 1;
            for (int y = y0; y != y1; y += dy) for (int x = x0; x != x1; x += dx) {
                int i = y * n + x, best = dist[i];
                if (cost[i] >= 100000) continue;   /* the sea is a wall */
                static const int NB[4][3] = { {-1, 0, 0}, {-1, -1, 1}, {0, -1, 0}, {1, -1, 1} };
                for (int k = 0; k < 4; k++) {
                    int nx = x + NB[k][0] * dx, ny = y + NB[k][1] * dy, j;
                    if (nx < bx0 || nx > bx1 || ny < by0 || ny > by1) continue;
                    j = ny * n + nx;
                    if (dist[j] >= TR_INF) continue;
                    int v = dist[j] + trail_step(cost, i, j, NB[k][2]);
                    if (v < best) best = v;
                }
                if (best < dist[i]) { dist[i] = best; changed = 1; }
            }
        }
        if (!changed) break;
    }
}
static void trail_sweep(int n, const int32_t *cost, int32_t *dist) { trail_sweep_box(n, cost, dist, 0, 0, n - 1, n - 1); }

/* Follows strictly falling distance from a cell to a source. Writes cells to out (when not NULL), returns the count
 * (-1 when it cannot reach a source) and the source cell. */
static int trail_walk(int n, const int32_t *cost, const int32_t *dist, int from, int32_t *out, int cap, int *src)
{
    int k = 0, cur = from, limit = n * n;
    if (dist[from] >= TR_INF) return -1;
    for (;;) {
        if (out && k < cap) out[k] = cur;
        k++;
        if (dist[cur] == 0 || k > limit) break;
        int x = cur % n, y = cur / n, best = -1, bv = TR_INF;
        for (int d = 0; d < 8; d++) {
            int nx = x + DX[d], ny = y + DY[d], j;
            if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
            j = ny * n + nx;
            if (dist[j] >= dist[cur]) continue;
            int v = dist[j] + trail_step(cost, cur, j, d & 1);
            if (v < bv) { bv = v; best = j; }
        }
        if (best < 0) return -1;
        cur = best;
    }
    if (src) *src = cur;
    return dist[cur] == 0 && k <= limit && (!out || k <= cap) ? k : -1;
}

#define TRAIL_HALF_M  11.f
#define TRAIL_BLEND_M 12.f

/* A cell on or beside a shallow-or-deeper river cell: its heights keep the channel and banks the river carved, so the trail
 * never dams, re-routes or ponds a river. */
static int trail_wet(const CpTerrain *t, int n, int i, float cell2)
{
    int x = i % n, y = i / n, nn = n * n;
    for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
        int xx = x + dx, yy = y + dy;
        if ((unsigned)xx >= (unsigned)n || (unsigned)yy >= (unsigned)n) continue;
        if (t->flow[yy * n + xx] * (float)nn * cell2 >= RIVER_SHALLOW_M2) return 1;
    }
    return 0;
}

/* Grades the ground along a path: a profile as close to the old heights as the slope limit allows, anchored at both
 * ends and wherever the path crosses a river (so channels keep their beds), stamped as a flat-bottomed corridor that
 * blends into the old ground. The corridor core joins the network mask. */
static void trail_carve(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws, const int32_t *path, int count,
                        int pin, float fx, float fy)
{
    int n = p->n, nn = n * n;
    float cell = p->size_m / (float)n, half = p->size_m * .5f, cell2 = cell * cell, lr = p->lake_radius_m * 1.25f;
    float *hp = ws->scratch, *qx, *qy;
    int32_t *stamp = ws->ups;
    if (count < 2 || (size_t)count * 3 > (size_t)nn) return;
    qx = hp + count; qy = qx + count;
    for (int k = 0; k < count; k++) {
        hp[k] = t->height[path[k]];
        qx[k] = (float)(path[k] % n) * cell; qy[k] = (float)(path[k] / n) * cell;
    }
    /* the centreline: the 8-connected zigzag smoothed, ends fixed, so slopes along it are not inflated by the grid */
    for (int pass = 0; pass < 8; pass++)
        for (int k = 1; k < count - 1; k++) {
            qx[k] = .25f * qx[k - 1] + .5f * qx[k] + .25f * qx[k + 1];
            qy[k] = .25f * qy[k - 1] + .5f * qy[k] + .25f * qy[k + 1];
        }
#define TR_ANCHOR(k) ((k) == 0 || (k) == count - 1 || trail_wet(t, n, path[k], cell2))
#define TR_D(k, j) sqrtf((qx[k] - qx[j]) * (qx[k] - qx[j]) + (qy[k] - qy[j]) * (qy[k] - qy[j]))
    for (int pass = 0; pass < 120; pass++) {
        float change = 0.f;
        for (int k = 1; k < count; k++) {
            if (TR_ANCHOR(k)) continue;
            float lim = TRAIL_SLOPE * TR_D(k, k - 1), v = clampf(hp[k], hp[k - 1] - lim, hp[k - 1] + lim);
            change += absf(v - hp[k]); hp[k] = v;
        }
        for (int k = count - 2; k >= 0; k--) {
            if (TR_ANCHOR(k)) continue;
            float lim = TRAIL_SLOPE * TR_D(k, k + 1), v = clampf(hp[k], hp[k + 1] - lim, hp[k + 1] + lim);
            change += absf(v - hp[k]); hp[k] = v;
        }
        if (change < .01f) break;
    }
    for (int pass = 0; pass < 3; pass++)
        for (int k = 1; k < count - 1; k++) if (!TR_ANCHOR(k)) hp[k] = .25f * hp[k - 1] + .5f * hp[k] + .25f * hp[k + 1];
    for (int k = 0; k < count; k++) if (hp[k] < .6f && t->height[path[k]] > .5f) hp[k] = .6f;
    memset(stamp, 0, (size_t)nn * sizeof *stamp);
    {
        /* Each cell takes the profile height at its nearest point on the polyline (linear along a segment), so the
         * corridor is a continuous ramp, not a staircase of per-cell plateaus. */
        float R = TRAIL_HALF_M + TRAIL_BLEND_M;
        int rc = (int)(R / cell) + 2;
        for (int k = 0; k + 1 < count; k++) {
            float sx = qx[k + 1] - qx[k], sy = qy[k + 1] - qy[k], sl = sx * sx + sy * sy;
            int x0 = (int)(fminf(qx[k], qx[k + 1]) / cell) - rc, x1 = (int)(fmaxf(qx[k], qx[k + 1]) / cell) + rc;
            int y0 = (int)(fminf(qy[k], qy[k + 1]) / cell) - rc, y1 = (int)(fmaxf(qy[k], qy[k + 1]) / cell) + rc;
            for (int yy = y0; yy <= y1; yy++) for (int xx = x0; xx <= x1; xx++) {
                float px, py, u, r, hv;
                int j, wb, dq, key;
                if ((unsigned)xx >= (unsigned)n || (unsigned)yy >= (unsigned)n) continue;
                px = (float)xx * cell - qx[k]; py = (float)yy * cell - qy[k];
                u = sl > 0.f ? clampf((px * sx + py * sy) / sl, 0.f, 1.f) : 0.f;
                r = sqrtf((px - u * sx) * (px - u * sx) + (py - u * sy) * (py - u * sy));
                if (r >= R) continue;
                j = yy * n + xx;
                wb = (int)((1.f - smoothstep(TRAIL_HALF_M, R, r)) * 255.f + .5f);
                dq = (int)(r / R * 1023.f);
                key = (wb << 10) | (1023 - dq);
                if (key > (stamp[j] & 0x3FFFF)) {
                    hv = hp[k] + (hp[k + 1] - hp[k]) * u;
                    stamp[j] = ((int)(hv * 8.f + .5f) << 18) | key;
                }
            }
        }
    }
    for (int i = 0; i < nn; i++) {
        int wb = (stamp[i] >> 10) & 255;
        float old = t->height[i], target = (float)(stamp[i] >> 18) * (1.f / 8.f), w = (float)wb * (1.f / 255.f);
        if (!wb || !(old > .5f)) continue;
        if (wb == 255) t->material[i] = 1;
        if (trail_wet(t, n, i, cell2)) continue;
        if (pin >= 0) {
            /* the rock behind an entrance stays: only ground in front of its plane is graded */
            float dx = (float)(i % n - pin % n) * cell, dy = (float)(i / n - pin / n) * cell;
            if (dx * fx + dy * fy < .5f * cell) continue;
        }
        {
            float lx = ((float)(i % n) + .5f) * cell - half - p->lake_x_m, ly = ((float)(i / n) + .5f) * cell - half - p->lake_y_m;
            if (lx * lx + ly * ly < lr * lr) continue;
        }
        t->height[i] = old + (target - old) * w;
    }
#undef TR_ANCHOR
#undef TR_D
}

/* The river gap, guaranteed on foot. The gap is where the range is lowest: the lowest dry cell on the circle of radius
 * 809 m around the start (the long-published checkpoint distance; (800,120) on seeds 1 and 42, elsewhere wherever the
 * warped range actually opens). A graded trail joins the start valley to it and continues to the nearest river mouth. */
static void gap_trail(const CpTerrainParams *p, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    int n = p->n, nn = n * n;
    float cell = p->size_m / (float)n, half = p->size_m * .5f, cell2 = cell * cell;
    BaseCtx c; base_ctx(p, &c);
    int32_t *cost = ws->queue, *dist = ws->ups, *path = ws->recv;
    float rad = minf(809.f, .926f * c.crest0);
    int ix = (int)((0.f + half) / cell), nest = ix * n + ix, w1 = -1, mouth = -1;
    memset(t->material, 0, (size_t)nn);
    {
        /* 720 steps of 0.5 degrees by rotation: no trig, identical on every platform */
        float ux = 1.f, uy = 0.f, best = 1.0e9f;
        const float cs = 0.99996192306f, sn = 0.00872653550f;
        for (int a = 0; a < 720; a++) {
            int x = (int)((ux * rad + half) / cell), y = (int)((uy * rad + half) / cell);
            if (x > 1 && y > 1 && x < n - 2 && y < n - 2) {
                int i = y * n + x;
                float h = t->height[i], sc = h;
                /* the checkpoint is dry land beside the river, not its bed */
                for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++)
                    if (t->flow[i + dy * n + dx] * (float)nn * cell2 >= RIVER_STREAM_M2) sc += 6.f;
                if (h > 1.2f && sc < best) { best = sc; w1 = i; }
            }
            { float tx = ux * cs - uy * sn; uy = ux * sn + uy * cs; ux = tx; }
        }
    }
    if (w1 < 0) return;
    trail_costs(p, t, cost);
    {
        /* one path, carved once: mouth -> checkpoint -> start. The two legs are traced on the uncarved costs. */
        int len2 = 0, len1 = 0;
        for (int i = 0; i < nn; i++) dist[i] = TR_INF;
        dist[w1] = 0;
        trail_sweep(n, cost, dist);
        {
            int32_t bd = TR_INF;
            for (int i = 0; i < nn; i++)
                if (t->height[i] > .8f && t->height[i] <= 2.f && dist[i] < bd) { bd = dist[i]; mouth = i; }
        }
        if (mouth >= 0) len2 = trail_walk(n, cost, dist, mouth, path, nn, NULL);
        if (len2 < 1) { len2 = 1; path[0] = w1; }
        for (int i = 0; i < nn; i++) dist[i] = TR_INF;
        dist[nest] = 0;
        trail_sweep(n, cost, dist);
        len1 = trail_walk(n, cost, dist, w1, path + len2 - 1, nn - len2 + 1, NULL);
        if (len1 > 0 && len2 + len1 - 1 > 1) trail_carve(p, t, ws, path, len2 + len1 - 1, -1, 0.f, 0.f);
    }
}

/* ---- island descs: authored trails and the protect mask (island.h, part I of the realism plan) --------------------------- */

#define DESC_TRAIL_CORRIDOR_M 40.f

/* Distance from a cell centre (cell units) to the hint segment, squared, in metres squared. */
static float hint_dist2(float px, float py, float ax, float ay, float bx, float by)
{
    float sx = bx - ax, sy = by - ay, l2 = sx * sx + sy * sy, u = 0.f, dx, dy;
    if (l2 > 0.f) u = clampf(((px - ax) * sx + (py - ay) * sy) / l2, 0.f, 1.f);
    dx = px - (ax + u * sx); dy = py - (ay + u * sy);
    return dx * dx + dy * dy;
}

/* Walls (cost + 200000) every cell of the box farther than the corridor from the segment, or takes them off again. */
static void corridor_walls(int n, int32_t *cost, int bx0, int by0, int bx1, int by1, float cell, float half,
                           float ax, float ay, float bx, float by, int on)
{
    const float lim2 = DESC_TRAIL_CORRIDOR_M * DESC_TRAIL_CORRIDOR_M;
    for (int y = by0; y <= by1; y++) for (int x = bx0; x <= bx1; x++) {
        float px = ((float)x + 0.5f) * cell - half, py = ((float)y + 0.5f) * cell - half;
        if (hint_dist2(px, py, ax, ay, bx, by) > lim2) cost[y * n + x] += on ? 200000 : -200000;
    }
}

/* The authored trails of a desc: for each trail of kind game_trail or path, a route through its waypoints that stays within
 * DESC_TRAIL_CORRIDOR_M of the hint polyline, found with the same costs as the river-gap trail (steep ground dear, deep
 * river and sea closed), then graded to TRAIL_SLOPE (16.7 degrees, far below the 51.6 degree grip rule, A66) by trail_carve.
 * A trail whose waypoints cannot be joined inside the corridor is skipped whole. Returns the number carved. */
static int desc_trails(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *t, const CpTerrainWorkspace *ws)
{
    int n = p->n, nn = n * n, done = 0, have_costs = 0;
    float cell = p->size_m / (float)n, half = p->size_m * .5f;
    int32_t *cost = ws->queue, *dist = ws->ups, *path = ws->recv;
    const int rc = (int)(DESC_TRAIL_CORRIDOR_M / cell) + 3, snap = (int)(20.f / cell) < 1 ? 1 : (int)(20.f / cell);   /* a waypoint snaps to dry ground within 20 m, inside the corridor */
    if (!trail_ok(p)) return 0;
    for (int ti = 0; ti < d->ntrail; ti++) {
        const CpIslandTrail *tr = &d->trail[ti];
        int wp[CP_ISL_MAX_TRAIL_PT], nw = 0, total = 0, ok = 1;
        float wxm[CP_ISL_MAX_TRAIL_PT], wym[CP_ISL_MAX_TRAIL_PT];
        if (strcmp(tr->kind, "game_trail") != 0 && strcmp(tr->kind, "path") != 0) continue;
        if (!have_costs) { trail_costs(p, t, cost); have_costs = 1; }
        for (int k = 0; k < tr->npts && nw < CP_ISL_MAX_TRAIL_PT; k++) {
            float wx = ((float)d->trail_pt[tr->pt0 + k][0] / 10.f) * d->scale, wy = ((float)d->trail_pt[tr->pt0 + k][1] / 10.f) * d->scale;
            int cx = (int)((wx + half) / cell), cy = (int)((wy + half) / cell), best = -1, bd = 0x7fffffff;
            for (int dy = -snap; dy <= snap; dy++) for (int dx = -snap; dx <= snap; dx++) {
                int x = cx + dx, y = cy + dy;
                if (x < 1 || y < 1 || x >= n - 1 || y >= n - 1) continue;
                if (cost[y * n + x] >= 100000 || (float)(dx * dx + dy * dy) * cell * cell > 400.f) continue;
                if (dx * dx + dy * dy < bd) { bd = dx * dx + dy * dy; best = y * n + x; }
            }
            if (best < 0) { ok = 0; break; }
            wp[nw] = best; wxm[nw] = wx; wym[nw] = wy; nw++;
        }
        if (!ok || nw < 2) continue;
        for (int leg = 0; leg + 1 < nw && ok; leg++) {
            int a = wp[leg], b = wp[leg + 1], len;
            int bx0 = (a % n < b % n ? a % n : b % n) - rc, bx1 = (a % n > b % n ? a % n : b % n) + rc;
            int by0 = (a / n < b / n ? a / n : b / n) - rc, by1 = (a / n > b / n ? a / n : b / n) + rc;
            if (bx0 < 0) bx0 = 0;
            if (by0 < 0) by0 = 0;
            if (bx1 > n - 1) bx1 = n - 1;
            if (by1 > n - 1) by1 = n - 1;
            /* the corridor follows the hint between the two waypoints, widened by the snap distance so a snapped end stays inside */
            corridor_walls(n, cost, bx0, by0, bx1, by1, cell, half, wxm[leg], wym[leg], wxm[leg + 1], wym[leg + 1], 1);
            for (int y = by0; y <= by1; y++) for (int x = bx0; x <= bx1; x++) dist[y * n + x] = TR_INF;
            dist[b] = 0;
            trail_sweep_box(n, cost, dist, bx0, by0, bx1, by1);
            len = trail_walk(n, cost, dist, a, path + (total ? total - 1 : 0), nn - (total ? total - 1 : 0), NULL);
            corridor_walls(n, cost, bx0, by0, bx1, by1, cell, half, wxm[leg], wym[leg], wxm[leg + 1], wym[leg + 1], 0);
            if (len < 1) ok = 0; else total += total ? len - 1 : len;
        }
        if (ok && total > 1) { trail_carve(p, t, ws, path, total, -1, 0.f, 0.f); done++; }
    }
    return done;
}

/* The PROTECT mask: every cell it marks is held within its band of the authored (pre-erosion) height. */
static void apply_protect(const CpTerrainParams *p, const CpIslandDesc *d, float *height)
{
    int n = p->n;
    float cell = p->size_m / (float)n, half = p->size_m * .5f;
    if (d->nmask <= CP_ISL_MASK_PROTECT) return;
    for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
        float wx = ((float)x + 0.5f) * cell - half, wy = ((float)y + 0.5f) * cell - half, v = cp_island_mask(d, CP_ISL_MASK_PROTECT, wx, wy), w, band, a, h;
        if (!(v > 128.f)) continue;
        w = (v - 128.f) / 127.f;
        if (w > 1.f) w = 1.f;
        if (w < 1.f / 64.f) continue;
        band = 0.5f / w;
        a = island_height(p, d, wx, wy);
        h = height[y * n + x];
        height[y * n + x] = clampf(h, a - band, a + band);
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
    if (!t || !t->height || !t->flow || !t->sediment || !t->material || t->cave_count<0 || t->cave_count>CP_TERRAIN_CAVES_MAX || t->n < 1 || t->n > CP_TERRAIN_N_MAX) return 0;
    nn = t->n * t->n;
    fnv_u32(&h, (uint32_t)CP_TERRAIN_VERSION);
    if (t->island_hash) { fnv_u32(&h, (uint32_t)t->island_hash); fnv_u32(&h, (uint32_t)(t->island_hash >> 32)); }
    fnv_u32(&h, (uint32_t)t->n);
    fnv_f(&h, t->size_m);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->height[i]);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->flow[i]);
    for (int i = 0; i < nn; i++) fnv_f(&h, t->sediment[i]);
    for (int i = 0; i < nn; i++) fnv_byte(&h, t->material[i]);
    if (t->river) for (int i = 0; i < nn; i++) fnv_byte(&h, t->river[i]);
    fnv_f(&h,t->volcano_x_m);fnv_f(&h,t->volcano_y_m);
    fnv_f(&h,t->volcano_radius_m);fnv_f(&h,t->crater_radius_m);
    fnv_u32(&h,(uint32_t)t->cave_count);
    for(int i=0;i<t->cave_count;i++) {
        const CpTerrainCave *v=&t->caves[i];
        fnv_f(&h,v->x_m);fnv_f(&h,v->y_m);fnv_f(&h,v->z_m);
        fnv_f(&h,v->facing_x);fnv_f(&h,v->facing_y);
        fnv_f(&h,v->width_m);fnv_f(&h,v->height_m);fnv_f(&h,v->depth_m);
        fnv_u32(&h,v->waterfall);
    }
    return h;
}

uint64_t cp_terrain_climate_hash(const CpTerrain *t)
{
    uint64_t h = 14695981039346656037ull;
    size_t cc, nn;
    if (!t || t->climate_n <= 0 || !t->climate || !t->biome || !t->veg) return 0;
    cc = (size_t)t->climate_n * (size_t)t->climate_n;
    nn = (size_t)t->n * (size_t)t->n;
    fnv_u32(&h, (uint32_t)CP_CLIMATE_VERSION);
    fnv_u32(&h, (uint32_t)t->climate_n);
    for (size_t i = 0; i < 4 * cc; i++) fnv_byte(&h, t->climate[i]);
    for (size_t i = 0; i < nn; i++) fnv_byte(&h, t->biome[i]);
    for (size_t i = 0; i < 4 * nn; i++) fnv_byte(&h, t->veg[i]);
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
static int generate_impl(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                         const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user)
{
    int rc = cp_terrain_validate(p);
    int n, n1, n2, use1, use2, nn;
    const float *prev_delta = NULL, *prev_sed = NULL;
    int prev_n = 0;
    Shape shape, settle;
    if (rc != CP_TERR_OK) return rc;
    if (!out || !out->height || !out->flow || !out->sediment || !out->material) return CP_TERR_ERR_BUFFER;
    if (!ws || !ws->scratch || !ws->recv || !ws->ups || !ws->queue) return CP_TERR_ERR_BUFFER;

    n = p->n;
    nn = n * n;
    n1 = n / 2;
    n2 = n / 4;
    use1 = p->stream_iters > 0 && n1 >= 16;
    use2 = p->stream_iters > 0 && n2 >= 16;
    out->n = n;
    out->size_m = p->size_m;
    out->island_hash = d ? cp_island_hash(d) : 0;
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
        fill_base(p, d, n2, base, &shape);
        for (int i = 0; i < a; i++) { h[i] = base[i]; sd[i] = 0.f; }
        stream_power(p, d, n2, h, sd, fl, lv, ws, level_iters(p, 2), &shape);
        for (int i = 0; i < a; i++) base[i] = h[i] - base[i];
        prev_delta = base;
        prev_sed = sd;
        prev_n = n2;
    }
    if (use1) {
        int b = n1 * n1;
        float *h = out->sediment, *fl = h + b, *lv = fl + b, *sd = lv + b, *base = ws->scratch;
        fill_base(p, d, n1, base, &shape);
        for (int j = 0; j < n1; j++) for (int i = 0; i < n1; i++) {
            int k = j * n1 + i;
            h[k] = base[k] + (prev_n ? upsample(prev_delta, prev_n, n1, i, j) : 0.f);
            sd[k] = prev_n ? upsample(prev_sed, prev_n, n1, i, j) : 0.f;
        }
        stream_power(p, d, n1, h, sd, fl, lv, ws, level_iters(p, 1), &shape);
        for (int i = 0; i < b; i++) {
            out->flow[i] = h[i] - base[i];
            out->flow[b + i] = sd[i];
        }
        prev_delta = out->flow;
        prev_sed = out->flow + b;
        prev_n = n1;
    }
    fill_base(p, d, n, out->height, &shape);
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
        hydraulic(p, d, out->height, out->sediment, ws->scratch, fn, user);
    stream_power(p, d, n, out->height, out->sediment, out->flow, ws->scratch, ws,
                 level_iters(p, 0), &settle);
    thermal(p, out->height, out->sediment, &settle);
    for(int i=0;i<nn;i++)out->height[i]=gentle_height(p,out->height[i]);
    cliff_bands(p, out->height, ws->scratch);
    if (d) apply_protect(p, d, out->height);
    flow_accum(out->height, n, p->size_m, p->seed, out->flow, ws->scratch,
               ws->recv, ws->ups, ws->queue, fn, user);
    if (p->rivers > 0.f && n >= 64) {
        carve_rivers(p, out, ws);
        if (d) apply_protect(p, d, out->height);   /* a river does not cut an authored surface */
        flow_accum(out->height, n, p->size_m, p->seed, out->flow, ws->scratch,
                   ws->recv, ws->ups, ws->queue, NULL, NULL);
    }
    memset(out->material, 0, (size_t)nn);
    if (p->rivers > 0.f && trail_ok(p) && !d && !(p->layout >= 1.f)) {
        gap_trail(p, out, ws);
        flow_accum(out->height, n, p->size_m, p->seed, out->flow, ws->scratch,
                   ws->recv, ws->ups, ws->queue, NULL, NULL);
    }
    if (d && d->ntrail > 0 && desc_trails(p, d, out, ws)) {
        apply_protect(p, d, out->height);
        flow_accum(out->height, n, p->size_m, p->seed, out->flow, ws->scratch,
                   ws->recv, ws->ups, ws->queue, NULL, NULL);
    }
    cave_entrances(p,out,ws);
    if(out->cave_count) flow_accum(out->height,n,p->size_m,p->seed,out->flow,ws->scratch,
                                  ws->recv,ws->ups,ws->queue,NULL,NULL);
    /* river_water first: it reads the corridor mask the trails left in the material bytes, which material_map then overwrites */
    if (p->rivers > 0.f && n >= 64) river_water(p, out, ws);
    else if (out->river) memset(out->river, 0, (size_t)nn);
    /* trails and fords may have set the floor of an entrance after it was recorded; the record is always the final floor */
    for (int c = 0; c < out->cave_count; c++) {
        CpTerrainCave *v = &out->caves[c];
        int cx = (int)((v->x_m + p->size_m * .5f) / (p->size_m / (float)n)), cy = (int)((v->y_m + p->size_m * .5f) / (p->size_m / (float)n));
        if (cx >= 0 && cy >= 0 && cx < n && cy < n) v->z_m = out->height[cy * n + cx];
    }
    out->climate_n = 0;
    if (d && n >= 64 && out->climate && out->biome && out->veg && ws->climate_work) {
        rc = cp_terrain_climate(p, d, out, ws);
        if (rc != CP_TERR_OK) return rc;
    }
    material_map(p,out);   /* M2 leaves the snow material on its altitude rule (the climate maps are an add-on; G1 switches it to biome == snow) */
    notify(fn, user, CP_TERR_STAGE_DONE, 1, 1);
    return CP_TERR_OK;
}

int cp_terrain_generate(const CpTerrainParams *p, CpTerrain *out,
                        const CpTerrainWorkspace *ws,
                        CpTerrainProgressFn fn, void *user)
{
    return generate_impl(p, NULL, out, ws, fn, user);
}

int cp_terrain_generate_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                             const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user)
{
    CpTerrainParams q;
    if (!p || !d) return CP_TERR_ERR_NULL;
    if (d->neval < 0 || d->neval > CP_ISL_MAX_EVAL || !(d->scale > 0.f)) return CP_TERR_ERR_ISL_FIELD;   /* not prepared */
    q = *p;
    cp_island_apply(d, &q);
    return generate_impl(&q, d, out, ws, fn, user);
}

/* The shape of a desc without erosion: the same pipeline as cp_terrain_generate_desc with droplets, thermal and stream passes
 * forced to 0 (also over the desc's own recommended erosion). Cheap enough to run while an author drags a point. */
int cp_terrain_shape_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                          const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user)
{
    CpTerrainParams q;
    if (!p || !d) return CP_TERR_ERR_NULL;
    if (d->neval < 0 || d->neval > CP_ISL_MAX_EVAL || !(d->scale > 0.f)) return CP_TERR_ERR_ISL_FIELD;   /* not prepared */
    q = *p;
    cp_island_apply(d, &q);
    q.droplets = 0; q.thermal_iters = 0; q.stream_iters = 0;
    return generate_impl(&q, d, out, ws, fn, user);
}
