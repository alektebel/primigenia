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
/* A defensive move deals no damage, so on raw hp margin its row can never beat an
 * attacker's. The headline payoff therefore also charges each side for the
 * stamina it burned, at PAYOFF_STAMINA_VALUE hp per point (about what a point of
 * stamina buys in bites at mid level). The raw matrix is printed as well. */
#define PAYOFF_STAMINA_VALUE 1.0
static double payoff[CB_MOVE_COUNT][CB_MOVE_COUNT];     /* raw hp margin            */
static double payoff_se[CB_MOVE_COUNT][CB_MOVE_COUNT];
static double payr[CB_MOVE_COUNT][CB_MOVE_COUNT];       /* resource-adjusted        */
static double payr_se[CB_MOVE_COUNT][CB_MOVE_COUNT];

static void compute_payoff(int duels)
{
    CpCombatProfile p;                     /* neutral: every part level 3 */
    p.mouth = p.charge = p.spit = p.tail = p.guard = 3;
    p.hp = 100000.0f; p.stamina = 100.0f; p.speed = 4.0f;     /* nobody dies: pure damage margin */

    for (int a = 0; a < CB_MOVE_COUNT; a++)
        for (int b = 0; b < CB_MOVE_COUNT; b++) {
            double sum = 0.0, sq = 0.0, sumr = 0.0, sqr = 0.0;
            for (int s = 0; s < duels; s++) {
                CpCombatSetup su;
                duel_setup(&su, 1000u + (uint32_t)s, &p, &p, 7.0f);
                CpBot b0, b1;
                bot_init(&b0, BOT_SPAM, (uint32_t)s); b0.spam_move = a; b0.delay = s % 4;
                bot_init(&b1, BOT_SPAM, (uint32_t)s + 7777u); b1.spam_move = b; b1.delay = (s / 4) % 7;
                CpDuelResult r;
                duel_run(&su, &b0, &b1, 120, NULL, 0, NULL, NULL, &r);
                double v = (double)r.dealt[0] - (double)r.dealt[1];
                double vr = v - PAYOFF_STAMINA_VALUE * ((double)r.spent[0] - (double)r.spent[1]);
                sum += v; sq += v * v; sumr += vr; sqr += vr * vr;
            }
            double m = sum / duels, var = sq / duels - m * m;
            payoff[a][b] = m;
            payoff_se[a][b] = sqrt((var > 0 ? var : 0) / duels);
            double mr = sumr / duels, varr = sqr / duels - mr * mr;
            payr[a][b] = mr;
            payr_se[a][b] = sqrt((varr > 0 ? varr : 0) / duels);
        }
}

/* Zero-sum value and the row player's equilibrium mix by regret matching. */
static void solve_game(double *value, double mix[CB_MOVE_COUNT])
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
            for (int j = 0; j < CB_MOVE_COUNT; j++) { ru[i] += payoff[i][j] * cp_[j]; cu[i] += -payoff[j][i] * rp[j]; }
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
        for (int j = 0; j < CB_MOVE_COUNT; j++) v += mix[i] * mix[j] * payoff[i][j];
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

static void report_payoff(int duels)
{
    printf("== Move-vs-move payoff, %d duels per cell: two creatures repeating one move, 7 m apart,\n", duels);
    printf("   random start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)\n\n");
    printf("-- raw: row's damage dealt minus column's (hp)\n");
    print_matrix(payoff);
    printf("\n-- resource-adjusted (headline): raw minus %.1f hp per stamina point the row spent, plus the same for the column\n",
           PAYOFF_STAMINA_VALUE);
    print_matrix(payr);

    printf("\n== Dominance check (tolerance 2*SE + 0.5 hp)\n");
    printf("-- raw matrix (informational: defensive rows are bounded by 0 here)\n");
    dominance(payoff, payoff_se);
    printf("-- resource-adjusted matrix (the check)\n");
    int any = dominance(payr, payr_se);
    memcpy(payoff, payr, sizeof(payoff));     /* equilibrium is solved on the headline matrix */
    double value, mix[CB_MOVE_COUNT];
    solve_game(&value, mix);
    printf("   equilibrium mix (regret matching, 200k iters), game value %.2f:", value);
    for (int a = 0; a < CB_MOVE_COUNT; a++) printf("  %s %.0f%%", cp_combat_move_name(a), mix[a] * 100.0);
    printf("\n");
    check(!any, "no move weakly dominates another (resource-adjusted payoff)");
}

/* ---------------- strategy round robin ---------------- */
typedef struct { double wins, games; } Tally;
static Tally strat[NS][NS];           /* [a][b]: a's score against b (draw = 0.5) */
static Tally build[N_PROFILES][N_PROFILES][2];   /* [profile][opponent profile][greedy|counter] */

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
                        strat[sa][sb].wins += s; strat[sa][sb].games += 1;
                        if (sa == sb && (sa == 2 || sa == 3) && pa != pb) {
                            Tally *t = &build[pa][pb][sa - 2];
                            t->wins += s; t->games += 1;
                        }
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

    /* strategy dominance: A weakly dominates B if A scores >= B against every opponent */
    printf("\n== Strategy dominance (score vs each opponent, tolerance 0.02)\n");
    int dominated_by_all = -1;
    for (int a = 0; a < NS; a++) {
        int cnt = 0;
        for (int b = 0; b < NS; b++) {
            if (a == b) continue;
            int ge = 1, gt = 0;
            for (int c = 0; c < NS; c++) {
                double sa = rate(&strat[a][c]), sb = rate(&strat[b][c]);
                if (c == a || c == b) { /* mirror and head-to-head compare differently */ continue; }
                if (sa < sb - 0.02) ge = 0;
                if (sa > sb + 0.02) gt = 1;
            }
            if (rate(&strat[a][b]) < 0.5 - 0.02) ge = 0;
            if (rate(&strat[a][b]) > 0.5 + 0.02) gt = 1;
            if (ge && gt) { printf("   %s weakly dominates %s\n", bot_name(STRAT[a]), bot_name(STRAT[b])); cnt++; }
        }
        if (cnt == NS - 1) dominated_by_all = a;
    }
    if (dominated_by_all >= 0)
        printf("   %s weakly dominates every other strategy (a strict skill ladder, as intended for the reference rows)\n",
               bot_name(STRAT[dominated_by_all]));

    printf("\n== Canaries and ladder\n");
    check(rate(&strat[2][0]) > 0.99 && rate(&strat[3][0]) > 0.99, "greedy and counter beat idle (>99%)");
    check(rate(&strat[2][1]) > 0.95 && rate(&strat[3][1]) > 0.95, "greedy and counter beat random (>95%)");
    check(rate(&strat[1][0]) > 0.5, "random beats idle");
    check(rate(&strat[0][1]) == 0.0 && rate(&strat[0][2]) == 0.0 && rate(&strat[0][3]) == 0.0, "idle never scores against an active bot (0%)");
    check(rate(&strat[1][2]) < 0.05 && rate(&strat[1][3]) < 0.05, "random rarely beats greedy or counter (<5%)");
    printf("   idle  vs greedy %.4f  vs counter %.4f | random vs greedy %.4f  vs counter %.4f\n",
           rate(&strat[0][2]), rate(&strat[0][3]), rate(&strat[1][2]), rate(&strat[1][3]));
    printf("   greedy vs counter: greedy scores %.3f\n", rate(&strat[2][3]));
}

static void report_builds(void)
{
    printf("\n== Builds: profile win rate, same strategy on both sides (profile vs the other four)\n");
    printf("   %-12s %8s %8s %8s\n", "profile", "greedy", "counter", "mean");
    double worst = 0;
    double bw[N_PROFILES], bg[N_PROFILES];
    for (int p = 0; p < N_PROFILES; p++) {
        double w[2] = { 0, 0 }, g[2] = { 0, 0 };
        for (int q = 0; q < N_PROFILES; q++) {
            if (q == p) continue;
            for (int s = 0; s < 2; s++) { w[s] += build[p][q][s].wins; g[s] += build[p][q][s].games; }
        }
        double r0 = g[0] > 0 ? w[0] / g[0] : 0.5, r1 = g[1] > 0 ? w[1] / g[1] : 0.5;
        double m = (w[0] + w[1]) / (g[0] + g[1]);
        printf("   %-12s %8.3f %8.3f %8.3f\n", PROFILE_NAME[p], r0, r1, m);
        if (r0 > worst) worst = r0;
        if (r1 > worst) worst = r1;
        bw[p] = w[0] + w[1]; bg[p] = g[0] + g[1];
    }
    printf("\n   build-vs-build score (row beats column), greedy and counter pooled\n   %-12s", "");
    for (int q = 0; q < N_PROFILES; q++) printf("%12s", PROFILE_NAME[q]);
    printf("\n");
    for (int p = 0; p < N_PROFILES; p++) {
        printf("   %-12s", PROFILE_NAME[p]);
        for (int q = 0; q < N_PROFILES; q++) {
            if (p == q) { printf("%12s", "-"); continue; }
            double w = build[p][q][0].wins + build[p][q][1].wins, g = build[p][q][0].games + build[p][q][1].games;
            printf("%12.3f", g > 0 ? w / g : 0.5);
        }
        printf("\n");
    }
    /* build Elo */
    static double wins[N_PROFILES * N_PROFILES], games[N_PROFILES * N_PROFILES];
    double rating[N_PROFILES];
    for (int p = 0; p < N_PROFILES; p++)
        for (int q = 0; q < N_PROFILES; q++) {
            wins[p * N_PROFILES + q] = games[p * N_PROFILES + q] = 0;
            if (p == q) continue;
            wins[p * N_PROFILES + q] = build[p][q][0].wins + build[p][q][1].wins + (build[q][p][0].games - build[q][p][0].wins) + (build[q][p][1].games - build[q][p][1].wins);
            games[p * N_PROFILES + q] = build[p][q][0].games + build[p][q][1].games + build[q][p][0].games + build[q][p][1].games;
        }
    elo_fit(N_PROFILES, wins, games, rating);
    printf("\n== Elo (builds, greedy and counter mirror matches pooled)\n");
    for (int p = 0; p < N_PROFILES; p++) printf("   %-12s %7.0f\n", PROFILE_NAME[p], rating[p]);
    (void)bw; (void)bg;
    char msg[160];
    snprintf(msg, sizeof msg, "no build exceeds the %.0f%% win-rate ceiling (worst %.1f%%)", BUILD_CEILING * 100, worst * 100);
    check(worst <= BUILD_CEILING, msg);
}

int main(int argc, char **argv)
{
    int seeds = argc > 1 ? atoi(argv[1]) : 40;
    int duels = argc > 2 ? atoi(argv[2]) : 400;
    if (seeds < 1) seeds = 1;
    if (duels < 1) duels = 1;
    printf("cpore combat tourney  (tick %d Hz, seeds/cell %d, payoff duels/cell %d)\n\n", CB_HZ, seeds, duels);
    compute_payoff(duels);
    report_payoff(duels);
    round_robin(seeds);
    report_strategies(seeds);
    report_builds();
    printf("\n%s\n", fails ? "tourney checks FAILED" : "tourney checks passed");
    return fails ? 1 : 0;
}
