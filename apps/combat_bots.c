#include "combat_bots.h"

#include <string.h>

const char *const PROFILE_NAME[N_PROFILES] = {
    "brawler", "spitter", "tank", "skirmisher", "allrounder"
};
/*                          mouth charge spit tail guard   hp     stamina speed */
const CpCombatProfile PROFILES[N_PROFILES] = {
    /* brawler    */ { 4, 3, 0, 1, 1,  110.0f,  90.0f, 3.8f },
    /* spitter    */ { 2, 0, 4, 0, 1,   90.0f, 110.0f, 4.2f },
    /* tank       */ { 2, 1, 0, 3, 4,  130.0f, 100.0f, 3.4f },
    /* skirmisher */ { 3, 0, 2, 2, 0,   95.0f, 100.0f, 4.6f },
    /* allrounder */ { 3, 2, 2, 2, 2,  100.0f, 100.0f, 4.0f },
};

const char *bot_name(int kind)
{
    static const char *n[BOT_KIND_COUNT] = { "idle", "random", "greedy", "counter", "spam" };
    return (kind >= 0 && kind < BOT_KIND_COUNT) ? n[kind] : "?";
}

void bot_init(CpBot *b, int kind, uint32_t seed)
{
    memset(b, 0, sizeof(*b));
    b->kind = kind;
    b->reaction = 2;
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

/* best attack by expected damage now; returns the move or -1 */
static int best_attack(const CpCombatWorld *w, int self, int foe)
{
    const CpCombatCreature *me = &w->c[self];
    int best = -1; float best_s = 0.0f;
    for (int m = 0; m < CB_MOVE_COUNT; m++) {
        if (!offensive(m) || !cp_combat_move_available(me, m)) continue;
        if (me->stamina < cp_combat_move_stamina(&me->prof, m)) continue;
        CpCombatPreview p;
        cp_combat_preview(w, self, m, foe, &p);
        float s = p.damage * (p.in_reach ? (p.in_arc ? 1.0f : 0.9f) : 0.4f);
        if (s > best_s) { best_s = s; best = m; }
    }
    return best;
}

static int rule_effect(int attack, int defend)
{
    for (int k = 0; k < CP_COMBAT_N_COUNTERS; k++) {
        const CpCombatCounter *r = &CP_COMBAT_COUNTERS[k];
        if ((r->attack == attack || r->attack < 0) && r->defend == defend) return r->effect;
    }
    return 0;
}

static int act_attack(CpCombatAction *o, int foe, int m)
{
    o->verb = CB_V_ATTACK; o->move = (int8_t)m; o->target = (int8_t)foe; o->dir = 0;
    return 1;
}

static int greedy(const CpCombatWorld *w, int self, int foe, CpCombatAction *out)
{
    int m = best_attack(w, self, foe);
    if (m < 0) {                                  /* nothing affordable or useful: rest, closing in */
        out->verb = CB_V_APPROACH; out->target = (int8_t)foe; out->move = 0; out->dir = 0;
        const CpCombatCreature *me = &w->c[self];
        for (int k = 0; k < CB_MOVE_COUNT; k++)
            if (offensive(k) && cp_combat_move_available(me, k) &&
                me->stamina < cp_combat_move_stamina(&me->prof, k)) { out->verb = CB_V_IDLE; break; }
        return 1;
    }
    return act_attack(out, foe, m);
}

/* The opponent's wind-up, if it is aimed at me, in reach, and has been visible
 * for `reaction` ticks; *rem is the ticks until its first active frame. */
static int incoming(const CpBot *b, const CpCombatWorld *w, int self, int foe, int *rem)
{
    const CpCombatCreature *me = &w->c[self], *f = &w->c[foe];
    if (me->phase != CB_PH_IDLE || me->stun_t != 0) return 0;     /* cannot react from here */
    if (!offensive(f->move) || f->phase != CB_PH_WINDUP || (int)f->ptick < b->reaction) return 0;
    CpCombatPreview thr;
    cp_combat_preview(w, foe, f->move, self, &thr);
    if (thr.gap > CP_COMBAT_MOVES[f->move].reach * 1.15f || !thr.in_arc) return 0;
    *rem = cp_combat_ticks_to_active(f);
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
                if (!cp_combat_move_available(me, r)) continue;
                const CpCombatMove *mr = &CP_COMBAT_MOVES[r];
                float cost = cp_combat_move_stamina(&me->prof, r);
                float v = 0.0f;
                if (mr->flags & CB_F_SELF) {                 /* guard / dodge: timed to cover the first active tick */
                    if (rem < (int)mr->windup || rem > (int)mr->windup + (int)mr->active - 1) continue;
                    int eff = rule_effect(fm, r);
                    float extra = 0.0f;
                    if (eff == CB_EFF_AVOID) { v = 2.5f; extra = 6.0f; }
                    else if (eff == CB_EFF_NEGATE) v = 3.0f;
                    else if (eff == CB_EFF_REDUCE) v = 1.5f;
                    else continue;                           /* no benefit, or worse (charge breaks guard) */
                    if (me->stamina < cost + extra) continue;
                } else {                                     /* an attack that interrupts the wind-up */
                    int eff = rule_effect(r, fm);
                    if (eff != CB_EFF_INTERRUPT && eff != CB_EFF_BREAK) continue;
                    CpCombatPreview p;
                    cp_combat_preview(w, self, r, foe, &p);
                    int lag = p.in_arc ? 0 : 1;
                    if (!p.in_reach || (int)mr->windup + lag > rem - 1) continue;
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
    /* a busy creature keeps its plan */
    if (me->phase != CB_PH_IDLE) return 0;
    return greedy(w, self, foe, out);
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
            if (offensive(m) && cp_combat_move_available(me, m)) legal[n++] = m;
        if (n == 0) { out->verb = CB_V_IDLE; return 1; }
        return act_attack(out, foe, legal[cp_rng_int(&b->rng, n)]);
    }
    switch (roll) {
    case 3: out->verb = CB_V_APPROACH; break;
    case 4: out->verb = CB_V_GUARD; if (!cp_combat_move_available(me, CB_GUARD)) out->verb = CB_V_IDLE; break;
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
    switch (b->kind) {
    case BOT_IDLE:    return 0;
    case BOT_RANDOM:  return random_bot(b, w, self, foe, out);
    case BOT_GREEDY:  return greedy(w, self, foe, out);
    case BOT_COUNTER: return counter(b, w, self, foe, out);
    case BOT_SPAM:
        memset(out, 0, sizeof(*out));
        if (b->spam_move == CB_GUARD || b->spam_move == CB_DODGE) {
            /* a defensive move is reactive: held until a wind-up shows, then timed to cover its first
             * active frame (same latency as the counter-picker). Repeating it blindly proves nothing. */
            const CpCombatMove *m = &CP_COMBAT_MOVES[b->spam_move];
            int rem;
            if (!incoming(b, w, self, foe, &rem)) return 0;
            if (rem < (int)m->windup || rem > (int)m->windup + (int)m->active - 1) return 0;
            if (b->spam_move == CB_GUARD) { out->verb = CB_V_GUARD; return 1; }
            out->verb = CB_V_DODGE; out->dir = (int8_t)dodge_dir(w, self); return 1;
        }
        return act_attack(out, foe, b->spam_move);
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
    for (int i = 0; i < 2; i++) { res->hp[i] = w.c[i].hp; res->dealt[i] = w.c[i].dmg_dealt; res->spent[i] = w.c[i].stamina_spent; }
    if (w.c[0].alive && !w.c[1].alive) res->winner = 0;
    else if (!w.c[0].alive && w.c[1].alive) res->winner = 1;
    else if (!w.c[0].alive && !w.c[1].alive) res->winner = -1;
    else {                                          /* timeout: higher hp fraction wins by >1% */
        float f0 = w.c[0].hp / w.c[0].prof.hp, f1 = w.c[1].hp / w.c[1].prof.hp;
        res->winner = f0 > f1 + 0.01f ? 0 : (f1 > f0 + 0.01f ? 1 : -1);
    }
}
