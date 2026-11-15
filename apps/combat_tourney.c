/* Scripted-bot tournament for the combat core (DESIGN.md P2 acceptance).
 *
 *   combat_tourney [seeds_per_cell] [payoff_duels]
 *
 * Prints: the move-vs-move payoff matrix, a weak-dominance check on it, the
 * strategy round-robin with an Elo table, the build (profile) win rates and
 * their ceiling check, and the canaries. Exits 1 if any check fails.
 * Everything is deterministic: same arguments, same output. */
#include "combat_bots.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NS 4                                   /* idle, random, greedy, counter */
static const int STRAT[NS] = { BOT_IDLE, BOT_RANDOM, BOT_GREEDY, BOT_COUNTER };

#define BUILD_CEILING 0.65                     /* max build win rate (assumed ceiling) */
#define DUEL_TICKS    900                      /* 90 s */
#define START_DIST    12.0f

static int fails = 0;
static void check(int ok, const char *msg)
{
    printf("  %s  %s\n", ok ? "PASS" : "FAIL", msg);
    if (!ok) fails++;
}

/* ---------------- payoff matrix: fixed move vs fixed move ---------------- */
/* Mean level-3 offensive HP (including a fresh bleed's future ticks) bought
 * per start-stamina point. Derived from move data, never fitted to dominance. */
static double stamina_value;
static double move_stamina_value(const CpCombatProfile *p)
{
    double total = 0; int n = 0;
    for (int m = 0; m < CB_MOVE_COUNT; m++) {
        if (CP_COMBAT_MOVES[m].flags & CB_F_SELF) continue;
        double damage = cp_combat_move_damage(p, m);
        if (CP_COMBAT_MOVES[m].status == CB_ST_BLEED)
            damage += 0.6 * (CP_COMBAT_MOVES[m].status_ticks - 1);
        double rate = damage / cp_combat_move_stamina(p, m);
        total += rate; n++;
    }
    return total / n;
}
static double payoff[CB_MOVE_COUNT][CB_MOVE_COUNT];     /* raw hp margin            */
static double payoff_se[CB_MOVE_COUNT][CB_MOVE_COUNT];
static double payr[CB_MOVE_COUNT][CB_MOVE_COUNT];       /* resource-adjusted        */
static double payr_se[CB_MOVE_COUNT][CB_MOVE_COUNT];

static void compute_payoff(int duels)
{
    CpCombatProfile p;                     /* neutral: every part level 3 */
    p.mouth = p.charge = p.spit = p.tail = p.guard = 3;
    p.hp = 100000.0f; p.stamina = 100.0f; p.speed = 4.0f; p.radius_cm = 0; /* default radius */

    stamina_value = move_stamina_value(&p);
    for (int a = 0; a < CB_MOVE_COUNT; a++)
        for (int b = 0; b < CB_MOVE_COUNT; b++) {
            double sum = 0.0, sq = 0.0, sumr = 0.0, sqr = 0.0;
            double pair_v = 0, pair_r = 0;
            for (int s = 0; s < duels; s++) {
                CpCombatSetup su;
                duel_setup(&su, 1000u + (uint32_t)(s/2), &p, &p, 7.0f);
                CpBot b0, b1;
                bot_init(&b0, BOT_SPAM, (uint32_t)s); b0.spam_move = s%2 ? b : a; b0.delay = (s/2) % 4;
                bot_init(&b1, BOT_SPAM, (uint32_t)s + 7777u); b1.spam_move = s%2 ? a : b; b1.delay = (s/8) % 7;
                /* Timed reads are averaged over reaction delays 0..3, the
                 * span the wind-ups are budgeted for; both seats share one. */
                b0.reaction = b1.reaction = (s/8) % 4;
                CpDuelResult r;
                duel_run(&su, &b0, &b1, 120, NULL, 0, NULL, NULL, &r);
                int row = s%2, col = 1-row;
                double v = (double)r.dealt[row] - (double)r.dealt[col];
                double vr = v - stamina_value * ((double)r.spent[row] - (double)r.spent[col]);
                if (s%2 == 0) { pair_v = v; pair_r = vr; }
                else {
                    /* The two seats share a seed. Estimate uncertainty from
                     * independent paired scenarios, not individual seats. */
                    double pv = (pair_v + v)*0.5, pr = (pair_r + vr)*0.5;
                    sum += pv; sq += pv*pv; sumr += pr; sqr += pr*pr;
                }
            }
            int pairs = duels/2;
            double m = sum / pairs, var = sq / pairs - m * m;
            payoff[a][b] = m;
            payoff_se[a][b] = pairs > 1 ? sqrt((var > 0 ? var : 0) / (pairs-1)) : 0;
            double mr = sumr / pairs, varr = sqr / pairs - mr * mr;
            payr[a][b] = mr;
            payr_se[a][b] = pairs > 1 ? sqrt((varr > 0 ? varr : 0) / (pairs-1)) : 0;
        }
}

/* Zero-sum value and the row player's equilibrium mix by regret matching. */
static void solve_game(double P[CB_MOVE_COUNT][CB_MOVE_COUNT], double *value, double mix[CB_MOVE_COUNT])
{
    double rr[CB_MOVE_COUNT] = { 0 }, cr[CB_MOVE_COUNT] = { 0 };
    double rs[CB_MOVE_COUNT] = { 0 };
    double rsum = 0.0;
    const int iters = 200000;
    for (int it = 0; it < iters; it++) {
        double rp[CB_MOVE_COUNT], cp_[CB_MOVE_COUNT], rt = 0, ct = 0;
        for (int i = 0; i < CB_MOVE_COUNT; i++) {
            rp[i] = rr[i] > 0 ? rr[i] : 0; rt += rp[i];
            cp_[i] = cr[i] > 0 ? cr[i] : 0; ct += cp_[i];
        }
        for (int i = 0; i < CB_MOVE_COUNT; i++) {
            rp[i] = rt > 0 ? rp[i] / rt : 1.0 / CB_MOVE_COUNT;
            cp_[i] = ct > 0 ? cp_[i] / ct : 1.0 / CB_MOVE_COUNT;
        }
        double ru[CB_MOVE_COUNT], cu[CB_MOVE_COUNT], v = 0;
        for (int i = 0; i < CB_MOVE_COUNT; i++) {
            ru[i] = cu[i] = 0;
            for (int j = 0; j < CB_MOVE_COUNT; j++) { ru[i] += P[i][j] * cp_[j]; cu[i] += -P[j][i] * rp[j]; }
        }
        for (int i = 0; i < CB_MOVE_COUNT; i++) v += rp[i] * ru[i];
        double cv = 0;
        for (int i = 0; i < CB_MOVE_COUNT; i++) cv += cp_[i] * cu[i];
        for (int i = 0; i < CB_MOVE_COUNT; i++) { rr[i] += ru[i] - v; cr[i] += cu[i] - cv; rs[i] += rp[i]; }
        rsum += 1.0;
    }
    double v = 0;
    for (int i = 0; i < CB_MOVE_COUNT; i++) mix[i] = rs[i] / rsum;
    for (int i = 0; i < CB_MOVE_COUNT; i++)
        for (int j = 0; j < CB_MOVE_COUNT; j++) v += mix[i] * mix[j] * P[i][j];
    *value = v;
}

/* A weakly dominates B: >= everywhere (within noise tol), > somewhere (beyond tol). */
static int dominates(double (*P)[CB_MOVE_COUNT], double (*SE)[CB_MOVE_COUNT], int a, int b)
{
    int strict = 0;
    for (int j = 0; j < CB_MOVE_COUNT; j++) {
        double tol = 2.0 * (SE[a][j] > SE[b][j] ? SE[a][j] : SE[b][j]) + 0.5;
        if (P[a][j] < P[b][j] - tol) return 0;
        if (P[a][j] > P[b][j] + tol) strict = 1;
    }
    return strict;
}

static void print_matrix(double (*P)[CB_MOVE_COUNT])
{
    printf("%-12s", "row \\ col");
    for (int b = 0; b < CB_MOVE_COUNT; b++) printf("%12s", cp_combat_move_name(b));
    printf("%12s\n", "row mean");
    for (int a = 0; a < CB_MOVE_COUNT; a++) {
        printf("%-12s", cp_combat_move_name(a));
        double m = 0;
        for (int b = 0; b < CB_MOVE_COUNT; b++) { printf("%12.2f", P[a][b]); m += P[a][b]; }
        printf("%12.2f\n", m / CB_MOVE_COUNT);
    }
}

static int dominance(double (*P)[CB_MOVE_COUNT], double (*SE)[CB_MOVE_COUNT])
{
    int any = 0;
    for (int a = 0; a < CB_MOVE_COUNT; a++)
        for (int b = 0; b < CB_MOVE_COUNT; b++) {
            if (a == b || !dominates(P, SE, a, b)) continue;
            printf("   %s weakly dominates %s\n", cp_combat_move_name(a), cp_combat_move_name(b));
            any = 1;
        }
    if (!any) printf("   no move weakly dominates any other\n");
    return any;
}

/* Ignore regret-matching initialization dust: a move must hold at least
 * one percent of the average strategy to count toward the four-move gate. */
static int equilibrium_support(const double mix[CB_MOVE_COUNT])
{
    int n = 0;
    for (int m = 0; m < CB_MOVE_COUNT; m++) n += mix[m] >= 0.01;
    return n;
}

static void report_payoff(int duels)
{
    printf("== Move-vs-move payoff, %d duels per cell: move policies, 7 m apart,\n", duels);
    printf("   paired seats and start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)\n");
    printf("   guard takes an earned bite riposte; ranged moves retreat and sidestep walls; dodge repeats\n\n");
    printf("-- raw: row's damage dealt minus column's (hp)\n");
    print_matrix(payoff);
    printf("\n-- resource-adjusted: raw minus %.6f hp per stamina point the row spent, plus the same for the column\n",
           stamina_value);
    print_matrix(payr);

    printf("\n== Dominance check (tolerance 2*SE + 0.5 hp)\n");
    printf("-- raw matrix (acceptance gate)\n");
    int raw_dominant = dominance(payoff, payoff_se);
    printf("-- resource-adjusted matrix (acceptance gate)\n");
    int resource_dominant = dominance(payr, payr_se);
    for (int r = 0; r < 2; r++) {
        double value, mix[CB_MOVE_COUNT];
        solve_game(r ? payr : payoff, &value, mix);
        printf("   %s equilibrium mix (regret matching, 200k iters), game value %.2f:", r ? "resource" : "raw", value);
        for (int a = 0; a < CB_MOVE_COUNT; a++) printf("  %s %.1f%%", cp_combat_move_name(a), mix[a] * 100.0);
        printf("\n");
        int support = equilibrium_support(mix);
        char msg[160];
        snprintf(msg, sizeof msg, "%s equilibrium uses >=4 moves at >=1%% weight (observed %d/6)",
                 r ? "resource" : "raw", support);
        check(support >= 4, msg);
    }
    check(!raw_dominant, "no move weakly dominates another (raw damage payoff)");
    check(!resource_dominant, "no move weakly dominates another (resource-adjusted payoff)");
}

/* ---------------- strategy round robin ---------------- */
typedef struct { double wins, games, draws; } Tally;
static Tally strat[NS][NS];           /* [a][b]: a's score against b (draw = 0.5) */
/* All nine ordered random/greedy/counter pairings; each duel enters both
 * seat perspectives so pooled build scores are complementary. */
static Tally build[N_PROFILES][N_PROFILES][3][3];
static void tally(Tally *t, double score)
{
    t->wins += score; t->games++;
    t->draws += score == 0.5;
}
static void record_build(int sa, int sb, int pa, int pb, double score)
{
    if (sa == 0 || sb == 0) return;
    tally(&build[pa][pb][sa-1][sb-1], score);
    tally(&build[pb][pa][sb-1][sa-1], 1-score);
}

static void play(int sa, int sb, int pa, int pb, uint32_t seed, double *score_a)
{
    CpCombatSetup su;
    duel_setup(&su, seed, &PROFILES[pa], &PROFILES[pb], START_DIST);
    CpBot b0, b1;
    bot_init(&b0, STRAT[sa], seed * 3u + 1u);
    bot_init(&b1, STRAT[sb], seed * 5u + 2u);
    CpDuelResult r;
    duel_run(&su, &b0, &b1, DUEL_TICKS, NULL, 0, NULL, NULL, &r);
    *score_a = r.winner == 0 ? 1.0 : (r.winner == 1 ? 0.0 : 0.5);
}

static void round_robin(int seeds)
{
    uint32_t seed = 5000;
    for (int sa = 0; sa < NS; sa++)
        for (int sb = 0; sb < NS; sb++)
            for (int pa = 0; pa < N_PROFILES; pa++)
                for (int pb = 0; pb < N_PROFILES; pb++)
                    for (int k = 0; k < seeds; k++) {
                        double s;
                        seed++;
                        play(sa, sb, pa, pb, seed, &s);
                        tally(&strat[sa][sb], s);
                        record_build(sa, sb, pa, pb, s);
                    }
}

/* Elo as a maximum-likelihood (Bradley-Terry) fit on pooled pair scores, with one
 * pseudo-game (half a win each way) per pair so that a 100 % record stays finite.
 * Anchored to a mean of 1000. */
static void elo_fit(int n, const double *wins, const double *games, double *rating)
{
    for (int i = 0; i < n; i++) rating[i] = 1000.0;
    for (int it = 0; it < 20000; it++) {
        double g[16];
        for (int i = 0; i < n; i++) {
            g[i] = 0;
            for (int j = 0; j < n; j++) {
                if (i == j) continue;
                double ng = games[i * n + j] + 1.0, w = wins[i * n + j] + 0.5;
                double e = 1.0 / (1.0 + pow(10.0, (rating[j] - rating[i]) / 400.0));
                g[i] += w - ng * e;
            }
        }
        double mean = 0;
        for (int i = 0; i < n; i++) { double gn = 0; for (int j = 0; j < n; j++) if (j != i) gn += games[i * n + j] + 1.0; rating[i] += 400.0 * g[i] / (gn > 0 ? gn : 1); mean += rating[i]; }
        mean /= n;
        for (int i = 0; i < n; i++) rating[i] += 1000.0 - mean;
    }
}

static double rate(const Tally *t) { return t->games > 0 ? t->wins / t->games : 0.5; }

static int idle_loses_both(int active)
{
    return rate(&strat[0][active]) == 0 && rate(&strat[active][0]) == 1;
}

static void report_strategies(int seeds)
{
    printf("\n== Strategy round robin: %d profiles x %d profiles x %d seeds per ordered pair, both sides, %d-tick cap\n",
           N_PROFILES, N_PROFILES, seeds, DUEL_TICKS);
    printf("   score of row against column (win = 1, draw = 0.5), pooled over all profile pairings\n\n");
    printf("%-10s", "row \\ col");
    for (int b = 0; b < NS; b++) printf("%10s", bot_name(STRAT[b]));
    printf("\n");
    for (int a = 0; a < NS; a++) {
        printf("%-10s", bot_name(STRAT[a]));
        for (int b = 0; b < NS; b++) printf("%10.3f", rate(&strat[a][b]));
        printf("\n");
    }

    double wins[NS * NS], games[NS * NS], rating[NS];
    for (int a = 0; a < NS; a++)
        for (int b = 0; b < NS; b++) {
            /* both orders played as "a vs b" and "b vs a"; pool them for the pair */
            wins[a * NS + b] = strat[a][b].wins + (strat[b][a].games - strat[b][a].wins);
            games[a * NS + b] = strat[a][b].games + strat[b][a].games;
            if (a == b) { wins[a * NS + b] = 0; games[a * NS + b] = 0; }
        }
    elo_fit(NS, wins, games, rating);
    printf("\n== Elo (strategies; max-likelihood fit with one pseudo-game per pair, mean 1000)\n");
    int order[NS] = { 0, 1, 2, 3 };
    for (int i = 0; i < NS; i++) for (int j = i + 1; j < NS; j++) if (rating[order[j]] > rating[order[i]]) { int t = order[i]; order[i] = order[j]; order[j] = t; }
    for (int i = 0; i < NS; i++) printf("   %-10s %7.0f\n", bot_name(STRAT[order[i]]), rating[order[i]]);

    printf("\n== Canaries (both seats; draw = half a score, reported separately)\n");
    for (int active = 1; active < NS; active++) {
        char msg[160];
        snprintf(msg, sizeof msg, "idle scores zero vs %s on BOTH seats (draws fail)", bot_name(STRAT[active]));
        check(idle_loses_both(active), msg);
        printf("   idle left vs %-7s score %.4f draws %.0f/%.0f; idle right score %.4f draws %.0f/%.0f\n",
               bot_name(STRAT[active]), rate(&strat[0][active]), strat[0][active].draws, strat[0][active].games,
               1-rate(&strat[active][0]), strat[active][0].draws, strat[active][0].games);
    }
    for (int smart = 2; smart < NS; smart++) {
        char msg[160];
        snprintf(msg, sizeof msg, "random scores <5%% vs %s on BOTH seats", bot_name(STRAT[smart]));
        check(rate(&strat[1][smart]) < 0.05 && rate(&strat[smart][1]) > 0.95, msg);
        printf("   random left vs %-7s score %.4f draws %.0f/%.0f; random right score %.4f draws %.0f/%.0f\n",
               bot_name(STRAT[smart]), rate(&strat[1][smart]), strat[1][smart].draws, strat[1][smart].games,
               1-rate(&strat[smart][1]), strat[smart][1].draws, strat[smart][1].games);
    }
}

static Tally pooled_build(int p, int q)
{
    Tally t = {0};
    for (int a = 0; a < 3; a++) for (int b = 0; b < 3; b++) {
        t.wins += build[p][q][a][b].wins;
        t.games += build[p][q][a][b].games;
        t.draws += build[p][q][a][b].draws;
    }
    return t;
}

static void build_limits(double *field, double *pair)
{
    *field = *pair = 0;
    for (int p = 0; p < N_PROFILES; p++) {
        double w = 0, g = 0;
        for (int q = 0; q < N_PROFILES; q++) {
            if (p == q) continue;
            Tally t = pooled_build(p, q);
            w += t.wins; g += t.games;
            if (rate(&t) > *pair) *pair = rate(&t);
        }
        if (g && w/g > *field) *field = w/g;
    }
}

static void report_builds(void)
{
    printf("\n== Full build pairwise tables (row score; both seats pooled, draws = 0.5)\n");
    for (int a = 0; a < 3; a++) for (int b = 0; b < 3; b++) {
        printf("\n   %s vs %s\n   %-12s", bot_name(STRAT[a+1]), bot_name(STRAT[b+1]), "row / col");
        for (int q = 0; q < N_PROFILES; q++) printf("%12s", PROFILE_NAME[q]);
        puts("");
        for (int p = 0; p < N_PROFILES; p++) {
            printf("   %-12s", PROFILE_NAME[p]);
            for (int q = 0; q < N_PROFILES; q++) printf("%12.3f", rate(&build[p][q][a][b]));
            puts("");
        }
    }
    printf("\n== Build scores pooled over ALL nine strategy pairings\n   %-12s", "row / col");
    for (int q = 0; q < N_PROFILES; q++) printf("%12s", PROFILE_NAME[q]);
    printf("%12s\n", "field mean");
    double worst, pair_worst;
    build_limits(&worst, &pair_worst);
    double wins[N_PROFILES*N_PROFILES] = {0}, games[N_PROFILES*N_PROFILES] = {0}, rating[N_PROFILES];
    for (int p = 0; p < N_PROFILES; p++) {
        printf("   %-12s", PROFILE_NAME[p]);
        double w = 0, g = 0;
        for (int q = 0; q < N_PROFILES; q++) {
            Tally t = pooled_build(p, q);
            printf("%12.3f", rate(&t));
            if (q == p) continue;
            w += t.wins; g += t.games;
            wins[p*N_PROFILES+q] = t.wins; games[p*N_PROFILES+q] = t.games;
        }
        double mean = g ? w/g : 0.5;
        printf("%12.3f\n", mean);
    }
    elo_fit(N_PROFILES, wins, games, rating);
    printf("\n== Elo (builds, all strategy pairings, both seats)\n");
    for (int p = 0; p < N_PROFILES; p++) printf("   %-12s %7.0f\n", PROFILE_NAME[p], rating[p]);
    char msg[160];
    snprintf(msg, sizeof msg, "no build field mean exceeds %.0f%% (worst %.1f%%)", BUILD_CEILING*100, worst*100);
    check(worst <= BUILD_CEILING, msg);
    snprintf(msg, sizeof msg, "no pooled build pair exceeds 90%% (worst %.1f%%)", pair_worst*100);
    check(pair_worst <= 0.90, msg);
}

int main(int argc, char **argv)
{
    int seeds = argc > 1 ? atoi(argv[1]) : 40;
    int duels = argc > 2 ? atoi(argv[2]) : 400;
    if (seeds < 1) seeds = 1;
    if (duels < 2) duels = 2;
    if (duels % 2) duels++; /* complete the seat pair */
    printf("cpore combat tourney  (tick %d Hz, seeds/cell %d, payoff duels/cell %d)\n\n", CB_HZ, seeds, duels);
    compute_payoff(duels);
    report_payoff(duels);
    round_robin(seeds);
    report_strategies(seeds);
    report_builds();
    printf("\n%s\n", fails ? "tourney checks FAILED" : "tourney checks passed");
    return fails ? 1 : 0;
}
