#include "cpore/world.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
static CpStageWorld w, other;
static CpStageSetup setup;
static void reset(void) {
    cp_stage_setup_default(&setup,42);
    setup.terrain=CP_STAGE_FLAT;
    setup.n=1;
    setup.wild[0].profile=(CpCombatProfile){2,1,0,1,0,100,100,4,0};setup.wild[0].bot=2;
    setup.nest_x=setup.nest_z=0;
    setup.wild[0].x=setup.wild[0].home_x=0;
    setup.wild[0].z=setup.wild[0].home_z=18;
    assert(cp_stage_reset(&w,&setup)==0);
}
static void validation(void) {
    reset();
    const uint64_t before=cp_stage_hash(&w);
    const char *bad[]={
        "", "jump", "go nan,0", "go 999,0", "heading nan", "approach #0", "attack #999 0", "attack #1 99", "wait extra"
    };
    for(unsigned i=0;i<sizeof bad/sizeof *bad;i++) {
        assert(cp_stage_command(&w,bad[i])<0);
        assert(cp_stage_hash(&w)==before);
    }
    CpStageInput a={
        0
    };
    a.verb=999;
    assert(cp_stage_order(&w,&a)<0);
    a.verb=CP_STAGE_HEADING;
    assert(cp_stage_order(&w,&a)<0);
    a.verb=CP_STAGE_DODGE;
    a.dir=8;
    assert(cp_stage_order(&w,&a)<0);
    assert(cp_stage_command(&w,"heading 90")==0);
    assert(w.order.hx>32700 && w.order.hz==0);
    assert(cp_stage_command(&w,"heading -90")==0 && w.order.hx< -32700);
    assert(cp_stage_command(&w,"heading 180")==0 && w.order.hz< -32700);
    assert(cp_stage_command(&w,"heading 30")==0);
    assert(fabsf((float)w.order.hx/w.order.hz-.57735027f)<.002f);
    assert(cp_stage_command(&w,"heading 30.5")==0);
    assert(cp_stage_command(&w,"heading 1e30")<0);
    assert(cp_stage_command(&w,"go 3,4")==0);
    assert(cp_stage_command(&w,"go 3 4")==0);
    assert(cp_stage_command(&w,"go_nest")==0);
    assert(cp_stage_command(&w,"flee")==0);
    assert(cp_stage_command(&w,"wait")==0);
    assert(cp_stage_command(&w,"approach #1")==0);
    assert(cp_stage_command(&w,"attack #1 0")==0);
    assert(cp_stage_command(&w,"attack #1 bite")==0);
    const CpStageSetup valid=setup;
    setup.n=25;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.n_obstacles=1025;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.player.hp=NAN;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.nest_x=INFINITY;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.wild[0].species=4;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.wild[0].bot=5;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.n_obstacles=1;
    setup.obstacles[0].r=-1;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.water_radius=-1;
    assert(cp_stage_reset(&w,&setup)<0);
}
static void terrain_and_hash(void) {
    reset();
    setup.terrain=CP_STAGE_ANALYTIC;
    assert(cp_stage_reset(&w,&setup)==0);
    for(int i=-190;i<190;i+=7) {
        assert(isfinite(cp_stage_height(&w,i,i/2.f)));
        assert(isfinite(cp_stage_ground(&w,i,i/2.f)));
    }
    assert(cp_stage_height(&w,NAN,0)==0);
    assert(!cp_stage_can_walk(&w,0,0,196,0,.6f));
    other=w;
    cp_rng_u32(&other.roam_rng);
    assert(cp_stage_hash(&other)!=cp_stage_hash(&w));
    assert(memcmp(&other.spawn_rng,&w.spawn_rng,sizeof(CpRng))==0);
    assert(cp_stage_height(&other,70,-55)==cp_stage_height(&w,70,-55));
    other=w;
    other.setup.player.radius_cm=70;
    assert(cp_stage_hash(&other)!=cp_stage_hash(&w));
    reset();
    setup.n=0;
    setup.water_x=3;
    setup.water_z=0;
    setup.water_radius=2;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(!cp_stage_can_walk(&w,0,0,2,0,.6f));
    w.clock=CP_STAGE_DAY_TICKS-1;
    cp_stage_step(&w,NULL);
    assert(w.clock==0);
}
static void encounters(void) {
    reset();
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    cp_stage_step(&w,NULL);
    assert(w.active==0);
    CpStageInput a={
        0
    };
    a.verb=CP_STAGE_GUARD;
    cp_stage_step(&w,&a);
    a.verb=CP_STAGE_DODGE;
    a.dir=2;
    cp_stage_step(&w,&a);
    a.verb=CP_STAGE_APPROACH;
    a.target=1;
    cp_stage_step(&w,&a);
    a.verb=CP_STAGE_GO;
    a.x=10;
    a.z=10;
    cp_stage_step(&w,&a);
    a.verb=CP_STAGE_FLEE;
    cp_stage_step(&w,&a);
    w.combat.c[1].hp=.1f;
    w.combat.c[1].bleed_t=2;
    cp_stage_step(&w,NULL);
    assert(w.outcome==CP_STAGE_VICTORY && w.wild[0].dead);
    char obs[4096];
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"carcass"));
    assert(cp_stage_command(&w,"attack #1 0")<0);
    reset();
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    cp_stage_step(&w,NULL);
    w.combat.c[0].hp=.1f;
    w.combat.c[0].bleed_t=2;
    cp_stage_step(&w,NULL);
    assert(w.outcome==CP_STAGE_DEATH && w.respawn_ticks==20);
    for(int i=0;i<20;i++)cp_stage_step(&w,NULL);
    assert(w.player.hp==setup.player.hp && w.player.x==setup.nest_x);
    reset();
    setup.wild[0].species=0;
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    for(int i=0;i<10;i++)cp_stage_step(&w,NULL);
    assert(w.active<0 && w.wild[0].z>4);
    /* timid never initiates */
    reset();
    setup.wild[0].species=2;
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    cp_stage_step(&w,NULL);
    assert(w.active==0);
}
static void multiple_creatures(void) {
    reset();
    setup.n=2;
    setup.wild[0].z=setup.wild[0].home_z=4;
    setup.wild[1]=setup.wild[0];
    setup.wild[1].species=0;
    setup.wild[1].x=setup.wild[1].home_x=60;
    assert(cp_stage_reset(&w,&setup)==0);
    cp_stage_step(&w,NULL);
    assert(w.active==0);
    w.wild[1].roam_ticks=1;
    const CpRng previous=w.roam_rng;
    cp_stage_step(&w,NULL);
    assert(memcmp(&previous,&w.roam_rng,sizeof previous)!=0);
    reset();
    setup.wild[0].species=2;
    setup.wild[0].z=4;
    setup.wild[0].home_x=40;
    setup.wild[0].home_z=40;
    assert(cp_stage_reset(&w,&setup)==0);
    cp_stage_step(&w,NULL);
    assert(w.active<0);
    /* proximity outside its home territory is safe */
}
static void agent_contract(void) {
    reset();
    CpStageLogEntry log[2]={{0,{.verb=CP_STAGE_GO,.x=4,.z=5}},
                            {50,{.verb=CP_STAGE_GO_NEST}}};
    uint64_t hashes[100];
    uint64_t replay_hash=cp_stage_replay(&setup,log,2,100,hashes);
    for(int i=0;i<100;i++) {
        if(i==0)cp_stage_order(&w,&log[0].input);
        if(i==50)cp_stage_order(&w,&log[1].input);
        assert(cp_stage_step(&w,NULL)==hashes[i]);
    }
    assert(replay_hash==cp_stage_hash(&w));
    assert(cp_stage_replay(&setup,log,-1,100,NULL)==0);
    assert(cp_stage_replay(&setup,NULL,1,100,NULL)==0);
    log[1].tick=100;assert(cp_stage_replay(&setup,log,2,100,NULL)==0);
    log[1].tick=0;log[0].tick=50;assert(cp_stage_replay(&setup,log,2,100,NULL)==0);
    assert(cp_stage_replay(NULL,NULL,0,100,NULL)==0);
    assert(cp_stage_replay(&setup,NULL,0,0,NULL)!=0);
    reset();setup.n=3;setup.n_obstacles=3;
    setup.wild[1]=setup.wild[0];setup.wild[1].x=10;
    setup.wild[2]=setup.wild[0];setup.wild[2].x=100;
    setup.obstacles[0]=(CpStageObstacle){10,0,1,0};
    setup.obstacles[1]=(CpStageObstacle){12,0,1,1};
    setup.obstacles[2]=(CpStageObstacle){100,0,1,1};
    assert(cp_stage_reset(&w,&setup)==0);
    char obs[16384];assert(cp_stage_observe(&w,obs,sizeof obs)>0);
    assert(strstr(obs,"tree")&&strstr(obs,"rock")&&strstr(obs,"attack_moves"));
    assert(cp_stage_observe(&w,NULL,1)<0 && cp_stage_observe(&w,obs,0)<0);
    assert(cp_stage_command(&w,NULL)<0);
    setup.n=0;setup.player.mouth=setup.player.charge=setup.player.spit=setup.player.tail=0;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && !strstr(obs,"\"attack\""));
    assert(cp_stage_order(&w,&(CpStageInput){0})==0);
    reset();setup.wild[0].species=2;setup.wild[0].x=1.5f;setup.wild[0].z=0;
    setup.wild[0].home_x=setup.wild[0].home_z=40;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(cp_stage_command(&w,"approach #1")==0);cp_stage_step(&w,NULL);
    assert(w.order.verb==CP_STAGE_CONTINUE);
    reset();setup.wild[0].species=0;setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);assert(cp_stage_command(&w,"attack #1 bite")==0);
    for(int i=0;i<100&&w.active<0;i++)cp_stage_step(&w,NULL);
    assert(w.active==0);w.combat.c[1].hp=10;cp_stage_step(&w,NULL);
    assert(w.combat_orders[1].verb==CB_V_FLEE);
}
static void numeric_boundaries(void) {
    reset();const CpStageSetup valid=setup;
    const float bad[]={NAN,INFINITY,-INFINITY,0,1000001};
    for(unsigned i=0;i<sizeof bad/sizeof *bad;i++) {
        setup=valid;setup.player.hp=bad[i];assert(cp_stage_reset(&w,&setup)<0);
        setup=valid;setup.player.stamina=bad[i];assert(cp_stage_reset(&w,&setup)<0);
        setup=valid;setup.player.speed=bad[i];assert(cp_stage_reset(&w,&setup)<0);
    }
    const int bad_counts[]={-1,25};
    for(int i=0;i<2;i++){setup=valid;setup.n=bad_counts[i];assert(cp_stage_reset(&w,&setup)<0);}
    setup=valid;setup.terrain=-1;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.nest_x=10001;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].x=NAN;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].z=NAN;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].home_x=NAN;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].home_z=NAN;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].x=196;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].z=196;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].home_x=196;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].home_z=196;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].species=-1;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].bot=-2;assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;setup.wild[0].profile.hp=0;assert(cp_stage_reset(&w,&setup)<0);
    for(int i=0;i<5;i++){
        setup=valid;uint8_t *levels=&setup.player.mouth;levels[i]=6;
        assert(cp_stage_reset(&w,&setup)<0);
    }
    setup=valid;assert(cp_stage_reset(&w,&setup)==0);
    assert(cp_stage_ground(&w,NAN,0)==0);
    assert(cp_stage_height(&w,100001,0)==0);
    assert(cp_stage_height(&w,0,100001)==0);
    assert(!cp_stage_can_walk(&w,0,0,NAN,0,.6f));
    const CpStageInput bad_input[]={
        {.verb=-1},{.verb=CP_STAGE_WAIT,.sprint=-1},{.verb=CP_STAGE_WAIT,.sprint=2},
        {.verb=CP_STAGE_WAIT,.z=NAN},{.verb=CP_STAGE_GO,.x=0,.z=196},
        {.verb=CP_STAGE_ATTACK,.target=1,.move=CB_GUARD},
        {.verb=CP_STAGE_ATTACK,.target=1,.move=-1},
    };
    for(unsigned i=0;i<sizeof bad_input/sizeof *bad_input;i++)assert(cp_stage_order(&w,&bad_input[i])<0);
    assert(cp_stage_order(NULL,&bad_input[0])<0 && cp_stage_order(&w,NULL)<0);
}
/* PLAN-feel motion law: jog and sprint response, acceleration caps, curved turns, pivot only near rest. */
static CpStageInput heading_to(float x,float z,int sprint){
    CpStageInput a={0};
    float s=fmaxf(fabsf(x),fabsf(z));
    a.verb=CP_STAGE_HEADING;a.hx=(int16_t)lroundf(x/s*32767);a.hz=(int16_t)lroundf(z/s*32767);a.sprint=sprint;
    return a;
}
static void motion_law(void) {
    const CpStageMotion *m=&CP_STAGE_MOTION;
    for(int sprint=0;sprint<2;sprint++) {
        reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
        float jog=setup.player.speed*m->jog_k,top=sprint?jog*m->sprint_k:jog,old=0,last_dyaw_limit=.7f;
        int t90=-1;
        CpStageInput a=heading_to(w.player.fx,w.player.fz,sprint);
        for(int i=1;i<=40;i++) {
            cp_stage_step(&w,&a);
            assert(w.player.speed-old<=m->accel*.1f+1e-3f);
            if(t90<0&&w.player.speed>=.9f*top)t90=i;
            old=w.player.speed;
        }
        assert(fabsf(w.player.speed-top)<.01f);
        assert(t90>0&&t90<=(sprint?6:4));
        assert(!w.player.pivot&&last_dyaw_limit>0);
    }
    /* A reversal at full jog is a skid, not a turret spin: the pivot flag stays off while v > pivot_v. */
    reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
    float jog=setup.player.speed*m->jog_k;
    CpStageInput a=heading_to(w.player.fx,w.player.fz,0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&a);
    float fx0=w.player.fx,fz0=w.player.fz;
    a=heading_to(-fx0,-fz0,0);
    for(int i=0;i<30;i++) {
        float pfx=w.player.fx,pfz=w.player.fz,v=w.player.speed;
        cp_stage_step(&w,&a);
        if(v>m->pivot_k*jog)assert(!w.player.pivot);
        float dyaw=acosf(fminf(1,fmaxf(-1,pfx*w.player.fx+pfz*w.player.fz)));
        assert(dyaw<=.7f+1e-4f);
    }
    assert(w.player.fx*fx0+w.player.fz*fz0<-.95f);
    /* A pivot from near rest reverses within ceil(pi/(rate*.1))+1 ticks. */
    reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
    a=heading_to(w.player.fx,w.player.fz,0);
    for(int i=0;i<2;i++)cp_stage_step(&w,&a);
    a=(CpStageInput){.verb=CP_STAGE_WAIT};
    for(int i=0;i<20&&w.player.speed>0;i++)cp_stage_step(&w,&a);
    assert(w.player.speed==0);
    fx0=w.player.fx;fz0=w.player.fz;
    float r=cp_combat_body_radius(&w.player.profile),turn0=fminf(m->turn_max,fmaxf(m->turn_min,m->turn_k*sqrtf(9.81f/r)));
    float pr=fminf(m->pivot_max,fmaxf(3,m->pivot_mul*turn0));
    int ticks=(int)ceilf(3.14159265f/(pr*.1f))+1,ok=0;
    a=heading_to(-fx0,-fz0,0);
    for(int i=0;i<ticks;i++)cp_stage_step(&w,&a);
    ok=w.player.fx*fx0+w.player.fz*fz0<-.98f;
    assert(ok);
    /* Radius of a held heading 90 degrees off, at jog, radius_cm 340: at least 1.4 m. */
    reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
    a=heading_to(w.player.fx,w.player.fz,0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&a);
    float rate=0,sp=0;
    for(int i=0;i<30;i++) {
        float fx=w.player.fx,fz=w.player.fz;
        a=heading_to(-fz,fx,0);
        cp_stage_step(&w,&a);
        if(i>=20){rate+=acosf(fminf(1,fmaxf(-1,fx*w.player.fx+fz*w.player.fz)))/.1f/10;sp+=w.player.speed/10;}
    }
    assert(sp/rate>=1.4f);
    printf("world motion law: jog %.2f sprint %.2f, circle radius %.2f m\n",jog,jog*m->sprint_k,sp/rate);
}
int main(void) {
    validation();
    motion_law();
    terrain_and_hash();
    encounters();
    multiple_creatures();
    agent_contract();
    numeric_boundaries();
    reset();
    CpStageInput a={
        0
    };
    a.verb=CP_STAGE_HEADING;
    a.hx=32767;
    a.sprint=1;
    for(int i=0;i<10;i++)cp_stage_step(&w,&a);
    assert(w.player.x>4 && w.player.stamina<100);
    reset();
    setup.n_obstacles=1;
    setup.obstacles[0]=(CpStageObstacle){
        2,0,1,0
    };
    assert(cp_stage_reset(&w,&setup)==0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&a);
    assert(w.player.x<1);
    assert(!cp_stage_can_walk(&w,0,0,4,0,.6f));
    reset();
    a=(CpStageInput){
        0
    };
    a.verb=CP_STAGE_GO;
    a.x=5;
    a.z=6;
    for(int i=0;i<70;i++)cp_stage_step(&w,i==0?&a:NULL);
    assert(sqrtf((w.player.x-5)*(w.player.x-5)+(w.player.z-6)*(w.player.z-6))<.25f);
    reset();
    uint64_t h=cp_stage_hash(&w);
    a.verb=CP_STAGE_ATTACK;
    a.target=999;
    assert(cp_stage_order(&w,&a)<0 && cp_stage_hash(&w)==h);
    a.verb=CP_STAGE_GO;
    a.x=NAN;
    assert(cp_stage_order(&w,&a)<0 && cp_stage_hash(&w)==h);
    reset();
    other=w;
    for(int i=0;i<3000;i++){
        a=(CpStageInput){
            0
        };
        a.verb=CP_STAGE_HEADING;
        a.hx=(i%101)*600-30000;
        a.hz=20000;
        assert(cp_stage_step(&w,&a)==cp_stage_step(&other,&a));
    }
    char obs[16384];
    assert(cp_stage_observe(&w,obs,sizeof obs)>0);
    assert(strstr(obs,"nearby"));
    assert(cp_stage_observe(&w,obs,4)<0);
    puts("PASS world movement, collision, arrival, atomic rejection, replay and observation");
}
