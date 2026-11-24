/* Standalone terrain ABI. One caller-owned static arena, 29 MiB at 1024².
 * Core stays allocation-free; one module instance serves one Worker. */
#include "cpore/terrain.h"
#include "cpore/island.h"
#include <emscripten.h>
#include <stdint.h>
#define MAX_N 1024
static float arena[4 * MAX_N * MAX_N];
static uint8_t materials[MAX_N * MAX_N];
static uint8_t river_map[MAX_N * MAX_N];
static int32_t indices[3 * MAX_N * MAX_N];
static CpTerrainParams params;
static CpTerrain terrain;
static CpTerrainWorkspace workspace;
static uint32_t hash_words[2];
static CpIslandDesc island;          /* the parsed desc (island.h), set by ct_desc_set */
static uint8_t desc_blob[1 << 18];   /* the blob JS writes into: 256 KiB, a full ISL1 file is under 120 KiB */
static int desc_ok, last_desc;   /* last_desc: the last generation was a desc (ct_size then reports its size) */
static int configured;
EM_JS(void, terrain_progress, (int stage, int done, int total), {
    if (Module['onTerrainProgress']) Module['onTerrainProgress'](stage, done, total);
});
static void progress(int stage, int done, int total, void *user) {
    (void)user; terrain_progress(stage, done, total);
}
int ct_config(uint32_t seed, int n, int droplets, int thermal,
              float warp, float ridge, float erosion, int stream) {
    configured=0;
    cp_terrain_params_default(&params);
    params.seed=seed; params.n=n;
    if(n>MAX_N) return CP_TERR_ERR_N;
    params.droplets=droplets; params.thermal_iters=thermal; params.stream_iters=stream;
    params.warp_m=warp; params.ridge_weight=ridge; params.erosion=erosion;
    int rc=cp_terrain_validate(&params); if(rc) return rc;
    int nn=n*n;
    terrain.material=materials;
    terrain.river=river_map;
    terrain.height=arena; terrain.flow=arena+nn; terrain.sediment=arena+2*nn;
    workspace.scratch=arena+3*nn;
    workspace.recv=indices;
    workspace.ups=indices+nn;
    workspace.queue=indices+2*nn;
    configured=1; return 0;
}
/* Separate entry point preserves ct_config's existing argument defaults. */
int ct_deltas(float gentle, float variety, float bands) {
    if (!configured) return CP_TERR_ERR_BUFFER;
    params.gentle_bases=gentle; params.layout_variety=variety; params.cliff_bands=bands;
    int rc=cp_terrain_validate(&params);
    if (rc) configured=0;
    return rc;
}
int ct_features(float coast, float rock, float volcano, float caves) {
    if (!configured) return CP_TERR_ERR_BUFFER;
    params.sea_cliffs=coast;params.hard_rock=rock;params.volcano=volcano;params.caves=caves;
    int rc=cp_terrain_validate(&params);if(rc)configured=0;return rc;
}
int ct_rivers(float rivers) {
    if (!configured) return CP_TERR_ERR_BUFFER;
    params.rivers=rivers;
    int rc=cp_terrain_validate(&params);if(rc)configured=0;return rc;
}
uint8_t *ct_river(void) { return configured ? terrain.river : 0; }
uint8_t *ct_material(void) { return configured ? terrain.material : 0; }
int ct_cave_count(void) { return configured ? terrain.cave_count : 0; }
CpTerrainCave *ct_caves(void) { return configured ? terrain.caves : 0; }
float *ct_volcano(void) { return configured ? &terrain.volcano_x_m : 0; }
int ct_generate(void) {
    if(!configured) return CP_TERR_ERR_BUFFER;
    last_desc=0;
    return cp_terrain_generate(&params,&terrain,&workspace,progress,0);
}
float *ct_map(int layer) {
    if(!configured) return 0;
    /* Layer 3 is the routing water level: above the ground where a basin holds a lake. */
    return layer==0 ? terrain.height : layer==1 ? terrain.flow : layer==2 ? terrain.sediment :
           layer==3 ? workspace.scratch : 0;
}
float ct_size(void) { return !configured ? 0.f : last_desc && desc_ok ? (float)island.size_dm/10.f : params.size_m; }
uint32_t *ct_hash(void) {
    uint64_t h=configured ? cp_terrain_hash(&terrain) : 0;
    hash_words[0]=(uint32_t)h; hash_words[1]=(uint32_t)(h>>32); return hash_words;
}
int ct_version(void) { return CP_TERRAIN_VERSION; }
/* Island descs (island.h). JS copies an ISL1 blob into ct_desc_buf(), calls ct_desc_set(len), then ct_config + ct_generate_desc;
 * the same height/flow/sediment/material/river layers and the same ct_hash (which now mixes the desc hash) come back. */
uint8_t *ct_desc_buf(void) { return desc_blob; }
int ct_desc_buf_size(void) { return (int)sizeof desc_blob; }
int ct_desc_set(int len) {
    desc_ok=0;
    if(len<0 || (size_t)len>sizeof desc_blob) return CP_TERR_ERR_ISL_TRUNC;
    int rc=cp_island_parse(desc_blob,(size_t)len,&island);
    if(rc==0) desc_ok=1;
    return rc;
}
uint32_t *ct_desc_hash(void) {
    uint64_t h=desc_ok ? cp_island_hash(&island) : 0;
    hash_words[0]=(uint32_t)h; hash_words[1]=(uint32_t)(h>>32); return hash_words;
}
int ct_desc_n(void) { return desc_ok ? island.n : 0; }
int ct_generate_desc(void) {
    if(!configured || !desc_ok) return CP_TERR_ERR_BUFFER;
    last_desc=1;
    return cp_terrain_generate_desc(&params,&island,&terrain,&workspace,progress,0);
}
