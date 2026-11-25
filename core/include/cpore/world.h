/* P4 world foundation. CpWorld is reserved by the cell stage in cpore.h. */
#ifndef CPORE_WORLD_H
#define CPORE_WORLD_H
#include "cpore/combat.h"
#include "cpore/ledger.h"
#include "cpore/creature_types.h"
#define CP_STAGE_VERSION 4   /* 4: island-realism M3 (static trunks are circle obstacles; the field may carry cover and trunks) */
/* Roster v9 (T9, docs/plans/creature-loop.md): 32 wild slots. The island setup fills at most CP_STAGE_ROSTER_CAP of them; the rest are
 * reserved so evolving always finds a free slot for the cousin and the nest family can later be backed by C slots (godot/game/island/family.gd).
 * It is a budget, not fixed indices (cp_stage_evolve and the debug spawn take the next free index, setup.n):
 *   ROSTER_CAP (24)   slots the island setup may fill (radial animals, night and slug species)
 *   RESERVE_COUSIN 4  kept free for cousins, one per evolve (the 3 evolves of a chain leave 3 cousins)
 *   RESERVE_FAMILY 4  kept free for the nest family, not wired yet: the family is still visual only */
#define CP_STAGE_MAX_WILD 32
#define CP_STAGE_RESERVE_COUSIN 4
#define CP_STAGE_RESERVE_FAMILY 4
#define CP_STAGE_ROSTER_CAP (CP_STAGE_MAX_WILD-CP_STAGE_RESERVE_COUSIN-CP_STAGE_RESERVE_FAMILY)
#define CP_STAGE_COUSIN_MAX_DIST 40.f /* a cousin spawns at most this far (m) from the nest */
#define CP_STAGE_MAX_OBSTACLES 1024
#define CP_STAGE_DAY_TICKS 12000
#define CP_STAGE_DT .1f
#define CP_STAGE_GRACE_TICKS 600 /* 60 seconds at 10 Hz */
#define CP_STAGE_WAKE_RADIUS 6.f
#define CP_STAGE_WAKE_TICKS 150 /* 15 seconds since the last approach */
#define CP_STAGE_SNAPSHOT_VERSION 16   /* 3: player loadout (A21); 4: social layer (C2); 5: lineage ledger and ancestry; 6: discovery, nest shop and eggs; 7: secrets (shards, cave chamber, day/night) and 6 species; 8: run and fixed-point fall state; 9: + recipes, calcium, mineral, stones (C2 moves/recipes); 10: digging (holes, fossil beds) and the fire gland (first-quest); 11: 8 species (brujula, corona), Garfio grace and Acechalunas wake clocks (species-v8); 12: roster v9, 32 wild slots and 12 species capacity (8 defined, 4 reserved for the food web and flying species, A59); 13: A59 slope grip traits and wildlife fall state; 15: A72/A74 context attacks (variant, momentum, knockback, projectiles, hold); 16: jump (jumping flag, landing cooldown; feat/jump, was 14) */
/* A31 fall damage: 10 HP per metre beyond the safe drop, capped at 60 % of max HP unless the fall is free (air above 2x the safe drop). */
#define CP_FALL_CAP_PERMILLE 600
#define CP_FALL_FREE_X 2
#define CP_JUMP_STAMINA_PCT 6      /* % of max stamina per jump (starting value; play test checks it) */
#define CP_JUMP_COOLDOWN_TICKS 3   /* 0.3 s after landing */
#define CP_STAGE_MAX_PATH 64      /* waypoints kept by the planner (docs/godot/NAV.md) */
#define CP_STAGE_MAX_EVENTS 64    /* event ring since the last observe */

enum { CP_STAGE_ANALYTIC, CP_STAGE_FLAT, CP_STAGE_FIELD }; /* FIELD: the generated island, needs cp_stage_attach_field() before reset */
enum { CP_STAGE_TIMID, CP_STAGE_TERRITORIAL, CP_STAGE_AGGRESSIVE };
enum { CP_STAGE_CONTINUE, CP_STAGE_WAIT, CP_STAGE_GO, CP_STAGE_HEADING,
       CP_STAGE_APPROACH, CP_STAGE_ATTACK, CP_STAGE_FLEE, CP_STAGE_GO_NEST,
       CP_STAGE_GUARD, CP_STAGE_DODGE,
       CP_STAGE_LOADOUT,     /* target = slot 1..4, move = move id or -1 to empty the slot; instant, not a standing order */
       /* C2 social verbs (docs/P4.md section 2.1, G75). BEFRIEND: target + move = skill (CP_SOC_*); GIFT: target + move = item
        * (CP_ITEM_*); OBSERVE and INTIMIDATE: target. All are standing orders: the player walks into range, performs it, and the
        * order ends. Any other order cancels it. */
       CP_STAGE_BEFRIEND, CP_STAGE_GIFT, CP_STAGE_OBSERVE, CP_STAGE_INTIMIDATE,
       CP_STAGE_EAT, CP_STAGE_INSPECT, CP_STAGE_BUY_PART, CP_STAGE_BUY_LEVEL, CP_STAGE_BUY_TIER,
       CP_STAGE_DIG,
       CP_STAGE_QUEST };   /* QUEST: target = task step, move = DNA; instant, once per step (stage_dig.c); a logged input so replays agree */   /* DIG: no target; digs where the player stands (anywhere dry; harder ground takes longer, A54), takes CP_DIG_TICKS standing still, costs stamina (first-quest, stage_dig.c) */   /* EAT: target = a carcass; bites every 10 ticks until it is gone, the player is full, or another order cancels it */
#define CP_STAGE_NEST_RADIUS 12.f   /* metres from the nest within which the loadout can be changed (tunable) */
/* Stage order codes added by A21 (-1..-6 are older): the loadout and move errors share the combat numbers. */
enum { CP_STAGE_ERR_ON_COOLDOWN=-8, CP_STAGE_ERR_NOT_EQUIPPED=-9, CP_STAGE_ERR_BAD_SLOT=-10,
       CP_STAGE_ERR_NOT_KNOWN=-11, CP_STAGE_ERR_UNKNOWN_MOVE=-12, CP_STAGE_ERR_NOT_AT_NEST=-13, CP_STAGE_ERR_IN_FIGHT=-14,
       /* C2 social errors */
       CP_STAGE_ERR_REFUSES=-15,      /* hostile, aggressive and not calmed, or mood <= -20: the creature ignores social play */
       CP_STAGE_ERR_NO_ITEM=-16,      /* gift: none of that item carried */
       CP_STAGE_ERR_BAD_SKILL=-17,    /* unknown skill or item name/id */
       CP_STAGE_ERR_STAGGERED=-18,    /* a rival heckled you: social actions are blocked for a few ticks */
       CP_STAGE_ERR_NO_STAMINA=-19,   /* not enough stamina for the skill */
       CP_STAGE_ERR_BUSY=-20,
       CP_STAGE_ERR_DIET=-21,         /* eat: this body cannot digest that (a herbivore and meat) */
       CP_STAGE_ERR_FULL=-22,
       CP_STAGE_ERR_NEEDS_EVOLVE=-23, /* nest apply: the change alters parts, levels or tiers; it needs Evolve */
       CP_STAGE_ERR_NO_DNA=-24,
       CP_STAGE_ERR_HARD_GROUND=-27,  /* dig: water or outside the island (any dry ground can be dug, A54) */
       CP_STAGE_ERR_ALREADY_DUG=-28 };  /* dig: there is a hole here already */    /* nest evolve: the DNA balance does not cover the purchases */      /* eat: the food meter is full */
enum { CP_DIET_HERBIVORE, CP_DIET_CARNIVORE, CP_DIET_OMNIVORE };
#define CP_SOC_CARCASS_BITES 4    /* bites in a carcass */
#define CP_SOC_BITE_TICKS 5      /* ticks per bite */
#define CP_SOC_BITE_FOOD 12       /* food per bite of meat */
#define CP_SOC_FOOD_MAX 100
#define CP_SOC_FOOD_START 70
#define CP_SOC_FOOD_DECAY 60      /* ticks per food point lost */       /* a social action is already under way / on cooldown (intimidate) */
enum { CP_SOC_SING, CP_SOC_DANCE, CP_SOC_CHARM, CP_SOC_POSE, CP_SOC_COUNT };
enum { CP_ITEM_PLANT, CP_ITEM_FRUIT, CP_ITEM_MEAT, CP_ITEM_BONE, CP_ITEM_COUNT };
enum { CP_REL_STRANGER, CP_REL_NEUTRAL, CP_REL_TRUSTED, CP_REL_ALLY };
enum { CP_RES_OPEN, CP_RES_ALLY, CP_RES_HUNTED };
/* Where a DNA award came from (the move field of a DNA event). */
enum { CP_DNA_KILL, CP_DNA_BOND, CP_DNA_ALLY, CP_DNA_DOMINATE, CP_DNA_CARCASS, CP_DNA_EXPLORE, CP_DNA_SEEN, CP_DNA_DUPLICATE, CP_DNA_FOSSIL, CP_DNA_OLD_CARCASS, CP_DNA_SHARD, CP_DNA_TASK, CP_DNA_SOURCES };
#define CP_SOC_BOND_TRUST 60      /* trust at which a creature bonds (Q-3) */
#define CP_SOC_BEAT 12            /* ticks between beats */
#define CP_SOC_WINDOW 2           /* rhythm window, +- ticks */
#define CP_SOC_OBSERVE_TICKS 50   /* ticks of unseen watching per revealed clue */
#define CP_SOC_OBSERVE_RANGE 40.f
#define CP_SOC_SPECIES 12     /* capacity; defined: Rondo, Zanco, Espinodo, Garfio, Acechalunas, Babosa, Brujula, Corona. 8..11 are reserved (T11 food web, A59 flying) */
#define CP_STAGE_SPECIES_COUNT 12   /* table capacity */
#define CP_STAGE_SPECIES_DEFINED 8  /* species 0..7 exist; spawning or listing 8..11 is refused until their rows are written */
#define CP_SOC_CHAIN_ITEMS 3
#define CP_SOC_EXPLORE_MAX 40
enum { CP_STAGE_NONE, CP_STAGE_VICTORY, CP_STAGE_DEATH, CP_STAGE_FLED };
typedef struct { float x,z,r; int32_t type; } CpStageObstacle;
/* Daily rhythm (W8): nocturnal species are hidden (asleep, not perceivable, not targetable) while the day is bright and
 * wake at dusk; crepuscular ones keep out of the noon light (they hunker down: no roaming) and move at dawn, dusk and night. */
enum { CP_ACT_DIURNAL, CP_ACT_NOCTURNAL, CP_ACT_CREPUSCULAR };
typedef struct {
    const char *name;
    float speed,sight,roam,hostile;
    int32_t temperament;
    CpCombatProfile profile;
    int32_t activity;   /* CP_ACT_*; 0 for the four daytime species */
} CpStageSpecies;
extern const CpStageSpecies CP_STAGE_SPECIES[CP_STAGE_SPECIES_COUNT];
/* Stage locomotion (PLAN-feel, version 2; speed by body size A39). jog = sqrt(Fr_walk g h)*jog_k, run/sprint = sqrt(sprint_k g h)*jog_k
 * (sprint_k is the run Froude number, 2.2 since A54: starter B runs about 3.2 m/s), wild = the same times wild_k; h = 0.56 * body radius. See stage_world.c. */
typedef struct {
    float jog_k,sprint_k,wild_k;
    float accel,brake;               /* m/s2 caps on the per-tick speed change */
    float ease;                      /* share of the remaining speed error closed per tick */
    float turn_k,turn_min,turn_max;  /* turn0 = clamp(turn_k*sqrt(9.81/r_body), turn_min, turn_max) rad/s */
    float grip;                      /* lateral limit, m/s2: yaw rate <= grip/v */
    float pivot_k,pivot_mul,pivot_max; /* pivot only below pivot_k*jog; rate clamp(pivot_mul*turn0, 3, pivot_max) */
    float turn_slow;                 /* wanted *= (1-turn_slow)+turn_slow*max(dot,0) */
    /* Steering and slopes (core/src/steer.c; docs/godot/LOCOMOTION.md). Radius r in metres, legs 1..8. */
    float ang_k;                     /* yaw acceleration = ang_k*9.81/r rad/s2 */
    float grip_mass;                 /* lateral grip /= 1+grip_mass*max(r-0.6,0): big bodies turn wider */
    float acc_mass;                  /* accel and brake /= 1+acc_mass*max(r-0.6,0) */
    float creep;                     /* a body that cannot pivot keeps at least this share of its speed in a U-turn */
    float pivot_r;                   /* only bodies up to this radius (m) turn on the spot */
    float look_min,look_k;           /* pure-pursuit lookahead = look_min + look_k*speed, metres */
    float climb_base,climb_legs;     /* grade a body plans and walks at: climb_base + climb_legs*(legs-2)/6, less for big bodies */
    float stall_mul;                 /* it cannot walk up a grade above climb*stall_mul (speed falls to 0 there) */
    float slide_mul,slide_k;         /* above grade stall*slide_mul it slides down at slide_k*(excess)+0.4 m/s */
    float down_gain;                 /* extra speed on a mild downhill (share, at grade 0.2) */
    float walk_fr;                   /* walk Froude number (default .24, A39); player and wild walkers: v = sqrt(walk_fr g h)*jog_k */
} CpStageMotion;
extern const CpStageMotion CP_STAGE_MOTION;
typedef struct {
    float x,z,home_x,home_z;
    int32_t species,bot; /* -1 uses the temperament's standard bot */
    CpCombatProfile profile;
    int32_t legs;        /* 0 = 4 */
} CpStageSpawn;
/* The hidden cave (G65, W18). `x,z` is the entrance cell and (fx,fz) the outward unit vector of the terrain record; the interior is a
 * corridor of half-width `half` that runs `length` m into the rock from the entrance plane and ends in a round chamber of
 * `radius` m. Inside it the walkable ground is flat at `floor` (the heightfield cannot represent a hollow). */
typedef struct { int32_t on; float x,z,fx,fz,floor,half,length,radius; } CpStageCave;
enum { CP_SECRETS_SHARDS=1, CP_SECRETS_CAVE=2 };   /* setup.secrets bits; the route tests use the cave alone (the shard placement walks the whole island) */
typedef struct {
    uint32_t seed,terrain_seed;
    int32_t terrain,n,n_obstacles;
    float nest_x,nest_z,flat_height,water_x,water_z,water_radius;
    CpCombatProfile player;
    int32_t player_legs; /* 0 = 4 */
    CpStageSpawn wild[CP_STAGE_MAX_WILD];
    CpStageObstacle obstacles[CP_STAGE_MAX_OBSTACLES];
    /* C2 secrets (core/src/stage_secrets.c). All zero = off, and then nothing below touches the simulation or its hash. */
    int32_t secrets;                 /* CP_SECRETS_* bits (FIELD only): 1 place the meteor shards from the island field, 2 open the cave chamber */
    int32_t start_clock;             /* world clock at tick 0 (0 = midnight, 3000 = 06:00); the game starts in the morning */
    CpStageCave cave;                /* the hidden cave entrance record (terrain caves[0]); chamber is derived from it */
} CpStageSetup;
typedef struct {
    int32_t verb,target,move,dir,sprint;
    int16_t hx,hz;
    float x,z;
} CpStageInput;   /* ATTACK: `dir` 1 = the key was held (A74: spit throws the charged glob, or the charged lob from far); the logs carry it as is */
typedef struct {
    float x,z,fx,fz,hp,stamina,speed,acceleration,turn_rate;
    float home_x,home_z,goal_x,goal_z;
    int32_t species,dead,pivot,returning,roam_ticks;
    CpCombatProfile profile;
    /* Steering (CP_STAGE_VERSION 3): yaw rate, legs (0 = 4) and the slide flag are state; grade is derived (not hashed). */
    float omega,grade;
    int32_t legs,sliding;
    /* A59 wildlife airborne state; player keeps the A31 world fields. */
    int32_t slip_air,slip_y,slip_v,slip_start,slip_dx,slip_dz;
} CpStageCreature;
/* Adapter state for the existing public apps/combat_bots.h API. No bot rules
 * are duplicated here; stage_world.c copies these fields to/from CpBot. */
typedef struct {
    CpRng rng;
    int32_t kind,spam_move,delay,reaction,ranged_commit,timer;
} CpStageBot;
/* A trunk that matters to the sim (island-realism plan 4.3; core/src/flora_place.c): a circle obstacle, placed once from the vegetation maps. */
typedef struct CpStageTrunk {
    float x,z,r,h;                   /* metres: centre, collision radius, tree height */
    int32_t species;                 /* CP_FLORA_SP_* (flora.h) */
} CpStageTrunk;
/* The trunks as a static spatial hash: `index` lists record numbers cell by cell (bucket c = index[start[c]..start[c+1])), buckets are
 * `cell` metres square over the field's square, row-major j*cell_n+i. Built by cp_stage_trunks_index (flora_place.c); not owned by C. */
typedef struct CpStageTrunks {
    int32_t count,cell_n;
    float cell;
    const CpStageTrunk *rec;
    const int32_t *start,*index;
} CpStageTrunks;
#define CP_TRUNK_RMAX 2.f            /* no trunk is wider than this (the spatial queries inflate by it) */
/* Generated island heights handed to the world by pointer (PLAN-heights H1). Not owned by C. */
typedef struct CpStageField {
    int32_t n;
    float size_m,cell,half;          /* cell = size_m/n, half = size_m/2 */
    const float *height;             /* n*n metres, row-major j*n+i (z rows, x columns) */
    const float *water_level;        /* n*n depression-filled level, may be NULL */
    uint64_t hash;                   /* cp_terrain_hash of the generated terrain, then sealed with the fields below by cp_stage_field_seal */
    /* Island-realism M3 (all optional, NULL/0 = a bare field: nothing below touches the simulation). Static and derived, so no snapshot
     * change; they are folded into `hash` by cp_stage_field_seal, so a different cover, trunk set or tuning is a different field. */
    const uint8_t *cover;            /* n*n undergrowth 0..255 at the field's resolution; 0 ONLY on a game trail (off the trails it is at least 1) */
    const CpStageTrunks *trunks;
    float cover_slow,trail_bonus;    /* speed *= 1 - cover_slow*cover/255 in undergrowth, *= 1 + trail_bonus on a trail. Ship 0 and 0 (plan risk 5): R tunes (0.4 and 0.15) */
} CpStageField;
/* Folds cover, trunks and the two tuning values into f->hash (terrain_hash is cp_terrain_hash of the island). With no cover and no
 * trunks the hash is the terrain hash unchanged. Call after every change to those members. */
void cp_stage_field_seal(CpStageField *f,uint64_t terrain_hash);
/* Events since the last cp_stage_ack_events(): what the agent could not see from positions alone. */
enum { CP_STAGE_EV_HIT=1, CP_STAGE_EV_KILL, CP_STAGE_EV_DEATH, CP_STAGE_EV_RESPAWN, CP_STAGE_EV_ORDER_REJECTED,
       CP_STAGE_EV_PATH_FOUND, CP_STAGE_EV_ARRIVED, CP_STAGE_EV_FLED, CP_STAGE_EV_PATH_FAILED,
       /* C2 social events: by = 0, target = creature id; move/value/x/z carry the detail (see stage_social.c) */
       CP_STAGE_EV_SKILL, CP_STAGE_EV_GIFT, CP_STAGE_EV_BOND_MADE, CP_STAGE_EV_BOND_BROKEN, CP_STAGE_EV_SPECIES_RESOLVED,
       CP_STAGE_EV_DNA, CP_STAGE_EV_OBSERVE, CP_STAGE_EV_CHAIN_DONE, CP_STAGE_EV_INTIMIDATE, CP_STAGE_EV_SOCIAL_CANCELLED, CP_STAGE_EV_EAT, CP_STAGE_EV_PART_FOUND, CP_STAGE_EV_INSPECTED, CP_STAGE_EV_PART_BOUGHT, CP_STAGE_EV_EDIT_ACCEPTED,
       CP_STAGE_EV_SHARD_FOUND,   /* target = shard entity id (3100+k), move = shard index 0..4, value = shards found so far, x/z = where; numeric id 25 is used by the Godot UI */
       CP_STAGE_EV_CAVE,          /* move = 1 entered the passage, 2 reached the chamber (numeric id 26) */
       CP_STAGE_EV_FELL,          /* numeric id 27 (owner fall) */
       CP_STAGE_EV_RECIPE,        /* numeric id 28 */
       CP_STAGE_EV_VOLLEY,        /* numeric id 29 */
       CP_STAGE_EV_DUG,        /* numeric id 30: target = hole index, move = CP_FIND_* (-1 = the dig was interrupted), value = bed index or -1, x/z = the hole */
       CP_STAGE_EV_MOVE_USED };  /* numeric id 31: the player started a combat move: move = move id, value = 1 */

enum { CP_STAGE_BLOCK_NONE, CP_STAGE_BLOCK_CLIFF, CP_STAGE_BLOCK_WATER, CP_STAGE_BLOCK_EDGE,
       CP_STAGE_BLOCK_CREATURE, CP_STAGE_BLOCK_UNREACHABLE, CP_STAGE_BLOCK_OBSTACLE };
typedef struct {
    uint32_t tick;
    int32_t type,by,target,move;   /* by/target: 0 = player, 1..n = wild creature id; move = combat move index or -1 */
    float value,x,z;               /* damage (HIT), path length in metres (PATH_FOUND), error code (ORDER_REJECTED) */
} CpStageEvent;
/* The social layer (C2). Per wild creature, per species and for the player; all integers. It is tracked from tick 0 but
 * folded into the world hash only once a social verb was accepted (`used`), so a run that never uses one keeps its hash. */
typedef struct {
    int16_t trust,mood;              /* trust 0..100, mood -50..50 */
    uint8_t bonded,ever_bonded,met,combo; /* bonded = the latch (Q-4); ever_bonded pays the bond DNA once; combo 0..2 */
    int32_t last_contact;            /* tick of the last social contact (decay clock), 0 = never */
    int32_t calm_ticks,leave_ticks,aggro_ticks; /* calmed by a liked gift; driven off by intimidate; hostile after its pack was attacked */
    int32_t last_skill,last_skill_tick;  /* combo: the previous skill started on this creature (-1 none) */
    int32_t hab_tick[CP_SOC_COUNT];  /* habituation: tick+1 of the last use of each skill, 0 = never */
    uint8_t hab_n[CP_SOC_COUNT];
    int32_t carcass_seen,eaten;      /* carcass DNA paid (first bite); bites taken from this carcass */
} CpStageSocialCreature;
typedef struct {
    CpRng rng;                       /* the `social` stream: mood jitter, rival heckle, display contest */
    int32_t used;                    /* a social verb has been accepted: the block below is hashed */
    int32_t dna_total,dna_balance;   /* total only rises (Q-1); balance is spendable */
    int32_t items[CP_ITEM_COUNT];
    int32_t act_verb,act_target,act_arg,act_t,act_len,act_rhythm,act_mult; /* the action under way (verb 0 = none) */
    int32_t stagger,intimidate_cd;
    int32_t food,diet;               /* hunger meter 0..100 (no starvation effect yet) and the body's diet (CP_DIET_*, omnivore by default) */
    int32_t obs_target,obs_ticks,obs_need;    /* observe: creature watched and ticks on the current clue */
    int32_t obs_items[CP_SOC_SPECIES]; /* clues revealed per species chain, 0..3 */
    uint32_t learned;                /* moves learned by observing (bit = 1 << move id) */
    int32_t kills[CP_SOC_SPECIES],latched[CP_SOC_SPECIES],resolution[CP_SOC_SPECIES],first_met[CP_SOC_SPECIES];
    uint64_t tested;                 /* preferences tried: bit s*8+k = species s skill k (k<4) or gift k-4, sign in `liked` */
    uint64_t liked;
    int32_t dna_by_source[CP_DNA_SOURCES];
    int32_t n_explored,explored[CP_SOC_EXPLORE_MAX];
    uint32_t species_seen;
    CpStageSocialCreature c[CP_STAGE_MAX_WILD];
} CpStageSocial;
typedef struct {
    char body[CP_LINEAGE_BODY_CAP],name[80];
    uint16_t parts[CP_LINEAGE_PARTS];
    CpCombatProfile profile;
} CpLineageForm;
typedef struct {
    CpLineageForm form;
    uint32_t generation,traits,deeds[CP_DEED_COUNT];
    int32_t cousin_id,home_x,home_z,temperament,diet,trust_bonus,type;
} CpLineageGeneration;
typedef struct { int32_t cell_x,cell_z,x,z; uint32_t ticks; } CpLineageResidence;
typedef struct {
    uint32_t count,n_residence,perk_serial[CP_TYPE_PERKS];
    CpLineageResidence residence[128];
    CpLineageGeneration forms[CP_LINEAGE_GENERATIONS];
} CpAncestry;
/* Part ids are stable catalogue indices, shared by the codex and lineage ledger. */
#define CP_STAGE_PART_COUNT 49   /* 47 (moves/recipes) + wing_vane, fire_gland (first-quest) */
#define CP_STAGE_PART_NODES 8
enum { CP_PART_KILL, CP_PART_ALLY, CP_PART_CARCASS, CP_PART_FOSSIL, CP_PART_OLD_CARCASS };
typedef struct { const char *id; int cost,mouth,charge,spit,tail,guard; } CpStagePartDef;
extern const CpStagePartDef CP_STAGE_PARTS[CP_STAGE_PART_COUNT];
extern const uint16_t CP_STAGE_PART_MOVES[CP_STAGE_PART_COUNT]; /* C2 morphology requirements */
typedef struct { float x,z; int kind,inspected; } CpStagePartNode;
typedef struct {
    CpRng loot,fossil;
    uint64_t discovered,owned,starter;
    uint8_t level[CP_STAGE_PART_COUNT],tier[CP_STAGE_PART_COUNT];
    uint32_t hits[CP_STAGE_PART_COUNT],wins[CP_STAGE_PART_COUNT],kills[CP_STAGE_PART_COUNT];
    uint32_t move_hits[CB_MOVE_COUNT],move_wins[CB_MOVE_COUNT];
    int dry[CP_STAGE_SPECIES_COUNT],kill_paid[CP_STAGE_MAX_WILD],ally_paid[CP_STAGE_SPECIES_COUNT];
    int used,eggs,lost,hatchling,n_nodes,inspect_id,inspect_ticks;
    int tiers_on,clues; /* A25: tier forms are built but off by default; fossil/bone clues (2 unlock a recipe) */
    float adult_hp;
    CpStagePartNode nodes[CP_STAGE_PART_NODES+1]; /* one extra slot: the cave chamber fossil, placed after the random nodes */
} CpStageParts;
enum { CP_RECIPE_UNKNOWN, CP_RECIPE_HINTED, CP_RECIPE_KNOWN, CP_RECIPE_MASTERED };
#define CP_STONE_NODES 6
typedef struct {
    int used,state,clues,calcium,mineral,eat_node,eat_ticks,n_stones;
    CpRng stone_rng;
    CpStagePartNode stones[CP_STONE_NODES];
    uint16_t cd[CB_MOVE_COUNT];
    uint8_t old_units[CP_STAGE_PART_NODES];
    uint8_t wild_calcium[CP_STAGE_MAX_WILD],quill_carcass[CP_STAGE_MAX_WILD];
} CpStageRecipes;
#define CP_STAGE_SHARDS 5
#define CP_STAGE_SHARD_ID 3100     /* entity ids of shards: 3100..3104 (fossil/bone nodes are 3000..3008, the nest 1000) */
/* Secrets state (stage_secrets.c). Sites are derived from the setup and the field at reset; `found` and the cave flags are play state. */
typedef struct {
    int32_t on,n_shards,found_mask,found,cave_entered,chamber_entered,placed_scale;
    float shard[CP_STAGE_SHARDS][2];
    float crater_x,crater_z;         /* where the ejecta ray ends (not yet a landmark: the crater itself is C5) */
    int32_t cave_on;
    float cave_x,cave_z,cave_fx,cave_fz,cave_floor,cave_half,cave_length,cave_radius,chamber_x,chamber_z;
} CpStageSecrets;
/* Digging (core/src/stage_dig.c): fossil beds placed at reset, holes the player leaves, the dig in progress. Everything is
 * integer or + - * /, derived from the seed and the field, and hashed only once a dig was accepted (`used`). */
#define CP_STAGE_BEDS 4
#define CP_STAGE_HOLES 16
#define CP_DIG_TICKS 20          /* 2 s standing still on soft soil */
#define CP_DIG_TICKS_HARD 35     /* 3.5 s on hard ground (steep, shore sand) */
#define CP_DIG_TICKS_ROCK 50     /* 5 s on rock (cliffs, caves) */
#define CP_DIG_STAMINA 12.f
#define CP_BED_RADIUS 3.f
enum { CP_BED_WING, CP_BED_BONE };
enum { CP_FIND_NONE, CP_FIND_GRUB, CP_FIND_PEBBLE, CP_FIND_WING_FOSSIL, CP_FIND_BONE_FOSSIL };
typedef struct { float x,z,r; int32_t kind,dug; } CpStageBed;
typedef struct { float x,z; int32_t find; } CpStageHole;
typedef struct {
    CpRng rng;                       /* the finds of ordinary soil; its own stream, seeded from the world seed */
    int32_t used,n_beds,n_holes,dug_total,act_t,flames,wing_found,fire_found;
    uint32_t quest_paid;             /* bit k: the DNA reward of task step k was paid (cp_stage_quest_award) */
    float act_x,act_z;
    CpStageBed bed[CP_STAGE_BEDS];
    CpStageHole hole[CP_STAGE_HOLES];
} CpStageDig;
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
    int32_t debug_flags,edit_anywhere; /* CP_STAGE_FLAG_* ; edit_anywhere (0/1, never hashed, set by the host's setting) lets the genome edits skip the nest radius */
    uint64_t field_hash;             /* hash of the attached field, 0 outside FIELD mode */
    /* C1-nav: the GO / GO_NEST path (hashed while n_path>0) and derived observation outputs (not hashed). */
    float path[CP_STAGE_MAX_PATH][2];/* waypoints, the last is where the order ends */
    int32_t n_path,path_i,blocked_ticks,replans;
    float path_goal_x,path_goal_z;   /* the unsnapped target of the planned order */
    int32_t blocked_reason;          /* CP_STAGE_BLOCK_* of the last step, derived */
    float blocked_x,blocked_z;
    uint32_t ev_total,ev_acked;      /* events pushed / already shown to the agent; ring index = n % CP_STAGE_MAX_EVENTS */
    CpStageEvent events[CP_STAGE_MAX_EVENTS];
    CpCombatLoadout loadout;         /* the player's kit; copied into the fight at its start; hashed when custom */
    CpAncestry ancestry;
    CpLedger ledger;              /* L0: opt in via cp_ledger_init; snapshot owns it */
    CpStageSocial social;            /* C2: trust, DNA, species progress, observe; hashed once `social.used` */
    CpStageParts parts;
    CpStageRecipes recipes;
    CpStageSecrets secrets;          /* derived at reset when setup.secrets; hashed only then */
    /* Run stamina is separate from combat stamina; mm, mm/s for fixed-step gravity. */
    int32_t running,run_stamina,falling,fall_y_mm,fall_v_mm_s,fall_start_mm;
    int32_t fall_dx_mm,fall_dz_mm;
    int32_t jumping,jump_cd;         /* jump: the current air phase was a jump (keeps the run-up speed on landing); ticks until another jump is allowed */
    CpStageDig dig;                  /* first-quest: fossil beds, holes, the dig in progress (snapshot 9) */
    uint32_t grace_until,wake_until[CP_STAGE_MAX_WILD]; /* v8 AI clocks; zero keeps legacy hashes */
    const CpStageField *field;       /* not owned, not in the snapshot, set by cp_stage_attach_field */
} CpStageWorld;
/* Speed factor of the ground at (x,z) from the field's cover (1 off the field, without cover, or with both tunings 0). */
float cp_stage_ground_speed(const CpStageWorld *w,float x,float z);
/* Trunks within the circle: number of trunks whose centre is closer than r + their radius to (x,z). */
int cp_stage_trunk_hit(const CpStageWorld *w,float x,float z,float r);
/* --- first-quest digging (core/src/stage_dig.c) --- */
void cp_stage_dig_reset(CpStageWorld *w);
int cp_stage_dig_order(CpStageWorld *w,const CpStageInput *a);
void cp_stage_dig_step(CpStageWorld *w);
int cp_stage_quest_award(CpStageWorld *w,int step,int dna);   /* pays a task step's DNA once; 0, or -1 when invalid or already paid */
void cp_stage_dig_flame(CpStageWorld *w);                      /* the player started the flamethrower */
int cp_stage_soft_soil(const CpStageWorld *w,float x,float z); /* soft soil here: dry, gentle, outside the cave (fossil beds sit on it, the dig is fastest on it) */
int cp_stage_dig_hardness(const CpStageWorld *w,float x,float z); /* 0 soft, 1 hard, 2 rock, -1 cannot dig (water, outside); A54 */
int cp_stage_dig_ticks(const CpStageWorld *w,float x,float z);    /* standing-still ticks the dig takes here: 20, 35 or 50 */
uint64_t cp_stage_dig_hash(const CpStageWorld *w);
int cp_stage_dig_json(const CpStageWorld *w,char *out,size_t cap);
int cp_stage_dig_observe(const CpStageWorld *w,char *out,size_t cap);   /* the agent's view: progress, holes, and the cue of any bed within 30 m (no coordinates of the far ones) */
/* --- C2 secrets (core/src/stage_secrets.c) --- */
void cp_stage_set_run(CpStageWorld *w,int on);
/* Space: a hop on the ground, applied before the step like set_run (log v5: bit 2 of the run column). Apex 0.8 x hip height, within
 * [0.2, 1.2] m and at most half the safe drop, so a jump on flat ground never hurts; the horizontal speed carries over. Costs
 * CP_JUMP_STAMINA_PCT % of max stamina. Returns 0 (jumped) or CP_STAGE_ERR_* / -1 when refused (nothing changes). */
int cp_stage_jump(CpStageWorld *w);
float cp_stage_jump_height(const CpStageWorld *w);   /* the apex in metres for the player's body */
float cp_stage_safe_drop(const CpStageWorld *w); /* metres, 1.5 times mean leg length */
int cp_stage_daylight(const CpStageWorld *w);                /* permille 0 (night) .. 1000 (full day), from the world clock */
int cp_stage_creature_hidden(const CpStageWorld *w,int index); /* index 0..n-1: asleep by day, unless approached within 6 m or recently awake */
int cp_stage_creature_hunkered(const CpStageWorld *w,int index); /* a crepuscular creature curled up in the noon light */
void cp_stage_secrets_reset(CpStageWorld *w);                /* after parts_reset: shards, cave chamber and its fossil node */
void cp_stage_secrets_step(CpStageWorld *w);
int cp_stage_secrets_order(CpStageWorld *w,const CpStageInput *a,int *rc); /* 1 = a shard collect order (rc is its result) */
uint64_t cp_stage_secrets_hash(const CpStageWorld *w);
int cp_stage_secrets_json(const CpStageWorld *w,char *out,size_t cap);
float cp_stage_secrets_ground(const CpStageWorld *w,float x,float z,float h); /* heightfield height h, overridden inside the cave */
int cp_stage_in_cave(const CpStageWorld *w,float x,float z);   /* 0 outside, 1 in the passage, 2 in the chamber */
extern const char *const CP_STAGE_SHARD_LINES_EN[CP_STAGE_SHARDS],*const CP_STAGE_SHARD_LINES_ES[CP_STAGE_SHARDS],*const CP_STAGE_SHARD_NAMES[CP_STAGE_SHARDS];
/* Fixed site lives in setup.nest_x/z; C3 may replace that setup choice without changing any caller. */
typedef struct {const char *id,*source;int cap,refill,spend;} CpStageMeterDef;
typedef struct {const char *id;int part[2],level[2],diet,move,meter;} CpStageRecipeDef;
extern const CpStageMeterDef CP_STAGE_METERS[2];
extern const CpStageRecipeDef CP_STAGE_RECIPES[1];
void cp_stage_recipes_reset(CpStageWorld *w);
void cp_stage_recipes_step(CpStageWorld *w);
void cp_stage_recipe_clue(CpStageWorld *w,int source);
int cp_stage_recipe_ready(const CpStageWorld *w);
void cp_stage_meter_add(CpStageWorld *w,int meter,int amount);
int cp_stage_stone_eat(CpStageWorld *w,int target);
uint64_t cp_stage_recipes_hash(const CpStageWorld *w);
int cp_stage_recipes_json(const CpStageWorld *w,char *out,size_t cap);
int cp_stage_at_nest(const CpStageWorld *w);
int cp_stage_route_from_nest(CpStageWorld *w,float x,float z); /* read-only planner probe */
int cp_stage_can_edit(const CpStageWorld *w);          /* at the nest, or anywhere when edit_anywhere is on (never in a fight, dead or lineage lost) */
void cp_stage_set_edit_anywhere(CpStageWorld *w,int on);
int cp_stage_walkable_from_nest(const CpStageWorld *w,float x,float z);
int cp_stage_part_id(const char *id);
int cp_stage_legacy_apply(CpStageWorld *w,int diet,int part); /* the cell's legacy: starting diet (-1 keep) and one owned starter part (-1 none) */
int cp_stage_part_find(CpStageWorld *w,int part,int source);
int cp_stage_part_buy(CpStageWorld *w,int part,int kind); /* 0 part, 1 next level, 2 next tier */
int cp_stage_edit(CpStageWorld *w,const char *genome);  /* Evolve: buys what the genome adds, then cp_stage_evolve once */
int cp_stage_apply(CpStageWorld *w,const char *genome); /* free repaint/rearrange at the nest: no generation */
void cp_stage_set_tiers(CpStageWorld *w,int on);
int cp_stage_start_genome(CpStageWorld *w,const char *genome);
void cp_stage_genome_tiers(const char *body,uint8_t tiers[CB_PART_COUNT]);
int cp_stage_genome_form(const char *json,CpLineageForm *form); /* validates /4 and /5, derives profile in C */
void cp_stage_parts_reset(CpStageWorld *w);
void cp_stage_parts_kill(CpStageWorld *w,int index);
void cp_stage_parts_ally(CpStageWorld *w,int species);
void cp_stage_parts_win(CpStageWorld *w);
void cp_stage_parts_usage(CpStageWorld *w,int move,int won);
void cp_stage_parts_death(CpStageWorld *w);
void cp_stage_parts_step(CpStageWorld *w);
int cp_stage_parts_order(CpStageWorld *w,const CpStageInput *a);
uint64_t cp_stage_parts_hash(const CpStageWorld *w);
int cp_stage_parts_json(const CpStageWorld *w,char *out,size_t cap);
int cp_stage_lineage_form(CpStageWorld *w,const CpLineageForm *form,int evolve);
int cp_stage_lineage_perk(CpStageWorld *w,int kind,uint32_t serial,int amount);
int cp_stage_evolve(CpStageWorld *w,const CpLineageForm *form);
int cp_stage_cousin_generation(const CpStageWorld *w,int entity_id);
int cp_stage_species_counts_progress(const CpStageWorld *w,int entity_id);
uint64_t cp_stage_ancestry_hash(const CpStageWorld *w);
int cp_stage_lineage_export(const CpStageWorld *w,char *out,size_t cap);
int cp_stage_lineage_begin(CpStageWorld *w);
int cp_stage_lineage_award(CpStageWorld *w,int deed,uint32_t amount,uint32_t cause);
void cp_stage_lineage_tick(CpStageWorld *w,int32_t old_x,int32_t old_z);
void cp_stage_setup_default(CpStageSetup *s,uint32_t seed);
int cp_stage_reset(CpStageWorld *w,const CpStageSetup *s);
float cp_stage_height(const CpStageWorld *w,float x,float z);
float cp_stage_ground(const CpStageWorld *w,float x,float z);
/* Standing water depth at (x,z) in metres (0 on dry land); walking is blocked deeper than 0.7 m. */
float cp_stage_water_depth(const CpStageWorld *w,float x,float z);
/* Half-extent of the walkable square: 195 m for ANALYTIC/FLAT, half-2*cell for FIELD. */
float cp_stage_bound(const CpStageWorld *w);
int cp_stage_can_walk(const CpStageWorld *w,float x,float z,float nx,float nz,float radius);
/* Stable ids: player 0, wild 1..n, nest 1000, obstacles 2000+i. */
int cp_stage_order(CpStageWorld *w,const CpStageInput *input);
int cp_stage_command(CpStageWorld *w,const char *command);
/* Parses a command text into the input it stands for, touching no world: 0 or the error code (-1 invalid, -6 / -12 unknown_move). */
int cp_stage_parse(const char *text,CpStageInput *out);
const char *cp_stage_order_error(int code);
/* Moves the player may slot (parts today; learned-by-observing moves will be added here). */
uint16_t cp_stage_known_moves(const CpStageWorld *w);   /* -4 = unreachable (no walkable route within the search limit) */
/* The current GO path: copies up to cap (x,z) pairs of the remaining waypoints (path_i..n_path), returns how many. */
int cp_stage_path(const CpStageWorld *w,float *xz,int cap);
/* The walkable grid cell size used by the planner for the attached field (0 when none / nav disabled). */
float cp_stage_nav_cell(const CpStageWorld *w);
/* Fills the whole walk grid now (about a second on the 3600 m island) so that no later GO pays for it; returns the grid
 * size or 0 when there is no field. Optional: the grid also fills lazily as the planner expands cells. */
int cp_stage_nav_warm(const CpStageWorld *w);
/* Marks every event so far as seen (the Python binding does this after each observe()). */
void cp_stage_ack_events(CpStageWorld *w);
typedef struct { uint32_t tick; CpStageInput input; } CpStageLogEntry;
uint64_t cp_stage_replay(const CpStageSetup *setup,const CpStageLogEntry *log,
                         int count,uint32_t ticks,uint64_t *hashes);
/* --- C2 social layer (core/src/stage_social.c) --- */
typedef struct { const char *name; int windup,active,recovery; float range; float stamina; } CpStageSkill;
extern const CpStageSkill CP_STAGE_SKILLS[CP_SOC_COUNT];   /* sing, dance, charm, pose */
extern const char *const CP_STAGE_ITEM_NAMES[CP_ITEM_COUNT];  /* plant, fruit, meat, bone */
typedef struct { const char *id,*trait; int move; const char *observe[CP_SOC_CHAIN_ITEMS]; } CpStageChain;
extern const CpStageChain CP_STAGE_CHAINS[CP_SOC_SPECIES];  /* one A22 chain per species; move = combat move id it teaches */
int cp_stage_social_relationship(const CpStageWorld *w,int index);   /* CP_REL_* of wild creature index 0..n-1 */
int cp_stage_social_beat_in(const CpStageWorld *w,int index);        /* ticks until that creature's next beat */
int cp_stage_social_hostile(const CpStageWorld *w,int index);        /* would it attack the player now */
int cp_stage_social_species_present(const CpStageWorld *w);          /* distinct species in the world */
int cp_stage_social_species_resolved(const CpStageWorld *w);
/* Gives items (tests, pickups later) / spends DNA. Spend returns 0 or -1 if the balance is too low; dna_total never changes. */
int cp_stage_social_give(CpStageWorld *w,int item,int count);
int cp_stage_social_spend(CpStageWorld *w,int amount);
int cp_stage_social_set_diet(CpStageWorld *w,int diet);               /* CP_DIET_*; the body's diet (from the genome later) */
int cp_stage_social_carcass_meat(const CpStageWorld *w,int index);    /* bites left in the dead creature's carcass */
/* internal hooks used by stage_world.c */
int cp_stage_social_order_check(CpStageWorld *w,const CpStageInput *a);
void cp_stage_social_step(CpStageWorld *w);
void cp_stage_social_on_fight(CpStageWorld *w,int index);
void cp_stage_social_on_kill(CpStageWorld *w,int index);
int cp_stage_social_shielded(const CpStageWorld *w,int index);   /* the player is offering a gift: it does not engage */
int cp_stage_social_pacified(const CpStageWorld *w,int index);   /* bonded, allied, calmed or driven off: not hostile */
int cp_stage_social_leaving(const CpStageWorld *w,int index);
uint64_t cp_stage_social_hash(const CpStageWorld *w);
void cp_stage_social_reset(CpStageWorld *w);
float cp_stage_social_reach(const CpStageWorld *w,const CpStageInput *a);   /* centre-to-centre distance at which the player stops walking */
int cp_stage_social_json(const CpStageWorld *w,char *out,size_t cap);                     /* the "social" object of world-2 */
int cp_stage_social_creature_json(const CpStageWorld *w,int index,char *out,size_t cap);  /* extra fields of a nearby creature, starts with a comma */
int cp_stage_social_carcass_json(const CpStageWorld *w,int index,char *out,size_t cap);  /* meat/edible of a carcass entry, starts with a comma */
int cp_stage_social_event_json(const CpStageEvent *e,char *out,size_t cap);               /* bytes, 0 when not a social event */
int cp_stage_social_parse(const char *text,CpStageInput *out,int *rc);   /* 1 = was a social command (rc is its result), 0 = not one */
int cp_stage_social_legal(const CpStageWorld *w,int verb);               /* the verb is worth listing in legal_verbs */
/* --- debug ops (PLAN-devtools step 4): the only way the dev tools change the simulation --- */
enum { CP_STAGE_DBG_TELEPORT=1, CP_STAGE_DBG_SPAWN, CP_STAGE_DBG_KILL, CP_STAGE_DBG_HEAL,
       CP_STAGE_DBG_CLOCK, CP_STAGE_DBG_FLAGS, CP_STAGE_DBG_PARAM, CP_STAGE_DBG_GRANT };
enum { CP_STAGE_FLAG_GOD=1, CP_STAGE_FLAG_AI_OFF=2 };
/* TELEPORT id x z | SPAWN a=species x z | KILL id | HEAL id x=hp z=stamina (negative = max) | CLOCK a=tick |
 * FLAGS a=mask | PARAM a=index into CP_STAGE_PARAMS v=value (clamped) |
 * GRANT a=part id (catalogue index) or -1 for every part: discovered and owned at level >= 1 (dev builds: a creature made in the creator
 * keeps all its parts, and the nest ownership checks accept them). id 0 = player, 1..n = wild. */
typedef struct { int32_t op,id,a; float x,z,v; } CpStageDebug;
typedef struct { uint32_t tick; CpStageDebug d; } CpStageDebugEntry;
/* 0 on success, <0 and nothing changed otherwise (text: cp_stage_debug_error). Recomputes w->hash. */
int cp_stage_debug(CpStageWorld *w,const CpStageDebug *d);
const char *cp_stage_debug_error(int code);
typedef struct { const char *name,*group; size_t offset; float min,max; } CpStageParam;
extern const CpStageParam CP_STAGE_PARAMS[];
extern const int CP_STAGE_PARAM_COUNT;
/* Replay from a setup (snapshot NULL) or from a snapshot, with orders and debug ops; entries carry absolute
 * world ticks. Per tick: debug ops, then the order input, then the step. */
uint64_t cp_stage_replay_ex(const CpStageSetup *setup,const uint8_t *snapshot,size_t snap_len,const CpStageField *field,
                            const CpStageLogEntry *log,int count,const CpStageDebugEntry *dbg,int dbg_count,
                            uint32_t ticks,uint64_t *hashes);
/* Input log v4/v5: bit 0 of `on` is the run toggle of a tick, bit 1 (v5) a jump requested that tick (cp_stage_jump after set_run). Run toggle (`on` 0/1, applied with cp_stage_set_run after that tick's debug ops, before its order and
 * step, as the Godot session does). Entries carry absolute world ticks, ascending. cp_stage_replay_ex is this with no run entries. */
typedef struct { uint32_t tick; int32_t on; } CpStageRunEntry;
uint64_t cp_stage_replay_run(const CpStageSetup *setup,const uint8_t *snapshot,size_t snap_len,const CpStageField *field,
                             const CpStageLogEntry *log,int count,const CpStageDebugEntry *dbg,int dbg_count,
                             const CpStageRunEntry *runs,int run_count,uint32_t ticks,uint64_t *hashes);
uint64_t cp_stage_step(CpStageWorld *w,const CpStageInput *input);
uint64_t cp_stage_hash(const CpStageWorld *w);
/* Returns bytes excluding NUL, or -1 on insufficient capacity. */
int cp_stage_observe(const CpStageWorld *w,char *out,size_t cap);   /* schema "world-2" */
int cp_stage_observe_v(const CpStageWorld *w,char *out,size_t cap,int version);   /* 1 = the old "world-1" text, 2 = world-2 */
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
