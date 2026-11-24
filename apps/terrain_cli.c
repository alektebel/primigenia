/* Terrain dump, hash and timing. Malloc lives here, not in core. */
#include "cpore/terrain.h"
#include "cpore/island.h"

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
    {   float lay = arg_f(argc, argv, "--layout", p->layout);
        if (lay >= 1.f) cp_terrain_layout_apply((int)(lay + 0.5f), p);   /* A83: nest radius, erosion strength; flags below still win */
    }
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
    p->rivers=arg_f(argc,argv,"--rivers",p->rivers);
    p->layout=arg_f(argc,argv,"--layout",p->layout);
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

static CpIslandDesc island;         /* --desc FILE: an ISL1 blob (core/include/cpore/island.h) */
static int have_desc, shape_only;   /* shape_only: --base with --desc runs cp_terrain_shape_desc (no erosion whatever the desc recommends) */
static int want_climate;   /* --climate */

static int run_gen(const CpTerrainParams *p, CpTerrain *t, CpTerrainWorkspace *ws, double *sec)
{
    double t0 = now_s();
    int rc = have_desc ? (shape_only ? cp_terrain_shape_desc(p, &island, t, ws, NULL, NULL) : cp_terrain_generate_desc(p, &island, t, ws, NULL, NULL)) : cp_terrain_generate(p, t, ws, NULL, NULL);
    *sec = now_s() - t0;
    return rc;
}

static void setup(const CpTerrainParams *p, CpTerrain *t, CpTerrainWorkspace *ws)
{
    memset(t,0,sizeof *t);
    t->material=calloc((size_t)p->n*p->n,1);if(!t->material)die("out of memory");
    t->river=calloc((size_t)p->n*p->n,1);if(!t->river)die("out of memory");
    t->height = falloc(p->n);
    t->flow = falloc(p->n);
    t->sediment = falloc(p->n);
    ws->scratch = falloc(p->n);
    ws->recv = ialloc(p->n);
    ws->ups = ialloc(p->n);
    ws->queue = ialloc(p->n);
    if (have_desc && want_climate && p->n >= 64) {   /* --climate: the climate, biome and veg maps (island.h descs only) */
        size_t nn = (size_t)p->n * (size_t)p->n, wf = cp_terrain_climate_work_floats();
        t->climate = calloc((size_t)CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N * 4, 1);
        t->biome = calloc(nn, 1);
        t->veg = calloc(nn * 4, 1);
        ws->climate_work = calloc(wf, sizeof(float));
        if (!t->climate || !t->biome || !t->veg || !ws->climate_work) die("out of memory");
    }
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
    /* v4 trailer: the river class map (n*n bytes) after the caves; older readers stop before it. */
    failed|=t->river && fwrite(t->river,1,(size_t)nn,f)!=(size_t)nn;
    failed|=fclose(f)!=0;
    free(dir);
    return failed?2:0;
}


/* A83 design maps: PPM shaded relief, PGM slope classes and PGM reachability from the nest (origin).
 * classes: 0 sea or deep river, 1 <30 deg, 2 30..45, 3 45..51.6, 4 steeper than 51.6, 5 shallow river or pond.
 * reach: 0 none, 1 plain body (51.6 deg grip, A66), 2 with climbing parts (75 deg) only. */
static void write_pnm(const char *path, const char *magic, int n, const uint8_t *px, int ch)
{
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); exit(2); }
    fprintf(f, "%s\n%d %d\n255\n", magic, n, n);
    if (fwrite(px, (size_t)ch, (size_t)n * (size_t)n, f) != (size_t)n * (size_t)n) die("short write");
    fclose(f);
}

static int flood(const uint8_t *cls, const float *slope, const CpTerrain *t, int n, float tan_limit, uint8_t *mark, int *q)
{
    int qh = 0, qt = 0, start = (n / 2) * n + n / 2, count = 0;
    q[qt++] = start;
    mark[start] = 1;
    while (qh < qt) {
        int c = q[qh++], x = c % n, y = c / n;
        count++;
        for (int d = 0; d < 8; d++) {
            static const int ox[8] = {1, 1, 0, -1, -1, -1, 0, 1}, oy[8] = {0, 1, 1, 1, 0, -1, -1, -1};
            int nx = x + ox[d], ny = y + oy[d], ni;
            if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
            ni = ny * n + nx;
            if (mark[ni] || cls[ni] == 0 || slope[ni] > tan_limit) continue;
            mark[ni] = 1;
            q[qt++] = ni;
        }
    }
    return count;
}

static void maps(const CpTerrain *t, const CpTerrainParams *p, const char *prefix)
{
    int n = t->n, nn = n * n;
    float cell = t->size_m / (float)n;
    float *slope = falloc(n);
    uint8_t *rgb = malloc((size_t)nn * 3), *shade = malloc(nn), *cls = malloc(nn), *plain = calloc(nn, 1), *climb = calloc(nn, 1), *reach = calloc(nn, 1);
    int *q = malloc(sizeof(int) * (size_t)nn);
    char path[1024];
    const float tan30 = 0.57735f, tan45 = 1.f, tan516 = 1.2608f, tan75 = 3.7321f;
    int land = 0, plain_n, climb_n;
    if (!rgb || !shade || !cls || !plain || !climb || !reach || !q) die("out of memory");
    cp_terrain_slope(t->height, n, t->size_m, slope);
    for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) {
        int k = j * n + i, i0 = i ? i - 1 : i, i1 = i < n - 1 ? i + 1 : i, j0 = j ? j - 1 : j, j1 = j < n - 1 ? j + 1 : j;
        float h = t->height[k];
        float gx = (t->height[j * n + i1] - t->height[j * n + i0]) / ((float)(i1 - i0) * cell);
        float gy = (t->height[j1 * n + i] - t->height[j0 * n + i]) / ((float)(j1 - j0) * cell);
        float nz = 1.f / sqrtf(1.f + 1.96f * (gx * gx + gy * gy)), nx = -1.4f * gx * nz, ny = -1.4f * gy * nz;
        float lit = nx * -0.45f + ny * -0.55f + nz * 0.70f;
        int rc = t->river ? (t->river[k] & 3) : 0;
        float r, g, b, sh;
        uint8_t c;
        lit = lit < 0.f ? 0.f : lit > 1.f ? 1.f : lit;
        sh = 0.25f + 0.85f * lit;
        shade[k] = (uint8_t)(255.f * (sh > 1.f ? 1.f : sh));
        if (h <= 0.f) {
            float dp = h < -24.f ? 1.f : -h / 24.f;
            r = 40.f - 18.f * dp; g = 90.f - 30.f * dp; b = 130.f - 25.f * dp; sh = 0.85f + 0.15f * lit;
            if (h > -12.f) { float a = (h + 12.f) / 12.f; r = 40.f + 40.f * a; g = 140.f + 70.f * a; b = 175.f + 20.f * a; }   /* warm shallows: reefs */
            else if (h < -60.f) { float a = h < -140.f ? 1.f : (-60.f - h) / 80.f; r = 24.f - 14.f * a; g = 70.f - 40.f * a; b = 112.f - 50.f * a; }   /* abyss */
            c = 0;
        } else {
            float u = h / 420.f; u = u > 1.f ? 1.f : u;
            if (h < 7.f) { r = 205.f; g = 190.f; b = 140.f; }
            else if (u < 0.12f) { r = 96.f + 40.f * u / 0.12f; g = 140.f - 10.f * u / 0.12f; b = 74.f; }
            else if (u < 0.45f) { float a = (u - 0.12f) / 0.33f; r = 136.f + 30.f * a; g = 130.f + 5.f * a; b = 74.f + 40.f * a; }
            else if (u < 0.85f) { float a = (u - 0.45f) / 0.40f; r = 166.f + 10.f * a; g = 135.f + 25.f * a; b = 114.f + 50.f * a; }
            else { r = 235.f; g = 238.f; b = 242.f; }
            if (t->material[k] == CP_TERR_MAT_ROCK || t->material[k] == CP_TERR_MAT_SCREE) { r = r * 0.55f + 78.f; g = g * 0.55f + 70.f; b = b * 0.55f + 64.f; }
            c = slope[k] < tan30 ? 1 : slope[k] < tan45 ? 2 : slope[k] < tan516 ? 3 : 4;
            if (rc == CP_TERR_RIVER_DEEP) { c = 0; r = 40.f; g = 98.f; b = 150.f; sh = 0.9f; }
            else if (rc == CP_TERR_RIVER_SHALLOW || rc == CP_TERR_RIVER_STREAM) { r = 80.f; g = 150.f; b = 190.f; sh = 0.95f; if (rc == CP_TERR_RIVER_SHALLOW) c = 5; }
            land++;
        }
        cls[k] = c;
        rgb[k * 3] = (uint8_t)(r * sh > 255.f ? 255.f : r * sh);
        rgb[k * 3 + 1] = (uint8_t)(g * sh > 255.f ? 255.f : g * sh);
        rgb[k * 3 + 2] = (uint8_t)(b * sh > 255.f ? 255.f : b * sh);
    }
    plain_n = flood(cls, slope, t, n, tan516, plain, q);
    climb_n = flood(cls, slope, t, n, tan75, climb, q);
    for (int k = 0; k < nn; k++) reach[k] = plain[k] ? 1 : climb[k] ? 2 : 0;
    snprintf(path, sizeof path, "%s-relief.ppm", prefix); write_pnm(path, "P6", n, rgb, 3);
    snprintf(path, sizeof path, "%s-shade.pgm", prefix); write_pnm(path, "P5", n, shade, 1);
    snprintf(path, sizeof path, "%s-cls.pgm", prefix); write_pnm(path, "P5", n, cls, 1);
    snprintf(path, sizeof path, "%s-reach.pgm", prefix); write_pnm(path, "P5", n, reach, 1);
    if (t->climate_n > 0) {   /* --climate on a desc: the raw maps next to the relief (tools/island/maps.py --climate reads them) */
        FILE *f;
        snprintf(path, sizeof path, "%s-climate.rgba", prefix);
        f = fopen(path, "wb"); if (!f) { perror(path); exit(2); }
        fwrite(t->climate, 4, (size_t)t->climate_n * (size_t)t->climate_n, f); fclose(f);
        snprintf(path, sizeof path, "%s-height.f32", prefix);
        f = fopen(path, "wb"); if (!f) { perror(path); exit(2); }
        fwrite(t->height, 4, (size_t)nn, f); fclose(f);
        snprintf(path, sizeof path, "%s-biome.pgm", prefix); write_pnm(path, "P5", n, t->biome, 1);
        snprintf(path, sizeof path, "%s-veg.rgba", prefix);
        f = fopen(path, "wb"); if (!f) { perror(path); exit(2); }
        fwrite(t->veg, 4, (size_t)nn, f); fclose(f);
    }
    printf("{\"land_cells\":%d,\"plain_reach\":%d,\"climb_reach\":%d,\"cell_m\":%.3f,\"climate_n\":%d,\"climate_hash\":\"%016" PRIx64 "\"}\n", land, plain_n, climb_n, (double)cell, t->climate_n, cp_terrain_climate_hash(t));
    (void)p;
    free(slope); free(rgb); free(shade); free(cls); free(plain); free(climb); free(reach); free(q);
}

/* L0/L1 look labs: a small square crop of the generated terrain for the browser (web/gaitlab/forest.html).
 * Layout (little endian): "CPCROP1\0", u32 seed, u32 m (cells per side), f32 cell_m, f32 x0_m, f32 z0_m (world x and z of cell
 * (0,0) centre, nest at the origin, z south), then height f32[m*m], flow f32[m*m], material u8[m*m], river u8[m*m]. */
static int write_crop(const char *path, const char *spec, const CpTerrainParams *p, const CpTerrain *t)
{
    float cx, cz, size;
    if (sscanf(spec, "%f,%f,%f", &cx, &cz, &size) != 3 || size < 8.f || size > 4000.f) die("--crop needs X,Z,SIZE_M (world metres)");
    const float cell = p->size_m / (float)p->n, half = p->size_m * 0.5f;
    int i0 = (int)floorf((cx - size * 0.5f + half) / cell), j0 = (int)floorf((cz - size * 0.5f + half) / cell);
    int m = (int)ceilf(size / cell);
    if (i0 < 0 || j0 < 0 || i0 + m > p->n || j0 + m > p->n) die("crop outside the terrain");
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return 2; }
    const char magic[8] = {'C', 'P', 'C', 'R', 'O', 'P', '1', '\0'};
    uint32_t seed = p->seed, mm = (uint32_t)m;
    float hdr[3] = {cell, ((float)i0 + 0.5f) * cell - half, ((float)j0 + 0.5f) * cell - half};
    int bad = fwrite(magic, 1, 8, f) != 8 || fwrite(&seed, 4, 1, f) != 1 || fwrite(&mm, 4, 1, f) != 1 || fwrite(hdr, 4, 3, f) != 3;
    for (int pass = 0; pass < 4 && !bad; pass++)
        for (int j = 0; j < m && !bad; j++) {
            size_t row = (size_t)(j0 + j) * (size_t)p->n + (size_t)i0;
            if (pass == 0) bad = fwrite(t->height + row, 4, (size_t)m, f) != (size_t)m;
            else if (pass == 1) bad = fwrite(t->flow + row, 4, (size_t)m, f) != (size_t)m;
            else if (pass == 2) bad = fwrite(t->material + row, 1, (size_t)m, f) != (size_t)m;
            else bad = fwrite(t->river ? t->river + row : t->material + row, 1, (size_t)m, f) != (size_t)m;
        }
    if (fclose(f) || bad) { fprintf(stderr, "short write %s\n", path); return 2; }
    printf("crop %d cells of %.4f m, x0 %.3f z0 %.3f\n", m, (double)cell, (double)hdr[1], (double)hdr[2]);
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
                "usage: terrain_cli hash|time|dump|stats --seed N --n N [--stream N] [--droplets N] [--thermal N] [--base] [--out PATH]\n");
        return 2;
    }
    cmd = argv[1];
    want_climate = has(argc, argv, "--climate");
    cp_terrain_params_default(&p);
    {   /* --desc FILE: generate that island. n is the desc's unless --n is given; the desc then sets size, nest, lake, erosion */
        const char *df = arg_s(argc, argv, "--desc");
        if (df) {
            static uint8_t blob[1 << 20]; FILE *fp = fopen(df, "rb"); size_t len; int drc;
            if (!fp) die("cannot open the --desc file");
            len = fread(blob, 1, sizeof blob, fp); fclose(fp);
            drc = cp_island_parse(blob, len, &island);
            if (drc != CP_TERR_OK) { fprintf(stderr, "bad island blob %d\n", drc); return 2; }
            have_desc = 1; shape_only = has(argc, argv, "--base");
            p.n = island.n;
            apply_overrides(&p, argc, argv);
            cp_island_apply(&island, &p);
        } else apply_overrides(&p, argc, argv);
    }
    rc = cp_terrain_validate(&p);
    if (rc != CP_TERR_OK) {
        fprintf(stderr, "bad params %d\n", rc);
        return 2;
    }
    setup(&p, &t, &ws);
    {   /* --cal SLOT=VALUE (repeatable): override one climate calibration slot (island.h CP_ISL_CAL_*) */
        for (int i = 2; i + 1 < argc; i++) if (!strcmp(argv[i], "--cal") && have_desc) {
            int slot = atoi(argv[i + 1]); const char *eq = strchr(argv[i + 1], '=');
            if (!eq || slot < 0 || (slot >= CP_ISL_CALIB_N && slot != 100 && slot != 101)) die("--cal SLOT=VALUE");
            if (slot == 100) island.clim_scale_h_pm = atoi(eq + 1);           /* experiments: the climate block's own scales */
            else if (slot == 101) island.clim_scale_z_pm = atoi(eq + 1);
            else { island.has_calib = 1; island.calib[slot] = atoi(eq + 1); }
        }
    }
    if (arg_s(argc, argv, "--height") && have_desc) {   /* skip the shape: read the final heights (a -height.f32 from `maps --climate`) and run the climate only */
        FILE *hf = fopen(arg_s(argc, argv, "--height"), "rb"); size_t cnt = (size_t)p.n * (size_t)p.n;
        double t0 = now_s();
        if (!hf || fread(t.height, 4, cnt, hf) != cnt) die("cannot read the --height file");
        fclose(hf);
        t.n = p.n; t.size_m = p.size_m;
        rc = cp_terrain_climate(&p, &island, &t, &ws);
        sec = now_s() - t0;
    } else
    rc = run_gen(&p, &t, &ws, &sec);
    if (rc != CP_TERR_OK) {
        fprintf(stderr, "generate %d\n", rc);
        return 2;
    }
    t.n = p.n;
    t.size_m = p.size_m;
    if (!strcmp(cmd, "layout-json")) {
        static char buf[65536];
        if (have_desc) { if (!cp_island_meta_json(&island, buf, sizeof buf)) die("island meta too long"); puts(buf); return 0; }
        if (!cp_terrain_layout_json((int)(p.layout + 0.5f), buf, sizeof buf)) die("unknown layout");
        puts(buf);
        return 0;
    }
    if (!strcmp(cmd, "maps")) {
        const char *prefix = arg_s(argc, argv, "--out");
        if (!prefix) die("maps needs --out PREFIX");
        maps(&t, &p, prefix);
        return 0;
    }
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
        if (t.climate_n > 0) printf("climate %016" PRIx64 "\n", cp_terrain_climate_hash(&t));
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
    if (!strcmp(cmd, "crop")) {
        const char *path = arg_s(argc, argv, "--out"), *spec = arg_s(argc, argv, "--crop");
        if (!path || !spec) die("crop needs --crop X,Z,SIZE and --out");
        return write_crop(path, spec, &p, &t);
    }
    die("unknown command");
    return 2;
}
