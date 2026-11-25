/* C1-nav: GO pathfinding on the generated island (docs/godot/NAV.md).
 *   build/nav_test [--island star|ring] [seed=1] [n=1024 (ring) | 1536 (star)]
 * 20 seeded far targets must be reached (>= 18), the planner time is reported, and the same orders replay to the
 * same hashes (also through cp_stage_replay_ex and a snapshot taken while a path is being followed). */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include "island_gen.h"
#include "cpore/climate.h"
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
/* A GO from (ax,az) to (bx,bz) on field f with the default body: ticks until it stops, reached = arrived within 3 m (island-realism M3 forest cases). */
static int trip(const CpStageField *f,float ax,float az,float bx,float bz,int *reached){
    memset(&world,0,sizeof world);
    assert(cp_stage_attach_field(&world,f)==0);
    cp_stage_setup_default(&setup,5);
    setup.terrain=CP_STAGE_FIELD;setup.n=0;setup.nest_x=ax;setup.nest_z=az;
    assert(cp_stage_reset(&world,&setup)==0);
    char cmd[96];
    snprintf(cmd,sizeof cmd,"go %.3f %.3f",bx,bz);
    *reached=0;
    if(cp_stage_command(&world,cmd))return -1;
    int ticks=0;
    while(ticks<120000&&world.order.verb==CP_STAGE_GO){cp_stage_step(&world,NULL);ticks++;}
    *reached=world.order.verb!=CP_STAGE_GO&&sqrtf((world.player.x-bx)*(world.player.x-bx)+(world.player.z-bz)*(world.player.z-bz))<3.f;
    return ticks;
}
static int in_jungle(int n,float x,float z,int min_canopy){
    const float half=field.half,cell=field.cell;
    const int i=(int)((x+half)/cell),j=(int)((z+half)/cell);
    if(i<1||j<1||i>=n-1||j>=n-1)return 0;
    const size_t k=(size_t)j*n+i;
    return terrain.biome[k]==CP_BIOME_JUNGLE&&terrain.veg[4*k]>=min_canopy;
}
static int forest_spot(int n,float *x,float *z){
    for(int t=0;t<4000;t++){
        const float px=(rnd()*2-1)*2200,pz=(rnd()*2-1)*2200;
        if(!in_jungle(n,px,pz,150)||!dry(px,pz)||!gentle(px,pz)||cp_stage_trunk_hit(&world,px,pz,3.5f))continue;
        *x=px;*z=pz;return 1;
    }
    return 0;
}
static void forest_cases(const CpTerrainParams *p,float nx,float nz){
    const int n=p->n;
    float cave[2*CP_TERRAIN_CAVES_MAX];
    const CpFloraMaps maps=island_maps(&terrain,p,ws.scratch,terrain.trail,cave);
    enum{CAP=200000};
    CpStageTrunk *a=malloc(CAP*sizeof *a),*b=malloc(CAP*sizeof *b);
    const int ca=cp_flora_trunks(&maps,a,CAP),cb=cp_flora_trunks(&maps,b,CAP);
    assert(ca==cb&&ca>2000&&ca<=CAP&&!memcmp(a,b,(size_t)ca*sizeof *a));
    assert(field.trunks&&field.trunks->count==ca&&!memcmp(a,field.trunks->rec,(size_t)ca*sizeof *a));
    /* the records: species, radius (>= 0.3 m blocking), forest biome, off the trails, 4.5 m apart (through the field's own bucket hash) */
    int spring=0,nieblon=0;
    for(int i=0;i<ca;i++){
        const CpStageTrunk *t=&a[i];
        assert(t->species==CP_FLORA_SP_NIEBLON||t->species==CP_FLORA_SP_MADRE);
        assert(t->r>=.3f&&t->r<=CP_TRUNK_RMAX&&t->h>5.f&&fabsf(t->x)<field.half&&fabsf(t->z)<field.half);
        if(t->species==CP_FLORA_SP_MADRE){spring++;continue;}
        nieblon++;
        assert(in_jungle(n,t->x,t->z,0)||terrain.biome[(size_t)((int)((t->z+field.half)/field.cell))*n+(int)((t->x+field.half)/field.cell)]==CP_BIOME_DRY_FOREST);
        assert(!terrain.trail[(size_t)((int)((t->z+field.half)/field.cell))*n+(int)((t->x+field.half)/field.cell)]);
        const CpStageTrunks *tr=field.trunks;
        const int bi=(int)((t->x+field.half)/tr->cell),bj=(int)((t->z+field.half)/tr->cell);
        for(int j=bj-1;j<=bj+1;j++)for(int i2=bi-1;i2<=bi+1;i2++){
            if(i2<0||j<0||i2>=tr->cell_n||j>=tr->cell_n)continue;
            for(int q=tr->start[j*tr->cell_n+i2];q<tr->start[j*tr->cell_n+i2+1];q++){
                const int o=tr->index[q];
                if(o==i||tr->rec[o].species!=CP_FLORA_SP_NIEBLON)continue;
                assert(sqrtf((t->x-tr->rec[o].x)*(t->x-tr->rec[o].x)+(t->z-tr->rec[o].z)*(t->z-tr->rec[o].z))>=CP_FLORA_MIN_GAP_M-1e-3f);
            }
        }
    }
    assert(spring==1&&nieblon>2000);
    printf("forest: %d trunks (%d nieblon, %d spring tree), identical on a second placement and in the field\n",ca,nieblon,spring);
    /* a trunk is an obstacle: a GO into one is refused, a straight walk through one is not allowed */
    int ti=0;while(a[ti].species!=CP_FLORA_SP_NIEBLON||!dry(a[ti].x,a[ti].z))ti++;
    fresh(nx,nz);
    char cmd[96];snprintf(cmd,sizeof cmd,"go %.3f %.3f",a[ti].x,a[ti].z);
    assert(cp_stage_command(&world,cmd)==-4);
    assert(!cp_stage_can_walk(&world,a[ti].x-6,a[ti].z,a[ti].x+6,a[ti].z,.6f));
    /* forest crossings: jungle to jungle, 150..400 m apart, all reached with the default body */
    int pairs=0,reached_all=1;
    long total_ticks=0;
    for(int tries=0;tries<200&&pairs<6;tries++){
        float ax,az,bx,bz;
        if(!forest_spot(n,&ax,&az)||!forest_spot(n,&bx,&bz))continue;
        const float d=sqrtf((ax-bx)*(ax-bx)+(az-bz)*(az-bz));
        if(d<150||d>400)continue;
        int ok;const int ticks=trip(&field,ax,az,bx,bz,&ok);
        if(!ok){   /* only pairs the bare terrain joins count (a jungle patch can sit on an island of its own, or behind a cliff) */
            CpStageField bare=field;bare.cover=NULL;bare.trunks=NULL;
            int bare_ok;trip(&bare,ax,az,bx,bz,&bare_ok);
            if(!bare_ok){printf("  (pair (%.0f,%.0f) -> (%.0f,%.0f) is not joined without trunks either: skipped)\n",ax,az,bx,bz);continue;}
        }
        printf("  forest crossing %d: (%.0f,%.0f) -> (%.0f,%.0f) %.0f m: %s in %d ticks\n",pairs,ax,az,bx,bz,d,ok?"REACHED":"NOT REACHED",ticks);
        reached_all&=ok;total_ticks+=ticks;pairs++;
    }
    assert(pairs==6&&reached_all);
    /* trail against off-trail, multipliers ON (the plan's 0.4 and 0.15; the game ships both 0): a 260 m straight run through the forest vale, with a
     * trail painted along it (the shipped island has no game_trail yet, so the lane is synthetic), against the same run with no trail */
    float lax=0,laz=0,ldx=0,ldz=0;int found=0;
    for(int tries=0;tries<20000&&!found;tries++){
        float px,pz;
        if(!forest_spot(n,&px,&pz))break;
        for(int k=0;k<8&&!found;k++){
            const float ang=(float)k*.7853982f,dx=cosf(ang),dz=sinf(ang);
            int ok=1;
            for(int s=0;s<=52&&ok;s++){
                const float x=px+dx*5*s,z=pz+dz*5*s;
                ok=in_jungle(n,x,z,150)&&dry(x,z)&&gentle(x,z);
            }
            if(ok){found=1;lax=px;laz=pz;ldx=dx;ldz=dz;}
        }
    }
    assert(found);
    const float bx=lax+ldx*260,bz=laz+ldz*260;
    uint8_t *lane=calloc((size_t)n*n,1);
    for(int s=0;s<=260*2;s++){
        const float x=lax+ldx*.5f*s,z=laz+ldz*.5f*s;
        const int i=(int)((x+field.half)/field.cell),j=(int)((z+field.half)/field.cell);
        lane[j*n+i]=1;lane[j*n+i-1]=1;lane[j*n+i+1]=1;lane[(j-1)*n+i]=1;lane[(j+1)*n+i]=1;
    }
    static CpFieldStore sa,sb,sc;
    const CpStageField fa=island_field_ex(&sa,&terrain,p,ws.scratch,lane,CP_FIELD_COVER_SLOW_PLAN,CP_FIELD_TRAIL_BONUS_PLAN);
    const CpStageField fb=island_field_ex(&sb,&terrain,p,ws.scratch,NULL,CP_FIELD_COVER_SLOW_PLAN,CP_FIELD_TRAIL_BONUS_PLAN);
    const CpStageField fc=island_field_ex(&sc,&terrain,p,ws.scratch,NULL,0,0);
    assert(fa.hash!=fb.hash&&fb.hash!=fc.hash&&fa.hash!=field.hash);
    int ra,rb,rc2;
    const int ta=trip(&fa,lax,laz,bx,bz,&ra),tb=trip(&fb,lax,laz,bx,bz,&rb),tc=trip(&fc,lax,laz,bx,bz,&rc2);
    printf("trail crossing (260 m through the forest vale, multipliers ON): by trail %d ticks (%s), off trail %d ticks (%s), shipped (off) %d ticks (%s): trail/off-trail = %.2f\n",
           ta,ra?"reached":"NOT",tb,rb?"reached":"NOT",tc,rc2?"reached":"NOT",tb>0?(double)ta/tb:0.);
    assert(ra&&rb&&rc2&&ta>0&&tb>0);
    assert((double)ta<=.7*(double)tb);
    free(lane);free(a);free(b);
    puts("PASS nav forest");
}
int main(int argc,char **argv){
    const int star=island_args(&argc,argv);
    const uint32_t seed=argc>1?(uint32_t)atoi(argv[1]):1;
    const int n_arg=argc>2?atoi(argv[2]):0;
    CpTerrainParams p;
    double t0=now_ms();
    island_generate(&terrain,&ws,&p,seed,star,n_arg);
    const int n=p.n;
    printf("%s island: terrain seed %u n %d generated in %.0f ms\n",star?"star":"ring",seed,n,now_ms()-t0);
    field=island_field(&terrain,&p,ws.scratch,0,0);
    printf("field: %d trunks (%s), cover %s, hash %016" PRIx64 "\n",field.trunks?field.trunks->count:0,field.trunks?"M3":"none",field.cover?"yes":"no",field.hash);
    fresh(0,0);
    float nx=0,nz=0;
    int found=dry(0,0)&&gentle(0,0);
    if(star){island_nest(&world,&nx,&nz);found=1;}
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
        if(d<500||d>1600||!dry(x,z)||!gentle(x,z)||cp_stage_trunk_hit(&world,x,z,2.f))continue;   /* a GO into a trunk is refused by design (M3) */
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
        while(ticks<120000&&world.order.verb==CP_STAGE_GO){
            cp_stage_step(&world,NULL);
            ticks++;
        }
        const float left=sqrtf((world.player.x-tx[i])*(world.player.x-tx[i])+(world.player.z-tz[i])*(world.player.z-tz[i]));
        const int ok=world.order.verb!=CP_STAGE_GO&&left<3.f;
        reached+=ok;
        printf("  #%02d (%7.1f,%7.1f) %s plan %.2f ms, %d waypoints, %d ticks, %.1f m left%s\n",i,tx[i],tz[i],ok?"REACHED":"NOT REACHED",ms,wps,ticks,left,ok?"":(world.last_error?" (path failed)":" (timeout)"));
        if(!ok)printf("      stopped at (%.1f,%.1f) blocked_reason %d at (%.1f,%.1f) replans %d trunk_hit_here %d\n",world.player.x,world.player.z,world.blocked_reason,world.blocked_x,world.blocked_z,world.replans,cp_stage_trunk_hit(&world,world.player.x,world.player.z,1.f));
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
    uint8_t *blob=malloc(cp_stage_snapshot_size());
    for(int i=0;i<400;i++)cp_stage_step(&world,i==0?&go:NULL);
    assert(world.n_path>0);
    int bytes=cp_stage_snapshot(&world,blob,cp_stage_snapshot_size());
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
    if(star&&terrain.climate_n>0)forest_cases(&p,nx,nz);
    puts("PASS nav");
    return 0;
}
