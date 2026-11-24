/* First quest: digging, the fossil beds, the fire gland and the flamethrower (core/src/stage_dig.c, combat.c).
 * `first_quest_test [--island star|ring] <seed>` generates the island (ring: n=1024; star: the frozen Star massif, n=1536, B1; terrain seeds 1, 7, 42 are the certified ones); `first_quest_test flat`
 * runs the rules that need no terrain. Run by `make test` through `make first-quest-test`. */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include "island_gen.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static CpTerrain t;
static CpTerrainWorkspace ws;
static CpStageField f;
static CpStageWorld w,w2;
static int checks;
#define OK(c,name) do{if(!(c)){printf("FAIL first-quest: %s (line %d)\n",name,__LINE__);exit(1);}checks++;}while(0)
#define PASS(name) printf("PASS first-quest: %s\n",name)
static float dist(float x,float z){return sqrtf(x*x+z*z);}
static int star;
static void generate(unsigned seed){
    CpTerrainParams p;
    island_generate(&t,&ws,&p,seed,star,0);
    f=(CpStageField){p.n,p.size_m,p.size_m/p.n,p.size_m*.5f,t.height,ws.scratch,cp_terrain_hash(&t)};
}
static unsigned world_seed=5;
static void setup(CpStageSetup *s){
    cp_stage_setup_default(s,world_seed);
    s->terrain=CP_STAGE_FIELD;s->n=0;s->nest_x=s->nest_z=0;s->player_legs=4;
    s->player=(CpCombatProfile){2,4,0,0,0,100,100,4,300,0};
}
static void reset(CpStageWorld *world,const CpStageSetup *s){
    memset(world,0,sizeof *world);
    assert(!cp_stage_attach_field(world,&f));
    assert(!cp_stage_reset(world,s));
}
static int event_since(const CpStageWorld *world,uint32_t from,int type,CpStageEvent *out){
    for(uint32_t k=from;k<world->ev_total;k++){
        const CpStageEvent *e=&world->events[k%CP_STAGE_MAX_EVENTS];
        if(e->type==type){if(out)*out=*e;return 1;}
    }
    return 0;
}
static int go(CpStageWorld *world,float x,float z,int budget){
    const uint32_t from=world->ev_total;
    CpStageInput in={.verb=CP_STAGE_GO,.x=x,.z=z};
    if(cp_stage_order(world,&in))return -1;
    for(int k=0;k<budget;k++){
        cp_stage_step(world,NULL);
        if(event_since(world,from,CP_STAGE_EV_ARRIVED,NULL))return k+1;
        if(event_since(world,from,CP_STAGE_EV_PATH_FAILED,NULL))return -1;
    }
    return -1;
}
static void tp(CpStageWorld *world,float x,float z){
    world->player.x=x;world->player.z=z;world->player.speed=0;   /* tests only: the debug teleport refuses water and cliffs, which some checks want */
}
static int part_known(const CpStageWorld *world,const char *id){return (world->parts.discovered>>cp_stage_part_id(id))&1;}
/* the dig order, then ticks of nothing (CONTINUE) until it ends; returns the DUG event's find or -99 when no event came */
static int dug_ticks;      /* the ticks the last dig_here took (A54: 20 on soft soil, 35 hard, 50 rock) */
static int dig_here(CpStageWorld *world,int *bed_out){
    const uint32_t from=world->ev_total;
    CpStageInput in={.verb=CP_STAGE_DIG};
    const int rc=cp_stage_order(world,&in);
    if(rc)return rc-1000;
    const int budget=cp_stage_dig_ticks(world,world->player.x,world->player.z)+3;
    for(int k=0;k<budget;k++){
        cp_stage_step(world,NULL);
        CpStageEvent ev;
        if(event_since(world,from,CP_STAGE_EV_DUG,&ev)){dug_ticks=k+1;if(bed_out)*bed_out=(int)ev.value;return ev.move;}
    }
    return -99;
}
static void field_tests(unsigned seed){
    generate(seed);world_seed=seed*131u+5u;
    CpStageSetup su;setup(&su);
    /* 1. the wing bed is guaranteed near the start valley, on soft soil, reachable on foot, the same on a second reset */
    reset(&w,&su);
    OK(w.dig.n_beds>=1&&w.dig.bed[0].kind==CP_BED_WING,"a wing bed exists");
    {
        const float d=dist(w.dig.bed[0].x-su.nest_x,w.dig.bed[0].z-su.nest_z);
        printf("  seed %u: wing bed at (%.1f, %.1f), %.0f m from the nest, %d bed(s) in all\n",seed,w.dig.bed[0].x,w.dig.bed[0].z,d,w.dig.n_beds);
        OK(d>=22.f&&d<=62.f,"the wing bed is 22 to 62 m from the nest");
        OK(cp_stage_soft_soil(&w,w.dig.bed[0].x,w.dig.bed[0].z)&&cp_stage_walkable_from_nest(&w,w.dig.bed[0].x,w.dig.bed[0].z),"the bed is soft soil on a walkable line");
    }
    reset(&w2,&su);
    OK(!memcmp(w.dig.bed,w2.dig.bed,sizeof w.dig.bed)&&w.hash==w2.hash,"beds are deterministic");
    OK(!w.dig.used&&!part_known(&w,"wing_vane")&&!part_known(&w,"fire_gland"),"nothing is dug or known at the start");
    PASS("wing bed placed near the start, soft, walkable, deterministic");
    /* 2. the real planner walks there; digging takes CP_DIG_TICKS standing still; the bed gives the wing and the fire gland */
    reset(&w,&su);
    const float bx=w.dig.bed[0].x,bz=w.dig.bed[0].z;
    const int walked=go(&w,bx,bz,6000);
    OK(walked>=0,"the wing bed is reachable on foot with the real planner");
    const int dna0=w.social.dna_total;
    const uint32_t evs=w.ev_total;
    int bed=-9;
    const int found=dig_here(&w,&bed);
    OK(found==CP_FIND_WING_FOSSIL&&bed==0,"digging the wing bed finds the wing fossil");
    OK(w.dig.bed[0].dug&&w.dig.dug_total==1&&w.dig.n_holes==1&&w.dig.wing_found&&w.dig.fire_found,"the bed is spent and a hole is left");
    OK(part_known(&w,"wing_vane")&&part_known(&w,"fire_gland"),"wing_vane and fire_gland are discovered");
    OK(w.social.dna_total-dna0==10,"a fossil bed pays 10 DNA");
    {int n=0;for(uint32_t k=evs;k<w.ev_total;k++)if(w.events[k%CP_STAGE_MAX_EVENTS].type==CP_STAGE_EV_PART_FOUND)n++;OK(n==2,"two part_found events");}
    printf("  seed %u: walked %d ticks, dug in %d ticks\n",seed,walked,CP_DIG_TICKS);
    OK(dig_here(&w,NULL)==CP_STAGE_ERR_ALREADY_DUG-1000,"the same spot cannot be dug twice");
    PASS("the wing bed is walked to, dug in 2 s, and gives wing_vane + fire_gland + DNA");
    /* 3. refusals: water, no stamina, interruption (the stamina is spent). Steep ground is no longer refused: it takes longer (A54) */
    {
        float wx=0,wz=0,sx=0,sz=0;int gw=0,gs=0;
        for(float x=-300;x<=300&&!(gw&&gs);x+=7)for(float z=-300;z<=300&&!(gw&&gs);z+=7){
            if(!gw&&cp_stage_water_depth(&w,x,z)>1.f){wx=x;wz=z;gw=1;}
            const float h=cp_stage_ground(&w,x,z);
            const float gx=(cp_stage_ground(&w,x+1,z)-cp_stage_ground(&w,x-1,z))*.5f,gz=(cp_stage_ground(&w,x,z+1)-cp_stage_ground(&w,x,z-1))*.5f;
            if(!gs&&h>5.f&&gx*gx+gz*gz>.8f*.8f&&gx*gx+gz*gz<1.1f*1.1f&&cp_stage_water_depth(&w,x,z)==0.f){sx=x;sz=z;gs=1;}
        }
        OK(gw&&gs,"the island has water and steep ground to test with");
        tp(&w,wx,wz);OK(dig_here(&w,NULL)==CP_STAGE_ERR_HARD_GROUND-1000,"water cannot be dug");
        OK(cp_stage_dig_hardness(&w,sx,sz)==2&&cp_stage_dig_ticks(&w,sx,sz)==CP_DIG_TICKS_ROCK,"steep ground is rock: 5 s");
        tp(&w,sx,sz);{const int r=dig_here(&w,NULL);OK(r>=0&&r!=CP_FIND_WING_FOSSIL&&r!=CP_FIND_BONE_FOSSIL&&dug_ticks>=CP_DIG_TICKS_ROCK,"steep ground can be dug, slowly, and holds nothing special");}
        {   /* hard ground (a gentle-but-not-soft cell) takes 3.5 s; every dry cell can be dug, only water refuses */
            int hard=0;
            for(float x=-300;x<=300&&!hard;x+=5)for(float z=-300;z<=300&&!hard;z+=5)if(cp_stage_dig_hardness(&w,x,z)==1){tp(&w,x,z);w.player.stamina=100;const int r=dig_here(&w,NULL);hard=r>=0?1:-1;OK(hard>0&&dug_ticks==CP_DIG_TICKS_HARD,"hard ground takes 3.5 s");}
            OK(hard>0,"the island has hard (not rock) ground to test with");
        }
        w.player.stamina=100;
    }
    reset(&w,&su);
    OK(go(&w,bx,bz,6000)>=0,"walk to the bed again");
    w.player.stamina=CP_DIG_STAMINA-1;
    OK(dig_here(&w,NULL)==CP_STAGE_ERR_NO_STAMINA-1000,"not enough stamina");
    w.player.stamina=100;
    {
        CpStageInput in={.verb=CP_STAGE_DIG};
        OK(!cp_stage_order(&w,&in),"dig accepted");
        for(int k=0;k<5;k++)cp_stage_step(&w,NULL);
        OK(w.dig.act_t>0&&w.player.stamina<100-CP_DIG_STAMINA+6,"digging, the stamina is paid up front");
        const uint32_t from=w.ev_total;
        CpStageInput hd={.verb=CP_STAGE_HEADING,.hx=32767,.hz=0};
        cp_stage_step(&w,&hd);
        CpStageEvent ev;
        OK(event_since(&w,from,CP_STAGE_EV_DUG,&ev)&&ev.move==-1&&w.dig.act_t==0&&w.dig.n_holes==0&&!w.dig.bed[0].dug,"walking away interrupts the dig, leaving no hole");
    }
    PASS("water refuses; steep and hard ground dig slowly (5 s, 3.5 s); tiredness and interruption cancel the dig");
    /* 4. ordinary soil: grubs and pebbles at low rates, deterministic; the hash covers the dig block; snapshot and replay agree */
    reset(&w,&su);reset(&w2,&su);
    int grubs=0,pebbles=0,nothing=0,spots=0;
    for(float x=-60;x<=60&&spots<40;x+=9)for(float z=-60;z<=60&&spots<40;z+=9){
        if(!cp_stage_soft_soil(&w,x,z)||dist(x-bx,z-bz)<6.f)continue;
        tp(&w,x,z);tp(&w2,x,z);w.player.stamina=w2.player.stamina=100;
        const int a=dig_here(&w,NULL),b=dig_here(&w2,NULL);
        OK(a==b&&a>=0,"two worlds dig the same find");
        grubs+=a==CP_FIND_GRUB;pebbles+=a==CP_FIND_PEBBLE;nothing+=a==CP_FIND_NONE;spots++;
    }
    printf("  seed %u: %d spots dug: %d grubs, %d pebbles, %d nothing\n",seed,spots,grubs,pebbles,nothing);
    OK(spots>=20&&grubs>0&&pebbles>0&&nothing>grubs+pebbles,"small finds are rare, soil mostly gives nothing");
    OK(w.hash==w2.hash&&w.dig.used,"the same digs give the same hash, and it covers them");
    {
        static uint8_t blob[48+offsetof(CpStageWorld,field)];
        CpStageWorld a;reset(&a,&su);
        tp(&a,bx,bz);CpStageInput in={.verb=CP_STAGE_DIG};
        OK(!cp_stage_order(&a,&in),"dig accepted at the bed");
        for(int k=0;k<8;k++)cp_stage_step(&a,NULL);
        OK(cp_stage_snapshot(&a,blob,sizeof blob)>0,"snapshot taken mid-dig");
        CpStageWorld b;memset(&b,0,sizeof b);OK(cp_stage_restore(&b,blob,sizeof blob,&f)==0,"restored mid-dig");
        for(int k=0;k<20;k++){OK(cp_stage_step(&a,NULL)==cp_stage_step(&b,NULL),"the dig continues in step after a restore");}
        OK(b.dig.bed[0].dug&&part_known(&b,"fire_gland"),"and finishes the same");
    }
    {   /* replay_ex: a log with the DIG input reproduces the live hash */
        CpStageWorld live;reset(&live,&su);
        tp(&live,bx,bz);
        CpStageLogEntry log[1]={{live.tick,{.verb=CP_STAGE_DIG}}};
        CpStageDebug d={.op=CP_STAGE_DBG_TELEPORT,.id=0,.x=bx,.z=bz};
        CpStageDebugEntry dbg[1]={{0,d}};
        /* the live world teleported before tick 0; the replay does it at tick 0 before the input */
        uint64_t hashes[40];
        const uint64_t final=cp_stage_replay_ex(&su,NULL,0,&f,log,1,dbg,1,30,hashes);
        CpStageWorld again;reset(&again,&su);tp(&again,bx,bz);
        cp_stage_order(&again,&log[0].input);for(int k=0;k<30;k++)cp_stage_step(&again,NULL);
        OK(final==cp_stage_hash(&again),"replay_ex with a DIG input matches the live run");
    }
    {   char *big=malloc(262144);
        reset(&w,&su);
        OK(cp_stage_observe(&w,big,262144)>0&&strstr(big,"\"dig\":{\"digging\":0"),"the observation carries the dig block");
        tp(&w,bx,bz);
        OK(cp_stage_observe(&w,big,262144)>0&&strstr(big,"cracked, dry soil")&&strstr(big,"\"dig\""),"a bed within 30 m shows its clue, and dig is a legal verb on soft soil");
        free(big);}
    PASS("ordinary soil finds, hash, snapshot mid-dig, replay and observation");
}
static const char *body="{\"schema\":\"cpore.creature/5\",\"name\":\"Starter\",\"nodes\":[{\"y\":1,\"z\":-2,\"r\":0.1},{\"y\":1,\"z\":-1,\"r\":0.5},{\"y\":1,\"z\":0,\"r\":0.6},{\"y\":1,\"z\":1,\"r\":0.1}],\"parts\":[{\"type\":\"pico\",\"t\":1,\"ang\":0,\"size\":1,\"level\":1,\"tier\":0}%s],\"skin\":{\"pat\":0,\"wet\":0.3,\"scale\":7,\"cA\":\"#aabbcc\",\"cB\":\"#112233\",\"cC\":\"#ffffff\",\"sk\":\"endo\"},\"regions\":[]}";
static void flat_world(unsigned seed){
    CpStageSetup s;cp_stage_setup_default(&s,seed);s.terrain=CP_STAGE_FLAT;s.n_obstacles=0;s.n=1;
    s.wild[0]=(CpStageSpawn){.x=3,.z=0,.home_x=3,.home_z=0,.species=0,.bot=0,.profile=CP_STAGE_SPECIES[0].profile};   /* bot 0: it stands still, so the cone can be measured */
    s.wild[0].profile.hp=400;
    memset(&w,0,sizeof w);assert(!cp_stage_reset(&w,&s));
}
static void flame_tests(void){
    char plain[4096],with_gland[4096];
    snprintf(plain,sizeof plain,body,"");
    snprintf(with_gland,sizeof with_gland,body,",{\"type\":\"fire_gland\",\"t\":0.9,\"ang\":0,\"size\":1,\"level\":1,\"tier\":0}");
    CpLineageForm form;
    OK(!cp_stage_genome_form(with_gland,&form)&&form.profile.fire==1&&form.profile.mouth==1,"a genome with a fire gland has fire level 1");
    OK(!cp_stage_genome_form(plain,&form)&&form.profile.fire==0,"without it, none");
    /* task rewards: DNA once per step, hashed, from its own source */
    flat_world(10);
    {const uint64_t h0=w.hash;{CpStageInput q={.verb=CP_STAGE_QUEST,.target=2,.move=15};OK(cp_stage_order(&w,&q)==0,"the QUEST order");}
     OK(w.social.dna_balance==15&&w.social.dna_by_source[CP_DNA_TASK]==15,"a task step pays its DNA");
     OK(cp_stage_quest_award(&w,2,15)==-1&&cp_stage_quest_award(&w,40,5)==-1&&cp_stage_quest_award(&w,3,0)==-1,"once only, and only valid steps");
     OK(w.hash!=h0&&w.dig.used,"the payment is part of the state hash");}
    /* at the nest: start plain, the gland is found (as in the bed), the editor buys it, the move joins the loadout */
    flat_world(11);
    OK(!cp_stage_start_genome(&w,plain),"start genome");
    OK((cp_stage_known_moves(&w)&(1u<<CB_FLAME))==0,"no flamethrower yet");
    {CpStageInput in={.verb=CP_STAGE_ATTACK,.target=1,.move=CB_FLAME};OK(cp_stage_order(&w,&in)==-3,"the flame is refused without the gland");}
    OK(cp_stage_edit(&w,with_gland)==CP_STAGE_ERR_NOT_KNOWN,"the gland cannot be added before it is found");
    OK(!cp_stage_part_find(&w,cp_stage_part_id("fire_gland"),CP_PART_FOSSIL),"found");
    w.social.dna_balance=100;w.social.dna_total=100;
    OK(!cp_stage_edit(&w,with_gland),"the editor evolves the creature with the gland");
    OK(w.player.profile.fire==1&&(cp_stage_known_moves(&w)&(1u<<CB_FLAME)),"the profile has fire 1 and the move is known");
    OK(cp_combat_loadout_slot_of(&w.loadout,CB_FLAME)>=0,"the flamethrower sits in the loadout (the default slots were free)");
    PASS("the fire gland is a part that adds the flamethrower to the loadout");
    /* the fight: the cone, the burn, the move-used event, determinism */
    {
        CpStageWorld a=w;
        uint64_t ha[400];CpStageInput in={.verb=CP_STAGE_ATTACK,.target=1,.move=CB_FLAME};
        const uint32_t from=a.ev_total;
        OK(cp_stage_order(&a,&in)==0,"flame accepted");
        int saw_burn=0,burn_ticks=0;float hp_after_hit=-1,hp_end=0;int hit=0;
        for(int k=0;k<120;k++){
            ha[k]=cp_stage_step(&a,k?&(CpStageInput){0}:NULL);
            if(a.active>=0){
                if(a.combat.c[1].burn_t>0){saw_burn=1;burn_ticks++;}
                for(int e=0;e<a.combat.n_ev;e++)if(a.combat.ev[e].type==CB_EV_HIT&&a.combat.ev[e].move==CB_FLAME&&!hit){hit=1;hp_after_hit=a.combat.c[1].hp;}
                hp_end=a.combat.c[1].hp;
            }
        }
        CpStageEvent ev;
        OK(event_since(&a,from,CP_STAGE_EV_MOVE_USED,&ev)&&ev.move==CB_FLAME,"a move_used event names the flame");
        OK(a.dig.flames>=1,"the flamethrower counter is up");
        OK(hit&&saw_burn&&burn_ticks>=10,"the cone hit and the target burned");
        OK(hp_after_hit>0&&hp_end<hp_after_hit-4.f,"burning keeps hurting after the hit");
        printf("  flame: hit left %.1f hp, burned %d ticks, ended %.1f hp\n",hp_after_hit,burn_ticks,hp_end);
        /* the same run again: bit-identical */
        CpStageWorld b=w;cp_stage_order(&b,&in);
        for(int k=0;k<120;k++)OK(cp_stage_step(&b,k?&(CpStageInput){0}:NULL)==ha[k],"the flame fight is deterministic");
    }
    /* the cooldown: the move cannot be fired twice within 60 ticks */
    {
        CpStageWorld a=w;CpStageInput in={.verb=CP_STAGE_ATTACK,.target=1,.move=CB_FLAME};
        cp_stage_order(&a,&in);int rejected=0;
        for(int k=0;k<40;k++){cp_stage_step(&a,NULL);if(a.active>=0&&a.combat.c[0].cd[CB_FLAME]){CpStageInput again=in;int rc=cp_stage_order(&a,&again);if(rc==CP_STAGE_ERR_ON_COOLDOWN){rejected=1;break;}}}
        OK(rejected,"the flame is on cooldown after it starts");
    }
    PASS("the flamethrower: cone, burn over time, event, cooldown, deterministic");
}
int main(int argc,char **argv){
    star=island_args(&argc,argv);
    if(argc>1&&!strcmp(argv[1],"flat")){flame_tests();printf("first-quest (flat): %d checks\n",checks);return 0;}
    field_tests(argc>1?(unsigned)atoi(argv[1]):1);
    printf("first-quest (seed %s): %d checks\n",argc>1?argv[1]:"1",checks);
    return 0;
}
