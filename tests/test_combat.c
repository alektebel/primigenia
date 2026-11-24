#include "combat_bots.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fails;
#define CHECK(c, msg) do { if (!(c)) { printf("  FAIL  %s (line %d)\n", msg, __LINE__); fails++; } } while (0)

static CpCombatWorld pair(float dist)
{
    CpCombatProfile p={0};
    CpCombatSetup s;
    CpCombatWorld w;
    cp_combat_profile_default(&p);
    duel_setup(&s, 42, &p, &p, dist);
    cp_combat_reset(&w, &s);
    return w;
}

/* The flame needs a fire gland, which the default profile does not have (so every older golden stays as it was). */
static void with_fire(CpCombatWorld *w, int i)
{
    w->c[i].prof.fire = 2;
    cp_combat_loadout_default(&w->c[i].lo, &w->c[i].prof);
    cp_combat_loadout_set(&w->c[i].lo, 0, CB_FLAME);    /* the four slots are full of the older moves: the flame takes the first */
}

/* Pin phases to isolate each resolution rule from bot/timing decisions. */
static void phase(CpCombatCreature *c, int move, int ph)
{
    c->move = (int8_t)move; c->phase = (uint8_t)ph;
    c->ptick = 0; c->plen = 100; c->hit_mask = 0;
    c->dash_x = c->fx; c->dash_y = c->fy;
}
static int event(const CpCombatWorld *w, int type)
{
    for (int i = 0; i < w->n_ev; i++) if (w->ev[i].type == type) return 1;
    return 0;
}
static void steps(CpCombatWorld *w, int n)
{
    while (n-- > 0) cp_combat_step(w);
}

static void counters(void)
{
    cp_combat_test_hit_variance(1);
    CpCombatWorld w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE);
    cp_combat_step(&w);
    CHECK(w.c[1].hp == 100 && w.c[1].bleed_t == 0 && w.c[1].blocked == 1,
          "guard negates bite and its bleed");

    w = pair(1.6f);
    phase(&w.c[0], CB_TAIL_STRIKE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE);
    cp_combat_step(&w);
    CHECK(w.c[1].dmg_taken == cp_combat_move_damage(&w.c[0].prof, CB_TAIL_STRIKE)*0.25f && !w.c[1].slow_t,
          "guard reduces tail damage to 25% and suppresses slow");

    w = pair(1.6f);
    phase(&w.c[0], CB_CHARGE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE);
    cp_combat_step(&w);
    CHECK(event(&w, CB_EV_GUARD_BROKEN) &&
          w.c[1].dmg_taken == cp_combat_move_damage(&w.c[0].prof, CB_CHARGE)*0.6f &&
          w.c[1].move == CB_MOVE_NONE && cp_combat_helpless(&w.c[1]),
          "charge contacts a nearby target and breaks guard");

    w = pair(5);
    phase(&w.c[0], CB_SPIT, CB_PH_ACTIVE);
    phase(&w.c[1], CB_CHARGE, CB_PH_WINDUP);
    cp_combat_step(&w);
    CHECK(w.c[1].move == CB_MOVE_NONE && w.c[1].interrupted == 1 &&
          w.c[1].slow_t && event(&w, CB_EV_INTERRUPTED), "spit interrupts charge wind-up");

    w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_SPIT, CB_PH_ACTIVE);
    cp_combat_step(&w);
    CHECK(w.c[0].hp == 100 && w.c[1].hp < 100 && w.c[1].interrupted == 1,
          "bite interrupts simultaneous spit hit at close range");

    w = pair(1.6f);
    cp_combat_attack(&w, 0, 1, CB_BITE);
    cp_combat_attack(&w, 1, 0, CB_SPIT);
    steps(&w, CP_COMBAT_MOVES[CB_BITE].windup + 1);
    CHECK(w.c[0].hp == 100 && w.c[1].interrupted == 1,
          "bite started alongside spit wins the close-range race");

    for (int m = 0; m < CB_CLAW_SWIPE; m++) {
        if (CP_COMBAT_MOVES[m].flags & CB_F_SELF) continue;
        w = pair(1.6f);
        phase(&w.c[0], m, CB_PH_ACTIVE);
        phase(&w.c[1], CB_DODGE, CB_PH_ACTIVE);
        w.c[1].dash_x = w.c[1].dash_y = 0; /* test avoidance, independent of displacement */
        float stamina = w.c[1].stamina;
        cp_combat_step(&w);
        if (m == CB_TAIL_STRIKE) {
            CHECK(w.c[1].hp < 100 && !w.c[1].dodged && w.c[1].interrupted == 1 &&
                  w.c[1].stamina == stamina, "tail catches active dodge without avoidance payment");
            continue;
        }
        CHECK(w.c[0].move == CB_MOVE_NONE && w.c[0].plen == 5 && w.c[1].phase == CB_PH_IDLE,
              "funded avoidance releases dodge and grants a five-tick punish stagger");
        CHECK(w.c[1].hp == 100 && w.c[1].dodged == 1 &&
              w.c[1].stamina == stamina - CP_COMBAT_COUNTERS[1].stamina,
              "funded active dodge avoids non-sweep attacks and pays per hit");
    }
    w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_DODGE, CB_PH_ACTIVE);
    w.c[1].dash_x = w.c[1].dash_y = 0; w.c[1].stamina = 0;
    cp_combat_step(&w);
    CHECK(w.c[1].hp < 100 && !w.c[1].dodged, "exhausted dodge cannot avoid a hit");

    w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE); w.c[1].stamina = 1;
    cp_combat_step(&w);
    CHECK(w.c[1].hp < 100 && event(&w, CB_EV_GUARD_BROKEN) && w.c[1].stun_t &&
          w.c[1].stamina == 0 && w.c[1].stamina_spent == 1,
          "exhausted guard breaks instead of granting free defence");

    w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE); w.c[1].fx = 1;
    CpCombatPreview p;
    cp_combat_preview(&w, 0, CB_BITE, 1, &p);
    CHECK(p.flank == 1.5f && p.counter == 1, "back attack bypasses frontal guard and gains flank bonus");
    cp_combat_step(&w);
    CHECK(w.c[1].dmg_taken == cp_combat_move_damage(&w.c[0].prof, CB_BITE)*1.5f && !w.c[1].blocked, "back hit deals exactly 1.5x damage");
    w = pair(1.6f); w.c[1].fx = 0; w.c[1].fy = 1;
    cp_combat_preview(&w, 0, CB_BITE, 1, &p);
    CHECK(p.flank == 1.25f, "side attack gains 25% damage");
    w.n_hills = 1; w.hill[0] = (CpCombatHill){w.c[0].x, w.c[0].y, 1, 3};
    cp_combat_preview(&w, 0, CB_BITE, 1, &p);
    CHECK(p.height == 1.25f, "height bonus caps at 25%");
    w.c[1].fx = -1; w.c[1].fy = 0;
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].dmg_taken == cp_combat_move_damage(&w.c[0].prof, CB_BITE)*1.25f,
          "actual height damage caps at exactly 1.25x");
    cp_combat_test_hit_variance(0);
}

/* A funded frontal block releases guard; application tick plus a complete
 * fast attack is the shortest stagger that forbids an attacker response. */
static void ripostes(void)
{
    for (int move = 0; move < CB_MOVE_COUNT; move++) {
        if (move != CB_BITE && move != CB_TAIL_STRIKE) continue;
        CpCombatWorld w = pair(1.6f);
        phase(&w.c[0], move, CB_PH_ACTIVE);
        phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE);
        cp_combat_step(&w);
        int window = 1 + CP_COMBAT_MOVES[CB_BITE].windup + CP_COMBAT_MOVES[CB_BITE].active;
        CHECK(w.c[0].move == CB_MOVE_NONE && w.c[0].plen == window &&
              w.c[0].ptick == 1 && w.c[1].phase == CB_PH_IDLE,
              "successful block releases guard and staggers for exactly one fast move");
        cp_combat_attack(&w, 1, 0, CB_BITE);
        for (int t = 0; t < window-1; t++) {
            CHECK(cp_combat_helpless(&w.c[0]), "attacker cannot act before riposte lands");
            cp_combat_attack(&w, 0, 1, CB_BITE);
            cp_combat_step(&w);
        }
        CHECK(w.c[0].hp < 100 && w.c[1].hits == 1 && w.c[0].phase == CB_PH_IDLE,
              "bite riposte lands on final stagger tick, without extra lockout");
        w = pair(1.6f);
        phase(&w.c[0], move, CB_PH_ACTIVE);
        phase(&w.c[1], CB_GUARD, CB_PH_ACTIVE); w.c[1].stamina = 0;
        cp_combat_step(&w);
        CHECK(w.c[0].move == move, "exhausted block grants no riposte stagger");
    }
}

static void spacing(void)
{
    for (int kind = BOT_GREEDY; kind <= BOT_COUNTER; kind++) {
        CpCombatWorld w = pair(3.5f);
        w.c[0].prof.mouth = w.c[0].prof.charge = w.c[0].prof.tail = 0;
        CpBot b; bot_init(&b, kind, 42);
        CpCombatAction a;
        CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb == CB_V_FLEE,
              "ranged picker steps back when its best attack needs space");
        cp_combat_order(&w, 0, &a);
        float x = w.c[0].x;
        cp_combat_step(&w);
        CHECK(w.c[0].x < x, "ranged spacing moves away through public orders");
        w = pair(6.0f);
        w.c[0].prof.mouth = w.c[0].prof.charge = w.c[0].prof.tail = 0;
        CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb == CB_V_ATTACK && a.move == CB_SPIT,
              "ranged picker fires once spacing is established");
        w = pair(7.0f);
        w.c[0].prof.mouth = w.c[0].prof.charge = w.c[0].prof.tail = 0;
        bot_init(&b, kind, 42);
        CpBot chase; bot_init(&chase, BOT_SPAM, 43); chase.spam_move = CB_BITE;
        for (int t = 0; t < 25; t++) {
            if (bot_decide(&b, &w, 0, 1, &a)) cp_combat_order(&w, 0, &a);
            if (bot_decide(&chase, &w, 1, 0, &a)) cp_combat_order(&w, 1, &a);
            cp_combat_step(&w);
        }
        CHECK(w.c[0].hits > 0, "spacing commits to a shot while turning instead of oscillating");

    }
}

static void ranged_exchanges(void)
{
    CpCombatProfile p={0}; cp_combat_profile_default(&p);
    p.mouth = p.charge = p.spit = p.tail = p.guard = 3;
    p.hp = 100000;
    for (int far = 0; far <= 1; far++) {
        double margin = 0;
        for (int s = 0; s < 80; s++) {
            CpCombatSetup setup;
            duel_setup(&setup, 1000u + (uint32_t)(s/2), &p, &p, far ? 7.0f : 1.6f);
            CpBot b0, b1; CpDuelResult r;
            bot_init(&b0, BOT_SPAM, (uint32_t)s);
            bot_init(&b1, BOT_SPAM, (uint32_t)s+7777u);
            b0.spam_move = s%2 ? CB_BITE : CB_SPIT; b0.delay = (s/2)%4;
            b1.spam_move = s%2 ? CB_SPIT : CB_BITE; b1.delay = (s/8)%7;
            duel_run(&setup, &b0, &b1, 120, NULL, 0, NULL, NULL, &r);
            margin += r.dealt[s%2] - r.dealt[1-s%2];
        }
        printf("  spit exchange %.1f m: mean damage margin %+.2f HP (80 paired-seat duels)\n",
               far ? 7.0 : 1.6, margin/80);
        CHECK(far ? margin > 0 : margin < 0,
              "spaced spit wins at range; bite wins the close exchange");
    }
}

/* Two attackers exchange ids, retaining their physical positions and profiles. */
static CpCombatWorld focus(int swap, int defence, float stamina, float hp)
{
    CpCombatWorld w = pair(1.6f);
    w.n = 3; w.c[2] = w.c[1];
    w.c[0].y -= 0.65f;
    w.c[1] = w.c[0]; w.c[1].y += 1.3f;
    w.c[2].stamina = stamina; w.c[2].hp = hp;
    w.c[0].prof.mouth = 1; w.c[1].prof.mouth = 4;
    if (swap) { CpCombatCreature t = w.c[0]; w.c[0] = w.c[1]; w.c[1] = t; }
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_BITE, CB_PH_ACTIVE);
    if (defence >= 0) phase(&w.c[2], defence, CB_PH_ACTIVE);
    w.c[2].dash_x = w.c[2].dash_y = 0;
    return w;
}

static void simultaneous(void)
{
    cp_combat_test_hit_variance(1);
    for (int swap = 0; swap < 2; swap++) {
        CpCombatWorld w = focus(swap, -1, 100, 1);
        cp_combat_step(&w);
        CHECK(w.c[0].hits == 1 && w.c[1].hits == 1 && w.c[2].hits_taken == 2,
              "focus fire credits every landed hit on a lethal tick");
        CHECK(w.c[0].kills == 1 && w.c[1].kills == 0 && !w.c[2].alive,
              "lowest id landing damage owns the lethal tick");
        CHECK(w.c[2].dmg_taken == cp_combat_move_damage(&w.c[0].prof, CB_BITE) +
              cp_combat_move_damage(&w.c[1].prof, CB_BITE),
              "focus damage is unchanged when attackers swap ids");
        w = focus(swap, -1, 100, 20);
        cp_combat_step(&w);
        CHECK(!w.c[2].alive && w.c[0].kills == 1 && w.c[1].kills == 0 && w.c[1].hits == 1,
              "lowest id gets lethal-tick credit even when its own hit was nonlethal");
        w = focus(swap, -1, 100, 100);
        cp_combat_step(&w);
        CHECK(w.c[2].bleed_t == CP_COMBAT_MOVES[CB_BITE].status_ticks-1 && w.c[2].bleed_src == 0,
              "equal-duration bleed cannot steal the extending hit's credit");
        w = focus(swap, -1, 100, 100); w.c[2].bleed_t = 20; w.c[2].bleed_src = 0;
        cp_combat_step(&w);
        CHECK(w.c[2].bleed_t == 19 && w.c[2].bleed_src == 0,
              "shorter bleed cannot replace an existing source");
        w = focus(swap, CB_DODGE, CP_COMBAT_COUNTERS[1].stamina, 100);
        cp_combat_step(&w);
        CHECK(w.c[0].hits == 0 && w.c[1].hits == 1 && w.c[2].dodged == 1 &&
              w.c[2].stamina == 0 && w.c[2].stamina_spent == CP_COMBAT_COUNTERS[1].stamina,
              "scarce dodge pays the lower-id hit only, from snapshot stamina");
        w = focus(swap, CB_GUARD, 2.0f, 100);
        cp_combat_step(&w);
        CHECK(w.c[0].hits == 0 && w.c[1].hits == 1 && w.c[2].blocked == 1 &&
              w.c[2].stamina == 0 && w.c[2].stamina_spent == 2.0f && w.c[2].stun_t == 5,
              "scarce guard records one block then one exhausted break");
        w = focus(swap, CB_DODGE, 100, 100);
        cp_combat_step(&w);
        CHECK(w.c[2].hp == 100 && w.c[2].dodged == 2 && w.c[2].stamina_spent == 2*CP_COMBAT_COUNTERS[1].stamina,
              "ample dodge has identical outcomes with attacker ids swapped");
        w = focus(swap, -1, 100, 1);
        w.c[0].x += 0.3f; w.c[1].x += 0.3f; /* inside charge contact gap */
        float dx = w.c[2].x-w.c[1].x, dy = w.c[2].y-w.c[1].y;
        float dist = sqrtf(dx*dx+dy*dy);
        w.c[1].fx = dx/dist; w.c[1].fy = dy/dist;
        phase(&w.c[1], CB_CHARGE, CB_PH_ACTIVE);
        w.c[1].dash_x = w.c[1].dash_y = 0;
        cp_combat_step(&w);
        int deaths = 0;
        for (int e = 0; e < w.n_ev; e++) deaths += w.ev[e].type == CB_EV_DEATH;
        CHECK(w.c[1].hits == 1 && event(&w, CB_EV_STUNNED) && deaths == 1,
              "later lethal-tick hit still applies status before the single death pass");
        w = focus(swap, CB_GUARD, 100, 100);
        cp_combat_step(&w);
        CHECK(w.c[2].hp == 100 && w.c[2].blocked == 2,
              "ample guard has identical outcomes with attacker ids swapped");
    }
    cp_combat_test_hit_variance(0);
}

static void bot_counters(void)
{
    puts("  counter execution (reaction delays 0..3; 1 = executed):");
    for (int row = 0; row < 7; row++) {
        const CpCombatCounter *r = &CP_COMBAT_COUNTERS[row];
        printf("    row %d:", row);
        for (int delay = 0; delay <= 3; delay++) {
            /* Dodge's wildcard is tested against every offensive move below. */
            int first = r->attack < 0 ? 0 : r->attack;
            int last = r->attack < 0 ? CB_CLAW_SWIPE-1 : r->attack;
            int all = 1;
            for (int attack = first; attack <= last; attack++) {
                if (CP_COMBAT_MOVES[attack].flags & CB_F_SELF) continue;
                if (r->attack < 0 && attack == CB_TAIL_STRIKE) continue;
                int response = (r->effect == CB_EFF_BREAK || r->effect == CB_EFF_INTERRUPT) ? attack : r->defend;
                int threat = response == attack ? r->defend : attack;
                CpCombatWorld w = pair(1.6f);
                if (threat == CB_FLAME) with_fire(&w, 0);
                CpBot bot; bot_init(&bot, BOT_COUNTER, 42); bot.reaction = delay;
                /* Isolate this row's equipment; every action still goes through
                 * bot_decide/order/step, starting from a real observed wind-up. */
                w.c[1].prof.mouth = w.c[1].prof.charge = w.c[1].prof.spit = w.c[1].prof.tail = w.c[1].prof.guard = 0;
                if (response == CB_BITE) w.c[1].prof.mouth = 2;
                if (response == CB_CHARGE) w.c[1].prof.charge = 2;
                if (response == CB_SPIT) w.c[1].prof.spit = 2;
                if (response == CB_TAIL_STRIKE) w.c[1].prof.tail = 2;
                if (response == CB_GUARD) w.c[1].prof.guard = 2;
                w.c[1].prof.fire = 0;
                if (response == CB_FLAME) with_fire(&w, 1);
                if (threat == CB_DODGE) cp_combat_dodge(&w, 0, 0);
                else if (threat == CB_GUARD) cp_combat_guard(&w, 0);
                else cp_combat_attack(&w, 0, 1, threat);
                int executed = 0;
                for (int t = 0; t < 35; t++) {
                    /* Keep the reactor free until its observation delay, then
                     * let the actual picker choose; no forced active phases. */
                    if (t >= (delay > 0 ? delay : 1)) {
                        CpCombatAction act;
                        if (bot_decide(&bot, &w, 1, 0, &act)) cp_combat_order(&w, 1, &act);
                    }
                    int evading = w.c[0].phase == CB_PH_ACTIVE && w.c[1].move == CB_DODGE && w.c[1].phase == CB_PH_ACTIVE;
                    cp_combat_step(&w);
                    /* A real dodge can also move entirely outside the hit
                     * cone. Both displacement and the avoid row are valid. */
                    if (response == CB_DODGE && evading && w.c[1].dmg_taken == 0) executed = 1;
                    for (int e = 0; e < w.n_ev; e++) {
                        const CpCombatEvent *ev = &w.ev[e];
                        if (response == CB_DODGE) executed |= ev->type == CB_EV_DODGED && ev->b == 1;
                        else if (response == CB_GUARD) executed |= ev->type == CB_EV_BLOCKED && ev->b == 1;
                        else executed |= ev->a == 1 && ev->b == 0 && ev->move == response &&
                            ev->type == (r->effect == CB_EFF_BREAK ? CB_EV_GUARD_BROKEN : CB_EV_INTERRUPTED);
                    }
                    if (w.c[0].hits || w.c[0].interrupted || executed) break;
                }
                if (r->effect == CB_EFF_AVOID) CHECK(executed == (delay <= 2 || attack == CB_CHARGE || attack == CB_SPIT || attack == CB_FLAME),
                    "dodge execution window is checked for each offensive move");
                all &= executed;
            }
            printf(" %d", all);
            int expected = r->defend == CB_DODGE && r->attack == CB_TAIL_STRIKE ? 0 : (r->effect == CB_EFF_AVOID || r->effect == CB_EFF_NEGATE || r->effect == CB_EFF_REDUCE) ? (delay <= 2 || r->attack == CB_FLAME) : 1;
            CHECK(all == expected, "counter row execution matches its documented reaction window");
        }
        puts("");
    }
    CHECK(bot_bleed_gain(15, 0) == 14 && bot_bleed_gain(15, 5) == 9 &&
          bot_bleed_gain(15, 15) == 0 && bot_bleed_gain(15, 20) == 0,
          "greedy counts only newly added future bleed damage ticks");
    CpCombatWorld w = pair(10);
    for (int m = CB_GUARD; m <= CB_DODGE; m += CB_DODGE-CB_GUARD) {
        CpBot b; bot_init(&b, BOT_SPAM, 42); b.spam_move = m;
        CpCombatAction act;
        CHECK(bot_decide(&b, &w, 0, 1, &act) && act.verb == CB_V_APPROACH,
              "defensive policies close to punish range before committing");
    }
}

static void defensive_policies(void)
{
    for (int m = CB_GUARD; m <= CB_DODGE; m += CB_DODGE-CB_GUARD) {
        CpBot b; bot_init(&b, BOT_SPAM, 42); b.spam_move = m;
        CpCombatAction a;
        CpCombatWorld w = pair(1.6f);
        phase(&w.c[1], CB_MOVE_NONE, CB_PH_RECOVERY);
        w.c[1].plen = 4;
        CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb == CB_V_ATTACK && a.move == CB_BITE,
              "defensive policy takes an aligned funded punish at the exact four-tick boundary");
        cp_combat_order(&w, 0, &a); steps(&w, 4);
        CHECK(w.c[0].hits == 1 && w.c[1].phase == CB_PH_IDLE,
              "real defensive bite lands on the final helpless frame");
        for (int scenario = 0; scenario < 5; scenario++) {
            w = pair(scenario == 2 ? 5 : 1.6f);
            phase(&w.c[1], CB_MOVE_NONE, CB_PH_RECOVERY); w.c[1].plen = 4;
            if (scenario == 0) w.c[1].plen = 3;
            if (scenario == 1) w.c[0].fx = -1;
            if (scenario == 3) w.c[0].stamina = 0;
            if (scenario == 4) w.c[0].stun_t = 1;
            CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb != CB_V_ATTACK,
                  "punish refuses short window, turn, walk-in, unfunded or stunned attack");
        }
    }
    CpBot b; bot_init(&b, BOT_SPAM, 42); b.spam_move = CB_DODGE;
    CpCombatAction a; CpCombatWorld w = pair(4.6f);
    phase(&w.c[1], CB_CHARGE, CB_PH_ACTIVE); w.c[1].plen = 5;
    CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb == CB_V_DODGE,
          "dodge reads contact during an active charge, after its wind-up has ended");
    phase(&w.c[1], CB_TAIL_STRIKE, CB_PH_WINDUP);
    CHECK(bot_decide(&b, &w, 0, 1, &a) && a.verb != CB_V_DODGE,
          "dodge policy respects the tail exception rather than claiming an avoid");
}

static void edges_and_verbs(void)
{
    CpCombatWorld w = pair(1.6f);
    float cost = cp_combat_move_stamina(&w.c[0].prof, CB_BITE);
    w.c[0].stamina = cost - 0.01f; w.c[0].since_spend = 0;
    cp_combat_attack(&w, 0, 1, CB_BITE); cp_combat_step(&w);
    CHECK(w.c[0].move == CB_MOVE_NONE && event(&w, CB_EV_NO_STAMINA), "unaffordable move waits without spending");
    w.c[0].stamina = cost; cp_combat_step(&w);
    CHECK(w.c[0].move == CB_BITE && w.c[0].stamina == 0, "exact stamina starts move once");
    float spent = w.c[0].stamina_spent;
    cp_combat_attack(&w, 0, 1, CB_BITE);
    steps(&w, CP_COMBAT_MOVES[CB_BITE].windup + CP_COMBAT_MOVES[CB_BITE].active + CP_COMBAT_MOVES[CB_BITE].recovery);
    CHECK(w.c[0].phase == CB_PH_IDLE && w.c[0].verb == CB_V_IDLE && w.c[0].stamina_spent == spent,
          "attack completes once; identical repeated order never restarts wind-up");
    steps(&w, 200);
    CHECK(w.c[0].stamina == w.c[0].prof.stamina, "idle regenerates stamina to its cap");

    w = pair(10); cp_combat_approach(&w, 0, 1); steps(&w, 60);
    CHECK(w.c[0].verb == CB_V_IDLE && w.c[1].x - w.c[0].x <= 2*CB_RADIUS + CB_APPROACH_GAP,
          "approach persists until near target, then completes");
    cp_combat_flee(&w, 0, 1); steps(&w, CB_FLEE_TICKS + 1);
    CHECK(w.c[0].verb == CB_V_IDLE && w.c[0].stamina_spent > 0, "flee completes by distance or timeout and costs stamina");
    for (int m = CB_GUARD; m <= CB_DODGE; m += CB_DODGE - CB_GUARD) {
        w = pair(10);
        if (m == CB_GUARD) cp_combat_guard(&w, 0); else cp_combat_dodge(&w, 0, 2);
        steps(&w, CP_COMBAT_MOVES[m].windup + CP_COMBAT_MOVES[m].active + CP_COMBAT_MOVES[m].recovery);
        CHECK(w.c[0].verb == CB_V_IDLE && w.c[0].move == CB_MOVE_NONE, "defensive verb completes after recovery");
    }
    w = pair(1.6f); cp_combat_attack(&w, 0, 1, CB_BITE); cp_combat_step(&w);
    cp_combat_flee(&w, 0, 1); steps(&w, 30);
    CHECK(w.c[0].x < 15 && w.c[0].hits == 1, "new verb queues behind committed move without repeating it");

    w = pair(1.6f); w.c[1].hp = 1;
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(!w.c[1].alive && w.c[1].hp == 0 && w.c[0].kills == 1 && w.c[1].died_tick == 0,
          "lethal damage clamps hp, clears move and credits death once");
    CHECK(cp_combat_guard(&w, 1) == CB_ERR_DEAD && cp_combat_attack(&w, 0, 1, CB_BITE) == CB_ERR_BAD_TARGET,
          "dead creatures cannot act or be ordered as targets");
    steps(&w, 100);
    CHECK(w.c[0].kills == 1 && !w.c[1].bleed_t && w.c[1].stamina == 100, "dead state stays inert");
    w = pair(1.6f); w.c[1].hp = 0.5f; w.c[1].bleed_t = 1; w.c[1].bleed_src = 0;
    cp_combat_step(&w);
    CHECK(!w.c[1].alive && w.c[0].kills == 1, "bleed can kill before planning");
    w = pair(1.6f); w.c[0].hp = w.c[1].hp = 1;
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE); phase(&w.c[1], CB_BITE, CB_PH_ACTIVE);
    cp_combat_step(&w);
    CHECK(cp_combat_alive_count(&w) == 0, "simultaneous lethal attacks trade kills");

    w = pair(10);
    uint64_t h = cp_combat_hash(&w);
    CpCombatAction bad[] = {{255,0,0,0,0,0}, {CB_V_ATTACK, CB_GUARD,1,0,0,0}, {CB_V_ATTACK,99,1,0,0,0},
                            {CB_V_ATTACK,CB_BITE,0,0,0,0}, {CB_V_DODGE,0,0,8,0,0}};
    for (size_t i = 0; i < sizeof bad / sizeof bad[0]; i++) {
        CHECK(cp_combat_order(&w, 0, &bad[i]) < 0 && cp_combat_hash(&w) == h, "invalid order leaves state untouched");
    }
    CHECK(cp_combat_guard(&w, -1) == CB_ERR_BAD_ID, "invalid creature id rejected");
    CHECK(cp_combat_attack(&w, 0, 1, 256) == CB_ERR_BAD_MOVE &&
          cp_combat_dodge(&w, 0, 256) == CB_ERR_BAD_DIR &&
          cp_combat_approach(&w, 1, 256) == CB_ERR_BAD_TARGET &&
          cp_combat_flee(&w, 1, 256) == CB_ERR_BAD_TARGET &&
          cp_combat_attack(&w, 1, 256, CB_BITE) == CB_ERR_BAD_TARGET,
          "integer verb helpers reject values before narrowing to action bytes");
    w.c[0].prof.mouth = 0;
    CHECK(cp_combat_attack(&w, 0, 1, CB_BITE) == CB_ERR_UNAVAILABLE && cp_combat_move_damage(&w.c[0].prof, CB_BITE) == 0,
          "missing part gates its move");
    w.c[0].medium = CB_WATER;
    CHECK(cp_combat_attack(&w, 0, 1, CB_CHARGE) == CB_ERR_UNAVAILABLE, "water blocks charge");
    cp_combat_approach(&w, 0, 1); float x = w.c[0].x; cp_combat_step(&w);
    CHECK(fabsf(w.c[0].x - x - 4*CB_DT*0.6f) < 1e-5f, "water slows walking");
    w = pair(10); w.c[0].slow_t = 5; cp_combat_approach(&w, 0, 1); x = w.c[0].x;
    cp_combat_step(&w);
    CHECK(fabsf(w.c[0].x - x - 4*CB_DT*0.5f) < 1e-5f, "slow status slows walking");
}

static void geometry_and_setup(void)
{
    CpCombatWorld w = pair(1.5f);
    w.c[1].y += 0.30f;
    CpCombatPreview preview;
    cp_combat_preview(&w, 0, CB_SPIT, 1, &preview);
    CHECK(preview.in_arc, "preview includes hit cone lateral slack");
    phase(&w.c[0], CB_SPIT, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].hp < 100, "preview slack agrees with actual spit hit");
    w = pair(1.6f);
    uint64_t h = cp_combat_hash(&w);
    memset(&w.c[2], 0xa5, sizeof w.c[2]);
    w.c[0].dash_y = -0.0f;
    CHECK(cp_combat_hash(&w) == h, "unused creatures and signed zero do not affect canonical hash");
    w = pair(1.6f);
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    cp_combat_step(&w); float hp = w.c[1].hp;
    cp_combat_step(&w);
    CHECK(w.c[1].hp > hp - 1 && w.c[0].hits == 1, "one move hits each creature only once, then bleed ticks");

    w = pair(1.6f); w.n = 4;
    w.c[2] = w.c[1]; w.c[2].y += 0.7f;
    w.c[3] = w.c[1]; w.c[3].y -= 0.7f; w.c[3].team = 0;
    phase(&w.c[0], CB_TAIL_STRIKE, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].hp < 100 && w.c[2].hp < 100 && w.c[3].hp == 100,
          "tail sweep hits multiple enemies but never teammates");
    w = pair(4); w.n = 3; w.c[2] = w.c[1]; w.c[2].x += 1.5f;
    phase(&w.c[0], CB_SPIT, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].hp < 100 && w.c[2].hp == 100, "spit hits nearest enemy on its ray only");
    w = pair(3); phase(&w.c[0], CB_BITE, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].hp == 100, "out-of-reach bite misses");
    w = pair(1.6f); w.c[0].fx = -1;
    phase(&w.c[0], CB_BITE, CB_PH_ACTIVE); cp_combat_step(&w);
    CHECK(w.c[1].hp == 100, "attack outside facing cone misses");
    w = pair(1.6f); phase(&w.c[0], CB_BITE, CB_PH_ACTIVE);
    phase(&w.c[1], CB_DODGE, CB_PH_WINDUP); cp_combat_step(&w);
    CHECK(w.c[1].hp < 100 && !w.c[1].dodged, "dodge wind-up is vulnerable");

    for (int move = 0; move < CB_MOVE_COUNT; move++) {
        if (move >= CB_CLAW_SWIPE && move != CB_FLAME) continue;
        const CpCombatMove *m = &CP_COMBAT_MOVES[move];
        w = pair(1.6f);
        if (move == CB_FLAME) with_fire(&w, 0);
        if (move == CB_GUARD) cp_combat_guard(&w, 0);
        else if (move == CB_DODGE) cp_combat_dodge(&w, 0, 0);
        else cp_combat_attack(&w, 0, 1, move);
        cp_combat_step(&w);
        CHECK(w.c[0].phase == (m->windup == 1 ? CB_PH_ACTIVE : CB_PH_WINDUP) && cp_combat_ticks_to_active(&w.c[0]) == m->windup - 1,
              "move begins in wind-up with exact remaining tick count");
        steps(&w, m->windup - 1);
        CHECK(w.c[0].phase == CB_PH_ACTIVE && w.c[1].hp == 100, "wind-up never hits before first active frame");
        steps(&w, m->active);
        CHECK(w.c[0].phase == CB_PH_RECOVERY && cp_combat_ticks_to_active(&w.c[0]) == -1,
              "active frame count leads to recovery");
        steps(&w, m->recovery);
        CHECK(w.c[0].move == CB_MOVE_NONE && w.c[0].verb == CB_V_IDLE,
              "each move completes at wind-up + active + recovery ticks");
    }
    CpCombatSetup s = {0}; s.n = 99; s.flat = 1;
    for (int i = 0; i < CB_MAX_CREATURES; i++) {
        s.c[i].prof = (CpCombatProfile){255,255,255,255,255, -5, -1, 100, 0, 0};
        s.c[i].x = 100; s.c[i].y = 100;
    }
    cp_combat_reset(&w, &s);
    CHECK(w.n == CB_MAX_CREATURES && w.c[0].prof.mouth == 5 && w.c[0].hp == 1 &&
          w.c[0].stamina == 1 && w.c[0].prof.speed == 12 && w.c[0].fx == 1 &&
          w.c[0].x == CB_ARENA_W - CB_RADIUS, "setup clamps count, profile, position and zero facing");
    s.n = -1; cp_combat_reset(&w, &s); cp_combat_step(&w);
    CHECK(w.n == 0 && cp_combat_alive_count(&w) == 0, "empty arena steps safely");
}

static void determinism(void)
{
    enum { TICKS = 10000, LOG_CAP = CB_MAX_CREATURES*TICKS };
    uint64_t *a = malloc(TICKS*sizeof(*a)), *b = malloc(TICKS*sizeof(*b));
    CpCombatLogEntry *log = malloc(LOG_CAP*sizeof(*log));
    if (!a || !b || !log) { fprintf(stderr, "allocation failed\n"); exit(2); }
    const uint32_t seeds[] = {0, 1, 42, 987654321u, UINT32_MAX};
    for (size_t k = 0; k < sizeof seeds / sizeof seeds[0]; k++) {
        CpCombatSetup s = {0}; s.seed = seeds[k]; s.n = CB_MAX_CREATURES;
        CpBot bots[CB_MAX_CREATURES];
        for (int i = 0; i < s.n; i++) {
            cp_combat_profile_default(&s.c[i].prof);
            s.c[i].prof.hp = 100000; /* exercise combat throughout the full 10k ticks */
            s.c[i].x = s.c[i].y = -1; s.c[i].team = (uint8_t)(i%2);
            s.c[i].medium = (uint8_t)(i%3 == 0);
            bot_init(&bots[i], i%3 + BOT_RANDOM, seeds[k] + (uint32_t)i);
        }
        CpCombatWorld end;
        int nl = 0;
        bots_run(&s, bots, TICKS, 0, log, LOG_CAP, &nl, a, &end);
        uint64_t h = cp_combat_replay(&s, log, nl, TICKS, b);
        CHECK(end.tick == TICKS && nl > 100 && nl < LOG_CAP && h == end.hash && memcmp(a,b,TICKS*sizeof(*a)) == 0,
              "10,000 per-tick hashes match replay from identical seed and action log");
        cp_combat_replay(&s, log, nl, TICKS, a);
        CHECK(memcmp(a,b,TICKS*sizeof(*a)) == 0, "second independent replay matches every tick");
        uint64_t canonical = cp_combat_hash(&end);
        end.ev[0].amount += 99; end.n_ev = 0; end.hash = 0;
        /* Deliberately dirty profile padding: canonical fields still match. */
        unsigned char *prof = (unsigned char *)&end.c[0].prof;
        for (size_t j = offsetof(CpCombatProfile, guard) + sizeof(end.c[0].prof.guard);
             j < offsetof(CpCombatProfile, hp); j++) prof[j] ^= 0xff;
        CHECK(cp_combat_hash(&end) == canonical, "derived event buffers and cached hash are excluded");
        end.rng[CB_RNG_HIT].s[0] ^= 1;
        CHECK(cp_combat_hash(&end) != canonical, "RNG state participates in canonical hash");
    }
    free(a); free(b); free(log);
}

static void canaries(void)
{
    /* Both seat orders, all ordered builds, 40 seeds: 8,000 duels. */
    for (int smart = BOT_GREEDY; smart <= BOT_COUNTER; smart++) {
        int idle_wins = 0, idle_draws = 0, random_wins = 0, random_draws = 0, smart_wins = 0, n = 0;
        for (int pa = 0; pa < N_PROFILES; pa++) for (int pb = 0; pb < N_PROFILES; pb++)
            for (int seed = 0; seed < 40; seed++) for (int seat = 0; seat < 2; seat++) {
                CpCombatSetup s; CpBot bots[2]; CpDuelResult r;
                uint32_t key = 200000u + (uint32_t)(seed + 40*(pb + N_PROFILES*pa));
                duel_setup(&s, key, &PROFILES[pa], &PROFILES[pb], 12);
                bot_init(&bots[seat], smart, key); bot_init(&bots[1-seat], BOT_IDLE, key+1);
                duel_run(&s, &bots[0], &bots[1], 900, NULL, 0, NULL, NULL, &r);
                idle_wins += r.winner == 1-seat; idle_draws += r.winner == -1;
                bot_init(&bots[seat], smart, key); bot_init(&bots[1-seat], BOT_RANDOM, key+1);
                duel_run(&s, &bots[0], &bots[1], 900, NULL, 0, NULL, NULL, &r);
                random_wins += r.winner == 1-seat; random_draws += r.winner == -1; smart_wins += r.winner == seat; n++;
            }
        printf("  canary %-7s: idle wins %d draws %d/%d, random wins %d draws %d/%d, smart wins %d/%d\n",
               bot_name(smart), idle_wins,idle_draws,n,random_wins,random_draws,n,smart_wins,n);
        CHECK(idle_wins == 0 && idle_draws == 0, "idle loses every duel on either seat; draws fail");
        CHECK((2*random_wins + random_draws)*10 < n && smart_wins*20 > n*19, "random wins <5%, scripted bot wins >95%");
    }
}

static void directional_movement(void)
{
    const int sx[8] = {1,1,0,-1,-1,-1,0,1};
    const int sy[8] = {0,-1,-1,-1,0,1,1,1};
    for (int dir = 0; dir < 8; dir++) {
        CpCombatWorld w = pair(20);
        CpCombatAction a = {CB_V_MOVE, 0, -1, (int8_t)dir, 0, 0 };
        float x = w.c[0].x, y = w.c[0].y;
        CHECK(cp_combat_order(&w, 0, &a) == CB_OK, "absolute movement order accepted");
        uint64_t ordered = cp_combat_hash(&w);
        CHECK(cp_combat_order(&w, 0, &a) == CB_OK && cp_combat_hash(&w) == ordered,
              "repeated movement is a no-op");
        cp_combat_step(&w);
        float dx = w.c[0].x-x, dy = w.c[0].y-y;
        CHECK((dx > 0) - (dx < 0) == sx[dir] && (dy > 0) - (dy < 0) == sy[dir],
              "movement uses absolute clockwise octants");
        CHECK(fabsf(sqrtf(dx*dx+dy*dy) - 0.4f) < 0.00001f,
              "diagonals walk at the same speed as axes");
        a.dir = 8;
        uint64_t before = cp_combat_hash(&w);
        CHECK(cp_combat_order(&w, 0, &a) == CB_ERR_BAD_DIR && cp_combat_hash(&w) == before,
              "invalid movement direction leaves state unchanged");
        cp_combat_idle(&w, 0); x = w.c[0].x; y = w.c[0].y;
        cp_combat_step(&w);
        CHECK(w.c[0].x == x && w.c[0].y == y, "idle stops directional walking");
    }
    CpCombatWorld w = pair(20);
    CpCombatAction a = {CB_V_MOVE, 0, -1, 0, 0, 0 };
    w.c[0].medium = CB_WATER; w.c[0].slow_t = 3;
    float x = w.c[0].x;
    cp_combat_order(&w, 0, &a); cp_combat_step(&w);
    CHECK(fabsf(w.c[0].x-x - 0.12f) < 0.00001f, "movement shares water and slow scaling");
    phase(&w.c[0], CB_BITE, CB_PH_WINDUP); x = w.c[0].x;
    cp_combat_step(&w);
    CHECK(w.c[0].x == x, "movement waits for a committed move to finish");
}

static void body_radius(void)
{
    CpCombatSetup s = {0};
    CpCombatWorld a, b;
    s.seed = 9; s.n = 2; s.flat = 1;
    cp_combat_profile_default(&s.c[0].prof);
    cp_combat_profile_default(&s.c[1].prof);
    s.c[0].x = 16; s.c[0].y = 20; s.c[0].fx = 1;
    s.c[1].x = 24; s.c[1].y = 20; s.c[1].fx = -1; s.c[1].team = 1;
    cp_combat_reset(&a, &s);
    s.c[0].prof.radius_cm = CB_RADIUS_CM; s.c[1].prof.radius_cm = CB_RADIUS_CM;
    cp_combat_reset(&b, &s);
    CHECK(cp_combat_hash(&a) == cp_combat_hash(&b), "60 cm is the default radius and is omitted from the hash");
    cp_combat_attack(&a, 0, 1, CB_BITE); cp_combat_attack(&b, 0, 1, CB_BITE);
    for (int i = 0; i < 30; i++) { cp_combat_step(&a); cp_combat_step(&b); }
    CHECK(a.c[0].x == b.c[0].x && a.c[1].hp == b.c[1].hp && cp_combat_hash(&a) == cp_combat_hash(&b),
          "explicit 60 cm stays bit-identical to the default through a fight");

    s.c[0].prof.radius_cm = 150; s.c[1].prof.radius_cm = 150;
    s.c[0].x = 20; s.c[0].y = 20; s.c[1].x = 21; s.c[1].y = 20;
    cp_combat_reset(&a, &s);
    uint64_t overlapped = cp_combat_hash(&a);
    cp_combat_step(&a);
    float dx = a.c[1].x - a.c[0].x;
    CHECK(fabsf(dx - 3.0f) < 0.001f, "150 cm bodies separate to 3 m");
    CHECK(cp_combat_hash(&a) != overlapped, "a non-default radius changes the canonical hash");

    s.c[0].x = 0.1f; s.c[0].y = 20; s.c[1].x = 30; s.c[1].y = 20;
    cp_combat_reset(&a, &s);
    CHECK(fabsf(a.c[0].x - 1.5f) < 0.001f, "spawn clamp uses the creature radius");
    s.c[0].prof.radius_cm = 0; s.c[1].prof.radius_cm = 0; s.c[0].x = 0.1f;
    cp_combat_reset(&a, &s);
    CHECK(fabsf(a.c[0].x - CB_RADIUS) < 0.0001f, "default radius keeps the 0.6 m arena clamp");
    s.c[0].prof.radius_cm = 1; s.c[1].prof.radius_cm = 900;
    cp_combat_reset(&a, &s);
    CHECK(a.c[0].prof.radius_cm == CB_RADIUS_CM_MIN && a.c[1].prof.radius_cm == CB_RADIUS_CM_MAX,
          "non-default radii clamp to 40..400 cm");
}


/* A21: loadout, known moves and cooldowns. */
static void loadout_and_cooldowns(void)
{
    CpCombatWorld w = pair(1.5f);
    CpCombatLoadout *lo = &w.c[0].lo;
    CHECK(lo->slot[0] == CB_BITE && lo->slot[1] == CB_CHARGE && lo->slot[2] == CB_SPIT && lo->slot[3] == CB_TAIL_STRIKE &&
          lo->sig_slot == -1, "default loadout is the available attack moves in table order");
    CHECK(lo->known == ((1u << CB_BITE) | (1u << CB_CHARGE) | (1u << CB_SPIT) | (1u << CB_TAIL_STRIKE)),
          "known moves are the moves whose part level is above zero");
    for (int i = 0; i < CB_CLAW_SWIPE; i++) CHECK(CP_COMBAT_MOVES[i].cooldown == 0, "every shipped move has cooldown 0");
    CHECK(CP_COMBAT_MOVES[CB_FLAME].cooldown == 60, "the flame has a 60 tick cooldown");
    CHECK(CP_COMBAT_MOVES[CB_TAIL_STRIKE].role == CB_ROLE_CONTROL && CP_COMBAT_MOVES[CB_DODGE].role == CB_ROLE_DEFENCE,
          "moves carry a role");

    uint64_t h0 = cp_combat_hash(&w);
    CpCombatLoadout copy = *lo;
    CHECK(cp_combat_loadout_set(&copy, 0, CB_BITE) == CB_OK && cp_combat_loadout_is_default(&copy, &w.c[0].prof),
          "slotting the move already in that slot keeps the default (and the hash)");
    CHECK(cp_combat_loadout_set(&copy, 4, CB_BITE) == CB_ERR_BAD_SLOT && cp_combat_loadout_set(&copy, -1, CB_BITE) == CB_ERR_BAD_SLOT,
          "slot must be 0..3");
    CHECK(cp_combat_loadout_set(&copy, 0, CB_GUARD) == CB_ERR_UNKNOWN_MOVE && cp_combat_loadout_set(&copy, 0, CB_DODGE) == CB_ERR_UNKNOWN_MOVE &&
          cp_combat_loadout_set(&copy, 0, 99) == CB_ERR_UNKNOWN_MOVE && cp_combat_loadout_set(&copy, 0, -5) == CB_ERR_UNKNOWN_MOVE,
          "guard, dodge and unknown ids never go in a slot");
    copy.known &= (uint16_t)~(1u << CB_SPIT);
    CHECK(cp_combat_loadout_set(&copy, 0, CB_SPIT) == CB_ERR_NOT_KNOWN, "a move that is not known cannot be slotted");
    copy.known |= (uint16_t)(1u << CB_SPIT);
    copy.sig_slot = 3;
    CHECK(cp_combat_loadout_set(&copy, 3, CB_BITE) == CB_ERR_BAD_SLOT, "the signature slot holds only signature moves");

    /* equipped / not_equipped */
    CpCombatLoadout before = *lo;
    CHECK(cp_combat_loadout_set(lo, 1, CB_MOVE_NONE) == CB_OK && lo->slot[1] == CB_MOVE_NONE, "a slot can be emptied");
    CHECK(cp_combat_attack(&w, 0, 1, CB_CHARGE) == CB_ERR_NOT_EQUIPPED, "an attack with a move outside the loadout is not_equipped");
    CHECK(w.c[0].verb == CB_V_IDLE, "the rejected attack changed nothing");
    CHECK(cp_combat_hash(&w) != h0, "a changed loadout changes the hash");
    CHECK(cp_combat_loadout_set(lo, 3, CB_CHARGE) == CB_OK && lo->slot[3] == CB_CHARGE && lo->slot[1] == CB_MOVE_NONE,
          "slotting a move into another slot moves it");
    CHECK(cp_combat_attack(&w, 0, 1, CB_TAIL_STRIKE) == CB_ERR_NOT_EQUIPPED, "the displaced move is not equipped any more");
    *lo = before;
    CHECK(cp_combat_hash(&w) == h0, "restoring the default loadout restores the hash");
    CHECK(cp_combat_attack(&w, 0, 1, CB_CHARGE) == CB_OK, "an equipped move is accepted");

    /* cooldown ticks deterministically */
    w = pair(1.5f);
    cp_combat_test_cooldown(CB_BITE, 30);
    CHECK(cp_combat_attack(&w, 0, 1, CB_BITE) == CB_OK, "a ready move is accepted");
    int started = -1;
    for (int t = 0; t < 12 && started < 0; t++) { cp_combat_step(&w); if (w.c[0].cd[CB_BITE]) started = t; }
    CHECK(started >= 0 && w.c[0].cd[CB_BITE] == 29, "the cooldown starts when the move starts and counts down that tick");
    CHECK(cp_combat_cooldown_left(&w.c[0], CB_BITE) == 29 && cp_combat_cooldown_left(&w.c[0], CB_SPIT) == 0, "cooldown_left reads the counter");
    CHECK(cp_combat_attack(&w, 0, 1, CB_BITE) == CB_ERR_ON_COOLDOWN, "a move on cooldown is on_cooldown");
    CHECK(cp_combat_attack(&w, 0, 1, CB_CHARGE) == CB_OK, "other moves are unaffected by a cooldown");
    CpCombatWorld fork = w;
    uint64_t hh = cp_combat_hash(&w);
    CpCombatWorld fresh = pair(1.5f);
    CHECK(hh != cp_combat_hash(&fresh), "a running cooldown is part of the hash");
    for (int t = 0; t < 29; t++) {
        cp_combat_step(&w);
        CHECK(w.c[0].cd[CB_BITE] == 28 - t, "cooldown drops by one per tick");
    }
    CHECK(w.c[0].cd[CB_BITE] == 0 && cp_combat_attack(&w, 0, 1, CB_BITE) == CB_OK, "the move is accepted again when the counter is 0");
    for (int t = 0; t < 29; t++) cp_combat_step(&fork);          /* a struct copy mid-cooldown continues identically */
    CHECK(cp_combat_hash(&fork) != 0 && fork.c[0].cd[CB_BITE] == 0, "a copy made during a cooldown finishes it");
    /* a standing attack on a recharging move waits instead of firing */
    w = pair(1.5f);
    cp_combat_attack(&w, 0, 1, CB_BITE);
    w.c[0].cd[CB_BITE] = 6; w.c[0].stamina = 100;
    for (int t = 0; t < 5; t++) cp_combat_step(&w);
    CHECK(w.c[0].move == CB_MOVE_NONE && w.c[0].verb == CB_V_ATTACK, "a standing attack holds while its move recharges");
    cp_combat_test_cooldown(CB_BITE, -1);
    CHECK(CP_COMBAT_MOVES[CB_BITE].cooldown == 0, "the test override leaves the table alone");

    /* determinism with loadout changes in a replay */
    uint64_t ha[2];
    for (int run = 0; run < 2; run++) {
        CpCombatWorld a = pair(6.0f);
        for (int t = 0; t < 200; t++) {
            if (t == 3) cp_combat_loadout_set(&a.c[0].lo, 0, CB_MOVE_NONE);
            if (t == 7) cp_combat_loadout_set(&a.c[0].lo, 1, CB_BITE);
            if (t % 5 == 0) { cp_combat_attack(&a, 0, 1, t % 2 ? CB_BITE : CB_SPIT); cp_combat_attack(&a, 1, 0, CB_CHARGE); }
            cp_combat_step(&a);
        }
        ha[run] = cp_combat_hash(&a);
    }
    CHECK(ha[0] == ha[1], "the same loadout changes and orders replay to the same hash");
}

/* A65: the peck is a galloping strike with a run-up; inside the run-up distance it is the standing bite; right after a connected
 * move it is a standing jab (the A64 chain). Strong opener: a cooldown. */
static CpCombatWorld beaked(float dist)
{
    CpCombatWorld w = pair(dist);
    w.c[0].prof.extra[1] = 2;
    cp_combat_loadout_default(&w.c[0].lo, &w.c[0].prof);
    cp_combat_loadout_set(&w.c[0].lo, 2, CB_PECK);
    return w;
}
static void galloping_peck(void)
{
    cp_combat_test_hit_variance(1);
    CpCombatWorld w = beaked(4.2f);
    CHECK(CP_COMBAT_MOVES[CB_PECK].flags & CB_F_DASH, "peck is a dash move");
    float x0 = w.c[0].x, hp0 = w.c[1].hp;
    CHECK(cp_combat_attack(&w, 0, 1, CB_PECK) == 0, "peck order accepted");
    int hit_tick = -1;
    for (int t = 0; t < 30 && hit_tick < 0; t++) {
        cp_combat_attack(&w, 0, 1, CB_PECK);
        cp_combat_step(&w);
        if (w.c[1].hp < hp0) hit_tick = t;
    }
    CHECK(hit_tick >= 0 && w.c[0].move == CB_PECK, "peck from range closes the distance and hits");
    CHECK(w.c[0].x - x0 > 1.0f, "the galloping peck moved the attacker");
    CHECK(hp0 - w.c[1].hp > 10.0f, "the galloping peck is a strong opener (14 damage)");
    CHECK(w.c[0].cd[CB_PECK] > 0, "the galloping peck starts its cooldown");
    w = beaked(1.6f);
    cp_combat_attack(&w, 0, 1, CB_PECK);
    cp_combat_step(&w);
    CHECK(w.c[0].move == CB_BITE, "inside the run-up distance the peck order becomes the standing bite");
    /* chain: a connected bite, then the peck order within the window is a standing jab at half damage and spends no cooldown */
    w = beaked(1.6f);
    cp_combat_attack(&w, 0, 1, CB_BITE);
    steps(&w, CP_COMBAT_MOVES[CB_BITE].windup + CP_COMBAT_MOVES[CB_BITE].active);
    float hp1 = w.c[1].hp;
    steps(&w, CP_COMBAT_MOVES[CB_BITE].recovery);
    cp_combat_attack(&w, 0, 1, CB_PECK);
    float xj = w.c[0].x;
    int jab = 0;
    float jab_dmg = 0.0f;
    for (int t = 0; t < 12; t++) {
        cp_combat_attack(&w, 0, 1, CB_PECK);
        cp_combat_step(&w);
        if (w.c[0].move == CB_PECK && w.c[0].dash_x == 0.0f) jab = 1;
        for (int e = 0; e < w.n_ev; e++) if (w.ev[e].type == CB_EV_HIT && w.ev[e].move == CB_PECK) jab_dmg = w.ev[e].amount;
    }
    CHECK(jab, "a peck right after a connected bite is a standing jab (no dash)");
    CHECK(fabsf(w.c[0].x - xj) < 0.01f && jab_dmg > 0.0f && jab_dmg < 10.0f && w.c[0].cd[CB_PECK] == 0, "the jab hits for reduced damage in place and keeps the cooldown free");
}

/* ---- A72/A74 context attacks: bands, momentum, projectiles, roar ---- */
static CpCombatWorld ctxpair(float dist, float speed)
{
    CpCombatWorld w = pair(dist);
    w.c[0].prof.extra[2] = 2;           /* legs: pounce */
    w.c[0].prof.extra[4] = 2;           /* throat: roar */
    cp_combat_loadout_starter(&w.c[0].lo, &w.c[0].prof);
    cp_combat_ctx_enable(&w, 0, speed);
    return w;
}
static float hit_amount(const CpCombatWorld *w, int move)
{
    for (int e = 0; e < w->n_ev; e++) if (w->ev[e].type == CB_EV_HIT && w->ev[e].move == move && w->ev[e].a == 0) return w->ev[e].amount;
    return 0.0f;
}
static void context_attacks(void)
{
    cp_combat_test_hit_variance(1);
    /* the starting loadout (A62): bite, pounce, spit, roar, with no dodge slot */
    CpCombatWorld w = ctxpair(2.0f, 0.0f);
    CHECK(w.c[0].lo.slot[0] == CB_BITE && w.c[0].lo.slot[1] == CB_POUNCE && w.c[0].lo.slot[2] == CB_SPIT && w.c[0].lo.slot[3] == CB_ROAR,
          "the starter loadout is bite, pounce, spit, roar");
    CHECK(cp_combat_loadout_slot_of(&w.c[0].lo, CB_DODGE) < 0, "dodge is a universal key, not a slot");

    /* bands and speed pick the context: close/mid standing, walking, galloping (>= canter band), far */
    float canter = cp_combat_canter_speed(&w.c[0]);
    CHECK(canter > 1.0f && canter < 2.0f, "canter band of the default body is about 1.3 m/s");
    CHECK(cp_combat_band(2.9f) == CB_BAND_CLOSE && cp_combat_band(3.0f) == CB_BAND_MID && cp_combat_band(4.9f) == CB_BAND_MID && cp_combat_band(5.0f) == CB_BAND_FAR,
          "bands: close < 3 m, mid 3-5 m, far from 5 m");
    CHECK(cp_combat_pick_ctx(&w, 0, 1) == CB_CTX_STAND, "standing close picks the standing variant");
    w.c[0].spd = 0.8f;  CHECK(cp_combat_pick_ctx(&w, 0, 1) == CB_CTX_WALK, "slow movement picks the walking variant");
    w.c[0].spd = canter + 0.01f; CHECK(cp_combat_pick_ctx(&w, 0, 1) == CB_CTX_GALLOP, "speed at the canter band picks the gallop variant");
    w = ctxpair(4.6f, 0.0f);   /* gap 4.0: mid band, still the speed variant */
    CHECK(cp_combat_pick_ctx(&w, 0, 1) == CB_CTX_STAND, "the mid band keeps the speed variant");
    w = ctxpair(9.0f, 3.0f);
    CHECK(cp_combat_pick_ctx(&w, 0, 1) == CB_CTX_FAR, "the far band wins over speed");

    /* momentum: a bite on the run hits harder and knocks back further than the standing bite, keeps moving, and overshoots */
    CpCombatWorld st = ctxpair(2.2f, 0.0f), rn = ctxpair(2.4f, 3.5f);
    cp_combat_attack(&st, 0, 1, CB_BITE); cp_combat_attack(&rn, 0, 1, CB_BITE);
    CHECK(rn.c[0].vctx == CB_CTX_GALLOP && st.c[0].vctx == CB_CTX_STAND, "the order stores the picked context");
    float xs = st.c[0].x, xr = rn.c[0].x, dst = 0, drn = 0, kbr = 0, kbs = 0;
    int moved_in_move = 0;
    for (int t = 0; t < 8; t++) {
        cp_combat_step(&st); cp_combat_step(&rn);
        if (hit_amount(&st, CB_BITE) > 0) { dst = hit_amount(&st, CB_BITE); kbs = st.c[1].kbx; }
        if (hit_amount(&rn, CB_BITE) > 0) { drn = hit_amount(&rn, CB_BITE); kbr = rn.c[1].kbx; }
        if (rn.c[0].move == CB_BITE && rn.c[0].x - xr > 0.4f) moved_in_move = 1;
    }
    CHECK(dst > 0 && drn > dst * 1.2f, "a bite at speed deals at least 20% more (momentum)");
    CHECK(kbr > kbs && kbs > 0 && kbr <= CB_KB_MAX + 0.01f, "knockback grows with the closing speed and is capped");
    CHECK(moved_in_move, "a moving bite keeps the body moving while it plays");
    {   /* no stutter: the launch tick of a moving attack keeps the body moving */
        CpCombatWorld m = ctxpair(4.2f, 2.5f);
        cp_combat_attack(&m, 0, 1, CB_BITE);
        float minspd = 99.0f;
        for (int t = 0; t < 12; t++) { cp_combat_step(&m); if (m.c[0].move == CB_BITE && m.c[0].spd < minspd) minspd = m.c[0].spd; }
        CHECK(minspd > 1.5f, "a moving attack does not stop on its launch tick");
    }
    CHECK(fabsf(st.c[0].x - xs) < 0.01f, "a standing bite does not move the body");
    {   /* overshoot after a moving hit, and a longer exposure after a miss (the target steps out of reach once the bite has started) */
        CpCombatWorld hit = ctxpair(2.4f, 3.5f), miss = ctxpair(2.4f, 3.5f);
        cp_combat_attack(&hit, 0, 1, CB_BITE); cp_combat_attack(&miss, 0, 1, CB_BITE);
        int over_hit = 0, over_miss = 0, moved = 0;
        for (int t = 0; t < 16; t++) {
            cp_combat_step(&hit); cp_combat_step(&miss);
            if (!moved && miss.c[0].move == CB_BITE) { moved = 1; miss.c[1].x += 6.0f; }
            if (hit.c[0].over_t > over_hit) over_hit = hit.c[0].over_t;
            if (miss.c[0].over_t > over_miss) over_miss = miss.c[0].over_t;
        }
        CHECK(hit.c[0].hits == 1 && miss.c[0].hits == 0, "the bite connects in one run and misses in the other");
        CHECK(over_hit >= CB_OVER_HIT - 1 && over_hit <= CB_OVER_HIT, "a moving bite that connects overshoots for about CB_OVER_HIT ticks");
        CHECK(over_miss >= CB_OVER_MISS - 1 && over_miss > over_hit, "a miss on the run leaves the creature exposed longer");
    }
    {   /* the wide turn: with overshoot the turn per tick is half */
        CpCombatWorld a = ctxpair(2.0f, 0.0f);
        a.c[0].fx = 1; a.c[0].fy = 0;
        a.c[0].over_t = 5; a.c[0].verb = CB_V_IDLE;
        float tx = 0.0f, ty = 1.0f;
        CpCombatWorld b = a; b.c[0].over_t = 0;
        (void)tx; (void)ty;
        cp_combat_order(&a, 0, &(CpCombatAction){ CB_V_MOVE, 0, 0, 6, 0, 0, 0 });
        cp_combat_order(&b, 0, &(CpCombatAction){ CB_V_MOVE, 0, 0, 6, 0, 0, 0 });
        cp_combat_step(&a); cp_combat_step(&b);
        CHECK(a.c[0].fy > 0 && a.c[0].fy < b.c[0].fy * 0.6f, "the wide turn after a moving attack is slower than the normal turn");
    }

    /* far bite = charge: a run-in at 1.25x walk speed, the hit carries the momentum, both recoil */
    w = ctxpair(10.0f, 0.0f);
    cp_combat_attack(&w, 0, 1, CB_BITE);
    CHECK(w.c[0].vctx == CB_CTX_FAR, "a bite from far is the charge");
    float maxv = 0, charge_dmg = 0, recoil = 0;
    for (int t = 0; t < 40; t++) {
        cp_combat_attack(&w, 0, 1, CB_BITE);
        cp_combat_step(&w);
        if (w.c[0].spd > maxv) maxv = w.c[0].spd;
        if (hit_amount(&w, CB_BITE) > 0) { charge_dmg = hit_amount(&w, CB_BITE); recoil = w.c[0].kbx; break; }
    }
    CHECK(maxv > w.c[0].prof.speed * 1.2f && maxv < w.c[0].prof.speed * 1.3f, "the charge run-in is a burst (x1.25 walk speed)");
    CHECK(charge_dmg > dst * 1.25f, "the charge hits with the run-up momentum");
    CHECK(recoil < 0 && w.c[1].kbx > 0, "the charge recoils both bodies");

    /* spit: damage lands when the projectile arrives, not at the press; the shot leads a moving target */
    w = ctxpair(7.0f, 0.0f);
    float hp0 = w.c[1].hp;
    cp_combat_attack(&w, 0, 1, CB_SPIT);
    CHECK(w.c[0].vctx == CB_CTX_FAR, "spit from 6.4 m gap picks the far lob");
    int fired = -1, landed = -1, flight = 0;
    for (int t = 0; t < 60 && landed < 0; t++) {
        cp_combat_attack(&w, 0, 1, CB_SPIT);
        cp_combat_step(&w);
        if (fired < 0 && event(&w, CB_EV_PROJECTILE)) { fired = t; for (int e = 0; e < w.n_ev; e++) if (w.ev[e].type == CB_EV_PROJECTILE) flight = (int)w.ev[e].amount; }
        if (landed < 0 && w.c[1].hp < hp0) landed = t;
    }
    CHECK(fired >= 0 && landed == fired + flight && flight == 11, "the lob lands exactly its flight time (11 ticks) after it is fired");
    {
        CpCombatWorld m = ctxpair(5.5f, 0.0f);   /* gap 4.9: close/mid, the cobra jet */
        float hpm = m.c[1].hp;
        m.c[1].verb = CB_V_MOVE; m.c[1].verb_dir = -1; m.c[1].heading_y = 1; m.c[1].heading_x = 0;
        cp_combat_attack(&m, 0, 1, CB_SPIT);
        CHECK(m.c[0].vctx == CB_CTX_STAND, "a jet from the mid band standing");
        float ty0 = m.c[1].y, aim_y = 0;
        int fire = -1, hit = -1;
        for (int t = 0; t < 40 && hit < 0; t++) {
            cp_combat_attack(&m, 0, 1, CB_SPIT);
            cp_combat_step(&m);
            if (fire < 0 && event(&m, CB_EV_PROJECTILE)) { fire = t; for (int k = 0; k < CB_MAX_PROJ; k++) if (m.proj[k].alive) aim_y = m.proj[k].y; }
            if (m.c[1].hp < hpm) hit = t;
        }
        CHECK(fire >= 0 && aim_y > m.c[1].y - 4.0f && aim_y > ty0 + 0.3f, "the shot aims ahead of a target that is walking away sideways (leading)");
        CHECK(hit > fire, "the shot hits the moving target on arrival");
    }
    {   /* a dodge in time avoids the arriving shot; hold = the charged glob hits harder */
        CpCombatWorld j = ctxpair(4.0f, 0.0f), g = ctxpair(4.0f, 0.0f);
        cp_combat_attack(&j, 0, 1, CB_SPIT);
        cp_combat_attack_hold(&g, 0, 1, CB_SPIT, 1);
        float dj = 0, dg = 0;
        for (int t = 0; t < 40; t++) {
            cp_combat_step(&j); cp_combat_step(&g);
            if (hit_amount(&j, CB_SPIT) > 0) dj = hit_amount(&j, CB_SPIT);
            if (hit_amount(&g, CB_SPIT) > 0) dg = hit_amount(&g, CB_SPIT);
        }
        CHECK(dj > 0 && dg > dj * 1.6f, "the held spit is a glob that hits about 1.8x harder");
        CHECK(g.c[1].slow_t >= j.c[1].slow_t, "the glob slows at least as long");
    }

    /* pounce: the gather shortens as the body already moves */
    w = ctxpair(4.0f, 3.5f);
    cp_combat_attack(&w, 0, 1, CB_POUNCE);
    for (int t = 0; t < 6 && w.c[0].move != CB_POUNCE; t++) cp_combat_step(&w);
    CHECK(w.c[0].move == CB_POUNCE && w.c[0].plen == 3, "a leap from the gallop gathers for 3 ticks");
    w = ctxpair(4.0f, 0.0f);
    cp_combat_attack(&w, 0, 1, CB_POUNCE);
    for (int t = 0; t < 6 && w.c[0].move != CB_POUNCE; t++) cp_combat_step(&w);
    CHECK(w.c[0].move == CB_POUNCE && w.c[0].plen == CP_COMBAT_MOVES[CB_POUNCE].windup, "the standing cat pounce keeps the full gather");

    /* roar: fear in the radius, none outside; far = run in then plant */
    w = ctxpair(3.6f, 0.0f);   /* gap 3.0 */
    cp_combat_attack(&w, 0, 1, CB_ROAR);
    {
        CpCombatWorld r = ctxpair(3.6f, 0.0f);
        cp_combat_attack(&r, 0, 1, CB_ROAR);
        int feared = 0;
        for (int t = 0; t < 14; t++) { cp_combat_step(&r); if (r.c[1].fear_t > 0) feared = 1; }
        CHECK(feared, "a roar frightens a target inside its 4 m radius");
        CpCombatWorld f = ctxpair(10.0f, 0.0f);
        cp_combat_attack(&f, 0, 1, CB_ROAR);
        CHECK(f.c[0].vctx == CB_CTX_FAR, "a roar from far runs in");
        int fear_far = 0, planted = 0; float x0 = f.c[0].x;
        for (int t = 0; t < 40; t++) {
            cp_combat_attack(&f, 0, 1, CB_ROAR);
            cp_combat_step(&f);
            if (f.c[1].fear_t > 0) fear_far = 1;
            if (f.c[0].move == CB_ROAR && f.c[0].spd < 0.01f) planted = 1;
        }
        CHECK(fear_far && planted && f.c[0].x - x0 > 3.0f, "far roar: run in, plant, rear, the target is afraid");
        /* a wildcard counter still holds: out of the radius nobody is afraid */
        CpCombatWorld o = ctxpair(3.6f, 0.0f);
        o.c[1].x += 3.0f;
        phase(&o.c[0], CB_ROAR, CB_PH_ACTIVE);
        cp_combat_step(&o);
        CHECK(o.c[1].fear_t == 0, "outside the 4 m radius there is no fear");
    }

    /* deterministic: the same orders give the same hashes, with the new state hashed */
    CpCombatWorld a = ctxpair(10.0f, 0.0f), b = ctxpair(10.0f, 0.0f);
    uint64_t ha = 0, hb = 0;
    for (int t = 0; t < 60; t++) { cp_combat_attack_hold(&a, 0, 1, CB_SPIT, t > 5); cp_combat_attack_hold(&b, 0, 1, CB_SPIT, t > 5); ha = cp_combat_step(&a); hb = cp_combat_step(&b); }
    CHECK(ha == hb && ha != 0, "context attacks are deterministic");
    /* opt-in: a plain creature is untouched (no variant, no knockback) */
    w = pair(2.0f);
    cp_combat_attack(&w, 0, 1, CB_BITE);
    steps(&w, 8);
    CHECK(w.c[0].vctx == 0 && w.c[1].kbx == 0.0f, "without ctx_on nothing changes");
    cp_combat_test_hit_variance(0);
}

int main(void)
{
    puts("cpore combat tests");
    directional_movement(); counters(); ripostes(); spacing(); ranged_exchanges(); simultaneous(); bot_counters(); defensive_policies(); edges_and_verbs(); geometry_and_setup(); body_radius(); loadout_and_cooldowns(); galloping_peck(); context_attacks(); determinism(); canaries();
    printf("combat: %d failure(s)\n", fails);
    return fails ? 1 : 0;
}
