#include "cpore/world.h"
#include "cpore/steer.h"
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
    setup.wild[0].profile=(CpCombatProfile){2,1,0,1,0,100,100,4,0,0};setup.wild[0].bot=2;
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
    setup.n=CP_STAGE_MAX_WILD+1;
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
    setup.wild[0].species=CP_STAGE_SPECIES_DEFINED;
    assert(cp_stage_reset(&w,&setup)<0);
    setup=valid;
    setup.wild[0].bot=6;
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
    w.tick=CP_STAGE_GRACE_TICKS; /* encounter rules after the new-game grace minute */
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
    char obs[16384];
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"carcass"));
    assert(cp_stage_command(&w,"attack #1 0")<0);
    reset();
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    w.tick=CP_STAGE_GRACE_TICKS; /* encounter rules after the new-game grace minute */
    cp_stage_step(&w,NULL);
    w.combat.c[0].hp=.1f;
    w.combat.c[0].bleed_t=2;
    cp_stage_step(&w,NULL);
    assert(w.outcome==CP_STAGE_DEATH && w.respawn_ticks==20);
    for(int i=0;i<20;i++)cp_stage_step(&w,NULL);
    assert(w.player.hp==setup.player.hp*3.f/5.f && w.player.x==setup.nest_x);
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
    w.tick=CP_STAGE_GRACE_TICKS; /* encounter rules after the new-game grace minute */
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
    w.tick=CP_STAGE_GRACE_TICKS; /* AI encounter after the grace minute */
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
    assert(strstr(obs,"\"stamina_cost\"")&&strstr(obs,"\"range_m\"")&&strstr(obs,"\"windup_ticks\"")&&strstr(obs,"\"usable\":true")&&strstr(obs,"\"attackable\":false"));
    assert(cp_stage_command(&w,"attack #1 BITE")==0&&w.order.move==CB_BITE);
    assert(cp_stage_command(&w,"attack #1 0")==0&&w.order.move==CB_BITE);
    assert(cp_stage_command(&w,"attack #1 atack")<0);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0&&strstr(obs,"\"last_error\":\"unknown_move\""));
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
    const int bad_counts[]={-1,CP_STAGE_MAX_WILD+1};
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
/* speed by body size (A39): v = sqrt(Fr g h), h = 0.56 * body radius */
static float law_speed(float fr,const CpCombatProfile *p){return sqrtf(fr*9.81f*.56f*cp_combat_body_radius(p));}
static void motion_law(void) {
    const CpStageMotion *m=&CP_STAGE_MOTION;
    for(int sprint=0;sprint<2;sprint++) {
        reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
        float jog=law_speed(.24f,&setup.player)*m->jog_k,top=sprint?law_speed(m->sprint_k,&setup.player)*m->jog_k:jog,old=0,last_dyaw_limit=.7f;
        int t90=-1;
        CpStageInput a=heading_to(w.player.fx,w.player.fz,sprint);
        for(int i=1;i<=40;i++) {
            cp_stage_step(&w,&a);
            assert(w.player.speed-old<=m->accel*1.7f*.1f+1e-3f);   /* A54: a run bursts at 1.7x the cap */
            if(t90<0&&w.player.speed>=.9f*top)t90=i;
            old=w.player.speed;
        }
        assert(fabsf(w.player.speed-top)<.01f);
        assert(t90>0&&t90<=(sprint?12:6));   /* A54: softer start, 90% of the speed in about half a second (accel 7, ease .45) */
        assert(!w.player.pivot&&last_dyaw_limit>0);
    }
    /* A reversal at full jog is a skid, not a turret spin: the pivot flag stays off while v > pivot_v. */
    reset();setup.n=0;setup.player.radius_cm=340;assert(cp_stage_reset(&w,&setup)==0);
    float jog=law_speed(.24f,&setup.player)*m->jog_k;
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
    /* A pivot (bodies up to pivot_r) from near rest reverses within ceil(pi/(rate*.1))+1 ticks plus the yaw ramp (steering v3). */
    reset();setup.n=0;setup.player.radius_cm=120;assert(cp_stage_reset(&w,&setup)==0);
    a=heading_to(w.player.fx,w.player.fz,0);
    for(int i=0;i<2;i++)cp_stage_step(&w,&a);
    a=(CpStageInput){.verb=CP_STAGE_WAIT};
    for(int i=0;i<20&&w.player.speed>0;i++)cp_stage_step(&w,&a);
    assert(w.player.speed==0);
    fx0=w.player.fx;fz0=w.player.fz;
    float r=cp_combat_body_radius(&w.player.profile),turn0=fminf(m->turn_max,fmaxf(m->turn_min,m->turn_k*sqrtf(9.81f/r)));
    float pr=fminf(m->pivot_max,fmaxf(3,m->pivot_mul*turn0));
    int ticks=(int)ceilf(3.14159265f/(pr*.1f))+1+(int)ceilf(pr/(w.motion.ang_k*9.81f/r)/.1f),ok=0;
    a=heading_to(-fx0,-fz0,0);
    for(int i=0;i<ticks;i++)cp_stage_step(&w,&a);
    ok=w.player.fx*fx0+w.player.fz*fz0<-.98f;
    assert(ok);
    /* Radius of a held heading 90 degrees off, at jog, radius_cm 340. The radius is v / yaw rate, and v is now the hero's 2 m/s walk
     * (Fr 0.24, A39) instead of 5.2 m/s, so it fell from 1.4 m to ~0.6 m: a walking body turns tighter than a running one. At least 0.5 m. */
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
    assert(sp/rate>=.5f);
    printf("world motion law: jog %.2f sprint %.2f, circle radius %.2f m\n",jog,law_speed(m->sprint_k,&setup.player)*m->jog_k,sp/rate);
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
static CpStageDebugEntry golden_dbg[64];
static int golden_ndbg;
static void load_golden_stem(const char *stem,CpStageSetup *su){
    char path[96];
    snprintf(path,sizeof path,"tests/golden/%s.log",stem);
    FILE *f=fopen(path,"r");
    assert(f);
    char magic[32];int version,ticks;
    assert(fscanf(f,"%31s%d",magic,&version)==2&&!strcmp(magic,"CPORE_WORLD_LOG")&&(version==2||version==3));
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
    golden_ndbg=0;
    if(version==3){
        assert(fscanf(f,"%d",&golden_ndbg)==1&&golden_ndbg>=0&&golden_ndbg<=64);
        for(int i=0;i<golden_ndbg;i++){
            CpStageDebugEntry *e=&golden_dbg[i];
            assert(fscanf(f,"%u%d%d%d%f%f%f",&e->tick,&e->d.op,&e->d.id,&e->d.a,&e->d.x,&e->d.z,&e->d.v)==7);
        }
    }
    fclose(f);
    snprintf(path,sizeof path,"tests/golden/%s.hashes",stem);
    f=fopen(path,"r");
    assert(f);
    for(int i=0;i<GOLDEN_TICKS;i++){
        unsigned long long h;
        assert(fscanf(f,"%16llx",&h)==1);
        golden_hash[i]=h;
    }
    fclose(f);
}
static void load_golden(unsigned seed,CpStageSetup *su){
    char stem[48];
    snprintf(stem,sizeof stem,"world-%u",seed);
    load_golden_stem(stem,su);
}
static CpStageWorld snap_a,snap_b;
static void snapshots(void){
    assert(cp_stage_world_size()==sizeof(CpStageWorld));
    assert(cp_stage_snapshot_size()==48+offsetof(CpStageWorld,field));
    static uint8_t blob[48+offsetof(CpStageWorld,field)],again[48+offsetof(CpStageWorld,field)];
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
            char oa[32768],ob[32768];
            assert(cp_stage_observe(&snap_a,oa,sizeof oa)>0&&cp_stage_observe(&snap_b,ob,sizeof ob)>0&&!strcmp(oa,ob));
        }
    }
    /* (d) every error code */
    reset();
    for(int i=0;i<50;i++)cp_stage_step(&w,NULL);
    int n=cp_stage_snapshot(&w,blob,sizeof blob);
    assert(n>0);
    const uint64_t before=cp_stage_hash(&snap_b);
    uint8_t bad[48+offsetof(CpStageWorld,field)];
    memcpy(bad,blob,(size_t)n);bad[0]='X';
    assert(cp_stage_restore(&snap_b,bad,(size_t)n,NULL)==CP_STAGE_SNAP_ERR_MAGIC);
    memcpy(bad,blob,(size_t)n);bad[8]=CP_STAGE_SNAPSHOT_VERSION+1;
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
    /* the steady speed is the jog times the steer.c slope factor for a 10 degree grade (4 legs, the default body) */
    CpSteerBody body;
    cp_steer_body(&w.motion,cp_combat_body_radius(&w.player.profile),w.player.legs,&body);
    const float predicted=cp_steer_slope(&w.motion,&body,.17632698f);
    assert(up<flat&&fabsf(up/flat-predicted)<.015f);
    /* wall, pond, sea */
    field_build(1);
    field_world(40,-20,0);
    float before=w.player.z;
    walk_dist(0,32767,420);   /* straight into the wall band at z ~ 34 (the default 0.6 m body walks 0.9 m/s now, A39) */
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
    static uint8_t blob[48+offsetof(CpStageWorld,field)];
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
/* H2: fights on the island stop at the edge. */
static void field_fight(void){
    field_build(1);
    field_world(40,28,1);
    setup.wild[0].x=setup.wild[0].home_x=40;
    setup.wild[0].z=setup.wild[0].home_z=24;
    setup.wild[0].species=3;
    assert(cp_stage_reset(&w,&setup)==0);
    w.tick=CP_STAGE_GRACE_TICKS; /* this test exercises an established fight at a cliff */
    CpStageInput into={.verb=CP_STAGE_HEADING,.hx=0,.hz=32767};
    int fight_ticks=0;
    float pz_max=-1000;
    for(int i=0;i<80;i++){
        float px=w.player.x,pz=w.player.z,ex=w.wild[0].x,ez=w.wild[0].z;
        int was=w.active>=0;
        cp_stage_step(&w,&into);
        if(!(was&&w.active>=0))continue;   /* only ticks that began and ended inside the fight */
        fight_ticks++;
        const CpStageCreature *c[2]={&w.player,&w.wild[0]};
        const float ox[2]={px,ex},oz[2]={pz,ez};
        for(int k=0;k<2;k++){
            assert((c[k]->x==ox[k]&&c[k]->z==oz[k])||cp_stage_can_walk(&w,ox[k],oz[k],c[k]->x,c[k]->z,cp_combat_body_radius(&c[k]->profile)));
            assert(fabsf(c[k]->x-(w.arena_x+w.combat.c[k].x-20))<1e-4f&&fabsf(c[k]->z-(w.arena_z+w.combat.c[k].y-20))<1e-4f);
            assert(cp_stage_water_depth(&w,c[k]->x,c[k]->z)<=.7f&&cp_stage_ground(&w,c[k]->x,c[k]->z)<13);
        }
        if(w.player.z>pz_max)pz_max=w.player.z;
    }
    assert(fight_ticks>=20&&pz_max<cc(40)-.5f);   /* the player pressed into the wall for the whole fight and never crossed it */
    /* the same push on flat ground does go through (so the clamp is what stopped it) */
    cp_stage_setup_default(&setup,42);
    setup.terrain=CP_STAGE_FLAT;setup.flat_height=10;setup.nest_x=40;setup.nest_z=28;
    setup.wild[0].x=setup.wild[0].home_x=40;setup.wild[0].z=setup.wild[0].home_z=24;
    assert(cp_stage_reset(&w,&setup)==0);
    w.tick=CP_STAGE_GRACE_TICKS; /* this test exercises an established fight at a cliff */
    float far=0;
    for(int i=0;i<80;i++){cp_stage_step(&w,&into);if(w.player.z>far)far=w.player.z;}
    assert(far>cc(40));
    puts("PASS field fights stop at cliffs and water");
}
/* ---- debug ops (PLAN-devtools step 4) ---- */
static void dbg_op(int op,int id,int a,float x,float z,float v,int expect){
    CpStageDebug d={op,id,a,x,z,v};
    const uint64_t before=cp_stage_hash(&w);
    const int rc=cp_stage_debug(&w,&d);
    assert(rc==expect);
    if(expect<0){
        assert(cp_stage_hash(&w)==before);   /* a rejected op changes nothing */
        assert(strlen(cp_stage_debug_error(rc))>4);
    }
    else assert(w.hash==cp_stage_hash(&w));
}
static void debug_ops(void){
    reset();   /* FLAT, nest 0,0, one Garfio at (0,18), no water circle */
    setup.n=1;setup.water_x=60;setup.water_z=60;setup.water_radius=5;
    assert(cp_stage_reset(&w,&setup)==0);
    /* teleport */
    dbg_op(CP_STAGE_DBG_TELEPORT,0,0,30,-20,0,0);
    assert(w.player.x==30&&w.player.z==-20&&w.player.speed==0);
    dbg_op(CP_STAGE_DBG_TELEPORT,1,0,-40,10,0,0);
    assert(w.wild[0].x==-40&&w.wild[0].goal_x==-40&&w.wild[0].goal_z==10);
    dbg_op(CP_STAGE_DBG_TELEPORT,2,0,0,0,0,-1);            /* no such creature */
    dbg_op(CP_STAGE_DBG_TELEPORT,0,0,NAN,0,0,-1);
    dbg_op(CP_STAGE_DBG_TELEPORT,0,0,196,0,0,-4);          /* outside the bound */
    dbg_op(CP_STAGE_DBG_TELEPORT,0,0,60,60,0,-4);          /* inside the water circle */
    dbg_op(99,0,0,0,0,0,-1);
    /* spawn: no RNG draw, full world rejects */
    const CpRng spawn_before=w.spawn_rng,roam_before=w.roam_rng;
    dbg_op(CP_STAGE_DBG_SPAWN,0,3,10,10,0,0);
    assert(w.setup.n==2&&w.wild[1].species==3&&w.wild[1].home_x==10&&w.wild[1].roam_ticks==40&&w.setup.wild[1].bot==-1);
    assert(!memcmp(&spawn_before,&w.spawn_rng,sizeof spawn_before)&&!memcmp(&roam_before,&w.roam_rng,sizeof roam_before));
    dbg_op(CP_STAGE_DBG_SPAWN,0,CP_STAGE_SPECIES_DEFINED,10,10,0,-1);
    dbg_op(CP_STAGE_DBG_SPAWN,0,0,1000,0,0,-4);
    while(w.setup.n<CP_STAGE_MAX_WILD)dbg_op(CP_STAGE_DBG_SPAWN,0,0,-100-4.f*(float)(w.setup.n%8),-100-4.f*(float)(w.setup.n/8),0,0);   /* spaced: 32 slots no longer fit one spot */
    dbg_op(CP_STAGE_DBG_SPAWN,0,0,-100,-100,0,-3);
    /* kill, heal, clock, flags, param */
    dbg_op(CP_STAGE_DBG_KILL,2,0,0,0,0,0);
    assert(w.wild[1].dead);
    dbg_op(CP_STAGE_DBG_KILL,0,0,0,0,0,-1);
    dbg_op(CP_STAGE_DBG_KILL,CP_STAGE_MAX_WILD+1,0,0,0,0,-1);
    w.player.hp=10;w.player.stamina=3;
    dbg_op(CP_STAGE_DBG_HEAL,0,0,50,-1,0,0);
    assert(w.player.hp==50&&w.player.stamina==w.player.profile.stamina);
    dbg_op(CP_STAGE_DBG_HEAL,0,0,1e9f,10,0,0);
    assert(w.player.hp==w.player.profile.hp&&w.player.stamina==10);
    dbg_op(CP_STAGE_DBG_HEAL,0,0,0,10,0,-1);
    dbg_op(CP_STAGE_DBG_HEAL,2,0,10,10,0,-1);               /* the dead are not healed */
    dbg_op(CP_STAGE_DBG_CLOCK,0,5000,0,0,0,0);
    assert(w.clock==5000);
    dbg_op(CP_STAGE_DBG_CLOCK,0,CP_STAGE_DAY_TICKS,0,0,0,-1);
    dbg_op(CP_STAGE_DBG_FLAGS,0,4,0,0,0,-1);
    dbg_op(CP_STAGE_DBG_FLAGS,0,3,0,0,0,0);
    assert(w.debug_flags==3);
    dbg_op(CP_STAGE_DBG_FLAGS,0,0,0,0,0,0);
    assert(CP_STAGE_PARAM_COUNT==28&&!strcmp(CP_STAGE_PARAMS[0].name,"jog_k"));
    for(int i=0;i<CP_STAGE_PARAM_COUNT;i++){
        const float def=*(const float *)((const char *)&CP_STAGE_MOTION+CP_STAGE_PARAMS[i].offset);
        assert(def>=CP_STAGE_PARAMS[i].min&&def<=CP_STAGE_PARAMS[i].max&&!strcmp(CP_STAGE_PARAMS[i].group,"movement"));
    }
    dbg_op(CP_STAGE_DBG_PARAM,0,0,0,0,100,0);
    assert(w.motion.jog_k==CP_STAGE_PARAMS[0].max);
    dbg_op(CP_STAGE_DBG_PARAM,0,CP_STAGE_PARAM_COUNT,0,0,1,-1);
    dbg_op(CP_STAGE_DBG_PARAM,0,0,0,0,NAN,-1);
    /* during a fight: the fighters cannot be teleported or killed, but can be healed */
    reset();
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    w.tick=CP_STAGE_GRACE_TICKS; /* AI encounter after the grace minute */
    cp_stage_step(&w,NULL);
    assert(w.active==0);
    dbg_op(CP_STAGE_DBG_TELEPORT,0,0,5,5,0,-2);
    dbg_op(CP_STAGE_DBG_TELEPORT,1,0,5,5,0,-2);
    dbg_op(CP_STAGE_DBG_KILL,1,0,0,0,0,-2);
    w.combat.c[0].hp=5;
    dbg_op(CP_STAGE_DBG_HEAL,0,0,60,-1,0,0);
    assert(w.combat.c[0].hp==60&&w.player.hp==60);
    /* GOD survives a fight it would lose, and AI_OFF freezes the wild */
    uint64_t plain_hash=0,god_hash=0;
    for(int god=0;god<2;god++){
        reset();
        setup.wild[0].z=setup.wild[0].home_z=4;
        assert(cp_stage_reset(&w,&setup)==0);
        w.tick=CP_STAGE_GRACE_TICKS; /* the god-mode test starts after the grace minute */
        if(god)dbg_op(CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_GOD,0,0,0,0);
        cp_stage_step(&w,NULL);
        w.combat.c[0].hp=.1f;
        w.combat.c[0].bleed_t=2;
        for(int i=0;i<30;i++)cp_stage_step(&w,NULL);
        if(god){
            assert(w.outcome!=CP_STAGE_DEATH&&w.player.hp>=1&&w.respawn_ticks==0);
            god_hash=cp_stage_hash(&w);
        }
        else{
            assert(w.outcome==CP_STAGE_DEATH);
            plain_hash=cp_stage_hash(&w);
        }
    }
    assert(god_hash!=plain_hash);
    reset();
    setup.wild[0].species=0;setup.wild[0].z=setup.wild[0].home_z=30;
    assert(cp_stage_reset(&w,&setup)==0);
    other=w;
    dbg_op(CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0,0);
    const float ex=w.wild[0].x,ez=w.wild[0].z;
    for(int i=0;i<100;i++){cp_stage_step(&w,NULL);cp_stage_step(&other,NULL);}
    assert(w.wild[0].x==ex&&w.wild[0].z==ez);
    assert(other.wild[0].x!=ex||other.wild[0].z!=ez);   /* with the AI on it roams */
    /* the new golden log: the replay_ex path reproduces the hashes world_cli printed, and a snapshot start does too */
    CpStageSetup su;
    load_golden_stem("world-debug-42",&su);
    assert(golden_ndbg==10);
    CpStageLogEntry log[GOLDEN_TICKS];
    for(int i=0;i<GOLDEN_TICKS;i++)log[i]=(CpStageLogEntry){(uint32_t)i,golden_in[i]};
    static uint64_t hashes[GOLDEN_TICKS];
    assert(cp_stage_replay_ex(&su,NULL,0,NULL,log,GOLDEN_TICKS,golden_dbg,golden_ndbg,GOLDEN_TICKS,hashes)!=0);
    for(int i=0;i<GOLDEN_TICKS;i++)assert(hashes[i]==golden_hash[i]);
    /* live run with the same ops applied through cp_stage_debug between steps equals the replay */
    assert(cp_stage_reset(&w,&su)==0);
    int cur=0;
    for(int i=0;i<GOLDEN_TICKS;i++){
        while(cur<golden_ndbg&&golden_dbg[cur].tick==(uint32_t)i)assert(cp_stage_debug(&w,&golden_dbg[cur++].d)==0);
        assert(cp_stage_step(&w,&log[i].input)==hashes[i]);
        if(i==1499){   /* snapshot mid-run, continue from it with the remaining ops */
            static uint8_t blob[48+offsetof(CpStageWorld,field)];
            int n=cp_stage_snapshot(&w,blob,sizeof blob);
            assert(n>0);
            CpStageLogEntry tail[GOLDEN_TICKS];int nt=0;
            CpStageDebugEntry dtail[16];int nd=0;
            for(int k=1500;k<GOLDEN_TICKS;k++)tail[nt++]=log[k];
            for(int k=0;k<golden_ndbg;k++)if(golden_dbg[k].tick>=1500)dtail[nd++]=golden_dbg[k];
            static uint64_t h2[GOLDEN_TICKS];
            assert(cp_stage_replay_ex(NULL,blob,(size_t)n,NULL,tail,nt,dtail,nd,1500,h2)!=0);
            for(int k=0;k<1500;k++)assert(h2[k]==hashes[1500+k]);
        }
    }
    puts("PASS debug ops, god, ai off, param, replay_ex and the world-debug-42 golden");
}
/* ---- C1-nav: last_error, events, blocked, no_threat, the walkable-square clamp in fights, world-1 text ---- */
static void nav_contract(void) {
    char obs[16384];
    reset();
    assert(cp_stage_command(&w,"bogus")<0);
    assert(w.last_error==-1);
    cp_stage_step(&w,NULL);cp_stage_step(&w,NULL);
    assert(w.last_error==-1);                       /* a step with no input keeps the last error */
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"schema\":\"world-2\"") && strstr(obs,"\"last_error\":\"invalid command or value\""));
    assert(strstr(obs,"\"blocked\":null") && strstr(obs,"\"order_rejected\"") && strstr(obs,"\"world\":{\"bound\":195.000000"));
    cp_stage_ack_events(&w);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"events\":[]"));
    assert(cp_stage_command(&w,"wait")==0 && w.last_error==0);
    assert(cp_stage_observe_v(&w,obs,sizeof obs,1)>0 && strstr(obs,"world-1") && !strstr(obs,"events") && !strstr(obs,"in_fight"));
    assert(cp_stage_observe_v(&w,obs,sizeof obs,3)<0);
    /* flee with no creature within 30 m: rejected by the text API, accepted but flagged by the struct API */
    setup.wild[0].x=setup.wild[0].home_x=120;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(cp_stage_command(&w,"flee")==-5 && w.last_error==-5 && !strcmp(cp_stage_order_error(-5),"no_threat"));
    CpStageInput f={.verb=CP_STAGE_FLEE};
    assert(cp_stage_order(&w,&f)==0 && w.last_error==-5);
    /* blocked: walking east into the edge of the square names the reason and never passes the bound */
    reset();
    setup.nest_x=194;
    setup.wild[0].x=setup.wild[0].home_x=-100;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(cp_stage_command(&w,"heading 90")==0);
    int seen=0;
    for(int i=0;i<60;i++){
        cp_stage_step(&w,NULL);
        assert(fabsf(w.player.x)<=195.f);
        if(w.blocked_reason==CP_STAGE_BLOCK_EDGE)seen=1;
    }
    assert(seen);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"blocked\":{\"reason\":\"edge\""));
    /* a fight: hit events with who/what/how much, then a kill, and the nearby entry shows hp and state */
    reset();
    setup.wild[0].z=setup.wild[0].home_z=4;
    assert(cp_stage_reset(&w,&setup)==0);
    w.tick=CP_STAGE_GRACE_TICKS; /* AI encounter after the grace minute */
    cp_stage_step(&w,NULL);
    assert(w.active==0);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"state\":\"fighting\"") && strstr(obs,"\"in_fight\":true") && strstr(obs,"\"hp_max\""));
    CpStageInput a={.verb=CP_STAGE_ATTACK,.target=1,.move=0};
    int hits=0;
    for(int i=0;i<200&&w.outcome==CP_STAGE_NONE;i++)cp_stage_step(&w,&a);
    for(uint32_t k=0;k<w.ev_total&&k<CP_STAGE_MAX_EVENTS;k++)hits+=w.events[k].type==CP_STAGE_EV_HIT;
    assert(hits>0&&w.outcome!=CP_STAGE_NONE);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"type\":\"hit\"") && (strstr(obs,"\"type\":\"kill\"")||strstr(obs,"\"type\":\"death\"")));
    /* fighters at the edge of the square are held inside it (agentplay saw 195.7) */
    reset();
    setup.nest_x=194;
    setup.wild[0].x=setup.wild[0].home_x=194;
    setup.wild[0].z=setup.wild[0].home_z=3;
    assert(cp_stage_reset(&w,&setup)==0);
    a=(CpStageInput){.verb=CP_STAGE_HEADING,.hx=32767};
    for(int i=0;i<200;i++){
        cp_stage_step(&w,&a);
        assert(fabsf(w.player.x)<=195.001f&&fabsf(w.wild[0].x)<=195.001f);
    }
}

static int cmd(CpStageWorld *x,const char *text){
    return cp_stage_command(x,text);
}
static void loadout_contract(void){
    reset();
    const uint64_t h0=cp_stage_hash(&w);
    char obs[16384];
    assert(cp_stage_observe(&w,obs,sizeof obs)>0);
    assert(strstr(obs,"\"loadout\":{\"slots\":[\"bite\",\"charge\",\"spit\",\"tail_strike\"],\"signature_slot\":null,\"can_edit\":true"));
    assert(strstr(obs,"\"known_moves\":[\"bite\",\"charge\",\"spit\",\"tail_strike\"]"));
    assert(strstr(obs,"\"role\":\"basic\"") && strstr(obs,"\"equipped\":true,\"slot\":1,"));
    assert(strstr(obs,"\"cooldown_ticks\":0,\"cooldown_left\":0"));
    /* errors, each with its own name */
    assert(cmd(&w,"loadout 5 bite")==CP_STAGE_ERR_BAD_SLOT && cmd(&w,"loadout 0 bite")==CP_STAGE_ERR_BAD_SLOT);
    assert(cmd(&w,"loadout 1 dance")==CP_STAGE_ERR_UNKNOWN_MOVE && cmd(&w,"loadout 1 guard")==CP_STAGE_ERR_UNKNOWN_MOVE && cmd(&w,"loadout 1 dodge")==CP_STAGE_ERR_UNKNOWN_MOVE);
    assert(!strcmp(cp_stage_order_error(w.last_error),"unknown_move"));
    assert(cp_stage_hash(&w)==h0);                          /* rejected orders change nothing */
    setup.player.spit=0;
    assert(cp_stage_reset(&w,&setup)==0);
    assert(cmd(&w,"loadout 1 spit")==CP_STAGE_ERR_NOT_KNOWN);
    assert(!strcmp(cp_stage_order_error(w.last_error),"not_known"));
    assert(w.loadout.slot[0]==CB_BITE && w.loadout.slot[1]==CB_CHARGE && w.loadout.slot[2]==CB_TAIL_STRIKE && w.loadout.slot[3]==CB_MOVE_NONE);
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"slots\":[\"bite\",\"charge\",\"tail_strike\",null]") && !strstr(obs,"\"known_moves\":[\"bite\",\"charge\",\"spit\""));
    reset();
    /* change, hash, restore */
    assert(cmd(&w,"loadout 1 none")==0 && cmd(&w,"loadout 1 tail_strike")==0);
    assert(w.loadout.slot[0]==CB_TAIL_STRIKE && w.loadout.slot[3]==CB_MOVE_NONE);
    assert(cp_stage_hash(&w)!=h0 && w.hash==cp_stage_hash(&w));
    assert(cmd(&w,"loadout 4 3")==0 && w.loadout.slot[3]==CB_SPIT && w.loadout.slot[2]==CB_MOVE_NONE);
    assert(cmd(&w,"loadout 1 bite")==0 && cmd(&w,"loadout 3 spit")==0 && cmd(&w,"loadout 4 tail_strike")==0);
    assert(w.loadout.slot[0]==CB_BITE && w.loadout.slot[2]==CB_SPIT && w.loadout.slot[3]==CB_TAIL_STRIKE);
    assert(cp_stage_hash(&w)==h0);                          /* back to the default loadout: the default hash */
    /* not_equipped outside a fight */
    assert(cmd(&w,"loadout 2 none")==0);
    assert(cmd(&w,"attack #1 charge")==CP_STAGE_ERR_NOT_EQUIPPED && !strcmp(cp_stage_order_error(w.last_error),"not_equipped"));
    assert(cmd(&w,"attack #1 bite")==0);
    /* away from the nest */
    CpStageDebug tp={CP_STAGE_DBG_TELEPORT,0,0,CP_STAGE_NEST_RADIUS+2,0,0};
    assert(cp_stage_debug(&w,&tp)==0);
    const uint64_t far=cp_stage_hash(&w);
    assert(cmd(&w,"loadout 2 charge")==CP_STAGE_ERR_NOT_AT_NEST && !strcmp(cp_stage_order_error(w.last_error),"not_at_nest"));
    assert(cp_stage_hash(&w)==far && w.loadout.slot[1]==CB_MOVE_NONE);
    tp.x=CP_STAGE_NEST_RADIUS-1;
    assert(cp_stage_debug(&w,&tp)==0 && cmd(&w,"loadout 2 charge")==0);
    /* a fight is played with the kit brought; no edits during it */
    reset();
    assert(cmd(&w,"loadout 4 none")==0);
    tp.x=0;tp.z=0;
    CpStageInput in={0};
    in.verb=CP_STAGE_ATTACK;in.target=1;in.move=CB_BITE;
    for(int i=0;i<300&&w.active<0;i++)cp_stage_step(&w,&in);
    assert(w.active>=0);
    assert(w.combat.c[0].lo.slot[3]==CB_MOVE_NONE && w.combat.c[0].lo.slot[0]==CB_BITE);
    assert(cmd(&w,"loadout 4 tail_strike")==CP_STAGE_ERR_IN_FIGHT && !strcmp(cp_stage_order_error(w.last_error),"in_fight"));
    assert(cmd(&w,"attack #1 tail_strike")==CP_STAGE_ERR_NOT_EQUIPPED);
    w.combat.c[0].cd[CB_BITE]=5;
    assert(cmd(&w,"attack #1 bite")==CP_STAGE_ERR_ON_COOLDOWN && !strcmp(cp_stage_order_error(w.last_error),"on_cooldown"));
    assert(cp_stage_observe(&w,obs,sizeof obs)>0 && strstr(obs,"\"cooldown_left\":5") && strstr(obs,"\"can_edit\":false"));
    /* struct input path and the observation mirror */
    reset();
    CpStageInput lo={0};
    lo.verb=CP_STAGE_LOADOUT;lo.target=3;lo.move=CB_MOVE_NONE;
    assert(cp_stage_order(&w,&lo)==0 && w.loadout.slot[2]==CB_MOVE_NONE);
    lo.target=0;assert(cp_stage_order(&w,&lo)==CP_STAGE_ERR_BAD_SLOT);
    lo.target=1;lo.move=-2;assert(cp_stage_order(&w,&lo)==CP_STAGE_ERR_UNKNOWN_MOVE);
    lo.move=CB_MOVE_COUNT;assert(cp_stage_order(&w,&lo)==CP_STAGE_ERR_UNKNOWN_MOVE);
    /* determinism: a replay with loadout orders, and a snapshot taken mid-run with a custom loadout */
    reset();
    enum{N=400};
    static CpStageLogEntry log[8];
    int n=0;
    log[n++]=(CpStageLogEntry){5,{.verb=CP_STAGE_LOADOUT,.target=2,.move=CB_MOVE_NONE}};
    log[n++]=(CpStageLogEntry){40,{.verb=CP_STAGE_LOADOUT,.target=2,.move=CB_SPIT}};
    log[n++]=(CpStageLogEntry){60,{.verb=CP_STAGE_ATTACK,.target=1,.move=CB_SPIT}};
    log[n++]=(CpStageLogEntry){90,{.verb=CP_STAGE_LOADOUT,.target=1,.move=CB_MOVE_NONE}};
    static uint64_t live[N],rep[N];
    static CpStageWorld mid,tail;
    static uint8_t blob[48+offsetof(CpStageWorld,field)];
    int cur=0;
    for(int i=0;i<N;i++){
        while(cur<n&&log[cur].tick==(uint32_t)i)cp_stage_order(&w,&log[cur++].input);
        live[i]=cp_stage_step(&w,NULL);
        if(i==70){
            assert(cp_stage_snapshot(&w,blob,sizeof blob)==(int)cp_stage_snapshot_size());
            mid=w;
        }
    }
    uint64_t fin=cp_stage_replay(&setup,log,n,N,rep);
    for(int i=0;i<N;i++)assert(live[i]==rep[i]);
    assert(fin==cp_stage_hash(&w));
    assert(cp_stage_restore(&tail,blob,cp_stage_snapshot_size(),NULL)==CP_STAGE_SNAP_OK);
    assert(cp_stage_hash(&tail)==cp_stage_hash(&mid));
    assert(tail.loadout.slot[1]==CB_SPIT);
    cur=3;
    for(int i=71;i<N;i++){
        while(cur<n&&log[cur].tick==(uint32_t)i)cp_stage_order(&tail,&log[cur++].input);
        assert(cp_stage_step(&tail,NULL)==live[i]);
    }
    assert(cp_stage_hash(&tail)==cp_stage_hash(&w));
    /* an old snapshot version is refused with the format error */
    blob[8]=2;
    assert(cp_stage_restore(&tail,blob,cp_stage_snapshot_size(),NULL)==CP_STAGE_SNAP_ERR_FORMAT);
    puts("PASS loadout: slots, errors, nest and fight rules, observation, replay and snapshot determinism");
}
/* agentplay seed 3: both fighters reach 0 hp in the same tick. The wild creature used to be left with hp 0 but
 * dead=0, listed as a live "creature" with state "dead", attackable, and the attack command accepted it. */
static void double_ko_is_consistent(void) {
    cp_stage_setup_default(&setup,3);
    assert(cp_stage_reset(&w,&setup)==0);
    static char obs[65536];
    int saw_ko=0;
    for(int tick=0;tick<220;tick++) {
        if(tick==40)assert(cp_stage_command(&w,"attack #1 bite")==0);
        cp_stage_step(&w,NULL);
        for(int i=0;i<w.setup.n;i++) {
            const CpStageCreature *e=&w.wild[i];
            if(e->hp<=0) {
                saw_ko=1;
                assert(e->dead);
                assert(w.active!=i);
                assert(cp_stage_command(&w,"attack #1 bite")==-2);
                assert(cp_stage_command(&w,"approach #1")==-2);
            }
        }
        assert(cp_stage_observe(&w,obs,sizeof obs)>0);
        const char *c=strstr(obs,"\"type\":\"creature\"");
        while(c) {
            const char *end=strchr(c,'}');
            assert(end);
            char one[512];
            size_t n=(size_t)(end-c)<sizeof one-1?(size_t)(end-c):sizeof one-1;
            memcpy(one,c,n);one[n]=0;
            assert(!strstr(one,"\"state\":\"dead\""));
            assert(!strstr(one,"\"hp\":0.000000,"));
            c=strstr(end,"\"type\":\"creature\"");
        }
    }
    assert(saw_ko);
}
static void approach_in_fight(void){
    /* during a fight, approach on another creature is in_fight (-14), like befriend/observe/gift */
    /* close enough that the 0.9 m/s walk of the default body reaches #1 before it can run off (A39) */
    CpStageSetup su;cp_stage_setup_default(&su,4);su.terrain=CP_STAGE_FLAT;su.n_obstacles=0;su.n=3;
    for(int i=0;i<3;i++){su.wild[i].profile=CP_STAGE_SPECIES[0].profile;su.wild[i].species=0;su.wild[i].x=su.nest_x+3+i*4;su.wild[i].z=su.nest_z+3;su.wild[i].home_x=su.wild[i].x;su.wild[i].home_z=su.wild[i].z;}
    assert(cp_stage_reset(&w,&su)==0);
    assert(cp_stage_command(&w,"attack #1 bite")==0);
    for(int i=0;i<400&&w.active<0;i++)cp_stage_step(&w,NULL);
    assert(w.active==0);
    assert(cp_stage_command(&w,"approach #2")==CP_STAGE_ERR_IN_FIGHT);
    assert(cp_stage_command(&w,"approach #999")==-2);
    assert(cp_stage_command(&w,"approach #1")==0);
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
    field_fight();
    debug_ops();
    nav_contract();
    loadout_contract();
    double_ko_is_consistent();
    approach_in_fight();
    reset();
    CpStageInput a={
        0
    };
    a.verb=CP_STAGE_HEADING;
    a.hx=32767;
    a.sprint=1;
    for(int i=0;i<30;i++)cp_stage_step(&w,&a);   /* 30 ticks: the default body sprints at 2.2 m/s now (A39) */
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
    for(int i=0;i<200;i++)cp_stage_step(&w,i==0?&a:NULL);   /* 7.8 m at the default body's 0.9 m/s walk (A39) */
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
