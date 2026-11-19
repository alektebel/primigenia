/* Scripted combat bots and a duel runner, shared by apps/combat_tourney.c and
 * tests/test_combat.c. Not part of core/: bots read the world through the
 * public combat.h API and act only through cp_combat_order, exactly like any
 * other agent, so an action log of their orders replays bit-for-bit. */
#ifndef COMBAT_BOTS_H
#define COMBAT_BOTS_H

#include "cpore/combat.h"

enum {
    BOT_IDLE = 0,      /* does nothing                                              */
    BOT_RANDOM,        /* random verb, random legal move, re-rolled every few ticks */
    BOT_GREEDY,        /* best expected damage per committed tick          */
    BOT_COUNTER,       /* answers the opponent's current wind-up with its counter   */
    BOT_SPAM,          /* fixed attack, or defence plus a safe punish (payoff matrix)            */
    BOT_COUNTER_NAIVE, /* legacy counter rows only, P4 surprise control */
    BOT_KIND_COUNT
};

typedef struct {
    int      kind;
    CpRng    rng;
    int      spam_move;      /* BOT_SPAM                                            */
    int      delay;          /* ticks to wait before the first order                */
    int      reaction;       /* COUNTER/SPAM: sees a wind-up once it is this many
                                ticks old (default 2, i.e. 200 ms)                  */
    int      ranged_commit;  /* keep a selected shot through its turn/approach     */
    int      timer;          /* BOT_RANDOM: ticks until the next re-roll            */
} CpBot;

/* New bleed contributes new_timer-1 ticks; existing timer is future damage. */
int bot_bleed_gain(int new_timer, int remaining_ticks);
/* Ticks before a creature can next start anything (0 = free now). */
int bot_locked_ticks(const CpCombatCreature *c);
const char *bot_name(int kind);
void bot_init(CpBot *b, int kind, uint32_t seed);
/* Returns 1 and fills *out if the bot wants to (re)issue a standing order. */
int  bot_decide(CpBot *b, const CpCombatWorld *w, int self, int foe, CpCombatAction *out);

/* ---- duels ---- */
typedef struct {
    int    winner;           /* 0, 1, or -1 for a draw                              */
    int    ticks;
    float  hp[2];            /* final hp                                            */
    float  dealt[2];         /* damage dealt                                        */
    float  spent[2];         /* stamina spent                                       */
    int    calcium_spent[2],volleys[2];
    int    n_hashes;
} CpDuelResult;

/* Two creatures facing each other `dist` metres apart on a flat arena. */
void duel_setup(CpCombatSetup *s, uint32_t seed, const CpCombatProfile *p0,
                const CpCombatProfile *p1, float dist);

/* Run any number of bots (one per creature, each aiming at its nearest living
 * enemy) for max_ticks, or until one team is left if stop_early. Orders are
 * logged and per-tick hashes stored as in duel_run. */
void bots_run(const CpCombatSetup *s, CpBot *bots, int max_ticks, int stop_early,
              CpCombatLogEntry *log, int log_cap, int *n_log,
              uint64_t *hashes, CpCombatWorld *final_world);

/* Run a duel between two bots until one dies or max_ticks. If `log` is non-NULL
 * every order issued is appended (up to log_cap) and *n_log is set; if `hashes`
 * is non-NULL it receives the per-tick hashes (res->ticks entries, the duel
 * stops when one creature is dead). */
void duel_run(const CpCombatSetup *s, CpBot *b0, CpBot *b1, int max_ticks,
              CpCombatLogEntry *log, int log_cap, int *n_log,
              uint64_t *hashes, CpDuelResult *res);

/* named profiles used by the tourney and the tests */
#define N_PROFILES 5
extern const char *const PROFILE_NAME[N_PROFILES];
extern const CpCombatProfile PROFILES[N_PROFILES];

#endif
