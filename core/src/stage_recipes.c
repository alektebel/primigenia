/* C2 recipes and diet-refilled resources. Integer gameplay state; placement has
 * its own stream and uses the same corridor check as fossil nodes. */
#include "cpore/world.h"
#include <stdio.h>
#include <string.h>

const CpStageMeterDef CP_STAGE_METERS[2]={{"calcium","carcass",100,15,20},{"mineral","stone",100,25,0}};
const CpStageRecipeDef CP_STAGE_RECIPES[1]={{"bone_spines",{46,0},{2,2},CP_DIET_CARNIVORE,CB_SPINE_VOLLEY,0}};
static void event(CpStageWorld *w,int type,int target,int move,int value){
 w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,0,target,move,value,w->player.x,w->player.z};w->ev_total++;
}
static int clamp_meter(int v,int cap){return v<0?0:v>cap?cap:v;}
void cp_stage_meter_add(CpStageWorld *w,int meter,int amount){
 if(!w||meter<0||meter>1)return;
 int *v=meter?&w->recipes.mineral:&w->recipes.calcium;
 int cap=CP_STAGE_METERS[meter].cap;
 *v=amount>cap?cap:amount< -cap?0:clamp_meter(*v+amount,cap);w->recipes.used=1;
 if(meter)w->player.profile.extra[6]=*v?1:0;
 w->hash=cp_stage_hash(w);
}
void cp_stage_recipe_clue(CpStageWorld *w,int source){
 if(source<0||source>2)return;
 CpStageRecipes *r=&w->recipes;
 if(r->clues&(1<<source))return;
 int before=r->state;
 r->used=1;r->clues|=1<<source;
 int n=0;for(int k=0;k<3;k++)n+=(r->clues>>k)&1;
 if(r->state<CP_RECIPE_KNOWN)r->state=n>=2?CP_RECIPE_KNOWN:CP_RECIPE_HINTED;
 event(w,CP_STAGE_EV_RECIPE,source,r->state,before);
 w->hash=cp_stage_hash(w);
}
int cp_stage_recipe_ready(const CpStageWorld *w){
 const CpCombatProfile *p=&w->player.profile;
 return w->recipes.state>=CP_RECIPE_KNOWN&&p->extra[7]>=CP_STAGE_RECIPES[0].level[0]&&p->mouth>=CP_STAGE_RECIPES[0].level[1]&&p->carnivore;
}
void cp_stage_recipes_reset(CpStageWorld *w){
 CpStageRecipes *r=&w->recipes;memset(r,0,sizeof *r);
 cp_rng_seed(&r->stone_rng,w->setup.seed^0x53544f4e);
 /* Retain the highest reachable candidates: stones favour uphill slopes.
  * Draw budget is fixed even once the table fills. No terrain/spawn draws. */
 for(int k=0;k<128;k++){
  int span=w->setup.terrain==CP_STAGE_FIELD?(int)cp_stage_bound(w):160;
  int dx=(int)(cp_rng_u32(&r->stone_rng)%(unsigned)(2*span+1))-span,dz=(int)(cp_rng_u32(&r->stone_rng)%(unsigned)(2*span+1))-span;
  float x=w->setup.nest_x+dx,z=w->setup.nest_z+dz;
  if(w->setup.terrain==CP_STAGE_FIELD&&cp_stage_ground(w,x,z)<80)continue;
  if(dx*dx+dz*dz<64||!cp_stage_walkable_from_nest(w,x,z))continue;
  int slot=r->n_stones;
  if(slot==CP_STONE_NODES){slot=0;for(int i=1;i<CP_STONE_NODES;i++)if(cp_stage_ground(w,r->stones[i].x,r->stones[i].z)<cp_stage_ground(w,r->stones[slot].x,r->stones[slot].z))slot=i;
   if(cp_stage_ground(w,x,z)<=cp_stage_ground(w,r->stones[slot].x,r->stones[slot].z))continue;
  }else r->n_stones++;
  r->stones[slot]=(CpStagePartNode){x,z,0,0};
 }
 /* Fixed second budget, with at most twelve planner probes near the mountain
  * ring. This reaches slopes behind river bends without an unbounded search. */
 int attempts=0,span=(int)cp_stage_bound(w);if(span>800)span=800;
 for(int k=0;k<128;k++){
  int dx=(int)(cp_rng_u32(&r->stone_rng)%(unsigned)(2*span+1))-span,dz=(int)(cp_rng_u32(&r->stone_rng)%(unsigned)(2*span+1))-span;
  float x=w->setup.nest_x+dx,z=w->setup.nest_z+dz;
  if(w->setup.terrain!=CP_STAGE_FIELD||r->n_stones==CP_STONE_NODES||attempts==12||cp_stage_ground(w,x,z)<80)continue;
  int near=0;for(int i=0;i<r->n_stones;i++){float a=x-r->stones[i].x,b=z-r->stones[i].z;if(a*a+b*b<16)near=1;}
  if(near)continue;
  attempts++;
  if(cp_stage_route_from_nest(w,x,z))r->stones[r->n_stones++]=(CpStagePartNode){x,z,0,0};
 }
 for(int i=0;i<w->parts.n_nodes;i++)if(w->parts.nodes[i].kind==CP_PART_OLD_CARCASS)r->old_units[i]=2;
 for(int i=0;i<w->setup.n;i++)if(w->wild[i].species==2){
  r->wild_calcium[i]=40;

 }
}
int cp_stage_stone_eat(CpStageWorld *w,int target){
 CpStageRecipes *r=&w->recipes;int stone=target>=4000,i=target-(stone?4000:3000);
 if(w->active>=0||w->respawn_ticks)return CP_STAGE_ERR_IN_FIGHT;
 if(i<0||i>=(stone?r->n_stones:w->parts.n_nodes))return -2;
 CpStagePartNode *n=stone?&r->stones[i]:&w->parts.nodes[i];
 if(stone?n->inspected>=4:(!n->inspected||!r->old_units[i]))return -2;
 if(!stone&&w->social.diet==CP_DIET_HERBIVORE)return CP_STAGE_ERR_DIET;
 float dx=w->player.x-n->x,dz=w->player.z-n->z;
 if(dx*dx+dz*dz>6.25f)return -2;
 if((stone?r->mineral:r->calcium)==100)return CP_STAGE_ERR_FULL;
 r->eat_node=target;r->eat_ticks=0;r->used=1;w->order=(CpStageInput){.verb=CP_STAGE_WAIT};return 0;
}

void cp_stage_recipes_step(CpStageWorld *w){
 CpStageRecipes *r=&w->recipes;
 w->player.profile.extra[6]=r->mineral?1:0;
 for(int mv=0;mv<CB_MOVE_COUNT;mv++)if(r->cd[mv]){r->used=1;r->cd[mv]--;}
 if(r->eat_node){
  int stone=r->eat_node>=4000,i=r->eat_node-(stone?4000:3000);
  CpStagePartNode *n=stone?&r->stones[i]:&w->parts.nodes[i];float dx=w->player.x-n->x,dz=w->player.z-n->z;
  if(w->active>=0||w->respawn_ticks||w->order.verb!=CP_STAGE_WAIT||dx*dx+dz*dz>6.25f){r->eat_node=r->eat_ticks=0;return;}
  if(++r->eat_ticks==5){if(stone)n->inspected++;else r->old_units[i]--;cp_stage_meter_add(w,stone?1:0,stone?CP_STAGE_METERS[1].refill:20);r->eat_node=r->eat_ticks=0;}
 }

}
static void hu(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}}
uint64_t cp_stage_recipes_hash(const CpStageWorld *w){
 const CpStageRecipes *r=&w->recipes;uint64_t h=14695981039346656037ULL;
 hu(&h,r->state);hu(&h,r->clues);hu(&h,r->calcium);hu(&h,r->mineral);hu(&h,r->eat_node);hu(&h,r->eat_ticks);hu(&h,r->n_stones);
 for(int k=0;k<4;k++)hu(&h,r->stone_rng.s[k]);
 for(int k=0;k<CB_MOVE_COUNT;k++)hu(&h,r->cd[k]);
 for(int k=0;k<r->n_stones;k++){uint32_t a,b;memcpy(&a,&r->stones[k].x,4);memcpy(&b,&r->stones[k].z,4);hu(&h,a);hu(&h,b);hu(&h,r->stones[k].inspected);}
 for(int k=0;k<CP_STAGE_PART_NODES;k++)hu(&h,r->old_units[k]);
 for(int k=0;k<w->setup.n;k++){hu(&h,r->wild_calcium[k]);hu(&h,r->quill_carcass[k]);}return h;
}
int cp_stage_recipes_json(const CpStageWorld *w,char *out,size_t cap){
 const CpStageRecipes *r=&w->recipes;static const char *const states[]={"unknown","hinted","known","mastered"};size_t n=0;
#define ADD(...) do{int k=snprintf(out+n,cap>n?cap-n:0,__VA_ARGS__);if(k<0||(size_t)k>=cap-n)return -1;n+=k;}while(0)
 ADD("{\"bone_spines\":{\"state\":\"%s\",\"clues\":%d,\"ready\":%s,\"move\":\"spine_volley\",\"parts\":[{\"id\":\"espinas_dorsales\",\"level\":2},{\"id\":\"fauces\",\"level\":2}],\"diet\":\"carnivore\",\"spend\":20},\"meters\":{\"calcium\":{\"value\":%d,\"cap\":100},\"mineral\":{\"value\":%d,\"cap\":100}},\"stones\":[",states[r->state],((r->clues&1)!=0)+((r->clues&2)!=0)+((r->clues&4)!=0),cp_stage_recipe_ready(w)?"true":"false",r->calcium,r->mineral);
 for(int i=0;i<r->n_stones;i++)ADD("%s{\"id\":%d,\"x\":%.3f,\"z\":%.3f,\"units\":%d}",i?",":"",4000+i,r->stones[i].x,r->stones[i].z,4-r->stones[i].inspected);
 ADD("],\"old_carcasses\":[");
 for(int i=0;i<w->parts.n_nodes;i++)ADD("%s{\"id\":%d,\"units\":%d}",i?",":"",3000+i,r->old_units[i]);
 ADD("]}");return (int)n;
#undef ADD
}
