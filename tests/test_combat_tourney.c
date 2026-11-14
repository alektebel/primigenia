/* Exercise acceptance arithmetic independently of whether design passes it. */
#define main combat_tourney_main
#include "../apps/combat_tourney.c"
#undef main
#include <assert.h>

int main(void)
{
    double P[CB_MOVE_COUNT][CB_MOVE_COUNT] = {{0}}, se[CB_MOVE_COUNT][CB_MOVE_COUNT] = {{0}};
    P[0][0] = 2;
    assert(dominates(P, se, 0, 1));
    P[0][1] = -2;
    assert(!dominates(P, se, 0, 1));
    /* Every strategy pair, including random and cross-strategy, enters the
     * build tally; inverse seats count as the same build comparison. */
    for (int a = 1; a < NS; a++) for (int b = 1; b < NS; b++) record_build(a,b,0,1,1);
    Tally t = pooled_build(0,1), inverse = pooled_build(1,0);
    assert(t.games == 9 && t.wins == 9 && inverse.games == 9 && inverse.wins == 0);
    double field, pair;
    build_limits(&field, &pair);
    assert(field == 1 && pair == 1); /* trips both 65% and 90% gates */
    memset(build, 0, sizeof build);
    record_build(0,2,0,1,1); /* idle is excluded */
    assert(pooled_build(0,1).games == 0);
    record_build(1,3,0,1,0.5);
    t = pooled_build(0,1);
    assert(t.draws == 1 && rate(&t) == 0.5);
    for (int active = 1; active < NS; active++) {
        tally(&strat[0][active], 0); tally(&strat[active][0], 1);
        assert(idle_loses_both(active));
        tally(&strat[active][0], 0.5); /* draw with idle right must fail */
        assert(!idle_loses_both(active));
        memset(strat, 0, sizeof strat);
        tally(&strat[0][active], 0.5); tally(&strat[active][0], 1);
        assert(!idle_loses_both(active));
        memset(strat, 0, sizeof strat);
    }
    compute_payoff(4);
    for (int a = 0; a < CB_MOVE_COUNT; a++) for (int b = 0; b < CB_MOVE_COUNT; b++) {
        assert(fabs(payoff[a][b] + payoff[b][a]) < 1e-9);
        assert(fabs(payr[a][b] + payr[b][a]) < 1e-9);
        if (a == b) assert(payoff_se[a][b] == 0 && payr_se[a][b] == 0);
    }
    puts("combat tournament arithmetic: passed (balance acceptance runs via make tourney)");
    return 0;
}
