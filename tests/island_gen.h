/* Shared by the stage tests that run on a generated island (nav, routes, first quest, secrets).
 *   island_args(&argc, argv)           removes "--island star" from the arguments; always returns 1 (the layout-0 ring variants of the stage
 *                                      tests were retired after B1 certified the star ones; "--island ring" is refused).
 *   island_generate(t, ws, p, seed, star, n)
 *                                      allocates the maps and generates the island: the ring island (cp_terrain_generate, n as given,
 *                                      0 = default) or the frozen Star massif (A101, the blob compiled into libcpore, n 1536 unless given,
 *                                      with the climate maps and the game-trail map, which the field's cover and trunks (M3) are made from).
 *                                      p comes back with the size the desc set.
 *   island_field(t, p, water_level, slow, bonus)
 *                                      the sealed CpStageField of a generated island: cover and trunks built from its climate maps (the star
 *                                      island; the ring island has none and gets a bare field), the cover tunings as given (the game ships 0, 0).
 * B1 (island-realism plan): the star variants are the certified ones. */
#ifndef CPORE_TESTS_ISLAND_GEN_H
#define CPORE_TESTS_ISLAND_GEN_H
#include "cpore/island.h"
#include "cpore/flora.h"
#include "cpore/terrain.h"
#include "cpore/world.h"
#include <math.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#define STAR_ISLAND_N 1536
static CpIslandDesc g_island_desc;

static int island_args(int *argc, char **argv)
{
    int star = 1;
    for (int i = 1; i + 1 < *argc; i++) {
        if (!strcmp(argv[i], "--island")) {
            assert(!strcmp(argv[i + 1], "star"));
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
    if (star) {
        t->climate = calloc((size_t)CP_TERRAIN_CLIMATE_N * CP_TERRAIN_CLIMATE_N, 4);
        t->biome = calloc(cells, 1); t->veg = calloc(cells, 4); t->trail = calloc(cells, 1);
        ws->climate_work = calloc(cp_terrain_climate_work_floats(), sizeof(float));
        assert(t->climate && t->biome && t->veg && t->trail && ws->climate_work);
        assert(cp_terrain_generate_desc(p, &g_island_desc, t, ws, NULL, NULL) == CP_TERR_OK);
        assert(t->climate_n > 0);
    }
    else assert(!cp_terrain_generate(p, t, ws, NULL, NULL));
}

static CpFieldStore g_island_store;
/* The flora maps of a generated star island (trail: the map the field's cover and trunks use, NULL = no game trails). cave must hold 2 * CP_TERRAIN_CAVES_MAX floats. */
static CpFloraMaps island_maps(const CpTerrain *t, const CpTerrainParams *p, const float *level, const uint8_t *trail, float *cave)
{
    for (int i = 0; i < t->cave_count; i++) { cave[2 * i] = t->caves[i].x_m; cave[2 * i + 1] = t->caves[i].y_m; }
    return (CpFloraMaps){p->n, t->climate_n, p->size_m, p->seed, t->height, level, t->biome, t->veg, t->climate, t->river, trail, cave, t->cave_count};
}
static CpStageField island_field_ex(CpFieldStore *store, const CpTerrain *t, const CpTerrainParams *p, const float *level, const uint8_t *trail, float slow, float bonus)
{
    float cave[2 * CP_TERRAIN_CAVES_MAX];
    CpStageField f = {p->n, p->size_m, p->size_m / (float)p->n, p->size_m * .5f, t->height, level, 0};
    CpFloraMaps m = island_maps(t, p, level, trail, cave);
    assert(cp_field_build(&f, store, t->veg ? &m : NULL, cp_terrain_hash(t), slow, bonus, NULL, 0) == 0);
    return f;
}
static CpStageField island_field(const CpTerrain *t, const CpTerrainParams *p, const float *level, float slow, float bonus)
{
    return island_field_ex(&g_island_store, t, p, level, t->trail, slow, bonus);
}

/* The nest of the stage tests: the same rule as godot/game/stage/stage_setup.gd find_nest (B1). The origin if it is dry, gentle and 30 m
 * clear of any pond or sea cell, else the nearest such cell on rings of 5 m (32 directions, a = k*2pi/32, x = sin a * r, z = cos a * r).
 * w is any world with the field attached. The ring island keeps the origin (it passes the rule). */
#define NEST_TRUNK_CLEAR 12.f
static int island_dry(const CpStageWorld *w,float x,float z){return cp_stage_ground(w,x,z)>1.f&&cp_stage_water_depth(w,x,z)==0.f;}
static int island_nest_ok(const CpStageWorld *w,float x,float z){
    const float c=w->field->cell;
    if(!island_dry(w,x,z)||cp_stage_trunk_hit(w,x,z,NEST_TRUNK_CLEAR))return 0;   /* M3: no trunk within 12 m of the nest (stage_setup.gd find_nest) */
    {   float gx=(cp_stage_ground(w,x+c,z)-cp_stage_ground(w,x-c,z))/(2*c),gz=(cp_stage_ground(w,x,z+c)-cp_stage_ground(w,x,z-c))/(2*c);
        if(1.f/sqrtf(1.f+gx*gx+gz*gz)<.9f)return 0;}
    for(int ri=0;ri<2;ri++)for(int k=0;k<8;k++){
        const float r=ri?30.f:15.f,a=(float)k*6.2831853f/8.f;
        if(!island_dry(w,x+sinf(a)*r,z+cosf(a)*r))return 0;
    }
    return 1;
}
static void island_nest(const CpStageWorld *w,float *nx,float *nz){
    *nx=*nz=0;
    if(island_nest_ok(w,0,0))return;
    for(int r=5;r<190;r+=5)for(int k=0;k<32;k++){
        const float a=(float)k*6.2831853f/32.f,x=sinf(a)*r,z=cosf(a)*r;
        if(island_nest_ok(w,x,z)){*nx=x;*nz=z;return;}
    }
}
/* Convenience: the nest of field f (a probe world is attached and reset on a scratch copy of the default setup). */
static void island_nest_of(const CpStageField *f,float *nx,float *nz){
    static CpStageWorld probe;
    CpStageSetup s;
    cp_stage_setup_default(&s,5);s.terrain=CP_STAGE_FIELD;s.n=0;
    memset(&probe,0,sizeof probe);assert(!cp_stage_attach_field(&probe,f));assert(!cp_stage_reset(&probe,&s));
    island_nest(&probe,nx,nz);
}
#endif
