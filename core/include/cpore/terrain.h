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
#define CP_TERRAIN_VERSION 5   /* 5: island descs (island.h): cp_terrain_hash mixes the desc hash; splines, masks, trails (F1) */

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

/* Progress stages. done/total grow inside a stage and reset at the next.
 * BASE is the shape and the coarse stream-power passes (N/4, N/2), HYDRAULIC
 * the droplets, THERMAL the fine stream-power pass and the scree sweeps. */
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
    int stream_iters;       /* stream-power steps at N/4; N/2 runs /3, N runs /8 */
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
    float pass_x, pass_y;   /* river-gap direction; normalised, (0,0) means +x */
    float pass_half_m;
    float pass_height_m;    /* gap floor where it crosses the crest line */
    float col_x, col_y;     /* direction of the promised high col */
    float col_height_m;     /* crest height at the col */
    float island_radius_m;  /* mean coast radius; the square edge is always sea */
    float lake_x_m, lake_y_m;
    float lake_radius_m;
    float lake_depth_m;
    float stream_k;         /* K*dt of one stream-power step, per sqrt(m2) of area */
    float inertia;
    float capacity;
    float deposition;
    float erosion;
    float evaporation;
    float gravity;
    float min_slope;        /* minimum downhill slope used for capacity */
    float talus_deg;        /* loose material: the final thermal passes */
    float gentle_bases;     /* 0 = v2 heights; 1 = gentle lowland remap */
    float layout_variety;   /* 0 = v2 seven slots; 1 = seeded 6..8, extra jitter */
    float cliff_bands;      /* 0 = off; 1 = subtle high, steep bedrock bands */
    float sea_cliffs;       /* 0 = beaches as v2; 1 = seeded rocky coastal sectors */
    float hard_rock;        /* 0 = v2 resistance; 1 = resistant high strata */
    float volcano;          /* 0 = original massif; 1 = one stratovolcano */
    float caves;            /* 0 = no entrances/notches; 1 = seeded entrances */
    float cliff_deg;        /* bedrock: the sweep inside stream power */
    float rivers;           /* 0 = no channels; 1 = carved river network (v4) */
    float layout;           /* 0 = v4 ring island; 1..4 = island layout candidates (DESIGN A83, design lab only) */
} CpTerrainParams;

enum {
    CP_TERR_MAT_MEADOW = 0, CP_TERR_MAT_ROCK = 1, CP_TERR_MAT_SCREE = 2,
    CP_TERR_MAT_VOLCANIC = 3, CP_TERR_MAT_SAND = 4, CP_TERR_MAT_SNOW = 5
};
/* River classes of CpTerrain.river (v4): bits 0..1 the class, bits 2..5 the D8 receiver direction + 1 (0 = outlet;
 * directions as cp_terrain_directions), so renderers can follow the channel. */
/* River classes (low 2 bits). Drainage area decides the class; the water level the world sees is the
 * bed plus 0.35 m (stream, under the 0.5 m a pond needs, so dry for the sim), 0.6 m (river: shallow, walkable)
 * or 1.2 m (deep: blocked until swimming exists). */
enum { CP_TERR_RIVER_NONE = 0, CP_TERR_RIVER_STREAM = 1, CP_TERR_RIVER_SHALLOW = 2, CP_TERR_RIVER_DEEP = 3 };
#define CP_TERRAIN_CAVES_MAX 6
/* Map x/y in metres, z altitude; facing is the outward horizontal unit vector.
 * A notch is only a heightfield hint. Passage/chamber meshes belong to rendering. */
typedef struct CpTerrainCave {
    float x_m, y_m, z_m;
    float facing_x, facing_y;
    float width_m, height_m, depth_m;
    uint32_t waterfall;
} CpTerrainCave;

typedef struct CpTerrain {
    int n;
    float size_m;
    float *height;          /* metres, row-major, n*n */
    float *flow;            /* fraction of the map draining through the cell */
    float *sediment;        /* metres deposited by droplets */
    uint8_t *material;      /* caller-owned n*n bytes, CP_TERR_MAT_* */
    uint8_t *river;         /* optional n*n bytes, CP_TERR_RIVER_* | receiver direction << 2; NULL skips the map (the carving still happens) */
    int cave_count;
    CpTerrainCave caves[CP_TERRAIN_CAVES_MAX];
    float volcano_x_m, volcano_y_m, volcano_radius_m, crater_radius_m;
    uint64_t island_hash;   /* cp_island_hash of the desc the terrain was generated from; 0 for layouts. Mixed into cp_terrain_hash */
} CpTerrain;

/* scratch: n*n floats. recv, ups, queue: n*n int32 each.
 * Each buffer has at least n*n elements, is suitably aligned, and must not
 * overlap any other buffer. scratch holds depression-filled water levels.
 * After generation recv holds flow receivers (-1 = boundary outlet). scratch is the routing water level, raised
 * to bed + 0.35/0.6/1.2 m on river cells (v4), so it is no longer strictly decreasing along recv there.
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
 * height, flow, sediment, material, volcano and cave records. +0 and -0 hash the same. */
uint64_t cp_terrain_hash(const CpTerrain *t);

/* A83 design lab: regions, routes and landmarks of layout 1..4 as one JSON object. Returns bytes written, 0 if unknown. */
size_t cp_terrain_layout_json(int layout, char *buf, size_t cap);
void cp_terrain_layout_apply(int layout, CpTerrainParams *p);

#ifdef __cplusplus
}
#endif
#endif /* CPORE_TERRAIN_H */
