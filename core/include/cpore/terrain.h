/* cpore - eroded terrain (DESIGN.md W11–W13).
 *
 * One seed produces one height field: a domain-warped ridged base shaped by a
 * mountain mask (start valley, ring, lake, pass), then a fixed number of
 * hydraulic droplets and thermal-erosion passes, then depression-routed D8 flow accumulation.
 * The hot path is + - * / and sqrtf only, compiled -fno-fast-math
 * -ffp-contract=off, so native and WASM hash the same bytes.
 *
 * No malloc. The caller owns the output maps and the scratch workspace.
 * A progress callback fires between fixed chunks of work so a Web Worker can
 * report the loading screen without sharing the solver's inner loop.
 */
#ifndef CPORE_TERRAIN_H
#define CPORE_TERRAIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Bump when the bytes for a seed change. Cached worlds key on this (W13). */
#define CP_TERRAIN_VERSION 1

#define CP_TERRAIN_N_MIN   8
#define CP_TERRAIN_N_MAX   2048

enum {
    CP_TERR_OK = 0,
    CP_TERR_ERR_NULL = -1,
    CP_TERR_ERR_N = -2,
    CP_TERR_ERR_SIZE = -3,
    CP_TERR_ERR_OCTAVES = -4,
    CP_TERR_ERR_DROPLETS = -5,
    CP_TERR_ERR_RANGE = -6,
    CP_TERR_ERR_FINITE = -7,
    CP_TERR_ERR_BUFFER = -8
};

/* Progress stages. done/total grow inside a stage and reset at the next. */
enum {
    CP_TERR_STAGE_BASE = 0,
    CP_TERR_STAGE_HYDRAULIC = 1,
    CP_TERR_STAGE_THERMAL = 2,
    CP_TERR_STAGE_FLOW = 3,
    CP_TERR_STAGE_DONE = 4
};

typedef void (*CpTerrainProgressFn)(int stage, int done, int total, void *user);

/* Droplet numbers are in grid steps (one step ≈ one cell), matching the
 * Beyer / Lague particle model. Heights elsewhere are metres. Talus is
 * degrees; it is converted once per generate with a polynomial, not in
 * the per-cell loop. frequency is cycles per metre of the lowest octave.
 */
typedef struct CpTerrainParams {
    uint32_t seed;
    int n;
    int octaves;
    int droplets;
    int lifetime;
    int radius;             /* brush radius in cells, 1..8 */
    int thermal_iters;
    float size_m;
    float frequency;
    float warp_m;
    float ridge_weight;     /* 0 = fbm hills, 1 = ridged peaks, on the ring */
    float valley_radius_m;
    float valley_floor_m;
    float ring_inner_m;
    float ring_outer_m;
    float ring_height_m;
    float pass_x, pass_y;   /* gap direction; normalised, (0,0) means +x */
    float pass_half_m;
    float pass_height_m;
    float lake_x_m, lake_y_m;
    float lake_radius_m;
    float lake_depth_m;
    float inertia;
    float capacity;
    float deposition;
    float erosion;
    float evaporation;
    float gravity;
    float min_slope;        /* minimum downhill slope used for capacity */
    float talus_deg;
} CpTerrainParams;

typedef struct CpTerrain {
    int n;
    float size_m;
    float *height;          /* metres, row-major, n*n */
    float *flow;            /* fraction of the map draining through the cell */
    float *sediment;        /* metres deposited by droplets */
} CpTerrain;

/* scratch: n*n floats. recv, ups, queue: n*n int32 each.
 * Each buffer has at least n*n elements, is suitably aligned, and must not
 * overlap any other buffer. scratch holds depression-filled water levels.
 * After generation recv holds flow receivers (-1 = boundary outlet).
 * The caller must size buffers; C cannot infer their capacity.
 * All callbacks run synchronously on the calling thread. */
typedef struct CpTerrainWorkspace {
    float *scratch;
    int32_t *recv;
    int32_t *ups;
    int32_t *queue;
} CpTerrainWorkspace;

void cp_terrain_params_default(CpTerrainParams *p);
int  cp_terrain_validate(const CpTerrainParams *p);

int  cp_terrain_generate(const CpTerrainParams *p, CpTerrain *out,
                         const CpTerrainWorkspace *ws,
                         CpTerrainProgressFn fn, void *user);

/* Rise/run. Edges use a one-sided difference. */
void cp_terrain_slope(const float *height, int n, float size_m, float *slope);

/* Raw (unfilled) D8 receiver helper; generation uses priority-flood routing
 * instead, exposed as workspace.recv. D8 receiver. dir[i] is -1 (sink) or 0..7:
 *   0 +x, 1 +x+y, 2 +y, 3 -x+y, 4 -x, 5 -x-y, 6 -y, 7 +x-y.
 * Ties keep the lowest index. Slope uses cell and cell*sqrt(2). */
void cp_terrain_directions(const float *height, int n, float size_m, int8_t *dir);

/* FNV-1a 64 over a canonical little-endian dump: version, n, size, then
 * height, flow, sediment. +0 and -0 hash the same. */
uint64_t cp_terrain_hash(const CpTerrain *t);

#ifdef __cplusplus
}
#endif
#endif /* CPORE_TERRAIN_H */
