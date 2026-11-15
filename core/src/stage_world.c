#include "cpore/world.h"
#include "../../apps/combat_bots.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>

const CpStageSpecies CP_STAGE_SPECIES[4]={
 {"Rondo",4.4f,20,22,0,CP_STAGE_TIMID,{0,0,2,0,0,60,100,4.4f,0}},
 {"Zanco",5.2f,24,26,0,CP_STAGE_TIMID,{0,0,2,1,0,70,100,5.2f,0}},
 {"Espinodo",4,24,22,8,CP_STAGE_TERRITORIAL,{2,1,0,2,1,100,100,4,0}},
 {"Garfio",5.8f,28,24,28,CP_STAGE_AGGRESSIVE,{3,0,0,1,0,80,100,5.8f,0}}
};
static float clamp(float x,float a,float b){return x<a?a:x>b?b:x;}
static float ab(float x){return x<0?-x:x;}
static float length(float x,float z){return sqrtf(x*x+z*z);}
static float dist(const CpStageCreature *a,const CpStageCreature *b){return length(a->x-b->x,a->z-b->z);}
static float mix(float a,float b,float t){return a+(b-a)*t;}
static int floor_int(float x){int i=(int)x;return x<i?i-1:i;}
/* exp(-x), range reduction + reciprocal Taylor; no libm transcendental. */
static float decay(float x){if(x>32)return 0;float v=x/32;
 float p=1+v*(1+v*(.5f+v*(1.0f/6+v*(1.0f/24+v/120))));
 p=1/p;for(int i=0;i<5;i++)p*=p;return p;}
static uint32_t mulberry(uint32_t *a){*a+=0x6D2B79F5u;uint32_t t=(*a^(*a>>15))*(1u|*a);t^=t+(t^(t>>7))*(61u|t);return t^(t>>14);}
static void seed_noise(CpStageWorld *w){uint32_t a=w->setup.terrain_seed*7919u+13;uint8_t p[256];
 for(int i=0;i<256;i++)p[i]=(uint8_t)i;
 for(int i=255;i>0;i--){int j=(int)((double)mulberry(&a)/4294967296.0*(i+1));uint8_t t=p[i];p[i]=p[j];p[j]=t;}
 for(int i=0;i<512;i++)w->noise[i]=p[i&255];}
static float noise(const CpStageWorld *w,float x,float z){int ix=floor_int(x),iz=floor_int(z);float u=x-ix,v=z-iz;
 u=u*u*(3-2*u);v=v*v*(3-2*v);
 float a=w->noise[w->noise[ix&255]+(iz&255)]/255.f,b=w->noise[w->noise[(ix+1)&255]+(iz&255)]/255.f;
 float c=w->noise[w->noise[ix&255]+((iz+1)&255)]/255.f,d=w->noise[w->noise[(ix+1)&255]+((iz+1)&255)]/255.f;
 return mix(mix(a,b,u),mix(c,d,u),v);}
static float fbm(const CpStageWorld *w,float x,float z,int n){float a=.5f,f=1,s=0,total=0;
 for(int i=0;i<n;i++){s+=a*noise(w,x*f,z*f);total+=a;a*=.5f;f*=2.03f;}return s/total;}
float cp_stage_height(const CpStageWorld *w,float x,float z){
 if(!isfinite(x)||!isfinite(z)||ab(x)>100000||ab(z)>100000)return 0;
 if(w->setup.terrain==CP_STAGE_FLAT){float d=length(x-w->setup.water_x,z-w->setup.water_z);return d<w->setup.water_radius?-1:w->setup.flat_height;}
 float d=length(x,z),h=(fbm(w,x*.006f+10,z*.006f+10,4)-.5f)*30+4;
 float c=decay(d*d/1600)*.8f;h=h*(1-c)+3*c;
 float lx=x-70,lz=z+55;h-=12*decay((lx*lx+lz*lz)/1500);
 float m=clamp((d/320-.42f)/.48f,0,1);m=m*m*(3-2*m);
 float rid=1-ab(fbm(w,x*.004f+50,z*.004f+50,5)*2-1);
 return h+m*(25+rid*rid*150)+m*m*30;
}
/* Same 256x256 triangular surface used by the stage mesh. W11 replaces this
 * interface without changing movement or perception. */
float cp_stage_ground(const CpStageWorld *w,float x,float z){
 if(w->setup.terrain==CP_STAGE_FLAT)return cp_stage_height(w,x,z);
 float fx=clamp((x+320)/2.5f,0,255.999f),fz=clamp((z+320)/2.5f,0,255.999f);
 int ix=(int)fx,iz=(int)fz;float u=fx-ix,v=fz-iz,px=ix*2.5f-320,pz=iz*2.5f-320;
 float a=cp_stage_height(w,px,pz),b=cp_stage_height(w,px,pz+2.5f),c=cp_stage_height(w,px+2.5f,pz+2.5f),d=cp_stage_height(w,px+2.5f,pz);
 return u+v<=1?a+u*(d-a)+v*(b-a):c+(1-u)*(b-c)+(1-v)*(d-c);
}
int cp_stage_can_walk(const CpStageWorld *w,float x,float z,float nx,float nz,float r){
 if(ab(nx)>195||ab(nz)>195||cp_stage_ground(w,nx,nz)<-.7f)return 0;
 if(ab(cp_stage_ground(w,nx,nz)-cp_stage_ground(w,x,z))>length(nx-x,nz-z)*1.2f+.04f)return 0;
 for(int i=0;i<w->setup.n_obstacles;i++){const CpStageObstacle *o=&w->setup.obstacles[i];if(length(nx-o->x,nz-o->z)<o->r+r)return 0;}return 1;
}
static int profile_valid(const CpCombatProfile *p){return p->mouth<=5&&p->charge<=5&&p->spit<=5&&p->tail<=5&&p->guard<=5&&isfinite(p->hp)&&p->hp>0&&p->hp<=1000000&&isfinite(p->stamina)&&p->stamina>0&&p->stamina<=1000000&&isfinite(p->speed)&&p->speed>0&&p->speed<=30;}
void cp_stage_setup_default(CpStageSetup *s,uint32_t seed){memset(s,0,sizeof *s);s->seed=seed;s->terrain_seed=7;s->flat_height=2;s->n=1;cp_combat_profile_default(&s->player);
 s->wild[0]=(CpStageSpawn){0,18,0,18,3,2,{2,1,0,1,0,100,100,4,0}};}
static void creature(CpStageCreature *c,float x,float z,int species,const CpCombatProfile *p){memset(c,0,sizeof *c);c->x=c->home_x=c->goal_x=x;c->z=c->home_z=c->goal_z=z;c->fz=1;c->profile=*p;c->hp=p->hp;c->stamina=p->stamina;c->species=species;}
int cp_stage_reset(CpStageWorld *w,const CpStageSetup *s){
 if(!w||!s||s->n<0||s->n>CP_STAGE_MAX_WILD||s->n_obstacles<0||s->n_obstacles>CP_STAGE_MAX_OBSTACLES||s->terrain<0||s->terrain>CP_STAGE_FLAT||!profile_valid(&s->player))return -1;
 const float values[]={s->nest_x,s->nest_z,s->flat_height,s->water_x,s->water_z,s->water_radius};
 for(unsigned i=0;i<sizeof values/sizeof *values;i++)if(!isfinite(values[i])||ab(values[i])>10000)return -1;
 if(s->water_radius<0)return -1;
 for(int i=0;i<s->n;i++){const CpStageSpawn *c=&s->wild[i];if(c->species<0||c->species>3||c->bot< -1||c->bot>=BOT_KIND_COUNT||!profile_valid(&c->profile)||!isfinite(c->x)||!isfinite(c->z)||!isfinite(c->home_x)||!isfinite(c->home_z)||ab(c->x)>195||ab(c->z)>195||ab(c->home_x)>195||ab(c->home_z)>195)return -1;}
 for(int i=0;i<s->n_obstacles;i++){const CpStageObstacle *o=&s->obstacles[i];if(!isfinite(o->x)||!isfinite(o->z)||!isfinite(o->r)||o->r<0||o->r>1000)return -1;}
 /* Copy first so resetting from &world.setup is supported. */
 CpStageSetup copy=*s;memset(w,0,sizeof *w);w->setup=copy;w->active=-1;
 cp_rng_seed(&w->spawn_rng,copy.seed^0x53504157u);cp_rng_seed(&w->roam_rng,copy.seed^0x524f414du);seed_noise(w);
 creature(&w->player,copy.nest_x,copy.nest_z,-1,&copy.player);
 for(int i=0;i<copy.n;i++){const CpStageSpawn *c=&copy.wild[i];creature(&w->wild[i],c->x,c->z,c->species,&c->profile);w->wild[i].home_x=c->home_x;w->wild[i].home_z=c->home_z;w->wild[i].fz=-1;w->wild[i].roam_ticks=10+(int)(cp_rng_u32(&w->spawn_rng)%40);}
 w->hash=cp_stage_hash(w);return 0;
}
static void bot_store(CpStageBot *s,const CpBot *b){s->rng=b->rng;s->kind=b->kind;s->spam_move=b->spam_move;s->delay=b->delay;s->reaction=b->reaction;s->ranged_commit=b->ranged_commit;s->timer=b->timer;}
static CpBot bot_load(const CpStageBot *s){CpBot b={0};b.rng=s->rng;b.kind=s->kind;b.spam_move=s->spam_move;b.delay=s->delay;b.reaction=s->reaction;b.ranged_commit=s->ranged_commit;b.timer=s->timer;return b;}
static void start(CpStageWorld *w,int index){CpStageCreature *e=&w->wild[index],*p=&w->player;w->arena_x=(p->x+e->x)/2;w->arena_z=(p->z+e->z)/2;
 CpCombatSetup s={0};s.seed=w->setup.seed;s.n=2;s.flat=1;
 CpStageCreature *c[2]={p,e};for(int i=0;i<2;i++){s.c[i].prof=c[i]->profile;s.c[i].prof.hp=c[i]->hp;s.c[i].prof.stamina=c[i]->stamina;s.c[i].x=c[i]->x-w->arena_x+20;s.c[i].y=c[i]->z-w->arena_z+20;s.c[i].fx=c[1-i]->x-c[i]->x;s.c[i].fy=c[1-i]->z-c[i]->z;s.c[i].team=(uint8_t)i;}
 cp_combat_reset(&w->combat,&s);CpBot b;int kind=w->setup.wild[index].bot;
 if(kind<0)kind=CP_STAGE_SPECIES[e->species].temperament==CP_STAGE_TERRITORIAL?BOT_GREEDY:BOT_COUNTER;
 bot_init(&b,kind,w->setup.seed+1);bot_store(&w->bot,&b);w->active=index;w->started++;w->outcome=0;
}
/* Polynomial turn: rotate a unit vector by at most .38 radians (.9 while
 * pivoting). Small-angle sin/cos give a bounded deterministic angular speed. */
static void walk(CpStageWorld *w,CpStageCreature *c,float dx,float dz,float speed){float n=length(dx,dz),ox=c->x,oz=c->z,old=c->speed,turn=0;
 if(n>.00001f){dx/=n;dz/=n;float dot=c->fx*dx+c->fz*dz,cross=c->fz*dx-c->fx*dz;
 if(dot<-.5f)c->pivot=1;
 if(c->pivot&&dot>.98f)c->pivot=0;
 float limit=c->pivot?.9f:.38f,co=1-limit*limit/2+limit*limit*limit*limit/24;
 if(dot>=co){turn=cross;c->fx=dx;c->fz=dz;}else {float si=limit-limit*limit*limit/6+limit*limit*limit*limit*limit/120;float sign=cross<0?-1:1;float fx=c->fx*co+c->fz*si*sign;c->fz=c->fz*co-c->fx*si*sign;c->fx=fx;turn=limit*sign;}
 float norm=length(c->fx,c->fz);c->fx/=norm;c->fz/=norm;}
 float wanted=c->pivot?0:speed*clamp(n,0,1),v=old+(wanted-old)*(wanted>old?.45118836f:.63212055f);if(v<.015f)v=0;
 float slope=ab(cp_stage_ground(w,c->x+c->fx,c->z+c->fz)-cp_stage_ground(w,c->x,c->z));float step=v*.1f/(1+slope*.65f),nx=c->x+c->fx*step,nz=c->z+c->fz*step;
 float r=cp_combat_body_radius(&c->profile);
 if(cp_stage_can_walk(w,c->x,c->z,nx,nz,r)){c->x=nx;c->z=nz;}else {if(cp_stage_can_walk(w,c->x,c->z,nx,c->z,r))c->x=nx;if(cp_stage_can_walk(w,c->x,c->z,c->x,nz,r))c->z=nz;}
 c->speed=length(c->x-ox,c->z-oz)*10;c->acceleration=(c->speed-old)*10;c->turn_rate=turn*10;
}
int cp_stage_order(CpStageWorld *w,const CpStageInput *a){if(!w||!a||a->verb<0||a->verb>CP_STAGE_DODGE||a->sprint<0||a->sprint>1)return -1;
 if(a->verb==CP_STAGE_CONTINUE)return 0;
 if(a->verb==CP_STAGE_GO&&(!isfinite(a->x)||!isfinite(a->z)||ab(a->x)>195||ab(a->z)>195))return -1;
 if((a->verb==CP_STAGE_APPROACH||a->verb==CP_STAGE_ATTACK)&&(a->target<1||a->target>w->setup.n||w->wild[a->target-1].dead))return -2;
 if(a->verb==CP_STAGE_ATTACK&&(a->move<0||a->move>=CB_MOVE_COUNT||(CP_COMBAT_MOVES[a->move].flags&CB_F_SELF)||!cp_combat_part_level(&w->player.profile,CP_COMBAT_MOVES[a->move].part)))return -3;
 if(a->verb==CP_STAGE_DODGE&&(a->dir<0||a->dir>7))return -1;
 if(a->verb==CP_STAGE_HEADING&&a->hx==0&&a->hz==0)return -1;
 if(w->active>=0&&(a->verb==CP_STAGE_ATTACK||a->verb==CP_STAGE_APPROACH)&&a->target!=w->active+1)return -2;
 w->order=*a;return 0;}
static void finish(CpStageWorld *w,int outcome){CpStageCreature *e=&w->wild[w->active];w->outcome=outcome;w->active=-1;w->cooldown_ticks=80;w->order=(CpStageInput){0};w->player.speed=e->speed=0;
 if(outcome==CP_STAGE_VICTORY)e->dead=1;else{e->returning=1;if(outcome==CP_STAGE_DEATH)w->respawn_ticks=20;}}
static void fight(CpStageWorld *w){CpStageInput *in=&w->order;CpCombatAction a={0};a.target=1;
 switch(in->verb){case CP_STAGE_ATTACK:a.verb=CB_V_ATTACK;a.move=(int8_t)in->move;break;
 case CP_STAGE_GUARD:a.verb=CB_V_GUARD;break;case CP_STAGE_DODGE:a.verb=CB_V_DODGE;a.dir=(int8_t)in->dir;break;
 case CP_STAGE_FLEE:a.verb=CB_V_FLEE;break;
 case CP_STAGE_APPROACH:a.verb=CB_V_APPROACH;break;
 case CP_STAGE_GO:case CP_STAGE_GO_NEST:case CP_STAGE_HEADING:{float dx=in->hx,dz=in->hz;
 if(in->verb!=CP_STAGE_HEADING){float x=in->verb==CP_STAGE_GO?in->x:w->setup.nest_x,z=in->verb==CP_STAGE_GO?in->z:w->setup.nest_z;dx=x-w->player.x;dz=z-w->player.z;if(length(dx,dz)<.16f){w->order=(CpStageInput){0};break;}float scale=ab(dx)>ab(dz)?ab(dx):ab(dz);dx=dx/scale*32767;dz=dz/scale*32767;}
 a.verb=CB_V_MOVE;a.dir=-1;a.heading_x=(int16_t)dx;a.heading_y=(int16_t)dz;
 if(in->sprint&&dist(&w->player,&w->wild[w->active])<15.2f)a.verb=CB_V_FLEE;
 break;}
 default:break;}
 w->last_error=cp_combat_order(&w->combat,0,&a);w->accepted[0]=w->last_error==0;w->combat_orders[0]=a;
 CpBot b=bot_load(&w->bot);CpCombatAction enemy={0};
 if(CP_STAGE_SPECIES[w->wild[w->active].species].temperament==CP_STAGE_TIMID&&w->combat.c[1].hp<w->wild[w->active].profile.hp*.5f){enemy.verb=CB_V_FLEE;enemy.target=0;w->accepted[1]=1;}else w->accepted[1]=bot_decide(&b,&w->combat,1,0,&enemy);
 bot_store(&w->bot,&b);if(w->accepted[1]){w->accepted[1]=cp_combat_order(&w->combat,1,&enemy)==0;w->combat_orders[1]=enemy;}
 cp_combat_step(&w->combat);
 CpStageCreature *entities[2]={&w->player,&w->wild[w->active]};
 for(int i=0;i<2;i++){CpStageCreature *e=entities[i];CpCombatCreature *c=&w->combat.c[i];float old=e->speed;e->speed=length(w->arena_x+c->x-20-e->x,w->arena_z+c->y-20-e->z)*10;e->acceleration=(e->speed-old)*10;e->turn_rate=(e->fz*c->fx-e->fx*c->fy)*10;e->x=w->arena_x+c->x-20;e->z=w->arena_z+c->y-20;e->fx=c->fx;e->fz=c->fy;e->hp=c->hp;e->stamina=c->stamina;}
 if(!w->combat.c[0].alive)finish(w,CP_STAGE_DEATH);else if(!w->combat.c[1].alive)finish(w,CP_STAGE_VICTORY);
 else{const CpCombatCreature *p=&w->combat.c[0];float edge=p->x;if(p->y<edge)edge=p->y;if(40-p->x<edge)edge=40-p->x;if(40-p->y<edge)edge=40-p->y;if(edge<cp_combat_body_radius(&w->player.profile)+.25f&&dist(entities[0],entities[1])>8)finish(w,CP_STAGE_FLED);}
}
uint64_t cp_stage_step(CpStageWorld *w,const CpStageInput *input){w->accepted[0]=w->accepted[1]=0;w->combat.n_ev=0;w->last_error=input?cp_stage_order(w,input):0;
 if(w->active>=0)fight(w);
 else if(w->respawn_ticks>0){if(--w->respawn_ticks==0){w->player.x=w->setup.nest_x;w->player.z=w->setup.nest_z;w->player.hp=w->player.profile.hp;w->player.stamina=w->player.profile.stamina;w->player.speed=0;}}
 else{CpStageInput *a=&w->order;float dx=0,dz=0,remaining=10000;
 if(a->verb==CP_STAGE_HEADING){dx=a->hx/32767.f;dz=a->hz/32767.f;}
 else if(a->verb==CP_STAGE_GO||a->verb==CP_STAGE_GO_NEST){dx=(a->verb==CP_STAGE_GO?a->x:w->setup.nest_x)-w->player.x;dz=(a->verb==CP_STAGE_GO?a->z:w->setup.nest_z)-w->player.z;remaining=length(dx,dz);if(remaining<.16f){w->order=(CpStageInput){0};dx=dz=0;}}
 else if(a->verb==CP_STAGE_ATTACK||a->verb==CP_STAGE_APPROACH){CpStageCreature *t=&w->wild[a->target-1];if(t->dead)w->order=(CpStageInput){0};else{dx=t->x-w->player.x;dz=t->z-w->player.z;remaining=length(dx,dz);if(a->verb==CP_STAGE_APPROACH&&remaining<cp_combat_body_radius(&t->profile)+cp_combat_body_radius(&w->player.profile)+CB_APPROACH_GAP){dx=dz=0;w->order=(CpStageInput){0};}}}
 else if(a->verb==CP_STAGE_FLEE){int nearest=-1;float d=100000;for(int i=0;i<w->setup.n;i++)if(!w->wild[i].dead&&dist(&w->player,&w->wild[i])<d){nearest=i;d=dist(&w->player,&w->wild[i]);}if(nearest>=0&&d<30){dx=w->player.x-w->wild[nearest].x;dz=w->player.z-w->wild[nearest].z;}}
 int sprint=(a->sprint||a->verb==CP_STAGE_FLEE)&&length(dx,dz)>0&&w->player.stamina>2;
 float speed=w->player.profile.speed*(sprint?1.7f:1),stop=sqrtf(clamp(remaining-.08f,0,10000)*12);if(stop<speed)speed=stop;walk(w,&w->player,dx,dz,speed);
 w->player.stamina=clamp(w->player.stamina+(sprint?-1.4f:1),0,w->player.profile.stamina);if(w->cooldown_ticks>0)w->cooldown_ticks--;
 for(int i=0;i<w->setup.n;i++){CpStageCreature *e=&w->wild[i];if(e->dead)continue;const CpStageSpecies *s=&CP_STAGE_SPECIES[e->species];float d=dist(e,&w->player),tx=e->goal_x,tz=e->goal_z;
 if(--e->roam_ticks<=0){/* Exactly three draws for every roam decision, even while reacting. */float rx=cp_rng_f(&w->roam_rng)*2-1,rz=cp_rng_f(&w->roam_rng)*2-1;uint32_t duration=cp_rng_u32(&w->roam_rng);float n=length(rx,rz);if(n>1){rx/=n;rz/=n;}e->goal_x=e->home_x+rx*s->roam;e->goal_z=e->home_z+rz*s->roam;e->roam_ticks=40+(int)(duration%61);tx=e->goal_x;tz=e->goal_z;}
 int hostile=d<s->sight&&d<s->hostile+cp_combat_body_radius(&e->profile)&&!w->cooldown_ticks;
 if(e->returning){tx=e->home_x;tz=e->home_z;}else if(hostile){tx=w->player.x;tz=w->player.z;}else if(s->temperament==CP_STAGE_TIMID&&d<s->sight*.5f){tx=e->x+(e->x-w->player.x);tz=e->z+(e->z-w->player.z);}
 float espeed=e->profile.speed*.7f;if(length(tx-e->x,tz-e->z)<.4f)espeed=0;
 walk(w,e,tx-e->x,tz-e->z,espeed);
 if(e->returning&&length(e->x-e->home_x,e->z-e->home_z)<.6f)e->returning=0;
 int targeted=(a->verb==CP_STAGE_ATTACK&&a->target==i+1);
 if(w->active<0&&!e->returning&&!w->cooldown_ticks&&(hostile||targeted)&&dist(&w->player,e)<5.5f)start(w,i);
 }
 }
 w->tick++;w->clock=(w->clock+1)%CP_STAGE_DAY_TICKS;return w->hash=cp_stage_hash(w);
}
/* Canonical FNV-1a, explicit LE fields, signed-zero canonicalisation. */
static void u32(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}}
static void fl(uint64_t *h,float v){uint32_t bits=0;if(v!=0)memcpy(&bits,&v,4);u32(h,bits);}
static void prof(uint64_t *h,const CpCombatProfile *p){u32(h,p->mouth);u32(h,p->charge);u32(h,p->spit);u32(h,p->tail);u32(h,p->guard);fl(h,p->hp);fl(h,p->stamina);fl(h,p->speed);u32(h,p->radius_cm);}
static void ent(uint64_t *h,const CpStageCreature *c){
 fl(h,c->x);fl(h,c->z);fl(h,c->fx);fl(h,c->fz);fl(h,c->hp);fl(h,c->stamina);fl(h,c->speed);fl(h,c->acceleration);fl(h,c->turn_rate);fl(h,c->home_x);fl(h,c->home_z);fl(h,c->goal_x);fl(h,c->goal_z);u32(h,c->species);u32(h,c->dead);u32(h,c->pivot);u32(h,c->returning);u32(h,c->roam_ticks);prof(h,&c->profile);}
uint64_t cp_stage_hash(const CpStageWorld *w){uint64_t h=14695981039346656037ULL;const CpStageSetup *s=&w->setup;
 u32(&h,CP_STAGE_VERSION);u32(&h,s->seed);u32(&h,s->terrain_seed);u32(&h,s->terrain);u32(&h,s->n);u32(&h,s->n_obstacles);fl(&h,s->nest_x);fl(&h,s->nest_z);fl(&h,s->flat_height);fl(&h,s->water_x);fl(&h,s->water_z);fl(&h,s->water_radius);prof(&h,&s->player);
 for(int i=0;i<s->n;i++){const CpStageSpawn *c=&s->wild[i];fl(&h,c->x);fl(&h,c->z);fl(&h,c->home_x);fl(&h,c->home_z);u32(&h,c->species);u32(&h,c->bot);prof(&h,&c->profile);}
 for(int i=0;i<s->n_obstacles;i++){fl(&h,s->obstacles[i].x);fl(&h,s->obstacles[i].z);fl(&h,s->obstacles[i].r);u32(&h,s->obstacles[i].type);}
 u32(&h,w->tick);u32(&h,w->clock);for(int i=0;i<4;i++){u32(&h,w->spawn_rng.s[i]);u32(&h,w->roam_rng.s[i]);u32(&h,w->bot.rng.s[i]);}
 ent(&h,&w->player);for(int i=0;i<s->n;i++)ent(&h,&w->wild[i]);
 u32(&h,w->order.verb);u32(&h,w->order.target);u32(&h,w->order.move);u32(&h,w->order.dir);u32(&h,w->order.sprint);u32(&h,(uint16_t)w->order.hx);u32(&h,(uint16_t)w->order.hz);fl(&h,w->order.x);fl(&h,w->order.z);
 u32(&h,w->active);u32(&h,w->started);u32(&h,w->outcome);u32(&h,w->respawn_ticks);u32(&h,w->cooldown_ticks);fl(&h,w->arena_x);fl(&h,w->arena_z);
 u32(&h,w->bot.kind);u32(&h,w->bot.spam_move);u32(&h,w->bot.delay);u32(&h,w->bot.reaction);u32(&h,w->bot.ranged_commit);u32(&h,w->bot.timer);
 if(w->started){uint64_t combat=cp_combat_hash(&w->combat);u32(&h,(uint32_t)combat);u32(&h,(uint32_t)(combat>>32));}return h;
}
int cp_stage_command(CpStageWorld *w,const char *text){CpStageInput a={0};char extra;int deg;
 if(!text)return -1;
 if(strcmp(text,"wait")==0)a.verb=CP_STAGE_WAIT;
 else if(strcmp(text,"go_nest")==0)a.verb=CP_STAGE_GO_NEST;
 else if(strcmp(text,"flee")==0)a.verb=CP_STAGE_FLEE;
 else if(sscanf(text,"go %f,%f %c",&a.x,&a.z,&extra)==2||sscanf(text,"go %f %f %c",&a.x,&a.z,&extra)==2)a.verb=CP_STAGE_GO;
 else if(sscanf(text,"approach #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_APPROACH;
 else if(sscanf(text,"attack #%d %d %c",&a.target,&a.move,&extra)==2)a.verb=CP_STAGE_ATTACK;
 else if(sscanf(text,"heading %d %c",&deg,&extra)==1){/* rational circle, integer degrees; 0 = +z */
 deg=((deg%360)+360)%360;int quadrant=deg/90;float t=(deg%90)/90.f;
 float x=t*(2-t),z=1-t*t;float n=length(x,z);x/=n;z/=n;
 if(quadrant==1){float q=x;x=z;z=-q;}else if(quadrant==2){x=-x;z=-z;}else if(quadrant==3){float q=x;x=-z;z=q;}
 a.verb=CP_STAGE_HEADING;a.hx=(int16_t)(x*32767);a.hz=(int16_t)(z*32767);
 }else return -1;return cp_stage_order(w,&a);}
/* JSON formatting is observation only: atan2 is never used by state updates. */
static void append(char *out,size_t cap,size_t *used,int *failed,const char *fmt,...){if(*failed)return;va_list args;va_start(args,fmt);int n=vsnprintf(out+*used,cap-*used,fmt,args);va_end(args);if(n<0||(size_t)n>=cap-*used){*failed=1;return;}*used+=(size_t)n;}
static float bearing(const CpStageCreature *p,float x,float z){return atan2f(p->fz*(x-p->x)-p->fx*(z-p->z),p->fx*(x-p->x)+p->fz*(z-p->z))*57.2957795f;}
int cp_stage_observe(const CpStageWorld *w,char *out,size_t cap){if(!out||!cap)return -1;size_t used=0;int failed=0,comma=0;
#define ADD(...) append(out,cap,&used,&failed,__VA_ARGS__)
 ADD("{\"schema\":\"world-1\",\"tick\":%u,\"clock\":{\"tick\":%u,\"day_ticks\":%d},\"own\":{\"id\":0,\"x\":%.6f,\"z\":%.6f,\"hp\":%.6f,\"stamina\":%.6f},\"nearby\":[",w->tick,w->clock,CP_STAGE_DAY_TICKS,w->player.x,w->player.z,w->player.hp,w->player.stamina);
 for(int i=0;i<w->setup.n;i++){const CpStageCreature *e=&w->wild[i];float d=dist(&w->player,e);if(d>40)continue;ADD("%s{\"id\":%d,\"type\":\"%s\",\"species\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",i+1,e->dead?"carcass":"creature",CP_STAGE_SPECIES[e->species].name,d,bearing(&w->player,e->x,e->z));comma=1;}
 float d=length(w->setup.nest_x-w->player.x,w->setup.nest_z-w->player.z);if(d<=40){ADD("%s{\"id\":1000,\"type\":\"nest\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",d,bearing(&w->player,w->setup.nest_x,w->setup.nest_z));comma=1;}
 for(int i=0;i<w->setup.n_obstacles;i++){const CpStageObstacle *o=&w->setup.obstacles[i];d=length(o->x-w->player.x,o->z-w->player.z);if(d<=40){ADD("%s{\"id\":%d,\"type\":\"%s\",\"distance\":%.6f,\"bearing\":%.6f}",comma?",":"",2000+i,o->type?"rock":"tree",d,bearing(&w->player,o->x,o->z));comma=1;}}
 ADD("],\"legal_verbs\":[\"go\",\"heading\",\"approach\",\"attack\",\"flee\",\"go_nest\",\"wait\"],\"summary\":\"Explore the valley; creature ids are stable.\"}");
#undef ADD
 return failed?-1:(int)used;
}
