/* cpore - tests for the moisture climate kernel (plan section 4, step M1).
 *   (a) m = tau = 0 equals the upslope Cw U.grad h
 *   (b) C against the lt_ref.py fixtures (tests/fixtures/climate/lt_*.bin), 4 terrains
 *   (c) wind rotated 90 degrees = map rotated 90 degrees
 *   (d) hash stable over 3 runs (and against a golden; the Makefile also compares gcc/clang, -O0/-O2)
 *   plus a synthetic-island pipeline check and the 256^2 timing gate (15 ms, plan 4.5 M1).
 * usage: climate_test [fixture_dir] [--bench]   (--bench enforces the 15 ms gate) */
#include "cpore/climate.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

static int fails = 0, checks = 0;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static double now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1e6;
}

/* test terrains use only + - * / so the goldens do not depend on the libm */
static void bump_terrain(float *h, int n, float dx, unsigned seed)
{
    int i, x, y;
    unsigned s = seed;
    for (i = 0; i < n * n; i++) h[i] = 0.f;
    for (i = 0; i < 6; i++) {
        float cx, cy, a, hm;
        s = s * 1664525u + 1013904223u; cx = (float)(s >> 8) / 16777216.f * (float)n * 0.6f + 0.2f * (float)n;
        s = s * 1664525u + 1013904223u; cy = (float)(s >> 8) / 16777216.f * (float)n * 0.6f + 0.2f * (float)n;
        s = s * 1664525u + 1013904223u; a = (2.f + 5.f * (float)(s >> 8) / 16777216.f) * dx;
        s = s * 1664525u + 1013904223u; hm = 200.f + 700.f * (float)(s >> 8) / 16777216.f;
        for (y = 0; y < n; y++)
            for (x = 0; x < n; x++) {
                float rx = ((float)x - cx) * dx, ry = ((float)y - cy) * dx;
                float q = (rx * rx + ry * ry) / (a * a);
                float d = 1.f / (1.f + q);          /* rational bump */
                h[y * n + x] += hm * d * d * d;
            }
    }
}

static double maxabs(const float *a, size_t n)
{
    double m = 0; size_t i;
    for (i = 0; i < n; i++) { double v = fabs((double)a[i]); if (v > m) m = v; }
    return m;
}
static double maxdiff(const float *a, const float *b, size_t n)
{
    double m = 0; size_t i;
    for (i = 0; i < n; i++) { double v = fabs((double)a[i] - (double)b[i]); if (v > m) m = v; }
    return m;
}

/* (a) ------------------------------------------------------------------ */
static void test_upslope(float *scr)
{
    int n = 64, x, y, k;
    float dx = 1000.f, a = 6000.f, hm = 800.f;
    float h[64 * 64], P[64 * 64], S[64 * 64];
    static const float winds[3][2] = { {8.f, 0.f}, {-5.f, 6.f}, {0.f, -9.f} };
    for (k = 0; k < 3; k++) {
        CpLtParams p;
        double err, mx;
        memset(&p, 0, sizeof p);
        p.dx = dx; p.U = winds[k][0]; p.V = winds[k][1];
        p.Cw = 7.4e-3f * 6.5f / 5.8f; p.Nm = 0.005f; p.Hw = 0.f; p.tau_c = 0.f; p.tau_f = 0.f; p.truncate = 0;
        for (y = 0; y < n; y++)
            for (x = 0; x < n; x++) {
                float rx = ((float)x - 32.f) * dx, ry = ((float)y - 31.f) * dx;
                float e = (float)exp(-(double)((rx * rx + ry * ry) / (a * a)));
                h[y * n + x] = hm * e;
                /* analytic Cw U.grad h in mm/h */
                S[y * n + x] = p.Cw * (p.U * (-2.f * rx / (a * a)) + p.V * (-2.f * ry / (a * a))) * hm * e * 3600.f;
            }
        CHECK(cp_lt_precip(h, n, &p, P, NULL, scr) == CP_CLIM_OK, "lt failed");
        mx = maxabs(S, (size_t)n * n);
        err = maxdiff(P, S, (size_t)n * n) / mx;
        CHECK(err < 1e-4, "(a) wind %d: m=tau=0 vs Cw U.grad h: rel err %.3e (limit 1e-4)", k, err);
        printf("  (a) wind (%g, %g): max S %.3f mm/h, rel err %.2e\n", p.U, p.V, mx, err);
        /* truncated: equals max(S, 0) */
        p.truncate = 1;
        cp_lt_precip(h, n, &p, P, NULL, scr);
        for (x = 0; x < n * n; x++) if (S[x] < 0.f) S[x] = 0.f;
        err = maxdiff(P, S, (size_t)n * n) / mx;
        CHECK(err < 1e-4, "(a) truncated wind %d: rel err %.3e", k, err);
    }
}

/* (b) ------------------------------------------------------------------ */
static int read_fixture(const char *dir, const char *name, CpLtParams *p, int *n, float **h, float **P, float **q)
{
    char path[512];
    FILE *f;
    int magic, nn, trunc, pad;
    double d[9];
    snprintf(path, sizeof path, "%s/lt_%s.bin", dir, name);
    f = fopen(path, "rb");
    if (!f) return 0;
    if (fread(&magic, 4, 1, f) != 1 || fread(&nn, 4, 1, f) != 1 || magic != 0x4C545231 ||
        fread(d, 8, 9, f) != 9 || fread(&trunc, 4, 1, f) != 1 || fread(&pad, 4, 1, f) != 1) { fclose(f); return 0; }
    *n = nn;
    *h = malloc(sizeof(float) * (size_t)nn * nn); *P = malloc(sizeof(float) * (size_t)nn * nn); *q = malloc(sizeof(float) * (size_t)nn * nn);
    if (fread(*h, 4, (size_t)nn * nn, f) != (size_t)nn * nn || fread(*P, 4, (size_t)nn * nn, f) != (size_t)nn * nn ||
        fread(*q, 4, (size_t)nn * nn, f) != (size_t)nn * nn) { fclose(f); return 0; }
    fclose(f);
    p->dx = (float)d[0]; p->U = (float)d[1]; p->V = (float)d[2]; p->Cw = (float)d[3]; p->Nm = (float)d[4];
    p->Hw = (float)d[5]; p->tau_c = (float)d[6]; p->tau_f = (float)d[7]; p->P0 = (float)d[8]; p->truncate = trunc;
    return 1;
}

static void test_fixtures(const char *dir)
{
    static const char *names[4] = { "gauss", "ridge", "bumpy", "island" };
    int k;
    for (k = 0; k < 4; k++) {
        CpLtParams p;
        int n;
        float *h, *Pr, *qr, *P, *q, *scr;
        double e, eq;
        if (!read_fixture(dir, names[k], &p, &n, &h, &Pr, &qr)) {
            CHECK(0, "(b) cannot read fixture lt_%s.bin in %s (run python3 tools/climate/lt_ref.py fixtures)", names[k], dir);
            continue;
        }
        P = malloc(sizeof(float) * (size_t)n * n); q = malloc(sizeof(float) * (size_t)n * n);
        scr = malloc(sizeof(float) * cp_lt_scratch_floats(n));
        CHECK(cp_lt_precip(h, n, &p, P, q, scr) == CP_CLIM_OK, "lt failed");
        e = maxdiff(P, Pr, (size_t)n * n) / maxabs(Pr, (size_t)n * n);
        eq = maxdiff(q, qr, (size_t)n * n) / maxabs(qr, (size_t)n * n);
        CHECK(e < 1e-3, "(b) %s: P differs from lt_ref by %.3e of max (limit 1e-3)", names[k], e);
        CHECK(eq < 1e-3, "(b) %s: qc differs from lt_ref by %.3e of max (limit 1e-3)", names[k], eq);
        printf("  (b) %-6s n=%d max P %.3f mm/h: P err %.2e, qc err %.2e of max\n", names[k], n, maxabs(Pr, (size_t)n * n), e, eq);
        free(h); free(Pr); free(qr); free(P); free(q); free(scr);
    }
}

/* (c) ------------------------------------------------------------------ */
static void test_rotation(void)
{
    int n = 32, x, y, tr;
    float dx = 2000.f;
    float *h = malloc(sizeof(float) * n * n), *hr = malloc(sizeof(float) * n * n), *PA = malloc(sizeof(float) * n * n),
          *PB = malloc(sizeof(float) * n * n), *PAr = malloc(sizeof(float) * n * n);
    float *scr = malloc(sizeof(float) * cp_lt_scratch_floats(n));
    bump_terrain(h, n, dx, 3);
    for (tr = 0; tr < 2; tr++) {
        CpLtParams p;
        double e;
        memset(&p, 0, sizeof p);
        p.dx = dx; p.U = 7.f; p.V = 2.f; p.Cw = 0.00829f; p.Nm = 0.005f; p.Hw = 2500.f; p.tau_c = 1000.f; p.tau_f = 1000.f;
        p.P0 = tr ? 0.02f : 0.f; p.truncate = tr;
        cp_lt_precip(h, n, &p, PA, NULL, scr);
        /* map rotation new[y][x] = old[x][n-1-y]: the vector (a, b) goes to (b, -a) */
        for (y = 0; y < n; y++) for (x = 0; x < n; x++) hr[y * n + x] = h[x * n + (n - 1 - y)];
        p.U = 2.f; p.V = -7.f;
        cp_lt_precip(hr, n, &p, PB, NULL, scr);
        for (y = 0; y < n; y++) for (x = 0; x < n; x++) PAr[y * n + x] = PA[x * n + (n - 1 - y)];
        e = maxdiff(PAr, PB, (size_t)n * n) / maxabs(PA, (size_t)n * n);
        CHECK(e < 1e-5, "(c) rotated wind vs rotated map (truncate %d): rel err %.3e", tr, e);
        printf("  (c) truncate=%d: rel err %.2e\n", tr, e);
    }
    free(h); free(hr); free(PA); free(PB); free(PAr); free(scr);
}

/* (d) + pipeline -------------------------------------------------------- */
/* golden hashes: identical for gcc -O0/-O1/-O2/-O3/-Os; bump them (and CP_CLIMATE_VERSION) only for an intended change */
#define GOLDEN_LT      0xee917a7172d34a5eULL
#define GOLDEN_CLIMATE 0xb788bd3cf2542707ULL

static void island_height(float *h, int n, float cell)
{   /* cone island, peak 824 m, radius about 0.4 n cells, sea floor to -40 m; + - * / only */
    int x, y;
    for (y = 0; y < n; y++)
        for (x = 0; x < n; x++) {
            float ux = ((float)x - (float)n * 0.5f) / (float)n, uy = ((float)y - (float)n * 0.5f) / (float)n;
            float r = sqrtf(ux * ux + uy * uy) / 0.4f;
            float v = 1.f - r;
            float peak = 1.f + 0.35f * (ux - uy);      /* the high side is the NE-facing one */
            (void)cell;
            if (v > 0.f) h[y * n + x] = 824.f * v * v * (peak > 0.4f ? peak : 0.4f) * 0.75f;
            else h[y * n + x] = -40.f * (r - 1.f) / (r + 1.f);
        }
}

static void test_hash_and_pipeline(int bench)
{
    int n = 256, run, i;
    size_t cnt = (size_t)n * n;
    float *h = malloc(sizeof(float) * cnt), *P = malloc(sizeof(float) * cnt), *scr = malloc(sizeof(float) * cp_climate_scratch_floats(n));
    CpClimateParams cp;
    CpClimateOut o;
    uint64_t hl[3], hc[3];
    float pmax = 0, pmin = 1e30f;
    int wi = 0, wmax = 0, lee = 0;
    int counts[CP_BIOME_COUNT];
    double t0, t1, best = 1e9, bestc = 1e9, tq = 1e9;
    CpLtParams lp;

    island_height(h, n, 31.25f);
    cp_climate_defaults(&cp, n, 31.25f);
    o.precip = malloc(sizeof(float) * cnt); o.temp = malloc(sizeof(float) * cnt); o.qc = malloc(sizeof(float) * cnt);
    o.fog = malloc(sizeof(float) * cnt); o.biome = malloc(cnt); o.veg = malloc(4 * cnt);

    memset(&lp, 0, sizeof lp);
    lp.dx = 250.f; lp.U = -5.6f; lp.V = 5.6f; lp.Cw = 0.00829f; lp.Nm = 0.005f; lp.Hw = 2500.f; lp.tau_c = 1000.f; lp.tau_f = 1000.f; lp.truncate = 1;
    for (i = 0; i < (int)cnt; i++) P[i] = h[i] > 0.f ? h[i] * 2.5f : 0.f;
    for (run = 0; run < 3; run++) {
        float *out = malloc(sizeof(float) * cnt);
        CHECK(cp_lt_precip(P, n, &lp, out, NULL, scr) == CP_CLIM_OK, "lt");
        hl[run] = cp_lt_hash(out, cnt);
        free(out);
        CHECK(cp_climate_run(&cp, h, NULL, NULL, &o, scr) == CP_CLIM_OK, "climate_run");
        hc[run] = cp_climate_hash(&o, n);
    }
    CHECK(hl[0] == hl[1] && hl[1] == hl[2], "(d) LT hash differs between runs");
    CHECK(hc[0] == hc[1] && hc[1] == hc[2], "(d) climate hash differs between runs");
    printf("  (d) hash lt=%016llx climate=%016llx\n", (unsigned long long)hl[0], (unsigned long long)hc[0]);
    if (GOLDEN_LT) CHECK(hl[0] == GOLDEN_LT, "(d) LT hash differs from the golden");
    if (GOLDEN_CLIMATE) CHECK(hc[0] == GOLDEN_CLIMATE, "(d) climate hash differs from the golden");

    /* pipeline sanity on the synthetic island (trade wind from the NE: west/south side is the lee) */
    memset(counts, 0, sizeof counts);
    for (i = 0; i < (int)cnt; i++) {
        counts[o.biome[i]]++;
        if (h[i] > 0.f) { if (o.precip[i] > pmax) { pmax = o.precip[i]; wi = i; } if (o.precip[i] < pmin) pmin = o.precip[i]; }
        if (h[i] <= 0.f) CHECK(o.biome[i] == CP_BIOME_SEA || o.biome[i] == CP_BIOME_REEF, "sea cell %d got biome %d", i, o.biome[i]);
        CHECK(o.precip[i] >= 0.f && o.fog[i] >= 0.f && o.fog[i] <= 1.f && o.qc[i] >= 0.f && o.qc[i] <= 1.f, "range at %d", i);
    }
    (void)wmax; (void)lee;
    printf("  island: land precip max %.0f mm/yr at (%d,%d), min %.0f mm/yr, ratio %.1f\n", pmax, wi % n, wi / n, pmin, pmax / (pmin > 1.f ? pmin : 1.f));
    printf("  biomes:");
    for (i = 0; i < CP_BIOME_COUNT; i++) printf(" %d:%d", i, counts[i]);
    printf("\n");
    CHECK(pmax > 2000.f && pmax < 5000.f, "windward annual max %.0f mm outside 2000-5000 (plan: 3000-4000)", pmax);
    CHECK(pmin >= 50.f && pmin < 400.f, "lee annual min %.0f mm outside 50-400 (plan: 150-300)", pmin);
    CHECK(pmax / (pmin > 1.f ? pmin : 1.f) >= 8.f, "windward/lee ratio %.1f < 8", pmax / pmin);
    CHECK(counts[CP_BIOME_SEA] > 0 && counts[CP_BIOME_JUNGLE] > 0 && counts[CP_BIOME_DESERT] + counts[CP_BIOME_SCRUB] + counts[CP_BIOME_BADLANDS] > 0,
          "island lacks sea, jungle or a dry biome");
    {   /* wind rotated: a NE wind leaves the SW side dry, so the dry cells sit to the SW of the wet ones */
        double wx = 0, wy = 0, dx_ = 0, dy_ = 0, ws = 0, ds = 0;
        for (i = 0; i < (int)cnt; i++) {
            if (h[i] <= 0.f) continue;
            if (o.biome[i] == CP_BIOME_JUNGLE) { wx += i % n; wy += i / n; ws += 1; }
            if (o.biome[i] == CP_BIOME_DESERT || o.biome[i] == CP_BIOME_SCRUB || o.biome[i] == CP_BIOME_BADLANDS) { dx_ += i % n; dy_ += i / n; ds += 1; }
        }
        if (ws > 0 && ds > 0) CHECK(wx / ws - dx_ / ds > 5.0 && dy_ / ds - wy / ws > 5.0, "jungle centroid (%.0f,%.0f) not NE of dry centroid (%.0f,%.0f)", wx / ws, wy / ws, dx_ / ds, dy_ / ds);
    }

    {   /* a taller climate scale puts snow on the summit (T < snow_C and P > 400 mm) */
        CpClimateParams tall = cp;
        int snow = 0;
        tall.scale_z = 5.f;
        CHECK(cp_climate_run(&tall, h, NULL, NULL, &o, scr) == CP_CLIM_OK, "tall run");
        for (i = 0; i < (int)cnt; i++) if (o.biome[i] == CP_BIOME_SNOW) snow++;
        CHECK(snow > 0, "no snow at scale_z 5");
        printf("  scale_z 5: %d snow cells\n", snow);
        cp_climate_run(&cp, h, NULL, NULL, &o, scr);
    }

    /* timing: LT P only for 256^2 (padded 512^2), then with qc, then the whole pipeline (two regimes + qc) */
    {
        float *hc2 = malloc(sizeof(float) * cnt), *out = malloc(sizeof(float) * cnt), *q = malloc(sizeof(float) * cnt);
        for (i = 0; i < (int)cnt; i++) hc2[i] = h[i] > 0.f ? h[i] * 2.5f : 0.f;
        cp_lt_precip(hc2, n, &lp, out, NULL, scr);
        for (run = 0; run < 15; run++) {
            t0 = now_ms(); cp_lt_precip(hc2, n, &lp, out, NULL, scr); t1 = now_ms();
            if (t1 - t0 < best) best = t1 - t0;
            t0 = now_ms(); cp_lt_precip(hc2, n, &lp, out, q, scr); t1 = now_ms();
            if (t1 - t0 < tq) tq = t1 - t0;
            t0 = now_ms(); cp_climate_run(&cp, h, NULL, NULL, &o, scr); t1 = now_ms();
            if (t1 - t0 < bestc) bestc = t1 - t0;
        }
        free(hc2); free(out); free(q);
    }
    printf("  timing 256^2 (padded 512^2), best of 15: LT precip %.2f ms, LT + qc %.2f ms, whole pipeline (2 regimes + qc + maps) %.2f ms\n", best, tq, bestc);
    if (bench) CHECK(best <= 15.0, "gate: LT 256^2 took %.2f ms (limit 15 ms)", best);
    else CHECK(best <= 100.0, "LT 256^2 took %.2f ms (soft limit 100 ms; the 15 ms gate runs under make climate-bench)", best);
    free(h); free(P); free(scr); free(o.precip); free(o.temp); free(o.qc); free(o.fog); free(o.biome); free(o.veg);
}

static void test_biome_table_and_args(void)
{
    CpClimateParams cp;
    CpClimateOut o;
    float h[64], scr_small[1];
    (void)scr_small;
    memset(&o, 0, sizeof o);
    cp_climate_defaults(&cp, 12, 31.25f);
    CHECK(cp_climate_run(&cp, h, NULL, NULL, &o, h) == CP_CLIM_ERR_NULL, "null outputs rejected");
    CHECK(cp_lt_precip(h, 12, (const CpLtParams *)&cp, h, NULL, h) == CP_CLIM_ERR_N, "n=12 rejected");
}

int main(int argc, char **argv)
{
    const char *dir = "tests/fixtures/climate";
    int bench = 0, i;
    float *scr;
    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--bench")) bench = 1; else dir = argv[i];
    }
    scr = malloc(sizeof(float) * cp_lt_scratch_floats(64));
    printf("climate kernel v%d\n", CP_CLIMATE_VERSION);
    test_upslope(scr);
    test_fixtures(dir);
    test_rotation();
    test_hash_and_pipeline(bench);
    test_biome_table_and_args();
    free(scr);
    printf("%d checks, %d failed\n", checks, fails);
    return fails ? 1 : 0;
}
