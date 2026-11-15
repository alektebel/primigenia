#include "cpore/terrain.h"
#include <assert.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { CpTerrain t; CpTerrainWorkspace w; float *mem; } Fixture;
static Fixture fixture(int n) {
    Fixture f = {0}; size_t nn = (size_t)n*n;
    f.mem = calloc(nn*7, sizeof(float)); assert(f.mem);
    f.t.height=f.mem; f.t.flow=f.mem+nn; f.t.sediment=f.mem+2*nn;
    f.w.scratch=f.mem+3*nn;
    f.w.recv= (int32_t *)(f.mem+4*nn);
    f.w.ups= (int32_t *)(f.mem+5*nn);
    f.w.queue= (int32_t *)(f.mem+6*nn);
    return f;
}
static void validation(void) {
    CpTerrainParams p, q; cp_terrain_params_default(&p);
    assert(cp_terrain_validate(&p)==0);
    assert(cp_terrain_validate(NULL)==CP_TERR_ERR_NULL);
#define BAD(field, value) do { q=p; q.field=value; assert(cp_terrain_validate(&q)<0); } while(0)
    BAD(n,7); BAD(n,2049); BAD(size_m,NAN); BAD(size_m,0);
    BAD(octaves,0); BAD(octaves,9); BAD(droplets,-1); BAD(droplets,2000001);
    BAD(lifetime,0); BAD(lifetime,129); BAD(radius,0); BAD(radius,9);
    BAD(thermal_iters,-1); BAD(thermal_iters,49);
    BAD(frequency,INFINITY); BAD(frequency,.6f); BAD(warp_m,-1);
    BAD(ridge_weight,2); BAD(valley_radius_m,0); BAD(valley_floor_m,NAN);
    BAD(ring_inner_m,p.ring_outer_m); BAD(ring_height_m,0);
    BAD(pass_x,1e19f); BAD(pass_y,INFINITY); BAD(pass_height_m,1e19f);
    BAD(lake_x_m,1e19f); BAD(lake_y_m,NAN); BAD(lake_depth_m,-1);
    BAD(inertia,1); BAD(capacity,0); BAD(deposition,2); BAD(erosion,-1);
    BAD(evaporation,1); BAD(gravity,-1); BAD(min_slope,2); BAD(talus_deg,90);
    BAD(stream_iters,-1); BAD(stream_iters,257); BAD(stream_k,-1); BAD(stream_k,NAN);
    BAD(cliff_deg,90); BAD(col_x,INFINITY); BAD(col_y,NAN); BAD(col_height_m,1e19f);
    BAD(island_radius_m,0);
#undef BAD
    assert(cp_terrain_generate(&p,NULL,NULL,NULL,NULL)==CP_TERR_ERR_BUFFER);
    Fixture f=fixture(8); p.n=8;
    assert(cp_terrain_generate(&p,&f.t,NULL,NULL,NULL)==CP_TERR_ERR_BUFFER);
    free(f.mem);
}
typedef struct { int stage, done, calls; } Progress;
static void progress(int stage,int done,int total,void *user) {
    Progress *p=user; assert(stage>=p->stage); assert(done>=0 && done<=total);
    if(stage==p->stage) assert(done>=p->done);
    p->stage=stage; p->done=done; p->calls++;
}
static void helpers(void) {
    float h[64],s[64]; int8_t d[64];
    for(int y=0;y<8;y++) for(int x=0;x<8;x++) h[y*8+x]=2.f*x+3.f*y;
    cp_terrain_slope(h,8,8,s); cp_terrain_directions(h,8,8,d);
    for(int i=0;i<64;i++) assert(fabsf(s[i]-sqrtf(13.f))<1e-6f);
    assert(d[0]==-1); assert(d[9]==5); assert(d[7]==4);
    memset(h,0,sizeof h); cp_terrain_directions(h,8,8,d);
    for(int i=0;i<64;i++) assert(d[i]==-1);
}
static void small(void) {
    const uint32_t seeds[]={1,7,42}; Fixture f=fixture(32);
    CpTerrainParams p; cp_terrain_params_default(&p);
    p.n=32; p.droplets=300; p.thermal_iters=3;
    uint64_t previous=0;
    for(int k=0;k<3;k++) {
        p.seed=seeds[k]; Progress pr={0};
        assert(cp_terrain_generate(&p,&f.t,&f.w,progress,&pr)==0);
        assert(pr.stage==CP_TERR_STAGE_DONE && pr.calls>5);
        uint64_t hash=cp_terrain_hash(&f.t); assert(hash && hash!=previous); previous=hash;
        assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
        assert(cp_terrain_hash(&f.t)==hash);
        char path[128]; snprintf(path,sizeof path,"tests/golden/terrain-%" PRIu32 ".hash",p.seed);
        FILE *file=fopen(path,"r"); assert(file); uint64_t golden;
        assert(fscanf(file,"%" SCNx64,&golden)==1); fclose(file); assert(golden==hash);
        double outlets=0,deposit=0;
        for(int i=0;i<p.n*p.n;i++) {
            assert(isfinite(f.t.height[i])); assert(f.t.flow[i]>0 && f.t.flow[i]<=1);
            assert(f.t.sediment[i]>=0); deposit+=f.t.sediment[i];
            if(f.w.recv[i]<0) outlets+=f.t.flow[i];
        }
        assert(fabs(outlets-1)<1e-6); assert(deposit>0);
    }
    /* Hash explicit bytes, canonicalize signed zero, exclude pointers/padding. */
    f.t.height[0]=0; uint64_t h=cp_terrain_hash(&f.t); f.t.height[0]=-0.f;
    assert(h==cp_terrain_hash(&f.t)); f.t.flow[0]+=.01f; assert(h!=cp_terrain_hash(&f.t));
    assert(cp_terrain_hash(NULL)==0);
    CpTerrain invalid=f.t; invalid.n=INT32_MAX; assert(cp_terrain_hash(&invalid)==0);
    cp_terrain_params_default(NULL);
    /* Hydraulic transport conserves terrain mass when the terminal load settles. */
    p.seed=1; p.thermal_iters=0; p.droplets=0; p.stream_iters=0;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    double mass0=0,mass1=0;
    for(int i=0;i<p.n*p.n;i++)mass0+=f.t.height[i];
    p.droplets=300;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    for(int i=0;i<p.n*p.n;i++)mass1+=f.t.height[i];
    assert(fabs(mass1-mass0)<.01);
    /* A filled routing surface leaves the physical lake intact and reaches
     * all cells in a DAG; the integer queue has each cell exactly once. */
    for(int i=0;i<p.n*p.n;i++)f.w.ups[i]=0;
    for(int i=0;i<p.n*p.n;i++) {
        int cell=f.w.queue[i]; assert(cell>=0 && cell<p.n*p.n);
        assert(f.w.ups[cell]++==0);
        /* Epsilon fill: water always has somewhere strictly lower to go, and
         * the sea and the map edge are the only outlets. */
        if(f.w.recv[cell]>=0)assert(f.w.scratch[cell]>f.w.scratch[f.w.recv[cell]]);
        else assert(f.t.height[cell]<=0 || cell%p.n==0 || cell/p.n==0 || cell%p.n==p.n-1 || cell/p.n==p.n-1);
        if(f.t.height[cell]>0)assert(f.w.scratch[cell]>=f.t.height[cell]);
    }
    /* Stream power only removes rock or fills pits; it never makes the range taller. */
    { float peak0=-1e9f,peak1=-1e9f;
      for(int i=0;i<p.n*p.n;i++)if(f.t.height[i]>peak0)peak0=f.t.height[i];
      p.droplets=0;p.stream_iters=48;
      assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
      for(int i=0;i<p.n*p.n;i++){assert(isfinite(f.t.height[i]));if(f.t.height[i]>peak1)peak1=f.t.height[i];}
      assert(peak1<=peak0+30.f); p.stream_iters=0; }
    /* Thermal relaxation conserves mass as well. */
    p.droplets=0; p.thermal_iters=8;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    mass1=0;for(int i=0;i<p.n*p.n;i++)mass1+=f.t.height[i];
    assert(fabs(mass1-mass0)<.02);
    p.n=8; p.droplets=0; p.thermal_iters=0; p.pass_x=0; p.pass_y=0;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    for(int i=0;i<64;i++) assert(f.t.sediment[i]==0);
    p.size_m=100000.f;p.frequency=.5f;p.warp_m=200000.f;p.octaves=8;
    p.pass_x=10000.f;p.pass_y=-10000.f;p.radius=8;p.droplets=10;
    p.lifetime=128;p.thermal_iters=1;p.talus_deg=55;p.stream_iters=256;p.stream_k=1;
    p.cliff_deg=75;p.col_x=0;p.col_y=0;p.island_radius_m=400000.f;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    for(int i=0;i<64;i++)assert(isfinite(f.t.height[i]));
    free(f.mem);
}
/* Actual connected sublevel sets, not just a low sample on the gap or rim.
 * Four-connected flood below `level`; true when it reaches the sea or the map
 * edge. With block_gap the river-gap corridor is closed, which leaves the cols. */
static int escapes(Fixture *f,const CpTerrainParams *p,int start,float level,int block_gap) {
    int n=f->t.n,head=0,tail=0; memset(f->w.ups,0,(size_t)n*n*sizeof(int32_t));
    float len=sqrtf(p->pass_x*p->pass_x+p->pass_y*p->pass_y),px=p->pass_x/len,py=p->pass_y/len;
    f->w.queue[tail++]=start; f->w.ups[start]=1;
    while(head<tail) {
        int i=f->w.queue[head++],x=i%n,y=i/n;
        if(x==0 || y==0 || x==n-1 || y==n-1 || f->t.height[i]<=0) return 1;
        for(int d=0;d<4;d++) {
            int nx=x+(d==0)-(d==1),ny=y+(d==2)-(d==3),j=ny*n+nx;
            float wx=(nx+.5f)*f->t.size_m/n-f->t.size_m*.5f;
            float wy=(ny+.5f)*f->t.size_m/n-f->t.size_m*.5f;
            if(f->w.ups[j] || f->t.height[j]>level) continue;
            if(block_gap && wx*px+wy*py>0 && fabsf(-wx*py+wy*px)<450.f) continue;
            f->w.ups[j]=1; f->w.queue[tail++]=j;
        }
    }
    return 0;
}
/* W12 on the three evidence seeds: a flat start, a lake that holds water, a
 * river gap that drains the valley without a climb, a real col (a second way
 * out, high but not a wall), and peaks. */
static void guarantees(void) {
    const uint32_t seeds[]={1,7,42};
    CpTerrainParams p; cp_terrain_params_default(&p); Fixture f=fixture(p.n);
    for(int k=0;k<3;k++) {
        p.seed=seeds[k];
        assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
        cp_terrain_slope(f.t.height,p.n,p.size_m,f.w.scratch);
        int total=0,flat=0,centre=(p.n/2)*p.n+p.n/2; float peak=-1e9f;
        for(int y=0;y<p.n;y++) for(int x=0;x<p.n;x++) {
            int i=y*p.n+x; float wx=(x+.5f)*p.size_m/p.n-p.size_m*.5f;
            float wy=(y+.5f)*p.size_m/p.n-p.size_m*.5f;
            if(wx*wx+wy*wy<=90.f*90.f) {total++; flat+=f.w.scratch[i]<.17632698f;}
            if(f.t.height[i]>peak) peak=f.t.height[i];
        }
        assert(flat>=.9f*total); assert(peak>400.f);
        int lx=(int)((p.lake_x_m/p.size_m+.5f)*p.n);
        int ly=(int)((p.lake_y_m/p.size_m+.5f)*p.n);
        float bottom=f.t.height[ly*p.n+lx],start=f.t.height[centre];
        assert(bottom<30.f); assert(!escapes(&f,&p,ly*p.n+lx,bottom+10.f,0));
        assert(start>20.f && start<60.f);
        assert(escapes(&f,&p,centre,start+5.f,0));
        assert(!escapes(&f,&p,centre,100.f,1)); assert(escapes(&f,&p,centre,300.f,1));
        printf("W12 seed %" PRIu32 ": %.2f%% flat within 90m; lake holds >=10m; river gap <= start+5m; col between 100 and 300m; peak %.2fm\n",p.seed,100.*flat/total,peak);
    }
    free(f.mem);
}
int main(int argc,char **argv) {
    validation(); helpers(); small();
    if(argc>1 && !strcmp(argv[1],"--heavy")) guarantees();
    puts("terrain: PASS"); return 0;
}
