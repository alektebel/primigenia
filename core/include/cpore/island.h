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
/* Climate calibration (part II, step M2): header flag bit 0 says 16 more i32 follow the masks. A slot of 0 means "use the
 * kernel's default" (climate.c, cp_climate_defaults), so a blob without the block (flag clear) behaves like all zeros. */
#define CP_ISL_CALIB_N 16
#define CP_ISL_FLAG_CALIB 1
enum {
    CP_ISL_CAL_RAIN_SCALE_PM = 0,   /* fraction of the year the regimes rain, permille (starting value 110) */
    CP_ISL_CAL_P_INF_MM,            /* background precipitation, mm/yr (200) */
    CP_ISL_CAL_QC_REF_PM,           /* cloud water that counts as 1.0, permille of a kg/m^2 (1000) */
    CP_ISL_CAL_SNOW_CC,             /* snow below this mean annual temperature, centi-degrees C (315) */
    CP_ISL_CAL_ASPECT_CC,           /* cooling on slopes facing away from the sun, cC (150) */
    CP_ISL_CAL_FOEHN_CC,            /* warming on lee slopes, cC (100) */
    CP_ISL_CAL_TRADE_W_PM,          /* share of the year under the trade wind, permille (750); the storms get the rest */
    CP_ISL_CAL_STORM_CMS,           /* storm speed, cm/s (1500) */
    CP_ISL_CAL_TREELINE_CC,         /* forest needs a mean annual temperature above this, cC (700) */
    CP_ISL_CAL_TUNDRA_CC,           /* tundra below this, alpine up to the treeline, cC (450) */
    CP_ISL_CAL_P_SCRUB_MM,          /* desert below, scrub above (250) */
    CP_ISL_CAL_P_MEADOW_MM,         /* scrub below, meadow above (450) */
    CP_ISL_CAL_P_DRYFOREST_MM,      /* meadow below, dry forest above (900) */
    CP_ISL_CAL_P_JUNGLE_MM,         /* dry forest below, cloud forest above (1700) */
    CP_ISL_CAL_CANOPY_P_FULL_MM,    /* canopy density reaches 1 at this precipitation (1800); it starts at a third of it */
    CP_ISL_CAL_TAU_S,               /* cloud-water conversion and fall-out time, seconds (1000: the abstract's value) */
    CP_ISL_CAL_RESERVED
};
/* Evaluator entries: one per non-polyline feature, one per straight polyline segment, CP_ISL_SPLINE_SEG per span of a
 * spline polyline. cp_island_prepare (hence parse) refuses a desc that needs more (CP_TERR_ERR_ISL_LIMIT). */
#define CP_ISL_SPLINE_SEG 16
#define CP_ISL_MAX_EVAL 4096

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
/* Feature flags. SPLINE (RANGE and CHANNEL only) makes the polyline a centripetal Catmull-Rom curve through its points
 * (island_desc.c, cp_island_prepare): CP_ISL_SPLINE_SEG straight evaluator segments per span, the end points exact. Width and
 * height are splined with x and y.
 *
 * Noise index. Several terms of the shape evaluator take a per-feature noise offset (the 3.1*i, 11*i, 13*i, 2*i, 3*i of
 * terrain_layouts.inc). Rule: the index of an evaluator entry is the running count of CONTROL SPANS before it: one per
 * non-polyline feature, one per control segment of a polyline, in feature order. For straight polylines this is the
 * evaluator-entry position, which is exactly what the layout tables use (layout-1 parity). A spline span gives all its
 * 16 sub-segments the same index, so turning a spline on or off, or changing its sampling, never shifts the noise of any
 * other feature, and inserting a control point shifts only what follows it. */
enum { CP_ISL_F_SEA = 1, CP_ISL_F_RIVER = 2, CP_ISL_F_SPLINE = 4 };

/* Mask slots (the desc's `mask[]`, 128 x 128 u8 over the whole square, bilinear, 128 = neutral). A blob may carry the first
 * 1..4; missing masks are neutral.
 *   CLIMATE_BIAS  precipitation +-50% (part II, not read by the terrain)
 *   CANOPY        forest allowed (255) or barred (0) (part II)
 *   EROSION       multiplier on stream-power and droplet erosion: v / 128, clamped to 0..1.5 (0 = untouched ground)
 *   PROTECT       cells above 128 keep their authored (pre-erosion) height within +-0.5 m at full value (255); the band widens
 *                 as the value falls: 0.5 m / ((v - 128) / 127), nothing below 129 */
enum { CP_ISL_MASK_CLIMATE = 0, CP_ISL_MASK_CANOPY, CP_ISL_MASK_EROSION, CP_ISL_MASK_PROTECT };

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
typedef struct CpIslandEval { int kind; float x0, y0, x1, y1, w, w2, h, h2, k; int ni; float a0; } CpIslandEval;
/* ni = noise index (rule above); a0 = design metres already travelled along the polyline's span at x0,y0 (0 for tables). */

typedef struct CpIslandDesc {
    /* integers, as stored */
    int32_t size_dm, island_radius_dm, n, scale_pm, wind_mdeg, wind_cms;
    int32_t reef_x_pm, reef_y_pm, cliff_x_pm, cliff_y_pm;        /* sheltered reef coast and exposed cliff coast, unit directions */
    int32_t nest_r_dm, nest_floor_cm, lake_x_dm, lake_y_dm, lake_r_dm, lake_depth_cm;
    int32_t has_calib, calib[CP_ISL_CALIB_N];                    /* the climate calibration block (CP_ISL_CAL_*), see above */
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
/* The shipped island (Star massif, A101): the ISL1 blob compiled in from core/src/islands/star_massif.inc (generated by
 * `make island-pack` from data/islands/star_massif.island.json). Returns a pointer to static bytes and sets *len. */
const uint8_t *cp_island_star_massif(size_t *len);
/* CRC-32 (IEEE 802.3, reflected, init and final xor 0xFFFFFFFF), exposed for the tools and tests. */
uint32_t cp_island_crc32(const uint8_t *p, size_t n);

/* The terrain parameters a desc overrides (size, island radius, nest, lake, and stream_iters / droplets when non-zero),
 * applied to *q. cp_terrain_generate_desc does exactly this to a copy of its p; the tools call it to learn the real size. */
void cp_island_apply(const CpIslandDesc *d, CpTerrainParams *q);
/* Bilinear sample of mask `which` (0..255, 128 when the desc has no such mask) at world metres; lerp form a + (b - a) t, so a
 * constant mask returns its value exactly. Edge texels extend. */
float cp_island_mask(const CpIslandDesc *d, int which, float x_m, float y_m);
/* The design maps' meta (id, nest, wind, regions, routes = the trails, marks) as the JSON cp_terrain_layout_json writes for a
 * layout, in world metres. Returns the bytes written (excluding the NUL), 0 on error. */
size_t cp_island_meta_json(const CpIslandDesc *d, char *buf, size_t cap);

/* Generates the terrain of a desc. p supplies the seed, n and the erosion tuning; the desc overrides size_m,
 * island_radius_m, the nest (valley_radius_m, valley_floor_m, lake) and, when non-zero, stream_iters and droplets.
 * The result carries cp_island_hash in out->island_hash, which cp_terrain_hash mixes in (terrain v5); clearing the field
 * gives the hash of the same arrays as a layout island (the F0 parity gate). The masks EROSION and PROTECT are applied.
 * Trails of kind "game_trail" or "path" are routed near their hint polyline (a corridor of +-40 m, walkable) and graded
 * to the 51.6 degree grip rule; other kinds ("exit", ...) are descriptive and not carved. Desc islands skip the
 * layout-0 river-gap trail. */
int cp_terrain_generate_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                             const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user);

/* The climate maps of t (t->height must be the final height; climate, biome, veg and ws->climate_work set; p->n == t->n >= 64),
 * made from the desc's climate block, wind, calibration and masks (climate.h; plan part II). cp_terrain_generate_desc calls it
 * when those buffers are present; the editor calls it again after changing only the calibration or the masks. It does not
 * touch the other maps (the snow material is decided at generation). Sets t->climate_n. */
int cp_terrain_climate(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *t, const CpTerrainWorkspace *ws);

/* Same as cp_terrain_generate_desc with every erosion pass off (droplets, thermal, stream power = 0, whatever p and the desc say):
 * the authored shape plus the cliff bands, protect mask, rivers cut into the base and trails. This is the editor's drag preview;
 * `terrain_cli hash --desc F --base` gives the same hash natively. */
int cp_terrain_shape_desc(const CpTerrainParams *p, const CpIslandDesc *d, CpTerrain *out,
                          const CpTerrainWorkspace *ws, CpTerrainProgressFn fn, void *user);

#ifdef __cplusplus
}
#endif
#endif /* CPORE_ISLAND_H */
