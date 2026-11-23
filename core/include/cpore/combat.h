/* cpore - creature-stage combat core (P2, DESIGN.md G16/G18/G23/G36, Q24/Q52).
 *
 * A self-contained, deterministic, tick-based fight simulation: N creatures
 * on a flat 2-D arena with an optional height function, a fixed 10 Hz tick,
 * moves as a const data table, the counter matrix as a const rule table,
 * id-targeted verbs for agents and a per-tick FNV-1a state hash.
 *
 * Determinism contract (what makes native == WASM possible, see COMBAT.md):
 *   - float arithmetic only through + - * / and sqrtf (all IEEE-exact); no
 *     sin/cos/atan2/exp/pow anywhere in the sim. Trig-like constants are
 *     literals or come from a small polynomial (cb_cos in combat.c).
 *   - no fast-math, -ffp-contract=off (Makefile).
 *   - RNG is the existing CpRng, one stream per subsystem, seeded from the
 *     world seed; the streams are part of the hashed state.
 *   - the hash is over a canonical little-endian serialisation of the state
 *     fields, never raw struct memory.
 *
 * Depends on libc/libm only (sqrtf) and on cpore.h for CpRng. */
#ifndef CPORE_COMBAT_H
#define CPORE_COMBAT_H

#include <stdint.h>
#include <stddef.h>
#include "cpore/cpore.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---- tick, limits, world constants ---- */
#define CB_HZ             10
#define CB_DT             0.1f          /* seconds per tick                    */
#define CB_MAX_CREATURES  8
#define CB_MAX_HILLS      3
#define CB_MAX_EVENTS     64            /* per tick; extra events are dropped  */
#define CB_ARENA_W        40.0f         /* arena is [0,W] x [0,H] metres       */
#define CB_ARENA_H        40.0f
#define CB_RADIUS         0.6f          /* default body radius, metres         */
#define CB_RADIUS_CM      60            /* same default, integer centimetres   */
#define CB_RADIUS_CM_MIN  40            /* clamp for a non-default radius      */
#define CB_RADIUS_CM_MAX  400
#define CB_PART_MAX_LEVEL 5

/* ---- moves (data table, see CP_COMBAT_MOVES) ---- */
enum {
    CB_BITE = 0,
    CB_CHARGE,
    CB_GUARD,
    CB_SPIT,
    CB_TAIL_STRIKE,
    CB_DODGE,
    CB_CLAW_SWIPE, CB_PECK, CB_POUNCE, CB_QUILL_VOLLEY, CB_ROAR, CB_STOMP,
    CB_CURL_UP, CB_SPINE_VOLLEY,
    CB_FLAME,         /* first-quest: the fire gland's cone (core/src/combat.c); after the 14 tourney moves */
    CB_MOVE_COUNT
};
#define CB_MOVE_NONE  (-1)

/* move roles (docs/COMBAT-MOVES.md): colour in the UI and place in the loadout */
enum { CB_ROLE_BASIC = 0, CB_ROLE_ENGAGE, CB_ROLE_POKE, CB_ROLE_CONTROL, CB_ROLE_DEFENCE,
       CB_ROLE_SIGNATURE, CB_ROLE_COUNT };
const char *cp_combat_role_name(int role);

/* statuses a move can apply */
enum { CB_ST_NONE = 0, CB_ST_STUN, CB_ST_BLEED, CB_ST_SLOW, CB_ST_FEAR, CB_ST_KNOCKDOWN, CB_ST_BURN, CB_ST_COUNT };

/* move flags */
#define CB_F_RANGED   0x01   /* hit-scan along the facing: nearest enemy in the ray   */
#define CB_F_DASH     0x02   /* moves the user (reach metres, spread over active ticks)*/
#define CB_F_DIR      0x04   /* dash direction comes from the order's `dir`            */
#define CB_F_SELF     0x08   /* defensive: deals no hit, not an `attack` target move   */
#define CB_F_GUARD    0x10   /* while active, shields the frontal arc (see counters)   */
#define CB_F_EVADE    0x20   /* while active, dodge rule applies to incoming hits      */
#define CB_F_SWEEP    0x40   /* hits every enemy in reach/arc, once each; else first   */
#define CB_F_NO_WATER 0x80   /* unavailable while the creature is in water             */

/* which profile part gates a move */
enum { CB_PART_NONE = 0, CB_PART_MOUTH, CB_PART_CHARGE, CB_PART_SPIT,
       CB_PART_TAIL, CB_PART_GUARD, CB_PART_CLAW, CB_PART_BEAK, CB_PART_LEGS,
       CB_PART_QUILL, CB_PART_THROAT, CB_PART_HEAVY, CB_PART_ROCK, CB_PART_BACKSPINE, CB_PART_FIRE, CB_PART_COUNT };

typedef struct {
    const char *name;
    uint8_t  windup, active, recovery;  /* ticks                                 */
    float    reach;                     /* m: user centre -> target surface;
                                           for dashes: distance travelled        */
    float    arc;                       /* rad, full cone width (guard: shielded
                                           frontal cone)                         */
    float    stamina;                   /* cost at level 1, paid when it starts  */
    float    damage;                    /* at level 1                            */
    uint8_t  status;                    /* CB_ST_*                               */
    uint8_t  status_ticks;
    uint8_t  flags;                     /* CB_F_*                                */
    uint8_t  part;                      /* CB_PART_*                             */
    uint8_t  role;                      /* CB_ROLE_*                             */
    uint8_t meter_cost, max_targets; /* calcium cost; 0 means normal target rules */
    uint16_t cooldown;                  /* ticks before the move can start again,
                                           counted from the tick it starts; 0 = none */
} CpCombatMove;

extern const CpCombatMove CP_COMBAT_MOVES[CB_MOVE_COUNT];

/* ---- counter matrix (data table, see CP_COMBAT_COUNTERS) ----
 *
 * Rules are looked up when a hit lands: first matching row wins. A row
 * matches when the attacker's move is `attack` (-1 = any), the defender is
 * currently in move `defend` in one of the phases in `phases`, the hit's
 * centre-to-surface gap is <= max_gap (0 = any) and, for guard moves, the
 * attacker is inside the defender's shielded cone. */
enum {
    CB_EFF_AVOID = 1,   /* hit avoided; defender pays `stamina` (flat) or is hit
                           normally if it cannot pay; on success release defence
                           and stagger attacker `ticks`                         */
    CB_EFF_NEGATE,      /* damage x mult (0 negates); defender pays damage x
                           `stamina` / guard factor, or the guard breaks; on success
                           release defence and stagger attacker `ticks`         */
    CB_EFF_REDUCE,      /* damage x mult, status suppressed; same block/riposte rule */
    CB_EFF_BREAK,       /* damage x mult, defender's move cancelled, defender
                           pays `stamina` flat (to 0) and is staggered `ticks`   */
    CB_EFF_PIERCE,      /* reduced damage, status retained, no riposte */
    CB_EFF_INTERRUPT    /* damage x mult, defender's move cancelled, defender
                           staggered `ticks`; also cancels the defender's own
                           hit in the same tick                                  */
};
#define CB_PH_BIT(p)  (1u << (p))

typedef struct {
    int8_t   attack, defend;     /* move ids; attack may be -1 (wildcard)       */
    uint8_t  phases;             /* mask of CB_PH_BIT(defender phase)           */
    uint8_t  effect;             /* CB_EFF_*                                    */
    uint8_t  ticks;              /* stagger: attacker on block/avoid, else defender    */
    float    max_gap;            /* 0 = no limit                                */
    float    mult;               /* damage multiplier                           */
    float    stamina;            /* see CB_EFF_*                                */
} CpCombatCounter;

extern const CpCombatCounter CP_COMBAT_COUNTERS[];
extern const int             CP_COMBAT_N_COUNTERS;

/* ---- phases ---- */
enum { CB_PH_IDLE = 0, CB_PH_WINDUP, CB_PH_ACTIVE, CB_PH_RECOVERY };

/* ---- profile: what a creature is made of (a projection of its genome) ---- */
typedef struct {
    uint8_t mouth, charge, spit, tail, guard;   /* part levels 0..5            */
    float   hp, stamina, speed;                 /* base hp, stamina pool, m/s  */
    /* Centimetres. 0 and CB_RADIUS_CM both mean the literal CB_RADIUS.
     * The canonical hash writes this field only when it is neither, so
     * default-radius worlds stay bit-identical to the golden logs.
     * 60*0.01f is not bit-identical to 0.6f; do not recompute the default. */
    uint16_t radius_cm;
    uint8_t extra[8]; /* claw, beak, strong legs, quills, throat, heavy legs, rock, back spines */
    uint8_t carnivore; /* derived from genome mouths, not host diet */
    /* The fire gland level (0 = none). Last member, written to the hash only when nonzero, so positional
     * initialisers and every existing hash stay as they were. */
    uint8_t fire;
    uint16_t grip_traits; /* A59: genome-derived contact adaptations */
    uint8_t grip_legs;    /* actual ground contacts; 0 uses stage legs */
} CpCombatProfile;

/* Resolved metres. Default values return the CB_RADIUS literal. */
static inline float cp_combat_body_radius(const CpCombatProfile *p)
{
    if (!p || p->radius_cm == 0 || p->radius_cm == CB_RADIUS_CM) return CB_RADIUS;
    return (float)p->radius_cm * 0.01f;
}

void  cp_combat_profile_default(CpCombatProfile *p);   /* all parts 2, 100/100/4 */
int   cp_combat_part_level(const CpCombatProfile *p, int part);
/* damage and stamina after part-level scaling (0 if the part is missing) */
float cp_combat_move_damage(const CpCombatProfile *p, int move);
float cp_combat_move_stamina(const CpCombatProfile *p, int move);

/* ---- loadout (A21): four attack slots on keys 1-4 ----
 * Guard and dodge are always available and never sit in a slot. `known` is a
 * bitmask over move ids (bit = 1 << move): what the creature may slot. A slot
 * holds a move id or CB_MOVE_NONE. `sig_slot` is the slot (0..3) reserved for a
 * Signature move, or -1 while no signature is unlocked (a Signature move can
 * only sit in that slot, and that slot holds nothing else). `custom` is set by
 * the first successful cp_combat_loadout_set and gates what is hashed, so a
 * default loadout leaves every existing hash unchanged. */
#define CB_LOADOUT_SLOTS 4
typedef struct {
    int8_t   slot[CB_LOADOUT_SLOTS];
    int8_t   sig_slot;
    uint8_t  pad;
    uint16_t known;
} CpCombatLoadout;

/* Moves whose part level is > 0 (hook: learned-by-observing moves will be OR-ed in by the caller). */
uint16_t cp_combat_known_default(const CpCombatProfile *p);
/* Default loadout: the known attack moves in table order (bite, charge, spit, tail_strike). */
void     cp_combat_loadout_default(CpCombatLoadout *lo, const CpCombatProfile *p);
/* slot 0..3, move id or CB_MOVE_NONE to empty it. Returns CB_OK or CB_ERR_BAD_SLOT / CB_ERR_UNKNOWN_MOVE /
 * CB_ERR_NOT_KNOWN; a rejected call changes nothing. A move already in another slot is moved. */
int      cp_combat_loadout_is_default(const CpCombatLoadout *lo, const CpCombatProfile *p);
int      cp_combat_loadout_set(CpCombatLoadout *lo, int slot, int move);
/* slot holding the move, or -1 */
int      cp_combat_loadout_slot_of(const CpCombatLoadout *lo, int move);

/* ---- verbs (what agents say) ---- */
enum {
    CB_V_IDLE = 0,
    CB_V_APPROACH,   /* target: walk until the surface gap <= CB_APPROACH_GAP     */
    CB_V_ATTACK,     /* target + move: close in, face, launch, carry through      */
    CB_V_GUARD,      /* raise the guard once                                      */
    CB_V_DODGE,      /* dir: 0 forward, then clockwise in 45 deg steps (2 = right,
                        4 = back, 6 = left)                                       */
    CB_V_FLEE,       /* target: sprint away until far, or CB_FLEE_TICKS elapsed   */
    CB_V_MOVE,       /* dir=-1: quantised heading_x/y; 0..7: legacy replay octants */
    CB_V_COUNT
};

typedef struct {
    uint8_t verb;
    int8_t  move;     /* attack                                                   */
    int8_t  target;   /* creature id                                              */
    int8_t  dir;      /* dodge                                                    */
    int16_t heading_x, heading_y; /* MOVE with dir=-1; nonzero vector */
} CpCombatAction;

/* order() return codes (readable text via cp_combat_order_error) */
enum {
    CB_OK = 0,
    CB_ERR_BAD_ID = -1,        /* no such creature                              */
    CB_ERR_DEAD = -2,          /* the creature is dead                          */
    CB_ERR_BAD_VERB = -3,
    CB_ERR_BAD_TARGET = -4,    /* missing, self, or not a creature              */
    CB_ERR_BAD_MOVE = -5,      /* not an attack move                            */
    CB_ERR_UNAVAILABLE = -6,   /* profile lacks the part, or wrong medium       */
    CB_ERR_BAD_DIR = -7,
    CB_ERR_ON_COOLDOWN = -8,   /* the move is recharging                        */
    CB_ERR_NOT_EQUIPPED = -9,  /* attack move is not in the loadout             */
    CB_ERR_BAD_SLOT = -10,     /* slot must be 0..3 (text: 1..4); signature rules */
    CB_ERR_NOT_KNOWN = -11,    /* loadout: the creature does not know the move  */
    CB_ERR_NO_METER = -25,
    CB_ERR_UNKNOWN_MOVE = -12  /* loadout: not an attack move id                */
};
const char *cp_combat_order_error(int code);

#define CB_APPROACH_GAP  0.6f   /* surface gap that ends `approach`              */
#define CB_FLEE_DONE_GAP 14.0f
#define CB_FLEE_TICKS    50

/* ---- creature ---- */
enum { CB_GROUND = 0, CB_WATER = 1 };

typedef struct {
    uint8_t  alive, medium, team;
    CpCombatProfile prof;
    uint8_t tiers[CB_PART_COUNT]; /* P4 form modifiers, absent at T0 */
    float    x, y;              /* position, m                                    */
    float    fx, fy;            /* facing, unit vector                            */
    float    hp, stamina;

    /* current move */
    int8_t   move;              /* CB_MOVE_NONE when none                         */
    uint8_t  phase;             /* CB_PH_*                                        */
    uint8_t  ptick, plen;       /* tick index within the phase, phase length      */
    uint8_t  hit_mask;          /* creatures this use already hit (bit per id)    */
    float    dash_x, dash_y;    /* unit dash direction of the current move        */

    /* statuses and stamina bookkeeping, in ticks */
    uint8_t  stun_t, bleed_t, slow_t, since_spend;
    uint8_t fear_t, fear_src, calcium, mineral;
    uint16_t volleys;
    int8_t   bleed_src;         /* who gets credit for the bleed damage, -1 none  */
    uint8_t  burn_t;            /* ticks of burning left (hashed only while nonzero) */
    int8_t   burn_src;          /* who gets credit for the burn damage, -1 none     */

    CpCombatLoadout lo;         /* hashed only when not the default                      */
    uint16_t cd[CB_MOVE_COUNT]; /* ticks left before each move can start again; hashed
                                   only while any is nonzero                        */

    /* standing order */
    uint8_t  verb, verb_move, verb_started;
    int8_t   verb_target, verb_dir;
    uint8_t  verb_ticks;
    int16_t heading_x, heading_y; /* hashed only for vector MOVE */

    /* bookkeeping (hashed; the tourney reads these) */
    float    dmg_dealt, dmg_taken, stamina_spent;
    int32_t  hits, hits_taken, blocked, dodged, interrupted, kills;
    int32_t  died_tick;         /* -1 while alive                                 */
} CpCombatCreature;

typedef struct {
    float cx, cy, radius, height;   /* a smooth bump: h * (1 - d^2/r^2)^2         */
} CpCombatHill;

/* ---- events of the last tick (for UIs, bots and tests) ---- */
enum {
    CB_EV_HIT = 1,       /* a damaged b                                           */
    CB_EV_BLOCKED,       /* b's guard negated or reduced a's hit                  */
    CB_EV_GUARD_BROKEN,  /* b's guard failed (charge, or out of stamina)          */
    CB_EV_DODGED,        /* b's dodge avoided a's hit                             */
    CB_EV_INTERRUPTED,   /* b's move was cancelled by a                           */
    CB_EV_STUNNED,       /* b stunned by a                                        */
    CB_EV_DEATH,         /* b died (a = killer or 255)                            */
    CB_EV_NO_STAMINA,    /* a could not afford its move */
    CB_EV_NO_METER
};
typedef struct {
    uint8_t type, a, b;
    int8_t  move;
    float   amount;
} CpCombatEvent;

/* ---- RNG streams: one per subsystem ---- */
enum { CB_RNG_TERRAIN = 0, CB_RNG_SPAWN, CB_RNG_HIT, CB_RNG_COUNT };

/* ---- world ---- */
typedef struct {
    CpRng    rng[CB_RNG_COUNT];
    uint32_t seed;
    int32_t  tick;
    int32_t  n;
    CpCombatHill hill[CB_MAX_HILLS];
    int32_t  n_hills;
    CpCombatCreature c[CB_MAX_CREATURES];

    /* derived outputs of the last tick (not part of the hashed state) */
    CpCombatEvent ev[CB_MAX_EVENTS];
    int32_t  n_ev;
    uint64_t hash;              /* hash after the last tick (or of the start)     */
} CpCombatWorld;

/* ---- setup: everything a replay needs besides the action log ---- */
typedef struct {
    CpCombatProfile prof;
    float   x, y, fx, fy;       /* fx,fy need not be normalised; (0,0) -> +x      */
    uint8_t medium, team;
    uint8_t has_loadout;        /* 1: use `loadout` as given; 0: the default loadout    */
    CpCombatLoadout loadout;
    uint8_t calcium,mineral;
} CpCombatSpawn;

typedef struct {
    uint32_t seed;
    int32_t  n;
    uint8_t  flat;              /* 1: no hills; 0: hills drawn from the terrain
                                   stream                                         */
    CpCombatSpawn c[CB_MAX_CREATURES];
} CpCombatSetup;

typedef struct {
    int32_t        tick;        /* applied before stepping this tick              */
    uint8_t        id;
    CpCombatAction act;
} CpCombatLogEntry;

void     cp_combat_reset(CpCombatWorld *w, const CpCombatSetup *s);
/* Set a standing order. Returns CB_OK or a CB_ERR_* code; a rejected order
 * changes nothing. Re-issuing the identical order is a no-op, so an agent may
 * repeat its verb every tick. */
int      cp_combat_order(CpCombatWorld *w, int id, const CpCombatAction *a);
int      cp_combat_approach(CpCombatWorld *w, int id, int target);
int      cp_combat_attack(CpCombatWorld *w, int id, int target, int move);
int      cp_combat_guard(CpCombatWorld *w, int id);
int      cp_combat_dodge(CpCombatWorld *w, int id, int dir);
int      cp_combat_flee(CpCombatWorld *w, int id, int target);
int      cp_combat_idle(CpCombatWorld *w, int id);
/* Advance one tick; returns the state hash after it. */
uint64_t cp_combat_step(CpCombatWorld *w);
/* FNV-1a 64 over the canonical serialisation of the state. */
uint64_t cp_combat_hash(const CpCombatWorld *w);

/* Re-simulate a setup + action log for `ticks` ticks; hashes[t] is the hash
 * after tick t (hashes may be NULL). Returns the final hash. This is the
 * Q24 replay verifier. */
uint64_t cp_combat_replay(const CpCombatSetup *s, const CpCombatLogEntry *log,
                          int n_log, int ticks, uint64_t *hashes);

/* ---- queries ---- */
float cp_combat_height(const CpCombatWorld *w, float x, float y);
int   cp_combat_move_available(const CpCombatCreature *c, int move);
/* attack move sits in a loadout slot */
int   cp_combat_move_equipped(const CpCombatCreature *c, int move);
/* ticks until the move can start again (0 = ready) */
int   cp_combat_cooldown_left(const CpCombatCreature *c, int move);
/* true while the creature can do nothing (stun, or a stagger) */
int   cp_combat_helpless(const CpCombatCreature *c);
/* ticks until the creature's current move first becomes (or next is) active;
 * 0 if active now, -1 if it has no pending active frame */
int   cp_combat_ticks_to_active(const CpCombatCreature *c);
int   cp_combat_alive_count(const CpCombatWorld *w);

typedef struct {
    float gap;           /* centre -> target surface                              */
    int   in_reach;      /* gap <= reach now                                      */
    int   in_arc;        /* target inside the cone now                            */
    float flank, height; /* multipliers                                           */
    float counter;       /* counter-matrix damage multiplier vs the target's
                            current move and phase (1 if none)                    */
    float damage;        /* mean damage if launched and landing as things stand   */
    int   effect;        /* CB_EFF_* of the matching counter rule, 0 if none      */
} CpCombatPreview;
void  cp_combat_preview(const CpCombatWorld *w, int atk, int move, int tgt,
                        CpCombatPreview *out);

#ifdef CP_COMBAT_TEST
/* Unit tests only: override a move's cooldown (ticks) for every world; -1 restores the table. */
void cp_combat_test_cooldown(int move, int ticks);
/* Unit tests only: fix damage variance at 1.0; still consume the hit RNG draw. */
void cp_combat_test_hit_variance(int enabled);
#endif

const char *cp_combat_move_name(int move);
const char *cp_combat_verb_name(int verb);

#ifdef __cplusplus
}
#endif
#endif /* CPORE_COMBAT_H */
