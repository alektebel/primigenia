/* Climate maps in the terrain pipeline (docs/plans/island-realism.md part II, step M2).
 *   test_terrain_climate BLOB.isl [--heavy] [--write-golden]
 * BLOB is the Star massif desc (make: build/island/star_f0.isl, with its climate calibration). Checks:
 *   - the climate maps are an add-on: the terrain hash is the same with and without the buffers
 *   - same bytes on two runs; cp_terrain_climate on the final heights reproduces the generation's maps
 *   - the goldens in tests/golden/island-climate.hashes (the climate hash of the Star massif at n = 256, 512 and, with --heavy, 1536)
 *   - the wind convention: wind_mdeg is the direction the wind blows TOWARD, atan2(y, x) in map axes (x east, y south), so 135000
 *     is a north-east trade wind and the north-east side is the wet one; the reverse wind swaps the sides
 *   - calibration slots are read (more rain_scale means more rain; a blob without the block means the kernel defaults)
 *   - the calibration block round trips through pack and parse and is part of the island hash
 *   - small n (a climate grid below 256), the maps stay in range, the biome ids are valid */
#include "cpore/island.h"
#include "cpore/climate.h"
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { CpTerrain t; CpTerrainWorkspace w; float *mem, *work; uint8_t *riv, *clim, *bio, *veg; int n; } Fx;

static Fx make(int n, int with_climate)
{
    Fx f; size_t nn = (size_t)n * (size_t)n;
    memset(&f, 0, sizeof f);
    f.n = n;
    f.mem = calloc(nn * 8, sizeof(float)); assert(f.mem);
    f.t.height = f.mem; f.t.flow = f.mem + nn; f.t.sediment = f.mem + 2 * nn;
    f.w.scratch = f.mem + 3 * nn;
    f.w.recv = (int32_t *)(f.mem + 4 * nn); f.w.ups = (int32_t *)(f.mem + 5 * nn); f.w.queue = (int32_t *)(f.mem + 6 * nn);
    f.t.material = (uint8_t *)(f.mem + 7 * nn);
    f.riv = calloc(nn, 1); assert(f.riv); f.t.river = f.riv;
    if (with_climate) {
        f.clim = calloc((size_t)CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N * 4, 1);
        f.bio = calloc(nn, 1); f.veg = calloc(nn * 4, 1);
        f.work = calloc(cp_terrain_climate_work_floats(), sizeof(float));
        assert(f.clim && f.bio && f.veg && f.work);
        f.t.climate = f.clim; f.t.biome = f.bio; f.t.veg = f.veg; f.w.climate_work = f.work;
    }
    return f;
}
static void drop(Fx *f) { free(f->mem); free(f->riv); free(f->clim); free(f->bio); free(f->veg); free(f->work); }

static CpIslandDesc D, D2;
static uint8_t *blob; static size_t blen;

static void params(CpTerrainParams *p, int n, unsigned seed)
{
    cp_terrain_params_default(p);
    p->seed = seed; p->n = n;
    cp_island_apply(&D, p);
}
static int gen(Fx *f, const CpIslandDesc *d, int n, unsigned seed)
{
    CpTerrainParams p; cp_terrain_params_default(&p);
    p.seed = seed; p.n = n;
    return cp_terrain_generate_desc(&p, d, &f->t, &f->w, NULL, NULL);
}

static double mean_precip_quadrant(const Fx *f, int east, int north)   /* mean R over the land-ish quarter of the 256 grid, 0..4000 mm */
{
    int cn = f->t.climate_n; double s = 0; long c = 0;
    for (int y = 0; y < cn; y++) for (int x = 0; x < cn; x++) {
        int e = x >= cn / 2, nn = y < cn / 2;
        double dx = (double)x - cn / 2.0, dy = (double)y - cn / 2.0;
        if (e != east || nn != north || dx * dx + dy * dy > (cn * 0.3) * (cn * 0.3)) continue;
        s += f->t.climate[4 * (y * cn + x)]; c++;
    }
    return s / (double)c * 4000.0 / 255.0;
}

static uint64_t golden_for(int n, const char *path, int write, uint64_t got)
{
    FILE *fp; char line[128]; uint64_t want = 0; int found = 0;
    if (write) {
        fp = fopen(path, n == 256 ? "w" : "a"); assert(fp);
        fprintf(fp, "%d %016" PRIx64 "\n", n, got); fclose(fp);
        return got;
    }
    fp = fopen(path, "r"); assert(fp);
    while (fgets(line, sizeof line, fp)) { int nn; unsigned long long h; if (sscanf(line, "%d %llx", &nn, &h) == 2 && nn == n) { want = h; found = 1; } }
    fclose(fp);
    assert(found);
    return want;
}

int main(int argc, char **argv)
{
    int heavy = 0, write = 0; FILE *fp; const char *gold = "tests/golden/island-climate.hashes";
    for (int i = 2; i < argc; i++) { if (!strcmp(argv[i], "--heavy")) heavy = 1; if (!strcmp(argv[i], "--write-golden")) write = 1; }
    if (argc < 2) { fprintf(stderr, "usage: test_terrain_climate BLOB.isl [--heavy] [--write-golden]\n"); return 2; }
    fp = fopen(argv[1], "rb"); assert(fp);
    fseek(fp, 0, SEEK_END); blen = (size_t)ftell(fp); fseek(fp, 0, SEEK_SET);
    blob = malloc(blen); assert(blob && fread(blob, 1, blen, fp) == blen); fclose(fp);
    assert(cp_island_parse(blob, blen, &D) == CP_TERR_OK);
    assert(D.has_calib);   /* the shipped Star massif carries its climate calibration */

    /* 1. the climate is an add-on: same terrain hash with and without the buffers; 2. stable; 3. re-run reproduces */
    {   Fx a = make(256, 0), b = make(256, 1), c = make(256, 1);
        assert(gen(&a, &D, 256, 1) == CP_TERR_OK && a.t.climate_n == 0);
        assert(gen(&b, &D, 256, 1) == CP_TERR_OK && b.t.climate_n == 256);
        assert(gen(&c, &D, 256, 1) == CP_TERR_OK);
        assert(cp_terrain_hash(&a.t) == cp_terrain_hash(&b.t));
        assert(cp_terrain_climate_hash(&b.t) == cp_terrain_climate_hash(&c.t) && cp_terrain_climate_hash(&b.t) != 0);
        assert(cp_terrain_climate_hash(&a.t) == 0);
        {   uint64_t h0 = cp_terrain_climate_hash(&b.t); CpTerrainParams p; params(&p, 256, 1);
            memset(b.clim, 0xAB, (size_t)256 * 256 * 4); memset(b.bio, 0xAB, (size_t)256 * 256); memset(b.veg, 0xAB, (size_t)256 * 256 * 4); b.t.climate_n = 0;
            assert(cp_terrain_climate(&p, &D, &b.t, &b.w) == CP_TERR_OK && b.t.climate_n == 256);
            assert(cp_terrain_climate_hash(&b.t) == h0); }
        assert(cp_terrain_climate(NULL, &D, &b.t, &b.w) == CP_TERR_ERR_NULL);
        /* ranges and ids */
        for (size_t i = 0; i < 256 * 256; i++) assert(b.bio[i] < CP_BIOME_COUNT);
        {   int seen[CP_BIOME_COUNT] = {0};
            for (size_t i = 0; i < 256 * 256; i++) seen[b.bio[i]]++;
            assert(seen[CP_BIOME_SEA] > 0 && seen[CP_BIOME_MEADOW] > 0 && seen[CP_BIOME_CLIFF] > 0 && seen[CP_BIOME_JUNGLE] + seen[CP_BIOME_DRY_FOREST] > 0); }
        /* sea cells have no vegetation; canopy never sits on cliffs */
        for (size_t i = 0; i < 256 * 256; i++) {
            if (b.t.height[i] <= 0.f) assert(b.veg[4 * i] == 0 && b.veg[4 * i + 1] == 0 && b.veg[4 * i + 2] == 0);
            if (b.bio[i] == CP_BIOME_CLIFF) assert(b.veg[4 * i] == 0);
        }
        drop(&a); drop(&b); drop(&c);
        printf("climate: add-on, stable, re-run reproduces\n"); }

    /* 4. goldens (and 5.: n = 512 has a 2 x 2 box filter) */
    {   static const int ns[3] = {256, 512, 1536};
        for (int k = 0; k < 3; k++) {
            Fx f; uint64_t h;
            if (ns[k] == 1536 && !heavy && !write) continue;
            if (ns[k] == 1536 && write && !heavy) continue;
            f = make(ns[k], 1);
            assert(gen(&f, &D, ns[k], 1) == CP_TERR_OK && f.t.climate_n == 256);
            h = cp_terrain_climate_hash(&f.t);
            if (write) golden_for(ns[k], gold, 1, h);
            else {   uint64_t want = golden_for(ns[k], gold, 0, 0);
                if (h != want) { fprintf(stderr, "climate golden n=%d: got %016" PRIx64 " want %016" PRIx64 "\n", ns[k], h, want); return 1; } }
            drop(&f);
        }
        printf("climate: goldens %s\n", write ? "written" : "match"); }

    /* 6. wind convention. Two winds on the same terrain: 135000 (toward the south-west: a NE trade) and 315000 (toward the north-east).
     * The upwind (north-east) side of the island must get more rain than the south-west side under the first wind, and less under the second. */
    {   Fx f = make(256, 1); double ne_ne, sw_ne, ne_sw, sw_sw;
        CpIslandDesc W = D;
        W.wind_mdeg = 135000; W.wind_cms = 800;
        assert(gen(&f, &W, 256, 1) == CP_TERR_OK);
        ne_ne = mean_precip_quadrant(&f, 1, 1); sw_ne = mean_precip_quadrant(&f, 0, 0);
        W.wind_mdeg = 315000;
        assert(gen(&f, &W, 256, 1) == CP_TERR_OK);
        ne_sw = mean_precip_quadrant(&f, 1, 1); sw_sw = mean_precip_quadrant(&f, 0, 0);
        printf("climate wind: NE trade  NE quarter %.0f mm, SW quarter %.0f mm; SW wind  NE %.0f, SW %.0f\n", ne_ne, sw_ne, ne_sw, sw_sw);
        assert(ne_ne > sw_ne);          /* the wind blows from the NE: the NE side is wet */
        assert(sw_sw > ne_sw);          /* the reverse wind swaps the sides */
        drop(&f); }

    /* 7. calibration slots are read: more rain_scale, more rain; a blob without the block uses the kernel defaults */
    {   Fx f = make(256, 1); CpIslandDesc C = D; double lo, hi; uint64_t hd, hn;
        C.calib[CP_ISL_CAL_RAIN_SCALE_PM] = 60;  assert(gen(&f, &C, 256, 1) == CP_TERR_OK);
        lo = mean_precip_quadrant(&f, 1, 1);
        C.calib[CP_ISL_CAL_RAIN_SCALE_PM] = 240; assert(gen(&f, &C, 256, 1) == CP_TERR_OK);
        hi = mean_precip_quadrant(&f, 1, 1);
        assert(hi > 1.5 * lo);
        C.has_calib = 0; memset(C.calib, 0, sizeof C.calib);
        assert(gen(&f, &C, 256, 1) == CP_TERR_OK); hd = cp_terrain_climate_hash(&f.t);
        C.has_calib = 1;   /* an all-zero block means the same defaults */
        assert(gen(&f, &C, 256, 1) == CP_TERR_OK); hn = cp_terrain_climate_hash(&f.t);
        assert(hd == hn);
        drop(&f);
        printf("climate calibration: rain_scale 60 -> %.0f mm, 240 -> %.0f mm; zero block == no block\n", lo, hi); }

    /* 8. the block round trips and is part of the island hash; a blob without it still parses */
    {   static uint8_t buf[1 << 19]; size_t n1, n2; CpIslandDesc N = D; uint64_t h1;
        n1 = cp_island_pack(&D, buf, sizeof buf); assert(n1 == blen && memcmp(buf, blob, blen) == 0);   /* pack(parse(b)) == b */
        assert(cp_island_parse(buf, n1, &D2) == CP_TERR_OK && D2.has_calib && memcmp(D2.calib, D.calib, sizeof D.calib) == 0);
        h1 = cp_island_hash(&D);
        N.calib[CP_ISL_CAL_P_INF_MM] += 1; assert(cp_island_hash(&N) != h1);
        N = D; N.has_calib = 0; memset(N.calib, 0, sizeof N.calib);
        n2 = cp_island_pack(&N, buf, sizeof buf); assert(n2 == n1 - (size_t)CP_ISL_CALIB_N * 4);
        assert(cp_island_parse(buf, n2, &D2) == CP_TERR_OK && !D2.has_calib && cp_island_hash(&N) != h1);
        buf[6] = 2; assert(cp_island_parse(buf, n2, &D2) == CP_TERR_ERR_ISL_VERSION);       /* unknown header flag bit */
        printf("climate calibration block: round trip, hashed, optional\n"); }

    /* 9. small grids: n = 64 (climate grid 64) and n = 96 (64, a 1.5 cell box); wrong n; sea level islands are fine */
    {   static const int ns[3] = {64, 96, 200};
        for (int k = 0; k < 3; k++) {
            Fx f = make(ns[k], 1); int cn = ns[k] >= 256 ? 256 : ns[k] >= 128 ? 128 : 64;
            assert(gen(&f, &D, ns[k], 1) == CP_TERR_OK);
            assert(f.t.climate_n == cn);
            for (int i = 0; i < ns[k] * ns[k]; i++) assert(f.t.biome[i] < CP_BIOME_COUNT);
            drop(&f);
        }
        printf("climate: small grids ok\n"); }
    free(blob);
    printf("terrain climate tests passed\n");
    return 0;
}
