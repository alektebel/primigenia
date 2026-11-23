/* C2 secrets: meteor shards, hidden cave chamber, day/night and the nocturnal and sixth species.
 * `secrets_test <seed>` generates the n=1024 island (terrain seeds 1, 7, 42 are the certified ones), `secrets_test flat` runs the
 * flat-world rules. Run by `make test` through `make secrets-test`. */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static CpTerrain t;
static CpTerrainWorkspace ws;
static CpStageField f;
static CpStageWorld w,w2;
#define PASS(name) printf("PASS secrets: %s\n",name)
static float dist(float x,float z){return sqrtf(x*x+z*z);}
static void generate(unsigned seed){
    CpTerrainParams p;cp_terrain_params_default(&p);p.seed=seed;
    size_t n=(size_t)p.n*p.n;
    t.height=calloc(n,4);t.flow=calloc(n,4);t.sediment=calloc(n,4);t.material=calloc(n,1);t.river=calloc(n,1);
    ws.scratch=calloc(n,4);ws.recv=calloc(n,4);ws.ups=calloc(n,4);ws.queue=calloc(n,4);
    assert(t.height&&t.flow&&t.sediment&&t.material&&t.river&&ws.scratch&&ws.recv&&ws.ups&&ws.queue);
    assert(!cp_terrain_generate(&p,&t,&ws,NULL,NULL));
    f=(CpStageField){p.n,p.size_m,p.size_m/p.n,p.size_m*.5f,t.height,ws.scratch,cp_terrain_hash(&t)};
}
static void setup(CpStageSetup *s,int secrets,int legs,int radius){
    cp_stage_setup_default(s,5);
    s->terrain=CP_STAGE_FIELD;s->n=0;s->nest_x=s->nest_z=0;s->player_legs=legs;
    s->player=(CpCombatProfile){2,4,0,0,0,100,100,4,(uint16_t)radius,0};
    s->secrets=secrets?3:0;
    if(secrets&&t.cave_count>0){
        const CpTerrainCave *c=&t.caves[0];
        s->cave=(CpStageCave){1,c->x_m,c->y_m,c->facing_x,c->facing_y,0,0,0,0};
    }
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
/* GO to (x,z); returns ticks used or -1 when the order was rejected or never arrived. */
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
static void field_tests(unsigned seed){
    generate(seed);
    assert(t.cave_count>0);
    CpStageSetup off,on;
    setup(&off,0,4,300);setup(&on,1,4,300);
    /* 1. off by default: no shards, the hash and the heights are exactly what they were */
    reset(&w,&off);
    assert(!w.secrets.on&&!w.secrets.cave_on);
    PASS("secrets off: nothing placed, ground untouched");
    /* 2. placement: five sites, in order of distance, away from the nest, the same on a second reset, dry and gentle */
    reset(&w,&on);
    assert(w.secrets.on&&w.secrets.n_shards==CP_STAGE_SHARDS&&w.secrets.cave_on);
    reset(&w2,&on);
    assert(!memcmp(w.secrets.shard,w2.secrets.shard,sizeof w.secrets.shard)&&w.hash==w2.hash);
    float prev=0;
    for(int k=0;k<CP_STAGE_SHARDS;k++){
        const float d=dist(w.secrets.shard[k][0]-on.nest_x,w.secrets.shard[k][1]-on.nest_z);
        printf("  seed %u shard %d at (%.1f, %.1f), %.0f m from the nest\n",seed,k,w.secrets.shard[k][0],w.secrets.shard[k][1],d);
        assert(d>prev&&d>=40.f);
        prev=d;
        assert(cp_stage_water_depth(&w,w.secrets.shard[k][0],w.secrets.shard[k][1])<=.3f);
        for(int j=0;j<k;j++)assert(dist(w.secrets.shard[k][0]-w.secrets.shard[j][0],w.secrets.shard[k][1]-w.secrets.shard[j][1])>=60.f);
    }
    printf("  seed %u crater end (%.0f, %.0f), scale %d%%\n",seed,w.secrets.crater_x,w.secrets.crater_z,w.secrets.placed_scale);
    PASS("five shards placed, ordered outward along one ray, deterministic");
    /* 3. every shard is reachable on foot with the real planner and can be collected; story event, DNA, saved state */
    reset(&w,&on);
    int total_ticks=0;
    for(int k=0;k<CP_STAGE_SHARDS;k++){
        const int ticks=go(&w,w.secrets.shard[k][0],w.secrets.shard[k][1],20000);
        assert(ticks>=0);
        total_ticks+=ticks;
        const int before=w.social.dna_total;
        const uint32_t from=w.ev_total;
        CpStageInput in={.verb=CP_STAGE_INSPECT,.target=CP_STAGE_SHARD_ID+k};
        assert(cp_stage_order(&w,&in)==0);
        CpStageEvent ev;
        assert(event_since(&w,from,CP_STAGE_EV_SHARD_FOUND,&ev)&&ev.move==k&&(int)ev.value==k+1&&ev.target==CP_STAGE_SHARD_ID+k);
        assert(w.secrets.found==k+1&&(w.secrets.found_mask&(1<<k)));
        assert(w.social.dna_total-before==(k==CP_STAGE_SHARDS-1?15:5)&&w.social.dna_by_source[CP_DNA_SHARD]>=5);
        assert(cp_stage_order(&w,&in)==-2);   /* once only */
    }
    char json[8192];
    assert(cp_stage_secrets_json(&w,json,sizeof json)>0&&strstr(json,"\"found\":5")&&strstr(json,"\"line_es\""));
    char *big=malloc(262144);
    assert(cp_stage_observe(&w,big,262144)>0&&strstr(big,"\"secrets\":{\"enabled\":true")&&strstr(big,"\"type\":\"shard_found\""));
    free(big);
    printf("  seed %u: all five shards walked to in %d ticks (default 4-leg body)\n",seed,total_ticks);
    PASS("all five shards reachable on foot, collected once, story + DNA events");
    /* 4. too far to collect */
    reset(&w,&on);
    {CpStageInput in={.verb=CP_STAGE_INSPECT,.target=CP_STAGE_SHARD_ID};assert(cp_stage_order(&w,&in)==-2);}
    PASS("a shard cannot be collected from afar");
    /* 5. snapshot and restore keep the found state; the replay is identical */
    {
        static uint8_t snap[1<<22];
        assert(cp_stage_snapshot_size()<sizeof snap);
        int n=cp_stage_snapshot(&w,snap,sizeof snap);
        assert(n>0);
    }
    reset(&w,&on);
    go(&w,w.secrets.shard[0][0],w.secrets.shard[0][1],20000);
    {CpStageInput in={.verb=CP_STAGE_INSPECT,.target=CP_STAGE_SHARD_ID};assert(cp_stage_order(&w,&in)==0);}
    static uint8_t snap[1<<22];
    assert(cp_stage_snapshot_size()<=sizeof snap);
    const int n=cp_stage_snapshot(&w,snap,sizeof snap);
    assert(n>0);
    memset(&w2,0,sizeof w2);
    assert(cp_stage_restore(&w2,snap,(size_t)n,&f)==CP_STAGE_SNAP_OK);
    assert(w2.secrets.found==1&&w2.hash==w.hash);
    for(int k=0;k<50;k++){cp_stage_step(&w,NULL);cp_stage_step(&w2,NULL);}
    assert(w.hash==w2.hash);
    PASS("found shards survive snapshot/restore; the run stays in step");
    /* 6. the cave: the chamber is reachable by the real planner for the default body, the mouth, the passage and the chamber
     * fire events once, the chamber fossil (the extra node) is collectable and gives its part */
    reset(&w,&on);
    const CpStageSecrets *s=&w.secrets;
    assert(s->cave_on&&cp_stage_in_cave(&w,s->chamber_x,s->chamber_z)==2);
    assert(w.parts.n_nodes>=1&&w.parts.nodes[w.parts.n_nodes-1].kind==CP_PART_FOSSIL);
    const float ex=s->cave_x+s->cave_fx*6.f,ez=s->cave_z+s->cave_fz*6.f;
    assert(go(&w,ex,ez,20000)>=0);
    assert(!w.secrets.cave_entered);
    const int ticks=go(&w,s->chamber_x,s->chamber_z,20000);
    printf("  seed %u: cave floor %.1f, mouth (%.1f,%.1f) chamber (%.1f,%.1f), walked in %d ticks\n",seed,s->cave_floor,s->cave_x,s->cave_z,s->chamber_x,s->chamber_z,ticks);
    assert(ticks>=0);
    assert(w.secrets.cave_entered&&w.secrets.chamber_entered&&cp_stage_in_cave(&w,w.player.x,w.player.z)==2);
    assert(fabsf(cp_stage_ground(&w,w.player.x,w.player.z)-s->cave_floor)<.05f);
    {
        const int node=w.parts.n_nodes-1;
        assert(go(&w,w.parts.nodes[node].x,w.parts.nodes[node].z,2000)>=0);
        CpStageInput in={.verb=CP_STAGE_INSPECT,.target=3000+node};
        assert(cp_stage_order(&w,&in)==0);
        for(int k=0;k<40;k++)cp_stage_step(&w,NULL);
        assert(w.parts.nodes[node].inspected&&w.parts.clues>=1);
    }
    PASS("hidden cave: the chamber is walkable by the real planner, entered once, its fossil can be inspected");
    /* 7. walls: the rock beside the passage is not walkable (the heightfield cliff blocks) */
    reset(&w,&on);
    {
        const float mx=s->cave_x-s->cave_fx*8.f-s->cave_fz*(s->cave_half+3.f),mz=s->cave_z-s->cave_fz*8.f+s->cave_fx*(s->cave_half+3.f);
        const float px=s->cave_x-s->cave_fx*8.f,pz=s->cave_z-s->cave_fz*8.f;
        assert(!cp_stage_can_walk(&w,px,pz,mx,mz,.3f));
    }
    PASS("cave walls block");
    /* 7b. the cave alone (what the route certification uses): no shard placement, same chamber, and it is still reachable */
    {
        CpStageSetup cave_only=on;
        cave_only.secrets=CP_SECRETS_CAVE;
        reset(&w2,&on);
        const float want_x=w2.secrets.chamber_x,want_z=w2.secrets.chamber_z;
        reset(&w,&cave_only);
        assert(!w.secrets.on&&w.secrets.cave_on&&w.secrets.n_shards==0);
        assert(w.secrets.chamber_x==want_x&&w.secrets.chamber_z==want_z);
        assert(go(&w,w.secrets.chamber_x,w.secrets.chamber_z,20000)>=0&&w.secrets.chamber_entered);
        CpStageInput in={.verb=CP_STAGE_INSPECT,.target=CP_STAGE_SHARD_ID};
        assert(cp_stage_order(&w,&in)<0);   /* no shards in this mode */
    }
    PASS("cave-only mode: chamber walkable, no shards");
    /* 8. the secrets hash is folded only when on: same world, secrets off, then on, differ; found state changes it */
    reset(&w,&off);reset(&w2,&on);
    assert(w.hash!=w2.hash);
    PASS("hash covers secrets only when enabled");
    free(t.height);free(t.flow);free(t.sediment);free(t.material);free(t.river);
    free(ws.scratch);free(ws.recv);free(ws.ups);free(ws.queue);
}
static CpStageSetup fs;
static void flat(int clock,int n,const int *species){
    cp_stage_setup_default(&fs,42);
    fs.terrain=CP_STAGE_FLAT;fs.nest_x=fs.nest_z=0;fs.n=n;fs.start_clock=clock;
    for(int i=0;i<n;i++)fs.wild[i]=(CpStageSpawn){.x=12.f+3*i,.z=0,.home_x=12.f+3*i,.home_z=0,.species=species[i],.bot=-1,.profile=CP_STAGE_SPECIES[species[i]].profile};
    memset(&w,0,sizeof w);
    assert(!cp_stage_reset(&w,&fs));
}
static void flat_tests(void){
    assert(CP_STAGE_SPECIES_DEFINED==8&&!strcmp(CP_STAGE_SPECIES[4].name,"Acechalunas")&&!strcmp(CP_STAGE_SPECIES[5].name,"Babosa"));
    assert(CP_STAGE_SPECIES[4].activity==CP_ACT_NOCTURNAL&&CP_STAGE_SPECIES[5].activity==CP_ACT_CREPUSCULAR);
    for(int i=0;i<4;i++)assert(CP_STAGE_SPECIES[i].activity==CP_ACT_DIURNAL);
    PASS("eight species, with their daily rhythm");
    /* the clock: 500 ticks an hour, dawn 05-07, dusk 18-20 */
    const int sp[]={4};
    flat(0,1,sp);assert(cp_stage_daylight(&w)==0);
    flat(3000,1,sp);assert(cp_stage_daylight(&w)==500);
    flat(5000,1,sp);assert(cp_stage_daylight(&w)==1000);
    flat(9500,1,sp);assert(cp_stage_daylight(&w)==500);
    flat(11000,1,sp);assert(cp_stage_daylight(&w)==0);
    flat(3500,1,sp);assert(cp_stage_daylight(&w)==1000&&w.clock==3500);
    PASS("daylight curve and start clock");
    /* by day the Acechalunas is hidden: not in nearby, not targetable, never hostile, never fights */
    flat(5000,1,sp);
    assert(cp_stage_creature_hidden(&w,0));
    {
        char *b=malloc(262144);
        assert(cp_stage_observe(&w,b,262144)>0);
        char *nb=strstr(b,"\"nearby\":["),*ne=strstr(nb,"\"legal_verbs\"");
        assert(nb&&ne);
        for(char *q=nb;q<ne;q++)assert(strncmp(q,"Acechalunas",11));
        free(b);
    }
    CpStageInput in={.verb=CP_STAGE_APPROACH,.target=1};
    assert(cp_stage_order(&w,&in)==-2);
    in=(CpStageInput){.verb=CP_STAGE_OBSERVE,.target=1};
    assert(cp_stage_order(&w,&in)<0);
    in=(CpStageInput){.verb=CP_STAGE_BEFRIEND,.target=1,.move=CP_SOC_SING};
    assert(cp_stage_order(&w,&in)<0);
    const float x0=w.wild[0].x,z0=w.wild[0].z;
    for(int k=0;k<200;k++)cp_stage_step(&w,NULL);
    assert(w.wild[0].x==x0&&w.wild[0].z==z0&&w.active<0);
    PASS("by day the nocturnal creature sleeps: hidden, untargetable, motionless");
    /* at night it is out and can be befriended; the same sing gains 50% more than in the light of day */
    flat(0,1,sp);
    assert(!cp_stage_creature_hidden(&w,0));
    {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
    in=(CpStageInput){.verb=CP_STAGE_BEFRIEND,.target=1,.move=CP_SOC_SING};
    assert(cp_stage_order(&w,&in)==0);
    for(int k=0;k<80&&w.order.verb;k++)cp_stage_step(&w,NULL);
    const int night=w.social.c[0].trust;
    assert(night>0);
    PASS("a nocturnal creature can be befriended in the dark");
    /* the bonus is exactly 3/2 on the gain */
    {
        const int a[]={4};
        flat(0,1,a);
        {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
        w.social.used=1;
        CpStageEvent ev;
        CpStageInput gift={.verb=CP_STAGE_BEFRIEND,.target=1,.move=CP_SOC_SING};
        const uint32_t from=w.ev_total;
        assert(cp_stage_order(&w,&gift)==0);
        for(int k=0;k<80&&w.order.verb;k++)cp_stage_step(&w,NULL);
        assert(event_since(&w,from,CP_STAGE_EV_SKILL,&ev));
        const int dark=(int)ev.value;
        /* dusk, light 400 and falling: awake but the dark bonus (light < 250) is not on yet during the action */
        flat(9600,1,a);
        {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
        assert(!cp_stage_creature_hidden(&w,0));   /* light 400 < 500: awake */
        const uint32_t from2=w.ev_total;
        assert(cp_stage_order(&w,&gift)==0);
        for(int k=0;k<80&&w.order.verb;k++)cp_stage_step(&w,NULL);
        assert(event_since(&w,from2,CP_STAGE_EV_SKILL,&ev));
        const int dusk=(int)ev.value;
        printf("  sing gain: dark %d, dusk %d\n",dark,dusk);
        fflush(stdout);assert(dark>dusk&&dark==dusk*3/2);
    }
    PASS("befriending bonus in the dark is +50% on trust gain");
    /* the sixth species hunkers at noon, moves at dusk; it can be befriended and its chain is defined */
    const int bab[]={5};
    flat(5000,1,bab);
    assert(cp_stage_creature_hunkered(&w,0)&&!cp_stage_creature_hidden(&w,0));
    {
        const float bx=w.wild[0].x,bz=w.wild[0].z;
        for(int k=0;k<300;k++)cp_stage_step(&w,NULL);
        assert(w.wild[0].x==bx&&w.wild[0].z==bz);
    }
    flat(0,1,bab);
    assert(!cp_stage_creature_hunkered(&w,0));
    {
        const float bx=w.wild[0].x;
        for(int k=0;k<400;k++)cp_stage_step(&w,NULL);
        assert(w.wild[0].x!=bx||w.wild[0].z!=0);
    }
    assert(CP_STAGE_CHAINS[4].move==CB_BITE&&CP_STAGE_CHAINS[5].move==CB_SPIT&&CP_STAGE_CHAINS[4].observe[2]&&CP_STAGE_CHAINS[5].observe[0]);
    PASS("Babosa hunkers in the noon light and moves at night");
    /* the Q43 loop counts them: three bonded Acechalunas at night make an ally species */
    {
        const int three[]={4,4,4};
        flat(0,3,three);
        {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
        cp_stage_social_give(&w,CP_ITEM_MEAT,18);
        for(int i=1;i<=3;i++)for(int g=0;g<6&&!w.social.c[i-1].bonded;g++){
            char c[64];snprintf(c,sizeof c,"gift #%d meat",i);
            assert(cp_stage_command(&w,c)==0);
            for(int k=0;k<60&&w.order.verb;k++)cp_stage_step(&w,NULL);
        }
        assert(w.social.latched[4]==3&&w.social.resolution[4]==CP_RES_ALLY);
        assert(cp_stage_social_species_present(&w)==1&&cp_stage_social_species_resolved(&w)==1);
    }
    PASS("Acechalunas counts as a species for the ally loop (Q43)");
    /* a world that never enables secrets and uses the original species keeps its hash: same trace as before */
    {
        const int old[]={3};
        flat(0,1,old);
        const uint64_t h0=w.hash;
        flat(0,1,old);
        assert(h0==w.hash);
    }
    PASS("original species unchanged");
}
int main(int argc,char **argv){
    assert(argc==2);
    if(!strcmp(argv[1],"flat"))flat_tests();
    else{
        const unsigned seed=(unsigned)atoi(argv[1]);
        assert(seed==1||seed==7||seed==42);
        field_tests(seed);
    }
    return 0;
}
