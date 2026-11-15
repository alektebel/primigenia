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
    p.n=8; p.droplets=0; p.thermal_iters=0; p.pass_x=0; p.pass_y=0;
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    for(int i=0;i<64;i++) assert(f.t.sediment[i]==0);
    free(f.mem);
}
/* Actual connected sublevel sets, not just a low sample on the pass or rim. */
static int flood(Fixture *f,int start,float level,int lake) {
    int n=f->t.n,head=0,tail=0; memset(f->w.ups,0,(size_t)n*n*sizeof(int32_t));
    f->w.queue[tail++]=start; f->w.ups[start]=1;
    while(head<tail) {
        int i=f->w.queue[head++],x=i%n,y=i/n;
        float wx=(x+.5f)*f->t.size_m/n-f->t.size_m*.5f;
        float wy=(y+.5f)*f->t.size_m/n-f->t.size_m*.5f;
        if(lake ? (x==0 || y==0 || x==n-1 || y==n-1) : wx*wx+wy*wy>850.f*850.f) return 1;
        for(int d=0;d<4;d++) {
            int nx=x+(d==0)-(d==1),ny=y+(d==2)-(d==3);
            if(nx<0 || ny<0 || nx>=n || ny>=n) continue;
            int j=ny*n+nx; if(!f->w.ups[j] && f->t.height[j]<=level) {
                f->w.ups[j]=1; f->w.queue[tail++]=j;
            }
        }
    }
    return 0;
}
static void guarantees(void) {
    CpTerrainParams p; cp_terrain_params_default(&p); Fixture f=fixture(p.n);
    assert(cp_terrain_generate(&p,&f.t,&f.w,NULL,NULL)==0);
    cp_terrain_slope(f.t.height,p.n,p.size_m,f.w.scratch);
    int total=0,flat=0; float peak=-1e9f;
    for(int y=0;y<p.n;y++) for(int x=0;x<p.n;x++) {
        int i=y*p.n+x; float wx=(x+.5f)*p.size_m/p.n-p.size_m*.5f;
        float wy=(y+.5f)*p.size_m/p.n-p.size_m*.5f;
        if(wx*wx+wy*wy<=90.f*90.f) {total++; flat+=f.w.scratch[i]<.17632698f;}
        if(f.t.height[i]>peak) peak=f.t.height[i];
    }
    assert(flat>=.9f*total); assert(peak>400.f);
    int lx=(int)((p.lake_x_m/p.size_m+.5f)*p.n);
    int ly=(int)((p.lake_y_m/p.size_m+.5f)*p.n);
    float bottom=f.t.height[ly*p.n+lx];
    assert(bottom<30.f); assert(!flood(&f,ly*p.n+lx,bottom+10.f,1));
    assert(flood(&f,(p.n/2)*p.n+p.n/2,150.f,0));
    printf("W12: %.2f%% flat within 90m; lake holds >=10m; connected pass <=150m; peak %.2fm\n",100.*flat/total,peak);
    free(f.mem);
}
int main(int argc,char **argv) {
    validation(); helpers(); small();
    if(argc>1 && !strcmp(argv[1],"--heavy")) guarantees();
    puts("terrain: PASS"); return 0;
}
