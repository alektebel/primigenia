/* Curated round trips through the public GO API; no debug move or teleport.
 * Fixtures are pinned to terrain v4, n=1024; see tests/routes/README.md. */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include "cpore/steer.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static CpTerrain t;
static CpTerrainWorkspace ws;
static CpStageField f;
static CpStageWorld w;
static double ms(void){struct timespec a;clock_gettime(CLOCK_MONOTONIC,&a);return a.tv_sec*1000.+a.tv_nsec/1e6;}
static float dist(float x,float z){return sqrtf(x*x+z*z);}
static float grade(float x,float z){
    float gx=(cp_stage_ground(&w,x+.25f,z)-cp_stage_ground(&w,x-.25f,z))*2;
    float gz=(cp_stage_ground(&w,x,z+.25f)-cp_stage_ground(&w,x,z-.25f))*2;
    return dist(gx,gz);
}
static void reset(float x,float z,int legs,int radius){
    CpStageSetup s;cp_stage_setup_default(&s,5);s.terrain=CP_STAGE_FIELD;s.n=0;
    s.nest_x=x;s.nest_z=z;s.player_legs=legs;
    s.player=(CpCombatProfile){2,4,0,0,0,100,100,4,(uint16_t)radius};
    /* the hidden cave chamber is part of the walkable world (C2 secrets); shard placement is off here (it walks the whole island) */
    s.secrets=CP_SECRETS_CAVE;
    if(t.cave_count>0)s.cave=(CpStageCave){1,t.caves[0].x_m,t.caves[0].y_m,t.caves[0].facing_x,t.caves[0].facing_y,0,0,0,0};
    memset(&w,0,sizeof w);assert(!cp_stage_attach_field(&w,&f));assert(!cp_stage_reset(&w,&s));
}
static void generate(unsigned seed){
    CpTerrainParams p;cp_terrain_params_default(&p);p.seed=seed;
    size_t n=(size_t)p.n*p.n;
    t.height=calloc(n,4);t.flow=calloc(n,4);t.sediment=calloc(n,4);t.material=calloc(n,1);t.river=calloc(n,1);
    ws.scratch=calloc(n,4);ws.recv=calloc(n,4);ws.ups=calloc(n,4);ws.queue=calloc(n,4);
    assert(t.height&&t.flow&&t.sediment&&t.material&&t.river&&ws.scratch&&ws.recv&&ws.ups&&ws.queue);
    assert(!cp_terrain_generate(&p,&t,&ws,NULL,NULL));
    f=(CpStageField){p.n,p.size_m,p.size_m/p.n,p.size_m*.5f,t.height,ws.scratch,cp_terrain_hash(&t)};
    reset(0,0,0,0);
}
int main(int argc,char **argv){
    assert(argc<=2);
    unsigned seed=argc>1?(unsigned)atoi(argv[1]):1;
    assert(seed==1||seed==7||seed==42);
    generate(seed);
    char file[128];snprintf(file,sizeof file,"tests/routes/seed%u.txt",seed);
    FILE *fp=fopen(file,"r");assert(fp);
    unsigned long long expected=0;
    assert(fscanf(fp,"terrain %llx",&expected)==1&&expected==f.hash);
    char names[32][40];float x[32],z[32];int count=0,npairs=0;
    int pairs[64][2];
    assert(fscanf(fp," places %d",&count)==1&&count>=9&&count<=32);
    for(int i=0;i<count;i++)assert(fscanf(fp,"%39s %f %f",names[i],&x[i],&z[i])==3);
    assert(fscanf(fp," pairs %d",&npairs)==1&&npairs>0&&npairs<=64);
    for(int i=0;i<npairs;i++){
        assert(fscanf(fp,"%d %d",&pairs[i][0],&pairs[i][1])==2);
        assert(pairs[i][0]>=0&&pairs[i][0]<count&&pairs[i][1]>=0&&pairs[i][1]<count);
    }
    fclose(fp);
    /* The pinned shard and chamber places must be what the C world derives from this field. */
    {
        CpStageSetup s;cp_stage_setup_default(&s,5);s.terrain=CP_STAGE_FIELD;s.n=0;s.nest_x=s.nest_z=0;
        s.secrets=CP_SECRETS_SHARDS|CP_SECRETS_CAVE;
        s.cave=(CpStageCave){1,t.caves[0].x_m,t.caves[0].y_m,t.caves[0].facing_x,t.caves[0].facing_y,0,0,0,0};
        static CpStageWorld probe;
        memset(&probe,0,sizeof probe);assert(!cp_stage_attach_field(&probe,&f));assert(!cp_stage_reset(&probe,&s));
        assert(probe.secrets.on&&probe.secrets.cave_on);
        int shards=0,chamber=0;
        for(int i=0;i<count;i++){
            int k;
            if(sscanf(names[i],"shard-%d",&k)==1){
                assert(k>=1&&k<=CP_STAGE_SHARDS&&fabsf(x[i]-probe.secrets.shard[k-1][0])<.01f&&fabsf(z[i]-probe.secrets.shard[k-1][1])<.01f);
                shards++;
            }
            else if(!strcmp(names[i],"cave-chamber")){
                assert(fabsf(x[i]-probe.secrets.chamber_x)<.01f&&fabsf(z[i]-probe.secrets.chamber_z)<.01f);
                chamber++;
            }
        }
        assert(shards==CP_STAGE_SHARDS&&chamber==1);
    }
    printf("# Routes seed %u — terrain v%d, n=%d, hash %016llx\n\n",seed,CP_TERRAIN_VERSION,f.n,(unsigned long long)f.hash);
    puts("| Body (legs/radius m) | Route | Reached | Ticks | Plan m | Walk m | Max grade | Fords | Stalls | Replans | Cold ms | Warm ms |\n|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|");
    const char *only=getenv("ROUTES_ONLY");
    int failed=0,total=0;
    for(int body=0;body<9;body++)for(int pair=0;pair<npairs;pair++)for(int reverse=0;reverse<2;reverse++){
        int legs=body?2+2*((body-1)/2):4,radius=body?((body-1)%2?400:50):300;
        int a=pairs[pair][reverse],b=pairs[pair][1-reverse];
        if(only&&!strstr(names[a],only)&&!strstr(names[b],only))continue;   /* ROUTES_ONLY=shard: a development filter, the gate runs everything */
        /* Invalidate only derived nav data through a different valid body signature. */
        reset(x[a],z[a],legs,radius==50?51:50);
        assert(cp_stage_nav_cell(&w)>0);
        reset(x[a],z[a],legs,radius);
        CpStageInput go={.verb=CP_STAGE_GO,.x=x[b],.z=z[b]};
        double before=ms();int rc=cp_stage_order(&w,&go);double cold=ms()-before;
        reset(x[a],z[a],legs,radius);before=ms();int rc2=cp_stage_order(&w,&go);double warm=ms()-before;assert(rc==rc2);
        float walked=0,maxgrade=grade(w.player.x,w.player.z);int ticks=0,stalls=0,plans=0,fords=0,wet=0,arrived=0;
        float planned=0;
        int deep_water=cp_stage_water_depth(&w,w.player.x,w.player.z)>.7f;
        uint64_t digest=14695981039346656037ULL;
        while(!rc&&w.order.verb==CP_STAGE_GO&&ticks<20000){
            float px=w.player.x,pz=w.player.z;
            digest^=cp_stage_step(&w,NULL);digest*=1099511628211ULL;ticks++;
            deep_water|=cp_stage_water_depth(&w,w.player.x,w.player.z)>.7f;
            float d=dist(w.player.x-px,w.player.z-pz);walked+=d;
            if(w.blocked_reason)stalls++;
            float g=grade(w.player.x,w.player.z);if(g>maxgrade)maxgrade=g;
            int ix=(int)((w.player.x+f.half)/f.cell),iz=(int)((w.player.z+f.half)/f.cell);
            int water=(t.river[iz*f.n+ix]&3)==CP_TERR_RIVER_SHALLOW;
            if(water&&!wet)fords++;
            wet=water;
            for(uint32_t k=w.ev_acked;k<w.ev_total;k++){
                const CpStageEvent *ev=&w.events[k%CP_STAGE_MAX_EVENTS];
                if(ev->type==CP_STAGE_EV_ARRIVED)arrived=1;
                if(ev->type==CP_STAGE_EV_PATH_FOUND){if(!plans)planned=ev->value;plans++;}
            }
            cp_stage_ack_events(&w);
        }
        int reached=!rc&&arrived&&!deep_water&&maxgrade<=CP_STEER_GRADE_MAX+.0001f&&dist(w.player.x-x[b],w.player.z-z[b])<.3f;
        printf("| %d/%.2f | %s → %s | %s | %d | %.2f | %.2f | %.4f | %d | %d | %d | %.3f | %.3f |\n",w.player.legs,cp_combat_body_radius(&w.player.profile),names[a],names[b],reached?"yes":"FAIL",ticks,planned,walked,maxgrade,fords,stalls,plans?plans-1:0,cold,warm);
        fflush(stdout);failed+=!reached;total++;
        /* Replay the actual trajectory, not only a planner's answer. */
        reset(x[a],z[a],legs,radius);assert(cp_stage_order(&w,&go)==rc);
        uint64_t again=14695981039346656037ULL;
        for(int k=0;k<ticks;k++){again^=cp_stage_step(&w,NULL);again*=1099511628211ULL;}
        assert(again==digest);
    }
    printf("\nResult: %d/%d reached; each trajectory replayed identically. Budget 20000 ticks.\n",total-failed,total);
    return failed?1:0;
}
