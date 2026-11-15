/* Standalone terrain ABI. One caller-owned static arena, 28 MiB at 1024².
 * Core stays allocation-free; one module instance serves one Worker. */
#include "cpore/terrain.h"
#include <emscripten.h>
#include <stdint.h>
#define MAX_N 1024
static float arena[7 * MAX_N * MAX_N];
static CpTerrainParams params;
static CpTerrain terrain;
static CpTerrainWorkspace workspace;
static uint32_t hash_words[2];
static int configured;
EM_JS(void, terrain_progress, (int stage, int done, int total), {
    if (Module['onTerrainProgress']) Module['onTerrainProgress'](stage, done, total);
});
static void progress(int stage, int done, int total, void *user) {
    (void)user; terrain_progress(stage, done, total);
}
int ct_config(uint32_t seed, int n, int droplets, int thermal,
              float warp, float ridge, float erosion) {
    configured=0;
    cp_terrain_params_default(&params);
    params.seed=seed; params.n=n;
    if(n>MAX_N) return CP_TERR_ERR_N;
    params.droplets=droplets; params.thermal_iters=thermal;
    params.warp_m=warp; params.ridge_weight=ridge; params.erosion=erosion;
    int rc=cp_terrain_validate(&params); if(rc) return rc;
    int nn=n*n;
    terrain.height=arena; terrain.flow=arena+nn; terrain.sediment=arena+2*nn;
    workspace.scratch=arena+3*nn;
    workspace.recv=(int32_t *)(arena+4*nn);
    workspace.ups=(int32_t *)(arena+5*nn);
    workspace.queue=(int32_t *)(arena+6*nn);
    configured=1; return 0;
}
int ct_generate(void) {
    if(!configured) return CP_TERR_ERR_BUFFER;
    return cp_terrain_generate(&params,&terrain,&workspace,progress,0);
}
float *ct_map(int layer) {
    if(!configured) return 0;
    return layer==0 ? terrain.height : layer==1 ? terrain.flow : layer==2 ? terrain.sediment : 0;
}
uint32_t *ct_hash(void) {
    uint64_t h=configured ? cp_terrain_hash(&terrain) : 0;
    hash_words[0]=(uint32_t)h; hash_words[1]=(uint32_t)(h>>32); return hash_words;
}
int ct_version(void) { return CP_TERRAIN_VERSION; }
