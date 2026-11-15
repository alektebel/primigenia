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

static float arg_f(int argc,char **argv,const char *key,float fallback)
{
    const char *value=arg_s(argc,argv,key); if(!value) return fallback;
    char *end; errno=0; float v=strtof(value,&end);
    if(errno || *end || !*value || !isfinite(v)) die("invalid float option");
    return v;
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
    int stream = arg_i(argc, argv, "--stream", p->stream_iters);
    if (has(argc, argv, "--base")) { drops = 0; thermal = 0; stream = 0; }
    p->gentle_bases=arg_f(argc,argv,"--gentle-bases",p->gentle_bases);
    p->layout_variety=arg_f(argc,argv,"--layout-variety",p->layout_variety);
    p->cliff_bands=arg_f(argc,argv,"--cliff-bands",p->cliff_bands);
    p->sea_cliffs=arg_f(argc,argv,"--sea-cliffs",p->sea_cliffs);
    p->hard_rock=arg_f(argc,argv,"--hard-rock",p->hard_rock);
    p->volcano=arg_f(argc,argv,"--volcano",p->volcano);
    p->caves=arg_f(argc,argv,"--caves",p->caves);
    p->stream_iters = stream;
    p->stream_k=arg_f(argc,argv,"--stream-k",p->stream_k);
    p->talus_deg=arg_f(argc,argv,"--talus",p->talus_deg);
    p->cliff_deg=arg_f(argc,argv,"--cliff",p->cliff_deg);
    p->ridge_weight=arg_f(argc,argv,"--ridge",p->ridge_weight);
    p->octaves=arg_i(argc,argv,"--octaves",p->octaves);
    p->ring_height_m=arg_f(argc,argv,"--relief",p->ring_height_m);
    p->radius=arg_i(argc,argv,"--radius",p->radius);
    p->erosion=arg_f(argc,argv,"--erosion",p->erosion);
    p->capacity=arg_f(argc,argv,"--capacity",p->capacity);
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
    memset(t,0,sizeof *t);
    t->material=calloc((size_t)p->n*p->n,1);if(!t->material)die("out of memory");
    t->height = falloc(p->n);
    t->flow = falloc(p->n);
    t->sediment = falloc(p->n);
    ws->scratch = falloc(p->n);
    ws->recv = ialloc(p->n);
    ws->ups = ialloc(p->n);
    ws->queue = ialloc(p->n);
}

/* Lowest water level at which a four-connected flood from `start` reaches
 * the sea or the map edge, to 0.25 m. With `block_gap` the river-gap corridor
 * is closed, so the answer is the lowest other way out: the col. */
static int escapes(const CpTerrain *t, const CpTerrainParams *p, int start, float level,
                   int block_gap, uint8_t *seen, int *q)
{
    int n = t->n, qh = 0, qt = 0;
    float cell = t->size_m / (float)n, half = t->size_m * 0.5f;
    float plen = sqrtf(p->pass_x * p->pass_x + p->pass_y * p->pass_y);
    float px = plen > 1e-6f ? p->pass_x / plen : 1.f;
    float py = plen > 1e-6f ? p->pass_y / plen : 0.f;
    memset(seen, 0, (size_t)n * (size_t)n);
    q[qt++] = start; seen[start] = 1;
    while (qh < qt) {
        int c = q[qh++], x = c % n, y = c / n;
        if (x == 0 || y == 0 || x == n - 1 || y == n - 1 || t->height[c] <= 0.f) return 1;
        for (int d = 0; d < 4; d++) {
            int nx = x + (d == 0) - (d == 1), ny = y + (d == 2) - (d == 3), ni = ny * n + nx;
            if (seen[ni] || t->height[ni] > level) continue;
            if (block_gap) {
                float wx = ((float)nx + 0.5f) * cell - half, wy = ((float)ny + 0.5f) * cell - half;
                if (wx * px + wy * py > 0.f && fabsf(-wx * py + wy * px) < 450.f) continue;
            }
            seen[ni] = 1; q[qt++] = ni;
        }
    }
    return 0;
}

static float sill(const CpTerrain *t, const CpTerrainParams *p, int start, int block_gap,
                  uint8_t *seen, int *q)
{
    float lo = t->height[start], hi = 4000.f;
    if (escapes(t, p, start, lo, block_gap, seen, q)) return lo;
    while (hi - lo > 0.25f) {
        float mid = 0.5f * (lo + hi);
        if (escapes(t, p, start, mid, block_gap, seen, q)) hi = mid; else lo = mid;
    }
    return hi;
}

static void stats(const CpTerrain *t, const CpTerrainParams *p)
{
    int n = t->n;
    float cell = t->size_m / (float)n;
    float half = t->size_m * 0.5f;
    float *slope = falloc(n);
    uint8_t *seen = calloc((size_t)n * (size_t)n, 1);
    int *q = malloc(sizeof(int) * (size_t)n * (size_t)n);
    double sum = 0.0;
    float hmin = t->height[0], hmax = t->height[0];
    int flat_n = 0, flat_ok = 0, land = 0;
    const float tan10 = 0.17632698f;
    const float flat_r = 90.f;
    int centre = (n / 2) * n + n / 2;
    int lx = (int)((p->lake_x_m / p->size_m + 0.5f) * (float)n);
    int ly = (int)((p->lake_y_m / p->size_m + 0.5f) * (float)n);
    if (!seen || !q) die("out of memory");
    cp_terrain_slope(t->height, n, t->size_m, slope);
    for (int j = 0; j < n; j++) {
        for (int i = 0; i < n; i++) {
            int k = j * n + i;
            float h = t->height[k];
            float x = ((float)i + 0.5f) * cell - half;
            float y = ((float)j + 0.5f) * cell - half;
            sum += h;
            if (h < hmin) hmin = h;
            if (h > hmax) hmax = h;
            if (h > 0.f) land++;
            if (x * x + y * y <= flat_r * flat_r) {
                flat_n++;
                if (slope[k] < tan10) flat_ok++;
            }
        }
    }
    printf("n %d seed %" PRIu32 " h[%.2f, %.2f] mean %.2f land %.3f\n",
           n, p->seed, hmin, hmax, sum / (double)n / (double)n, (double)land / (double)n / (double)n);
    printf("valley_flat %d/%d (%.3f) within %.0fm slope<10deg, start %.2f m\n",
           flat_ok, flat_n, flat_n ? (double)flat_ok / (double)flat_n : 0.0, flat_r, t->height[centre]);
    if ((unsigned)lx < (unsigned)n && (unsigned)ly < (unsigned)n) {
        float bottom = t->height[ly * n + lx];
        float spill = sill(t, p, ly * n + lx, 0, seen, q);
        printf("lake bottom %.2f spill %.2f holds %.2f\n", bottom, spill, spill - bottom);
    }
    printf("river_gap_sill %.2f col_sill %.2f (lowest way from the start to the sea, with and without the gap)\n",
           sill(t, p, centre, 0, seen, q), sill(t, p, centre, 1, seen, q));
    free(seen);
    free(q);
    free(slope);
}

static int write_dump(const char *path, const CpTerrainParams *p, const CpTerrain *t, const CpTerrainWorkspace *ws)
{
    FILE *f = fopen(path, "wb");
    int8_t *dir;
    uint32_t version = CP_TERRAIN_VERSION;
    uint32_t flags = (p->droplets == 0 && p->thermal_iters == 0 && p->stream_iters == 0) ? 3u : 2u;
    int nn = p->n * p->n;
    char magic[8] = {'C', 'P', 'T', 'E', 'R', '1', '0', '\0'};
    if (!f) { perror(path); return 2; }
    dir = malloc((size_t)nn);
    if (!dir) die("out of memory");
    const int dx[8]={1,1,0,-1,-1,-1,0,1},dy[8]={0,1,1,1,0,-1,-1,-1};
    for(int i=0;i<nn;i++) {
        dir[i]=-1;
        if(ws->recv[i]>=0) for(int d=0;d<8;d++)
            if(ws->recv[i]==i+dy[d]*p->n+dx[d]) {dir[i]=(int8_t)d;break;}
    }
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
    /* Version 3 feature extension (flags bit 1); no struct padding on disk. */
    int failed=fwrite(t->material,1,(size_t)nn,f)!=(size_t)nn;
    const float landmark[]={t->volcano_x_m,t->volcano_y_m,t->volcano_radius_m,t->crater_radius_m};
    uint32_t count=(uint32_t)t->cave_count;
    failed|=fwrite(landmark,4,4,f)!=4 || fwrite(&count,4,1,f)!=1;
    for(int i=0;i<t->cave_count;i++) {
        const CpTerrainCave *v=&t->caves[i];
        const float fields[]={v->x_m,v->y_m,v->z_m,v->facing_x,v->facing_y,v->width_m,v->height_m,v->depth_m};
        failed|=fwrite(fields,4,8,f)!=8 || fwrite(&v->waterfall,4,1,f)!=1;
    }
    failed|=fclose(f)!=0;
    free(dir);
    return failed?2:0;
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
                "usage: terrain_cli hash|time|dump|stats --seed N --n N [--stream N] [--droplets N] [--thermal N] [--base] [--out PATH]\n");
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
    if (!strcmp(cmd,"features")) {
        int counts[6]={0};for(int i=0;i<p.n*p.n;i++)counts[t.material[i]]++;
        printf("{\"seed\":%u,\"volcano\":[%.6f,%.6f,%.6f,%.6f],\"materials\":[%d,%d,%d,%d,%d,%d],\"caves\":[",
               p.seed,t.volcano_x_m,t.volcano_y_m,t.volcano_radius_m,t.crater_radius_m,
               counts[0],counts[1],counts[2],counts[3],counts[4],counts[5]);
        for(int i=0;i<t.cave_count;i++) {
            const CpTerrainCave *v=&t.caves[i];
            printf("%s{\"position\":[%.6f,%.6f,%.6f],\"facing\":[%.6f,%.6f],\"size\":[%.6f,%.6f,%.6f],\"waterfall\":%u}",
                   i?",":"",v->x_m,v->y_m,v->z_m,v->facing_x,v->facing_y,v->width_m,v->height_m,v->depth_m,v->waterfall);
        }
        puts("]}");return 0;
    }
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
        return write_dump(path, &p, &t, &ws);
    }
    die("unknown command");
    return 2;
}
