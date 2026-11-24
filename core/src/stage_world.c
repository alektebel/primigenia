#include "cpore/world.h"
#include "cpore/steer.h"
#include "../../apps/combat_bots.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <stddef.h>
#ifdef NAV_STATS
#include <time.h>
#endif
const CpStageSpecies CP_STAGE_SPECIES[CP_STAGE_SPECIES_COUNT]={
    {
        "Rondo",4.4f,20,22,0,CP_STAGE_TIMID,{
            0,0,2,0,0,60,100,4.4f,0,0
        },CP_ACT_DIURNAL
    },
    {
        "Zanco",5.2f,24,26,0,CP_STAGE_TIMID,{
            0,0,2,1,0,70,100,5.2f,0,0
        },CP_ACT_DIURNAL
    },
    {
        "Espinodo",4,24,22,8,CP_STAGE_TERRITORIAL,{
            2,1,0,2,1,100,100,4,0,0
        },CP_ACT_DIURNAL
    },
    {
        "Garfio",5.8f,28,24,28,CP_STAGE_AGGRESSIVE,{
            3,0,0,1,0,80,100,5.8f,0,0
        },CP_ACT_DIURNAL
    },
    {
        /* C2 secrets (W8, G68): the nocturnal creature. Asleep and hidden while the day is bright, a stealthy ambusher at night. */
        "Acechalunas",5.4f,30,28,6,CP_STAGE_TERRITORIAL,{
            1,0,0,2,0,70,100,5.4f,0,0
        },CP_ACT_NOCTURNAL
    },
    {
        /* The sixth species: a slow herbivore that hunkers into its mucus sphere in the noon light. */
        "Babosa",2.4f,16,14,0,CP_STAGE_TIMID,{
            0,0,2,0,2,80,100,2.4f,0,0
        },CP_ACT_CREPUSCULAR
    },
    {"Brujula",2.0f,14,10,0,CP_STAGE_TERRITORIAL,{0,0,0,0,2,70,100,2.0f,0},CP_ACT_DIURNAL},
    {"Corona",1.4f,10,8,0,CP_STAGE_TIMID,{0,0,1,0,1,50,100,1.4f,0},CP_ACT_CREPUSCULAR}
    /* 8..11: reserved capacity (zero rows) for the food-web species (T11) and flying species (A59); never spawned (CP_STAGE_SPECIES_DEFINED) */
};
static float clamp(float x,float a,float b){
    return x<a?a:x>b?b:x;
}
static float ab(float x){
    return x<0?-x:x;
}
static float length(float x,float z){
    return sqrtf(x*x+z*z);
}
static float dist(const CpStageCreature *a,const CpStageCreature *b){
    return length(a->x-b->x,a->z-b->z);
}
static float mix(float a,float b,float t){
    return a+(b-a)*t;
}
static int floor_int(float x){
    int i=(int)x;
    return x<i?i-1:i;
}
/* exp(-x), range reduction + reciprocal Taylor; no libm transcendental. */
static float decay(float x){
    if(x>32)return 0;
    float v=x/32;
    float p=1+v*(1+v*(.5f+v*(1.0f/6+v*(1.0f/24+v/120))));
    p=1/p;
    for(int i=0;i<5;i++)p*=p;
    return p;
}
static uint32_t mulberry(uint32_t *a){
    *a+=0x6D2B79F5u;
    uint32_t t=(*a^(*a>>15))*(1u|*a);
    t^=t+(t^(t>>7))*(61u|t);
    return t^(t>>14);
}
static void seed_noise(CpStageWorld *w){
    uint32_t a=w->setup.terrain_seed*7919u+13;
    uint8_t p[256];
    for(int i=0;i<256;i++)p[i]=(uint8_t)i;
    for(int i=255;i>0;i--){
        int j=(int)(((uint64_t)mulberry(&a)*(uint32_t)(i+1))>>32);
        uint8_t t=p[i];
        p[i]=p[j];
        p[j]=t;
    }
    for(int i=0;i<512;i++)w->noise[i]=p[i&255];
}
static float noise(const CpStageWorld *w,float x,float z){
    int ix=floor_int(x),iz=floor_int(z);
    float u=x-ix,v=z-iz;
    u=u*u*(3-2*u);
    v=v*v*(3-2*v);
    float a=w->noise[w->noise[ix&255]+(iz&255)]/255.f,b=w->noise[w->noise[(ix+1)&255]+(iz&255)]/255.f;
    float c=w->noise[w->noise[ix&255]+((iz+1)&255)]/255.f,d=w->noise[w->noise[(ix+1)&255]+((iz+1)&255)]/255.f;
    return mix(mix(a,b,u),mix(c,d,u),v);
}
static float fbm(const CpStageWorld *w,float x,float z,int n){
    float a=.5f,f=1,s=0,total=0;
    for(int i=0;i<n;i++){
        s+=a*noise(w,x*f,z*f);
        total+=a;
        a*=.5f;
        f*=2.03f;
    }
    return s/total;
}
/* --- FIELD mode (PLAN-heights H1): the generated island heights, read through a pointer ---------------
 * Same surface as godot/game/island/terrain_data.gd ground(): cell-centred samples, two triangles per quad
 * with the (i+1,j)-(i,j+1) diagonal, clamped at the edge. Only + - * / and floor, so it is deterministic. */
static int clampi(int x,int a,int b){
    return x<a?a:x>b?b:x;
}
static int field_ok(const CpStageField *f){
    return f&&f->n>=2&&f->height&&isfinite(f->size_m)&&isfinite(f->cell)&&isfinite(f->half)&&f->cell>0&&f->half>0;
}
static float field_ground(const CpStageField *f,float x,float z){
    const float lim=(float)f->n;
    float u=clamp((x+f->half)/f->cell-.5f,-1,lim),v=clamp((z+f->half)/f->cell-.5f,-1,lim);
    int i=clampi(floor_int(u),0,f->n-2),j=clampi(floor_int(v),0,f->n-2);
    float fu=clamp(u-i,0,1),fv=clamp(v-j,0,1);
    const float *h=f->height+(size_t)j*f->n+i;
    return fu>=fv?h[0]+fu*(h[1]-h[0])+fv*(h[f->n+1]-h[1]):h[0]+fv*(h[f->n]-h[0])+fu*(h[f->n+1]-h[f->n]);
}
static float bound_of(int terrain,const CpStageField *f){
    return terrain==CP_STAGE_FIELD&&field_ok(f)?f->half-2*f->cell:195.f;
}
float cp_stage_bound(const CpStageWorld *w){
    return bound_of(w->setup.terrain,w->field);
}
/* Depth of standing water at (x,z): sea below 0 m, ponds (depression-filled level well above the ground),
 * the FLAT circle; 0 on dry land. FIELD uses the nearest cell, like TerrainData.is_pond/is_sea. */
float cp_stage_water_depth(const CpStageWorld *w,float x,float z){
    if(!isfinite(x)||!isfinite(z))return 0;
    if(w->setup.terrain==CP_STAGE_FIELD){
        const CpStageField *f=w->field;
        if(!field_ok(f))return 0;
        const float lim=(float)f->n;
        int i=clampi(floor_int(clamp((x+f->half)/f->cell,-1,lim)),0,f->n-1),j=clampi(floor_int(clamp((z+f->half)/f->cell,-1,lim)),0,f->n-1);
        size_t k=(size_t)j*f->n+i;
        float h=f->height[k];
        if(h<=0)return -h;
        if(f->water_level&&f->water_level[k]-h>.5f)return f->water_level[k]-h;
        return 0;
    }
    if(w->setup.terrain==CP_STAGE_FLAT)return length(x-w->setup.water_x,z-w->setup.water_z)<w->setup.water_radius?1.f:0.f;
    return 0;
}
float cp_stage_height(const CpStageWorld *w,float x,float z){
    if(!isfinite(x)||!isfinite(z)||ab(x)>100000||ab(z)>100000)return 0;
    if(w->setup.terrain==CP_STAGE_FIELD)return field_ok(w->field)?cp_stage_secrets_ground(w,x,z,field_ground(w->field,x,z)):0;
    if(w->setup.terrain==CP_STAGE_FLAT){
        float d=length(x-w->setup.water_x,z-w->setup.water_z);
        return d<w->setup.water_radius?-1:w->setup.flat_height;
    }
    float d=length(x,z),h=(fbm(w,x*.006f+10,z*.006f+10,4)-.5f)*30+4;
    float c=decay(d*d/1600)*.8f;
    h=h*(1-c)+3*c;
    float lx=x-70,lz=z+55;
    h-=12*decay((lx*lx+lz*lz)/1500);
    float m=clamp((d/320-.42f)/.48f,0,1);
    m=m*m*(3-2*m);
    float rid=1-ab(fbm(w,x*.004f+50,z*.004f+50,5)*2-1);
    return h+m*(25+rid*rid*150)+m*m*30;
}
/* Same 256x256 triangular surface used by the stage mesh. W11 replaces this
 * interface without changing movement or perception. */
float cp_stage_ground(const CpStageWorld *w,float x,float z){
    if(!isfinite(x)||!isfinite(z))return 0;
    if(w->setup.terrain==CP_STAGE_FLAT||w->setup.terrain==CP_STAGE_FIELD)return cp_stage_height(w,x,z);
    float fx=clamp((x+320)/2.5f,0,255.999f),fz=clamp((z+320)/2.5f,0,255.999f);
    int ix=(int)fx,iz=(int)fz;
    float u=fx-ix,v=fz-iz,px=ix*2.5f-320,pz=iz*2.5f-320;
    float a=cp_stage_height(w,px,pz),b=cp_stage_height(w,px,pz+2.5f),c=cp_stage_height(w,px+2.5f,pz+2.5f),d=cp_stage_height(w,px+2.5f,pz);
    return u+v<=1?a+u*(d-a)+v*(b-a):c+(1-u)*(b-c)+(1-v)*(d-c);
}
int cp_stage_can_walk(const CpStageWorld *w,float x,float z,float nx,float nz,float radius){
    if(!isfinite(x)||!isfinite(z)||!isfinite(nx)||!isfinite(nz)||!isfinite(radius)||radius<0)return 0;
    if(ab(x)>10000||ab(z)>10000||ab(nx)>cp_stage_bound(w)||ab(nz)>cp_stage_bound(w))return 0;
    const int field=w->setup.terrain==CP_STAGE_FIELD;
    const float dx=nx-x,dz=nz-z,distance=length(dx,dz);
    const int steps=(int)(distance/.25f)+1;
    float previous=cp_stage_ground(w,x,z);
    for(int i=1;i<=steps;i++){
        const float t=(float)i/steps,height=cp_stage_ground(w,x+dx*t,z+dz*t);
        if((field?cp_stage_water_depth(w,x+dx*t,z+dz*t)>.7f:height<-.7f)||ab(height-previous)>distance/steps*1.2f+.04f)return 0;
        previous=height;
    }
    for(int i=0;i<w->setup.n_obstacles;i++){
        const CpStageObstacle *o=&w->setup.obstacles[i];
        const float t=distance>0?clamp(((o->x-x)*dx+(o->z-z)*dz)/(distance*distance),0,1):0;
        if(length(x+dx*t-o->x,z+dz*t-o->z)<o->r+radius)return 0;
    }
    return 1;
}
/* A body does not follow a planned line to the centimetre (yaw inertia, turn radius), so a route may not skim blocking water:
 * the planner, its shortcuts and the waypoint following also want `clear` metres of dry-enough ground either side of the line.
 * Carved deep rivers are one cell wide, so without this a plan threads the corner between two deep cells and the body drives
 * into the channel. Field terrain only (the other terrains have no narrow channels). */
#define WATER_MARGIN 1.f
static int water_clear(const CpStageWorld *w,float x,float z,float nx,float nz,float clear){
    if(w->setup.terrain!=CP_STAGE_FIELD)return 1;
    const float dx=nx-x,dz=nz-z,distance=length(dx,dz);
    if(distance<1e-4f)return 1;
    const float px=-dz/distance*clear,pz=dx/distance*clear;
    const int steps=(int)(distance/1.f)+1;
    for(int i=0;i<=steps;i++){
        const float t=(float)i/steps,cx=x+dx*t,cz=z+dz*t;
        if(cp_stage_water_depth(w,cx+px,cz+pz)>.7f||cp_stage_water_depth(w,cx-px,cz-pz)>.7f)return 0;
    }
    return 1;
}
/* Shared planning/shortcut/following rule: directional climb, full-gradient holding limit and lateral clearance.
 * Clearance keeps inertial steering away from bank facets that the centre line alone could skirt. */
static void ground_grad(const CpStageWorld *w,float x,float z,float *gx,float *gz,float h);
static int walk_ok(const CpStageWorld *w,float x,float z,float nx,float nz,float radius,float climb,float grip){
    /* Keep the planner's existing conservative contour margin, capped by actual grip.
     * Larger holding ability must not route inertial bodies along bank edges. */
    const float comfort=climb*w->motion.stall_mul*w->motion.slide_mul;
    const float hold=(grip<comfort?grip:comfort)+.0001f;
    if(!cp_stage_can_walk(w,x,z,nx,nz,radius))return 0;
    const float dx=nx-x,dz=nz-z,distance=length(dx,dz);
    const int steps=(int)(distance/1.f)+1;
    float previous=cp_stage_ground(w,x,z);
    const float run=distance/steps;
    const float px=distance>0?-dz/distance:0,pz=distance>0?dx/distance:0;
    const float hold2=hold*hold;
    for(int i=0;i<=steps;i++){
        const float t=(float)i/steps,height=cp_stage_ground(w,x+dx*t,z+dz*t);
        float gx,gz;
        ground_grad(w,x+dx*t,z+dz*t,&gx,&gz,.25f);
        if(gx*gx+gz*gz>hold2)return 0;
        if(distance>0){
            ground_grad(w,x+dx*t+px,z+dz*t+pz,&gx,&gz,.25f);
            if(gx*gx+gz*gz>hold2)return 0;
            ground_grad(w,x+dx*t-px,z+dz*t-pz,&gx,&gz,.25f);
            if(gx*gx+gz*gz>hold2)return 0;
        }
        if(ab(height-previous)>(climb+.0001f)*run)return 0;
        previous=height;
    }
    return water_clear(w,x,z,nx,nz,radius+WATER_MARGIN);
}
static float player_climb(const CpStageWorld *w){
    CpSteerBody body;
    cp_steer_creature(&w->motion,&w->player,&body);
    return body.climb;
}
int cp_stage_walkable_from_nest(const CpStageWorld *w,float x,float z){
    return walk_ok(w,w->setup.nest_x,w->setup.nest_z,x,z,cp_combat_body_radius(&w->player.profile),player_climb(w),cp_stage_grip_grade(&w->player.profile,w->player.legs));
}
/* --- C1-nav: events, block reasons, the walk grid and the GO planner (docs/godot/NAV.md) ---------------- */
static void ev_push(CpStageWorld *w,int type,int by,int target,int move,float value,float x,float z){
    w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,by,target,move,value,x,z};
    w->ev_total++;
}
void cp_stage_ack_events(CpStageWorld *w){
    if(w)w->ev_acked=w->ev_total;
}
/* Why cp_stage_can_walk refuses the straight move: the same checks, in the same order, naming the first failure. */
static int block_reason(const CpStageWorld *w,float x,float z,float nx,float nz,float radius){
    const float bound=cp_stage_bound(w);
    if(!isfinite(nx)||!isfinite(nz)||ab(nx)>bound||ab(nz)>bound)return CP_STAGE_BLOCK_EDGE;
    const int field=w->setup.terrain==CP_STAGE_FIELD;
    const float dx=nx-x,dz=nz-z,distance=length(dx,dz);
    const int steps=(int)(distance/.25f)+1;
    float previous=cp_stage_ground(w,x,z);
    for(int i=1;i<=steps;i++){
        const float t=(float)i/steps,height=cp_stage_ground(w,x+dx*t,z+dz*t);
        if(field?cp_stage_water_depth(w,x+dx*t,z+dz*t)>.7f:height<-.7f)return CP_STAGE_BLOCK_WATER;
        if(ab(height-previous)>distance/steps*1.2f+.04f)return CP_STAGE_BLOCK_CLIFF;
        previous=height;
    }
    for(int i=0;i<w->setup.n_obstacles;i++){
        const CpStageObstacle *o=&w->setup.obstacles[i];
        const float t=distance>0?clamp(((o->x-x)*dx+(o->z-z)*dz)/(distance*distance),0,1):0;
        if(length(x+dx*t-o->x,z+dz*t-o->z)<o->r+radius)return CP_STAGE_BLOCK_OBSTACLE;
    }
    return CP_STAGE_BLOCK_CLIFF;
}
/* The walk grid: cells of ~4 m over the walkable square, 8 passability bits per cell computed with
 * cp_stage_can_walk between cell centres for the player's body radius. It is a pure function of the attached
 * field, the obstacles and the radius, so it lives in static derived storage (not in the world, not in the
 * snapshot, not hashed) and is filled lazily, one cell the first time the search expands it. A signature of its
 * inputs decides when it is thrown away. */
/* Native and WASM use the same planner: resource-node placement probes it too.
 * The world WASM target reserves enough memory for these derived caches. */
#define NAV_DIM 1024
#define NAV_EXPAND 500000
#define NAV_HEAP (1<<21)
#define NAV_CELLS ((size_t)NAV_DIM*NAV_DIM)
static uint8_t nav_mask[NAV_CELLS];
static float nav_gr[NAV_CELLS];   /* memoised ground height at the cell centre (NaN = not yet sampled); same value cp_stage_ground returns */
static int32_t nav_g[NAV_CELLS];
static uint32_t nav_stamp[NAV_CELLS];
static uint8_t nav_dir[NAV_CELLS];
static uint64_t nav_heap[NAV_HEAP];
static int32_t nav_cells[NAV_EXPAND+2];
static struct {
    uint64_t sig;
    int dim,valid;
    float cs,bound,radius,climb,grip;
    uint32_t gen;
} nav;
static const int NAV_DX[8]={1,1,0,-1,-1,-1,0,1},NAV_DZ[8]={0,1,1,1,0,-1,-1,-1};
static void sig_u32(uint64_t *h,uint32_t v){
    for(int i=0;i<4;i++){
        *h^=(uint8_t)(v>>(8*i));
        *h*=1099511628211ULL;
    }
}
static void sig_fl(uint64_t *h,float v){
    uint32_t bits=0;
    memcpy(&bits,&v,4);
    sig_u32(h,bits);
}
static int nav_ready(const CpStageWorld *w){
    if(NAV_DIM<4||w->setup.terrain!=CP_STAGE_FIELD||!field_ok(w->field))return 0;
    const float radius=cp_combat_body_radius(&w->player.profile),bound=cp_stage_bound(w);
    uint64_t h=14695981039346656037ULL;
    sig_u32(&h,(uint32_t)w->field->hash);
    sig_u32(&h,(uint32_t)(w->field->hash>>32));
    sig_u32(&h,(uint32_t)w->field->n);
    sig_fl(&h,w->field->size_m);
    sig_u32(&h,(uint32_t)(uintptr_t)w->field->height);
    sig_u32(&h,(uint32_t)((uint64_t)(uintptr_t)w->field->height>>32));
    sig_fl(&h,radius);
    CpSteerBody body;
    cp_steer_creature(&w->motion,&w->player,&body);
    sig_fl(&h,body.climb);sig_fl(&h,cp_stage_grip_grade(&w->player.profile,w->player.legs));
    sig_fl(&h,w->motion.stall_mul);
    sig_fl(&h,w->motion.slide_mul);
    /* the carved cave changes the walkable ground (stage_secrets.c), so it is part of the signature */
    sig_u32(&h,(uint32_t)w->secrets.cave_on);
    if(w->secrets.cave_on){sig_fl(&h,w->secrets.cave_x);sig_fl(&h,w->secrets.cave_z);sig_fl(&h,w->secrets.cave_fx);sig_fl(&h,w->secrets.cave_fz);
        sig_fl(&h,w->secrets.cave_floor);sig_fl(&h,w->secrets.cave_half);sig_fl(&h,w->secrets.cave_length);sig_fl(&h,w->secrets.cave_radius);}
    sig_u32(&h,(uint32_t)w->setup.n_obstacles);
    for(int i=0;i<w->setup.n_obstacles;i++){
        sig_fl(&h,w->setup.obstacles[i].x);
        sig_fl(&h,w->setup.obstacles[i].z);
        sig_fl(&h,w->setup.obstacles[i].r);
    }
    if(nav.valid&&nav.sig==h)return 1;
    int dim=(int)(2*bound/4+.999f);
    if(dim<2)dim=2;
    if(dim>NAV_DIM)dim=NAV_DIM;
    nav.sig=h;
    nav.dim=dim;
    nav.cs=2*bound/dim;
    nav.bound=bound;
    nav.radius=radius;
    nav.climb=body.climb;nav.grip=cp_stage_grip_grade(&w->player.profile,w->player.legs);   /* the creature's own grip: nav cost and holding limit */
    nav.valid=1;
    memset(nav_mask,0,(size_t)dim*dim*sizeof *nav_mask);
    memset(nav_gr,0xFF,(size_t)dim*dim*sizeof *nav_gr);
    return 1;
}
float cp_stage_nav_cell(const CpStageWorld *w){
    return w&&nav_ready(w)?nav.cs:0;
}
static float nav_c(int i){
    return -nav.bound+((float)i+.5f)*nav.cs;
}
static int nav_index_of(float v){
    int i=floor_int((v+nav.bound)/nav.cs);
    return clampi(i,0,nav.dim-1);
}
/* One byte per cell: bits 0-3 the memoised result of the four forward edges E, SE, S, SW, bits 4-7 "known".
 * The backward edges of a cell are the forward edges of its neighbours, so each undirected edge is tested once
 * (can_walk is symmetric: same sample points, same slope rule). */
static int nav_edge(const CpStageWorld *w,int idx,int d){
    const int i=idx%nav.dim,j=idx/nav.dim;
    int from=idx,dir=d;
    if(d>=4){
        const int ni=i+NAV_DX[d],nj=j+NAV_DZ[d];
        if(ni<0||nj<0||ni>=nav.dim||nj>=nav.dim)return 0;
        from=nj*nav.dim+ni;
        dir=d-4;
    }
    else if(i+NAV_DX[d]<0||j+NAV_DZ[d]<0||i+NAV_DX[d]>=nav.dim||j+NAV_DZ[d]>=nav.dim)return 0;
    const int fi=from%nav.dim,fj=from/nav.dim;
    uint8_t m=nav_mask[from];
    if(!(m&(16u<<dir))){
        /* an edge steeper than the player's body can climb is no edge (the walk cost below also prefers flatter routes) */
        const int ok=walk_ok(w,nav_c(fi),nav_c(fj),nav_c(fi+NAV_DX[dir]),nav_c(fj+NAV_DZ[dir]),nav.radius,nav.climb,nav.grip);
        m|=(uint8_t)((16u<<dir)|(ok?1u<<dir:0));
        nav_mask[from]=m;
    }
    return (m>>dir)&1;
}
/* The 8 passability bits of a cell (bit d = may step in direction d). */
static uint16_t nav_cell(const CpStageWorld *w,int idx){
    uint16_t m=0;
    {   /* fast path: interior cell whose 4 forward edges and the 4 neighbours' forward edges are all memoised */
        const int d=nav.dim,i=idx%d;
        if(i>0&&i<d-1&&idx>=d&&idx<d*d-d){
            const uint8_t f=nav_mask[idx],e=nav_mask[idx-1],nw=nav_mask[idx-d-1],n=nav_mask[idx-d],ne=nav_mask[idx-d+1];
            if((f&0xF0)==0xF0&&(e&0x10)&&(nw&0x20)&&(n&0x40)&&(ne&0x80))
                return (uint16_t)((f&15)|((e&1)<<4)|(((nw>>1)&1)<<5)|(((n>>2)&1)<<6)|(((ne>>3)&1)<<7));
        }
    }
    for(int d=0;d<8;d++)if(nav_edge(w,idx,d))m|=(uint16_t)(1u<<d);
    return m;
}
static float nav_ground(const CpStageWorld *w,int i,int j){
    float *g=&nav_gr[j*nav.dim+i];
    if(*g!=*g)*g=cp_stage_ground(w,nav_c(i),nav_c(j));
    return *g;
}
static int nav_hij(int i,int j,int gi,int gj){
    const int dx=i>gi?i-gi:gi-i,dz=j>gj?j-gj:gj-j;
    return 10*(dx>dz?dx:dz)+4*(dx<dz?dx:dz);
}
static int nav_h(int idx,int gi,int gj){
    return nav_hij(idx%nav.dim,idx/nav.dim,gi,gj);
}
static size_t heap_n;
static int heap_push(uint64_t key){
    if(heap_n>=NAV_HEAP)return -1;
    size_t i=heap_n++;
    while(i>0){
        size_t p=(i-1)/2;
        if(nav_heap[p]<=key)break;
        nav_heap[i]=nav_heap[p];
        i=p;
    }
    nav_heap[i]=key;
    return 0;
}
static uint64_t heap_pop(void){
    uint64_t top=nav_heap[0],last=nav_heap[--heap_n];
    size_t i=0;
    for(;;){
        size_t c=2*i+1;
        if(c>=heap_n)break;
        if(c+1<heap_n&&nav_heap[c+1]<nav_heap[c])c++;
        if(nav_heap[c]>=last)break;
        nav_heap[i]=nav_heap[c];
        i=c;
    }
    if(heap_n)nav_heap[i]=last;
    return top;
}
/* A*: costs 10/14, octile heuristic, ties broken by lowest f, then lowest h, then lowest cell index (the packed
 * key orders exactly so). Returns the number of cells of the path start..goal in nav_cells, or -1 (no route
 * within NAV_EXPAND expansions / heap capacity). */
#ifdef NAV_STATS
static int nav_expanded_last;
#endif
static int nav_astar(const CpStageWorld *w,int start,int goal){
    if(++nav.gen==0){
        memset(nav_stamp,0,NAV_CELLS*sizeof *nav_stamp);
        nav.gen=1;
    }
    const int gi=goal%nav.dim,gj=goal/nav.dim;
    heap_n=0;
    nav_stamp[start]=nav.gen;
    nav_g[start]=0;
    nav_dir[start]=255;
    heap_push(((uint64_t)nav_h(start,gi,gj)<<36)|((uint64_t)nav_h(start,gi,gj)<<20)|(uint64_t)start);
    int expanded=0;
    while(heap_n){
        const uint64_t key=heap_pop();
        const int idx=(int)(key&0xFFFFF);
        const int h=nav_h(idx,gi,gj);
        if(nav_stamp[idx]!=nav.gen||(int64_t)(key>>36)!=(int64_t)nav_g[idx]+h)continue;
        if(idx==goal){
#ifdef NAV_STATS
            nav_expanded_last=expanded;
#endif
            int count=0;
            for(int c=goal;c!=start;){
                nav_cells[count++]=c;
                const int d=nav_dir[c];
                c-=NAV_DZ[d]*nav.dim+NAV_DX[d];
            }
            nav_cells[count++]=start;
            for(int a=0,b=count-1;a<b;a++,b--){
                int t=nav_cells[a];
                nav_cells[a]=nav_cells[b];
                nav_cells[b]=t;
            }
            return count;
        }
        if(++expanded>NAV_EXPAND)return -1;
        const uint16_t m=nav_cell(w,idx);
        const int i=idx%nav.dim,j=idx/nav.dim;
        for(int d=0;d<8;d++){
            if(!(m&(1u<<d)))continue;
            const int n=(j+NAV_DZ[d])*nav.dim+i+NAV_DX[d];
            const float rise=nav_ground(w,i+NAV_DX[d],j+NAV_DZ[d])-nav_ground(w,i,j);
            const int ng=nav_g[idx]+((d&1)?14:10)+(int)(ab(rise)/nav.cs*6*(CP_STEER_GRADE_MAX/nav.grip));   /* a steeper step costs more: 6 per unit of grade */
            if(nav_stamp[n]==nav.gen&&ng>=nav_g[n])continue;
            nav_stamp[n]=nav.gen;
            nav_g[n]=ng;
            nav_dir[n]=(uint8_t)d;
            uint64_t hn=(uint64_t)nav_hij(i+NAV_DX[d],j+NAV_DZ[d],gi,gj);
            if(hn>65535)hn=65535;
            if(heap_push((((uint64_t)ng+hn)<<36)|(hn<<20)|(uint64_t)n))return -1;
        }
    }
    return -1;
}
static float point_x(int k,int count,float sx,float ex){
    return k==0?sx:k==count+1?ex:nav_c(nav_cells[k-1]%nav.dim);
}
static float point_z(int k,int count,float sz,float ez){
    return k==0?sz:k==count+1?ez:nav_c(nav_cells[k-1]/nav.dim);
}
/* Plans from the player to (tx,tz). 0 = path stored (and an event), CP_STAGE_BLOCK_UNREACHABLE otherwise. */
static int plan_path(CpStageWorld *w,float tx,float tz){
    const float radius=cp_combat_body_radius(&w->player.profile),sx=w->player.x,sz=w->player.z;
    float pp[CP_STAGE_MAX_PATH][2];
    if(!nav_ready(w)||!isfinite(tx)||!isfinite(tz))return CP_STAGE_BLOCK_UNREACHABLE;
    float ex=tx,ez=tz;
    int count=0;
    if(!walk_ok(w,sx,sz,tx,tz,radius,nav.climb,nav.grip)){
        /* start cell: the nearest cell centre of the 5x5 block the player can walk to */
        const int ci=nav_index_of(sx),cj=nav_index_of(sz);
        int start=-1,gcell=-1;
        {
            int idxs[25];
            float d2[25];
            int n=0;
            for(int dj=-2;dj<=2;dj++)for(int di=-2;di<=2;di++){
                const int i=ci+di,j=cj+dj;
                if(i<0||j<0||i>=nav.dim||j>=nav.dim)continue;
                const float dx=nav_c(i)-sx,dz=nav_c(j)-sz;
                idxs[n]=j*nav.dim+i;
                d2[n++]=dx*dx+dz*dz;
            }
            for(int pick=0;pick<n&&start<0;pick++){
                int best=-1;
                for(int k=0;k<n;k++)if(idxs[k]>=0&&(best<0||d2[k]<d2[best]||(d2[k]==d2[best]&&idxs[k]<idxs[best])))best=k;
                const int idx=idxs[best];
                idxs[best]=-1;
                if(walk_ok(w,sx,sz,nav_c(idx%nav.dim),nav_c(idx/nav.dim),radius,nav.climb,nav.grip)&&nav_cell(w,idx))start=idx;
            }
        }
        if(start<0)return CP_STAGE_BLOCK_UNREACHABLE;
        /* goal cell: nearest connected cell within 3 cells (~12 m) from which the target itself is walkable,
         * otherwise reject: arrival must refer to the requested destination */
        {
            const int ti=nav_index_of(tx),tj=nav_index_of(tz);
            int idxs[49];
            float d2[49];
            int n=0;
            for(int dj=-3;dj<=3;dj++)for(int di=-3;di<=3;di++){
                const int i=ti+di,j=tj+dj;
                if(i<0||j<0||i>=nav.dim||j>=nav.dim)continue;
                const float dx=nav_c(i)-tx,dz=nav_c(j)-tz;
                if(dx*dx+dz*dz>144.f)continue;
                idxs[n]=j*nav.dim+i;
                d2[n++]=dx*dx+dz*dz;
            }
            for(int pick=0;pick<n&&gcell<0;pick++){
                int best=-1;
                for(int k=0;k<n;k++)if(idxs[k]>=0&&(best<0||d2[k]<d2[best]||(d2[k]==d2[best]&&idxs[k]<idxs[best])))best=k;
                const int idx=idxs[best];
                idxs[best]=-1;
                if(!nav_cell(w,idx))continue;
                if(walk_ok(w,nav_c(idx%nav.dim),nav_c(idx/nav.dim),tx,tz,radius,nav.climb,nav.grip))gcell=idx;
            }
        }
        if(gcell<0)return CP_STAGE_BLOCK_UNREACHABLE;
#ifdef NAV_STATS
        { struct timespec a,b; clock_gettime(CLOCK_MONOTONIC,&a); count=nav_astar(w,start,gcell); clock_gettime(CLOCK_MONOTONIC,&b);
          fprintf(stderr,"astar %.2f ms count %d expanded %d\n",(b.tv_sec-a.tv_sec)*1e3+(b.tv_nsec-a.tv_nsec)/1e6,count,nav_expanded_last); }
#else
        count=nav_astar(w,start,gcell);
#endif
        if(count<0)return CP_STAGE_BLOCK_UNREACHABLE;
    }
    /* string pull over the points: player, the cell centres, the end point; every kept segment is checked by
     * cp_stage_can_walk, found by doubling the reach and then bisecting */
    const int m=count+2;
    int anchor=0;
    float length_m=0,px=sx,pz=sz;
    int n=0;
    if(count==0){
        pp[n][0]=ex;
        pp[n++][1]=ez;
        length_m=length(ex-sx,ez-sz);
    }
    else while(anchor<m-1&&n<CP_STAGE_MAX_PATH){
        const float ax=point_x(anchor,count,sx,ex),az=point_z(anchor,count,sz,ez);
        int lo=anchor+1,hi=-1,t=2;
        while(lo<m-1){
            int j=anchor+t;
            if(j>m-1)j=m-1;
            if(walk_ok(w,ax,az,point_x(j,count,sx,ex),point_z(j,count,sz,ez),radius,nav.climb,nav.grip)){
                lo=j;
                t*=2;
            }
            else{
                hi=j;
                break;
            }
        }
        while(hi>0&&hi-lo>1){
            const int mid=(lo+hi)/2;
            if(walk_ok(w,ax,az,point_x(mid,count,sx,ex),point_z(mid,count,sz,ez),radius,nav.climb,nav.grip))lo=mid;
            else hi=mid;
        }
        const float bx=point_x(lo,count,sx,ex),bz=point_z(lo,count,sz,ez);
        pp[n][0]=bx;
        pp[n++][1]=bz;
        length_m+=length(bx-px,bz-pz);
        px=bx;
        pz=bz;
        anchor=lo;
    }
    memset(w->path,0,sizeof w->path);
    memcpy(w->path,pp,(size_t)n*sizeof *pp);
    w->n_path=n;
    w->path_i=0;
    w->path_goal_x=ex;
    w->path_goal_z=ez;
    w->blocked_ticks=0;
    ev_push(w,CP_STAGE_EV_PATH_FOUND,0,0,-1,length_m,ex,ez);
    return 0;
}
/* Placement may need a route around a river. Preserve every observable field;
 * the navigation cache is derived and intentionally stays warm. */
int cp_stage_route_from_nest(CpStageWorld *w,float x,float z){
    float path[CP_STAGE_MAX_PATH][2];memcpy(path,w->path,sizeof path);
    const float px=w->player.x,pz=w->player.z,gx=w->path_goal_x,gz=w->path_goal_z;
    const int n=w->n_path,i=w->path_i,blocked=w->blocked_ticks;
    const uint32_t total=w->ev_total;const CpStageEvent event=w->events[total%CP_STAGE_MAX_EVENTS];
    w->player.x=w->setup.nest_x;w->player.z=w->setup.nest_z;
    int rc=plan_path(w,x,z);
    w->player.x=px;w->player.z=pz;memcpy(w->path,path,sizeof path);
    w->n_path=n;w->path_i=i;w->blocked_ticks=blocked;w->path_goal_x=gx;w->path_goal_z=gz;
    w->events[total%CP_STAGE_MAX_EVENTS]=event;w->ev_total=total;
    return rc==0;
}
int cp_stage_nav_warm(const CpStageWorld *w){
    if(!w||!nav_ready(w))return 0;
    for(int idx=0;idx<nav.dim*nav.dim;idx++){
        nav_cell(w,idx);
        nav_ground(w,idx%nav.dim,idx/nav.dim);
    }
    return nav.dim;
}
int cp_stage_path(const CpStageWorld *w,float *xz,int cap){
    if(!w||!xz||cap<0)return 0;
    int n=0;
    for(int i=w->path_i;i<w->n_path&&n<cap;i++,n++){
        xz[2*n]=w->path[i][0];
        xz[2*n+1]=w->path[i][1];
    }
    return n;
}
static void path_clear(CpStageWorld *w){
    w->n_path=w->path_i=w->blocked_ticks=w->replans=0;
    w->path_goal_x=w->path_goal_z=0;
    memset(w->path,0,sizeof w->path);
}
static int profile_valid(const CpCombatProfile *p){
    for(int k=0;k<8;k++)if(p->extra[k]>5)return 0;
    if(p->carnivore>1)return 0;
    return p->grip_traits<=63&&p->mouth<=5&&p->charge<=5&&p->spit<=5&&p->tail<=5&&p->guard<=5&&p->fire<=5&&isfinite(p->hp)&&p->hp>=1&&p->hp<=100000&&isfinite(p->stamina)&&p->stamina>=1&&p->stamina<=100000&&isfinite(p->speed)&&p->speed>=.5f&&p->speed<=12&&(p->radius_cm==0||(p->radius_cm>=CB_RADIUS_CM_MIN&&p->radius_cm<=CB_RADIUS_CM_MAX));
}
void cp_stage_setup_default(CpStageSetup *s,uint32_t seed){
    memset(s,0,sizeof *s);
    s->seed=seed;
    s->terrain_seed=7;
    s->flat_height=2;
    s->n=1;
    cp_combat_profile_default(&s->player);
    s->wild[0]=(CpStageSpawn){.x=0,.z=18,.home_x=0,.home_z=18,.species=3,.bot=-1,.profile=CP_STAGE_SPECIES[3].profile};
}
static void creature(CpStageCreature *c,float x,float z,int species,const CpCombatProfile *p){
    memset(c,0,sizeof *c);
    c->x=c->home_x=c->goal_x=x;
    c->z=c->home_z=c->goal_z=z;
    c->fz=1;
    c->profile=*p;
    c->hp=p->hp;
    c->stamina=p->stamina;
    c->species=species;
}
int cp_stage_reset(CpStageWorld *w,const CpStageSetup *s){
    if(!w||!s||s->n<0||s->n>CP_STAGE_MAX_WILD||s->n_obstacles<0||s->n_obstacles>CP_STAGE_MAX_OBSTACLES||s->terrain<0||s->terrain>CP_STAGE_FIELD||!profile_valid(&s->player))return -1;
    if(s->terrain==CP_STAGE_FIELD&&!(w->field&&field_ok(w->field)))return -1; /* FIELD needs cp_stage_attach_field() first */
    const float bound=bound_of(s->terrain,w->field);
    const float values[]={
        s->nest_x,s->nest_z,s->flat_height,s->water_x,s->water_z,s->water_radius
    };
    for(unsigned i=0;i<sizeof values/sizeof *values;i++)if(!isfinite(values[i])||ab(values[i])>10000)return -1;
    if(s->water_radius<0||ab(s->nest_x)>bound||ab(s->nest_z)>bound)return -1;
    for(int i=0;i<s->n;i++){
        const CpStageSpawn *c=&s->wild[i];
        if(c->species<0||c->species>=CP_STAGE_SPECIES_DEFINED||c->bot< -1||c->bot>=BOT_KIND_COUNT||!profile_valid(&c->profile)||!isfinite(c->x)||!isfinite(c->z)||!isfinite(c->home_x)||!isfinite(c->home_z)||ab(c->x)>bound||ab(c->z)>bound||ab(c->home_x)>bound||ab(c->home_z)>bound)return -1;
    }
    for(int i=0;i<s->n_obstacles;i++){
        const CpStageObstacle *o=&s->obstacles[i];
        if(!isfinite(o->x)||!isfinite(o->z)||!isfinite(o->r)||o->r<0||o->r>1000)return -1;
    }
    /* Copy first so resetting from &world.setup is supported. */
    CpStageSetup copy=*s;
    /* The attached field survives reset only in FIELD mode (the caller attaches it first); other modes
     * never read it, and dropping it keeps a world from a previous FIELD run from leaking its pointer. */
    const CpStageField *field=copy.terrain==CP_STAGE_FIELD?w->field:NULL;
    memset(w,0,sizeof *w);
    w->field=field;
    w->motion=CP_STAGE_MOTION;
    w->field_hash=field?field->hash:0;
    w->setup=copy;
    cp_stage_social_reset(w);
    w->active=-1;
    cp_rng_seed(&w->spawn_rng,copy.seed^0x53504157u);
    cp_rng_seed(&w->roam_rng,copy.seed^0x524f414du);
    seed_noise(w);
    creature(&w->player,copy.nest_x,copy.nest_z,-1,&copy.player);
    w->player.legs=copy.player_legs;
    w->run_stamina=1000;
    cp_stage_parts_reset(w);
    cp_stage_secrets_reset(w);
    cp_stage_dig_reset(w);
    cp_combat_loadout_starter(&w->loadout,&copy.player);
    for(int i=0;i<copy.n;i++){
        const CpStageSpawn *c=&copy.wild[i];
        creature(&w->wild[i],c->x,c->z,c->species,&c->profile);
        w->wild[i].home_x=c->home_x;
        w->wild[i].home_z=c->home_z;
        w->wild[i].fz=-1;
        w->wild[i].legs=c->legs;
        w->wild[i].roam_ticks=10+(int)(cp_rng_u32(&w->spawn_rng)%40);
    }
    cp_stage_recipes_reset(w);
    w->hash=cp_stage_hash(w);
    return 0;
}
static void bot_store(CpStageBot *s,const CpBot *b){
    s->rng=b->rng;
    s->kind=b->kind;
    s->spam_move=b->spam_move;
    s->delay=b->delay;
    s->reaction=b->reaction;
    s->ranged_commit=b->ranged_commit;
    s->timer=b->timer;
}
static CpBot bot_load(const CpStageBot *s){
    CpBot b={
        0
    };
    b.rng=s->rng;
    b.filler=CB_MOVE_NONE;
    b.kind=s->kind;
    b.spam_move=s->spam_move;
    b.delay=s->delay;
    b.reaction=s->reaction;
    b.ranged_commit=s->ranged_commit;
    b.timer=s->timer;
    return b;
}
static void start(CpStageWorld *w,int index){
    CpStageCreature *e=&w->wild[index],*p=&w->player;
    if(w->falling||e->slip_air)return; /* an encounter must not freeze a fall */
    cp_stage_social_on_fight(w,index);
    w->arena_x=(p->x+e->x)/2;
    w->arena_z=(p->z+e->z)/2;
    CpCombatSetup s={
        0
    };
    s.seed=w->setup.seed;
    s.n=2;
    s.flat=1;
    CpStageCreature *c[2]={
        p,e
    };
    for(int i=0;i<2;i++){
        if(i==0){
            s.c[0].has_loadout=1;
            s.c[0].loadout=w->loadout;
            s.c[0].loadout.known=cp_stage_known_moves(w);
        }
        s.c[i].prof=c[i]->profile;
        s.c[i].calcium=i?w->recipes.wild_calcium[index]:w->recipes.calcium;
        s.c[i].mineral=i?0:w->recipes.mineral;
        if(i && c[i]->species==2){
            s.c[i].prof.extra[7]=2;s.c[i].prof.carnivore=1;s.c[i].prof.mouth=2;
            s.c[i].has_loadout=1;cp_combat_loadout_default(&s.c[i].loadout,&s.c[i].prof);
            s.c[i].loadout.known|=1u<<CB_SPINE_VOLLEY;s.c[i].loadout.sig_slot=3;s.c[i].loadout.slot[3]=CB_SPINE_VOLLEY;
        }
        s.c[i].prof.hp=c[i]->hp;
        s.c[i].prof.stamina=c[i]->stamina;
        s.c[i].x=c[i]->x-w->arena_x+20;
        s.c[i].y=c[i]->z-w->arena_z+20;
        s.c[i].fx=c[1-i]->x-c[i]->x;
        s.c[i].fy=c[1-i]->z-c[i]->z;
        s.c[i].team=(uint8_t)i;
    }
    cp_combat_reset(&w->combat,&s);
    cp_combat_ctx_enable(&w->combat,0,p->speed);   /* A72/A74: the player's pressed attacks pick a variant by distance and speed */
    w->combat.c[0].vx=p->fx*p->speed;w->combat.c[0].vy=p->fz*p->speed;
    memcpy(w->combat.c[0].cd,w->recipes.cd,sizeof w->recipes.cd);
    w->combat.c[0].calcium=w->recipes.calcium;w->combat.c[0].mineral=w->recipes.mineral;
    w->combat.c[1].calcium=w->recipes.wild_calcium[index];
    if(w->ancestry.count&&w->parts.tiers_on)cp_stage_genome_tiers(w->ancestry.forms[w->ancestry.count-1].form.body,w->combat.c[0].tiers);
    int generation=cp_stage_cousin_generation(w,index+1);
    if(generation>0&&w->parts.tiers_on)cp_stage_genome_tiers(w->ancestry.forms[generation-1].form.body,w->combat.c[1].tiers);
    path_clear(w);
    CpBot b;
    int kind=w->setup.wild[index].bot;
    if(kind<0)kind=CP_STAGE_SPECIES[e->species].temperament==CP_STAGE_TERRITORIAL?BOT_GREEDY:BOT_COUNTER;
    bot_init(&b,kind,w->setup.seed+1);
    bot_store(&w->bot,&b);
    if(w->ledger.enabled&&w->order.verb==CP_STAGE_ATTACK)cp_stage_lineage_award(w,CP_DEED_FIGHTS,1,index+1);
    w->active=index;
    w->started++;
    w->outcome=0;
}
/* Ground gradient (rise/run) over a 0.5 m stencil, the one the ceiling is measured with. */
static void ground_grad(const CpStageWorld *w,float x,float z,float *gx,float *gz,float h){
    if(w->setup.terrain==CP_STAGE_FIELD&&field_ok(w->field)&&!w->secrets.cave_on){
        /* The finite world positions and field are already validated: avoid four repeated dispatches. */
        *gx=(field_ground(w->field,x+h,z)-field_ground(w->field,x-h,z))/(2*h);
        *gz=(field_ground(w->field,x,z+h)-field_ground(w->field,x,z-h))/(2*h);
    }
    else{
        *gx=(cp_stage_ground(w,x+h,z)-cp_stage_ground(w,x-h,z))/(2*h);
        *gz=(cp_stage_ground(w,x,z+h)-cp_stage_ground(w,x,z-h))/(2*h);
    }
}
/* Each body obeys its own grip ceiling; an already steep spawn may escape downhill. */
static int steep_up(const CpStageWorld *w,const CpStageCreature *c,float x,float z,float nx,float nz){
    float gx,gz;
    ground_grad(w,nx,nz,&gx,&gz,.25f);
    if(length(gx,gz)<=cp_stage_grip_grade(&c->profile,c->legs))return 0;
    ground_grad(w,x,z,&gx,&gz,.25f);   /* already on such ground (spawned, slid onto it): only downhill is allowed, the slide takes it from there */
    return length(gx,gz)<=cp_stage_grip_grade(&c->profile,c->legs)||cp_stage_ground(w,nx,nz)>=cp_stage_ground(w,x,z);
}
/* Speed by body size (A39 / D-26): a body walks at a fixed Froude number, v = sqrt(Fr g h), with h its hip height.
 * The C profile carries no leg length, so h = CP_STAGE_HIP_PER_RADIUS * body radius; the factor is the h / r of the
 * seven zoo bodies, measured on their rigs (hip 0.306 m at r 0.6 ... 2.250 at r 3.99; hero 1.69 at r 3.0), starting value.
 * Walk Fr 0.24 puts the hero (h 1.68 m) at 2.0 m/s, the owner's cruise speed. Run Fr is motion.sprint_k (2.2 since A54, starting value
 * checked by the owner's play: 1.5 felt slow; a gallop with a long flight phase; Alexander & Jayes 1983 put the walk-run change near Fr 0.5).
 * Mass still slows acceleration and turning through steer.c (A29). Plain float maths (sqrtf is exactly rounded), so it is
 * reproducible like the rest of the stage. */
#define CP_STAGE_HIP_PER_RADIUS .56f
#define CP_STAGE_FR_WALK .24f   /* default of motion.walk_fr */
#define CP_STAGE_WILD_RUN_FR 1.5f /* wild chase / flee Froude number, fixed (A54): the player's run Fr (motion.sprint_k) went 1.5 -> 2.2, but prey and hunters keep
                                   * their speeds, or a timid creature would flee faster than the player can walk up to it (the befriend task could not finish) */
static float gait_speed(const CpCombatProfile *p,float fr){
    return sqrtf(fr*9.81f*CP_STAGE_HIP_PER_RADIUS*cp_combat_body_radius(p));
}
const CpStageMotion CP_STAGE_MOTION={
    1.f,2.2f,.6f,7.f,7.f,.45f,.9f,.6f,4.5f,11.8f,.3f,1.2f,7.f,.4f,
    1.4f,.35f,.03f,.25f,3.2f,1.5f,.8f,.55f,1.35f,1.4f,1.1f,8.f,.15f,
    CP_STAGE_FR_WALK
};
/* Run intent is latched until release or exhaustion. A held/repeated request cannot bypass the threshold. */
void cp_stage_set_run(CpStageWorld *w,int on){
    if(!w)return;
    if(!on)w->running=0;
    else if(!w->running&&w->run_stamina>=150&&!w->respawn_ticks&&!w->parts.lost&&w->active<0&&!w->falling)w->running=1;
    w->hash=cp_stage_hash(w);
}
static int32_t ground_mm(const CpStageWorld *w,float x,float z);
float cp_stage_jump_height(const CpStageWorld *w){
    float apex=.8f*CP_STAGE_HIP_PER_RADIUS*cp_combat_body_radius(&w->player.profile);
    if(apex>1.2f)apex=1.2f;
    if(apex<.2f)apex=.2f;
    const float cap=.5f*cp_stage_safe_drop(w);
    if(apex>cap)apex=cap;
    return apex;
}
int cp_stage_jump(CpStageWorld *w){
    if(!w)return -1;
    CpStageCreature *c=&w->player;
    const int v=w->order.verb;
    if(w->falling||w->active>=0||w->respawn_ticks||w->parts.lost||w->outcome||w->jump_cd>0||c->sliding)return CP_STAGE_ERR_BUSY;
    if(v!=CP_STAGE_CONTINUE&&v!=CP_STAGE_WAIT&&v!=CP_STAGE_GO&&v!=CP_STAGE_HEADING&&v!=CP_STAGE_GO_NEST&&v!=CP_STAGE_FLEE)return CP_STAGE_ERR_BUSY;
    if(cp_stage_water_depth(w,c->x,c->z)>.3f)return CP_STAGE_ERR_BUSY;
    const float need=c->profile.stamina*.1f,cost=c->profile.stamina*CP_JUMP_STAMINA_PCT*.01f;
    if(c->stamina<need||c->stamina<cost)return CP_STAGE_ERR_NO_STAMINA;
    c->stamina-=cost;
    const float apex=cp_stage_jump_height(w);
    w->falling=1;w->jumping=1;
    w->fall_y_mm=w->fall_start_mm=ground_mm(w,c->x,c->z);
    w->fall_v_mm_s=(int32_t)lroundf(sqrtf(2*9.81f*apex)*1000);
    w->fall_dx_mm=(int32_t)lroundf(c->fx*c->speed*100);
    w->fall_dz_mm=(int32_t)lroundf(c->fz*c->speed*100);
    w->hash=cp_stage_hash(w);
    return 0;
}
static int32_t ground_mm(const CpStageWorld *w,float x,float z){return (int32_t)lroundf(cp_stage_ground(w,x,z)*1000);}
/* Slope-free collision sweep for direct movement and airborne drift. Water, bounds and obstacles still block. */
static int fall_clear(const CpStageWorld *w,float x,float z,float nx,float nz,float r){
    if(ab(nx)>cp_stage_bound(w)||ab(nz)>cp_stage_bound(w))return 0;
    float dx=nx-x,dz=nz-z,d2=dx*dx+dz*dz;
    int steps=(int)(sqrtf(d2)/.25f)+1;
    for(int k=1;k<=steps;k++){
        float t=(float)k/steps,px=x+dx*t,pz=z+dz*t;
        if(w->setup.terrain==CP_STAGE_FIELD?cp_stage_water_depth(w,px,pz)>.7f:cp_stage_ground(w,px,pz)<-.7f)return 0;
    }
    for(int i=0;i<w->setup.n_obstacles;i++){
        const CpStageObstacle *o=&w->setup.obstacles[i];
        float t=d2>0?clamp(((o->x-x)*dx+(o->z-z)*dz)/d2,0,1):0;
        if(length(x+dx*t-o->x,z+dz*t-o->z)<o->r+r)return 0;
    }
    return 1;
}
static void fall_tick(CpStageWorld *w){
    CpStageCreature *c=&w->player;
    float gx,gz;ground_grad(w,c->x,c->z,&gx,&gz,.25f);
    CpSteerBody b;cp_steer_creature(&w->motion,c,&b);
    float limit=w->order.verb==CP_STAGE_HEADING?b.climb:b.slide,g=length(gx,gz);   /* steered by hand: the climb limit (raised by adaptations, steer.c); otherwise the planner's grip */
    c->sliding=g>limit+.0001f;
    if(c->sliding){
        float v=clamp(.4f+w->motion.slide_k*(g-limit),.4f,5);
        w->fall_dx_mm=(int32_t)lroundf(-gx/g*v*100);
        w->fall_dz_mm=(int32_t)lroundf(-gz/g*v*100);
    }
    float ox=c->x,oz=c->z;
    float nx=c->x+w->fall_dx_mm*.001f,nz=c->z+w->fall_dz_mm*.001f;
    if(fall_clear(w,c->x,c->z,nx,nz,b.r)){c->x=nx;c->z=nz;}
    else w->fall_dx_mm=w->fall_dz_mm=0;
    c->speed=length(c->x-ox,c->z-oz)*10;
    /* Trapezoidal (exact for constant g) at 10 Hz; integer mm and mm/s, g = 9.81 m/s². */
    int32_t prev_y=w->fall_y_mm,prev_v=w->fall_v_mm_s;
    w->fall_v_mm_s-=981;
    w->fall_y_mm+=(prev_v+w->fall_v_mm_s)/20; /* trapezoid: exact for constant g */
    int32_t floor=ground_mm(w,c->x,c->z);
    ground_grad(w,c->x,c->z,&gx,&gz,.25f);
    if(w->fall_y_mm<=floor){
        w->fall_y_mm=floor;
        if(floor>w->fall_start_mm)w->fall_start_mm=floor;
        /* fall_start_mm is the height of the last ground contact (the takeoff, or the last steep slope touched while sliding), so
         * start - floor is the vertical air of this fall since it last touched the ground. */
        if(length(gx,gz)>limit+.0001f){
            w->fall_start_mm=floor;
            /* Contact friction bounds slide energy to the measured vertical descent. */
            int32_t contact_v=(prev_y-floor)*10;if(contact_v<0)contact_v=0;
            if(contact_v>5000)contact_v=5000;
            if(w->fall_v_mm_s < -contact_v)w->fall_v_mm_s=-contact_v;
        }   /* touched a slope it cannot hold: a slide, the air count restarts here */
        else{
            int drop=w->fall_start_mm-floor;if(drop<0)drop=0;
            const int32_t air=drop;
            /* D8: damage comes from the vertical impact speed as an equivalent drop v^2/2g (integer mm), so a glide or
             * flare that slows the descent lowers it; a plain free fall gives the geometric drop back. */
            int64_t pv=prev_v<0?-(int64_t)prev_v:0,fy=prev_y>floor?prev_y-floor:0;
            int eq=(int)((pv*pv+2*9810*fy)/(2*9810)); /* speed at the instant of contact, not after the overshoot */
            if(w->fall_v_mm_s>=0)eq=0;
            /* A31: 10 HP per metre beyond the safe drop (0.01 HP per mm), at most CP_FALL_CAP_PERMILLE of max HP unless it was a
             * real free fall: the air between the last ground contact and this landing exceeds CP_FALL_FREE_X times the safe drop.
             * A long slide down a steep slope keeps touching ground, so it is never a free fall. */
            const int32_t safe_mm=(int32_t)lroundf(cp_stage_safe_drop(w)*1000);
            float damage=(float)(eq-safe_mm)*.01f;
            if(damage<0)damage=0;
            if(air<=CP_FALL_FREE_X*safe_mm){float cap=c->profile.hp*(CP_FALL_CAP_PERMILLE*.001f);if(damage>cap)damage=cap;}
            if(w->debug_flags&CP_STAGE_FLAG_GOD)damage=0;
            ev_push(w,CP_STAGE_EV_FELL,0,0,(drop+5)/10,damage,c->x,c->z);
            c->hp=clamp(c->hp-damage,0,c->profile.hp);
            w->falling=0;w->fall_y_mm=w->fall_v_mm_s=w->fall_start_mm=0;
            const float carry=(w->jumping&&damage<=0&&!c->sliding)?length((float)w->fall_dx_mm,(float)w->fall_dz_mm)*.01f:0;
            w->fall_dx_mm=w->fall_dz_mm=0;c->sliding=0;c->speed=carry;   /* a jump keeps its run-up speed so a running jump does not stutter on landing */
            if(w->jumping)w->jump_cd=CP_JUMP_COOLDOWN_TICKS;
            w->jumping=0;
            if(c->hp<=0){
                w->running=0;w->outcome=CP_STAGE_DEATH;w->order=(CpStageInput){0};path_clear(w);
                cp_stage_parts_death(w);
                ev_push(w,CP_STAGE_EV_DEATH,0,0,-1,0,c->x,c->z);
            }
        }
    }
}
/* Wildlife uses the same integer gravity, contact friction and A31 impact law.
 * Without a retained genome its safe drop is the existing 3 * radius fallback. */
static void wild_fall_tick(CpStageWorld *w,CpStageCreature *c,const CpSteerBody *b){
    float gx,gz;ground_grad(w,c->x,c->z,&gx,&gz,.25f);float g=length(gx,gz);
    c->sliding=g>b->slide+.0001f;
    if(c->sliding){float v=cp_steer_slide(&w->motion,b,g);c->slip_dx=(int32_t)lroundf(-gx/g*v*100);c->slip_dz=(int32_t)lroundf(-gz/g*v*100);}
    float ox=c->x,oz=c->z,nx=ox+c->slip_dx*.001f,nz=oz+c->slip_dz*.001f;
    if(fall_clear(w,ox,oz,nx,nz,b->r)){c->x=nx;c->z=nz;}else c->slip_dx=c->slip_dz=0;
    c->speed=length(c->x-ox,c->z-oz)*10;
    int32_t py=c->slip_y,pv=c->slip_v;c->slip_v-=981;c->slip_y+=(pv+c->slip_v)/20;
    int32_t floor=ground_mm(w,c->x,c->z);ground_grad(w,c->x,c->z,&gx,&gz,.25f);
    if(c->slip_y>floor)return;
    c->slip_y=floor;
    if(length(gx,gz)>b->slide+.0001f){
        c->slip_start=floor;int32_t cv=py>floor?(py-floor)*10:0;if(cv>5000)cv=5000;if(c->slip_v < -cv)c->slip_v=-cv;return;
    }
    int drop=c->slip_start>floor?c->slip_start-floor:0;
    int64_t v=pv<0?-(int64_t)pv:0,dy=py>floor?py-floor:0;
    int eq=(int)((v*v+19620*dy)/19620),safe=(int)lroundf(3000*b->r);
    float damage=eq>safe?(eq-safe)*.01f:0;
    if(drop<=CP_FALL_FREE_X*safe&&damage>c->profile.hp*.6f)damage=c->profile.hp*.6f;
    int id=(int)(c-w->wild)+1;ev_push(w,CP_STAGE_EV_FELL,id,0,(drop+5)/10,damage,c->x,c->z);
    c->hp=clamp(c->hp-damage,0,c->profile.hp);
    c->slip_air=c->slip_y=c->slip_v=c->slip_start=c->slip_dx=c->slip_dz=c->sliding=0;c->speed=0;
    if(c->hp<=0){c->dead=1;ev_push(w,CP_STAGE_EV_DEATH,id,0,-1,0,c->x,c->z);}
}
/* Stage locomotion (CP_STAGE_VERSION 3). The decisions (yaw acceleration, turn radius from grip and size, braking into
 * corners, pivot, slope speed and slide) live in core/src/steer.c; this moves the body with them. The heading turns with
 * an angular velocity, so a new target never snaps it (docs/godot/LOCOMOTION.md, "Steering"). */
static void walk(CpStageWorld *w,CpStageCreature *c,float dx,float dz,float speed,float jog){
    const CpStageMotion *m=&w->motion;
    const float ox=c->x,oz=c->z,old=c->speed,r=cp_combat_body_radius(&c->profile);
    CpSteerBody body;
    cp_steer_creature(m,c,&body);
    if(c!=&w->player){
        float gx,gz;ground_grad(w,c->x,c->z,&gx,&gz,.25f);
        if(c->slip_air||length(gx,gz)>body.slide+.0001f){
            if(!c->slip_air){c->slip_air=1;c->slip_y=c->slip_start=ground_mm(w,ox,oz);c->slip_v=c->slip_dx=c->slip_dz=0;}
            wild_fall_tick(w,c,&body);return;
        }
    }

    /* A59: motion and planned segments share the profile grip grade. */

    if(c==&w->player){
        float gx,gz;ground_grad(w,c->x,c->z,&gx,&gz,.25f);
        float limit=w->order.verb==CP_STAGE_HEADING?body.climb:body.slide;
        if(length(gx,gz)>limit+.0001f){
            w->falling=1;w->running=0;w->fall_y_mm=w->fall_start_mm=ground_mm(w,ox,oz);
            w->fall_v_mm_s=0;w->fall_dx_mm=w->fall_dz_mm=0;
            fall_tick(w);return;
        }
    }
    const float grade=cp_stage_ground(w,c->x+c->fx,c->z+c->fz)-cp_stage_ground(w,c->x,c->z);
    CpSteer st={c->fx,c->fz,c->speed,c->omega,c->pivot};
    const int direct=c==&w->player&&w->order.verb==CP_STAGE_HEADING;
    const float limit=body.climb;
    const float sf=cp_steer_slope(m,&body,direct&&grade>limit?limit:grade);
    const float v=cp_steer_tick(m,&body,&st,dx,dz,speed,jog,sf);
    c->fx=st.fx;
    c->fz=st.fz;
    c->pivot=st.pivot;
    c->omega=st.omega;
    c->grade=grade;
    const float step=v*.1f,nx=c->x+c->fx*step,nz=c->z+c->fz*step;
    if(direct){
        float gx,gz;ground_grad(w,nx,nz,&gx,&gz,.25f);
        float limit=body.climb;
        float h=cp_stage_ground(w,ox,oz),nh=cp_stage_ground(w,nx,nz);
        if(fall_clear(w,ox,oz,nx,nz,r)&&step>0&&nh<=h&&(length(gx,gz)>limit+.0001f||(h-nh>limit*step+.04f))){
            w->falling=1;w->running=0;w->fall_y_mm=w->fall_start_mm=ground_mm(w,ox,oz);w->fall_v_mm_s=0;
            w->fall_dx_mm=(int32_t)lroundf(c->fx*step*1000);w->fall_dz_mm=(int32_t)lroundf(c->fz*step*1000);
            c->x=nx;c->z=nz;c->sliding=length(gx,gz)>limit+.0001f;c->speed=step*10;return;
        }
    }
    if(steep_up(w,c,c->x,c->z,nx,nz)){
        /* the cell ahead is above the ceiling and higher than here: refuse it (the same predicate the slide below uses) */
    }
    else if(cp_stage_can_walk(w,c->x,c->z,nx,nz,r)){
        c->x=nx;
        c->z=nz;
    }
    else {
        if(!steep_up(w,c,c->x,c->z,nx,c->z)&&cp_stage_can_walk(w,c->x,c->z,nx,c->z,r))c->x=nx;
        if(!steep_up(w,c,c->x,c->z,c->x,nz)&&cp_stage_can_walk(w,c->x,c->z,c->x,nz,r))c->z=nz;
    }
    /* A54: .01 not .02: a softer start (and the slow creep down to a shore, wanted speed x .4) must still count as pushing against a wall */
    if(c==&w->player&&step>.01f&&length(c->x-ox,c->z-oz)<step*.5f&&!w->blocked_reason){
        w->blocked_reason=block_reason(w,ox,oz,nx,nz,r);
        w->blocked_x=nx;
        w->blocked_z=nz;
    }
    else if(c==&w->player&&speed>.5f&&sf<=0&&!w->blocked_reason){
        /* too steep to climb: report it like a wall so the order replans, and gives up after four tries */
        w->blocked_reason=CP_STAGE_BLOCK_CLIFF;
        w->blocked_x=nx;
        w->blocked_z=nz;
    }
    c->speed=length(c->x-ox,c->z-oz)*10;
    c->acceleration=(c->speed-old)*10;
    c->turn_rate=c->omega;
    /* ground steeper than the body can hold: it slides down the fall line (deterministic; the walk above has already stopped) */
    float gx,gz;
    ground_grad(w,c->x,c->z,&gx,&gz,.5f);
    const float g=length(gx,gz),vs=cp_steer_slide(m,&body,g);
    c->sliding=0;
    if(vs>0&&g>.00001f){
        const float sx=c->x-gx/g*vs*.1f,sz=c->z-gz/g*vs*.1f;
        if(cp_stage_can_walk(w,c->x,c->z,sx,sz,r)){
            c->x=sx;
            c->z=sz;
            c->sliding=1;
        }
    }
}
/* the one death predicate: the flag set at fight resolution, or no hp left */
static int creature_is_dead(const CpStageCreature *e){
    return e->dead||e->hp<=0;
}
static int has_threat(const CpStageWorld *w){
    for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&!cp_stage_creature_hidden(w,i)&&dist(&w->player,&w->wild[i])<30)return 1;
    return 0;
}
static int order_apply(CpStageWorld *w,const CpStageInput *a){
    if(!w||!a||!isfinite(a->x)||!isfinite(a->z)||a->verb<0||a->verb>CP_STAGE_QUEST||a->sprint<0||a->sprint>1)return -1;
    if(w->parts.lost)return CP_STAGE_ERR_BUSY;
    if(a->verb==CP_STAGE_CONTINUE)return 0;
    if(w->falling&&a->verb!=CP_STAGE_HEADING&&a->verb!=CP_STAGE_WAIT)return CP_STAGE_ERR_BUSY;
    if(a->verb==CP_STAGE_EAT&&a->target>=3000)return cp_stage_stone_eat(w,a->target);
    if(a->verb==CP_STAGE_QUEST)return cp_stage_quest_award(w,a->target,a->move);
    if(a->verb==CP_STAGE_DIG){w->parts.inspect_id=w->parts.inspect_ticks=0;return cp_stage_dig_order(w,a);}
    if(a->verb>=CP_STAGE_INSPECT){int src=0;if(cp_stage_secrets_order(w,a,&src))return src;return cp_stage_parts_order(w,a);}
    w->parts.inspect_id=w->parts.inspect_ticks=0;
    if(a->verb==CP_STAGE_LOADOUT){
        if(a->target<1||a->target>CB_LOADOUT_SLOTS)return CP_STAGE_ERR_BAD_SLOT;
        if(a->move!=CB_MOVE_NONE&&(a->move<0||a->move>=CB_MOVE_COUNT||(CP_COMBAT_MOVES[a->move].flags&CB_F_SELF)))return CP_STAGE_ERR_UNKNOWN_MOVE;
        if(w->active>=0)return CP_STAGE_ERR_IN_FIGHT;
        if(length(w->player.x-w->setup.nest_x,w->player.z-w->setup.nest_z)>CP_STAGE_NEST_RADIUS)return CP_STAGE_ERR_NOT_AT_NEST;
        CpCombatLoadout next=w->loadout;
        next.known=cp_stage_known_moves(w);
        if(next.known&(1u<<CB_SPINE_VOLLEY)){
            if(next.sig_slot<0&&next.slot[3]>=0&&CP_COMBAT_MOVES[next.slot[3]].role!=CB_ROLE_SIGNATURE)next.slot[3]=CB_MOVE_NONE;
            next.sig_slot=3;
        }
        const int rc=cp_combat_loadout_set(&next,a->target-1,a->move);
        if(rc)return rc;
        w->loadout=next;
        w->hash=cp_stage_hash(w);
        return 0;
    }
    if(a->verb>=CP_STAGE_BEFRIEND){
        const int rc=cp_stage_social_order_check(w,a);
        if(rc)return rc;
        path_clear(w);
        w->order=*a;
        w->social.used=1;
        return 0;
    }
    if(a->verb==CP_STAGE_GO&&(!isfinite(a->x)||!isfinite(a->z)||ab(a->x)>cp_stage_bound(w)||ab(a->z)>cp_stage_bound(w)))return -1;
    if((a->verb==CP_STAGE_APPROACH||a->verb==CP_STAGE_ATTACK)&&(a->target<1||a->target>w->setup.n||creature_is_dead(&w->wild[a->target-1])||cp_stage_creature_hidden(w,a->target-1)))return -2;
    if(a->verb==CP_STAGE_ATTACK&&(a->move<0||a->move>=CB_MOVE_COUNT||(CP_COMBAT_MOVES[a->move].flags&CB_F_SELF)||!cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[a->move].part)))return -3;
    if(a->verb==CP_STAGE_ATTACK&&CP_COMBAT_MOVES[a->move].meter_cost){
        if(!cp_stage_recipe_ready(w))return CP_STAGE_ERR_NOT_KNOWN;
        if(w->recipes.calcium<CP_COMBAT_MOVES[a->move].meter_cost)return CB_ERR_NO_METER;
    }
    if(a->verb==CP_STAGE_ATTACK&&cp_combat_loadout_slot_of(&w->loadout,a->move)<0)return CP_STAGE_ERR_NOT_EQUIPPED;
    if(a->verb==CP_STAGE_ATTACK&&(w->recipes.cd[a->move]||(w->active>=0&&w->combat.c[0].cd[a->move])))return CP_STAGE_ERR_ON_COOLDOWN;
    if(a->verb==CP_STAGE_DODGE&&(a->dir<0||a->dir>7))return -1;
    if(a->verb==CP_STAGE_HEADING&&a->hx==0&&a->hz==0)return -1;
    if(w->active>=0&&a->verb==CP_STAGE_APPROACH&&a->target!=w->active+1)return CP_STAGE_ERR_IN_FIGHT; /* same as befriend/observe/gift */
    if(w->active>=0&&a->verb==CP_STAGE_ATTACK&&a->target!=w->active+1)return -2;
    if(w->setup.terrain==CP_STAGE_FIELD&&w->active<0&&(a->verb==CP_STAGE_GO||a->verb==CP_STAGE_GO_NEST)){
        /* the same GO again while its path runs keeps the path (clients may repeat the order every frame) */
        if(w->n_path>0&&w->order.verb==a->verb&&(a->verb==CP_STAGE_GO_NEST||(w->order.x==a->x&&w->order.z==a->z)))return 0;
        const float tx=a->verb==CP_STAGE_GO?a->x:w->setup.nest_x,tz=a->verb==CP_STAGE_GO?a->z:w->setup.nest_z;
        if(plan_path(w,tx,tz))return -4;
        w->replans=0;
    }
    else path_clear(w);
    w->order=*a;
    return 0;
}
static int reject(CpStageWorld *w,const CpStageInput *a,int rc){
    w->last_error=rc;
    ev_push(w,CP_STAGE_EV_ORDER_REJECTED,0,a?a->target:0,a?a->move:-1,(float)rc,a?a->x:0,a?a->z:0);
    return rc;
}
int cp_stage_order(CpStageWorld *w,const CpStageInput *a){
    const int rc=order_apply(w,a);
    if(!w||!a||a->verb==CP_STAGE_CONTINUE)return rc;
    if(rc<0){
        reject(w,a,rc);
        if(rc==-4){
            w->blocked_reason=CP_STAGE_BLOCK_UNREACHABLE;
            w->blocked_x=a->verb==CP_STAGE_GO?a->x:w->setup.nest_x;
            w->blocked_z=a->verb==CP_STAGE_GO?a->z:w->setup.nest_z;
        }
    }
    else w->last_error=a->verb==CP_STAGE_FLEE&&w->active<0&&!has_threat(w)?-5:0;
    return rc;
}
static void finish(CpStageWorld *w,int outcome){
    CpStageCreature *e=&w->wild[w->active];
    w->outcome=outcome;
    w->active=-1;
    w->cooldown_ticks=80;
    w->order=(CpStageInput){
        0
    };
    w->player.speed=e->speed=0;
    path_clear(w);
    const int id=(int)(e-w->wild)+1;
    /* a double KO (both fighters reach 0 hp in the same combat tick) is a death for the player AND a kill: the wild
     * creature is dead too, it must not walk home as a 0 hp "living" creature that is still attackable */
    const int wild_ko=outcome==CP_STAGE_DEATH&&!w->combat.c[1].alive;
    if(outcome==CP_STAGE_VICTORY||wild_ko){
        e->dead=1;
        if(w->ledger.enabled)cp_ledger_deed(&w->ledger,w->tick,CP_DEED_KILLS,1,(int32_t)(e->x*100),(int32_t)(e->z*100),id);
        ev_push(w,CP_STAGE_EV_KILL,0,id,-1,0,e->x,e->z);
        cp_stage_social_on_kill(w,id-1);
        cp_stage_parts_kill(w,id-1);
    }
    else e->returning=1;
    if(outcome==CP_STAGE_VICTORY)cp_stage_parts_win(w);
    if(outcome!=CP_STAGE_VICTORY){
        if(outcome==CP_STAGE_DEATH){
            cp_stage_parts_death(w);
            ev_push(w,CP_STAGE_EV_DEATH,id,0,-1,0,w->player.x,w->player.z);
        }
        else {if(w->ledger.enabled)cp_stage_lineage_award(w,CP_DEED_FLED,1,id);ev_push(w,CP_STAGE_EV_FLED,0,id,-1,0,w->player.x,w->player.z);}
    }
}
static void fight(CpStageWorld *w){
    CpStageInput *in=&w->order;
    CpCombatAction a={
        0
    };
    a.target=1;
    switch(in->verb){
        case CP_STAGE_ATTACK:a.verb=CB_V_ATTACK;
        a.move=(int8_t)in->move;
        a.hold=in->dir==1?1:0;
        break;
        case CP_STAGE_GUARD:a.verb=CB_V_GUARD;
        break;
        case CP_STAGE_DODGE:a.verb=CB_V_DODGE;
        a.dir=(int8_t)in->dir;
        break;
        case CP_STAGE_FLEE:a.verb=CB_V_FLEE;
        break;
        case CP_STAGE_APPROACH:a.verb=CB_V_APPROACH;
        break;
        case CP_STAGE_GO:case CP_STAGE_GO_NEST:case CP_STAGE_HEADING:{
            float dx=in->hx,dz=in->hz;
            if(in->verb!=CP_STAGE_HEADING){
                float x=in->verb==CP_STAGE_GO?in->x:w->setup.nest_x,z=in->verb==CP_STAGE_GO?in->z:w->setup.nest_z;
                dx=x-w->player.x;
                dz=z-w->player.z;
                if(length(dx,dz)<.16f){
                    w->order=(CpStageInput){
                        0
                    };
                    break;
                }
                float scale=ab(dx)>ab(dz)?ab(dx):ab(dz);
                dx=dx/scale*32767;
                dz=dz/scale*32767;
            }
            a.verb=CB_V_MOVE;
            a.dir=-1;
            a.heading_x=(int16_t)dx;
            a.heading_y=(int16_t)dz;
            if(in->sprint&&dist(&w->player,&w->wild[w->active])<15.2f)a.verb=CB_V_FLEE;
            break;
        }
        default:break;
    }
    const int combat_rc=cp_combat_order(&w->combat,0,&a);
    if(combat_rc)w->last_error=combat_rc;
    w->accepted[0]=combat_rc==0;
    w->combat_orders[0]=a;
    CpBot b=bot_load(&w->bot);
    CpCombatAction enemy={
        0
    };
    if(CP_STAGE_SPECIES[w->wild[w->active].species].temperament==CP_STAGE_TIMID&&w->combat.c[1].hp<w->wild[w->active].profile.hp*.5f){
        enemy.verb=CB_V_FLEE;
        enemy.target=0;
        w->accepted[1]=1;
    }
    else w->accepted[1]=bot_decide(&b,&w->combat,1,0,&enemy);
    bot_store(&w->bot,&b);
    if(w->accepted[1]){
        w->accepted[1]=cp_combat_order(&w->combat,1,&enemy)==0;
        w->combat_orders[1]=enemy;
    }
    /* Debug GOD: the player cannot die. A hit cannot be undone once cp_combat_step kills, so the player gets a
     * 1000 hp buffer for the tick and what the tick took is subtracted afterwards (hp floors at 1). */
    const int god=(w->debug_flags&CP_STAGE_FLAG_GOD)!=0;
    const float real_hp=w->combat.c[0].hp;
    if(god)w->combat.c[0].hp=real_hp+1000;
    const int move_before=w->combat.c[0].move,phase_before=w->combat.c[0].phase;
    cp_combat_step(&w->combat);
    for(int mv=0;mv<CB_MOVE_COUNT;mv++)w->recipes.cd[mv]=w->combat.c[0].cd[mv]?w->combat.c[0].cd[mv]+1:0;
    if(w->recipes.calcium!=w->combat.c[0].calcium){w->recipes.used=1;w->recipes.calcium=w->combat.c[0].calcium;}
    if(w->recipes.wild_calcium[w->active]!=w->combat.c[1].calcium)w->recipes.used=1;
    w->recipes.wild_calcium[w->active]=w->combat.c[1].calcium;
    for(int k=0;k<w->combat.n_ev;k++){
        const CpCombatEvent *ev=&w->combat.ev[k];
        if(ev->type==CB_EV_HIT&&ev->b==1){
            /* Last direct damage identifies a volley whose bleed later kills. */
            int wound=ev->move==CB_SPINE_VOLLEY;
            if(w->recipes.quill_carcass[w->active]!=wound)w->recipes.used=1;
            w->recipes.quill_carcass[w->active]=(uint8_t)wound;
        }
        if(ev->type==CB_EV_HIT&&ev->move==CB_SPINE_VOLLEY){
            if(ev->a==0&&w->recipes.state!=CP_RECIPE_MASTERED){
                w->recipes.state=CP_RECIPE_MASTERED;w->recipes.used=1;
                ev_push(w,CP_STAGE_EV_RECIPE,0,0,CP_RECIPE_MASTERED,CP_RECIPE_KNOWN,w->player.x,w->player.z);
            }
        }
    }
    {
        const CpCombatCreature *pc=&w->combat.c[0];
        if(pc->move!=CB_MOVE_NONE&&!(CP_COMBAT_MOVES[pc->move].flags&CB_F_SELF)&&(move_before!=pc->move||phase_before==CB_PH_IDLE)){
            ev_push(w,CP_STAGE_EV_MOVE_USED,0,0,pc->move,1,w->player.x,w->player.z);
            if(pc->move==CB_FLAME)cp_stage_dig_flame(w);
        }
    }
    for(int i=0;i<w->combat.n_ev;i++){
        const CpCombatEvent *ev=&w->combat.ev[i];
        if(ev->type==CB_EV_HIT&&ev->a==0&&ev->b==1)cp_stage_parts_usage(w,ev->move,0);
        if(ev->type==CB_EV_HIT&&ev->a<2&&ev->b<2)ev_push(w,CP_STAGE_EV_HIT,ev->a?w->active+1:0,ev->b?w->active+1:0,ev->move,ev->amount,0,0);
    }
    if(god){
        CpCombatCreature *p=&w->combat.c[0];
        float taken=(real_hp+1000)-p->hp;
        p->hp=real_hp-taken;
        if(p->hp<1)p->hp=1;
        p->stamina=w->player.profile.stamina;
        p->alive=1;
    }
    CpStageCreature *entities[2]={
        &w->player,&w->wild[w->active]
    };
    for(int i=0;i<2;i++){
        CpStageCreature *e=entities[i];
        CpCombatCreature *c=&w->combat.c[i];
        float old=e->speed;
        if(w->setup.terrain==CP_STAGE_FIELD&&!cp_stage_can_walk(w,e->x,e->z,w->arena_x+c->x-20,w->arena_z+c->y-20,cp_combat_body_radius(&e->profile))){
            /* PLAN-heights H2: the arena is flat but the island is not. A move that would cross a cliff, the sea
             * or the bound is refused: the fighter keeps its place and the combat creature is put back with it. */
            if(i==0){
                w->blocked_reason=block_reason(w,e->x,e->z,w->arena_x+c->x-20,w->arena_z+c->y-20,cp_combat_body_radius(&e->profile));
                w->blocked_x=w->arena_x+c->x-20;
                w->blocked_z=w->arena_z+c->y-20;
            }
            c->x=e->x-w->arena_x+20;
            c->y=e->z-w->arena_z+20;
        }
        else if(w->setup.terrain!=CP_STAGE_FIELD){
            /* the walkable square is a hard limit in a fight too (agentplay saw 195.7 with a bound of 195) */
            const float bound=cp_stage_bound(w),wx=w->arena_x+c->x-20,wz=w->arena_z+c->y-20;
            if(ab(wx)>bound||ab(wz)>bound){
                if(i==0){
                    w->blocked_reason=CP_STAGE_BLOCK_EDGE;
                    w->blocked_x=wx;
                    w->blocked_z=wz;
                }
                c->x=clamp(wx,-bound,bound)-w->arena_x+20;
                c->y=clamp(wz,-bound,bound)-w->arena_z+20;
            }
        }
        e->speed=length(w->arena_x+c->x-20-e->x,w->arena_z+c->y-20-e->z)*10;
        e->acceleration=(e->speed-old)*10;
        e->turn_rate=(e->fz*c->fx-e->fx*c->fy)*10;
        e->x=w->arena_x+c->x-20;
        e->z=w->arena_z+c->y-20;
        e->fx=c->fx;
        e->fz=c->fy;
        e->hp=c->hp;
        e->stamina=c->stamina;
    }
    if(!w->combat.c[0].alive)finish(w,CP_STAGE_DEATH);
    else if(!w->combat.c[1].alive)finish(w,CP_STAGE_VICTORY);
    else{
        const CpCombatCreature *p=&w->combat.c[0];
        float edge=p->x;
        if(p->y<edge)edge=p->y;
        if(40-p->x<edge)edge=40-p->x;
        if(40-p->y<edge)edge=40-p->y;
        if(edge<cp_combat_body_radius(&w->player.profile)+.25f&&dist(entities[0],entities[1])>8)finish(w,CP_STAGE_FLED);
    }
}
/* A72: a pressed bite, pounce, spit or roar on a target within the far band (5 to 20 m) starts the fight at once: the run-in, the lob
 * and the charge are the fight's first moves. Other moves, and wild aggression, keep the 5.5 m of the old walk-in. */
static float engage_range(const CpStageWorld *w){
    const int m=w->order.move;
    return (m==CB_BITE||m==CB_POUNCE||m==CB_SPIT||m==CB_ROAR)?CB_BAND_MAX_GAP:5.5f;
}
static void wild_tick(CpStageWorld *w,int skip,int engage){
    /* Respawn is emitted before AI runs. Keep this clock here so player movement stays independent. */
    for(uint32_t n=0;n<w->ev_total&&n<CP_STAGE_MAX_EVENTS;n++){
        const CpStageEvent *ev=&w->events[(w->ev_total-1-n)%CP_STAGE_MAX_EVENTS];
        if(ev->tick!=w->tick)break;
        if(ev->type==CP_STAGE_EV_RESPAWN)w->grace_until=w->tick+CP_STAGE_GRACE_TICKS;
    }
    for(int i=0;i<w->setup.n;i++){
        CpStageCreature *e=&w->wild[i];
        if(CP_STAGE_SPECIES[e->species].activity==CP_ACT_NOCTURNAL&&!e->dead&&
           (i==w->active||dist(e,&w->player)<=CP_STAGE_WAKE_RADIUS))
            w->wake_until[i]=w->tick+CP_STAGE_WAKE_TICKS;
        if(e->dead||i==skip)continue;
        if(w->debug_flags&CP_STAGE_FLAG_AI_OFF){
            /* Debug AI_OFF: the wild neither walk, roam (no RNG draw) nor attack; the player can still start a fight. */
            int targeted=(w->order.verb==CP_STAGE_ATTACK&&w->order.target==i+1);
            if(engage&&w->active<0&&!e->returning&&!w->cooldown_ticks&&targeted&&dist(&w->player,e)<engage_range(w))start(w,i);
            continue;
        }
        if(cp_stage_creature_hidden(w,i))continue;   /* asleep by day (W8): it neither walks nor engages */
        const CpStageSpecies *s=&CP_STAGE_SPECIES[e->species];
        float d=dist(e,&w->player),tx=e->goal_x,tz=e->goal_z;
        if(--e->roam_ticks<=0){
            /* Exactly three draws for every roam decision, even while reacting. */float rx=cp_rng_f(&w->roam_rng)*2-1,rz=cp_rng_f(&w->roam_rng)*2-1;
            uint32_t duration=cp_rng_u32(&w->roam_rng);
            float n=length(rx,rz);
            if(n>1){
                rx/=n;
                rz/=n;
            }
            e->goal_x=e->home_x+rx*s->roam;
            e->goal_z=e->home_z+rz*s->roam;
            e->roam_ticks=40+(int)(duration%61);
            if(w->setup.terrain==CP_STAGE_FIELD&&!walk_ok(w,e->x,e->z,e->goal_x,e->goal_z,cp_combat_body_radius(&e->profile),cp_stage_grip_grade(&e->profile,e->legs),cp_stage_grip_grade(&e->profile,e->legs))){
                /* only reachable roam goals (a cheap straight check): otherwise stay where it is */
                e->goal_x=e->x;
                e->goal_z=e->z;
            }
            tx=e->goal_x;
            tz=e->goal_z;
        }
        int hostile=cp_stage_social_hostile(w,i);   /* the temperament rule, minus what the social layer pacifies */
        if(e->returning){
            tx=e->home_x;
            tz=e->home_z;
        }
        else if(hostile){
            tx=w->player.x;
            tz=w->player.z;
        }
        else if(cp_stage_social_leaving(w,i)){
            tx=e->x+(e->x-w->player.x);
            tz=e->z+(e->z-w->player.z);
        }
        else if(s->temperament==CP_STAGE_TIMID&&d<s->sight*.5f){
            tx=e->x+(e->x-w->player.x);
            tz=e->z+(e->z-w->player.z);
        }
        /* species >= 6 (star, slug, radial) keep their own authored speeds; the daytime and night bodies follow the Froude law */
        const int by_size=e->species<6;
        const float k=w->motion.wild_k*w->motion.jog_k;
        float jog=by_size?gait_speed(&e->profile,w->motion.walk_fr)*k:e->profile.speed,espeed=jog;
        /* chasing or fleeing is a run; roaming, returning home and hunkering are walks */
        if(by_size&&!e->returning&&(hostile||cp_stage_social_leaving(w,i)||(s->temperament==CP_STAGE_TIMID&&d<s->sight*.5f)))espeed=gait_speed(&e->profile,CP_STAGE_WILD_RUN_FR)*k;
        /* A star probes slowly on tube feet, and rows at full speed when driven off or provoked. */
        if(e->species==6&&!hostile&&!e->returning&&!cp_stage_social_leaving(w,i))espeed=.3f;
        if(length(tx-e->x,tz-e->z)<.4f||(cp_stage_creature_hunkered(w,i)&&!hostile))espeed=0;   /* hunkered: curled up in the noon light */
        if(!walk_ok(w,e->x,e->z,tx,tz,cp_combat_body_radius(&e->profile),cp_stage_grip_grade(&e->profile,e->legs),cp_stage_grip_grade(&e->profile,e->legs)))espeed=0;
        walk(w,e,tx-e->x,tz-e->z,espeed,jog);
        if(e->returning&&length(e->x-e->home_x,e->z-e->home_z)<.6f)e->returning=0;
        int targeted=(w->order.verb==CP_STAGE_ATTACK&&w->order.target==i+1);
        if(engage&&w->active<0&&!e->returning&&!w->cooldown_ticks&&((hostile&&!cp_stage_social_shielded(w,i))||targeted)&&dist(&w->player,e)<(targeted?engage_range(w):5.5f))start(w,i);
    }
}
uint64_t cp_stage_step(CpStageWorld *w,const CpStageInput *input){
    if(w->parts.lost)return w->hash=cp_stage_hash(w);
    int32_t lineage_x=(int32_t)(w->player.x*100),lineage_z=(int32_t)(w->player.z*100);
    int run_moved=0;
    int skip=w->active,engage=w->active<0&&w->respawn_ticks==0&&!w->falling;
    w->accepted[0]=w->accepted[1]=0;
    w->combat.n_ev=0;
    w->blocked_reason=0;
    w->blocked_x=w->blocked_z=0;
    /* last_error is the result of the last command and stays until the next one (a step with no input keeps it) */
    if(input)cp_stage_order(w,input);
    int following=0;
    if(w->active>=0){w->running=0;fight(w);}
    else if(w->respawn_ticks>0){
        if(--w->respawn_ticks==0){
            ev_push(w,CP_STAGE_EV_RESPAWN,0,0,-1,0,w->setup.nest_x,w->setup.nest_z);
            w->player.x=w->setup.nest_x;
            w->player.z=w->setup.nest_z;
            w->player.hp=w->player.profile.hp;
            w->player.stamina=w->player.profile.stamina;
            w->player.speed=0;
        }
    }
    else if(w->falling){fall_tick(w);}
    else{
        CpStageInput *a=&w->order;
        float dx=0,dz=0,remaining=10000;
        if(a->verb==CP_STAGE_HEADING){
            dx=a->hx/32767.f;
            dz=a->hz/32767.f;
        }
        else if(a->verb==CP_STAGE_GO||a->verb==CP_STAGE_GO_NEST){
            const float gx=a->verb==CP_STAGE_GO?a->x:w->setup.nest_x,gz=a->verb==CP_STAGE_GO?a->z:w->setup.nest_z;
            if(w->n_path>0){
                /* follow the planned waypoints: take the next one when this one is reached, or when the next one is
                 * already in a clear line and this one is near (so corners are cut where the ground allows) */
                const float pr=cp_combat_body_radius(&w->player.profile);
                while(w->path_i<w->n_path-1){
                    const float *wp=w->path[w->path_i],*nx=w->path[w->path_i+1];
                    const float d=length(wp[0]-w->player.x,wp[1]-w->player.z);
                    const float look=w->motion.look_min+w->motion.look_k*w->player.speed;
                    const int passed=(w->player.x-wp[0])*(nx[0]-wp[0])+(w->player.z-wp[1])*(nx[1]-wp[1])>0;
                    if(d<1.5f||((d<(look>8?look:8)||passed)&&walk_ok(w,w->player.x,w->player.z,nx[0],nx[1],pr,player_climb(w),cp_stage_grip_grade(&w->player.profile,w->player.legs))))w->path_i++;
                    else break;
                }
                const float *wp=w->path[w->path_i];
                dx=wp[0]-w->player.x;
                dz=wp[1]-w->player.z;
                remaining=length(dx,dz);
                const float wdx=dx,wdz=dz;
                {
                    /* pure pursuit: steer at the point `look` metres ahead on the path, so corners become arcs */
                    float cx,cz;
                    cp_steer_carrot((const float (*)[2])w->path,w->n_path,w->path_i,w->player.x,w->player.z,w->motion.look_min+w->motion.look_k*w->player.speed,&cx,&cz);
                    if(walk_ok(w,w->player.x,w->player.z,cx,cz,cp_combat_body_radius(&w->player.profile),player_climb(w),cp_stage_grip_grade(&w->player.profile,w->player.legs))){
                        dx=cx-w->player.x;
                        dz=cz-w->player.z;
                    }
                }
                for(int k=w->path_i;k<w->n_path-1;k++)remaining+=length(w->path[k+1][0]-w->path[k][0],w->path[k+1][1]-w->path[k][1]);
                following=1;
                if(w->path_i==w->n_path-1&&length(wdx,wdz)<.16f){
                    dx=dz=0;
                    if(length(w->path_goal_x-wp[0],w->path_goal_z-wp[1])>.5f){
                        /* the stored waypoints ran out before the goal (more than 64 corners): plan the rest */
                        following=0;
                        if(plan_path(w,gx,gz)){
                            ev_push(w,CP_STAGE_EV_PATH_FAILED,0,0,-1,CP_STAGE_BLOCK_UNREACHABLE,gx,gz);
                            w->last_error=-4;
                            w->blocked_reason=CP_STAGE_BLOCK_UNREACHABLE;
                            w->blocked_x=gx;w->blocked_z=gz;
                            w->order=(CpStageInput){
                                0
                            };
                            path_clear(w);
                        }
                    }
                    else{
                        ev_push(w,CP_STAGE_EV_ARRIVED,0,0,-1,0,w->player.x,w->player.z);
                        w->order=(CpStageInput){
                            0
                        };
                        path_clear(w);
                        following=0;
                    }
                }
            }
            else{
                dx=gx-w->player.x;
                dz=gz-w->player.z;
                remaining=length(dx,dz);
                if(remaining<.16f){
                    ev_push(w,CP_STAGE_EV_ARRIVED,0,0,-1,0,w->player.x,w->player.z);
                    w->order=(CpStageInput){
                        0
                    };
                    dx=dz=0;
                }
            }
        }
        else if(a->verb==CP_STAGE_ATTACK||a->verb==CP_STAGE_APPROACH){
            CpStageCreature *t=&w->wild[a->target-1];
            if(t->dead)w->order=(CpStageInput){
                0
            };
            else{
                dx=t->x-w->player.x;
                dz=t->z-w->player.z;
                remaining=length(dx,dz);
                if(a->verb==CP_STAGE_APPROACH&&remaining<cp_combat_body_radius(&t->profile)+cp_combat_body_radius(&w->player.profile)+CB_APPROACH_GAP){
                    dx=dz=0;
                    w->order=(CpStageInput){
                        0
                    };
                }
            }
        }
        else if(a->verb>=CP_STAGE_BEFRIEND&&a->verb<=CP_STAGE_EAT){
            /* social verbs: walk into range, then stand still while performing (observe never moves) */
            if(a->target>=1&&a->target<=w->setup.n&&(a->verb==CP_STAGE_EAT||!creature_is_dead(&w->wild[a->target-1]))&&a->verb!=CP_STAGE_OBSERVE){
                const CpStageCreature *t=&w->wild[a->target-1];
                dx=t->x-w->player.x;
                dz=t->z-w->player.z;
                remaining=length(dx,dz);
                if(w->social.act_verb||remaining<=cp_stage_social_reach(w,a)){
                    dx=dz=0;
                    remaining=0;
                }
            }
        }
        else if(a->verb==CP_STAGE_FLEE){
            int nearest=-1;
            float d=100000;
            for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&dist(&w->player,&w->wild[i])<d){
                nearest=i;
                d=dist(&w->player,&w->wild[i]);
            }
            if(nearest>=0&&d<30){
                dx=w->player.x-w->wild[nearest].x;
                dz=w->player.z-w->wild[nearest].z;
            }
        }
        int sprint=(a->sprint||a->verb==CP_STAGE_FLEE)&&length(dx,dz)>0&&w->player.stamina>2;
        const float slow=w->motion.jog_k*(1.f-w->recipes.mineral*.003f);
        float jog=gait_speed(&w->player.profile,w->motion.walk_fr)*slow,speed=(w->running||sprint)?gait_speed(&w->player.profile,w->motion.sprint_k)*slow:jog,stop=sqrtf(clamp(remaining-.08f,0,10000)*12);
        if(stop<speed)speed=stop;
        walk(w,&w->player,dx,dz,speed,jog);
        if(w->running&&length(dx,dz)>0&&w->player.speed>.01f){
            run_moved=1;
            w->run_stamina-=10;
            if(w->run_stamina<=0){w->run_stamina=0;w->running=0;}
        }

        if(following&&w->falling){
            ev_push(w,CP_STAGE_EV_PATH_FAILED,0,0,-1,CP_STAGE_BLOCK_UNREACHABLE,w->order.x,w->order.z);
            w->last_error=-4;w->order=(CpStageInput){0};path_clear(w);following=0;
        }
        if(following){
            if(w->blocked_reason)w->blocked_ticks++;
            else w->blocked_ticks=0;
            if(w->blocked_ticks>=10){
                /* blocked for a second: plan again from where we stand; give up after four tries */
                const float gx=w->order.verb==CP_STAGE_GO?w->order.x:w->setup.nest_x,gz=w->order.verb==CP_STAGE_GO?w->order.z:w->setup.nest_z;
                const int tries=w->replans+1;
                if(tries>4||plan_path(w,gx,gz)){
                    ev_push(w,CP_STAGE_EV_PATH_FAILED,0,0,-1,CP_STAGE_BLOCK_UNREACHABLE,gx,gz);
                    w->blocked_reason=CP_STAGE_BLOCK_UNREACHABLE;
                    w->blocked_x=gx;
                    w->blocked_z=gz;
                    w->last_error=-4;
                    w->order=(CpStageInput){
                        0
                    };
                    path_clear(w);
                }
                else w->replans=tries;
            }
        }
        w->player.stamina=clamp(w->player.stamina+(sprint?-1.4f:1),0,w->player.profile.stamina);
        if(w->cooldown_ticks>0)w->cooldown_ticks--;
    }
    if(w->jump_cd>0)w->jump_cd--;
    if(!run_moved&&w->run_stamina<1000){w->run_stamina+=5;if(w->run_stamina>1000)w->run_stamina=1000;}
    if(w->falling||w->respawn_ticks||w->parts.lost)engage=0;
    cp_stage_social_step(w);
    cp_stage_parts_step(w);
    cp_stage_recipes_step(w);
    cp_stage_dig_step(w);
    cp_stage_secrets_step(w);
    wild_tick(w,skip,engage);
    cp_stage_lineage_tick(w,lineage_x,lineage_z);
    w->tick++;
    w->clock=(w->clock+1)%CP_STAGE_DAY_TICKS;
    return w->hash=cp_stage_hash(w);
}
/* Canonical FNV-1a, explicit LE fields, signed-zero canonicalisation. */
static void u32(uint64_t *h,uint32_t v){
    for(int i=0;i<4;i++){
        *h^=(uint8_t)(v>>(8*i));
        *h*=1099511628211ULL;
    }
}
static void fl(uint64_t *h,float v){
    uint32_t bits=0;
    if(v!=0)memcpy(&bits,&v,4);
    u32(h,bits);
}
static void prof(uint64_t *h,const CpCombatProfile *p){
    u32(h,p->mouth);
    u32(h,p->charge);
    u32(h,p->spit);
    u32(h,p->tail);
    u32(h,p->guard);
    fl(h,p->hp);
    fl(h,p->stamina);
    fl(h,p->speed);
    u32(h,p->radius_cm);
    int extra=p->carnivore;for(int k=0;k<8;k++)extra|=p->extra[k];
    if(extra){u32(h,0x43325052);for(int k=0;k<8;k++)u32(h,p->extra[k]);u32(h,p->carnivore);}
    if(p->fire){u32(h,0x46495245);u32(h,p->fire);}
    if(p->grip_traits||p->grip_legs){u32(h,0x47524950);u32(h,p->grip_traits);u32(h,p->grip_legs);}
}
static void ent(uint64_t *h,const CpStageCreature *c){
    fl(h,c->x);
    fl(h,c->z);
    fl(h,c->fx);
    fl(h,c->fz);
    fl(h,c->hp);
    fl(h,c->stamina);
    fl(h,c->speed);
    fl(h,c->acceleration);
    fl(h,c->turn_rate);
    fl(h,c->home_x);
    fl(h,c->home_z);
    fl(h,c->goal_x);
    fl(h,c->goal_z);
    u32(h,c->species);
    u32(h,c->dead);
    u32(h,c->pivot);
    u32(h,c->returning);
    u32(h,c->roam_ticks);
    prof(h,&c->profile);
    fl(h,c->omega);
    u32(h,c->legs);
    u32(h,c->sliding);
    if(c->slip_air){u32(h,0x534c4950);u32(h,c->slip_air);u32(h,c->slip_y);u32(h,c->slip_v);u32(h,c->slip_start);u32(h,c->slip_dx);u32(h,c->slip_dz);}
}
uint64_t cp_stage_hash(const CpStageWorld *w){
    uint64_t h=14695981039346656037ULL;
    const CpStageSetup *s=&w->setup;
    u32(&h,CP_STAGE_VERSION);
    u32(&h,s->seed);
    u32(&h,s->terrain_seed);
    u32(&h,s->terrain);
    u32(&h,s->n);
    u32(&h,s->n_obstacles);
    fl(&h,s->nest_x);
    fl(&h,s->nest_z);
    fl(&h,s->flat_height);
    fl(&h,s->water_x);
    fl(&h,s->water_z);
    fl(&h,s->water_radius);
    prof(&h,&s->player);
    for(int i=0;i<s->n;i++){
        const CpStageSpawn *c=&s->wild[i];
        fl(&h,c->x);
        fl(&h,c->z);
        fl(&h,c->home_x);
        fl(&h,c->home_z);
        u32(&h,c->species);
        u32(&h,c->bot);
        prof(&h,&c->profile);
    }
    for(int i=0;i<s->n_obstacles;i++){
        fl(&h,s->obstacles[i].x);
        fl(&h,s->obstacles[i].z);
        fl(&h,s->obstacles[i].r);
        u32(&h,s->obstacles[i].type);
    }
    u32(&h,w->tick);
    u32(&h,w->clock);
    for(int i=0;i<4;i++){
        u32(&h,w->spawn_rng.s[i]);
        u32(&h,w->roam_rng.s[i]);
        u32(&h,w->bot.rng.s[i]);
    }
    ent(&h,&w->player);
    for(int i=0;i<s->n;i++)ent(&h,&w->wild[i]);
    u32(&h,w->order.verb);
    u32(&h,w->order.target);
    u32(&h,w->order.move);
    u32(&h,w->order.dir);
    u32(&h,w->order.sprint);
    u32(&h,(uint16_t)w->order.hx);
    u32(&h,(uint16_t)w->order.hz);
    fl(&h,w->order.x);
    fl(&h,w->order.z);
    u32(&h,w->active);
    u32(&h,w->started);
    u32(&h,w->outcome);
    u32(&h,w->respawn_ticks);
    u32(&h,w->cooldown_ticks);
    fl(&h,w->arena_x);
    fl(&h,w->arena_z);
    u32(&h,w->bot.kind);
    u32(&h,w->bot.spam_move);
    u32(&h,w->bot.delay);
    u32(&h,w->bot.reaction);
    u32(&h,w->bot.ranged_commit);
    u32(&h,w->bot.timer);
    if(w->started){
        uint64_t combat=cp_combat_hash(&w->combat);
        u32(&h,(uint32_t)combat);
        u32(&h,(uint32_t)(combat>>32));
    }
    /* DT0 state is folded in only when it differs from the default, so the committed golden logs and
     * every analytic/flat run keep their hashes. */
    if(memcmp(&w->motion,&CP_STAGE_MOTION,sizeof w->motion)){
        const float *m=(const float *)&w->motion;
        for(unsigned i=0;i<offsetof(CpStageMotion,walk_fr)/sizeof *m;i++)fl(&h,m[i]);
        if(w->motion.walk_fr!=CP_STAGE_MOTION.walk_fr)fl(&h,w->motion.walk_fr);   /* newer than the goldens: folded only when tuned */
    }
    if(w->debug_flags)u32(&h,(uint32_t)w->debug_flags);
    if(!cp_combat_loadout_is_default(&w->loadout,&w->player.profile)){
        for(int i=0;i<CB_LOADOUT_SLOTS;i++)u32(&h,(uint32_t)(uint8_t)w->loadout.slot[i]);
        u32(&h,(uint32_t)(uint8_t)w->loadout.sig_slot);
    }
    if(w->n_path>0){
        u32(&h,(uint32_t)w->n_path);
        u32(&h,(uint32_t)w->path_i);
        u32(&h,(uint32_t)w->blocked_ticks);
        u32(&h,(uint32_t)w->replans);
        fl(&h,w->path_goal_x);
        fl(&h,w->path_goal_z);
        for(int i=0;i<w->n_path;i++){
            fl(&h,w->path[i][0]);
            fl(&h,w->path[i][1]);
        }
    }
    if(w->running||w->run_stamina!=1000||w->falling){
        u32(&h,0x52554e46);u32(&h,w->running);u32(&h,w->run_stamina);u32(&h,w->falling);
        u32(&h,w->fall_y_mm);u32(&h,w->fall_v_mm_s);u32(&h,w->fall_start_mm);
        u32(&h,w->fall_dx_mm);u32(&h,w->fall_dz_mm);
    }
    if(w->jumping||w->jump_cd){u32(&h,0x4a554d50);u32(&h,w->jumping);u32(&h,w->jump_cd);}
    if(w->recipes.used){uint64_t rh=cp_stage_recipes_hash(w);u32(&h,(uint32_t)rh);u32(&h,(uint32_t)(rh>>32));}
    if(w->dig.used){uint64_t dh=cp_stage_dig_hash(w);u32(&h,0x44494731);u32(&h,(uint32_t)dh);u32(&h,(uint32_t)(dh>>32));}
    if(w->secrets.on||w->secrets.cave_on){uint64_t sh=cp_stage_secrets_hash(w);u32(&h,(uint32_t)sh);u32(&h,(uint32_t)(sh>>32));}
    if(w->parts.used){uint64_t ph=cp_stage_parts_hash(w);u32(&h,(uint32_t)ph);u32(&h,(uint32_t)(ph>>32));}
    if(w->social.used){
        const uint64_t sh=cp_stage_social_hash(w);
        u32(&h,(uint32_t)sh);
        u32(&h,(uint32_t)(sh>>32));
    }
    if(s->terrain==CP_STAGE_FIELD){
        u32(&h,(uint32_t)w->field_hash);
        u32(&h,(uint32_t)(w->field_hash>>32));
    }
    if(w->ledger.enabled){uint64_t lh=cp_ledger_hash(&w->ledger);u32(&h,(uint32_t)lh);u32(&h,(uint32_t)(lh>>32));uint64_t ah=cp_stage_ancestry_hash(w);u32(&h,(uint32_t)ah);u32(&h,(uint32_t)(ah>>32));}
    if(w->grace_until){u32(&h,0x47524143u);u32(&h,w->grace_until);}
    for(int i=0;i<s->n;i++)if(w->wake_until[i]){u32(&h,0x57414b45u+(uint32_t)i);u32(&h,w->wake_until[i]);}
    return h;
}
uint16_t cp_stage_known_moves(const CpStageWorld *w){
    /* learning by observing (A21 section 4, A22): moves of completed observe chains are OR-ed in */
    return (uint16_t)(cp_combat_known_default(&w->player.profile)|(uint16_t)w->social.learned|(cp_stage_recipe_ready(w)?(1u<<CB_SPINE_VOLLEY):0));
}
static int parse_text(const char *text,CpStageInput *out){
    CpStageInput a={
        0
    };
    char extra,move_name[32];
    if(sscanf(text,"inspect #%d %c",&a.target,&extra)==1){a.verb=CP_STAGE_INSPECT;*out=a;return 0;}
    if(text&&strcmp(text,"dig")==0){a.verb=CP_STAGE_DIG;*out=a;return 0;}
    const char *buy[]={"buy_part ","buy_level ","buy_tier "};
    for(int k=0;k<3;k++)if(!strncmp(text,buy[k],strlen(buy[k]))){
        if(sscanf(text+strlen(buy[k]),"%31s %c",move_name,&extra)!=1)return -1;
        a.target=cp_stage_part_id(move_name);if(a.target<0)return -1;a.verb=CP_STAGE_BUY_PART+k;*out=a;return 0;
    }
    float deg;
    int rc=0;
    if(!text)return -1;
    if(strcmp(text,"wait")==0)a.verb=CP_STAGE_WAIT;
    else if(strcmp(text,"go_nest")==0)a.verb=CP_STAGE_GO_NEST;
    else if(strcmp(text,"flee")==0)a.verb=CP_STAGE_FLEE;
    else if(sscanf(text,"go %f,%f %c",&a.x,&a.z,&extra)==2||sscanf(text,"go %f %f %c",&a.x,&a.z,&extra)==2)a.verb=CP_STAGE_GO;
    else if(sscanf(text,"approach #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_APPROACH;
    else if(sscanf(text,"attack #%d %31s %c",&a.target,move_name,&extra)==2||(sscanf(text,"attack #%d %31s hold %c",&a.target,move_name,&extra)==2&&(a.dir=1))){
        a.verb=CP_STAGE_ATTACK;
        a.move=-1;
        for(int i=0;i<CB_MOVE_COUNT;i++)if(strcasecmp(move_name,cp_combat_move_name(i))==0)a.move=i;
        if(a.move<0){
            char *end;
            long value=strtol(move_name,&end,10);
            if(*move_name&&!*end&&value>=0&&value<CB_MOVE_COUNT)a.move=(int)value;
        }
        if(a.move<0){rc=-6;goto done;}
    }
    else if(sscanf(text,"loadout %d %31s %c",&a.target,move_name,&extra)==2){
        a.verb=CP_STAGE_LOADOUT;
        a.move=-2;
        if(strcasecmp(move_name,"none")==0||strcasecmp(move_name,"empty")==0||strcmp(move_name,"-1")==0)a.move=CB_MOVE_NONE;
        for(int i=0;i<CB_MOVE_COUNT;i++)if(strcasecmp(move_name,cp_combat_move_name(i))==0)a.move=i;
        if(a.move==-2){
            char *end;
            long value=strtol(move_name,&end,10);
            if(*move_name&&!*end&&value>=0&&value<CB_MOVE_COUNT)a.move=(int)value;
        }
        if(a.move==-2){rc=CP_STAGE_ERR_UNKNOWN_MOVE;goto done;}
    }
    else if(sscanf(text,"heading %f %c",&deg,&extra)==1){
        if(!isfinite(deg)||ab(deg)>1000000){rc=-1;goto done;}
        deg-=(int)(deg/360)*360;
        if(deg<0)deg+=360;
        int quadrant=(int)(deg/90);
        float angle=(deg-quadrant*90)*.01745329252f,t=angle*angle;
        float x=angle*(1+t*(-1.f/6+t*(1.f/120+t*(-1.f/5040+t/362880))));
        float z=1+t*(-.5f+t*(1.f/24+t*(-1.f/720+t/40320)));
        float n=length(x,z);
        x/=n;
        z/=n;
        if(quadrant==1){
            float q=x;
            x=z;
            z=-q;
        }
        else if(quadrant==2){
            x=-x;
            z=-z;
        }
        else if(quadrant==3){
            float q=x;
            x=-z;
            z=q;
        }
        a.verb=CP_STAGE_HEADING;
        a.hx=(int16_t)(x*32767);
        a.hz=(int16_t)(z*32767);
    }
    else{
        int soc_rc=0;
        if(cp_stage_social_parse(text,&a,&soc_rc))rc=soc_rc;
        else rc=-1;
    }
done:
    *out=a;
    return rc;
}
int cp_stage_parse(const char *text,CpStageInput *out){
    return parse_text(text,out);
}
int cp_stage_command(CpStageWorld *w,const char *text){
    CpStageInput a;
    if(!w||!text)return -1;
    const int rc=parse_text(text,&a);
    if(rc)return reject(w,&a,rc);
    if(a.verb==CP_STAGE_FLEE&&w->active<0&&!has_threat(w))return reject(w,&a,-5);
    return cp_stage_order(w,&a);
}
/* JSON formatting is observation only: atan2 is never used by state updates. */
static void append(char *out,size_t cap,size_t *used,int *failed,const char *fmt,...){
    if(*failed)return;
    va_list args;
    va_start(args,fmt);
    int n=vsnprintf(out+*used,cap-*used,fmt,args);
    va_end(args);
    if(n<0||(size_t)n>=cap-*used){
        *failed=1;
        return;
    }
    *used+=(size_t)n;
}
static float bearing(const CpStageCreature *p,float x,float z){
    return atan2f(p->fz*(x-p->x)-p->fx*(z-p->z),p->fx*(x-p->x)+p->fz*(z-p->z))*57.2957795f;
}
const char *cp_stage_order_error(int code){
    switch(code){
        case 0:return "ok";
        case -2:return "invalid or unavailable target";
        case -3:return "invalid or unavailable attack move";
        case -4:return "unreachable";
        case -5:return "no_threat";
        case -6:return "unknown_move";
        case CB_ERR_NO_METER:return "no_meter";
        case CP_STAGE_ERR_ON_COOLDOWN:return "on_cooldown";
        case CP_STAGE_ERR_NOT_EQUIPPED:return "not_equipped";
        case CP_STAGE_ERR_BAD_SLOT:return "invalid slot (1..4, and a signature move only fits the signature slot)";
        case CP_STAGE_ERR_NOT_KNOWN:return "not_known";
        case CP_STAGE_ERR_UNKNOWN_MOVE:return "unknown_move";
        case CP_STAGE_ERR_NOT_AT_NEST:return "not_at_nest";
        case CP_STAGE_ERR_IN_FIGHT:return "in_fight";
        case CP_STAGE_ERR_REFUSES:return "refuses (hostile, aggressive and not calmed, or in a bad mood)";
        case CP_STAGE_ERR_NO_ITEM:return "no_item";
        case CP_STAGE_ERR_BAD_SKILL:return "unknown_skill_or_item";
        case CP_STAGE_ERR_STAGGERED:return "staggered";
        case CP_STAGE_ERR_NO_STAMINA:return "no_stamina";
        case CP_STAGE_ERR_BUSY:return "busy (cooldown)";
        case CP_STAGE_ERR_DIET:return "cannot_digest (diet)";
        case CP_STAGE_ERR_FULL:return "full";
        case CP_STAGE_ERR_HARD_GROUND:return "hard_ground (only soft soil can be dug)";
        case CP_STAGE_ERR_ALREADY_DUG:return "already_dug";
        default:return "invalid command or value";
    }
}
/* Per tick, in this order: debug ops of the tick, then the order input of the tick, then the step.
 * Log and debug entries carry absolute world ticks (== replay index when starting from a setup). */
uint64_t cp_stage_replay_run(const CpStageSetup *setup,const uint8_t *snapshot,size_t snap_len,const CpStageField *field,
                             const CpStageLogEntry *log,int count,const CpStageDebugEntry *dbg,int dbg_count,
                             const CpStageRunEntry *runs,int run_count,uint32_t ticks,uint64_t *hashes){
    if(run_count<0||(run_count&&!runs))return 0;
    if(count<0||(count&&!log)||dbg_count<0||(dbg_count&&!dbg))return 0;
    CpStageWorld replay;
    memset(&replay,0,sizeof replay);
    uint32_t first=0;
    if(snapshot){
        if(cp_stage_restore(&replay,snapshot,snap_len,field))return 0;
        first=replay.tick;
    }
    else{
        if(!setup)return 0;
        if(field&&cp_stage_attach_field(&replay,field))return 0;
        if(cp_stage_reset(&replay,setup))return 0;
    }
    for(int i=0;i<count;i++)if(log[i].tick<first||log[i].tick-first>=ticks||(i&&log[i].tick<log[i-1].tick))return 0;
    for(int i=0;i<dbg_count;i++)if(dbg[i].tick<first||dbg[i].tick-first>=ticks||(i&&dbg[i].tick<dbg[i-1].tick))return 0;
    for(int i=0;i<run_count;i++)if(runs[i].tick<first||runs[i].tick-first>=ticks||(i&&runs[i].tick<runs[i-1].tick))return 0;
    int cursor=0,dcursor=0,rcursor=0;
    for(uint32_t k=0;k<ticks;k++){
        const uint32_t tick=first+k;
        while(dcursor<dbg_count&&dbg[dcursor].tick==tick)cp_stage_debug(&replay,&dbg[dcursor++].d);
        while(rcursor<run_count&&runs[rcursor].tick==tick){cp_stage_set_run(&replay,runs[rcursor].on&1);if(runs[rcursor].on&2)cp_stage_jump(&replay);rcursor++;}
        while(cursor<count&&log[cursor].tick==tick)cp_stage_order(&replay,&log[cursor++].input);
        uint64_t hash=cp_stage_step(&replay,NULL);
        if(hashes)hashes[k]=hash;
    }
    return cp_stage_hash(&replay);
}
uint64_t cp_stage_replay_ex(const CpStageSetup *setup,const uint8_t *snapshot,size_t snap_len,const CpStageField *field,
                            const CpStageLogEntry *log,int count,const CpStageDebugEntry *dbg,int dbg_count,
                            uint32_t ticks,uint64_t *hashes){
    return cp_stage_replay_run(setup,snapshot,snap_len,field,log,count,dbg,dbg_count,NULL,0,ticks,hashes);
}
uint64_t cp_stage_replay(const CpStageSetup *setup,const CpStageLogEntry *log,int count,uint32_t ticks,uint64_t *hashes){
    return cp_stage_replay_ex(setup,NULL,0,NULL,log,count,NULL,0,ticks,hashes);
}
static const char *block_name(int r){
    switch(r){
        case CP_STAGE_BLOCK_CLIFF:return "cliff";
        case CP_STAGE_BLOCK_WATER:return "water";
        case CP_STAGE_BLOCK_EDGE:return "edge";
        case CP_STAGE_BLOCK_CREATURE:return "creature";
        case CP_STAGE_BLOCK_UNREACHABLE:return "unreachable";
        case CP_STAGE_BLOCK_OBSTACLE:return "obstacle";
        default:return "none";
    }
}
static const char *creature_state(const CpStageWorld *w,int i){
    const CpStageCreature *e=&w->wild[i];
    const CpStageSpecies *s=&CP_STAGE_SPECIES[e->species];
    if(creature_is_dead(e))return "carcass";
    if(w->active==i)return "fighting";
    if(cp_stage_creature_hunkered(w,i))return "hunkered";
    const float d=dist(&w->player,e);
    if(e->returning)return "roam";
    if(s->temperament!=CP_STAGE_TIMID&&d<s->sight&&!w->cooldown_ticks)return "alert";
    if(s->temperament==CP_STAGE_TIMID&&d<s->sight*.5f)return "alert";
    return "roam";
}
int cp_stage_observe(const CpStageWorld *w,char *out,size_t cap){
    return cp_stage_observe_v(w,out,cap,2);
}
/* A move the player can attack with (part owned, not a self move). */
static int attack_move_ok(const CpStageWorld *w,int i){
    return (!CP_COMBAT_MOVES[i].meter_cost||cp_stage_recipe_ready(w))&&!(CP_COMBAT_MOVES[i].flags&CB_F_SELF)&&cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[i].part)>0;
}
/* Usable now: enough stamina, and (in a fight) the fighter is free to start it. */
static int attack_move_usable(const CpStageWorld *w,int i){
    if(w->recipes.calcium<CP_COMBAT_MOVES[i].meter_cost)return 0;
    if(!attack_move_ok(w,i)||cp_combat_loadout_slot_of(&w->loadout,i)<0||(w->recipes.cd[i]||(w->active>=0&&w->combat.c[0].cd[i]))||w->player.stamina<cp_combat_move_stamina(&w->player.profile,i))return 0;
    if(w->active>=0){
        const CpCombatCreature *c=&w->combat.c[0];
        return cp_combat_move_available(c,i)&&c->move==CB_MOVE_NONE&&c->phase!=CB_PH_RECOVERY&&c->stun_t<=0;
    }
    return 1;
}
/* Centre-to-target-surface gap against the move's reach (the combat rule). */
static int attack_move_reaches(const CpStageWorld *w,int i,const CpStageCreature *t){
    return dist(&w->player,t)-cp_combat_body_radius(&t->profile)<=CP_COMBAT_MOVES[i].reach;
}
static int creature_attackable(const CpStageWorld *w,int k){
    const CpStageCreature *t=&w->wild[k];
    if(creature_is_dead(t)||(w->active>=0&&w->active!=k))return 0;
    for(int i=0;i<CB_MOVE_COUNT;i++)if(attack_move_ok(w,i)&&attack_move_reaches(w,i,t))return 1;
    return 0;
}
int cp_stage_observe_v(const CpStageWorld *w,char *out,size_t cap,int version){
    if(!out||!cap||(version!=1&&version!=2))return -1;
    size_t used=0;
    int failed=0,comma=0;
#define ADD(...) append(out,cap,&used,&failed,__VA_ARGS__)
    ADD("{\"schema\":\"world-%d\",\"tick\":%u,\"clock\":{\"tick\":%u,\"day_ticks\":%d},",version,w->tick,w->clock,CP_STAGE_DAY_TICKS);
    if(version==2){char r[4096];if(cp_stage_recipes_json(w,r,sizeof r)<0)return -1;ADD("\"recipes\":%s,",r);}
    if(version==2){char parts[16384];if(cp_stage_parts_json(w,parts,sizeof parts)<0)return -1;ADD("\"parts\":%s,",parts);}
    if(version==2){char sec[8192];if(cp_stage_secrets_json(w,sec,sizeof sec)<0)return -1;ADD("\"secrets\":%s,",sec);}
    if(version==2){char dg[2048];if(cp_stage_dig_observe(w,dg,sizeof dg)<0)return -1;ADD("\"dig\":%s,",dg);}
    if(version==2)ADD("\"world\":{\"bound\":%.6f,\"units\":\"metres; x and z are the ground plane; heading 0 = +z and 90 = +x (clockwise seen from above with +z up); bearing is relative to your facing, positive = clockwise (to your right), 0 = dead ahead, +-180 = behind\",\"nest\":{\"x\":%.6f,\"z\":%.6f},\"tick_hz\":10},",cp_stage_bound(w),w->setup.nest_x,w->setup.nest_z);
    if(version==2){int scores[4],prev=w->ancestry.count>1?w->ancestry.forms[w->ancestry.count-2].type:15;char code[8];int type=cp_type_score(w->ledger.current,prev,scores);cp_type_code(type,code);
        ADD("\"lineage\":{\"format\":\"cpore.lineage/1\",\"enabled\":%s,\"generation\":%u,\"trait_mask\":%u,\"entries\":%u,\"deeds_aggregated\":%u,\"type_code\":\"%s\",\"scores\":[%d,%d,%d,%d]},",w->ledger.enabled?"true":"false",w->ledger.generation,w->ledger.traits,w->ledger.count,w->ledger.dropped,code,scores[0],scores[1],scores[2],scores[3]);}

    ADD("\"own\":{\"id\":0,\"x\":%.6f,\"z\":%.6f,\"hp\":%.6f,\"stamina\":%.6f,\"hp_max\":%.6f,\"stamina_max\":%.6f,\"speed\":%.6f,\"facing\":[%.6f,%.6f]},\"last_error\":\"%s\",",w->player.x,w->player.z,w->player.hp,w->player.stamina,w->player.profile.hp,w->player.profile.stamina,w->player.speed,w->player.fx,w->player.fz,cp_stage_order_error(w->last_error));
    if(version==2)ADD("\"player\":{\"running\":%s,\"stamina\":%d,\"falling\":%s,\"y\":%.3f,\"vertical_velocity\":%.3f},",w->running?"true":"false",w->run_stamina,w->falling?"true":"false",w->falling?w->fall_y_mm*.001f:cp_stage_ground(w,w->player.x,w->player.z),w->fall_v_mm_s*.001f);
    if(version==2){
        if(w->blocked_reason)ADD("\"blocked\":{\"reason\":\"%s\",\"x\":%.6f,\"z\":%.6f},",block_name(w->blocked_reason),w->blocked_x,w->blocked_z);
        else ADD("\"blocked\":null,");
        uint32_t first=w->ev_acked;
        if(w->ev_total-first>CP_STAGE_MAX_EVENTS)first=w->ev_total-CP_STAGE_MAX_EVENTS;
        ADD("\"events_dropped\":%u,\"events\":[",first-w->ev_acked);
        for(uint32_t k=first;k<w->ev_total;k++){
            const CpStageEvent *e=&w->events[k%CP_STAGE_MAX_EVENTS];
            const char *sep=k>first?",":"";
            switch(e->type){
                case CP_STAGE_EV_FELL:ADD("%s{\"tick\":%u,\"type\":\"fell\",\"drop_cm\":%d,\"damage\":%.3f}",sep,e->tick,e->move,e->value);break;
                case CP_STAGE_EV_HIT:ADD("%s{\"tick\":%u,\"type\":\"hit\",\"by\":%d,\"target\":%d,\"move\":\"%s\",\"damage\":%.3f}",sep,e->tick,e->by,e->target,e->move>=0&&e->move<CB_MOVE_COUNT?cp_combat_move_name(e->move):"none",e->value);break;
                case CP_STAGE_EV_KILL:ADD("%s{\"tick\":%u,\"type\":\"kill\",\"target\":%d}",sep,e->tick,e->target);break;
                case CP_STAGE_EV_DEATH:ADD("%s{\"tick\":%u,\"type\":\"death\",\"by\":%d}",sep,e->tick,e->by);break;
                case CP_STAGE_EV_RESPAWN:ADD("%s{\"tick\":%u,\"type\":\"respawn\",\"x\":%.3f,\"z\":%.3f}",sep,e->tick,e->x,e->z);break;
                case CP_STAGE_EV_ORDER_REJECTED:ADD("%s{\"tick\":%u,\"type\":\"order_rejected\",\"error\":\"%s\"}",sep,e->tick,cp_stage_order_error((int)e->value));break;
                case CP_STAGE_EV_PATH_FOUND:ADD("%s{\"tick\":%u,\"type\":\"path_found\",\"length\":%.1f,\"x\":%.3f,\"z\":%.3f}",sep,e->tick,e->value,e->x,e->z);break;
                case CP_STAGE_EV_ARRIVED:ADD("%s{\"tick\":%u,\"type\":\"arrived\",\"x\":%.3f,\"z\":%.3f}",sep,e->tick,e->x,e->z);break;
                case CP_STAGE_EV_FLED:ADD("%s{\"tick\":%u,\"type\":\"fled\",\"target\":%d}",sep,e->tick,e->target);break;
                case CP_STAGE_EV_PATH_FAILED:ADD("%s{\"tick\":%u,\"type\":\"path_failed\",\"x\":%.3f,\"z\":%.3f,\"reason\":\"%s\"}",sep,e->tick,e->x,e->z,block_name((int)e->value));break;
                default:{
                    char eb[640];
                    if(cp_stage_social_event_json(e,eb,sizeof eb))ADD("%s%s",sep,eb);
                    else ADD("%s{\"tick\":%u,\"type\":\"unknown\"}",sep,e->tick);
                    break;
                }
            }
        }
        ADD("],");
    }
    ADD("\"nearby\":[");
    for(int i=0;i<w->setup.n;i++){
        const CpStageCreature *e=&w->wild[i];
        float d=dist(&w->player,e);
        if(d>40||cp_stage_creature_hidden(w,i))continue;   /* an asleep nocturnal creature cannot be perceived */
        if(version==2){
            const char *state=creature_state(w,i);
            ADD("%s{\"id\":%d,\"type\":\"%s\",\"species\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f,\"hp\":%.6f,\"hp_max\":%.6f,\"state\":\"%s\",\"in_fight\":%s,\"attackable\":%s}",comma?",":"",i+1,creature_is_dead(e)?"carcass":"creature",CP_STAGE_SPECIES[e->species].name,d,bearing(&w->player,e->x,e->z),e->hp,e->profile.hp,state,w->active==i?"true":"false",creature_attackable(w,i)?"true":"false");
            {
                const int generation=cp_stage_cousin_generation(w,i+1);
                if(generation){
                    used--;
                    ADD(",\"cousin_generation\":%d,\"lineage_species_id\":%d,\"counts_progress\":false}",generation,4+generation);
                }
            }
            if(creature_is_dead(e)){
                char sb[256];
                if(cp_stage_social_carcass_json(w,i,sb,sizeof sb)>0){
                    used--;
                    ADD("%s}",sb);
                }
            }
            else{
                char sb[1024];
                if(cp_stage_social_creature_json(w,i,sb,sizeof sb)>0){
                    /* splice the social fields in before the closing brace */
                    used--;
                    ADD("%s}",sb);
                }
            }
        }
        else ADD("%s{\"id\":%d,\"type\":\"%s\",\"species\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",i+1,creature_is_dead(e)?"carcass":"creature",CP_STAGE_SPECIES[e->species].name,d,bearing(&w->player,e->x,e->z));
        comma=1;
    }
    float d=length(w->setup.nest_x-w->player.x,w->setup.nest_z-w->player.z);
    if(d<=40){
        ADD("%s{\"id\":1000,\"type\":\"nest\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",d,bearing(&w->player,w->setup.nest_x,w->setup.nest_z));
        comma=1;
    }
    for(int i=0;i<w->setup.n_obstacles;i++){
        const CpStageObstacle *o=&w->setup.obstacles[i];
        d=length(o->x-w->player.x,o->z-w->player.z);
        if(d<=40){
            ADD("%s{\"id\":%d,\"type\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",2000+i,o->type?"rock":"tree",d,bearing(&w->player,o->x,o->z));
            comma=1;
        }
    }
    ADD("],\"legal_verbs\":[\"go\",\"heading\"");
    if(version==1||w->active>=0||has_threat(w))ADD(",\"flee\"");   /* world-2 lists flee only when there is something to flee from */
    ADD(",\"go_nest\",\"wait\"");
    int target=0,attacks=0;
    for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&!cp_stage_creature_hidden(w,i)&&(w->active<0||w->active==i))target=1;
    for(int i=0;i<CB_MOVE_COUNT;i++)if(attack_move_ok(w,i)&&cp_combat_loadout_slot_of(&w->loadout,i)>=0)attacks++;
    if(target)ADD(",\"approach\"");
    if(target&&attacks)ADD(",\"attack\"");
    if(version==2){
        if(w->active<0&&!w->falling&&!w->respawn_ticks&&cp_stage_soft_soil(w,w->player.x,w->player.z)&&w->player.stamina>=CP_DIG_STAMINA)ADD(",\"dig\"");
        if(cp_stage_social_legal(w,CP_STAGE_BEFRIEND))ADD(",\"befriend\"");
        if(cp_stage_social_legal(w,CP_STAGE_OBSERVE))ADD(",\"observe\"");
        if(cp_stage_social_legal(w,CP_STAGE_INTIMIDATE))ADD(",\"intimidate\"");
        if(cp_stage_social_legal(w,CP_STAGE_EAT))ADD(",\"eat\"");
        if(cp_stage_social_legal(w,CP_STAGE_GIFT))ADD(",\"gift\"");
    }
    if(version==2&&!w->parts.lost){
        if(cp_stage_can_edit(w))ADD(",\"buy_part\",\"buy_level\",\"buy_tier\",\"edit\"");
        for(int i=0;i<w->parts.n_nodes;i++){float dx=w->player.x-w->parts.nodes[i].x,dz=w->player.z-w->parts.nodes[i].z;
            if(!w->parts.nodes[i].inspected&&w->active<0&&!w->respawn_ticks&&dx*dx+dz*dz<=6.25f){ADD(",\"inspect\"");break;}}
        if(w->secrets.on&&w->active<0&&!w->respawn_ticks)for(int k=0;k<CP_STAGE_SHARDS;k++){float dx=w->player.x-w->secrets.shard[k][0],dz=w->player.z-w->secrets.shard[k][1];
            if(!(w->secrets.found_mask&(1<<k))&&dx*dx+dz*dz<=6.25f){ADD(",\"inspect\"");break;}}
    }
    if(version==2&&cp_stage_at_nest(w))ADD(",\"loadout\"");   /* only at the nest, never in a fight */
    ADD("]");
    if(version==2){
        /* A21: the kit. Slots are keys 1..4; guard and dodge are always available and never in a slot. */
        const int edit=w->active<0&&length(w->player.x-w->setup.nest_x,w->player.z-w->setup.nest_z)<=CP_STAGE_NEST_RADIUS;
        ADD(",\"loadout\":{\"slots\":[");
        for(int k=0;k<CB_LOADOUT_SLOTS;k++){
            const int mv=w->loadout.slot[k];
            if(mv>=0&&mv<CB_MOVE_COUNT)ADD("%s\"%s\"",k?",":"",cp_combat_move_name(mv));
            else ADD("%snull",k?",":"");
        }
        ADD("],\"signature_slot\":");
        if(w->loadout.sig_slot>=0)ADD("%d",w->loadout.sig_slot+1);else ADD("null");
        ADD(",\"can_edit\":%s,\"nest_radius_m\":%.1f},\"known_moves\":[",edit?"true":"false",(double)CP_STAGE_NEST_RADIUS);
        const uint16_t known=cp_stage_known_moves(w);
        int kc=0;
        for(int i=0;i<CB_MOVE_COUNT;i++)if(known&(1u<<i)){
            ADD("%s\"%s\"",kc?",":"",cp_combat_move_name(i));
            kc++;
        }
        ADD("]");
        {
            char *sb=malloc(16384);
            if(sb&&cp_stage_social_json(w,sb,16384)>0)ADD(",\"social\":%s",sb);
            free(sb);
        }
    }
    ADD(",\"attack_moves\":[");
    comma=0;
    int tgt=-1;
    float best=1e30f;
    for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&(w->active<0||w->active==i)&&dist(&w->player,&w->wild[i])<best){
        tgt=i;
        best=dist(&w->player,&w->wild[i]);
    }
    for(int i=0;i<CB_MOVE_COUNT;i++)if(attack_move_ok(w,i)){
        const CpCombatMove *m=&CP_COMBAT_MOVES[i];
        if(version==2){
            const int slot=cp_combat_loadout_slot_of(&w->loadout,i),left=w->active>=0?w->combat.c[0].cd[i]:w->recipes.cd[i];
            ADD("%s{\"index\":%d,\"id\":%d,\"name\":\"%s\",\"role\":\"%s\",\"stamina_cost\":%.3f,\"range_m\":%.3f,\"windup_ticks\":%d,\"active_ticks\":%d,\"recover_ticks\":%d,\"cooldown_ticks\":%d,\"cooldown_left\":%d,\"equipped\":%s,\"slot\":",comma?",":"",i,i,m->name,cp_combat_role_name(m->role),cp_combat_move_stamina(&w->player.profile,i),m->reach,m->windup,m->active,m->recovery,m->cooldown,left,slot>=0?"true":"false");
            if(slot>=0)ADD("%d",slot+1);else ADD("null");
            ADD(",\"usable\":%s,\"target_in_range\":%s}",attack_move_usable(w,i)?"true":"false",tgt<0?"null":attack_move_reaches(w,i,&w->wild[tgt])?"true":"false");
        }
        else ADD("%s{\"index\":%d,\"id\":%d,\"name\":\"%s\",\"stamina_cost\":%.3f,\"range_m\":%.3f,\"windup_ticks\":%d,\"active_ticks\":%d,\"recover_ticks\":%d,\"usable\":%s,\"target_in_range\":%s}",comma?",":"",i,i,m->name,cp_combat_move_stamina(&w->player.profile,i),m->reach,m->windup,m->active,m->recovery,attack_move_usable(w,i)?"true":"false",tgt<0?"null":attack_move_reaches(w,i,&w->wild[tgt])?"true":"false");
        comma=1;
    }
    ADD("],\"summary\":\"Explore the valley; creature ids are stable.\"}");
#undef ADD
    return failed?-1:(int)used;
}

/* ---- debug ops (PLAN-devtools step 4) -----------------------------------------------------------
 * Everything the dev tools change in the simulation goes through here (and the per-tick log), so a
 * session with teleports, spawns and tuning replays bit for bit. Rejected ops change nothing. */
#define MOTION_PARAM(field,lo,hi) {#field,"movement",offsetof(CpStageMotion,field),lo,hi}
const CpStageParam CP_STAGE_PARAMS[]={
    MOTION_PARAM(jog_k,.3f,5.f),MOTION_PARAM(sprint_k,1.f,4.f),MOTION_PARAM(wild_k,.1f,3.f),
    MOTION_PARAM(accel,2.f,60.f),MOTION_PARAM(brake,2.f,60.f),MOTION_PARAM(ease,.05f,1.f),
    MOTION_PARAM(turn_k,.2f,3.f),MOTION_PARAM(turn_min,.5f,10.f),MOTION_PARAM(turn_max,.5f,10.f),
    MOTION_PARAM(grip,3.f,50.f),MOTION_PARAM(pivot_k,.05f,1.f),MOTION_PARAM(pivot_mul,.5f,8.f),
    MOTION_PARAM(pivot_max,2.f,20.f),MOTION_PARAM(turn_slow,0.f,1.f),
    MOTION_PARAM(ang_k,.1f,5.f),MOTION_PARAM(grip_mass,0.f,2.f),MOTION_PARAM(acc_mass,0.f,2.f),
    MOTION_PARAM(creep,0.f,1.f),MOTION_PARAM(pivot_r,0.f,5.f),MOTION_PARAM(look_min,.2f,10.f),
    MOTION_PARAM(look_k,0.f,3.f),MOTION_PARAM(climb_base,.1f,2.f),MOTION_PARAM(climb_legs,0.f,3.f),MOTION_PARAM(stall_mul,1.f,3.f),
    MOTION_PARAM(slide_mul,1.f,3.f),MOTION_PARAM(slide_k,0.f,30.f),MOTION_PARAM(down_gain,0.f,1.f),MOTION_PARAM(walk_fr,.1f,1.5f)
};
const int CP_STAGE_PARAM_COUNT=(int)(sizeof CP_STAGE_PARAMS/sizeof *CP_STAGE_PARAMS);
static int spot_ok(const CpStageWorld *w,float x,float z,float radius){
    if(!isfinite(x)||!isfinite(z)||ab(x)>cp_stage_bound(w)||ab(z)>cp_stage_bound(w))return 0;
    if(w->setup.terrain==CP_STAGE_FIELD?cp_stage_water_depth(w,x,z)>.7f:cp_stage_ground(w,x,z)<-.7f)return 0;
    for(int i=0;i<w->setup.n_obstacles;i++){
        const CpStageObstacle *o=&w->setup.obstacles[i];
        if(length(x-o->x,z-o->z)<o->r+radius)return 0;
    }
    return 1;
}
const char *cp_stage_debug_error(int code){
    switch(code){
        case 0:return "ok";
        case -2:return "not during a fight";
        case -3:return "the world is full (24 creatures)";
        case -4:return "that spot is outside the island, in deep water or inside an obstacle";
        default:return "invalid debug op or value";
    }
}
int cp_stage_debug(CpStageWorld *w,const CpStageDebug *d){
    if(!w||!d)return -1;
    int rc=0;
    switch(d->op){
        case CP_STAGE_DBG_TELEPORT:{
            if(d->id<0||d->id>w->setup.n||!isfinite(d->x)||!isfinite(d->z))return -1;
            CpStageCreature *c=d->id?&w->wild[d->id-1]:&w->player;
            if(w->active>=0&&(d->id==0||d->id==w->active+1))return -2;
            if(!spot_ok(w,d->x,d->z,cp_combat_body_radius(&c->profile)))return -4;
            c->x=d->x;
            c->z=d->z;
            c->speed=c->acceleration=c->turn_rate=0;
            if(!d->id){w->jumping=0;w->falling=0;w->fall_y_mm=w->fall_start_mm=w->fall_v_mm_s=0;w->fall_dx_mm=w->fall_dz_mm=0;c->sliding=0;}
            if(d->id)c->goal_x=d->x,c->goal_z=d->z;
            break;
        }
        case CP_STAGE_DBG_SPAWN:{
            if(d->a<0||d->a>=CP_STAGE_SPECIES_DEFINED||!isfinite(d->x)||!isfinite(d->z))return -1;
            if(w->setup.n>=CP_STAGE_MAX_WILD)return -3;
            const CpStageSpecies *sp=&CP_STAGE_SPECIES[d->a];
            if(!spot_ok(w,d->x,d->z,cp_combat_body_radius(&sp->profile)))return -4;
            const int n=w->setup.n;
            w->setup.wild[n]=(CpStageSpawn){.x=d->x,.z=d->z,.home_x=d->x,.home_z=d->z,.species=d->a,.bot=-1,.profile=sp->profile};
            creature(&w->wild[n],d->x,d->z,d->a,&sp->profile);
            w->wild[n].fz=-1;
            w->wild[n].roam_ticks=40; /* no RNG draw: the other streams stay untouched */
            w->setup.n=n+1;
            break;
        }
        case CP_STAGE_DBG_KILL:
            if(d->id<1||d->id>w->setup.n)return -1;
            if(w->active==d->id-1)return -2;
            w->wild[d->id-1].dead=1;
            break;
        case CP_STAGE_DBG_HEAL:{
            if(d->id<0||d->id>w->setup.n||!isfinite(d->x)||!isfinite(d->z)||d->x==0)return -1;
            CpStageCreature *c=d->id?&w->wild[d->id-1]:&w->player;
            if(d->id&&c->dead)return -1;
            const float hp=d->x<0?c->profile.hp:d->x>c->profile.hp?c->profile.hp:d->x;
            const float st=d->z<0?c->profile.stamina:d->z>c->profile.stamina?c->profile.stamina:d->z;
            c->hp=hp;
            c->stamina=st;
            if(w->active>=0&&(d->id==0||d->id==w->active+1)){
                CpCombatCreature *cc=&w->combat.c[d->id?1:0];
                cc->hp=hp;
                cc->stamina=st;
            }
            break;
        }
        case CP_STAGE_DBG_CLOCK:
            if(d->a<0||d->a>=CP_STAGE_DAY_TICKS)return -1;
            w->clock=(uint32_t)d->a;
            break;
        case CP_STAGE_DBG_FLAGS:
            if(d->a<0||(d->a&~(CP_STAGE_FLAG_GOD|CP_STAGE_FLAG_AI_OFF)))return -1;
            w->debug_flags=d->a;
            break;
        case CP_STAGE_DBG_PARAM:{
            if(d->a<0||d->a>=CP_STAGE_PARAM_COUNT||!isfinite(d->v))return -1;
            const CpStageParam *p=&CP_STAGE_PARAMS[d->a];
            *(float *)((char *)&w->motion+p->offset)=clamp(d->v,p->min,p->max);
            break;
        }
        case CP_STAGE_DBG_GRANT:{
            if(d->a<-1||d->a>=CP_STAGE_PART_COUNT)return -1;
            for(int p=d->a<0?0:d->a,end=d->a<0?CP_STAGE_PART_COUNT:d->a+1;p<end;p++){
                w->parts.discovered|=1ULL<<p;w->parts.owned|=1ULL<<p;
                if(w->parts.level[p]<1)w->parts.level[p]=1;
            }
            w->parts.used=1;
            break;
        }
        default:return -1;
    }
    w->hash=cp_stage_hash(w);
    return rc;
}
/* ---- snapshot / restore (PLAN-devtools step 3) ------------------------------------------------
 * Raw copy of the POD world (no pointers, no heap) up to `field`, so a restored world is bit-identical,
 * RNG streams and derived outputs included. Guarded by a layout fingerprint instead of assumed portable. */
#define SNAP_HEADER 48u
#define SNAP_PAYLOAD (offsetof(CpStageWorld,field))
static void lay(uint64_t *h,size_t v){
    for(int i=0;i<8;i++){
        *h^=(uint8_t)((uint64_t)v>>(8*i));
        *h*=1099511628211ULL;
    }
}
#define LAY(T,m) do{lay(&h,offsetof(T,m));lay(&h,sizeof(((T*)0)->m));}while(0)
uint64_t cp_stage_layout(void){
    uint64_t h=14695981039346656037ULL;
    lay(&h,sizeof(CpStageWorld));lay(&h,sizeof(CpStageSetup));lay(&h,sizeof(CpStageCreature));
    lay(&h,sizeof(CpCombatWorld));lay(&h,sizeof(CpCombatCreature));lay(&h,sizeof(CpStageBot));
    lay(&h,sizeof(CpStageMotion));lay(&h,sizeof(CpStageInput));lay(&h,sizeof(CpStageSpawn));
    lay(&h,sizeof(CpStageObstacle));lay(&h,sizeof(CpCombatProfile));lay(&h,sizeof(CpRng));
    lay(&h,sizeof(CpCombatHill));lay(&h,sizeof(CpCombatEvent));lay(&h,sizeof(CpCombatAction));
    LAY(CpStageWorld,setup);LAY(CpStageWorld,spawn_rng);LAY(CpStageWorld,roam_rng);LAY(CpStageWorld,noise);
    LAY(CpStageWorld,tick);LAY(CpStageWorld,clock);LAY(CpStageWorld,player);LAY(CpStageWorld,wild);
    LAY(CpStageWorld,order);LAY(CpStageWorld,active);LAY(CpStageWorld,started);LAY(CpStageWorld,outcome);
    LAY(CpStageWorld,respawn_ticks);LAY(CpStageWorld,cooldown_ticks);LAY(CpStageWorld,arena_x);
    LAY(CpStageWorld,arena_z);LAY(CpStageWorld,combat);LAY(CpStageWorld,bot);LAY(CpStageWorld,combat_orders);
    LAY(CpStageWorld,accepted);LAY(CpStageWorld,last_error);LAY(CpStageWorld,hash);LAY(CpStageWorld,motion);
    LAY(CpStageWorld,debug_flags);LAY(CpStageWorld,edit_anywhere);LAY(CpStageWorld,field_hash);LAY(CpStageWorld,path);LAY(CpStageWorld,n_path);LAY(CpStageWorld,path_i);
    LAY(CpStageWorld,blocked_ticks);LAY(CpStageWorld,replans);LAY(CpStageWorld,path_goal_x);LAY(CpStageWorld,path_goal_z);
    LAY(CpStageWorld,blocked_reason);LAY(CpStageWorld,blocked_x);LAY(CpStageWorld,blocked_z);LAY(CpStageWorld,ev_total);
    LAY(CpStageWorld,running);LAY(CpStageWorld,run_stamina);LAY(CpStageWorld,falling);LAY(CpStageWorld,fall_y_mm);LAY(CpStageWorld,fall_v_mm_s);LAY(CpStageWorld,fall_start_mm);LAY(CpStageWorld,fall_dx_mm);LAY(CpStageWorld,fall_dz_mm);LAY(CpStageWorld,jumping);LAY(CpStageWorld,jump_cd);
    LAY(CpStageWorld,ev_acked);LAY(CpStageWorld,events);LAY(CpStageWorld,loadout);LAY(CpStageWorld,social);LAY(CpStageWorld,ledger);LAY(CpStageWorld,ancestry);LAY(CpStageWorld,parts);LAY(CpStageWorld,recipes);LAY(CpStageWorld,secrets);LAY(CpStageWorld,dig);LAY(CpStageWorld,grace_until);LAY(CpStageWorld,wake_until);LAY(CpStageWorld,field);lay(&h,sizeof(CpStageSecrets));lay(&h,sizeof(CpStageCave));lay(&h,sizeof(CpStageSocial));lay(&h,sizeof(CpStageSocialCreature));lay(&h,sizeof(CpStageEvent));
    LAY(CpStageSetup,seed);LAY(CpStageSetup,terrain_seed);LAY(CpStageSetup,terrain);LAY(CpStageSetup,n);
    LAY(CpStageSetup,n_obstacles);LAY(CpStageSetup,nest_x);LAY(CpStageSetup,nest_z);LAY(CpStageSetup,flat_height);
    LAY(CpStageSetup,water_x);LAY(CpStageSetup,water_z);LAY(CpStageSetup,water_radius);LAY(CpStageSetup,player);LAY(CpStageSetup,player_legs);
    LAY(CpStageSetup,wild);LAY(CpStageSetup,obstacles);LAY(CpStageSetup,secrets);LAY(CpStageSetup,start_clock);LAY(CpStageSetup,cave);
    LAY(CpStageCreature,x);LAY(CpStageCreature,z);LAY(CpStageCreature,fx);LAY(CpStageCreature,fz);
    LAY(CpStageCreature,hp);LAY(CpStageCreature,stamina);LAY(CpStageCreature,speed);LAY(CpStageCreature,acceleration);
    LAY(CpStageCreature,turn_rate);LAY(CpStageCreature,home_x);LAY(CpStageCreature,home_z);LAY(CpStageCreature,goal_x);
    LAY(CpStageCreature,goal_z);LAY(CpStageCreature,species);LAY(CpStageCreature,dead);LAY(CpStageCreature,pivot);
    LAY(CpStageCreature,returning);LAY(CpStageCreature,roam_ticks);LAY(CpStageCreature,profile);LAY(CpStageCreature,omega);LAY(CpStageCreature,legs);LAY(CpStageCreature,sliding);
    LAY(CpCombatWorld,rng);LAY(CpCombatWorld,seed);LAY(CpCombatWorld,tick);LAY(CpCombatWorld,n);LAY(CpCombatWorld,hill);
    LAY(CpCombatWorld,n_hills);LAY(CpCombatWorld,c);LAY(CpCombatWorld,ev);LAY(CpCombatWorld,n_ev);LAY(CpCombatWorld,hash);
    LAY(CpStageCreature,slip_air);LAY(CpStageCreature,slip_y);LAY(CpStageCreature,slip_v);LAY(CpStageCreature,slip_start);LAY(CpStageCreature,slip_dx);LAY(CpStageCreature,slip_dz);
    LAY(CpCombatProfile,grip_traits);LAY(CpCombatProfile,grip_legs);
    LAY(CpCombatCreature,alive);LAY(CpCombatCreature,medium);LAY(CpCombatCreature,team);LAY(CpCombatCreature,prof);
    LAY(CpCombatCreature,x);LAY(CpCombatCreature,y);LAY(CpCombatCreature,fx);LAY(CpCombatCreature,fy);
    LAY(CpCombatCreature,hp);LAY(CpCombatCreature,stamina);LAY(CpCombatCreature,move);LAY(CpCombatCreature,phase);
    LAY(CpCombatCreature,ptick);LAY(CpCombatCreature,plen);LAY(CpCombatCreature,hit_mask);LAY(CpCombatCreature,dash_x);
    LAY(CpCombatCreature,dash_y);LAY(CpCombatCreature,stun_t);LAY(CpCombatCreature,bleed_t);LAY(CpCombatCreature,slow_t);
    LAY(CpCombatCreature,since_spend);LAY(CpCombatCreature,bleed_src);LAY(CpCombatCreature,burn_t);LAY(CpCombatCreature,burn_src);LAY(CpCombatCreature,verb);
    LAY(CpCombatCreature,verb_move);LAY(CpCombatCreature,verb_started);LAY(CpCombatCreature,verb_target);
    LAY(CpCombatCreature,verb_dir);LAY(CpCombatCreature,verb_ticks);LAY(CpCombatCreature,heading_x);
    LAY(CpCombatCreature,heading_y);LAY(CpCombatCreature,dmg_dealt);LAY(CpCombatCreature,dmg_taken);
    LAY(CpCombatCreature,stamina_spent);LAY(CpCombatCreature,hits);LAY(CpCombatCreature,hits_taken);
    LAY(CpCombatCreature,blocked);LAY(CpCombatCreature,dodged);LAY(CpCombatCreature,interrupted);
    LAY(CpCombatCreature,kills);LAY(CpCombatCreature,died_tick);LAY(CpCombatCreature,ctx_on);LAY(CpCombatCreature,vctx);LAY(CpCombatCreature,mctx);LAY(CpCombatCreature,over_t);LAY(CpCombatCreature,mspd);LAY(CpCombatCreature,kbx);LAY(CpCombatCreature,spd);LAY(CpCombatWorld,proj);lay(&h,sizeof(CpCombatProj));LAY(CpCombatCreature,lo);LAY(CpCombatCreature,cd);
    LAY(CpCombatLoadout,slot);LAY(CpCombatLoadout,sig_slot);LAY(CpCombatLoadout,pad);LAY(CpCombatLoadout,known);
    LAY(CpStageBot,rng);LAY(CpStageBot,kind);LAY(CpStageBot,spam_move);LAY(CpStageBot,delay);
    LAY(CpStageBot,reaction);LAY(CpStageBot,ranged_commit);LAY(CpStageBot,timer);
    LAY(CpStageMotion,jog_k);LAY(CpStageMotion,sprint_k);LAY(CpStageMotion,wild_k);LAY(CpStageMotion,accel);
    LAY(CpStageMotion,brake);LAY(CpStageMotion,ease);LAY(CpStageMotion,turn_k);LAY(CpStageMotion,turn_min);
    LAY(CpStageMotion,turn_max);LAY(CpStageMotion,grip);LAY(CpStageMotion,pivot_k);LAY(CpStageMotion,pivot_mul);
    LAY(CpStageMotion,pivot_max);LAY(CpStageMotion,turn_slow);LAY(CpStageMotion,walk_fr);
    return h;
}
size_t cp_stage_world_size(void){
    return sizeof(CpStageWorld);
}
size_t cp_stage_snapshot_size(void){
    return SNAP_HEADER+SNAP_PAYLOAD;
}
static void put32(uint8_t *p,uint32_t v){
    for(int i=0;i<4;i++)p[i]=(uint8_t)(v>>(8*i));
}
static void put64(uint8_t *p,uint64_t v){
    for(int i=0;i<8;i++)p[i]=(uint8_t)(v>>(8*i));
}
static uint32_t get32(const uint8_t *p){
    return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static uint64_t get64(const uint8_t *p){
    return (uint64_t)get32(p)|(uint64_t)get32(p+4)<<32;
}
int cp_stage_snapshot(const CpStageWorld *w,uint8_t *out,size_t cap){
    if(!w||!out||cap<SNAP_HEADER+SNAP_PAYLOAD)return CP_STAGE_SNAP_ERR_SIZE;
    memcpy(out,"CPSTAGE",8);
    put32(out+8,CP_STAGE_SNAPSHOT_VERSION);
    put32(out+12,CP_STAGE_VERSION);
    put64(out+16,cp_stage_layout());
    put32(out+24,(uint32_t)SNAP_PAYLOAD);
    put32(out+28,0);
    put64(out+32,w->field_hash);
    put64(out+40,cp_stage_hash(w));
    memcpy(out+SNAP_HEADER,w,SNAP_PAYLOAD);
    return (int)(SNAP_HEADER+SNAP_PAYLOAD);
}
int cp_stage_restore(CpStageWorld *w,const uint8_t *in,size_t len,const CpStageField *field){
    if(!w||!in||len<SNAP_HEADER||memcmp(in,"CPSTAGE",8))return CP_STAGE_SNAP_ERR_MAGIC;
    if(get32(in+8)!=CP_STAGE_SNAPSHOT_VERSION)return CP_STAGE_SNAP_ERR_FORMAT;
    if(get32(in+12)!=CP_STAGE_VERSION)return CP_STAGE_SNAP_ERR_ENGINE;
    if(get64(in+16)!=cp_stage_layout())return CP_STAGE_SNAP_ERR_LAYOUT;
    if(get32(in+24)!=SNAP_PAYLOAD||get32(in+28)!=0||len!=SNAP_HEADER+SNAP_PAYLOAD)return CP_STAGE_SNAP_ERR_SIZE;
    const uint64_t field_hash=get64(in+32);
    if(field_hash&&(!field||field->hash!=field_hash))return CP_STAGE_SNAP_ERR_FIELD;
    CpStageWorld temp;
    memset(&temp,0,sizeof temp);
    memcpy(&temp,in+SNAP_HEADER,SNAP_PAYLOAD);
    temp.field=field_hash?field:NULL;
    if(temp.field_hash!=field_hash||cp_stage_hash(&temp)!=get64(in+40))return CP_STAGE_SNAP_ERR_HASH;
    temp.hash=get64(in+40);
    *w=temp;
    return CP_STAGE_SNAP_OK;
}
const char *cp_stage_snapshot_error(int code){
    switch(code){
        case CP_STAGE_SNAP_OK:return "ok";
        case CP_STAGE_SNAP_ERR_MAGIC:return "not a world snapshot (wrong magic)";
        case CP_STAGE_SNAP_ERR_FORMAT:return "snapshot format is newer or older than this build reads";
        case CP_STAGE_SNAP_ERR_ENGINE:return "snapshot was made by another engine version (CP_STAGE_VERSION); rebuild it from the scenario recipe";
        case CP_STAGE_SNAP_ERR_LAYOUT:return "snapshot memory layout differs from this build (different struct layout); rebuild it from the scenario recipe";
        case CP_STAGE_SNAP_ERR_SIZE:return "snapshot has the wrong size or a buffer is too small";
        case CP_STAGE_SNAP_ERR_FIELD:return "snapshot needs the island field it was made on (field missing or its hash differs)";
        case CP_STAGE_SNAP_ERR_HASH:return "snapshot is corrupt (state hash mismatch)";
        default:return "unknown snapshot error";
    }
}
int cp_stage_attach_field(CpStageWorld *w,const CpStageField *f){
    if(!w||(f&&!field_ok(f)))return -1;
    if(w->field!=f)path_clear(w);
    w->field=f;
    return 0;
}
