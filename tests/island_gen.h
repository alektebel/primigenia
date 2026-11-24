/* Shared by the stage tests that run on a generated island (nav, routes, first quest, secrets).
 *   island_args(&argc, argv)           removes "--island star" (or "--island ring") from the arguments and returns 1 for star;
 *                                      the default is the layout-0 ring island until its variants are retired.
 *   island_generate(t, ws, p, seed, star, n)
 *                                      allocates the maps and generates the island: the ring island (cp_terrain_generate, n as given,
 *                                      0 = default) or the frozen Star massif (A101, the blob compiled into libcpore, n 1536 unless given,
 *                                      no climate maps: the tests do not read them). p comes back with the size the desc set.
 * B1 (island-realism plan): the star variants are the certified ones; the ring variants are retired in a later commit. */
#ifndef CPORE_TESTS_ISLAND_GEN_H
#define CPORE_TESTS_ISLAND_GEN_H
#include "cpore/island.h"
#include "cpore/terrain.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#define STAR_ISLAND_N 1536
static CpIslandDesc g_island_desc;

static int island_args(int *argc, char **argv)
{
    int star = 0;
    for (int i = 1; i + 1 < *argc; i++) {
        if (!strcmp(argv[i], "--island")) {
            star = !strcmp(argv[i + 1], "star");
            assert(star || !strcmp(argv[i + 1], "ring"));
            for (int k = i; k + 2 < *argc; k++) argv[k] = argv[k + 2];
            *argc -= 2;
            break;
        }
    }
    return star;
}

static void island_generate(CpTerrain *t, CpTerrainWorkspace *ws, CpTerrainParams *p, unsigned seed, int star, int n)
{
    size_t len = 0, cells;
    const uint8_t *blob = star ? cp_island_star_massif(&len) : NULL;
    cp_terrain_params_default(p);
    p->seed = seed;
    if (star) {
        assert(blob && cp_island_parse(blob, len, &g_island_desc) == CP_TERR_OK);
        p->n = n > 0 ? n : STAR_ISLAND_N;
        cp_island_apply(&g_island_desc, p);
    } else if (n > 0) {
        p->n = n;
    }
    cells = (size_t)p->n * (size_t)p->n;
    t->height = calloc(cells, 4); t->flow = calloc(cells, 4); t->sediment = calloc(cells, 4);
    t->material = calloc(cells, 1); t->river = calloc(cells, 1);
    ws->scratch = calloc(cells, 4); ws->recv = calloc(cells, 4); ws->ups = calloc(cells, 4); ws->queue = calloc(cells, 4);
    assert(t->height && t->flow && t->sediment && t->material && t->river && ws->scratch && ws->recv && ws->ups && ws->queue);
    if (star) assert(cp_terrain_generate_desc(p, &g_island_desc, t, ws, NULL, NULL) == CP_TERR_OK);
    else assert(!cp_terrain_generate(p, t, ws, NULL, NULL));
}
#endif
