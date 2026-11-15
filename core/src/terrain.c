#include "cpore/terrain.h"
#include "cpore/cpore.h"

#include <math.h>
#include <string.h>

/* Mountains are a mask plus erosion, not a height painted by hand (W11).
 * The mask places the walkable valley, the lake, the ring and the pass.
 * Droplets then cut the gullies; thermal passes pull cliffs back to talus;
 * D8 flow is what materials and the drainage checks read.
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

/* Ridged multifractal (Musgrave): fold the gradient noise, square it, and
 * feed the previous octave's sharpness forward as a weight so ridges stay
 * sharp instead of blurring back into fbm. */
static float ridged(float x, float y, int oct, uint32_t seed)
{
    float sum = 0.f, amp = 1.f, freq = 1.f, weight = 1.f, norm = 0.f;
    for (int o = 0; o < oct; o++) {
        float n = noise2(x * freq, y * freq, octave_seed(seed, o, 0xB5297A4Du));
        float s;
        n *= 1.7f;
        n = clampf(n, -1.f, 1.f);
        s = 1.f - absf(n);
        s = s * s * weight;
        weight = clampf(s * 2.f, 0.f, 1.f);
        sum += s * amp;
        norm += amp;
        amp *= 0.5f;
        freq *= 2.f;
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
    /* About one droplet per 16 cells at 1024². Fixed count, not a time budget. */
    p->droplets = 70000;
    p->lifetime = 32;
    p->radius = 4;
    p->thermal_iters = 5;
    p->size_m = 2000.f;
    p->frequency = 1.7f / 2000.f;
    p->warp_m = 280.f;
    p->ridge_weight = 0.72f;
    p->valley_radius_m = 300.f;
    p->valley_floor_m = 42.f;
    p->ring_inner_m = 430.f;
    p->ring_outer_m = 820.f;
    p->ring_height_m = 540.f;
    p->pass_x = 1.f;
    p->pass_y = 0.15f;
    p->pass_half_m = 120.f;
    p->pass_height_m = 118.f;
    p->lake_x_m = -150.f;
    p->lake_y_m = 70.f;
    p->lake_radius_m = 68.f;
    p->lake_depth_m = 34.f;
    p->inertia = 0.40f;
    p->capacity = 4.f;
    p->deposition = 0.28f;
    p->erosion = 0.32f;
    p->evaporation = 0.015f;
    p->gravity = 4.f;
    p->min_slope = 0.012f;
    p->talus_deg = 34.f;
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
    return CP_TERR_OK;
}

static void notify(CpTerrainProgressFn fn, void *user, int stage, int done, int total)
{
    if (fn) fn(stage, done, total, user);
}

/* ---- base ---------------------------------------------------------------- */

static void pass_basis(const CpTerrainParams *p, float *px, float *py)
{
    float len = sqrtf(p->pass_x * p->pass_x + p->pass_y * p->pass_y);
    if (len < 1.0e-6f) { *px = 1.f; *py = 0.f; }
    else { *px = p->pass_x / len; *py = p->pass_y / len; }
}

static void fill_base(const CpTerrainParams *p, float *height, CpTerrainProgressFn fn, void *user)
{
    const int n = p->n;
    const float cell = p->size_m / (float)n;
    const float half = p->size_m * 0.5f;
    float px, py;
    int woct = p->octaves > 3 ? 3 : p->octaves;
    int row_step = n > 32 ? n / 32 : 1;
    pass_basis(p, &px, &py);

    for (int j = 0; j < n; j++) {
        for (int i = 0; i < n; i++) {
            float x = ((float)i + 0.5f) * cell - half;
            float y = ((float)j + 0.5f) * cell - half;
            float r = sqrtf(x * x + y * y);
            float along = x * px + y * py;
            float across = absf(x * (-py) + y * px);
            float valley = 1.f - smoothstep(p->valley_radius_m * 0.45f, p->valley_radius_m, r);
            /* Irregular, broad foothills: the ring locates mountains without
             * imposing a circular cliff. Keep the guaranteed floor unwarped. */
            float mask_noise = noise2((x+8192.f)*p->frequency*.7f,
                                       (y+8192.f)*p->frequency*.7f, p->seed^0x19B39A21u);
            float mountain_r = r + mask_noise * 180.f;
            float ring_in = smoothstep(p->valley_radius_m*.75f, p->ring_inner_m*1.35f, mountain_r);
            float ring_out = 1.f - smoothstep(p->ring_outer_m*.85f, p->ring_outer_m*1.12f, mountain_r);
            float ring = ring_in * ring_out;
            /* Corridor, not a cosine lobe: the notch has to cross the whole
             * ring thickness or the outer shoulder stays a wall. */
            float corridor = 1.f - smoothstep(p->pass_half_m * 0.22f, p->pass_half_m, across);
            float pass_side = smoothstep(0.f, p->ring_inner_m * 0.28f, along);
            float pass_zone = smoothstep(p->valley_radius_m * 0.8f, p->ring_inner_m, r);
            pass_zone *= 1.f - smoothstep(p->ring_outer_m, p->ring_outer_m * 1.25f, r);
            float cut = clampf(corridor * pass_side * pass_zone, 0.f, 1.f);
            float lx = x - p->lake_x_m;
            float ly = y - p->lake_y_m;
            float lr = sqrtf(lx * lx + ly * ly);
            float lake = 1.f - smoothstep(p->lake_radius_m * 0.2f, p->lake_radius_m, lr);

            float u = clampf(r / p->valley_radius_m, 0.f, 1.f);
            u *= u;
            /* Gentle parabolic bowl: at the valley rim the slope is
             * 2*12/radius, about 4.6 degrees for the default 300 m. */
            /* A low plinth, not a smooth cone. Peak height comes from the
             * ridged noise below, so valleys can run across the slope and
             * actually join instead of falling straight downhill. */
            float macro = p->valley_floor_m + 12.f * u;
            macro += smoothstep(p->valley_radius_m, p->ring_inner_m*1.3f, r) * 45.f;
            macro += ring * p->ring_height_m * 0.16f;
            {
                float outside = smoothstep(p->ring_outer_m * 0.9f, p->ring_outer_m * 1.2f, r);
                macro = macro * (1.f - outside) + p->valley_floor_m * outside;
            }
            macro = macro * (1.f - cut) + p->pass_height_m * cut;

            {
                float nx = (x + 8192.f) * p->frequency;
                float ny = (y + 8192.f) * p->frequency;
                float wscale = p->warp_m * p->frequency;
                float wx = fbm(nx, ny, woct, p->seed ^ 0xA341316Cu);
                float wy = fbm(nx + 4.2f, ny + 1.7f, woct, p->seed ^ 0xC8013EA4u);
                float sx = nx + wx * wscale;
                float sy = ny + wy * wscale;
                float hills = fbm(sx, sy, p->octaves, p->seed ^ 0x51F0EDE5u);
                float ridge = ridged(sx * 1.35f, sy * 1.35f, p->octaves, p->seed ^ 0x7F4A7C15u);
                float damp = (1.f - valley * 0.97f) * (1.f - cut);
                float ridge01 = clampf(ridge, 0.f, 1.f);
                float hill01 = clampf(hills * 0.5f + 0.5f, 0.f, 1.f);
                float shape = hill01 * (1.f - p->ridge_weight) + ridge01 * p->ridge_weight;
                float h = macro;
                h += hills * 22.f * damp * (1.f - ring * 0.5f);
                h += shape * p->ring_height_m * 0.84f * ring * (1.f - cut);
                h -= p->lake_depth_m * lake;
                height[(size_t)j * (size_t)n + (size_t)i] = h;
            }
        }
        if (row_step && (j % row_step) == 0)
            notify(fn, user, CP_TERR_STAGE_BASE, j + 1, n);
    }
    notify(fn, user, CP_TERR_STAGE_BASE, n, n);
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
                float w = 1.f - d2 / r2;
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

/* Squared-distance fades, so the brush does not pay a sqrt per tap.
 * The start floor and the lake bowl are left almost uncut: gullies belong
 * on the ring, and the basin has to still hold water after the droplets.
 * Deposition is not scaled, so fans still spread onto the floor. */
static float erode_scale_at(const CpTerrainParams *p, float cell, float x, float y)
{
    float half = p->size_m * 0.5f;
    float wx = ((float)x + 0.5f) * cell - half;
    float wy = ((float)y + 0.5f) * cell - half;
    float r2 = wx * wx + wy * wy;
    float vr0 = p->valley_radius_m * 0.15f;
    float vr1 = p->valley_radius_m * 0.72f;
    float valley = 1.f - smoothstep(vr0 * vr0, vr1 * vr1, r2);
    float lx = wx - p->lake_x_m;
    float ly = wy - p->lake_y_m;
    float lr0 = p->lake_radius_m * 0.15f;
    float lr1 = p->lake_radius_m * 1.2f;
    float lake = 1.f - smoothstep(lr0 * lr0, lr1 * lr1, lx * lx + ly * ly);
    float hold = valley > lake ? valley : lake;
    return 1.f - hold * 0.94f;
}

static float erode_brush(float *h, int n, const CpTerrainParams *p, float cell,
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
                float d = b[k].w * scale * erode_scale_at(p, cell, (float)x, (float)y);
                h[y * n + x] -= d;
                removed += d;
            }
        }
        return removed;
    }
}

static void hydraulic(const CpTerrainParams *p, float *height, float *sed,
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
    memset(sed, 0, sizeof(float) * (size_t)n * (size_t)n);
    step = p->droplets > 32 ? p->droplets / 32 : 1;

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
                taken = erode_brush(height, n, p, cell, (int)x, (int)y, amount, brush, nb);
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
        /* Settle the remaining load on termination, including lifetime expiry. */
        if (sediment > 0.f) deposit_at(height, sed, n, x, y, sediment);
        if ((d % step) == 0)
            notify(fn, user, CP_TERR_STAGE_HYDRAULIC, d + 1, p->droplets);
    }
    notify(fn, user, CP_TERR_STAGE_HYDRAULIC, p->droplets, p->droplets > 0 ? p->droplets : 1);
}

/* ---- thermal ------------------------------------------------------------- */

static void thermal(const CpTerrainParams *p, float *height, float *scratch,
                    CpTerrainProgressFn fn, void *user)
{
    const int n = p->n;
    const float cell = p->size_m / (float)n;
    const float diag = cell * sqrtf(2.f);
    const float talus = tan_deg(p->talus_deg);
    (void)scratch;

    for (int iter = 0; iter < p->thermal_iters; iter++) {
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                int i = y * n + x;
                float h = height[i];
                float best = 0.f;
                int bi = -1;
                for (int d = 0; d < 8; d++) {
                    int nx = x + DX[d];
                    int ny = y + DY[d];
                    float dist, excess;
                    if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
                    dist = (d & 1) ? diag : cell;
                    excess = (h - height[ny * n + nx]) - talus * dist;
                    if (excess > best) { best = excess; bi = ny * n + nx; }
                }
                if (bi >= 0) {
                    float move = best * 0.25f;
                    height[i] -= move;
                    height[bi] += move;
                }
            }
        }

        notify(fn, user, CP_TERR_STAGE_THERMAL, iter + 1, p->thermal_iters);
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

/* Priority-flood depression routing. The physical surface is untouched.
 * Filled water levels live in scratch; parent pointers route equal-level flats
 * toward the spill. Heap ties use cell index, and parents always precede their
 * children. A strict descent or a flat parent therefore cannot form a cycle. */
static int heap_less(int a, int b, const float *level)
{
    return level[a] < level[b] || (level[a] == level[b] && a < b);
}
static void heap_push(int *heap, int *count, int cell, const float *level)
{
    int j=(*count)++;
    while(j>0) {
        int parent=(j-1)/2;
        if(!heap_less(cell,heap[parent],level)) break;
        heap[j]=heap[parent]; j=parent;
    }
    heap[j]=cell;
}
static int heap_pop(int *heap, int *count, const float *level)
{
    int result=heap[0],last=heap[--*count],j=0;
    while(j*2+1<*count) {
        int child=j*2+1;
        if(child+1<*count && heap_less(heap[child+1],heap[child],level)) child++;
        if(!heap_less(heap[child],last,level)) break;
        heap[j]=heap[child]; j=child;
    }
    if(*count) heap[j]=last;
    return result;
}
static void flow_accum(const float *height, int n, float size_m, float *flow,
                       float *level, int32_t *recv, int32_t *ups, int32_t *queue,
                       CpTerrainProgressFn fn, void *user)
{
    float cell=size_m/(float)n,diag=cell*sqrtf(2.f);
    int nn=n*n,heap_count=0,qn=0,popped=0;
    memset(ups,0,(size_t)nn*sizeof *ups);
    notify(fn,user,CP_TERR_STAGE_FLOW,0,2*nn);
    for(int y=0;y<n;y++) for(int x=0;x<n;x++) {
        int i=y*n+x; recv[i]=-1; level[i]=height[i]; flow[i]=1.f;
        if(x==0 || y==0 || x==n-1 || y==n-1) {
            ups[i]=1; heap_push(queue,&heap_count,i,level);
        }
    }
    while(heap_count) {
        int i=heap_pop(queue,&heap_count,level),x=i%n,y=i/n;
        for(int d=0;d<8;d++) {
            int nx=x+DX[d],ny=y+DY[d];
            if((unsigned)nx>=(unsigned)n || (unsigned)ny>=(unsigned)n) continue;
            int j=ny*n+nx; if(ups[j]) continue;
            ups[j]=1; recv[j]=i;
            level[j]=maxf(height[j],level[i]);
            heap_push(queue,&heap_count,j,level);
        }
        if((++popped % 8192)==0) notify(fn,user,CP_TERR_STAGE_FLOW,popped,2*nn);
    }
    memset(ups,0,(size_t)nn*sizeof *ups);
    for(int y=0;y<n;y++) for(int x=0;x<n;x++) {
        int i=y*n+x;
        int d=steepest(level,n,cell,diag,x,y);
        if(d>=0) recv[i]=(y+DY[d])*n+x+DX[d];
        if(recv[i]>=0) ups[recv[i]]++;
    }
    for(int i=0;i<nn;i++) if(ups[i]==0) queue[qn++]=i;
    for(int qh=0;qh<qn;qh++) {
        int i=queue[qh],r=recv[i];
        if(r>=0) {
            flow[r]+=flow[i];
            if(--ups[r]==0) queue[qn++]=r;
        }
        if((qh % 8192)==0) notify(fn,user,CP_TERR_STAGE_FLOW,nn+qh,2*nn);
    }
    float inv=1.f/(float)nn;
    for(int i=0;i<nn;i++) flow[i]*=inv;
    notify(fn,user,CP_TERR_STAGE_FLOW,2*nn,2*nn);
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

int cp_terrain_generate(const CpTerrainParams *p, CpTerrain *out,
                        const CpTerrainWorkspace *ws,
                        CpTerrainProgressFn fn, void *user)
{
    int rc = cp_terrain_validate(p);
    if (rc != CP_TERR_OK) return rc;
    if (!out || !out->height || !out->flow || !out->sediment) return CP_TERR_ERR_BUFFER;
    if (!ws || !ws->scratch || !ws->recv || !ws->ups || !ws->queue) return CP_TERR_ERR_BUFFER;

    out->n = p->n;
    out->size_m = p->size_m;
    fill_base(p, out->height, fn, user);
    if (p->droplets > 0)
        hydraulic(p, out->height, out->sediment, fn, user);
    else
        memset(out->sediment, 0, sizeof(float) * (size_t)p->n * (size_t)p->n);
    if (p->thermal_iters > 0)
        thermal(p, out->height, ws->scratch, fn, user);
    flow_accum(out->height, p->n, p->size_m, out->flow, ws->scratch, ws->recv, ws->ups, ws->queue, fn, user);
    notify(fn, user, CP_TERR_STAGE_DONE, 1, 1);
    return CP_TERR_OK;
}
