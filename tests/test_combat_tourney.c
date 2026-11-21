/* Exercise acceptance arithmetic independently of whether design passes it. */
#define main combat_tourney_main
#include "../apps/combat_tourney.c"
#undef main
#include <assert.h>

int main(void)
{
    /* Solver initialization leaves tiny weights on unused moves. Those do
     * not establish a meaningful mixed strategy. */
    double mix[CB_MOVE_COUNT] = {0.34, 0.33, 0.329999, 0.000001, 0, 0};
    assert(equilibrium_support(mix) == 3);
    mix[0] = 0.25; mix[1] = 0.25; mix[2] = 0.25; mix[3] = 0.25;
    assert(equilibrium_support(mix) == 4);
    double P[CB_MOVE_COUNT][CB_MOVE_COUNT] = {{0}}, se[CB_MOVE_COUNT][CB_MOVE_COUNT] = {{0}};
    P[0][0] = 2;
    assert(dominates(P, se, 0, 1));
    P[0][1] = -2;
    assert(!dominates(P, se, 0, 1));
    se[0][0] = 1;
    P[0][1] = 0;
    assert(!dominates(P, se, 0, 1)); /* 2 HP is inside 2*SE + 0.5 */
    P[0][0] = 3;
    assert(dominates(P, se, 0, 1));
    P[0][1] = -3; se[1][1] = 2;
    assert(dominates(P, se, 0, 1)); /* use the larger row's SE */
    /* A known five-action cycle, plus a dominated sixth action, must have
     * real five-move support rather than solver initialization dust. */
    for (int i = 0; i < 5; i++) for (int j = 0; j < 5; j++)
        P[i][j] = i == j ? 0 : ((j-i+5)%5 <= 2 ? 1 : -1);
    for (int i = 0; i < 5; i++) { P[i][5] = 2; P[5][i] = -2; }
    P[5][5] = 0;
    double value;
    solve_game(P, &value, mix);
    assert(equilibrium_support(mix) == 5 && fabs(value) < 1e-9);
    for (int i = 0; i < 5; i++) assert(fabs(mix[i]-0.2) < 0.001);
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
    seed_offset = 2000000u;
    compute_payoff(4);
    CpCombatProfile p={0}; cp_combat_profile_default(&p);
    p.mouth = p.charge = p.spit = p.tail = p.guard = 3;
    double expected = ((15.4+4.2)/10.8 + 42.0/21.6 + 18.2/14.4 + 23.8/12.0)/4;
    assert(fabs(move_stamina_value(&p)-expected) < 1e-6);

    for (int a = 0; a < CB_MOVE_COUNT; a++) for (int b = 0; b < CB_MOVE_COUNT; b++) {
        assert(fabs(payoff[a][b] + payoff[b][a]) < 1e-9);
        assert(fabs(payr[a][b] + payr[b][a]) < 1e-9);
        if (a == b) assert(payoff_se[a][b] == 0 && payr_se[a][b] == 0);
    }
    /* B3 truth table */
    assert(b3_ok(0.13,0,0.094));
    assert(!b3_ok(0.005,0,0.094));
    assert(!b3_ok(0.36,0,0.094));
    assert(!b3_ok(0.13,0.36,0.094));
    assert(!b3_ok(0.13,0,0.02));
    assert(!b3_ok(0.13,0,0.21));
    /* BOT_SPAM filler: default idles while the volley is cooling; filler=bite bites between volleys */
    for(int with_filler=0;with_filler<2;with_filler++){
        CpCombatProfile np={0};memset(np.extra,3,sizeof np.extra);np.carnivore=1;
        np.mouth=np.charge=np.spit=np.tail=np.guard=3;np.hp=100000.0f;np.stamina=100.0f;np.speed=4.0f;
        CpCombatSetup su;duel_setup(&su,1234u,&np,&np,7.0f);
        for(int seat=0;seat<2;seat++){
            CpCombatSpawn *sp=&su.c[seat];sp->has_loadout=1;sp->calcium=100;
            cp_combat_loadout_default(&sp->loadout,&sp->prof);sp->loadout.known|=1u<<CB_SPINE_VOLLEY;
            sp->loadout.sig_slot=3;sp->loadout.slot[3]=CB_SPINE_VOLLEY;
        }
        CpBot b0,b1;bot_init(&b0,BOT_SPAM,1);bot_init(&b1,BOT_SPAM,2);
        assert(b0.filler==CB_MOVE_NONE);
        b0.spam_move=CB_SPINE_VOLLEY;b0.filler=with_filler?CB_BITE:CB_MOVE_NONE;
        b1.spam_move=CB_BITE;
        static CpCombatLogEntry lg[4096];int nl=0,bites=0;
        CpDuelResult r;duel_run(&su,&b0,&b1,120,lg,4096,&nl,NULL,&r);
        for(int i=0;i<nl;i++)if(lg[i].id==0&&lg[i].act.verb==CB_V_ATTACK&&lg[i].act.move==CB_BITE)bites++;
        assert(r.volleys[0]<=4&&r.volleys[0]>=1);
        if(with_filler)assert(bites>0);else assert(bites==0);
    }
    puts("combat tournament arithmetic: passed (balance acceptance runs via make tourney)");
    return 0;
}
