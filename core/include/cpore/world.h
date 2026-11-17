/* P4 world foundation. CpWorld is reserved by the cell stage in cpore.h. */
#ifndef CPORE_WORLD_H
#define CPORE_WORLD_H
#include "cpore/combat.h"
#define CP_STAGE_VERSION 2
#define CP_STAGE_MAX_WILD 24
#define CP_STAGE_MAX_OBSTACLES 1024
#define CP_STAGE_DAY_TICKS 12000
#define CP_STAGE_DT .1f
#define CP_STAGE_SNAPSHOT_VERSION 1

enum { CP_STAGE_ANALYTIC, CP_STAGE_FLAT, CP_STAGE_FIELD }; /* FIELD: F4 (PLAN-heights H1); reset rejects it until then */
enum { CP_STAGE_TIMID, CP_STAGE_TERRITORIAL, CP_STAGE_AGGRESSIVE };
enum { CP_STAGE_CONTINUE, CP_STAGE_WAIT, CP_STAGE_GO, CP_STAGE_HEADING,
       CP_STAGE_APPROACH, CP_STAGE_ATTACK, CP_STAGE_FLEE, CP_STAGE_GO_NEST,
       CP_STAGE_GUARD, CP_STAGE_DODGE };
enum { CP_STAGE_NONE, CP_STAGE_VICTORY, CP_STAGE_DEATH, CP_STAGE_FLED };
typedef struct { float x,z,r; int32_t type; } CpStageObstacle;
typedef struct {
    const char *name;
    float speed,sight,roam,hostile;
    int32_t temperament;
    CpCombatProfile profile;
} CpStageSpecies;
extern const CpStageSpecies CP_STAGE_SPECIES[4];
/* Stage locomotion (PLAN-feel, version 2). jog = profile.speed*jog_k, sprint = jog*sprint_k, wild = speed*wild_k*jog_k. */
typedef struct {
    float jog_k,sprint_k,wild_k;
    float accel,brake;               /* m/s2 caps on the per-tick speed change */
    float ease;                      /* share of the remaining speed error closed per tick */
    float turn_k,turn_min,turn_max;  /* turn0 = clamp(turn_k*sqrt(9.81/r_body), turn_min, turn_max) rad/s */
    float grip;                      /* lateral limit, m/s2: yaw rate <= grip/v */
    float pivot_k,pivot_mul,pivot_max; /* pivot only below pivot_k*jog; rate clamp(pivot_mul*turn0, 3, pivot_max) */
    float turn_slow;                 /* wanted *= (1-turn_slow)+turn_slow*max(dot,0) */
} CpStageMotion;
extern const CpStageMotion CP_STAGE_MOTION;
typedef struct {
    float x,z,home_x,home_z;
    int32_t species,bot; /* -1 uses the temperament's standard bot */
    CpCombatProfile profile;
} CpStageSpawn;
typedef struct {
    uint32_t seed,terrain_seed;
    int32_t terrain,n,n_obstacles;
    float nest_x,nest_z,flat_height,water_x,water_z,water_radius;
    CpCombatProfile player;
    CpStageSpawn wild[CP_STAGE_MAX_WILD];
    CpStageObstacle obstacles[CP_STAGE_MAX_OBSTACLES];
} CpStageSetup;
typedef struct {
    int32_t verb,target,move,dir,sprint;
    int16_t hx,hz;
    float x,z;
} CpStageInput;
typedef struct {
    float x,z,fx,fz,hp,stamina,speed,acceleration,turn_rate;
    float home_x,home_z,goal_x,goal_z;
    int32_t species,dead,pivot,returning,roam_ticks;
    CpCombatProfile profile;
} CpStageCreature;
/* Adapter state for the existing public apps/combat_bots.h API. No bot rules
 * are duplicated here; stage_world.c copies these fields to/from CpBot. */
typedef struct {
    CpRng rng;
    int32_t kind,spam_move,delay,reaction,ranged_commit,timer;
} CpStageBot;
/* Generated island heights handed to the world by pointer (PLAN-heights H1). Not owned by C. */
typedef struct CpStageField {
    int32_t n;
    float size_m,cell,half;          /* cell = size_m/n, half = size_m/2 */
    const float *height;             /* n*n metres, row-major j*n+i (z rows, x columns) */
    const float *water_level;        /* n*n depression-filled level, may be NULL */
    uint64_t hash;                   /* cp_terrain_hash of the generated terrain */
} CpStageField;
typedef struct {
    CpStageSetup setup;
    CpRng spawn_rng,roam_rng;
    uint8_t noise[512]; /* derived from terrain_seed; not hashed twice */
    uint32_t tick,clock;
    CpStageCreature player,wild[CP_STAGE_MAX_WILD];
    CpStageInput order;
    int32_t active,started,outcome,respawn_ticks,cooldown_ticks;
    float arena_x,arena_z;
    CpCombatWorld combat;
    CpStageBot bot;
    /* Derived last-tick outputs. Excluded from hash. */
    CpCombatAction combat_orders[2];
    int32_t accepted[2],last_error;
    uint64_t hash;
    /* DT0 additions (PLAN-devtools step 3). Part of the snapshot payload, except `field`, which MUST stay
     * the last member: the payload is offsetof(CpStageWorld,field) bytes. */
    CpStageMotion motion;            /* per-world copy of CP_STAGE_MOTION, changed by debug PARAM ops */
    int32_t debug_flags,reserved;    /* CP_STAGE_FLAG_* ; reserved keeps the layout explicit */
    uint64_t field_hash;             /* hash of the attached field, 0 outside FIELD mode */
    const CpStageField *field;       /* not owned, not in the snapshot, set by cp_stage_attach_field */
} CpStageWorld;
void cp_stage_setup_default(CpStageSetup *s,uint32_t seed);
int cp_stage_reset(CpStageWorld *w,const CpStageSetup *s);
float cp_stage_height(const CpStageWorld *w,float x,float z);
float cp_stage_ground(const CpStageWorld *w,float x,float z);
int cp_stage_can_walk(const CpStageWorld *w,float x,float z,float nx,float nz,float radius);
/* Stable ids: player 0, wild 1..n, nest 1000, obstacles 2000+i. */
int cp_stage_order(CpStageWorld *w,const CpStageInput *input);
int cp_stage_command(CpStageWorld *w,const char *command);
const char *cp_stage_order_error(int code);
typedef struct { uint32_t tick; CpStageInput input; } CpStageLogEntry;
uint64_t cp_stage_replay(const CpStageSetup *setup,const CpStageLogEntry *log,
                         int count,uint32_t ticks,uint64_t *hashes);
uint64_t cp_stage_step(CpStageWorld *w,const CpStageInput *input);
uint64_t cp_stage_hash(const CpStageWorld *w);
/* Returns bytes excluding NUL, or -1 on insufficient capacity. */
int cp_stage_observe(const CpStageWorld *w,char *out,size_t cap);
/* --- snapshot / restore (PLAN-devtools step 3) ---
 * A snapshot is a 48-byte little-endian header ("CPSTAGE\0", snapshot version, CP_STAGE_VERSION, layout
 * fingerprint, payload bytes, 0, field hash, state hash) followed by a raw copy of the POD world up to
 * (not including) `field`. Restore validates everything in the order of the error codes below and leaves the
 * world untouched on failure. */
enum { CP_STAGE_SNAP_OK=0, CP_STAGE_SNAP_ERR_MAGIC=-1, CP_STAGE_SNAP_ERR_FORMAT=-2,
       CP_STAGE_SNAP_ERR_ENGINE=-3, CP_STAGE_SNAP_ERR_LAYOUT=-4, CP_STAGE_SNAP_ERR_SIZE=-5,
       CP_STAGE_SNAP_ERR_FIELD=-6, CP_STAGE_SNAP_ERR_HASH=-7 };
size_t cp_stage_world_size(void);
size_t cp_stage_snapshot_size(void);
uint64_t cp_stage_layout(void);
int cp_stage_snapshot(const CpStageWorld *w,uint8_t *out,size_t cap);   /* bytes written, or ERR_SIZE */
int cp_stage_restore(CpStageWorld *w,const uint8_t *in,size_t len,const CpStageField *field);
const char *cp_stage_snapshot_error(int code);
/* Attaches (or with NULL detaches) the island heights. Call before cp_stage_reset in FIELD mode. */
int cp_stage_attach_field(CpStageWorld *w,const CpStageField *f);
#endif
