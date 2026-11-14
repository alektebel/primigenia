#include "cpore/combat.h"

#include <math.h>
#include <string.h>

/* Creature-stage combat core. See combat.h for the contract and docs/COMBAT.md
 * for the tick model. Only + - * / and sqrtf are used on floats (no libm
 * transcendentals), so the result is bit-reproducible wherever IEEE-754
 * single precision without contraction is. */

/* ------------------------------------------------------------------ *
 * Tuning constants that are not per-move data.
 * ------------------------------------------------------------------ */
#define CB_BLEED_DPT      0.6f    /* hp per tick while bleeding               */
#define CB_REGEN          1.6f    /* stamina per idle tick                     */
#define CB_REGEN_DELAY    4       /* ticks after spending before regen starts  */
#define CB_WATER_SPEED    0.6f
#define CB_SLOW_SPEED     0.5f
#define CB_SPRINT_SPEED   1.25f
#define CB_SPRINT_COST    0.5f    /* stamina per sprint tick                   */
#define CB_FLANK_SIDE     1.25f
#define CB_FLANK_BACK     1.5f
#define CB_HEIGHT_K       0.10f   /* per metre of height advantage, to 2.5 m   */
#define CB_HEIGHT_MAX     2.5f
#define CB_VAR_LO         0.9f    /* damage variance, from the hit stream      */
#define CB_VAR_HI         1.1f
#define CB_GUARD_BREAK_STUN 6     /* ticks, when a guard runs out of stamina   */
#define CB_CONTACT_GAP    0.35f   /* surface gap that counts as a dash contact */
#define CB_LATERAL_SLACK  0.42f   /* aim tolerance (m) added to every cone     */
#define CB_GUARD_LEVEL_K  0.15f
#define CB_LEVEL_DAMAGE   0.20f
#define CB_LEVEL_STAMINA  0.10f
/* facing turns by this much per tick: cos/sin(0.8 rad), as literals */
#define CB_TURN_COS       0.69670671f
#define CB_TURN_SIN       0.71735609f

/* ------------------------------------------------------------------ *
 * Data: moves.
 * Bite can punish a simultaneous spit; spit still has time to interrupt a
 * charge after the bot's two-tick reaction delay. Charge travels 1 m/frame
 * (less than a body diameter) so a nearby target cannot be stepped over.
 * Spit's slow expires before the next shot, leaving a closing opportunity.
 * ------------------------------------------------------------------ */
const CpCombatMove CP_COMBAT_MOVES[CB_MOVE_COUNT] = {
  { "bite",        3, 1, 3,  1.8f, 1.00f,  9.0f, 11.0f, CB_ST_BLEED, 15, 0,                                       CB_PART_MOUTH  },
  { "charge",      7, 5, 4,  5.0f, 0.70f, 18.0f, 17.0f, CB_ST_STUN,   6, CB_F_DASH | CB_F_NO_WATER,               CB_PART_CHARGE },
  { "guard",       1,10, 2,  0.0f, 2.40f,  5.0f,  0.0f, CB_ST_NONE,   0, CB_F_SELF | CB_F_GUARD,                  CB_PART_GUARD  },
  { "spit",        4, 1, 5,  6.0f, 0.25f, 12.0f,  8.0f, CB_ST_SLOW,   8, CB_F_RANGED,                             CB_PART_SPIT   },
  { "tail_strike", 3, 2, 4,  2.2f, 2.40f, 10.0f, 10.0f, CB_ST_SLOW,  15, CB_F_SWEEP,                              CB_PART_TAIL   },
  { "dodge",       1, 2, 3,  2.2f, 0.00f,  8.0f,  0.0f, CB_ST_NONE,   0, CB_F_SELF | CB_F_DASH | CB_F_DIR | CB_F_EVADE, CB_PART_NONE },
};

/* ------------------------------------------------------------------ *
 * Data: the counter matrix. First matching row wins, so the dodge row is
 * first: an active dodge outranks everything else about the defender.
 * ------------------------------------------------------------------ */
const CpCombatCounter CP_COMBAT_COUNTERS[] = {
  { -1,            CB_DODGE,  CB_PH_BIT(CB_PH_ACTIVE),                 CB_EFF_AVOID,     0,  0.0f, 0.0f,  6.0f },
  { CB_CHARGE,     CB_GUARD,  CB_PH_BIT(CB_PH_ACTIVE),                 CB_EFF_BREAK,     5,  0.0f, 0.6f, 20.0f },
  { CB_BITE,       CB_GUARD,  CB_PH_BIT(CB_PH_ACTIVE),                 CB_EFF_NEGATE,    0,  0.0f, 0.0f,  0.35f },
  { CB_TAIL_STRIKE,CB_GUARD,  CB_PH_BIT(CB_PH_ACTIVE),                 CB_EFF_REDUCE,    0,  0.0f, 0.4f,  0.3f },
  { CB_SPIT,       CB_CHARGE, CB_PH_BIT(CB_PH_WINDUP),                 CB_EFF_INTERRUPT, 6,  0.0f, 1.0f,  0.0f },
  { CB_BITE,       CB_SPIT,   CB_PH_BIT(CB_PH_WINDUP) | CB_PH_BIT(CB_PH_ACTIVE),
                                                                      CB_EFF_INTERRUPT, 4,  2.0f, 1.25f, 0.0f },
};
const int CP_COMBAT_N_COUNTERS = (int)(sizeof(CP_COMBAT_COUNTERS) / sizeof(CP_COMBAT_COUNTERS[0]));

/* dir 0..7: (cos, sin) of -45 deg * dir, i.e. clockwise from forward with y up */
static const float DIRS8[8][2] = {
    { 1.0f, 0.0f }, { 0.70710678f, -0.70710678f }, { 0.0f, -1.0f }, { -0.70710678f, -0.70710678f },
    { -1.0f, 0.0f }, { -0.70710678f, 0.70710678f }, { 0.0f, 1.0f }, { 0.70710678f, 0.70710678f },
};

const char *cp_combat_move_name(int m)
{
    return (m >= 0 && m < CB_MOVE_COUNT) ? CP_COMBAT_MOVES[m].name : "none";
}
const char *cp_combat_verb_name(int v)
{
    static const char *n[CB_V_COUNT] = { "idle", "approach", "attack", "guard", "dodge", "flee" };
    return (v >= 0 && v < CB_V_COUNT) ? n[v] : "?";
}
const char *cp_combat_order_error(int code)
{
    switch (code) {
    case CB_OK:              return "ok";
    case CB_ERR_BAD_ID:      return "no such creature";
    case CB_ERR_DEAD:        return "the creature is dead";
    case CB_ERR_BAD_VERB:    return "unknown verb";
    case CB_ERR_BAD_TARGET:  return "target must be another living creature";
    case CB_ERR_BAD_MOVE:    return "attack needs an offensive move (bite, charge, spit, tail_strike)";
    case CB_ERR_UNAVAILABLE: return "this creature cannot use that move (missing part or wrong medium)";
    case CB_ERR_BAD_DIR:     return "dir must be 0..7";
    default:                 return "unknown error";
    }
}

/* ------------------------------------------------------------------ *
 * Small maths.
 * ------------------------------------------------------------------ */
static float cb_cos(float x)   /* x in [0, pi]; Taylor to x^16, +,-,*,/ only */
{
    float x2 = x * x;
    return 1.0f - x2 / 2.0f * (1.0f - x2 / 12.0f * (1.0f - x2 / 30.0f * (1.0f - x2 / 56.0f *
           (1.0f - x2 / 90.0f * (1.0f - x2 / 132.0f * (1.0f - x2 / 182.0f * (1.0f - x2 / 240.0f)))))));
}
static float cb_clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
static float cb_maxf(float a, float b) { return a > b ? a : b; }

/* ------------------------------------------------------------------ *
 * Profile.
 * ------------------------------------------------------------------ */
void cp_combat_profile_default(CpCombatProfile *p)
{
    p->mouth = p->charge = p->spit = p->tail = p->guard = 2;
    p->hp = 100.0f; p->stamina = 100.0f; p->speed = 4.0f;
}

int cp_combat_part_level(const CpCombatProfile *p, int part)
{
    switch (part) {
    case CB_PART_MOUTH:  return p->mouth;
    case CB_PART_CHARGE: return p->charge;
    case CB_PART_SPIT:   return p->spit;
    case CB_PART_TAIL:   return p->tail;
    case CB_PART_GUARD:  return p->guard;
    default:             return 1;     /* CB_PART_NONE: always available */
    }
}

float cp_combat_move_damage(const CpCombatProfile *p, int move)
{
    if (move < 0 || move >= CB_MOVE_COUNT) return 0.0f;
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    int lv = cp_combat_part_level(p, m->part);
    if (lv <= 0) return 0.0f;
    return m->damage * (1.0f + CB_LEVEL_DAMAGE * (float)(lv - 1));
}

float cp_combat_move_stamina(const CpCombatProfile *p, int move)
{
    if (move < 0 || move >= CB_MOVE_COUNT) return 0.0f;
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    int lv = cp_combat_part_level(p, m->part);
    if (lv <= 0) return 0.0f;
    return m->stamina * (1.0f + CB_LEVEL_STAMINA * (float)(lv - 1));
}

int cp_combat_move_available(const CpCombatCreature *c, int move)
{
    if (move < 0 || move >= CB_MOVE_COUNT) return 0;
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    if (cp_combat_part_level(&c->prof, m->part) <= 0) return 0;
    if ((m->flags & CB_F_NO_WATER) && c->medium == CB_WATER) return 0;
    return 1;
}

int cp_combat_helpless(const CpCombatCreature *c)
{
    return c->stun_t > 0 || (c->move == CB_MOVE_NONE && c->phase == CB_PH_RECOVERY);
}

int cp_combat_ticks_to_active(const CpCombatCreature *c)
{
    if (c->move == CB_MOVE_NONE) return -1;
    if (c->phase == CB_PH_WINDUP) return (int)c->plen - (int)c->ptick;
    if (c->phase == CB_PH_ACTIVE) return 0;
    return -1;
}

int cp_combat_alive_count(const CpCombatWorld *w)
{
    int n = 0;
    for (int i = 0; i < w->n; i++) n += w->c[i].alive;
    return n;
}

/* ------------------------------------------------------------------ *
 * Terrain.
 * ------------------------------------------------------------------ */
float cp_combat_height(const CpCombatWorld *w, float x, float y)
{
    float z = 0.0f;
    for (int i = 0; i < w->n_hills; i++) {
        const CpCombatHill *h = &w->hill[i];
        float dx = x - h->cx, dy = y - h->cy;
        float q = (dx * dx + dy * dy) / (h->radius * h->radius);
        if (q < 1.0f) { float u = 1.0f - q; z += h->height * u * u; }
    }
    return z;
}

/* ------------------------------------------------------------------ *
 * Hash: FNV-1a 64 over an explicit little-endian serialisation.
 * ------------------------------------------------------------------ */
typedef struct { uint64_t h; } Fnv;
static void fb(Fnv *f, uint8_t b) { f->h ^= b; f->h *= 1099511628211ull; }
static void fu8(Fnv *f, uint32_t v) { fb(f, (uint8_t)v); }
static void fu32(Fnv *f, uint32_t v) { for (int i = 0; i < 4; i++) fb(f, (uint8_t)(v >> (8 * i))); }
static void ff(Fnv *f, float x)
{
    uint32_t b = 0;
    if (x != 0.0f) memcpy(&b, &x, 4);       /* -0 and +0 hash alike */
    fu32(f, b);
}

uint64_t cp_combat_hash(const CpCombatWorld *w)
{
    Fnv f; f.h = 14695981039346656037ull;
    fu32(&f, w->seed);
    fu32(&f, (uint32_t)w->tick);
    fu32(&f, (uint32_t)w->n);
    fu32(&f, (uint32_t)w->n_hills);
    for (int k = 0; k < CB_RNG_COUNT; k++)
        for (int j = 0; j < 4; j++) fu32(&f, w->rng[k].s[j]);
    for (int i = 0; i < w->n_hills; i++) {
        const CpCombatHill *h = &w->hill[i];
        ff(&f, h->cx); ff(&f, h->cy); ff(&f, h->radius); ff(&f, h->height);
    }
    for (int i = 0; i < w->n; i++) {
        const CpCombatCreature *c = &w->c[i];
        fu8(&f, c->alive); fu8(&f, c->medium); fu8(&f, c->team);
        fu8(&f, c->prof.mouth); fu8(&f, c->prof.charge); fu8(&f, c->prof.spit);
        fu8(&f, c->prof.tail); fu8(&f, c->prof.guard);
        ff(&f, c->prof.hp); ff(&f, c->prof.stamina); ff(&f, c->prof.speed);
        ff(&f, c->x); ff(&f, c->y); ff(&f, c->fx); ff(&f, c->fy);
        ff(&f, c->hp); ff(&f, c->stamina);
        fu8(&f, (uint8_t)c->move); fu8(&f, c->phase); fu8(&f, c->ptick); fu8(&f, c->plen);
        fu8(&f, c->hit_mask); ff(&f, c->dash_x); ff(&f, c->dash_y);
        fu8(&f, c->stun_t); fu8(&f, c->bleed_t); fu8(&f, c->slow_t); fu8(&f, c->since_spend);
        fu8(&f, (uint8_t)c->bleed_src);
        fu8(&f, c->verb); fu8(&f, c->verb_move); fu8(&f, c->verb_started);
        fu8(&f, (uint8_t)c->verb_target); fu8(&f, (uint8_t)c->verb_dir); fu8(&f, c->verb_ticks);
        ff(&f, c->dmg_dealt); ff(&f, c->dmg_taken); ff(&f, c->stamina_spent);
        fu32(&f, (uint32_t)c->hits); fu32(&f, (uint32_t)c->hits_taken);
        fu32(&f, (uint32_t)c->blocked); fu32(&f, (uint32_t)c->dodged);
        fu32(&f, (uint32_t)c->interrupted); fu32(&f, (uint32_t)c->kills);
        fu32(&f, (uint32_t)c->died_tick);
    }
    return f.h;
}

/* ------------------------------------------------------------------ *
 * Setup.
 * ------------------------------------------------------------------ */
static void norm_or(float *x, float *y, float dx, float dy)
{
    float l2 = *x * *x + *y * *y;
    if (l2 < 1e-12f) { *x = dx; *y = dy; return; }
    float inv = 1.0f / sqrtf(l2);
    *x *= inv; *y *= inv;
}

static void clamp_prof(CpCombatProfile *p)
{
    if (p->mouth  > CB_PART_MAX_LEVEL) p->mouth  = CB_PART_MAX_LEVEL;
    if (p->charge > CB_PART_MAX_LEVEL) p->charge = CB_PART_MAX_LEVEL;
    if (p->spit   > CB_PART_MAX_LEVEL) p->spit   = CB_PART_MAX_LEVEL;
    if (p->tail   > CB_PART_MAX_LEVEL) p->tail   = CB_PART_MAX_LEVEL;
    if (p->guard  > CB_PART_MAX_LEVEL) p->guard  = CB_PART_MAX_LEVEL;
    p->hp      = cb_clampf(p->hp, 1.0f, 100000.0f);
    p->stamina = cb_clampf(p->stamina, 1.0f, 100000.0f);
    p->speed   = cb_clampf(p->speed, 0.5f, 12.0f);
}

void cp_combat_reset(CpCombatWorld *w, const CpCombatSetup *s)
{
    memset(w, 0, sizeof(*w));
    w->seed = s->seed;
    for (int k = 0; k < CB_RNG_COUNT; k++)
        cp_rng_seed(&w->rng[k], s->seed + 0x7F4A7C15u * (uint32_t)(k + 1));

    if (!s->flat) {
        CpRng *r = &w->rng[CB_RNG_TERRAIN];
        w->n_hills = 1 + cp_rng_int(r, CB_MAX_HILLS);
        for (int i = 0; i < w->n_hills; i++) {
            CpCombatHill *h = &w->hill[i];
            h->cx = cp_rng_range(r, 8.0f, CB_ARENA_W - 8.0f);
            h->cy = cp_rng_range(r, 8.0f, CB_ARENA_H - 8.0f);
            h->radius = cp_rng_range(r, 6.0f, 12.0f);
            h->height = cp_rng_range(r, 1.0f, 3.0f);
        }
    }

    int n = s->n;
    if (n < 0) n = 0;
    if (n > CB_MAX_CREATURES) n = CB_MAX_CREATURES;
    w->n = n;
    for (int i = 0; i < n; i++) {
        const CpCombatSpawn *sp = &s->c[i];
        CpCombatCreature *c = &w->c[i];
        c->alive = 1;
        c->medium = sp->medium ? CB_WATER : CB_GROUND;
        c->team = sp->team;
        c->prof = sp->prof;
        clamp_prof(&c->prof);
        c->x = sp->x; c->y = sp->y; c->fx = sp->fx; c->fy = sp->fy;
        if (sp->x < 0.0f || sp->y < 0.0f) {          /* random placement */
            CpRng *r = &w->rng[CB_RNG_SPAWN];
            for (int tries = 0; tries < 24; tries++) {
                c->x = cp_rng_range(r, 4.0f, CB_ARENA_W - 4.0f);
                c->y = cp_rng_range(r, 4.0f, CB_ARENA_H - 4.0f);
                int ok = 1;
                for (int j = 0; j < i; j++) {
                    float dx = c->x - w->c[j].x, dy = c->y - w->c[j].y;
                    if (dx * dx + dy * dy < 16.0f) { ok = 0; break; }
                }
                if (ok) break;
            }
            c->fx = cp_rng_range(r, -1.0f, 1.0f);
            c->fy = cp_rng_range(r, -1.0f, 1.0f);
        }
        c->x = cb_clampf(c->x, CB_RADIUS, CB_ARENA_W - CB_RADIUS);
        c->y = cb_clampf(c->y, CB_RADIUS, CB_ARENA_H - CB_RADIUS);
        norm_or(&c->fx, &c->fy, 1.0f, 0.0f);
        c->hp = c->prof.hp;
        c->stamina = c->prof.stamina;
        c->move = CB_MOVE_NONE;
        c->phase = CB_PH_IDLE;
        c->since_spend = 255;
        c->verb_target = -1;
        c->bleed_src = -1;
        c->died_tick = -1;
    }
    w->hash = cp_combat_hash(w);
}

/* ------------------------------------------------------------------ *
 * Orders.
 * ------------------------------------------------------------------ */
int cp_combat_order(CpCombatWorld *w, int id, const CpCombatAction *a)
{
    if (id < 0 || id >= w->n) return CB_ERR_BAD_ID;
    CpCombatCreature *c = &w->c[id];
    if (!c->alive) return CB_ERR_DEAD;
    if (a->verb >= CB_V_COUNT) return CB_ERR_BAD_VERB;

    int target = -1, move = 0, dir = 0;
    switch (a->verb) {
    case CB_V_IDLE: break;
    case CB_V_APPROACH:
    case CB_V_FLEE:
    case CB_V_ATTACK:
        if (a->target < 0 || a->target >= w->n || a->target == id || !w->c[a->target].alive)
            return CB_ERR_BAD_TARGET;
        target = a->target;
        if (a->verb == CB_V_ATTACK) {
            if (a->move < 0 || a->move >= CB_MOVE_COUNT) return CB_ERR_BAD_MOVE;
            if (CP_COMBAT_MOVES[a->move].flags & CB_F_SELF) return CB_ERR_BAD_MOVE;
            if (!cp_combat_move_available(c, a->move)) return CB_ERR_UNAVAILABLE;
            move = a->move;
        }
        break;
    case CB_V_GUARD:
        if (!cp_combat_move_available(c, CB_GUARD)) return CB_ERR_UNAVAILABLE;
        break;
    case CB_V_DODGE:
        if (a->dir < 0 || a->dir > 7) return CB_ERR_BAD_DIR;
        if (!cp_combat_move_available(c, CB_DODGE)) return CB_ERR_UNAVAILABLE;
        dir = a->dir;
        break;
    }

    /* identical standing order: nothing to do (lets agents repeat it per tick) */
    if (c->verb == a->verb && c->verb_target == target && c->verb_move == (uint8_t)move &&
        c->verb_dir == dir && a->verb != CB_V_IDLE)
        return CB_OK;

    c->verb = a->verb;
    c->verb_target = (int8_t)target;
    c->verb_move = (uint8_t)move;
    c->verb_dir = (int8_t)dir;
    c->verb_started = 0;
    c->verb_ticks = (a->verb == CB_V_FLEE) ? CB_FLEE_TICKS : 0;
    return CB_OK;
}

/* Preserve invalid integer values as an invalid sentinel before storing the
 * byte-sized action fields; e.g. move 256 must not wrap into CB_BITE. */
static int8_t target_id(int target)
{
    return (int8_t)(target >= 0 && target < CB_MAX_CREATURES ? target : -1);
}

int cp_combat_approach(CpCombatWorld *w, int id, int t)
{
    CpCombatAction a = { CB_V_APPROACH, 0, target_id(t), 0 };
    return cp_combat_order(w, id, &a);
}
int cp_combat_attack(CpCombatWorld *w, int id, int t, int m)
{
    CpCombatAction a = { CB_V_ATTACK,
        (int8_t)(m >= 0 && m < CB_MOVE_COUNT ? m : -1), target_id(t), 0 };
    return cp_combat_order(w, id, &a);
}
int cp_combat_guard(CpCombatWorld *w, int id)
{
    CpCombatAction a = { CB_V_GUARD, 0, 0, 0 };
    return cp_combat_order(w, id, &a);
}
int cp_combat_dodge(CpCombatWorld *w, int id, int d)
{
    CpCombatAction a = { CB_V_DODGE, 0, 0, (int8_t)(d >= 0 && d < 8 ? d : -1) };
    return cp_combat_order(w, id, &a);
}
int cp_combat_flee(CpCombatWorld *w, int id, int t)
{
    CpCombatAction a = { CB_V_FLEE, 0, target_id(t), 0 };
    return cp_combat_order(w, id, &a);
}
int cp_combat_idle(CpCombatWorld *w, int id)
{
    CpCombatAction a = { CB_V_IDLE, 0, 0, 0 };
    return cp_combat_order(w, id, &a);
}

/* ------------------------------------------------------------------ *
 * Internals.
 * ------------------------------------------------------------------ */
static void ev_add(CpCombatWorld *w, int type, int a, int b, int move, float amount)
{
    if (w->n_ev >= CB_MAX_EVENTS) return;
    CpCombatEvent *e = &w->ev[w->n_ev++];
    e->type = (uint8_t)type; e->a = (uint8_t)a; e->b = (uint8_t)b;
    e->move = (int8_t)move; e->amount = amount;
}

static void cancel_move(CpCombatCreature *c)
{
    c->move = CB_MOVE_NONE; c->phase = CB_PH_IDLE; c->ptick = c->plen = 0;
    c->verb_started = 0;
}
static void stagger(CpCombatCreature *c, int ticks)
{
    cancel_move(c);
    c->verb = CB_V_IDLE;
    if (ticks > 0) { c->phase = CB_PH_RECOVERY; c->plen = (uint8_t)ticks; }
}
static void kill(CpCombatWorld *w, int i, int killer)
{
    CpCombatCreature *c = &w->c[i];
    c->alive = 0; c->hp = 0.0f;
    cancel_move(c);
    c->verb = CB_V_IDLE; c->stun_t = c->bleed_t = c->slow_t = 0; c->bleed_src = -1;
    c->died_tick = w->tick;
    if (killer >= 0 && killer < w->n) w->c[killer].kills++;
    ev_add(w, CB_EV_DEATH, killer >= 0 ? killer : 255, i, CB_MOVE_NONE, 0.0f);
}

static void turn_toward(CpCombatCreature *c, float dx, float dy)
{
    float dot = c->fx * dx + c->fy * dy;
    if (dot >= CB_TURN_COS) { c->fx = dx; c->fy = dy; return; }
    float cross = c->fx * dy - c->fy * dx;
    float s = cross >= 0.0f ? CB_TURN_SIN : -CB_TURN_SIN;
    float nx = c->fx * CB_TURN_COS - c->fy * s;
    float ny = c->fx * s + c->fy * CB_TURN_COS;
    norm_or(&nx, &ny, c->fx, c->fy);
    c->fx = nx; c->fy = ny;
}

/* unit vector from a to b and the centre distance */
static float dir_to(const CpCombatCreature *a, const CpCombatCreature *b, float *ux, float *uy)
{
    float dx = b->x - a->x, dy = b->y - a->y;
    float d2 = dx * dx + dy * dy;
    if (d2 < 1e-10f) { *ux = a->fx; *uy = a->fy; return 0.0f; }
    float d = sqrtf(d2), inv = 1.0f / d;
    *ux = dx * inv; *uy = dy * inv;
    return d;
}

/* cone test: attacker facing vs unit direction to target */
static int in_cone(const CpCombatCreature *a, float ux, float uy, float dist, float arc)
{
    float cosang = a->fx * ux + a->fy * uy;
    if (cosang >= cb_cos(arc * 0.5f)) return 1;
    float lateral = a->fx * uy - a->fy * ux;     /* sin of the angle */
    if (lateral < 0.0f) lateral = -lateral;
    return cosang > 0.0f && lateral * dist <= CB_LATERAL_SLACK;
}

static float walk_speed(const CpCombatCreature *c)
{
    float s = c->prof.speed;
    if (c->medium == CB_WATER) s *= CB_WATER_SPEED;
    if (c->slow_t > 0) s *= CB_SLOW_SPEED;
    return s;
}

static void begin_move(CpCombatCreature *c, int move)
{
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    float cost = cp_combat_move_stamina(&c->prof, move);
    c->stamina = cb_maxf(0.0f, c->stamina - cost);
    c->stamina_spent += cost;
    c->since_spend = 0;
    c->move = (int8_t)move;
    c->hit_mask = 0;
    c->ptick = 0;
    if (m->windup)        { c->phase = CB_PH_WINDUP; c->plen = m->windup; }
    else if (m->active)   { c->phase = CB_PH_ACTIVE; c->plen = m->active; }
    else                  { c->phase = CB_PH_RECOVERY; c->plen = m->recovery; }
    c->verb_started = 1;
    if (m->flags & CB_F_DASH) {
        float dx = c->fx, dy = c->fy;
        if (m->flags & CB_F_DIR) {
            const float *d = DIRS8[c->verb_dir & 7];
            dx = c->fx * d[0] - c->fy * d[1];
            dy = c->fx * d[1] + c->fy * d[0];
        }
        c->dash_x = dx; c->dash_y = dy;
    }
}

static void finish_move(CpCombatCreature *c)
{
    int was_verb = c->verb_started;
    c->move = CB_MOVE_NONE; c->phase = CB_PH_IDLE; c->ptick = c->plen = 0;
    c->verb_started = 0;
    if (was_verb && (c->verb == CB_V_ATTACK || c->verb == CB_V_GUARD || c->verb == CB_V_DODGE))
        c->verb = CB_V_IDLE;
}

static void advance_phase(CpCombatCreature *c)
{
    c->ptick++;
    if (c->ptick < c->plen) return;
    if (c->move == CB_MOVE_NONE) {                 /* a stagger ends */
        c->phase = CB_PH_IDLE; c->ptick = c->plen = 0;
        return;
    }
    const CpCombatMove *m = &CP_COMBAT_MOVES[c->move];
    c->ptick = 0;
    if (c->phase == CB_PH_WINDUP) {
        if (m->active)   { c->phase = CB_PH_ACTIVE;   c->plen = m->active;   return; }
        if (m->recovery) { c->phase = CB_PH_RECOVERY; c->plen = m->recovery; return; }
    } else if (c->phase == CB_PH_ACTIVE) {
        if (m->recovery) { c->phase = CB_PH_RECOVERY; c->plen = m->recovery; return; }
    }
    finish_move(c);
}

/* movement requested this tick, applied after planning */
typedef struct { float dx, dy; uint8_t walked, sprinted; } Disp;

static void walk(const CpCombatWorld *w, int i, Disp *d, float ux, float uy, float speed)
{
    const CpCombatCreature *c = &w->c[i];
    float step = speed * CB_DT;
    if (w->n_hills) {                               /* uphill is slower */
        float z0 = cp_combat_height(w, c->x, c->y);
        float z1 = cp_combat_height(w, c->x + ux * step, c->y + uy * step);
        float slope = (z1 - z0) / step;
        if (slope > 0.0f) step *= cb_maxf(0.4f, 1.0f - slope);
    }
    d->dx += ux * step; d->dy += uy * step;
    d->walked = 1;
}

static void plan(CpCombatWorld *w, int i, Disp *d)
{
    CpCombatCreature *c = &w->c[i];
    if (!c->alive || c->stun_t > 0 || c->phase != CB_PH_IDLE) return;

    float ux, uy, dist;
    switch (c->verb) {
    case CB_V_IDLE:
        return;
    case CB_V_APPROACH: {
        const CpCombatCreature *t = &w->c[(int)c->verb_target];
        if (!t->alive) { c->verb = CB_V_IDLE; return; }
        dist = dir_to(c, t, &ux, &uy);
        if (dist - 2.0f * CB_RADIUS <= CB_APPROACH_GAP) { c->verb = CB_V_IDLE; return; }
        turn_toward(c, ux, uy);
        walk(w, i, d, ux, uy, walk_speed(c));
        return;
    }
    case CB_V_ATTACK: {
        const CpCombatCreature *t = &w->c[(int)c->verb_target];
        int mv = c->verb_move;
        if (!t->alive || !cp_combat_move_available(c, mv)) { c->verb = CB_V_IDLE; return; }
        const CpCombatMove *m = &CP_COMBAT_MOVES[mv];
        dist = dir_to(c, t, &ux, &uy);
        float gap = dist - CB_RADIUS;
        if (gap <= m->reach * 0.92f) {
            int aligned = (c->fx * ux + c->fy * uy) >= cb_cos(m->arc * 0.25f);
            if (!aligned) { turn_toward(c, ux, uy); return; }
            if (c->stamina >= cp_combat_move_stamina(&c->prof, mv)) begin_move(c, mv);
            else { turn_toward(c, ux, uy); ev_add(w, CB_EV_NO_STAMINA, i, i, mv, 0.0f); }
            return;
        }
        turn_toward(c, ux, uy);
        walk(w, i, d, ux, uy, walk_speed(c));
        return;
    }
    case CB_V_GUARD:
        if (c->stamina >= cp_combat_move_stamina(&c->prof, CB_GUARD)) begin_move(c, CB_GUARD);
        else ev_add(w, CB_EV_NO_STAMINA, i, i, CB_GUARD, 0.0f);
        return;
    case CB_V_DODGE:
        if (c->stamina >= cp_combat_move_stamina(&c->prof, CB_DODGE)) begin_move(c, CB_DODGE);
        else ev_add(w, CB_EV_NO_STAMINA, i, i, CB_DODGE, 0.0f);
        return;
    case CB_V_FLEE: {
        const CpCombatCreature *t = &w->c[(int)c->verb_target];
        if (!t->alive || c->verb_ticks == 0) { c->verb = CB_V_IDLE; return; }
        dist = dir_to(c, t, &ux, &uy);
        if (dist - 2.0f * CB_RADIUS > CB_FLEE_DONE_GAP) { c->verb = CB_V_IDLE; return; }
        c->verb_ticks--;
        ux = -ux; uy = -uy;
        turn_toward(c, ux, uy);
        float sp = walk_speed(c);
        if (c->stamina >= CB_SPRINT_COST) {
            sp *= CB_SPRINT_SPEED;
            c->stamina -= CB_SPRINT_COST; c->stamina_spent += CB_SPRINT_COST;
            c->since_spend = 0;
            d->sprinted = 1;
        }
        walk(w, i, d, ux, uy, sp);
        return;
    }
    }
}

/* ---- hit evaluation ---- */
typedef struct {
    const CpCombatCounter *rule;     /* primary rule or NULL                       */
    const CpCombatCounter *alt;      /* first non-AVOID rule (if the primary is AVOID) */
    float flank, height;
} HitEval;

static const CpCombatCounter *find_rule(const CpCombatCreature *a, const CpCombatCreature *d,
                                        int move, float gap, int skip_avoid)
{
    if (d->move == CB_MOVE_NONE) return NULL;
    const CpCombatMove *dm = &CP_COMBAT_MOVES[d->move];
    for (int k = 0; k < CP_COMBAT_N_COUNTERS; k++) {
        const CpCombatCounter *r = &CP_COMBAT_COUNTERS[k];
        if (r->attack >= 0 && r->attack != move) continue;
        if (r->defend != d->move) continue;
        if (!(r->phases & CB_PH_BIT(d->phase))) continue;
        if (r->max_gap > 0.0f && gap > r->max_gap) continue;
        if (skip_avoid && r->effect == CB_EFF_AVOID) continue;
        if (dm->flags & CB_F_GUARD) {              /* a guard only covers its front */
            float ux, uy;
            float dist = dir_to(d, a, &ux, &uy);
            if (!in_cone(d, ux, uy, dist, dm->arc)) continue;
        }
        return r;
    }
    return NULL;
}

static float flank_mult(const CpCombatCreature *a, const CpCombatCreature *d)
{
    float ux, uy;
    dir_to(d, a, &ux, &uy);                         /* defender -> attacker */
    float c = d->fx * ux + d->fy * uy;
    if (c >= 0.5f) return 1.0f;
    if (c > -0.5f) return CB_FLANK_SIDE;
    return CB_FLANK_BACK;
}

static float height_mult(const CpCombatWorld *w, const CpCombatCreature *a, const CpCombatCreature *d)
{
    if (!w->n_hills) return 1.0f;
    float dz = cp_combat_height(w, a->x, a->y) - cp_combat_height(w, d->x, d->y);
    return 1.0f + CB_HEIGHT_K * cb_clampf(dz, 0.0f, CB_HEIGHT_MAX);
}

static HitEval eval_hit(const CpCombatWorld *w, const CpCombatCreature *a,
                        const CpCombatCreature *d, int move, float gap)
{
    HitEval e;
    e.rule = find_rule(a, d, move, gap, 0);
    e.alt = (e.rule && e.rule->effect == CB_EFF_AVOID) ? find_rule(a, d, move, gap, 1) : NULL;
    e.flank = flank_mult(a, d);
    e.height = height_mult(w, a, d);
    return e;
}

void cp_combat_preview(const CpCombatWorld *w, int atk, int move, int tgt, CpCombatPreview *out)
{
    memset(out, 0, sizeof(*out));
    out->flank = out->height = out->counter = 1.0f;
    if (atk < 0 || atk >= w->n || tgt < 0 || tgt >= w->n || atk == tgt) return;
    if (move < 0 || move >= CB_MOVE_COUNT) return;
    const CpCombatCreature *a = &w->c[atk], *d = &w->c[tgt];
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    float ux, uy;
    float dist = dir_to(a, d, &ux, &uy);
    out->gap = dist - CB_RADIUS;
    out->in_reach = out->gap <= m->reach;
    out->in_arc = (a->fx * ux + a->fy * uy) >= cb_cos(m->arc * 0.5f);
    HitEval e = eval_hit(w, a, d, move, out->gap);
    out->flank = e.flank; out->height = e.height;
    if (e.rule) {
        out->effect = e.rule->effect;
        out->counter = (e.rule->effect == CB_EFF_AVOID) ? 0.0f : e.rule->mult;
    }
    out->damage = cp_combat_move_damage(&a->prof, move) * e.flank * e.height * out->counter;
}

/* ------------------------------------------------------------------ *
 * The tick.
 * ------------------------------------------------------------------ */
typedef struct { uint8_t atk, def; int8_t move; float gap; HitEval ev; } Hit;

static void separate(CpCombatWorld *w)
{
    for (int pass = 0; pass < 2; pass++) {
        for (int i = 0; i < w->n; i++) {
            if (!w->c[i].alive) continue;
            for (int j = i + 1; j < w->n; j++) {
                if (!w->c[j].alive) continue;
                CpCombatCreature *a = &w->c[i], *b = &w->c[j];
                float dx = b->x - a->x, dy = b->y - a->y;
                float d2 = dx * dx + dy * dy, min = 2.0f * CB_RADIUS;
                if (d2 >= min * min) continue;
                float nx, ny, d;
                if (d2 < 1e-10f) { nx = 1.0f; ny = 0.0f; d = 0.0f; }
                else { d = sqrtf(d2); nx = dx / d; ny = dy / d; }
                float push = (min - d) * 0.5f;
                a->x -= nx * push; a->y -= ny * push;
                b->x += nx * push; b->y += ny * push;
            }
        }
        for (int i = 0; i < w->n; i++) {
            CpCombatCreature *c = &w->c[i];
            c->x = cb_clampf(c->x, CB_RADIUS, CB_ARENA_W - CB_RADIUS);
            c->y = cb_clampf(c->y, CB_RADIUS, CB_ARENA_H - CB_RADIUS);
        }
    }
}

static int gather_hits(const CpCombatWorld *w, Hit *hits)
{
    int nh = 0;
    for (int i = 0; i < w->n; i++) {
        const CpCombatCreature *a = &w->c[i];
        if (!a->alive || a->phase != CB_PH_ACTIVE || a->move == CB_MOVE_NONE) continue;
        const CpCombatMove *m = &CP_COMBAT_MOVES[a->move];
        if (m->flags & CB_F_SELF) continue;
        if (!(m->flags & CB_F_SWEEP) && a->hit_mask) continue;   /* single-hit move already spent */

        int best = -1; float best_d = 0.0f;
        for (int j = 0; j < w->n; j++) {
            const CpCombatCreature *t = &w->c[j];
            if (j == i || !t->alive || t->team == a->team) continue;
            if (a->hit_mask & (1u << j)) continue;
            float ux, uy;
            float dist = dir_to(a, t, &ux, &uy);
            float gap = dist - CB_RADIUS;
            int ok;
            if (m->flags & CB_F_DASH) ok = dist - 2.0f * CB_RADIUS <= CB_CONTACT_GAP;
            else                      ok = gap <= m->reach;
            if (!ok || !in_cone(a, ux, uy, dist, m->arc)) continue;
            if (m->flags & CB_F_SWEEP) {
                Hit *h = &hits[nh++];
                h->atk = (uint8_t)i; h->def = (uint8_t)j; h->move = a->move; h->gap = gap;
            } else if (best < 0 || dist < best_d) { best = j; best_d = dist; }
        }
        if (best >= 0) {
            const CpCombatCreature *t = &w->c[best];
            Hit *h = &hits[nh++];
            h->atk = (uint8_t)i; h->def = (uint8_t)best; h->move = a->move;
            h->gap = sqrtf((t->x - a->x) * (t->x - a->x) + (t->y - a->y) * (t->y - a->y)) - CB_RADIUS;
        }
    }
    return nh;
}

static void apply_status(CpCombatWorld *w, int atk, int def, const CpCombatMove *m)
{
    CpCombatCreature *d = &w->c[def];
    if (!d->alive || m->status == CB_ST_NONE) return;
    switch (m->status) {
    case CB_ST_STUN:
        if (d->stun_t < m->status_ticks) d->stun_t = m->status_ticks;
        stagger(d, 0);
        ev_add(w, CB_EV_STUNNED, atk, def, -1, (float)m->status_ticks);
        break;
    case CB_ST_BLEED:
        if (d->bleed_t < m->status_ticks) d->bleed_t = m->status_ticks;
        d->bleed_src = (int8_t)atk;
        break;
    case CB_ST_SLOW:  if (d->slow_t  < m->status_ticks) d->slow_t  = m->status_ticks; break;
    }
}

static void resolve_hits(CpCombatWorld *w)
{
    Hit hits[CB_MAX_CREATURES * CB_MAX_CREATURES];
    int nh = gather_hits(w, hits);
    if (!nh) return;

    /* pass 1: evaluate every hit against the state at the start of resolution,
     * so all hits of a tick are simultaneous and order-independent */
    uint8_t cancelled[CB_MAX_CREATURES] = { 0 };
    for (int k = 0; k < nh; k++) {
        Hit *h = &hits[k];
        const CpCombatCreature *a = &w->c[h->atk], *d = &w->c[h->def];
        h->ev = eval_hit(w, a, d, h->move, h->gap);
        if (h->ev.rule && h->ev.rule->effect == CB_EFF_INTERRUPT) cancelled[h->def] = 1;
        w->c[h->atk].hit_mask |= (uint8_t)(1u << h->def);
    }

    /* pass 2: apply */
    for (int k = 0; k < nh; k++) {
        const Hit *h = &hits[k];
        if (cancelled[h->atk]) continue;
        CpCombatCreature *a = &w->c[h->atk], *d = &w->c[h->def];
        const CpCombatMove *m = &CP_COMBAT_MOVES[h->move];
        float var = cp_rng_range(&w->rng[CB_RNG_HIT], CB_VAR_LO, CB_VAR_HI);
        if (!d->alive) continue;

        float base = cp_combat_move_damage(&a->prof, h->move) * h->ev.flank * h->ev.height * var;
        float dmg = base;
        int status = 1, broke = 0, interrupted = 0;
        const CpCombatCounter *r = h->ev.rule;

        if (r && r->effect == CB_EFF_AVOID) {
            if (d->stamina >= r->stamina) {
                d->stamina -= r->stamina; d->stamina_spent += r->stamina; d->since_spend = 0;
                d->dodged++;
                ev_add(w, CB_EV_DODGED, h->atk, h->def, h->move, 0.0f);
                continue;
            }
            r = h->ev.alt;                         /* cannot pay: hit lands normally */
        }
        if (r) {
            switch (r->effect) {
            case CB_EFF_NEGATE:
            case CB_EFF_REDUCE: {
                float gl = 1.0f + CB_GUARD_LEVEL_K * (float)(d->prof.guard > 0 ? d->prof.guard - 1 : 0);
                float cost = base * r->stamina / gl;
                if (d->stamina >= cost) {
                    d->stamina -= cost; d->stamina_spent += cost; d->since_spend = 0;
                    dmg = base * r->mult;
                    status = 0;
                    d->blocked++;
                    ev_add(w, CB_EV_BLOCKED, h->atk, h->def, h->move, dmg);
                } else {                            /* guard gives out */
                    d->stamina_spent += d->stamina;
                    d->stamina = 0.0f; d->since_spend = 0;
                    broke = 1;
                    ev_add(w, CB_EV_GUARD_BROKEN, h->atk, h->def, h->move, 0.0f);
                }
                break;
            }
            case CB_EFF_BREAK:
                dmg = base * r->mult;
                d->stamina_spent += cb_clampf(r->stamina, 0.0f, d->stamina);
                d->stamina = cb_maxf(0.0f, d->stamina - r->stamina);
                d->since_spend = 0;
                interrupted = r->ticks ? r->ticks : 1;
                ev_add(w, CB_EV_GUARD_BROKEN, h->atk, h->def, h->move, 0.0f);
                break;
            case CB_EFF_INTERRUPT:
                dmg = base * r->mult;
                interrupted = r->ticks ? r->ticks : 1;
                ev_add(w, CB_EV_INTERRUPTED, h->atk, h->def, h->move, 0.0f);
                break;
            default: break;
            }
        }
        if (broke) { stagger(d, 0); d->stun_t = CB_GUARD_BREAK_STUN; }
        if (interrupted) { stagger(d, interrupted); d->interrupted++; }

        if (dmg > 0.0f) {
            d->hp -= dmg;
            d->dmg_taken += dmg; d->hits_taken++;
            a->dmg_dealt += dmg; a->hits++;
            ev_add(w, CB_EV_HIT, h->atk, h->def, h->move, dmg);
        }
        if (status) apply_status(w, h->atk, h->def, m);
        if (d->hp <= 0.0f) kill(w, h->def, h->atk);
    }
}

uint64_t cp_combat_step(CpCombatWorld *w)
{
    Disp disp[CB_MAX_CREATURES];
    memset(disp, 0, sizeof(disp));
    w->n_ev = 0;

    /* 1. bleeding */
    for (int i = 0; i < w->n; i++) {
        CpCombatCreature *c = &w->c[i];
        if (!c->alive || c->bleed_t == 0) continue;
        c->hp -= CB_BLEED_DPT;
        c->dmg_taken += CB_BLEED_DPT;
        if (c->bleed_src >= 0 && c->bleed_src < w->n) w->c[c->bleed_src].dmg_dealt += CB_BLEED_DPT;
        if (c->hp <= 0.0f) kill(w, i, c->bleed_src);
    }

    /* 2. verbs decide: walk, turn, or launch a move */
    for (int i = 0; i < w->n; i++) plan(w, i, &disp[i]);

    /* 3. dashes (charge, dodge) while active; then apply all movement */
    for (int i = 0; i < w->n; i++) {
        CpCombatCreature *c = &w->c[i];
        if (!c->alive || c->phase != CB_PH_ACTIVE || c->move == CB_MOVE_NONE) continue;
        const CpCombatMove *m = &CP_COMBAT_MOVES[c->move];
        if (!(m->flags & CB_F_DASH)) continue;
        if (!(m->flags & CB_F_SWEEP) && c->hit_mask && !(m->flags & CB_F_SELF)) continue; /* dash ends on contact */
        float step = m->reach / (float)m->active;
        if (c->medium == CB_WATER) step *= 0.5f;
        disp[i].dx += c->dash_x * step;
        disp[i].dy += c->dash_y * step;
    }
    for (int i = 0; i < w->n; i++) {
        CpCombatCreature *c = &w->c[i];
        if (!c->alive) continue;
        c->x = cb_clampf(c->x + disp[i].dx, CB_RADIUS, CB_ARENA_W - CB_RADIUS);
        c->y = cb_clampf(c->y + disp[i].dy, CB_RADIUS, CB_ARENA_H - CB_RADIUS);
    }
    separate(w);

    /* 4. hits of this tick, simultaneously */
    resolve_hits(w);

    /* 5. end of tick: phases, timers, stamina */
    for (int i = 0; i < w->n; i++) {
        CpCombatCreature *c = &w->c[i];
        if (!c->alive) continue;
        if (c->phase != CB_PH_IDLE) advance_phase(c);
        if (c->stun_t)  c->stun_t--;
        if (c->slow_t)  c->slow_t--;
        if (c->bleed_t) c->bleed_t--;
        if (c->phase == CB_PH_IDLE && !disp[i].sprinted && c->since_spend >= CB_REGEN_DELAY) {
            float rg = disp[i].walked ? CB_REGEN * 0.5f : CB_REGEN;
            c->stamina = c->stamina + rg;
            if (c->stamina > c->prof.stamina) c->stamina = c->prof.stamina;
        }
        if (c->since_spend < 255) c->since_spend++;
    }

    w->tick++;
    w->hash = cp_combat_hash(w);
    return w->hash;
}

uint64_t cp_combat_replay(const CpCombatSetup *s, const CpCombatLogEntry *log,
                          int n_log, int ticks, uint64_t *hashes)
{
    CpCombatWorld w;
    cp_combat_reset(&w, s);
    int li = 0;
    uint64_t h = w.hash;
    for (int t = 0; t < ticks; t++) {
        while (li < n_log && log[li].tick <= t) {
            if (log[li].tick == t) cp_combat_order(&w, log[li].id, &log[li].act);
            li++;
        }
        h = cp_combat_step(&w);
        if (hashes) hashes[t] = h;
    }
    return h;
}
