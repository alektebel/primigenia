/* P4 world foundation. CpWorld is reserved by the cell stage in cpore.h. */
#ifndef CPORE_WORLD_H
#define CPORE_WORLD_H
#include "cpore/combat.h"
#define CP_STAGE_VERSION 1
#define CP_STAGE_MAX_WILD 24
#define CP_STAGE_MAX_OBSTACLES 1024
#define CP_STAGE_DAY_TICKS 12000
#define CP_STAGE_DT .1f

enum { CP_STAGE_ANALYTIC, CP_STAGE_FLAT };
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
#endif
