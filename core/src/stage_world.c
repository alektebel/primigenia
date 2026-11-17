#include "cpore/world.h"
#include "../../apps/combat_bots.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <stddef.h>
const CpStageSpecies CP_STAGE_SPECIES[4]={
    {
        "Rondo",4.4f,20,22,0,CP_STAGE_TIMID,{
            0,0,2,0,0,60,100,4.4f,0
        }
    },
    {
        "Zanco",5.2f,24,26,0,CP_STAGE_TIMID,{
            0,0,2,1,0,70,100,5.2f,0
        }
    },
    {
        "Espinodo",4,24,22,8,CP_STAGE_TERRITORIAL,{
            2,1,0,2,1,100,100,4,0
        }
    },
    {
        "Garfio",5.8f,28,24,28,CP_STAGE_AGGRESSIVE,{
            3,0,0,1,0,80,100,5.8f,0
        }
    }
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
    if(w->setup.terrain==CP_STAGE_FIELD)return field_ok(w->field)?field_ground(w->field,x,z):0;
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
static int profile_valid(const CpCombatProfile *p){
    return p->mouth<=5&&p->charge<=5&&p->spit<=5&&p->tail<=5&&p->guard<=5&&isfinite(p->hp)&&p->hp>=1&&p->hp<=100000&&isfinite(p->stamina)&&p->stamina>=1&&p->stamina<=100000&&isfinite(p->speed)&&p->speed>=.5f&&p->speed<=12&&(p->radius_cm==0||(p->radius_cm>=CB_RADIUS_CM_MIN&&p->radius_cm<=CB_RADIUS_CM_MAX));
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
        if(c->species<0||c->species>3||c->bot< -1||c->bot>=BOT_KIND_COUNT||!profile_valid(&c->profile)||!isfinite(c->x)||!isfinite(c->z)||!isfinite(c->home_x)||!isfinite(c->home_z)||ab(c->x)>bound||ab(c->z)>bound||ab(c->home_x)>bound||ab(c->home_z)>bound)return -1;
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
    w->active=-1;
    cp_rng_seed(&w->spawn_rng,copy.seed^0x53504157u);
    cp_rng_seed(&w->roam_rng,copy.seed^0x524f414du);
    seed_noise(w);
    creature(&w->player,copy.nest_x,copy.nest_z,-1,&copy.player);
    for(int i=0;i<copy.n;i++){
        const CpStageSpawn *c=&copy.wild[i];
        creature(&w->wild[i],c->x,c->z,c->species,&c->profile);
        w->wild[i].home_x=c->home_x;
        w->wild[i].home_z=c->home_z;
        w->wild[i].fz=-1;
        w->wild[i].roam_ticks=10+(int)(cp_rng_u32(&w->spawn_rng)%40);
    }
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
        s.c[i].prof=c[i]->profile;
        s.c[i].prof.hp=c[i]->hp;
        s.c[i].prof.stamina=c[i]->stamina;
        s.c[i].x=c[i]->x-w->arena_x+20;
        s.c[i].y=c[i]->z-w->arena_z+20;
        s.c[i].fx=c[1-i]->x-c[i]->x;
        s.c[i].fy=c[1-i]->z-c[i]->z;
        s.c[i].team=(uint8_t)i;
    }
    cp_combat_reset(&w->combat,&s);
    CpBot b;
    int kind=w->setup.wild[index].bot;
    if(kind<0)kind=CP_STAGE_SPECIES[e->species].temperament==CP_STAGE_TERRITORIAL?BOT_GREEDY:BOT_COUNTER;
    bot_init(&b,kind,w->setup.seed+1);
    bot_store(&w->bot,&b);
    w->active=index;
    w->started++;
    w->outcome=0;
}
const CpStageMotion CP_STAGE_MOTION={
    1.3f,1.7f,.6f,15.f,20.f,.6f,1.1f,1.5f,4.5f,11.8f,.3f,2.f,7.f,.4f
};
/* Stage locomotion (CP_STAGE_VERSION 2, PLAN-feel). Speed eases toward the wanted speed with an
 * acceleration and a braking cap; the yaw rate is limited by body size (turn0), by lateral grip at
 * speed, and by a slow pivot used only from near rest. Turn: rotate a unit vector by at most
 * `limit` radians with small-angle polynomials, so the angular speed is bounded and deterministic
 * (only + - * / and sqrtf, identical natively and in WASM). */
static void walk(CpStageWorld *w,CpStageCreature *c,float dx,float dz,float speed,float jog){
    const CpStageMotion *m=&w->motion;
    float n=length(dx,dz),ox=c->x,oz=c->z,old=c->speed,turn=0,r=cp_combat_body_radius(&c->profile);
    float dot=1,cross=0;
    if(n>.00001f){
        dx/=n;
        dz/=n;
        dot=c->fx*dx+c->fz*dz;
        cross=c->fz*dx-c->fx*dz;
    }
    float turn0=clamp(m->turn_k*sqrtf(9.81f/r),m->turn_min,m->turn_max),pivot_v=m->pivot_k*jog;
    if(n>.00001f&&!c->pivot&&dot<-.5f&&old<=pivot_v)c->pivot=1;
    if(c->pivot&&(dot>.5f||n<=.00001f))c->pivot=0;
    float wt=speed*clamp(n,0,1);
    if(c->pivot)wt=0;
    else if(n>.00001f&&dot>=0)wt*=(1-m->turn_slow)+m->turn_slow*dot;
    else if(n>.00001f)wt*=(1-m->turn_slow)*clamp(1+2*dot,0,1);  /* behind: plant and brake, continuous at 90 degrees */
    float dv=(wt-old)*m->ease;
    dv=clamp(dv,-m->brake*.1f,m->accel*.1f);
    float v=old+dv;
    if(v<.015f&&wt<.015f)v=0;
    if(n>.00001f){
        float rate=turn0;
        if(c->pivot)rate=clamp(m->pivot_mul*turn0,3,m->pivot_max);
        else if(v>.001f&&m->grip/v<rate)rate=m->grip/v;
        float limit=rate*.1f,co=1-limit*limit/2+limit*limit*limit*limit/24;
        if(dot>=co){
            turn=cross;
            c->fx=dx;
            c->fz=dz;
        }
        else {
            float si=limit-limit*limit*limit/6+limit*limit*limit*limit*limit/120;
            float sign=cross<0?-1:1;
            float fx=c->fx*co+c->fz*si*sign;
            c->fz=c->fz*co-c->fx*si*sign;
            c->fx=fx;
            turn=limit*sign;
        }
        float norm=length(c->fx,c->fz);
        c->fx/=norm;
        c->fz/=norm;
    }
    float slope=ab(cp_stage_ground(w,c->x+c->fx,c->z+c->fz)-cp_stage_ground(w,c->x,c->z));
    float step=v*.1f/(1+slope*.65f),nx=c->x+c->fx*step,nz=c->z+c->fz*step;
    if(cp_stage_can_walk(w,c->x,c->z,nx,nz,r)){
        c->x=nx;
        c->z=nz;
    }
    else {
        if(cp_stage_can_walk(w,c->x,c->z,nx,c->z,r))c->x=nx;
        if(cp_stage_can_walk(w,c->x,c->z,c->x,nz,r))c->z=nz;
    }
    c->speed=length(c->x-ox,c->z-oz)*10;
    c->acceleration=(c->speed-old)*10;
    c->turn_rate=turn*10;
}
int cp_stage_order(CpStageWorld *w,const CpStageInput *a){
    if(!w||!a||!isfinite(a->x)||!isfinite(a->z)||a->verb<0||a->verb>CP_STAGE_DODGE||a->sprint<0||a->sprint>1)return -1;
    if(a->verb==CP_STAGE_CONTINUE)return 0;
    if(a->verb==CP_STAGE_GO&&(!isfinite(a->x)||!isfinite(a->z)||ab(a->x)>cp_stage_bound(w)||ab(a->z)>cp_stage_bound(w)))return -1;
    if((a->verb==CP_STAGE_APPROACH||a->verb==CP_STAGE_ATTACK)&&(a->target<1||a->target>w->setup.n||w->wild[a->target-1].dead))return -2;
    if(a->verb==CP_STAGE_ATTACK&&(a->move<0||a->move>=CB_MOVE_COUNT||(CP_COMBAT_MOVES[a->move].flags&CB_F_SELF)||!cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[a->move].part)))return -3;
    if(a->verb==CP_STAGE_DODGE&&(a->dir<0||a->dir>7))return -1;
    if(a->verb==CP_STAGE_HEADING&&a->hx==0&&a->hz==0)return -1;
    if(w->active>=0&&(a->verb==CP_STAGE_ATTACK||a->verb==CP_STAGE_APPROACH)&&a->target!=w->active+1)return -2;
    w->order=*a;
    return 0;
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
    if(outcome==CP_STAGE_VICTORY)e->dead=1;
    else{
        e->returning=1;
        if(outcome==CP_STAGE_DEATH)w->respawn_ticks=20;
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
    w->last_error=cp_combat_order(&w->combat,0,&a);
    w->accepted[0]=w->last_error==0;
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
    cp_combat_step(&w->combat);
    CpStageCreature *entities[2]={
        &w->player,&w->wild[w->active]
    };
    for(int i=0;i<2;i++){
        CpStageCreature *e=entities[i];
        CpCombatCreature *c=&w->combat.c[i];
        float old=e->speed;
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
static void wild_tick(CpStageWorld *w,int skip,int engage){
    for(int i=0;i<w->setup.n;i++){
        CpStageCreature *e=&w->wild[i];
        if(e->dead||i==skip)continue;
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
            tx=e->goal_x;
            tz=e->goal_z;
        }
        float territory=s->temperament==CP_STAGE_TERRITORIAL?length(w->player.x-e->home_x,w->player.z-e->home_z):d;
        int hostile=s->temperament!=CP_STAGE_TIMID&&d<s->sight&&territory<s->hostile+cp_combat_body_radius(&e->profile)&&!w->cooldown_ticks;
        if(e->returning){
            tx=e->home_x;
            tz=e->home_z;
        }
        else if(hostile){
            tx=w->player.x;
            tz=w->player.z;
        }
        else if(s->temperament==CP_STAGE_TIMID&&d<s->sight*.5f){
            tx=e->x+(e->x-w->player.x);
            tz=e->z+(e->z-w->player.z);
        }
        float jog=e->profile.speed*w->motion.wild_k*w->motion.jog_k,espeed=jog;
        if(length(tx-e->x,tz-e->z)<.4f)espeed=0;
        walk(w,e,tx-e->x,tz-e->z,espeed,jog);
        if(e->returning&&length(e->x-e->home_x,e->z-e->home_z)<.6f)e->returning=0;
        int targeted=(w->order.verb==CP_STAGE_ATTACK&&w->order.target==i+1);
        if(engage&&w->active<0&&!e->returning&&!w->cooldown_ticks&&(hostile||targeted)&&dist(&w->player,e)<5.5f)start(w,i);
    }
}
uint64_t cp_stage_step(CpStageWorld *w,const CpStageInput *input){
    int skip=w->active,engage=w->active<0&&w->respawn_ticks==0;
    w->accepted[0]=w->accepted[1]=0;
    w->combat.n_ev=0;
    w->last_error=input?cp_stage_order(w,input):0;
    if(w->active>=0)fight(w);
    else if(w->respawn_ticks>0){
        if(--w->respawn_ticks==0){
            w->player.x=w->setup.nest_x;
            w->player.z=w->setup.nest_z;
            w->player.hp=w->player.profile.hp;
            w->player.stamina=w->player.profile.stamina;
            w->player.speed=0;
        }
    }
    else{
        CpStageInput *a=&w->order;
        float dx=0,dz=0,remaining=10000;
        if(a->verb==CP_STAGE_HEADING){
            dx=a->hx/32767.f;
            dz=a->hz/32767.f;
        }
        else if(a->verb==CP_STAGE_GO||a->verb==CP_STAGE_GO_NEST){
            dx=(a->verb==CP_STAGE_GO?a->x:w->setup.nest_x)-w->player.x;
            dz=(a->verb==CP_STAGE_GO?a->z:w->setup.nest_z)-w->player.z;
            remaining=length(dx,dz);
            if(remaining<.16f){
                w->order=(CpStageInput){
                    0
                };
                dx=dz=0;
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
        float jog=w->player.profile.speed*w->motion.jog_k,speed=sprint?jog*w->motion.sprint_k:jog,stop=sqrtf(clamp(remaining-.08f,0,10000)*12);
        if(stop<speed)speed=stop;
        walk(w,&w->player,dx,dz,speed,jog);
        w->player.stamina=clamp(w->player.stamina+(sprint?-1.4f:1),0,w->player.profile.stamina);
        if(w->cooldown_ticks>0)w->cooldown_ticks--;
    }
    wild_tick(w,skip,engage);
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
        for(unsigned i=0;i<sizeof w->motion/sizeof *m;i++)fl(&h,m[i]);
    }
    if(w->debug_flags)u32(&h,(uint32_t)w->debug_flags);
    if(s->terrain==CP_STAGE_FIELD){
        u32(&h,(uint32_t)w->field_hash);
        u32(&h,(uint32_t)(w->field_hash>>32));
    }
    return h;
}
int cp_stage_command(CpStageWorld *w,const char *text){
    CpStageInput a={
        0
    };
    char extra,move_name[32];
    float deg;
    if(!text)return -1;
    if(strcmp(text,"wait")==0)a.verb=CP_STAGE_WAIT;
    else if(strcmp(text,"go_nest")==0)a.verb=CP_STAGE_GO_NEST;
    else if(strcmp(text,"flee")==0)a.verb=CP_STAGE_FLEE;
    else if(sscanf(text,"go %f,%f %c",&a.x,&a.z,&extra)==2||sscanf(text,"go %f %f %c",&a.x,&a.z,&extra)==2)a.verb=CP_STAGE_GO;
    else if(sscanf(text,"approach #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_APPROACH;
    else if(sscanf(text,"attack #%d %31s %c",&a.target,move_name,&extra)==2){
        a.verb=CP_STAGE_ATTACK;
        a.move=-1;
        for(int i=0;i<CB_MOVE_COUNT;i++)if(strcmp(move_name,cp_combat_move_name(i))==0)a.move=i;
        if(a.move<0){
            char *end;
            long value=strtol(move_name,&end,10);
            if(*move_name&&!*end&&value>=0&&value<CB_MOVE_COUNT)a.move=(int)value;
        }
    }
    else if(sscanf(text,"heading %f %c",&deg,&extra)==1){
        if(!isfinite(deg)||ab(deg)>1000000)return -1;
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
    else return -1;
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
        default:return "invalid command or value";
    }
}
uint64_t cp_stage_replay(const CpStageSetup *setup,const CpStageLogEntry *log,int count,uint32_t ticks,uint64_t *hashes){
    if(count<0||(count&&!log))return 0;
    for(int i=0;i<count;i++)if(log[i].tick>=ticks||(i&&log[i].tick<log[i-1].tick))return 0;
    CpStageWorld replay;
    if(cp_stage_reset(&replay,setup))return 0;
    int cursor=0;
    for(uint32_t tick=0;tick<ticks;tick++){
        while(cursor<count&&log[cursor].tick==tick)cp_stage_order(&replay,&log[cursor++].input);
        uint64_t hash=cp_stage_step(&replay,NULL);
        if(hashes)hashes[tick]=hash;
    }
    return cp_stage_hash(&replay);
}
int cp_stage_observe(const CpStageWorld *w,char *out,size_t cap){
    if(!out||!cap)return -1;
    size_t used=0;
    int failed=0,comma=0;
#define ADD(...) append(out,cap,&used,&failed,__VA_ARGS__)
    ADD("{\"schema\":\"world-1\",\"tick\":%u,\"clock\":{\"tick\":%u,\"day_ticks\":%d},\"own\":{\"id\":0,\"x\":%.6f,\"z\":%.6f,\"hp\":%.6f,\"stamina\":%.6f,\"hp_max\":%.6f,\"stamina_max\":%.6f,\"speed\":%.6f,\"facing\":[%.6f,%.6f]},\"last_error\":\"%s\",\"nearby\":[",w->tick,w->clock,CP_STAGE_DAY_TICKS,w->player.x,w->player.z,w->player.hp,w->player.stamina,w->player.profile.hp,w->player.profile.stamina,w->player.speed,w->player.fx,w->player.fz,cp_stage_order_error(w->last_error));
    for(int i=0;i<w->setup.n;i++){
        const CpStageCreature *e=&w->wild[i];
        float d=dist(&w->player,e);
        if(d>40)continue;
        ADD("%s{\"id\":%d,\"type\":\"%s\",\"species\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",i+1,e->dead?"carcass":"creature",CP_STAGE_SPECIES[e->species].name,d,bearing(&w->player,e->x,e->z));
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
    ADD("],\"legal_verbs\":[\"go\",\"heading\",\"flee\",\"go_nest\",\"wait\"");
    int target=0,attacks=0;
    for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&(w->active<0||w->active==i))target=1;
    for(int i=0;i<CB_MOVE_COUNT;i++)if(!(CP_COMBAT_MOVES[i].flags&CB_F_SELF)&&cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[i].part)>0)attacks++;
    if(target)ADD(",\"approach\"");
    if(target&&attacks)ADD(",\"attack\"");
    ADD("],\"attack_moves\":[");
    comma=0;
    for(int i=0;i<CB_MOVE_COUNT;i++)if(!(CP_COMBAT_MOVES[i].flags&CB_F_SELF)&&cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[i].part)>0){
        ADD("%s{\"id\":%d,\"name\":\"%s\"}",comma?",":"",i,cp_combat_move_name(i));comma=1;
    }
    ADD("],\"summary\":\"Explore the valley; creature ids are stable.\"}");
#undef ADD
    return failed?-1:(int)used;
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
    LAY(CpStageWorld,debug_flags);LAY(CpStageWorld,reserved);LAY(CpStageWorld,field_hash);LAY(CpStageWorld,field);
    LAY(CpStageSetup,seed);LAY(CpStageSetup,terrain_seed);LAY(CpStageSetup,terrain);LAY(CpStageSetup,n);
    LAY(CpStageSetup,n_obstacles);LAY(CpStageSetup,nest_x);LAY(CpStageSetup,nest_z);LAY(CpStageSetup,flat_height);
    LAY(CpStageSetup,water_x);LAY(CpStageSetup,water_z);LAY(CpStageSetup,water_radius);LAY(CpStageSetup,player);
    LAY(CpStageSetup,wild);LAY(CpStageSetup,obstacles);
    LAY(CpStageCreature,x);LAY(CpStageCreature,z);LAY(CpStageCreature,fx);LAY(CpStageCreature,fz);
    LAY(CpStageCreature,hp);LAY(CpStageCreature,stamina);LAY(CpStageCreature,speed);LAY(CpStageCreature,acceleration);
    LAY(CpStageCreature,turn_rate);LAY(CpStageCreature,home_x);LAY(CpStageCreature,home_z);LAY(CpStageCreature,goal_x);
    LAY(CpStageCreature,goal_z);LAY(CpStageCreature,species);LAY(CpStageCreature,dead);LAY(CpStageCreature,pivot);
    LAY(CpStageCreature,returning);LAY(CpStageCreature,roam_ticks);LAY(CpStageCreature,profile);
    LAY(CpCombatWorld,rng);LAY(CpCombatWorld,seed);LAY(CpCombatWorld,tick);LAY(CpCombatWorld,n);LAY(CpCombatWorld,hill);
    LAY(CpCombatWorld,n_hills);LAY(CpCombatWorld,c);LAY(CpCombatWorld,ev);LAY(CpCombatWorld,n_ev);LAY(CpCombatWorld,hash);
    LAY(CpCombatCreature,alive);LAY(CpCombatCreature,medium);LAY(CpCombatCreature,team);LAY(CpCombatCreature,prof);
    LAY(CpCombatCreature,x);LAY(CpCombatCreature,y);LAY(CpCombatCreature,fx);LAY(CpCombatCreature,fy);
    LAY(CpCombatCreature,hp);LAY(CpCombatCreature,stamina);LAY(CpCombatCreature,move);LAY(CpCombatCreature,phase);
    LAY(CpCombatCreature,ptick);LAY(CpCombatCreature,plen);LAY(CpCombatCreature,hit_mask);LAY(CpCombatCreature,dash_x);
    LAY(CpCombatCreature,dash_y);LAY(CpCombatCreature,stun_t);LAY(CpCombatCreature,bleed_t);LAY(CpCombatCreature,slow_t);
    LAY(CpCombatCreature,since_spend);LAY(CpCombatCreature,bleed_src);LAY(CpCombatCreature,verb);
    LAY(CpCombatCreature,verb_move);LAY(CpCombatCreature,verb_started);LAY(CpCombatCreature,verb_target);
    LAY(CpCombatCreature,verb_dir);LAY(CpCombatCreature,verb_ticks);LAY(CpCombatCreature,heading_x);
    LAY(CpCombatCreature,heading_y);LAY(CpCombatCreature,dmg_dealt);LAY(CpCombatCreature,dmg_taken);
    LAY(CpCombatCreature,stamina_spent);LAY(CpCombatCreature,hits);LAY(CpCombatCreature,hits_taken);
    LAY(CpCombatCreature,blocked);LAY(CpCombatCreature,dodged);LAY(CpCombatCreature,interrupted);
    LAY(CpCombatCreature,kills);LAY(CpCombatCreature,died_tick);
    LAY(CpStageBot,rng);LAY(CpStageBot,kind);LAY(CpStageBot,spam_move);LAY(CpStageBot,delay);
    LAY(CpStageBot,reaction);LAY(CpStageBot,ranged_commit);LAY(CpStageBot,timer);
    LAY(CpStageMotion,jog_k);LAY(CpStageMotion,sprint_k);LAY(CpStageMotion,wild_k);LAY(CpStageMotion,accel);
    LAY(CpStageMotion,brake);LAY(CpStageMotion,ease);LAY(CpStageMotion,turn_k);LAY(CpStageMotion,turn_min);
    LAY(CpStageMotion,turn_max);LAY(CpStageMotion,grip);LAY(CpStageMotion,pivot_k);LAY(CpStageMotion,pivot_mul);
    LAY(CpStageMotion,pivot_max);LAY(CpStageMotion,turn_slow);
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
    w->field=f;
    return 0;
}
