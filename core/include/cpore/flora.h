/* cpore - the flora the simulation needs (island-realism plan 4.3, step M3).
 *
 * Only the trunks that matter to the sim are placed in C: wide enough to block (radius >= 0.3 m), the big climbable cloud-forest trees,
 * and the landmark spring tree. Everything small stays visual (GDScript). Pure and deterministic: + - * / and sqrtf on floats, an integer
 * hash instead of an RNG stream, no libm trig, so native and WASM give the same records. Inputs are the climate maps (CpTerrain.veg,
 * biome, climate) and the heights; the output goes into CpStageField (world.h), folded into its hash by cp_stage_field_seal. */
#ifndef CPORE_FLORA_H
#define CPORE_FLORA_H
#include <stdint.h>
#include <stddef.h>
#include "cpore/world.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CP_FLORA_VERSION 1                 /* bump when the records for the same maps change */
enum { CP_FLORA_SP_NONE = 0, CP_FLORA_SP_NIEBLON = 1, CP_FLORA_SP_MADRE = 2 };   /* flora.json ids nieblon and madre_de_agua */
#define CP_FLORA_GRID_M 6.f                /* the jittered placement grid (plan 4.3) */
#define CP_FLORA_MIN_GAP_M 4.5f            /* Poisson rejection: trunk centres at least this far apart */
#define CP_FLORA_ACCEPT 0.2f               /* starting value: share of the canopy density that becomes a trunk, about 55 per ha in full canopy. 0.5 closed the forest to the 3 m bodies the route tests certify (nav edges of 7.8 m between trunks); checked by test_nav forest cases and the island-path OG5-OG7 */
#define CP_FLORA_RADIUS_PER_M 0.03f        /* nieblon trunk radius = this x height (12..22 m -> 0.36..0.66 m, all above the 0.3 m blocking threshold) */
#define CP_FLORA_CAVE_CLEAR_M 45.f         /* the secret cave: 14 m of passage and a 10 m chamber (stage_secrets.c) plus the apron */
#define CP_FLORA_TRUNK_CELL_M 16.f         /* the spatial hash bucket */
/* What the game ships (plan risk 5: the cover multiplier is OFF until the loop re-tune R measures it; the trail bonus likewise). The plan's
 * starting values are 0.4 (speed x lerp(1, 0.6, cover/255)) and 0.15 (x 1.15 on a trail); tests switch them on explicitly. */
#define CP_FIELD_COVER_SLOW_SHIP 0.f
#define CP_FIELD_TRAIL_BONUS_SHIP 0.f
#define CP_FIELD_COVER_SLOW_PLAN 0.4f
#define CP_FIELD_TRAIL_BONUS_PLAN 0.15f

/* The maps the placement reads (all n*n unless noted; veg is n*n*4 RGBA8, climate climate_n^2*4 RGBA8). NULL water_level, river and trail are allowed. */
typedef struct CpFloraMaps {
    int32_t n, climate_n;
    float size_m;
    uint32_t seed;
    const float *height, *water_level;
    const uint8_t *biome, *veg, *climate, *river, *trail;
    const float *cave_xz;      /* n_caves (x, z) metre pairs: no trunk within CP_FLORA_CAVE_CLEAR_M of a cave entrance (the passage and chamber run under the slope behind it) */
    int32_t n_caves;
} CpFloraMaps;

/* Writes up to `cap` trunk records (row-major over the 6 m grid, the spring tree first) and returns how many there are in all; if that
 * exceeds cap only the first cap were stored, so call again with a bigger buffer. -1 on missing maps. */
int cp_flora_trunks(const CpFloraMaps *m, CpStageTrunk *out, int cap);
/* Undergrowth cover for the sim: veg G, at least 1 off a game trail, 0 on one (m->trail). n*n bytes. */
void cp_flora_cover(const CpFloraMaps *m, uint8_t *cover);

/* Bucket counts for the spatial hash of a field of size_m: cells per side, and the `start` array length (cells + 1). */
int32_t cp_stage_trunks_cells(float size_m);
/* Fills the hash: start (cp_stage_trunks_cells^2 + 1 entries) and index (count entries); `out` then points at rec/start/index. 0 or -1. */
int cp_stage_trunks_index(CpStageTrunks *out, const CpStageTrunk *rec, int count, float size_m, int32_t *start, int32_t *index);

/* One-call builder for hosts: allocates and keeps cover, records and the hash, points f at them and seals f->hash over terrain_hash.
 * f must already carry n, size_m, cell, half, height, water_level. Without veg in m (m->veg NULL) f gets no cover and no trunks. */
typedef struct CpFieldStore {
    uint8_t *cover;
    CpStageTrunk *rec;
    int32_t *start, *index;
    CpStageTrunks trunks;
} CpFieldStore;
/* `given` (optional, `given_n` records): trunk records made earlier by cp_flora_trunks from the same maps (the island cache keeps them); NULL
 * places them here. The ship tunings are CP_FIELD_*_SHIP. */
int cp_field_build(CpStageField *f, CpFieldStore *st, const CpFloraMaps *m, uint64_t terrain_hash, float cover_slow, float trail_bonus,
                   const CpStageTrunk *given, int given_n);
void cp_field_store_free(CpFieldStore *st);

#ifdef __cplusplus
}
#endif
#endif
