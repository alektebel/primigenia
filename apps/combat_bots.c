#include "combat_bots.h"

#include <string.h>
#include <math.h>

const char *const PROFILE_NAME[N_PROFILES] = {
    "brawler", "spitter", "tank", "skirmisher", "allrounder"
};
/* Published archetypes: shared baseline health/endurance; only the armoured
 * tank buys +20 HP for -0.6 m/s. No per-build calibration to tournament scores.
 *                          mouth charge spit tail guard   hp     stamina speed */
const CpCombatProfile PROFILES[N_PROFILES] = {
    /* brawler    */ { 4, 3, 0, 1, 1,   100.0f, 100.0f, 3.8f, 0, 0 },
    /* spitter    */ { 2, 0, 4, 0, 1,   100.0f, 100.0f, 4.2f, 0, 0 },
    /* tank       */ { 2, 1, 0, 3, 4,  120.0f, 100.0f, 3.4f, 0, 0 },
    /* skirmisher */ { 3, 0, 2, 2, 0,   100.0f, 100.0f, 4.6f, 0, 0 },
    /* allrounder */ { 3, 2, 2, 2, 2,  100.0f, 100.0f, 4.0f, 0, 0 },
};

const char *bot_name(int kind)
{
    static const char *n[BOT_KIND_COUNT] = { "idle", "random", "greedy", "counter", "spam", "counter_naive" };
    return (kind >= 0 && kind < BOT_KIND_COUNT) ? n[kind] : "?";
}

void bot_init(CpBot *b, int kind, uint32_t seed)
{
    memset(b, 0, sizeof(*b));
    b->kind = kind;
    b->reaction = 2;
    b->filler = CB_MOVE_NONE;
    cp_rng_seed(&b->rng, seed * 2654435761u + (uint32_t)kind * 40503u + 17u);
}

/* ---- helpers ---- */
static int offensive(int m)
{
    return m >= 0 && m < CB_MOVE_COUNT && !(CP_COMBAT_MOVES[m].flags & CB_F_SELF);
}

static float wall_room(float x, float y)
{
    float r = x;
    if (y < r) r = y;
    if (CB_ARENA_W - x < r) r = CB_ARENA_W - x;
    if (CB_ARENA_H - y < r) r = CB_ARENA_H - y;
    return r;
}

/* dodge sideways towards whichever side has more room */
static int dodge_dir(const CpCombatWorld *w, int self)
{
    const CpCombatCreature *c = &w->c[self];
    float rx = c->fy, ry = -c->fx;               /* right of facing, y up */
    float wp = wall_room(c->x + rx * 2.2f, c->y + ry * 2.2f);
    float wq = wall_room(c->x - rx * 2.2f, c->y - ry * 2.2f);
    return wp >= wq ? 2 : 6;
}

int bot_bleed_gain(int new_timer, int remaining_ticks)
{
    if (new_timer <= remaining_ticks) return 0;
    int gain = (new_timer - 1) - remaining_ticks;
    return gain > 0 ? gain : 0;
}

static int bot_available(const CpCombatCreature *c,int m){
 return cp_combat_move_available(c,m) && ((CP_COMBAT_MOVES[m].flags&CB_F_SELF)||cp_combat_move_equipped(c,m)) && !c->cd[m] && c->calcium>=CP_COMBAT_MOVES[m].meter_cost;
}
/* Best expected damage per committed tick, including unstacked bleed. */
static int best_attack(const CpCombatWorld *w, int self, int foe, int naive)
{
    const CpCombatCreature *me = &w->c[self];
    int best = -1; float best_s = 0.0f;
    for (int m = 0; m < CB_MOVE_COUNT; m++) {
        if (!offensive(m) || !bot_available(me, m)) continue;
        if (me->stamina < cp_combat_move_stamina(&me->prof, m)) continue;
        CpCombatPreview p;
        if(naive && ((m>=CB_CLAW_SWIPE&&w->c[foe].move!=CB_DODGE)||w->c[foe].move>=CB_CLAW_SWIPE)){
            /* The old picker cannot infer a new counter row through preview. */
            CpCombatWorld seen=*w;seen.c[foe].move=CB_MOVE_NONE;
            cp_combat_preview(&seen,self,m,foe,&p);
        }else cp_combat_preview(w, self, m, foe, &p);
        const CpCombatMove *mv = &CP_COMBAT_MOVES[m];
        float damage = p.damage;
        /* Bleed cannot stack; credit only ticks not already pending. */
        if (mv->status == CB_ST_BLEED && p.counter > 0 &&
            w->c[foe].bleed_t < mv->status_ticks)
            damage += 0.6f * bot_bleed_gain(mv->status_ticks, w->c[foe].bleed_t);
        float s = damage / (float)(mv->windup + mv->active + mv->recovery);
        s *= p.in_reach ? (p.in_arc ? 1.0f : 0.9f) : 0.4f;
        if (s > best_s) { best_s = s; best = m; }
    }
    return best;
}

static const CpCombatCounter *counter_rule(int attack, int defend, int naive)
{
    for (int k = 0; k < (naive?7:CP_COMBAT_N_COUNTERS); k++) {
        const CpCombatCounter *r = &CP_COMBAT_COUNTERS[k];
        if ((r->attack == attack || r->attack < 0) && r->defend == defend) return r;
    }
    return NULL;
}

static int act_attack(CpCombatAction *o, int foe, int m)
{
    o->verb = CB_V_ATTACK; o->move = (int8_t)m; o->target = (int8_t)foe; o->dir = 0;
    return 1;
}

/* A ranged commitment needs room for the enemy's approach during wind-up.
 * Flee is re-evaluated each observation, so this is a short step back rather
 * than an unconditional run to the arena wall. Sidestep along walls to
 * recover space. Move data supplies the desired gap; no build identities. */
static int spaced_attack(CpBot *b, const CpCombatWorld *w, int self, int foe, int m, CpCombatAction *out)
{
    const CpCombatCreature *me = &w->c[self];
    const CpCombatMove *mv = &CP_COMBAT_MOVES[m];
    if ((mv->flags & CB_F_RANGED) && me->phase == CB_PH_IDLE && !b->ranged_commit) {
        CpCombatPreview p; cp_combat_preview(w, self, m, foe, &p);
        float dx = me->x - w->c[foe].x, dy = me->y - w->c[foe].y;
        float room = wall_room(me->x, me->y);
        float rad = cp_combat_body_radius(&me->prof);
        int away_wall = (me->x <= rad+0.5f && dx < 0) ||
            (me->x >= CB_ARENA_W-rad-0.5f && dx > 0) ||
            (me->y <= rad+0.5f && dy < 0) ||
            (me->y >= CB_ARENA_H-rad-0.5f && dy > 0);
        if (p.gap < mv->reach * 0.85f) {
            if (away_wall || room <= rad) {
                if (me->stamina >= cp_combat_move_stamina(&me->prof, CB_DODGE)) {
                    *out = (CpCombatAction){CB_V_DODGE, 0, 0, (int8_t)dodge_dir(w, self), 0, 0, 0};
                    return 1;
                }
            } else {
                *out = (CpCombatAction){CB_V_FLEE, 0, (int8_t)foe, 0, 0, 0, 0 };
                return 1;
            }
        }
    }
    b->ranged_commit = !!(mv->flags & CB_F_RANGED);
    return act_attack(out, foe, m);
}

int bot_locked_ticks(const CpCombatCreature *c)
{
    int lock = 0;
    if (c->phase != CB_PH_IDLE) {
        lock = (int)c->plen - (int)c->ptick;
        if (c->move != CB_MOVE_NONE) {
            const CpCombatMove *m = &CP_COMBAT_MOVES[c->move];
            if (c->phase == CB_PH_WINDUP) lock += m->active + m->recovery;
            else if (c->phase == CB_PH_ACTIVE) lock += m->recovery;
        }
    }
    return lock > (int)c->stun_t ? lock : (int)c->stun_t;
}

/* A guaranteed punish: the fastest mouth attack, launched only when the foe
 * stays locked through walk-in, turn, wind-up and the hit frame. */
static int punish(const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    const CpCombatCreature *me = &w->c[self], *f = &w->c[foe];
    const CpCombatMove *mv = &CP_COMBAT_MOVES[CB_BITE];
    if (me->stun_t || !bot_available(me, CB_BITE) ||
        me->stamina < cp_combat_move_stamina(&me->prof, CB_BITE)) return 0;
    CpCombatPreview p; cp_combat_preview(w, self, CB_BITE, foe, &p);
    /* Do not estimate walk/turn time: launch only from actual attack-start
     * geometry, against a stationary helpless target. */
    float dx = f->x-me->x, dy = f->y-me->y;
    float dist = sqrtf(dx*dx + dy*dy);
    if (p.gap > mv->reach * 0.92f ||
        me->fx*dx + me->fy*dy < 0.97f*dist) return 0;
    int need = (int)mv->windup + (int)mv->active;
    /* A pending hit frame or a standing defence can still answer. */
    if (cp_combat_ticks_to_active(f) >= 0 || p.counter < 1.0f) return 0;
    if (bot_locked_ticks(f) < need) return 0;
    return act_attack(out, foe, CB_BITE);
}

static int greedy(CpBot *b, const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    int m = best_attack(w, self, foe,b->kind==BOT_COUNTER_NAIVE);
    if (m < 0) {                                  /* nothing affordable or useful: rest, closing in */
        out->verb = CB_V_APPROACH; out->target = (int8_t)foe; out->move = 0; out->dir = 0;
        const CpCombatCreature *me = &w->c[self];
        for (int k = 0; k < CB_MOVE_COUNT; k++)
            if (offensive(k) && bot_available(me, k) &&
                me->stamina < cp_combat_move_stamina(&me->prof, k)) { out->verb = CB_V_IDLE; break; }
        return 1;
    }
    return spaced_attack(b, w, self, foe, m, out);
}

/* The opponent's wind-up, if it is aimed at me, in reach, and has been visible
 * for `reaction` ticks; *rem is the ticks until its first active frame. */
static int incoming(const CpBot *b, const CpCombatWorld *w, int self, int foe, int *rem)
{
    const CpCombatCreature *me = &w->c[self], *f = &w->c[foe];
    if (me->phase != CB_PH_IDLE || me->stun_t != 0) return 0;     /* cannot react from here */
    if(b->kind==BOT_COUNTER_NAIVE&&f->move>=CB_CLAW_SWIPE)return 0;
    if (!offensive(f->move) || f->phase != CB_PH_WINDUP || (int)f->ptick < b->reaction) return 0;
    CpCombatPreview thr;
    cp_combat_preview(w, foe, f->move, self, &thr);
    if (thr.gap > CP_COMBAT_MOVES[f->move].reach * 1.15f || !thr.in_arc) return 0;
    *rem = cp_combat_ticks_to_active(f);
    return 1;
}

/* Dash threats hit on contact rather than on the first active frame.
 * Estimate that frame for a stationary reactor; a short forward evade then
 * keeps contact within the active window instead of reading the launch. */
static int dodge_incoming(const CpBot *b, const CpCombatWorld *w, int self, int foe, int *rem)
{
    const CpCombatCreature *f = &w->c[foe];
    if(b->kind==BOT_COUNTER_NAIVE&&f->move>=CB_CLAW_SWIPE)return 0;
    if (w->c[self].stun_t || !offensive(f->move)) return 0;
    const CpCombatMove *m = &CP_COMBAT_MOVES[f->move];
    if (!(m->flags & CB_F_DASH)) return incoming(b, w, self, foe, rem);
    if (f->phase != CB_PH_WINDUP && f->phase != CB_PH_ACTIVE) return 0;
    if (f->phase == CB_PH_WINDUP && f->ptick < b->reaction) return 0;
    CpCombatPreview p; cp_combat_preview(w, foe, f->move, self, &p);
    if (!p.in_arc) return 0;
    float over = p.gap - cp_combat_body_radius(&f->prof) - 0.35f;
    float step = m->reach / m->active;
    if (f->medium == CB_WATER) step *= 0.5f;
    int travel = over > 0 ? (int)(over / step) : 0;
    int left = m->active - (f->phase == CB_PH_ACTIVE ? f->ptick : 0);
    if (travel >= left) return 0;
    *rem = (f->phase == CB_PH_WINDUP ? f->plen-f->ptick : 0) + travel;
    return 1;
}

static int counter(CpBot *b, const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    const CpCombatCreature *me = &w->c[self], *f = &w->c[foe];
    int fm = f->move;

    /* only react from a free state, and only to a wind-up that has been visible
     * long enough, that is aimed at me and in reach */
    {
        int rem;
        if (incoming(b, w, self, foe, &rem)) {
            int best = -1; float best_v = 0.0f;
            for (int r = 0; r < CB_MOVE_COUNT; r++) {
                if (!bot_available(me, r)) continue;
                const CpCombatMove *mr = &CP_COMBAT_MOVES[r];
                float cost = cp_combat_move_stamina(&me->prof, r);
                float v = 0.0f;
                if (mr->flags & (CB_F_SELF|CB_F_GUARD)) {                 /* guard / dodge: timed to cover the first active tick */
                    if (rem < (int)mr->windup || rem > (int)mr->windup + (int)mr->active - 1) continue;
                    const CpCombatCounter *rule = counter_rule(fm, r,b->kind==BOT_COUNTER_NAIVE);
                    int eff = rule ? rule->effect : 0;
                    float extra = 0.0f;
                    if (eff == CB_EFF_AVOID) { v = 2.5f; extra = rule->stamina; }
                    else if (eff == CB_EFF_NEGATE) v = 3.0f;
                    else if (eff == CB_EFF_REDUCE) v = 3.0f;
                    else continue;                           /* no benefit, or worse (charge breaks guard) */
                    if (me->stamina < cost + extra) continue;
                } else {                                     /* an attack that interrupts the wind-up */
                    const CpCombatCounter *rule = counter_rule(r, fm,b->kind==BOT_COUNTER_NAIVE);
                    int eff = rule ? rule->effect : 0;
                    if (eff != CB_EFF_INTERRUPT && eff != CB_EFF_BREAK) continue;
                    CpCombatPreview p;
                    cp_combat_preview(w, self, r, foe, &p);
                    int lag = p.in_arc ? 0 : 1;
                    /* Bite may interrupt spit's active frame; spit must arrive
                     * strictly before charge becomes active. Honour each row. */
                    int same_tick = rule && (rule->phases & CB_PH_BIT(CB_PH_ACTIVE));
                    if (!p.in_reach || (rule && rule->max_gap > 0 && p.gap > rule->max_gap) ||
                        (int)mr->windup + lag > rem - (same_tick ? 0 : 1)) continue;
                    if (me->stamina < cost) continue;
                    v = 3.2f;
                }
                if (v > best_v) { best_v = v; best = r; }
            }
            if (best >= 0) {
                if (CP_COMBAT_MOVES[best].flags & CB_F_SELF) {
                    if (best == CB_GUARD) { out->verb = CB_V_GUARD; out->move = 0; out->target = 0; out->dir = 0; }
                    else { out->verb = CB_V_DODGE; out->move = 0; out->target = 0; out->dir = (int8_t)dodge_dir(w, self); }
                    return 1;
                }
                return act_attack(out, foe, best);
            }
        }
    }
    /* Guard is a visible defensive commitment rather than an incoming hit.
     * Charge must make contact while guard is still active. */
    if (me->phase == CB_PH_IDLE && !me->stun_t && f->move == CB_GUARD && f->phase == CB_PH_ACTIVE &&
        CP_COMBAT_MOVES[CB_GUARD].windup + f->ptick >= b->reaction &&
        bot_available(me, CB_CHARGE)) {
        CpCombatPreview p; cp_combat_preview(w, self, CB_CHARGE, foe, &p);
        int lag = p.in_arc ? 0 : 1;
        if (p.in_reach && p.effect == CB_EFF_BREAK &&
            CP_COMBAT_MOVES[CB_CHARGE].windup + lag < f->plen - f->ptick &&
            me->stamina >= cp_combat_move_stamina(&me->prof, CB_CHARGE))
            return act_attack(out, foe, CB_CHARGE);
    }
    /* a busy creature keeps its plan */
    if (me->phase != CB_PH_IDLE) return 0;
    return greedy(b, w, self, foe, out);
}

static int random_bot(CpBot *b, const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    const CpCombatCreature *me = &w->c[self];
    if (b->timer > 0) b->timer--;
    if (b->timer > 0 && me->verb != CB_V_IDLE) return 0;
    b->timer = 3 + cp_rng_int(&b->rng, 10);

    int roll = cp_rng_int(&b->rng, 8);
    memset(out, 0, sizeof(*out));
    out->target = (int8_t)foe;
    if (roll < 3) {                                       /* a random legal attack */
        int legal[CB_MOVE_COUNT], n = 0;
        for (int m = 0; m < CB_MOVE_COUNT; m++)
            if (offensive(m) && bot_available(me, m)) legal[n++] = m;
        if (n == 0) { out->verb = CB_V_IDLE; return 1; }
        return act_attack(out, foe, legal[cp_rng_int(&b->rng, n)]);
    }
    switch (roll) {
    case 3: out->verb = CB_V_APPROACH; break;
    case 4: out->verb = CB_V_GUARD; if (!bot_available(me, CB_GUARD)) out->verb = CB_V_IDLE; break;
    case 5: out->verb = CB_V_DODGE; out->dir = (int8_t)cp_rng_int(&b->rng, 8); break;
    case 6: out->verb = CB_V_FLEE; break;
    default: out->verb = CB_V_IDLE; break;
    }
    return 1;
}

int bot_decide(CpBot *b, const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    const CpCombatCreature *me = &w->c[self];
    if (!me->alive || foe < 0 || !w->c[foe].alive) return 0;
    if (w->tick < b->delay) return 0;
    if (b->kind != BOT_RANDOM && me->phase != CB_PH_IDLE) {
        b->ranged_commit = 0;
        return 0;
    }
    switch (b->kind) {
    case BOT_IDLE:    return 0;
    case BOT_RANDOM:  return random_bot(b, w, self, foe, out);
    case BOT_GREEDY:  return greedy(b, w, self, foe, out);
    case BOT_COUNTER_NAIVE:
    case BOT_COUNTER: return counter(b, w, self, foe, out);
    case BOT_SPAM:
        memset(out, 0, sizeof(*out));
        /* A fixed-move policy rests while recharging or out of ammunition.
         * Retreating forever after the final shot would price movement, not the move. */
        if(!bot_available(me,b->spam_move)){
            if(b->filler!=CB_MOVE_NONE){
                if(bot_available(me,b->filler)&&me->stamina>=cp_combat_move_stamina(&me->prof,b->filler))
                    return spaced_attack(b,w,self,foe,b->filler,out);
                out->verb=CB_V_APPROACH;out->target=(int8_t)foe;return 1;
            }
            out->verb=CB_V_IDLE;return 1;
        }
        if (CP_COMBAT_MOVES[b->spam_move].flags & (CB_F_SELF|CB_F_GUARD)) {
            /* Defensive commitment: the defence plus the punish it earns.
             * It never gambles: it strikes only when the foe is provably
             * unable to answer before the bite lands, through the same
             * public orders as a player. Never invent defensive damage. */
            if (punish(w, self, foe, out)) return 1;
            if (CP_COMBAT_MOVES[b->spam_move].flags & CB_F_GUARD) {
                CpCombatPreview p; cp_combat_preview(w, self, CB_BITE, foe, &p);
                if (p.gap <= CP_COMBAT_MOVES[CB_BITE].reach * 0.92f && p.in_arc) {
                    if(b->spam_move!=CB_GUARD)return act_attack(out,foe,b->spam_move);
                    out->verb = CB_V_GUARD; return 1;
                }
                out->verb = CB_V_APPROACH; out->target = (int8_t)foe; return 1;
            }
            /* Evasion is a timed read: stay close, dodge a visible wind-up
             * that the table says can be avoided, otherwise keep contact. */
            int rem;
            const CpCombatMove *dm = &CP_COMBAT_MOVES[b->spam_move];
            if (dodge_incoming(b, w, self, foe, &rem) &&
                rem >= (int)dm->windup && rem <= (int)dm->windup + (int)dm->active - 1) {
                const CpCombatCounter *rule = counter_rule(w->c[foe].move, b->spam_move,0);
                if (rule && rule->effect == CB_EFF_AVOID &&
                    me->stamina >= cp_combat_move_stamina(&me->prof, b->spam_move) + rule->stamina) {
                    out->verb = CB_V_DODGE; out->dir = 0; return 1;
                }
            }
            out->verb = CB_V_APPROACH; out->target = (int8_t)foe; return 1;
        }
        return spaced_attack(b, w, self, foe, b->spam_move, out);
    }
    return 0;
}

/* ---- duels ---- */
void duel_setup(CpCombatSetup *s, uint32_t seed, const CpCombatProfile *p0,
                const CpCombatProfile *p1, float dist)
{
    memset(s, 0, sizeof(*s));
    s->seed = seed; s->flat = 1; s->n = 2;
    float cx = CB_ARENA_W * 0.5f, cy = CB_ARENA_H * 0.5f;
    s->c[0].prof = *p0; s->c[0].x = cx - dist * 0.5f; s->c[0].y = cy; s->c[0].fx = 1.0f;  s->c[0].team = 0;
    s->c[1].prof = *p1; s->c[1].x = cx + dist * 0.5f; s->c[1].y = cy; s->c[1].fx = -1.0f; s->c[1].team = 1;
}

static int nearest_enemy(const CpCombatWorld *w, int self)
{
    int best = -1; float bd = 0.0f;
    const CpCombatCreature *a = &w->c[self];
    for (int j = 0; j < w->n; j++) {
        const CpCombatCreature *t = &w->c[j];
        if (j == self || !t->alive || t->team == a->team) continue;
        float dx = t->x - a->x, dy = t->y - a->y, d = dx * dx + dy * dy;
        if (best < 0 || d < bd) { best = j; bd = d; }
    }
    return best;
}

void bots_run(const CpCombatSetup *s, CpBot *bots, int max_ticks, int stop_early,
              CpCombatLogEntry *log, int log_cap, int *n_log,
              uint64_t *hashes, CpCombatWorld *final_world)
{
    CpCombatWorld w;
    cp_combat_reset(&w, s);
    int nl = 0;
    for (int t = 0; t < max_ticks; t++) {
        if (stop_early) {                       /* stop once one team is left */
            int team = -1, multi = 0;
            for (int i = 0; i < w.n; i++)
                if (w.c[i].alive) { if (team < 0) team = w.c[i].team; else if (w.c[i].team != team) multi = 1; }
            if (!multi) break;
        }
        for (int i = 0; i < w.n; i++) {
            CpCombatAction a;
            int foe = nearest_enemy(&w, i);
            if (bot_decide(&bots[i], &w, i, foe, &a) && cp_combat_order(&w, i, &a) == CB_OK && log && nl < log_cap) {
                log[nl].tick = w.tick; log[nl].id = (uint8_t)i; log[nl].act = a; nl++;
            }
        }
        uint64_t h = cp_combat_step(&w);
        if (hashes) hashes[t] = h;
    }
    if (n_log) *n_log = nl;
    if (final_world) *final_world = w;
}

void duel_run(const CpCombatSetup *s, CpBot *b0, CpBot *b1, int max_ticks,
              CpCombatLogEntry *log, int log_cap, int *n_log,
              uint64_t *hashes, CpDuelResult *res)
{
    CpBot bots[2] = { *b0, *b1 };
    CpCombatWorld w;
    bots_run(s, bots, max_ticks, 1, log, log_cap, n_log, hashes, &w);
    *b0 = bots[0]; *b1 = bots[1];
    if (!res) return;
    memset(res, 0, sizeof(*res));
    res->ticks = w.tick;
    for (int i = 0; i < 2; i++) { res->volleys[i]=w.c[i].volleys;res->calcium_spent[i]=w.c[i].volleys*CP_COMBAT_MOVES[CB_SPINE_VOLLEY].meter_cost;res->hp[i] = w.c[i].hp; res->dealt[i] = w.c[i].dmg_dealt; res->spent[i] = w.c[i].stamina_spent; }
    if (w.c[0].alive && !w.c[1].alive) res->winner = 0;
    else if (!w.c[0].alive && w.c[1].alive) res->winner = 1;
    else if (!w.c[0].alive && !w.c[1].alive) res->winner = -1;
    else {                                          /* timeout: higher hp fraction wins by >1% */
        float f0 = w.c[0].hp / w.c[0].prof.hp, f1 = w.c[1].hp / w.c[1].prof.hp;
        res->winner = f0 > f1 + 0.01f ? 0 : (f1 > f0 + 0.01f ? 1 : -1);
    }
}
