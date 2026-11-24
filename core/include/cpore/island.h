/* cpore - island description (docs/plans/island-realism.md section 3, step F0).
 *
 * An island is data: a binary blob ("ISL1") that cp_island_parse() validates and unpacks into a CpIslandDesc, and
 * cp_terrain_generate_desc() turns into a height field. The blob holds integers only (decimetres, centimetres,
 * millidegrees, permille); the evaluator converts each once with a single float division, which is exact below
 * 2^24 and correctly rounded above, so the data is bit-identical on every platform (determinism: + - * / sqrtf).
 *
 * Wire format, little endian:
 *   header  16 bytes  "ISL1", u16 version (1), u16 flags (0), u32 body length, u32 CRC-32 (IEEE) of the first
 *                     12 header bytes followed by the body
 *   body              every field an i32 unless noted; strings are 32-byte NUL-padded fields. Order:
 *                     meta (22 i32 + id string), counts (8 i32), features, points, trails,
 *                     trail points, regions, region points, marks, masks.
 * The blob length must equal 16 + body length exactly. No malloc anywhere: the desc lives in the caller's memory.
 *
 * Units. Features, points, trails, regions and marks are in DESIGN units; world metres = design x scale_pm / 1000
 * (1560 for the Star massif, the old LSCALE). Keeping the factor in the data is what makes the F0 parity with
 * layout 1 exact: rounding the products to decimetres would move the geometry by up to 5 cm. The nest, the lake,
 * the island radius, the size and the RING feature are already world metres. */
#ifndef CPORE_ISLAND_H
#define CPORE_ISLAND_H

#include <stdint.h>
#include <stddef.h>
#include "cpore/terrain.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CP_ISL_FORMAT 1
#define CP_ISL_HEADER_BYTES 16
#define CP_ISL_MAX_FEAT 96
#define CP_ISL_MAX_PT 1024
#define CP_ISL_MAX_TRAIL 32
#define CP_ISL_MAX_TRAIL_PT 256
#define CP_ISL_MAX_REGION 24
#define CP_ISL_MAX_REGION_PT 96
#define CP_ISL_MAX_MARK 32
#define CP_ISL_MAX_MASK 4
#define CP_ISL_MASK_RES 128
#define CP_ISL_NAME 32
/* Evaluator entries: one per non-polyline feature, one per polyline segment. */
#define CP_ISL_MAX_EVAL (CP_ISL_MAX_FEAT + CP_ISL_MAX_PT)

/* Feature kinds (the numbers are the old LF_* values of the layout tables). Fields by kind, units in brackets:
 *   MASSIF   x,y centre [dm]; across, along [dm]; k axis angle [mdeg]; h height [cm]
 *   RANGE    pts (x,y,half width [dm], height [cm]); k ruggedness [pm]
 *   RING     across = radius, along = half width [dm, WORLD]; h height [cm]
 *   PLATEAU  x,y; across = flat radius, along = cliff width [dm]; h top [cm]
 *   TERRACE  x,y; across = full radius, along = feather [dm]; h tread step [cm]; k strength [pm]
 *   BADLANDS x,y; across = radius [dm]; h amplitude [cm]; k frequency scale [pm]
 *   CHANNEL  pts (x,y,half floor [dm], floor altitude [cm]); along = wall width [dm]; flags SEA = the last segment
 *            reaches the sea (beach, not cliff)
 *   ISLET    x,y; across = radius, along = bay radius [dm]; h peak [cm]
 *   CONE     x,y; across = reach [dm]; h height at the centre [cm] */
enum { CP_ISL_MASSIF = 1, CP_ISL_RANGE, CP_ISL_RING, CP_ISL_PLATEAU, CP_ISL_TERRACE, CP_ISL_BADLANDS, CP_ISL_CHANNEL,
       CP_ISL_ISLET, CP_ISL_CONE };
/* Feature flags. SPLINE (Catmull-Rom) and the masks arrive in F1; F0 refuses SPLINE rather than ignore it. */
enum { CP_ISL_F_SEA = 1, CP_ISL_F_RIVER = 2, CP_ISL_F_SPLINE = 4 };

/* Parse and validation errors, on top of CP_TERR_ERR_*. */
enum {
    CP_TERR_ERR_ISL_MAGIC = -10,    /* not an "ISL1" blob */
    CP_TERR_ERR_ISL_VERSION = -11,  /* format or flags this build does not read */
    CP_TERR_ERR_ISL_TRUNC = -12,    /* shorter than the header or the counts say, or length mismatch */
    CP_TERR_ERR_ISL_CRC = -13,      /* checksum mismatch */
    CP_TERR_ERR_ISL_LIMIT = -14,    /* a count above its limit */
    CP_TERR_ERR_ISL_FIELD = -15     /* a value out of range, a bad kind, a bad point reference */
};

typedef struct CpIslandFeature {
    int32_t kind, x_dm, y_dm, across_dm, along_dm, h_cm, k, pt0, npts, flags;
    char name[CP_ISL_NAME];
} CpIslandFeature;
typedef struct CpIslandPoint { int32_t x_dm, y_dm, hw_dm, h_cm; } CpIslandPoint;
typedef struct CpIslandTrail { int32_t pt0, npts; char kind[16]; } CpIslandTrail;       /* points are [x_dm, y_dm] pairs */
typedef struct CpIslandRegion { int32_t gate, w_dm, pt0, npts; char name[CP_ISL_NAME], kind[16], biome[16]; } CpIslandRegion;
typedef struct CpIslandMark { int32_t x_dm, y_dm; char name[CP_ISL_NAME], kind[16]; } CpIslandMark;

/* The evaluator's float form of one feature (identical to the layout tables' LFeat): lengths in design metres,
 * heights in metres, k as float. kind and field use are as the layout comment in terrain_layouts.inc. */
typedef struct CpIslandEval { int kind; float x0, y0, x1, y1, w, w2, h, h2, k; } CpIslandEval;

typedef struct CpIslandDesc {
    /* integers, as stored */
    int32_t size_dm, island_radius_dm, n, scale_pm, wind_mdeg, wind_cms;
    int32_t reef_x_pm, reef_y_pm, cliff_x_pm, cliff_y_pm;        /* sheltered reef coast and exposed cliff coast, unit directions */
    int32_t nest_r_dm, nest_floor_cm, lake_x_dm, lake_y_dm, lake_r_dm, lake_depth_cm;
    int32_t stream_iters, droplets;                              /* recommended erosion; 0 = the caller's value */
    int32_t clim_scale_h_pm, clim_scale_z_pm, clim_t_sea_cC, clim_lapse_cK_per_km;   /* the moisture model (part II) */
    char id[CP_ISL_NAME];
    int32_t nfeat, npt, ntrail, ntrail_pt, nregion, nregion_pt, nmark, nmask;
    CpIslandFeature feat[CP_ISL_MAX_FEAT];
    CpIslandPoint pt[CP_ISL_MAX_PT];
    CpIslandTrail trail[CP_ISL_MAX_TRAIL];
    int32_t trail_pt[CP_ISL_MAX_TRAIL_PT][2];
    CpIslandRegion region[CP_ISL_MAX_REGION];
    int32_t region_pt[CP_ISL_MAX_REGION_PT][2];
    CpIslandMark mark[CP_ISL_MAX_MARK];
    uint8_t mask[CP_ISL_MAX_MASK][CP_ISL_MASK_RES * CP_ISL_MASK_RES];   /* 128 = neutral; parsed and hashed, used from F1 */
    /* filled by cp_island_prepare (parse calls it) */
    int neval;
    float scale, nest_r, reef_x, reef_y, cliff_x, cliff_y;
    CpIslandEval eval[CP_ISL_MAX_EVAL];
} CpIslandDesc;

/* Validates and unpacks a blob. On any error *out is unspecified and a negative CP_TERR_ERR_* is returned. */
int cp_island_parse(const uint8_t *blob, size_t len, CpIslandDesc *out);
/* Rebuilds the float cache from the integer fields (parse calls it). Returns 0 or CP_TERR_ERR_ISL_*. */
int cp_island_prepare(CpIslandDesc *d);
/* Serialises a desc back to its blob (used by tools and tests). Returns the bytes written, 0 if cap is too small. */
size_t cp_island_pack(const CpIslandDesc *d, uint8_t *buf, size_t cap);
/* FNV-1a 64 over the integer fields (not the float cache), little endian. The same blob always hashes the same. */
uint64_t cp_island_hash(const CpIslandDesc *d);
/* CRC-32 (IEEE 802.3, reflected, init and final xor 0xFFFFFFFF), exposed for the tools and tests. */
uint32_t cp_island_crc32(const uint8_t *p, size_t n);

/* Generates the terrain of a desc. p supplies the seed, n and the erosion tuning; the desc overrides size_m,
 * island_radius_m, the nest (valley_radius_m, valley_floor_m, lake) and, when non-zero, stream_iters and droplets.
 * The result hash is NOT mixed with the desc (the F0 parity gate); cp_island_hash identifies the desc. Desc islands
 * skip the river-gap trail until F1 brings authored trails back. */
int cp_terrain_generate_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                             const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user);

#ifdef __cplusplus
}
#endif
#endif /* CPORE_ISLAND_H */
