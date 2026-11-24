/* The shipped island (docs/plans/island-realism.md step F4, DESIGN A101): the Star massif frozen as data.
 *   test_island_star [FILE.isl] [--heavy] [--write-golden]
 * Checks:
 *   - cp_island_star_massif() (the blob compiled in from core/src/islands/star_massif.inc) parses, hashes, and is byte for byte
 *     the godot/game/data/islands/star_massif.isl file (default path), so the extension and the C core load the same island
 *   - tests/golden/island-star-<seed>.hash: one line per size, "n terrain-hash climate-hash" (hex). Seeds 1, 7, 42 at n 512; seed 1
 *     also at n 1536 (--heavy, about 10 s). The terrain hash is cp_terrain_hash (v5, mixes the desc hash); the climate hash covers the
 *     climate, biome and veg maps. Regenerate on purpose with --write-golden (never in the test run). */
#include "cpore/island.h"
#include "cpore/climate.h"
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { CpTerrain t; CpTerrainWorkspace w; float *mem, *work; uint8_t *riv, *clim, *bio, *veg; } Fx;

static Fx make(int n)
{
    Fx f; size_t nn = (size_t)n * (size_t)n;
    memset(&f, 0, sizeof f);
    f.mem = calloc(nn * 8, sizeof(float)); assert(f.mem);
    f.t.height = f.mem; f.t.flow = f.mem + nn; f.t.sediment = f.mem + 2 * nn;
    f.w.scratch = f.mem + 3 * nn;
    f.w.recv = (int32_t *)(f.mem + 4 * nn); f.w.ups = (int32_t *)(f.mem + 5 * nn); f.w.queue = (int32_t *)(f.mem + 6 * nn);
    f.t.material = (uint8_t *)(f.mem + 7 * nn);
    f.riv = calloc(nn, 1); assert(f.riv); f.t.river = f.riv;
    f.clim = calloc((size_t)CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N * 4, 1);
    f.bio = calloc(nn, 1); f.veg = calloc(nn * 4, 1);
    f.work = calloc(cp_terrain_climate_work_floats(), sizeof(float));
    assert(f.clim && f.bio && f.veg && f.work);
    f.t.climate = f.clim; f.t.biome = f.bio; f.t.veg = f.veg; f.w.climate_work = f.work;
    return f;
}
static void drop(Fx *f) { free(f->mem); free(f->riv); free(f->clim); free(f->bio); free(f->veg); free(f->work); }

static CpIslandDesc D;

static int one(const char *path, int seed, int n, int write, FILE *out, int *wrote)
{
    Fx f = make(n); CpTerrainParams p; uint64_t th, ch, wt = 0, wc = 0; int found = 0;
    cp_terrain_params_default(&p); p.seed = (uint32_t)seed; p.n = n;
    assert(cp_terrain_generate_desc(&p, &D, &f.t, &f.w, NULL, NULL) == CP_TERR_OK);
    th = cp_terrain_hash(&f.t); ch = cp_terrain_climate_hash(&f.t);
    assert(th != 0 && ch != 0 && f.t.island_hash == cp_island_hash(&D));
    if (write) { fprintf(out, "%d %016" PRIx64 " %016" PRIx64 "\n", n, th, ch); (*wrote)++; drop(&f); return 0; }
    {   FILE *g = fopen(path, "r"); char line[128]; int ln; unsigned long long a, b;
        if (!g) { fprintf(stderr, "missing golden %s\n", path); drop(&f); return 1; }
        while (fgets(line, sizeof line, g)) if (sscanf(line, "%d %llx %llx", &ln, &a, &b) == 3 && ln == n) { wt = a; wc = b; found = 1; }
        fclose(g); }
    if (!found || th != wt || ch != wc) {
        fprintf(stderr, "island-star golden %s n=%d: got %016" PRIx64 " %016" PRIx64 " want %016" PRIx64 " %016" PRIx64 "\n", path, n, th, ch, wt, wc);
        drop(&f); return 1;
    }
    printf("island-star seed %d n=%d: %016" PRIx64 " climate %016" PRIx64 " match\n", seed, n, th, ch);
    drop(&f); return 0;
}

int main(int argc, char **argv)
{
    const char *isl = "godot/game/data/islands/star_massif.isl"; int heavy = 0, write = 0, bad = 0;
    size_t len = 0; const uint8_t *blob = cp_island_star_massif(&len);
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--heavy")) heavy = 1; else if (!strcmp(argv[i], "--write-golden")) write = 1; else isl = argv[i];
    }
    assert(blob && len > 16);
    assert(cp_island_parse(blob, len, &D) == CP_TERR_OK);
    {   FILE *fp = fopen(isl, "rb"); uint8_t *buf = malloc(len + 1); size_t got;
        if (!fp || !buf) { fprintf(stderr, "cannot read %s\n", isl); return 1; }
        got = fread(buf, 1, len + 1, fp); fclose(fp);
        if (got != len || memcmp(buf, blob, len)) { fprintf(stderr, "%s differs from the blob compiled into libcpore (make island-pack)\n", isl); return 1; }
        free(buf); }
    printf("island-star: embedded blob %zu bytes == %s, desc hash %016" PRIx64 "\n", len, isl, cp_island_hash(&D));
    static const int seeds[3] = {1, 7, 42};
    for (int s = 0; s < 3; s++) {
        char path[96]; FILE *out = NULL; int wrote = 0;
        snprintf(path, sizeof path, "tests/golden/island-star-%d.hash", seeds[s]);
        if (write) { out = fopen(path, "w"); assert(out); }
        bad |= one(path, seeds[s], 512, write, out, &wrote);
        if (seeds[s] == 1 && (heavy || write)) {
            if (write && !heavy) { fprintf(stderr, "--write-golden needs --heavy (seed 1 also holds n = 1536)\n"); return 2; }
            bad |= one(path, 1, 1536, write, out, &wrote);
        }
        if (out) fclose(out);
    }
    return bad;
}
