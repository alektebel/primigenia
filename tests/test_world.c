#include "cpore/world.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
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
/* ---- golden logs + snapshot / restore (PLAN-devtools step 3) ---- */
#define GOLDEN_TICKS 3000
static CpStageInput golden_in[GOLDEN_TICKS];
static uint64_t golden_hash[GOLDEN_TICKS];
static int profile_read(FILE *f,CpCombatProfile *p){
    unsigned a,b,c,d,e,r;
    if(fscanf(f,"%u%u%u%u%u%f%f%f%u",&a,&b,&c,&d,&e,&p->hp,&p->stamina,&p->speed,&r)!=9)return -1;
    p->mouth=a;p->charge=b;p->spit=c;p->tail=d;p->guard=e;p->radius_cm=r;
    return 0;
}
/* Same container as apps/world_cli.c replay(): v2 header, setup, then one input per tick. */
static void load_golden(unsigned seed,CpStageSetup *su){
    char path[96];
    snprintf(path,sizeof path,"tests/golden/world-%u.log",seed);
    FILE *f=fopen(path,"r");
    assert(f);
    char magic[32];int version,ticks;
    assert(fscanf(f,"%31s%d",magic,&version)==2&&!strcmp(magic,"CPORE_WORLD_LOG")&&version==2);
    memset(su,0,sizeof *su);
    assert(fscanf(f,"%u%u%d%f%f%f%f%f%f%d%d",&su->seed,&su->terrain_seed,&su->terrain,&su->nest_x,&su->nest_z,&su->flat_height,&su->water_x,&su->water_z,&su->water_radius,&su->n,&su->n_obstacles)==11);
    assert(profile_read(f,&su->player)==0);
    for(int i=0;i<su->n;i++){
        CpStageSpawn *c=&su->wild[i];
        assert(fscanf(f,"%f%f%f%f%d%d",&c->x,&c->z,&c->home_x,&c->home_z,&c->species,&c->bot)==6&&profile_read(f,&c->profile)==0);
    }
    for(int i=0;i<su->n_obstacles;i++){
        CpStageObstacle *o=&su->obstacles[i];
        assert(fscanf(f,"%f%f%f%d",&o->x,&o->z,&o->r,&o->type)==4);
    }
    assert(fscanf(f,"%d",&ticks)==1&&ticks==GOLDEN_TICKS);
    for(int i=0;i<ticks;i++){
        CpStageInput *a=&golden_in[i];int hx,hz;
        memset(a,0,sizeof *a);
        assert(fscanf(f,"%d%d%d%d%d%d%d%f%f",&a->verb,&a->target,&a->move,&a->dir,&a->sprint,&hx,&hz,&a->x,&a->z)==9);
        a->hx=hx;a->hz=hz;
    }
    fclose(f);
    snprintf(path,sizeof path,"tests/golden/world-%u.hashes",seed);
    f=fopen(path,"r");
    assert(f);
    for(int i=0;i<GOLDEN_TICKS;i++){
        unsigned long long h;
        assert(fscanf(f,"%16llx",&h)==1);
        golden_hash[i]=h;
    }
    fclose(f);
}
static CpStageWorld snap_a,snap_b;
static void snapshots(void){
    assert(cp_stage_world_size()==sizeof(CpStageWorld));
    assert(cp_stage_snapshot_size()==48+offsetof(CpStageWorld,field));
    static uint8_t blob[1<<16],again[1<<16];
    const unsigned seeds[]={1,42,987654321};
    for(unsigned si=0;si<3;si++){
        CpStageSetup su;
        load_golden(seeds[si],&su);
        /* (a) the committed golden hashes still hold */
        assert(cp_stage_reset(&snap_a,&su)==0);
        int fight_tick=-1;
        for(int i=0;i<GOLDEN_TICKS;i++){
            assert(cp_stage_step(&snap_a,&golden_in[i])==golden_hash[i]);
            if(fight_tick<0&&snap_a.active>=0)fight_tick=i;
        }
        assert(fight_tick>=0);
        const int at[]={0,1,777,fight_tick+5};
        for(unsigned k=0;k<sizeof at/sizeof *at;k++){
            assert(cp_stage_reset(&snap_a,&su)==0);
            for(int i=0;i<at[k];i++)cp_stage_step(&snap_a,&golden_in[i]);
            int n=cp_stage_snapshot(&snap_a,blob,sizeof blob);
            assert(n==(int)cp_stage_snapshot_size());
            /* (b) restore into a dirty world and keep going: every tick hash and the final observation match */
            memset(&snap_b,0x5a,sizeof snap_b);
            assert(cp_stage_restore(&snap_b,blob,(size_t)n,NULL)==CP_STAGE_SNAP_OK);
            assert(cp_stage_hash(&snap_b)==cp_stage_hash(&snap_a));
            /* (c) a snapshot of a restored world is the same bytes */
            assert(cp_stage_snapshot(&snap_b,again,sizeof again)==n&&!memcmp(blob,again,(size_t)n));
            for(int i=at[k];i<GOLDEN_TICKS;i++){
                uint64_t h=cp_stage_step(&snap_b,&golden_in[i]);
                assert(h==golden_hash[i]);
                assert(h==cp_stage_step(&snap_a,&golden_in[i]));
            }
            char oa[8192],ob[8192];
            assert(cp_stage_observe(&snap_a,oa,sizeof oa)>0&&cp_stage_observe(&snap_b,ob,sizeof ob)>0&&!strcmp(oa,ob));
        }
    }
    /* (d) every error code */
    reset();
    for(int i=0;i<50;i++)cp_stage_step(&w,NULL);
    int n=cp_stage_snapshot(&w,blob,sizeof blob);
    assert(n>0);
    const uint64_t before=cp_stage_hash(&snap_b);
    uint8_t bad[1<<16];
    memcpy(bad,blob,(size_t)n);bad[0]='X';
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_MAGIC);
    memcpy(bad,blob,(size_t)n);bad[8]=2;
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_FORMAT);
    memcpy(bad,blob,(size_t)n);bad[12]=CP_STAGE_VERSION+1;
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_ENGINE);
    memcpy(bad,blob,(size_t)n);bad[16]^=1;
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_LAYOUT);
    assert(cp_stage_restore(&snap_b,blob,(size_t)n-1,NULL)==CP_STAGE_SNAP_ERR_SIZE);
    assert(cp_stage_restore(&snap_b,blob,20,NULL)==CP_STAGE_SNAP_ERR_MAGIC);
    memcpy(bad,blob,(size_t)n);bad[24]^=1;
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_SIZE);
    memcpy(bad,blob,(size_t)n);bad[32]=1; /* header claims an island field; none given */
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_FIELD);
    memcpy(bad,blob,(size_t)n);bad[48+offsetof(CpStageWorld,tick)]^=0x40;
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_HASH);
    assert(cp_stage_hash(&snap_b)==before); /* failed restores leave the world untouched */
    assert(cp_stage_snapshot(&w,blob,10)==CP_STAGE_SNAP_ERR_SIZE);
    for(int c=CP_STAGE_SNAP_ERR_HASH;c<CP_STAGE_SNAP_OK;c++)assert(strlen(cp_stage_snapshot_error(c))>3);
    assert(strstr(cp_stage_snapshot_error(CP_STAGE_SNAP_ERR_ENGINE),"engine version"));
    /* DT0 state is hashed only when it differs from the default */
    reset();
    const uint64_t plain=cp_stage_hash(&w);
    w.motion.jog_k*=1.5f;
    assert(cp_stage_hash(&w)!=plain);
    w.motion=CP_STAGE_MOTION;
    assert(cp_stage_hash(&w)==plain);
    w.debug_flags=1;
    assert(cp_stage_hash(&w)!=plain);
    w.debug_flags=0;
    assert(cp_stage_hash(&w)==plain&&w.field==NULL&&w.field_hash==0);
    /* the layout fingerprint is stable inside one build */
    assert(cp_stage_layout()==cp_stage_layout()&&cp_stage_layout()!=0);
    puts("PASS golden logs, snapshot/restore round trips, snapshot errors and hash compatibility");
}
/* ---- FIELD mode (PLAN-heights H1): a synthetic 64x64 island, cell 4 m ---- */
#define FN 64
#define FCELL 4.f
static float fh[FN*FN],fl_[FN*FN];
static CpStageField fld;
static float cc(int i){ return -128.f+(i+.5f)*FCELL; }
static void field_build(int kind){
    memset(fl_,0,sizeof fl_);
    for(int j=0;j<FN;j++)for(int i=0;i<FN;i++){
        float h;
        if(kind==0)h=20+.17632698f*cc(j);               /* 10 degree plane rising with z */
        else{
            h=10;
            if(i>=40&&i<=47&&j>=40)h+=j==40?6.93f:13.86f;   /* ~60 degree wall band across +z */
            if(i<=9&&j>=44)h=10-2.f*(float)(j-44);          /* sea: shore slope 0.5, dry to -6 */
            if(i>=20&&i<=23&&j>=20&&j<=23){h=9;fl_[j*FN+i]=12;}  /* pond 3 m deep */
            else if(fl_[j*FN+i]==0)fl_[j*FN+i]=h;
        }
        fh[j*FN+i]=h;
    }
    fld=(CpStageField){FN,FN*FCELL,FCELL,FN*FCELL/2,fh,fl_,0x1234abcdULL+kind};
}
static float ref_ground(const CpStageField *f,float x,float z){   /* independent copy of the documented formula */
    float u=(x+f->half)/f->cell-.5f,v=(z+f->half)/f->cell-.5f;
    int i=(int)floorf(u),j=(int)floorf(v);
    if(i<0)i=0;
    if(i>f->n-2)i=f->n-2;
    if(j<0)j=0;
    if(j>f->n-2)j=f->n-2;
    float fu=u-i,fv=v-j;
    fu=fu<0?0:fu>1?1:fu;fv=fv<0?0:fv>1?1:fv;
    const float *h=f->height+j*f->n+i;
    return fu>=fv?h[0]+fu*(h[1]-h[0])+fv*(h[f->n+1]-h[1]):h[0]+fv*(h[f->n]-h[0])+fu*(h[f->n+1]-h[f->n]);
}
static void field_world(float nx,float nz,int n_wild){
    cp_stage_setup_default(&setup,42);
    setup.terrain=CP_STAGE_FIELD;
    setup.n=n_wild;
    setup.nest_x=nx;setup.nest_z=nz;
    setup.wild[0].x=setup.wild[0].home_x=nx+30;
    setup.wild[0].z=setup.wild[0].home_z=nz;
    memset(&w,0,sizeof w);
    assert(cp_stage_attach_field(&w,&fld)==0);
    assert(cp_stage_reset(&w,&setup)==0);
}
static float walk_dist(float hx,float hz,int ticks){
    CpStageInput a={.verb=CP_STAGE_HEADING};
    a.hx=(int16_t)hx;a.hz=(int16_t)hz;
    float x0=w.player.x,z0=w.player.z;
    for(int i=0;i<ticks;i++)cp_stage_step(&w,&a);
    return sqrtf((w.player.x-x0)*(w.player.x-x0)+(w.player.z-z0)*(w.player.z-z0));
}
static void field_mode(void){
    /* reset needs a field */
    cp_stage_setup_default(&setup,42);
    setup.terrain=CP_STAGE_FIELD;
    memset(&w,0,sizeof w);
    assert(cp_stage_reset(&w,&setup)==-1);
    field_build(0);
    assert(cp_stage_attach_field(&w,NULL)==0&&cp_stage_reset(&w,&setup)==-1);
    CpStageField broken=fld;broken.n=1;
    assert(cp_stage_attach_field(&w,&broken)<0);
    broken=fld;broken.height=NULL;assert(cp_stage_attach_field(&w,&broken)<0);
    /* the plane: ground equals the independent formula bit for bit at 1000 points (and the analytic plane within 1 mm) */
    field_world(0,-60,1);
    assert(fabsf(cp_stage_bound(&w)-(128-2*FCELL))<1e-4f);
    unsigned long s=12345;
    float worst=0;
    for(int k=0;k<1000;k++){
        s=s*6364136223846793005ULL+1442695040888963407ULL;
        float x=((s>>33)%2800)/10.f-140,z;
        s=s*6364136223846793005ULL+1442695040888963407ULL;
        z=((s>>33)%2800)/10.f-140;
        assert(cp_stage_ground(&w,x,z)==ref_ground(&fld,x,z));
        assert(cp_stage_height(&w,x,z)==cp_stage_ground(&w,x,z));
        if(fabsf(x)<120&&fabsf(z)<120){
            float e=fabsf(cp_stage_ground(&w,x,z)-(20+.17632698f*z));
            if(e>worst)worst=e;
        }
    }
    assert(worst<1e-3f);
    assert(isfinite(cp_stage_ground(&w,1e30f,-1e30f))&&isfinite(cp_stage_ground(&w,-1e30f,1e30f)));
    /* walking uphill (10 degrees) is slower than along the contour by the walk() slope factor */
    field_world(0,-60,0);
    walk_dist(32767,0,40);
    float flat=walk_dist(32767,0,30);
    field_world(0,-60,0);
    walk_dist(0,32767,40);
    float up=walk_dist(0,32767,30);
    /* walk(): step = v/(1+.65*slope), and the eased speed is the reduced one, so the steady ratio is
     * (ease/(1-(1-ease)/(1+k)))/(1+k) with k = .65*tan(10 deg) (about .84), not just 1/(1+k) */
    const float k=.65f*.17632698f,ease=CP_STAGE_MOTION.ease,predicted=(ease/(1-(1-ease)/(1+k)))/(1+k);
    assert(up<flat&&fabsf(up/flat-predicted)<.015f);
    /* wall, pond, sea */
    field_build(1);
    field_world(40,-20,0);
    float before=w.player.z;
    walk_dist(0,32767,120);   /* straight into the wall band at z ~ 34 */
    assert(w.player.z>before+30&&w.player.z<cc(40)&&cp_stage_ground(&w,w.player.x,w.player.z)<13); /* nibbles at the foot of the ramp, never climbs the 60 degree face */
    assert(!cp_stage_can_walk(&w,40,cc(39),40,cc(41),.6f));
    assert(cp_stage_can_walk(&w,40,-20,40,0,.6f));
    /* pond: shallow depression, blocked only by the water */
    assert(fabsf(cp_stage_water_depth(&w,cc(21),cc(21))-3)<1e-4f);
    assert(cp_stage_ground(&w,cc(21),cc(21))==9);
    assert(!cp_stage_can_walk(&w,cc(21),cc(15),cc(21),cc(21),.6f));
    assert(cp_stage_can_walk(&w,cc(21),cc(15),cc(21),cc(18),.6f));
    assert(cp_stage_water_depth(&w,cc(30),cc(30))==0);
    /* sea: deeper than 0.7 m blocks, wading does not (rows: j=49 -> 0 m, 50 -> -2, shore slope .5) */
    field_world(-100,cc(40),0);
    assert(cp_stage_water_depth(&w,cc(5),cc(49))==0&&fabsf(cp_stage_water_depth(&w,cc(5),cc(50))-2)<1e-4f);
    assert(cp_stage_can_walk(&w,cc(5),cc(44),cc(5),cc(48),.6f));
    float ground_at=cp_stage_ground(&w,cc(5),cc(49)+1.f);   /* about -0.25 m: wading */
    assert(ground_at<0&&ground_at>-.7f&&cp_stage_can_walk(&w,cc(5),cc(48),cc(5),cc(49)+1.f,.6f));
    assert(!cp_stage_can_walk(&w,cc(5),cc(49),cc(5),cc(51),.6f));   /* nearest cell j=51 is 4 m deep */
    assert(!cp_stage_can_walk(&w,cc(5),cc(45),cc(5),cc(53),.6f));
    /* bounds: nest and orders outside half-2*cell are rejected */
    field_build(1);
    setup.nest_x=121;
    assert(cp_stage_reset(&w,&setup)<0);
    field_world(0,0,0);
    assert(cp_stage_command(&w,"go 119 0")==0&&cp_stage_command(&w,"go 121 0")<0);
    /* determinism: two identical runs agree; another field hash changes the state hash; flat hashes untouched */
    field_world(0,-60,1);
    CpStageWorld second=w;
    uint64_t h1=0,h2=0;
    for(int i=0;i<300;i++){
        CpStageInput a={.verb=CP_STAGE_HEADING,.hx=(int16_t)(i*97-12000),.hz=20000};
        h1=cp_stage_step(&w,&a);h2=cp_stage_step(&second,&a);
        assert(h1==h2);
    }
    field_world(0,-60,1);
    uint64_t base=cp_stage_hash(&w);
    CpStageField other_field=fld;other_field.hash^=1;
    memset(&second,0,sizeof second);
    cp_stage_attach_field(&second,&other_field);
    assert(cp_stage_reset(&second,&setup)==0&&cp_stage_hash(&second)!=base);
    /* snapshot of a FIELD world needs the field back */
    static uint8_t blob[1<<16];
    for(int i=0;i<20;i++)cp_stage_step(&w,NULL);
    int n=cp_stage_snapshot(&w,blob,sizeof blob);
    assert(n>0);
    assert(cp_stage_restore(&second,blob,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_FIELD);
    assert(cp_stage_restore(&second,blob,(size_t)n,&other_field)==CP_STAGE_SNAP_ERR_FIELD);
    assert(cp_stage_restore(&second,blob,(size_t)n,&fld)==CP_STAGE_SNAP_OK&&cp_stage_hash(&second)==cp_stage_hash(&w)&&second.field==&fld);
    for(int i=0;i<50;i++)assert(cp_stage_step(&w,NULL)==cp_stage_step(&second,NULL));
    /* a world last used in FIELD mode drops the field when reset flat */
    setup.terrain=CP_STAGE_FLAT;setup.nest_x=setup.nest_z=0;
    assert(cp_stage_reset(&w,&setup)==0&&w.field==NULL&&w.field_hash==0);
    puts("PASS field mode: ground formula, slope, wall, pond, sea, bound, determinism, snapshot");
}
int main(void) {
    validation();
    motion_law();
    terrain_and_hash();
    encounters();
    multiple_creatures();
    agent_contract();
    numeric_boundaries();
    snapshots();
    field_mode();
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
