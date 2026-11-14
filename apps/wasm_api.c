/* Allocation-free browser ABI. Each modularized WASM instance owns one world.
 * No Emscripten types or dependencies enter core/. Layout IDs are versioned
 * with web/engine/cpcombat.js; mismatches fail before JS writes any memory. */
#include "combat_bots.h"
#include <stddef.h>
#include <math.h>

static CpCombatWorld world;
static CpCombatSetup setup;
static CpBot bots[CB_MAX_CREATURES];
static CpCombatAction action;
enum { STATE_FLOATS = 17, EVENT_FLOATS = 5, PREVIEW_FLOATS = 14 };
static float states[CB_MAX_CREATURES * STATE_FLOATS];
static float events[CB_MAX_EVENTS * EVENT_FLOATS];
static float preview[PREVIEW_FLOATS];
static uint32_t hash_words[2];

#define OFF(t, f) ((int)offsetof(t, f))
int cb_layout(int index)
{
    const int values[] = {
        1, sizeof(CpCombatSetup), OFF(CpCombatSetup, seed), OFF(CpCombatSetup, n),
        OFF(CpCombatSetup, flat), OFF(CpCombatSetup, c), sizeof(CpCombatSpawn),
        OFF(CpCombatSpawn, prof), OFF(CpCombatSpawn, x), OFF(CpCombatSpawn, y),
        OFF(CpCombatSpawn, fx), OFF(CpCombatSpawn, fy), OFF(CpCombatSpawn, medium),
        OFF(CpCombatSpawn, team), sizeof(CpCombatProfile),
        OFF(CpCombatProfile, mouth), OFF(CpCombatProfile, charge), OFF(CpCombatProfile, spit),
        OFF(CpCombatProfile, tail), OFF(CpCombatProfile, guard), OFF(CpCombatProfile, hp),
        OFF(CpCombatProfile, stamina), OFF(CpCombatProfile, speed),
        sizeof(CpCombatAction), OFF(CpCombatAction, verb), OFF(CpCombatAction, move),
        OFF(CpCombatAction, target), OFF(CpCombatAction, dir),
        STATE_FLOATS, EVENT_FLOATS, PREVIEW_FLOATS, CB_MAX_CREATURES, CB_MAX_EVENTS,
        CB_HZ, (int)CB_ARENA_W, (int)CB_ARENA_H
    };
    int n = (int)(sizeof(values) / sizeof(values[0]));
    return index == 0 ? n : (index > 0 && index <= n ? values[index-1] : -1);
}
CpCombatSetup *cb_setup(void) { return &setup; }
int cb_reset(void)
{
    if (setup.n < 1 || setup.n > CB_MAX_CREATURES || setup.flat > 1) return -1;
    for (int i = 0; i < setup.n; i++) {
        CpCombatSpawn *c = &setup.c[i];
        if (!isfinite(c->x) || !isfinite(c->y) || !isfinite(c->fx) || !isfinite(c->fy) ||
            !isfinite(c->prof.hp) || !isfinite(c->prof.stamina) || !isfinite(c->prof.speed) ||
            c->medium > CB_WATER) return -1;
    }
    cp_combat_reset(&world, &setup);
    for (int i = 0; i < world.n; i++) bot_init(&bots[i], BOT_IDLE, setup.seed + (uint32_t)i);
    return 0;
}
int cb_order(int id, int verb, int move, int target, int dir)
{
    if (verb < 0 || verb >= CB_V_COUNT) return CB_ERR_BAD_VERB;
    /* Keep invalid integers invalid rather than allowing byte truncation. */
    CpCombatAction a = {(uint8_t)verb, (int8_t)(move >= -1 && move < CB_MOVE_COUNT ? move : -1),
        (int8_t)(target >= 0 && target < CB_MAX_CREATURES ? target : -1),
        (int8_t)(dir >= 0 && dir < 8 ? dir : -1)};
    return cp_combat_order(&world, id, &a);
}
void cb_step(void) { cp_combat_step(&world); }
int cb_tick(void) { return world.tick; }
int cb_count(void) { return world.n; }
float *cb_states(void)
{
    for (int i = 0; i < world.n; i++) {
        const CpCombatCreature *c = &world.c[i];
        float *s = states + i * STATE_FLOATS;
        const float row[STATE_FLOATS] = {c->x, c->y, c->fx, c->fy, c->hp, c->stamina,
            c->move, c->phase, c->ptick, c->plen, c->stun_t, c->bleed_t, c->slow_t,
            c->alive, c->medium, c->team, c->verb};
        for (int j = 0; j < STATE_FLOATS; j++) s[j] = row[j];
    }
    return states;
}
int cb_event_count(void) { return world.n_ev; }
float *cb_events(void)
{
    for (int i = 0; i < world.n_ev; i++) {
        const CpCombatEvent *e = &world.ev[i];
        float *o = events + i * EVENT_FLOATS;
        o[0] = e->type; o[1] = e->a; o[2] = e->b; o[3] = e->move; o[4] = e->amount;
    }
    return events;
}
uint32_t *cb_hash(void)
{
    uint64_t h = cp_combat_hash(&world);
    hash_words[0] = (uint32_t)h; hash_words[1] = (uint32_t)(h >> 32);
    return hash_words;
}
float *cb_preview(int id, int move, int target)
{
    if (id < 0 || id >= world.n || target < 0 || target >= world.n ||
        id == target || move < 0 || move >= CB_MOVE_COUNT) return NULL;
    CpCombatPreview p;
    cp_combat_preview(&world, id, move, target, &p);
    const CpCombatCreature *c = &world.c[id];
    const CpCombatMove *m = &CP_COMBAT_MOVES[move];
    const float row[PREVIEW_FLOATS] = {c->x, c->y, c->fx, c->fy, m->reach, m->arc,
        p.gap, p.in_reach, p.in_arc, p.flank, p.height, p.counter, p.damage, p.effect};
    for (int i = 0; i < PREVIEW_FLOATS; i++) preview[i] = row[i];
    return preview;
}
int cb_bot_init(int id, int kind, uint32_t seed, int spam_move)
{
    if (id < 0 || id >= world.n || kind < 0 || kind >= BOT_KIND_COUNT ||
        spam_move < 0 || spam_move >= CB_MOVE_COUNT) return -1;
    bot_init(&bots[id], kind, seed); bots[id].spam_move = spam_move;
    return 0;
}
CpCombatAction *cb_bot_decide(int id, int foe)
{
    if (id < 0 || id >= world.n || foe < 0 || foe >= world.n || id == foe ||
        world.c[id].team == world.c[foe].team) return NULL;
    return bot_decide(&bots[id], &world, id, foe, &action) ? &action : NULL;
}
