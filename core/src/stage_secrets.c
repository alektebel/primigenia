/* C2 secrets (docs/SECRETS-REPORT.md): the five meteor shards (W10, G68), the hidden cave chamber (G65, W18) and the
 * day/night clock (W8). Everything here is integer or + - * / only, derived from the setup and the island field at reset,
 * and folded into the world hash only when `setup.secrets` is on, so worlds that never ask for secrets keep their hashes.
 *
 * Shards. A coarse flood fill (8 m cells, gentle dry ground) from the nest gives the reachable land. The five shards lie
 * along one bent ray (the canon: "five shards along one bent ejecta ray", lore/worlds/primigenia.json F22) that leaves the
 * valley and ends toward where the crater will be: the k-th ideal point is further out and slightly rotated; each snaps to the
 * nearest reachable cell. The direction comes from the field hash, so a given island always has the same trail. The sites are
 * certified on foot by tests/test_routes.c with the real planner, for all nine bodies.
 *
 * Cave. The heightfield cannot hold a hollow, so the chamber is a region where the walkable ground is flat at the entrance
 * floor (cp_stage_secrets_ground): a corridor into the rock, then a round chamber. Rock outside the region keeps its steep
 * heights, so its walls block like cliffs. The planner, the gradient rule and the walk all read the same function. */
#include "cpore/world.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

const char *const CP_STAGE_SHARD_NAMES[CP_STAGE_SHARDS]={"Spark","Trail","Seed","Echo","Threshold"};
/* DRAFT lines for the owner (one each, English and Spanish). They follow the F22 canon: a second capsule fell here ~12,000 years
 * ago, the shards lie along one bent ejecta ray, the crater is at its end. */
const char *const CP_STAGE_SHARD_LINES_EN[CP_STAGE_SHARDS]={
    "A warm iron stone, humming faintly. It did not grow here. It fell, and it fell in a line.",
    "Its edge is glassy and bent, the way a thing melts when it arrives too fast. The line bends with it.",
    "Inside the metal runs a seam of tiny cells, long dead and still in order. A seed, thrown with the stone.",
    "The humming is a pattern, not a noise: counted, patient, repeating. Someone made this to be found.",
    "The stone is cold toward the crater and warm away from it. The second capsule is still there."
};
const char *const CP_STAGE_SHARD_LINES_ES[CP_STAGE_SHARDS]={
    "Una piedra de hierro, tibia, que zumba apenas. No nacio aqui. Cayo, y cayo en linea.",
    "Su borde es vitreo y torcido, como lo que se funde al llegar demasiado deprisa. La linea se curva con el.",
    "Dentro del metal corre una veta de celulas diminutas, muertas hace mucho y aun en orden. Una semilla lanzada con la piedra.",
    "El zumbido es un patron, no un ruido: contado, paciente, repetido. Alguien hizo esto para que lo encontraran.",
    "La piedra esta fria hacia el crater y tibia al otro lado. La segunda capsula sigue alli."
};

#define GRID_MAX 640
/* The shard search grid is 8 m cells (the ring island, bound 1.8 km). A bigger field (the Star massif, bound 3.99 km) widens the cell so the
 * grid still fits GRID_MAX; smaller fields are untouched. Set at the start of place_shards. */
static float g_cell=8.f;
#define CELL g_cell
#define PICKUP_RANGE 2.5f
static uint8_t g_ok[GRID_MAX*GRID_MAX],g_seen[GRID_MAX*GRID_MAX];
static int32_t g_queue[GRID_MAX*GRID_MAX];

static float fabs_(float x){return x<0?-x:x;}
static float clampf(float x,float a,float b){return x<a?a:x>b?b:x;}
static float len2(float x,float z){return sqrtf(x*x+z*z);}

/* --- the clock --- */
int cp_stage_daylight(const CpStageWorld *w){
    const int t=(int)(w->clock%CP_STAGE_DAY_TICKS);       /* 500 ticks per hour, 0 = midnight */
    if(t<2500)return 0;
    if(t<3500)return t-2500;                              /* dawn 05:00-07:00 */
    if(t<9000)return 1000;
    if(t<10000)return 10000-t;                            /* dusk 18:00-20:00 */
    return 0;
}
int cp_stage_creature_hidden(const CpStageWorld *w,int i){
    if(i<0||i>=w->setup.n||w->active==i)return 0;
    const CpStageCreature *e=&w->wild[i];
    return CP_STAGE_SPECIES[e->species].activity==CP_ACT_NOCTURNAL&&!e->dead&&cp_stage_daylight(w)>=500&&w->tick>=w->wake_until[i]&&
        (w->player.x-e->x)*(w->player.x-e->x)+(w->player.z-e->z)*(w->player.z-e->z)>CP_STAGE_WAKE_RADIUS*CP_STAGE_WAKE_RADIUS;
}
int cp_stage_creature_hunkered(const CpStageWorld *w,int i){
    if(i<0||i>=w->setup.n||w->active==i)return 0;
    const CpStageCreature *e=&w->wild[i];
    return CP_STAGE_SPECIES[e->species].activity==CP_ACT_CREPUSCULAR&&!e->dead&&cp_stage_daylight(w)>=900;
}

/* --- the cave --- */
static void frame(const CpStageSecrets *s,float x,float z,float *u,float *v){
    const float dx=x-s->cave_x,dz=z-s->cave_z;
    *u=-(dx*s->cave_fx+dz*s->cave_fz);        /* metres into the rock from the entrance plane */
    *v=-dx*s->cave_fz+dz*s->cave_fx;          /* sideways */
}
/* The floor profile along the passage: it keeps the trail's 0.30 slope for the last CAVE_LEAD m before the entrance plane (so the
 * surface blends into the graded apron instead of meeting the steep face), then it is flat. */
#define CAVE_LEAD 4.f
#define CAVE_BLEND 3.f
#define CAVE_TRAIL_SLOPE .30f
float cp_stage_secrets_ground(const CpStageWorld *w,float x,float z,float h){
    const CpStageSecrets *s=&w->secrets;
    if(!s->cave_on)return h;
    float u,v;
    frame(s,x,z,&u,&v);
    float k=0,floor_h=s->cave_floor;
    if(u>-CAVE_LEAD-CAVE_BLEND&&u<s->cave_length+s->cave_radius+.01f){
        const float wv=clampf((s->cave_half-fabs_(v))/.8f,0,1);
        const float wu=u<-CAVE_LEAD?(u+CAVE_LEAD+CAVE_BLEND)/CAVE_BLEND:1.f;
        k=wv*wu;
        if(u<0)floor_h+=CAVE_TRAIL_SLOPE*u;
    }
    {
        const float d=len2(x-s->chamber_x,z-s->chamber_z),wd=clampf((s->cave_radius-d)/.8f,0,1);
        if(wd>k){k=wd;floor_h=s->cave_floor;}
    }
    return k>0?h+(floor_h-h)*k:h;
}
int cp_stage_in_cave(const CpStageWorld *w,float x,float z){
    if(!w->secrets.cave_on)return 0;
    float u,v;
    frame(&w->secrets,x,z,&u,&v);
    const CpStageSecrets *s=&w->secrets;
    if(len2(x-s->chamber_x,z-s->chamber_z)<s->cave_radius)return 2;
    if(u>=0&&u<s->cave_length+s->cave_radius&&fabs_(v)<s->cave_half)return 1;
    return 0;
}

/* --- shard placement --- */
static int cell_of(const CpStageWorld *w,float v){
    return (int)floorf((v+cp_stage_bound(w))/CELL);
}
static float centre(const CpStageWorld *w,int i){
    return -cp_stage_bound(w)+((float)i+.5f)*CELL;
}
static int good_cell(const CpStageWorld *w,float x,float z){
    const float h=cp_stage_ground(w,x,z);
    if(h<1.5f||cp_stage_water_depth(w,x,z)>.3f)return 0;
    const float gx=(cp_stage_ground(w,x+4,z)-cp_stage_ground(w,x-4,z))/8,gz=(cp_stage_ground(w,x,z+4)-cp_stage_ground(w,x,z-4))/8;
    if(len2(gx,gz)>.42f)return 0;
    /* a body also needs a dry neighbourhood: no standing water within 6 m */
    static const float ring[8][2]={{6,0},{-6,0},{0,6},{0,-6},{4.2f,4.2f},{-4.2f,4.2f},{4.2f,-4.2f},{-4.2f,-4.2f}};
    for(int k=0;k<8;k++)if(cp_stage_water_depth(w,x+ring[k][0],z+ring[k][1])>.3f)return 0;
    return 1;
}
static uint32_t mix32(uint32_t a){
    a^=a>>16;a*=0x7feb352du;a^=a>>15;a*=0x846ca68bu;a^=a>>16;return a;
}
/* A site a two-legged body can also stand on and leave: fine slopes (0.25 m stencil, the one the planner holds bodies to) stay
 * gentle at the site and 2 m around it. */
static int site_ok(const CpStageWorld *w,float x,float z){
    static const float off[5][2]={{0,0},{2,0},{-2,0},{0,2},{0,-2}};
    for(int k=0;k<5;k++){
        const float px=x+off[k][0],pz=z+off[k][1];
        const float gx=(cp_stage_ground(w,px+.25f,pz)-cp_stage_ground(w,px-.25f,pz))*2,gz=(cp_stage_ground(w,px,pz+.25f)-cp_stage_ground(w,px,pz-.25f))*2;
        if(len2(gx,gz)>.30f)return 0;
    }
    return 1;
}
/* The planner takes a straight line whenever its centre line is gentle, and a big body (4 m, six or eight legs) swings wide of it: it
 * then walks onto the steep face that runs beside the line and stalls. A site whose straight line to the nest has a steep face within
 * 4 m of it is not a good shard site (the nest-star routes are certified for every body). */
static int shortcut_trap(const CpStageWorld *w,float x,float z){
    const float dx=x-w->setup.nest_x,dz=z-w->setup.nest_z,d=len2(dx,dz);
    if(d<1.f)return 0;
    const float px=-dz/d*4.f,pz=dx/d*4.f;
    const int steps=(int)(d/2.f)+1;
    for(int i=0;i<=steps;i++){
        const float t=(float)i/steps;
        for(int side=-1;side<=1;side+=2){
            const float cx=w->setup.nest_x+dx*t+px*side,cz=w->setup.nest_z+dz*t+pz*side;
            const float gx=(cp_stage_ground(w,cx+.25f,cz)-cp_stage_ground(w,cx-.25f,cz))*2,gz=(cp_stage_ground(w,cx,cz+.25f)-cp_stage_ground(w,cx,cz-.25f))*2;
            if(len2(gx,gz)>1.0f)return 1;
        }
    }
    return 0;
}
/* Nearest reachable cell to (tx,tz) within `reach` metres; -1 when none. Ties go to the lowest index (rings, then row-major). */
static int snap(const CpStageWorld *w,int dim,float tx,float tz,float reach,const float (*taken)[2],int n_taken){
    const int ci=cell_of(w,tx),cj=cell_of(w,tz),rmax=(int)(reach/CELL)+1;
    int best=-1;float bd=reach*reach+1;
    for(int dj=-rmax;dj<=rmax;dj++)for(int di=-rmax;di<=rmax;di++){
        const int i=ci+di,j=cj+dj;
        if(i<1||j<1||i>=dim-1||j>=dim-1||!g_ok[j*dim+i]||!g_seen[j*dim+i])continue;
        const float x=centre(w,i),z=centre(w,j),d=(x-tx)*(x-tx)+(z-tz)*(z-tz);
        if(d>=bd||!site_ok(w,x,z)||shortcut_trap(w,x,z))continue;
        int near=0;
        for(int k=0;k<n_taken;k++)if(len2(x-taken[k][0],z-taken[k][1])<70.f)near=1;
        if(near)continue;
        bd=d;best=j*dim+i;
    }
    return best;
}
static int place_shards(CpStageWorld *w){
    CpStageSecrets *s=&w->secrets;
    const float bound=cp_stage_bound(w);
    g_cell=8.f;
    if(2*bound/g_cell>(float)GRID_MAX)g_cell=2*bound/(float)GRID_MAX*1.0001f;
    int dim=(int)(2*bound/CELL);
    if(dim<8||dim>GRID_MAX)return -1;
    for(int j=0;j<dim;j++)for(int i=0;i<dim;i++)g_ok[j*dim+i]=(uint8_t)good_cell(w,centre(w,i),centre(w,j));
    memset(g_seen,0,(size_t)dim*dim);
    int start=-1;
    {
        const int ci=cell_of(w,w->setup.nest_x),cj=cell_of(w,w->setup.nest_z);
        float bd=1e30f;
        for(int dj=-4;dj<=4;dj++)for(int di=-4;di<=4;di++){
            const int i=ci+di,j=cj+dj;
            if(i<0||j<0||i>=dim||j>=dim||!g_ok[j*dim+i])continue;
            const float d=(float)(di*di+dj*dj);
            if(d<bd){bd=d;start=j*dim+i;}
        }
    }
    if(start<0)return -1;
    int head=0,tail=0;
    g_queue[tail++]=start;g_seen[start]=1;
    while(head<tail){
        const int c=g_queue[head++],ci=c%dim,cj=c/dim;
        for(int d=0;d<8;d++){
            static const int dx[8]={1,1,0,-1,-1,-1,0,1},dz[8]={0,1,1,1,0,-1,-1,-1};
            const int ni=ci+dx[d],nj=cj+dz[d];
            if(ni<0||nj<0||ni>=dim||nj>=dim)continue;
            const int n=nj*dim+ni;
            if(g_seen[n]||!g_ok[n])continue;
            const float run=(dx[d]&&dz[d])?CELL*1.4142f:CELL;
            const float dh=cp_stage_ground(w,centre(w,ni),centre(w,nj))-cp_stage_ground(w,centre(w,ci),centre(w,cj));
            if(fabs_(dh)>.42f*run)continue;
            g_seen[n]=1;g_queue[tail++]=n;
        }
    }
    static const float scales[5]={1.f,.85f,.7f,.55f,.4f};
    static const float radii[CP_STAGE_SHARDS+1]={110.f,330.f,650.f,1000.f,1400.f,1850.f};
    const uint32_t hash=mix32((uint32_t)w->field_hash^(uint32_t)(w->field_hash>>32));
    const int first=(int)(hash%16),bend=(hash>>8)&1?1:-1;
    for(int sc=0;sc<5;sc++)for(int dir=0;dir<16;dir++){
        /* no libm trig: the sixteen directions are a unit-vector table */
        static const float ux[16]={1.f,.92388f,.70711f,.38268f,0.f,-.38268f,-.70711f,-.92388f,-1.f,-.92388f,-.70711f,-.38268f,0.f,.38268f,.70711f,.92388f};
        static const float uz[16]={0.f,.38268f,.70711f,.92388f,1.f,.92388f,.70711f,.38268f,0.f,-.38268f,-.70711f,-.92388f,-1.f,-.92388f,-.70711f,-.38268f};
        float taken[CP_STAGE_SHARDS+1][2];
        int ok=1,last=-1;
        float lastd=0;
        for(int k=0;k<=CP_STAGE_SHARDS&&ok;k++){
            /* the bend rotates the direction by one sixteenth step every second shard (the ray curves, it is not straight) */
            const int step=((first+dir)%16+16+(bend>0?(k+1)/2:-((k+1)/2)))%16;
            const float r=radii[k]*scales[sc];
            const float tx=w->setup.nest_x+ux[step]*r,tz=w->setup.nest_z+uz[step]*r;
            const int c=snap(w,dim,tx,tz,k==CP_STAGE_SHARDS?160.f:90.f,(const float (*)[2])taken,k);
            if(c<0){ok=k==CP_STAGE_SHARDS;break;}   /* the crater end is optional */
            taken[k][0]=centre(w,c%dim);taken[k][1]=centre(w,c/dim);
            const float d=len2(taken[k][0]-w->setup.nest_x,taken[k][1]-w->setup.nest_z);
            if(d<=lastd||d<40.f){ok=k==CP_STAGE_SHARDS;break;}
            lastd=d;last=k;
        }
        if(last<CP_STAGE_SHARDS-1)continue;
        for(int k=0;k<CP_STAGE_SHARDS;k++){s->shard[k][0]=taken[k][0];s->shard[k][1]=taken[k][1];}
        if(last==CP_STAGE_SHARDS){s->crater_x=taken[CP_STAGE_SHARDS][0];s->crater_z=taken[CP_STAGE_SHARDS][1];}
        else{s->crater_x=s->shard[CP_STAGE_SHARDS-1][0];s->crater_z=s->shard[CP_STAGE_SHARDS-1][1];}
        s->n_shards=CP_STAGE_SHARDS;
        s->placed_scale=(int)(scales[sc]*100.f+.5f);
        return 0;
    }
    return -1;
}

static void event(CpStageWorld *w,int type,int target,int move,float value,float x,float z){
    w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,0,target,move,value,x,z};
    w->ev_total++;
}
static void dna(CpStageWorld *w,int amount,int source){
    w->social.dna_total+=amount;w->social.dna_balance+=amount;w->social.dna_by_source[source]+=amount;
    event(w,CP_STAGE_EV_DNA,0,source,(float)amount,(float)w->social.dna_total,(float)w->social.dna_balance);
    w->social.used=1;
}

void cp_stage_secrets_reset(CpStageWorld *w){
    CpStageSecrets *s=&w->secrets;
    memset(s,0,sizeof *s);
    w->clock=(uint32_t)(w->setup.start_clock<0?0:w->setup.start_clock)%CP_STAGE_DAY_TICKS;
    if(!w->setup.secrets||w->setup.terrain!=CP_STAGE_FIELD)return;
    const CpStageCave *c=&w->setup.cave;
    int have_cave=0;
    if((w->setup.secrets&CP_SECRETS_CAVE)&&c->on){
        have_cave=1;
        s->cave_x=c->x;s->cave_z=c->z;
        const float n=len2(c->fx,c->fz);
        s->cave_fx=n>0?c->fx/n:0;s->cave_fz=n>0?c->fz/n:1;
        s->cave_half=c->half>0?c->half:4.f;s->cave_length=c->length>0?c->length:14.f;s->cave_radius=c->radius>0?c->radius:10.f;
        /* the floor is the ground at the entrance plane; read before the override exists */
        s->cave_floor=cp_stage_ground(w,c->x,c->z);
        s->chamber_x=c->x-s->cave_fx*(s->cave_length+s->cave_radius);
        s->chamber_z=c->z-s->cave_fz*(s->cave_length+s->cave_radius);
    }
    if(w->setup.secrets&CP_SECRETS_SHARDS){
        /* shards are placed on the original heights, before the cave override can change any cell */
        if(!place_shards(w))s->on=1;
    }
    if(have_cave){
        s->cave_on=1;
        /* the fossil node inside the chamber: the extra slot after the eight random ones */
        if(w->parts.n_nodes<=CP_STAGE_PART_NODES){
            const int i=w->parts.n_nodes++;
            w->parts.nodes[i]=(CpStagePartNode){s->chamber_x-s->cave_fx*2.5f,s->chamber_z-s->cave_fz*2.5f,CP_PART_FOSSIL,0};
        }
    }
}

void cp_stage_secrets_step(CpStageWorld *w){
    CpStageSecrets *s=&w->secrets;
    if(!s->cave_on)return;
    const int where=cp_stage_in_cave(w,w->player.x,w->player.z);
    if(where>=1&&!s->cave_entered){
        s->cave_entered=1;
        event(w,CP_STAGE_EV_CAVE,0,1,0,w->player.x,w->player.z);
    }
    if(where==2&&!s->chamber_entered){
        s->chamber_entered=1;
        event(w,CP_STAGE_EV_CAVE,0,2,0,w->player.x,w->player.z);
        dna(w,5,CP_DNA_EXPLORE);
    }
}

int cp_stage_secrets_order(CpStageWorld *w,const CpStageInput *a,int *rc){
    CpStageSecrets *s=&w->secrets;
    if(!s->on||a->verb!=CP_STAGE_INSPECT||a->target<CP_STAGE_SHARD_ID||a->target>=CP_STAGE_SHARD_ID+CP_STAGE_SHARDS)return 0;
    const int k=a->target-CP_STAGE_SHARD_ID;
    if(w->active>=0||w->respawn_ticks||w->parts.lost){*rc=CP_STAGE_ERR_IN_FIGHT;return 1;}
    if(s->found_mask&(1<<k)){*rc=-2;return 1;}
    if(len2(w->player.x-s->shard[k][0],w->player.z-s->shard[k][1])>PICKUP_RANGE){*rc=-2;return 1;}
    s->found_mask|=1<<k;
    s->found++;
    event(w,CP_STAGE_EV_SHARD_FOUND,a->target,k,(float)s->found,s->shard[k][0],s->shard[k][1]);
    dna(w,5,CP_DNA_SHARD);
    if(s->found==CP_STAGE_SHARDS)dna(w,10,CP_DNA_SHARD);   /* the whole line: the story is complete */
    w->parts.used=1;
    w->hash=cp_stage_hash(w);
    *rc=0;
    return 1;
}

static void hu(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}}
uint64_t cp_stage_secrets_hash(const CpStageWorld *w){
    const CpStageSecrets *s=&w->secrets;
    uint64_t h=14695981039346656037ULL;
    hu(&h,0x53454352u);
    hu(&h,(uint32_t)s->found_mask);hu(&h,(uint32_t)s->found);hu(&h,(uint32_t)s->cave_entered);hu(&h,(uint32_t)s->chamber_entered);
    for(int k=0;k<CP_STAGE_SHARDS;k++){uint32_t b;memcpy(&b,&s->shard[k][0],4);hu(&h,b);memcpy(&b,&s->shard[k][1],4);hu(&h,b);}
    return h;
}

#define ADD(...) do{int r_=snprintf(out+n,cap>n?cap-n:0,__VA_ARGS__);if(r_<0||(size_t)r_>=cap-n)return -1;n+=(size_t)r_;}while(0)
int cp_stage_secrets_json(const CpStageWorld *w,char *out,size_t cap){
    const CpStageSecrets *s=&w->secrets;
    size_t n=0;
    const int light=cp_stage_daylight(w),t=(int)(w->clock%CP_STAGE_DAY_TICKS);
    const char *phase=t>=2500&&t<3500?"dawn":t>=9000&&t<10000?"dusk":light>=1000?"day":"night";
    ADD("{\"enabled\":%s,\"day\":{\"light\":%d,\"phase\":\"%s\",\"night\":%s,\"hour\":%.2f},",s->on?"true":"false",light,phase,light<500?"true":"false",(double)t/500.0);
    ADD("\"shards\":{\"total\":%d,\"found\":%d,\"mask\":%d,\"items\":[",s->on?CP_STAGE_SHARDS:0,s->found,s->found_mask);
    if(s->on)for(int k=0;k<CP_STAGE_SHARDS;k++){
        const int f=(s->found_mask>>k)&1;
        ADD("%s{\"id\":%d,\"index\":%d,\"name\":\"%s\",\"found\":%s,\"x\":%.3f,\"z\":%.3f",k?",":"",CP_STAGE_SHARD_ID+k,k,CP_STAGE_SHARD_NAMES[k],f?"true":"false",s->shard[k][0],s->shard[k][1]);
        if(f)ADD(",\"line\":\"%s\",\"line_es\":\"%s\"",CP_STAGE_SHARD_LINES_EN[k],CP_STAGE_SHARD_LINES_ES[k]);
        ADD("}");
    }
    ADD("],\"toward_crater\":{\"x\":%.1f,\"z\":%.1f}},",s->crater_x,s->crater_z);
    ADD("\"cave\":{\"enabled\":%s,\"entered\":%s,\"chamber_entered\":%s,\"inside\":%d,\"x\":%.3f,\"z\":%.3f,\"fx\":%.5f,\"fz\":%.5f,\"floor\":%.3f,\"half\":%.2f,\"length\":%.2f,\"radius\":%.2f,\"chamber_x\":%.3f,\"chamber_z\":%.3f}}",
        s->cave_on?"true":"false",s->cave_entered?"true":"false",s->chamber_entered?"true":"false",cp_stage_in_cave(w,w->player.x,w->player.z),
        s->cave_x,s->cave_z,s->cave_fx,s->cave_fz,s->cave_floor,s->cave_half,s->cave_length,s->cave_radius,s->chamber_x,s->chamber_z);
    return (int)n;
}
#undef ADD
