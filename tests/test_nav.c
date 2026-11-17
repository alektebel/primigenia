/* C1-nav: GO pathfinding on the generated island (docs/godot/NAV.md).
 *   build/nav_test [seed=1] [n=1024]
 * 20 seeded far targets must be reached (>= 18), the planner time is reported, and the same orders replay to the
 * same hashes (also through cp_stage_replay_ex and a snapshot taken while a path is being followed). */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include <assert.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static CpTerrain terrain;
static CpTerrainWorkspace ws;
static CpStageField field;
static CpStageWorld world,twin;
static CpStageSetup setup;
static double now_ms(void){
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC,&t);
    return t.tv_sec*1e3+t.tv_nsec/1e6;
}
static int dry(float x,float z){
    return cp_stage_ground(&world,x,z)>1&&cp_stage_water_depth(&world,x,z)==0;
}
static int gentle(float x,float z){
    const float c=field.cell,dx=cp_stage_ground(&world,x+c,z)-cp_stage_ground(&world,x-c,z),dz=cp_stage_ground(&world,x,z+c)-cp_stage_ground(&world,x,z-c);
    return 2*c/sqrtf(dx*dx+4*c*c+dz*dz)>.9f;
}
static uint32_t lcg=12345;
static float rnd(void){
    lcg=lcg*1664525u+1013904223u;
    return (float)(lcg>>8)/16777216.f;
}
static void fresh(float nx,float nz){
    memset(&world,0,sizeof world);
    assert(cp_stage_attach_field(&world,&field)==0);
    cp_stage_setup_default(&setup,5);
    setup.terrain=CP_STAGE_FIELD;
    setup.n=0;
    setup.nest_x=nx;
    setup.nest_z=nz;
    assert(cp_stage_reset(&world,&setup)==0);
}
int main(int argc,char **argv){
    const uint32_t seed=argc>1?(uint32_t)atoi(argv[1]):1;
    const int n=argc>2?atoi(argv[2]):1024;
    CpTerrainParams p;
    cp_terrain_params_default(&p);
    p.seed=seed;
    p.n=n;
    const size_t count=(size_t)n*n;
    terrain.material=calloc(count,1);
    terrain.height=calloc(count,sizeof(float));
    terrain.flow=calloc(count,sizeof(float));
    terrain.sediment=calloc(count,sizeof(float));
    ws.scratch=calloc(count,sizeof(float));
    ws.recv=calloc(count,sizeof(int32_t));
    ws.ups=calloc(count,sizeof(int32_t));
    ws.queue=calloc(count,sizeof(int32_t));
    double t0=now_ms();
    assert(cp_terrain_generate(&p,&terrain,&ws,NULL,NULL)==0);
    printf("terrain seed %u n %d generated in %.0f ms\n",seed,n,now_ms()-t0);
    field=(CpStageField){n,p.size_m,p.size_m/(float)n,p.size_m*.5f,terrain.height,ws.scratch,cp_terrain_hash(&terrain)};
    fresh(0,0);
    float nx=0,nz=0;
    int found=dry(0,0)&&gentle(0,0);
    for(int r=5;r<400&&!found;r+=5)for(int k=0;k<32&&!found;k++){
        float a=k*6.2831853f/32,x=sinf(a)*r,z=cosf(a)*r;
        if(dry(x,z)&&gentle(x,z)){nx=x;nz=z;found=1;}
    }
    assert(found);
    printf("nest (%.1f,%.1f) bound %.1f nav cell %.3f m\n",nx,nz,cp_stage_bound(&world),0.f);
    /* 20 seeded far targets: dry gentle ground 500..1600 m from the nest */
    float tx[20],tz[20];
    for(int i=0;i<20;){
        float x=(rnd()*2-1)*1700,z=(rnd()*2-1)*1700,d=sqrtf((x-nx)*(x-nx)+(z-nz)*(z-nz));
        if(d<500||d>1600||!dry(x,z)||!gentle(x,z))continue;
        tx[i]=x;tz[i]=z;i++;
    }
    if(argc>3&&!strcmp(argv[3],"prefill")){
        double w0=now_ms();
        int dim=cp_stage_nav_warm(&world);
        printf("full nav grid fill (%dx%d cells): %.0f ms\n",dim,dim,now_ms()-w0);
        fresh(nx,nz);
    }
    int reached=0,rejected=0;
    double worst=0,sum=0;
    int planned=0;
    for(int i=0;i<20;i++){
        fresh(nx,nz);
        char cmd[96];
        snprintf(cmd,sizeof cmd,"go %.3f %.3f",tx[i],tz[i]);
        double a=now_ms();
        int rc=cp_stage_command(&world,cmd);
        double ms=now_ms()-a;
        if(rc){
            rejected++;
            printf("  #%02d (%7.1f,%7.1f) REJECTED %s  plan %.2f ms\n",i,tx[i],tz[i],cp_stage_order_error(rc),ms);
            continue;
        }
        planned++;
        if(ms>worst)worst=ms;
        sum+=ms;
        const int wps=world.n_path;
        int ticks=0;
        while(ticks<12000&&world.order.verb==CP_STAGE_GO){
            cp_stage_step(&world,NULL);
            ticks++;
        }
        const float left=sqrtf((world.player.x-tx[i])*(world.player.x-tx[i])+(world.player.z-tz[i])*(world.player.z-tz[i]));
        const int ok=world.order.verb!=CP_STAGE_GO&&left<3.f;
        reached+=ok;
        printf("  #%02d (%7.1f,%7.1f) %s plan %.2f ms, %d waypoints, %d ticks, %.1f m left%s\n",i,tx[i],tz[i],ok?"REACHED":"NOT REACHED",ms,wps,ticks,left,ok?"":(world.last_error?" (path failed)":" (timeout)"));
    }
    printf("RESULT reached %d/20 (rejected unreachable %d, planned %d); A* plan time mean %.2f ms worst %.2f ms\n",reached,rejected,planned,planned?sum/planned:0,worst);
    /* a second plan on the warm grid, the same targets: this is the steady-state cost */
    double warm_worst=0;
    for(int i=0;i<20;i++){
        fresh(nx,nz);
        char cmd[96];
        snprintf(cmd,sizeof cmd,"go %.3f %.3f",tx[i],tz[i]);
        double a=now_ms();
        cp_stage_command(&world,cmd);
        double ms=now_ms()-a;
        if(ms>warm_worst)warm_worst=ms;
    }
    printf("warm-grid plan time worst %.2f ms (cell %.3f m)\n",warm_worst,cp_stage_nav_cell(&world));
    assert(reached>=18);
    /* determinism: the same order twice, then through cp_stage_replay_ex, then a snapshot restored mid-path */
    int pick=-1;
    for(int i=0;i<20&&pick<0;i++){
        fresh(nx,nz);
        char cmd[96];
        snprintf(cmd,sizeof cmd,"go %.3f %.3f",tx[i],tz[i]);
        if(cp_stage_command(&world,cmd)==0&&world.n_path>2)pick=i;
    }
    assert(pick>=0);
    enum{TICKS=1500};
    static uint64_t h1[TICKS],h2[TICKS],h3[TICKS];
    fresh(nx,nz);
    CpStageInput go={.verb=CP_STAGE_GO,.x=tx[pick],.z=tz[pick]};
    for(int i=0;i<TICKS;i++)h1[i]=cp_stage_step(&world,i==0?&go:NULL);
    fresh(nx,nz);
    for(int i=0;i<TICKS;i++)h2[i]=cp_stage_step(&world,i==0?&go:NULL);
    assert(!memcmp(h1,h2,sizeof h1));
    CpStageLogEntry entry={0,go};
    const uint64_t final=cp_stage_replay_ex(&setup,NULL,0,&field,&entry,1,NULL,0,TICKS,h3);
    assert(final&&!memcmp(h1,h3,sizeof h1));
    fresh(nx,nz);
    static uint8_t blob[1<<20];
    for(int i=0;i<400;i++)cp_stage_step(&world,i==0?&go:NULL);
    assert(world.n_path>0);
    int bytes=cp_stage_snapshot(&world,blob,sizeof blob);
    assert(bytes>0);
    memset(&twin,0,sizeof twin);
    assert(cp_stage_restore(&twin,blob,(size_t)bytes,&field)==0);
    for(int i=400;i<TICKS;i++)assert(cp_stage_step(&twin,NULL)==h1[i]);
    printf("determinism: two runs, cp_stage_replay_ex and a snapshot restored at tick 400 (path of %d waypoints) all give the %d hashes of target #%d\n",world.n_path,TICKS,pick);
    /* a target in the sea is rejected as unreachable and leaves the previous state alone */
    fresh(nx,nz);
    float sx=0,sz=0;
    int sea=0;
    for(float x=-1700;x<1700&&!sea;x+=40)for(float z=-1700;z<1700&&!sea;z+=40)if(cp_stage_water_depth(&world,x,z)>5){sx=x;sz=z;sea=1;}
    assert(sea);
    const uint64_t before=cp_stage_hash(&world);
    snprintf((char *)blob,64,"go %.2f %.2f",sx,sz);
    double a=now_ms();
    int rc=cp_stage_command(&world,(char *)blob);
    printf("sea target (%.0f,%.0f): code %d '%s' in %.2f ms\n",sx,sz,rc,cp_stage_order_error(rc),now_ms()-a);
    assert(rc==-4&&world.last_error==-4&&cp_stage_hash(&world)==before);
    puts("PASS nav");
    return 0;
}
