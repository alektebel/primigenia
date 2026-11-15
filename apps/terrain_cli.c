/* Terrain dump, hash and timing. Malloc lives here, not in core. */
#include "cpore/terrain.h"

#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_s(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

static void die(const char *msg)
{
    fprintf(stderr, "%s\n", msg);
    exit(2);
}

static float *falloc(int n)
{
    float *p = calloc((size_t)n * (size_t)n, sizeof(float));
    if (!p) die("out of memory");
    return p;
}

static int32_t *ialloc(int n)
{
    int32_t *p = calloc((size_t)n * (size_t)n, sizeof(int32_t));
    if (!p) die("out of memory");
    return p;
}

static int arg_i(int argc, char **argv, const char *key, int fallback)
{
    for (int i = 0; i < argc - 1; i++)
        if (!strcmp(argv[i], key)) {
            char *end; errno=0; long v=strtol(argv[i+1], &end, 10);
            if (errno || *end || !*argv[i+1] || v < 0 || v > 2147483647L) die("invalid integer option");
            return (int)v;
        }
    return fallback;
}

static int has(int argc, char **argv, const char *key)
{
    for (int i = 0; i < argc; i++)
        if (!strcmp(argv[i], key)) return 1;
    return 0;
}

static const char *arg_s(int argc, char **argv, const char *key)
{
    for (int i = 0; i < argc - 1; i++)
        if (!strcmp(argv[i], key)) return argv[i + 1];
    return NULL;
}

static void apply_overrides(CpTerrainParams *p, int argc, char **argv)
{
    int n = arg_i(argc, argv, "--n", p->n);
    int drops = arg_i(argc, argv, "--droplets", p->droplets);
    int thermal = arg_i(argc, argv, "--thermal", p->thermal_iters);
    const char *seed_arg=arg_s(argc,argv,"--seed");
    uint32_t seed=p->seed;
    if(seed_arg) {
        char *end; errno=0; unsigned long v=strtoul(seed_arg,&end,10);
        if(errno || *end || !*seed_arg || *seed_arg=='-' || v>UINT32_MAX) die("invalid seed");
        seed=(uint32_t)v;
    }
    int life = arg_i(argc, argv, "--lifetime", p->lifetime);
    if (has(argc, argv, "--base")) { drops = 0; thermal = 0; }
    p->n = n;
    p->droplets = drops;
    p->thermal_iters = thermal;
    p->lifetime = life;
    p->seed = (uint32_t)seed;
}

static int run_gen(const CpTerrainParams *p, CpTerrain *t, CpTerrainWorkspace *ws, double *sec)
{
    double t0 = now_s();
    int rc = cp_terrain_generate(p, t, ws, NULL, NULL);
    *sec = now_s() - t0;
    return rc;
}

static void setup(const CpTerrainParams *p, CpTerrain *t, CpTerrainWorkspace *ws)
{
    t->height = falloc(p->n);
    t->flow = falloc(p->n);
    t->sediment = falloc(p->n);
    ws->scratch = falloc(p->n);
    ws->recv = ialloc(p->n);
    ws->ups = ialloc(p->n);
    ws->queue = ialloc(p->n);
}

static void stats(const CpTerrain *t, const CpTerrainParams *p)
{
    int n = t->n;
    float cell = t->size_m / (float)n;
    float half = t->size_m * 0.5f;
    float *slope = falloc(n);
    double sum = 0.0;
    float hmin = t->height[0], hmax = t->height[0];
    int flat_n = 0, flat_ok = 0;
    float lake_in = 1.0e9f, lake_rim = 1.0e9f;
    float pass_max = -1.0e9f, ring_max = -1.0e9f;
    const float tan10 = 0.17632698f;
    const float flat_r = 90.f;
    cp_terrain_slope(t->height, n, t->size_m, slope);
    for (int j = 0; j < n; j++) {
        for (int i = 0; i < n; i++) {
            int k = j * n + i;
            float h = t->height[k];
            float x = ((float)i + 0.5f) * cell - half;
            float y = ((float)j + 0.5f) * cell - half;
            float r = sqrtf(x * x + y * y);
            float lx = x - p->lake_x_m;
            float ly = y - p->lake_y_m;
            float lr = sqrtf(lx * lx + ly * ly);
            sum += h;
            if (h < hmin) hmin = h;
            if (h > hmax) hmax = h;
            if (r <= flat_r) {
                flat_n++;
                if (slope[k] < tan10) flat_ok++;
            }
            if (lr <= p->lake_radius_m * 0.4f && h < lake_in) lake_in = h;
            if (lr >= p->lake_radius_m * 0.9f && lr <= p->lake_radius_m * 1.15f && h < lake_rim)
                lake_rim = h;
            if (r >= p->ring_inner_m && r <= p->ring_outer_m) {
                if (h > ring_max) ring_max = h;
            }
        }
    }
    /* Pass corridor along the normalised default-or-param direction. */
    {
        float plen = sqrtf(p->pass_x * p->pass_x + p->pass_y * p->pass_y);
        float px = plen > 1e-6f ? p->pass_x / plen : 1.f;
        float py = plen > 1e-6f ? p->pass_y / plen : 0.f;
        for (int j = 0; j < n; j++) {
            for (int i = 0; i < n; i++) {
                float x = ((float)i + 0.5f) * cell - half;
                float y = ((float)j + 0.5f) * cell - half;
                float r = sqrtf(x * x + y * y);
                float along = x * px + y * py;
                float across = fabsf(-py * x + px * y);
                if (along > 0.f && across < p->pass_half_m &&
                    r >= p->ring_inner_m * 0.95f && r <= p->ring_outer_m) {
                    float h = t->height[j * n + i];
                    if (h > pass_max) pass_max = h;
                }
            }
        }
    }
    printf("n %d seed %" PRIu32 " h[%.2f, %.2f] mean %.2f\n",
           n, p->seed, hmin, hmax, sum / (double)n / (double)n);
    printf("valley_flat %d/%d (%.3f) within %.0fm slope<10deg\n",
           flat_ok, flat_n, flat_n ? (double)flat_ok / (double)flat_n : 0.0, flat_r);
    printf("lake_inner %.2f rim %.2f hold %.2f\n", lake_in, lake_rim, lake_rim - lake_in);
    printf("pass_max %.2f ring_max %.2f\n", pass_max, ring_max);
    {
        float plen = sqrtf(p->pass_x * p->pass_x + p->pass_y * p->pass_y);
        float px = plen > 1e-6f ? p->pass_x / plen : 1.f;
        float py = plen > 1e-6f ? p->pass_y / plen : 0.f;
        float saddle = -1.0e9f;
        int reached = 0;
        uint8_t *seen = calloc((size_t)n * (size_t)n, 1);
        int *q = malloc(sizeof(int) * (size_t)n * (size_t)n);
        int qh = 0, qt = 0;
        if (!seen || !q) die("out of memory");
        for (int j = 0; j < n; j++) {
            for (int i = 0; i < n; i++) {
                float x = ((float)i + 0.5f) * cell - half;
                float y = ((float)j + 0.5f) * cell - half;
                float r = sqrtf(x * x + y * y);
                float along = x * px + y * py;
                float across = fabsf(-py * x + px * y);
                if (along > 0.f && across < p->pass_half_m * 0.35f &&
                    r >= p->ring_inner_m && r <= p->ring_outer_m) {
                    float h = t->height[j * n + i];
                    if (h > saddle) saddle = h;
                }
            }
        }
        q[qt++] = (n / 2) * n + (n / 2);
        seen[(n / 2) * n + (n / 2)] = 1;
        while (qh < qt) {
            int c = q[qh++];
            int x = c % n, y = c / n;
            float wx = ((float)x + 0.5f) * cell - half;
            float wy = ((float)y + 0.5f) * cell - half;
            if (sqrtf(wx * wx + wy * wy) > p->ring_outer_m) { reached = 1; break; }
            for (int d = 0; d < 8; d++) {
                int nx = x + (d == 0 || d == 1 || d == 7) - (d == 3 || d == 4 || d == 5);
                int ny = y + (d == 1 || d == 2 || d == 3) - (d == 5 || d == 6 || d == 7);
                int ni;
                if ((unsigned)nx >= (unsigned)n || (unsigned)ny >= (unsigned)n) continue;
                ni = ny * n + nx;
                if (seen[ni] || t->height[ni] > 200.f) continue;
                seen[ni] = 1;
                q[qt++] = ni;
            }
        }
        printf("saddle %.2f pass_reachable %d\n", saddle, reached);
        free(seen);
        free(q);
    }
    free(slope);
}

static int write_dump(const char *path, const CpTerrainParams *p, const CpTerrain *t)
{
    FILE *f = fopen(path, "wb");
    int8_t *dir;
    uint32_t version = CP_TERRAIN_VERSION;
    uint32_t flags = (p->droplets == 0 && p->thermal_iters == 0) ? 1u : 0u;
    int nn = p->n * p->n;
    char magic[8] = {'C', 'P', 'T', 'E', 'R', '1', '0', '\0'};
    if (!f) { perror(path); return 2; }
    dir = malloc((size_t)nn);
    if (!dir) die("out of memory");
    cp_terrain_directions(t->height, t->n, t->size_m, dir);
    if (fwrite(magic, 1, 8, f) != 8 ||
        fwrite(&version, 4, 1, f) != 1 ||
        fwrite(&p->seed, 4, 1, f) != 1 ||
        fwrite(&p->n, 4, 1, f) != 1 ||
        fwrite(&p->size_m, 4, 1, f) != 1 ||
        fwrite(&flags, 4, 1, f) != 1 ||
        fwrite(t->height, 4, (size_t)nn, f) != (size_t)nn ||
        fwrite(t->flow, 4, (size_t)nn, f) != (size_t)nn ||
        fwrite(t->sediment, 4, (size_t)nn, f) != (size_t)nn ||
        fwrite(dir, 1, (size_t)nn, f) != (size_t)nn) {
        fprintf(stderr, "short write %s\n", path);
        fclose(f);
        free(dir);
        return 2;
    }
    fclose(f);
    free(dir);
    return 0;
}

int main(int argc, char **argv)
{
    CpTerrainParams p;
    CpTerrain t;
    CpTerrainWorkspace ws;
    double sec = 0.0;
    int rc;
    const char *cmd;
    if (argc < 2) {
        fprintf(stderr,
                "usage: terrain_cli hash|time|dump|stats --seed N --n N [--droplets N] [--thermal N] [--base] [--out PATH]\n");
        return 2;
    }
    cmd = argv[1];
    cp_terrain_params_default(&p);
    apply_overrides(&p, argc, argv);
    rc = cp_terrain_validate(&p);
    if (rc != CP_TERR_OK) {
        fprintf(stderr, "bad params %d\n", rc);
        return 2;
    }
    setup(&p, &t, &ws);
    rc = run_gen(&p, &t, &ws, &sec);
    if (rc != CP_TERR_OK) {
        fprintf(stderr, "generate %d\n", rc);
        return 2;
    }
    t.n = p.n;
    t.size_m = p.size_m;
    if (!strcmp(cmd, "hash")) {
        printf("%016" PRIx64 " %.4f\n", cp_terrain_hash(&t), sec);
        return 0;
    }
    if (!strcmp(cmd, "time")) {
        printf("seconds %.4f hash %016" PRIx64 "\n", sec, cp_terrain_hash(&t));
        return 0;
    }
    if (!strcmp(cmd, "stats")) {
        printf("seconds %.4f hash %016" PRIx64 "\n", sec, cp_terrain_hash(&t));
        stats(&t, &p);
        return 0;
    }
    if (!strcmp(cmd, "dump")) {
        const char *path = arg_s(argc, argv, "--out");
        if (!path) die("dump needs --out");
        printf("seconds %.4f hash %016" PRIx64 "\n", sec, cp_terrain_hash(&t));
        return write_dump(path, &p, &t);
    }
    die("unknown command");
    return 2;
}
