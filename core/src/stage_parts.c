/* P4 discovery, nest shop and eggs. Catalogue order is the lineage part id. */
#include "cpore/world.h"
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <limits.h>

const CpStagePartDef CP_STAGE_PARTS[CP_STAGE_PART_COUNT]={
 {"fauces",25,2,0,0,0,0},
 {"romo",15,0,0,2,0,0},
 {"pico",20,1,0,1,0,0},
 {"ojo",5,0,0,0,0,0},
 {"tallo",10,0,0,0,0,0},
 {"antena",10,0,0,0,0,0},
 {"trompa",15,0,0,0,0,0},
 {"pinzas",25,0,0,0,0,0},
 {"oreja",5,0,0,0,0,0},
 {"pata",25,0,0,0,0,0},
 {"zanca",25,0,0,0,0,0},
 {"pezuna",20,0,0,0,0,0},
 {"asta",18,0,1,0,0,0},
 {"aguijon",18,0,0,0,0,0},
 {"cuerno",15,0,1,0,0,0},
 {"pua",8,0,1,0,0,0},
 {"maza",20,0,0,0,0,0},
 {"placa",10,0,0,0,0,1},
 {"cresta",10,0,0,0,0,0},
 {"bulbo",12,0,0,0,0,0},
 {"aleta",12,0,0,0,0,0},
 {"excavadora",18,0,0,0,0,0},
 {"eye_stalk",16,0,0,0,0,0},
 {"eye_triad",16,0,0,0,0,0},
 {"jaw_nipper",16,2,0,0,0,0},
 {"horn_crown",16,0,1,0,0,0},
 {"shell_plate",16,0,0,0,0,1},
 {"leg_sprinter",16,0,0,0,0,0},
 {"leg_sucker",16,0,0,0,0,0},
 {"arm_grasper",24,0,0,0,0,0},
 {"tail_paddle",16,0,0,0,0,0},
 {"tail_spike",16,0,0,0,1,0},
 {"wing_glider",24,0,0,0,0,0},
 {"frill_fan",16,0,0,0,0,0},
 {"beak_crusher",16,1,0,1,0,0},
 {"mandible_shear",16,2,0,0,0,0},
 {"snout_trumpet",16,2,0,0,0,0},
 {"tongue_spring",16,0,0,0,0,0},
 {"sac_spitter",16,0,0,0,0,0},
 {"arm_smasher",24,0,0,0,0,0},
 {"foot_spring",16,0,0,0,0,0},
 {"foot_hoof",16,0,0,0,0,0},
 {"foot_gecko",16,0,0,0,0,0},
 {"lure_lantern",16,0,0,0,0,0},
 {"wing_insect",24,0,0,0,0,0},
 {"tail_hammer",16,0,0,0,1,0},
 {"espinas_dorsales",30,0,0,0,0,0},
};
/* Stable catalogue indices; each bit grants the corresponding C2 body capability.
 * The recipe move still requires its second part, diet, clues and calcium. */
const uint16_t CP_STAGE_PART_MOVES[CP_STAGE_PART_COUNT]={
 [7]=1u<<CB_CLAW_SWIPE,[21]=1u<<CB_CLAW_SWIPE,[29]=1u<<CB_CLAW_SWIPE,[35]=1u<<CB_CLAW_SWIPE,
 [2]=1u<<CB_PECK,[34]=1u<<CB_PECK,
 [10]=1u<<CB_POUNCE,[27]=1u<<CB_POUNCE,[40]=1u<<CB_POUNCE,
 [13]=1u<<CB_QUILL_VOLLEY,[15]=1u<<CB_QUILL_VOLLEY,
 [18]=1u<<CB_ROAR,[33]=1u<<CB_ROAR,[36]=1u<<CB_ROAR,
 [11]=1u<<CB_STOMP,[41]=1u<<CB_STOMP,[46]=1u<<CB_SPINE_VOLLEY
};
static void event(CpStageWorld *w,int type,int target,int move,int value){
 w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,0,target,move,(float)value,w->player.x,w->player.z};w->ev_total++;
}
static void dna(CpStageWorld *w,int amount,int source){
 w->social.dna_total+=amount;w->social.dna_balance+=amount;
 w->social.dna_by_source[source]+=amount;
 event(w,CP_STAGE_EV_DNA,0,source,amount);
 CpStageEvent *e=&w->events[(w->ev_total-1)%CP_STAGE_MAX_EVENTS];e->x=(float)w->social.dna_total;e->z=(float)w->social.dna_balance;
 w->social.used=1;
}
int cp_stage_part_id(const char *id){if(!id)return -1;for(int i=0;i<CP_STAGE_PART_COUNT;i++)if(!strcmp(id,CP_STAGE_PARTS[i].id))return i;return -1;}
int cp_stage_at_nest(const CpStageWorld *w){
 if(!w||w->active>=0||w->respawn_ticks||w->parts.lost)return 0;
 float dx=w->player.x-w->setup.nest_x,dz=w->player.z-w->setup.nest_z;
 return dx*dx+dz*dz<=CP_STAGE_NEST_RADIUS*CP_STAGE_NEST_RADIUS;
}
/* Authored victim tables: repeated entries are integer weights. */
static const char *const victim[4][6]={
 {"romo","romo","pata","ojo","cresta","placa"},
 {"zanca","zanca","pico","tail_spike","ojo","cresta"},
 {"pua","pua","cuerno","placa","fauces","tail_spike"},
 {"fauces","fauces","jaw_nipper","tail_hammer","cuerno","leg_sprinter"}
};
static const char *const signature[4]={"romo","zanca","pua","fauces"};
void cp_stage_parts_reset(CpStageWorld *w){
 CpStageParts *p=&w->parts;memset(p,0,sizeof *p);p->eggs=3;p->adult_hp=w->player.profile.hp;
 cp_rng_seed(&p->loot,w->setup.seed^0x4c4f4f54u);cp_rng_seed(&p->fossil,w->setup.seed^0x464f5353u);
 const char *start[]={"pico","pata","ojo"};
 for(int k=0;k<3;k++){int id=cp_stage_part_id(start[k]);p->starter|=1ULL<<id;p->level[id]=1;}
 p->discovered=p->owned=p->starter;
 /* A straight walkable corridor is stronger than merely finding a dry endpoint.
  * Fixed candidate budget and two placement draws per candidate, even once full. */
 for(int k=0;k<128;k++){
  int dx=(int)(cp_rng_u32(&p->fossil)%81)-40,dz=(int)(cp_rng_u32(&p->fossil)%81)-40;
  if(p->n_nodes==CP_STAGE_PART_NODES||dx*dx+dz*dz<64)continue;
  float x=w->setup.nest_x+dx,z=w->setup.nest_z+dz;
  if(!cp_stage_walkable_from_nest(w,x,z))continue;
  int near=0;for(int i=0;i<p->n_nodes;i++){float a=x-p->nodes[i].x,b=z-p->nodes[i].z;if(a*a+b*b<16)near=1;}
  if(!near){int i=p->n_nodes++;p->nodes[i]=(CpStagePartNode){x,z,i%2?CP_PART_OLD_CARCASS:CP_PART_FOSSIL,0};}
 }
}
int cp_stage_part_find(CpStageWorld *w,int id,int source){
 if(!w||id<0||id>=CP_STAGE_PART_COUNT||source<0||source>CP_PART_OLD_CARCASS)return -1;
 CpStageParts *p=&w->parts;p->used=1;
 int duplicate=(p->discovered&(1ULL<<id))!=0;
 if(duplicate)dna(w,CP_STAGE_PARTS[id].cost/4,CP_DNA_DUPLICATE);else p->discovered|=1ULL<<id;
 event(w,CP_STAGE_EV_PART_FOUND,id,source,duplicate);w->hash=cp_stage_hash(w);return 0;
}
void cp_stage_parts_ally(CpStageWorld *w,int sp){
 if(sp<0||sp>=4||w->parts.ally_paid[sp])return;
 w->parts.ally_paid[sp]=1;cp_stage_part_find(w,cp_stage_part_id(signature[sp]),CP_PART_ALLY);
}
void cp_stage_parts_kill(CpStageWorld *w,int i){
 if(i<0||i>=w->setup.n||w->parts.kill_paid[i]||!cp_stage_species_counts_progress(w,i+1))return;
 CpStageParts *p=&w->parts;int sp=w->wild[i].species;
 if(sp<0||sp>=4)return;
 p->kill_paid[i]=1;
 if(w->ancestry.count){const CpLineageForm *f=&w->ancestry.forms[w->ancestry.count-1].form;for(int k=0;k<CP_STAGE_PART_COUNT;k++)if(f->parts[k]&&p->kills[k]<UINT32_MAX)p->kills[k]++;}
 unsigned roll=cp_rng_u32(&p->loot)%1000,pick=cp_rng_u32(&p->loot);
 int choices[6],n=0,undiscovered=0;
 for(int k=0;k<6;k++){int id=cp_stage_part_id(victim[sp][k]);if(!(p->discovered&(1ULL<<id)))undiscovered++;if(!(p->owned&(1ULL<<id)))choices[n++]=id;}
 if(roll<(unsigned)(sp==3?350:200)||(++p->dry[sp]>=4&&undiscovered)){
  p->dry[sp]=0;int id=n?choices[pick%(unsigned)n]:cp_stage_part_id(victim[sp][pick%6]);
  cp_stage_part_find(w,id,CP_PART_KILL);
 }
 /* No hash block on a legacy kill with no drop: the stream is folded in on first use. */
}
void cp_stage_set_tiers(CpStageWorld *w,int on){if(!w)return;w->parts.tiers_on=on?1:0;if(on)w->parts.used=1;w->hash=cp_stage_hash(w);}
int cp_stage_part_buy(CpStageWorld *w,int id,int kind){
 if(!w||id<0||id>=CP_STAGE_PART_COUNT||kind<0||kind>2)return -1;
 if(!cp_stage_at_nest(w))return CP_STAGE_ERR_NOT_AT_NEST;
 CpStageParts *p=&w->parts;uint64_t bit=1ULL<<id;int cost;
 if(!(p->discovered&bit))return CP_STAGE_ERR_NOT_KNOWN;
 if(kind==0){if(p->owned&bit)return -1;cost=CP_STAGE_PARTS[id].cost;}
 else{
  if(!(p->owned&bit))return CP_STAGE_ERR_NOT_KNOWN;
  if(kind==1){if(p->level[id]>=5)return -1;cost=CP_STAGE_PARTS[id].cost*(1<<p->level[id]);}
  else{
   if(!p->tiers_on)return -1;
   int t=p->tier[id];const CpStagePartDef *d=&CP_STAGE_PARTS[id];
   if(t>=2||!(d->mouth||d->charge||d->spit||d->tail||d->guard)||p->hits[id]<(t?75u:25u)||p->wins[id]<(t?10u:3u))return -1;
   cost=t?150:60;
  }
 }
 if(cp_stage_social_spend(w,cost))return -1;
 p->used=1;if(kind==0){p->owned|=bit;p->level[id]=1;}else if(kind==1)p->level[id]++;else p->tier[id]++;
 event(w,CP_STAGE_EV_PART_BOUGHT,id,kind,cost);w->hash=cp_stage_hash(w);return 0;
}
void cp_stage_parts_usage(CpStageWorld *w,int move,int won){
 if(move<0||move>=CB_MOVE_COUNT||!w->ancestry.count)return;
 CpStageParts *p=&w->parts;
 uint32_t *m=won?&p->move_wins[move]:&p->move_hits[move];if(*m<UINT32_MAX)(*m)++;p->used=1;
 const CpLineageForm *f=&w->ancestry.forms[w->ancestry.count-1].form;
 for(int i=0;i<CP_STAGE_PART_COUNT;i++)if(f->parts[i]){
  const CpStagePartDef *d=&CP_STAGE_PARTS[i];
  int applies=(CP_STAGE_PART_MOVES[i]&(1u<<move))||(move==CB_SPINE_VOLLEY&&d->mouth==2)||(move==CB_BITE&&d->mouth)||(move==CB_CHARGE&&d->charge)||(move==CB_SPIT&&d->spit)||(move==CB_TAIL_STRIKE&&d->tail);
  if(applies){uint32_t *v=won?&p->wins[i]:&p->hits[i];if(*v<UINT32_MAX)(*v)++;p->used=1;}
 }
}
void cp_stage_parts_win(CpStageWorld *w){
 if(!w->ancestry.count)return;
 CpStageParts *p=&w->parts;
 for(int mv=0;mv<CB_MOVE_COUNT;mv++)if(cp_combat_loadout_slot_of(&w->loadout,mv)>=0&&p->move_wins[mv]<UINT32_MAX)p->move_wins[mv]++;
 const CpLineageForm *f=&w->ancestry.forms[w->ancestry.count-1].form;
 for(int id=0;id<CP_STAGE_PART_COUNT;id++)if(f->parts[id]){
  const CpStagePartDef *d=&CP_STAGE_PARTS[id];
  int equipped=d->guard||(d->mouth&&cp_combat_loadout_slot_of(&w->loadout,CB_BITE)>=0)||(d->spit&&cp_combat_loadout_slot_of(&w->loadout,CB_SPIT)>=0)||(d->charge&&cp_combat_loadout_slot_of(&w->loadout,CB_CHARGE)>=0)||(d->tail&&cp_combat_loadout_slot_of(&w->loadout,CB_TAIL_STRIKE)>=0);
  for(int m=CB_CLAW_SWIPE;m<CB_MOVE_COUNT;m++)if(cp_combat_loadout_slot_of(&w->loadout,m)>=0&&((CP_STAGE_PART_MOVES[id]&(1u<<m))||(m==CB_SPINE_VOLLEY&&d->mouth==2)))equipped=1;
  if(equipped&&p->wins[id]<UINT32_MAX){p->wins[id]++;p->used=1;}
 }
}
void cp_stage_parts_death(CpStageWorld *w){
 CpStageParts *p=&w->parts;p->used=1;if(p->eggs>0)p->eggs--;
 if(!p->eggs){p->lost=1;w->respawn_ticks=0;w->player.hp=0;return;}
 if(!p->hatchling)p->adult_hp=w->player.profile.hp;
 p->hatchling=1200;w->player.profile.hp=p->adult_hp*3.f/5.f;w->respawn_ticks=20;
}
int cp_stage_parts_order(CpStageWorld *w,const CpStageInput *a){
 if(a->verb>=CP_STAGE_BUY_PART)return cp_stage_part_buy(w,a->target,a->verb-CP_STAGE_BUY_PART);
 int i=a->target-3000;
 if(w->active>=0||w->respawn_ticks||w->parts.lost)return CP_STAGE_ERR_IN_FIGHT;
 if(i<0||i>=w->parts.n_nodes||w->parts.nodes[i].inspected)return -2;
 float dx=w->player.x-w->parts.nodes[i].x,dz=w->player.z-w->parts.nodes[i].z;
 if(dx*dx+dz*dz>2.5f*2.5f)return -2;
 w->order=(CpStageInput){.verb=CP_STAGE_WAIT};w->parts.inspect_id=i+1;w->parts.inspect_ticks=0;w->parts.used=1;return 0;
}
void cp_stage_parts_step(CpStageWorld *w){
 CpStageParts *p=&w->parts;
 if(p->hatchling>0&&--p->hatchling==0){w->player.profile.hp=p->adult_hp;w->player.hp=w->player.hp>0?p->adult_hp:0;}
 if(!p->inspect_id)return;
 CpStagePartNode *node=&p->nodes[p->inspect_id-1];float dx=w->player.x-node->x,dz=w->player.z-node->z;
 if(w->active>=0||w->respawn_ticks||w->order.verb!=CP_STAGE_WAIT||dx*dx+dz*dz>6.25f){p->inspect_id=p->inspect_ticks=0;return;}
 if(++p->inspect_ticks<20)return;
 unsigned roll=cp_rng_u32(&p->loot),pick=cp_rng_u32(&p->loot);
 static const char *const fossils[]={"cuerno","foot_hoof","arm_grasper","fauces","pua","placa","jaw_nipper","cresta"};
 static const char *const bones[]={"romo","zanca","pua","fauces","ojo","pata","placa","tail_spike"};
 const char *id=node->kind==CP_PART_FOSSIL?fossils[pick%8]:bones[pick%8];
 (void)roll; /* fixed two draws; surface biome currently guarantees a catalogue result */
 node->inspected=1;p->clues++;
 if(node==&p->nodes[0])cp_stage_recipe_clue(w,1);
 if(node==&p->nodes[1])cp_stage_recipe_clue(w,2);
 if(node==&p->nodes[0])cp_stage_part_find(w,cp_stage_part_id("espinas_dorsales"),CP_PART_FOSSIL);
 dna(w,8,node->kind==CP_PART_FOSSIL?CP_DNA_FOSSIL:CP_DNA_OLD_CARCASS);cp_stage_part_find(w,cp_stage_part_id(id),node->kind);
 event(w,CP_STAGE_EV_INSPECTED,2999+p->inspect_id,node->kind,8);p->inspect_id=p->inspect_ticks=0;
}
static void hu(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}}
uint64_t cp_stage_parts_hash(const CpStageWorld *w){
 const CpStageParts *p=&w->parts;uint64_t h=14695981039346656037ULL;
 for(int i=0;i<4;i++){hu(&h,p->loot.s[i]);hu(&h,p->fossil.s[i]);hu(&h,p->dry[i]);hu(&h,p->ally_paid[i]);}
 hu(&h,p->discovered);hu(&h,p->discovered>>32);hu(&h,p->owned);hu(&h,p->owned>>32);
 for(int i=0;i<46;i++){hu(&h,p->level[i]);hu(&h,p->tier[i]);hu(&h,p->hits[i]);hu(&h,p->wins[i]);hu(&h,p->kills[i]);}
 for(int i=0;i<6;i++){hu(&h,p->move_hits[i]);hu(&h,p->move_wins[i]);}
 int extra=p->level[46]|p->tier[46]|p->hits[46]|p->wins[46]|p->kills[46];
 for(int i=6;i<CB_MOVE_COUNT;i++)extra|=p->move_hits[i]|p->move_wins[i];
 if(extra){hu(&h,0x43325054);hu(&h,p->level[46]);hu(&h,p->tier[46]);hu(&h,p->hits[46]);hu(&h,p->wins[46]);hu(&h,p->kills[46]);for(int i=6;i<CB_MOVE_COUNT;i++){hu(&h,p->move_hits[i]);hu(&h,p->move_wins[i]);}}
 for(int i=0;i<CP_STAGE_MAX_WILD;i++)hu(&h,p->kill_paid[i]);
 if(p->tiers_on||p->clues){hu(&h,0x41323521u);hu(&h,p->tiers_on);hu(&h,p->clues);}
 hu(&h,p->eggs);hu(&h,p->lost);hu(&h,p->hatchling);hu(&h,p->n_nodes);hu(&h,p->inspect_id);hu(&h,p->inspect_ticks);
 uint32_t f;memcpy(&f,&p->adult_hp,4);hu(&h,f);
 for(int i=0;i<p->n_nodes;i++){const CpStagePartNode *n=&p->nodes[i];memcpy(&f,&n->x,4);hu(&h,f);memcpy(&f,&n->z,4);hu(&h,f);hu(&h,n->kind);hu(&h,n->inspected);}return h;
}
static const char *form_name(const CpStagePartDef *d,int tier){
 static const char *const names[5][3]={{"base","hooked","serrated"},{"base","acid","corrosive"},{"base","reinforced","ram"},{"base","barbed","clubbed"},{"base","layered","ridged"}};
 int family=d->mouth==2?0:d->spit?1:d->charge?2:d->tail?3:d->guard?4:-1;
 return family<0?"base":names[family][tier>2?2:tier];
}
int cp_stage_parts_json(const CpStageWorld *w,char *out,size_t cap){
 size_t n=0;const CpStageParts *p=&w->parts;
#define ADD(...) do{int k=snprintf(out+n,cap>n?cap-n:0,__VA_ARGS__);if(k<0||(size_t)k>=cap-n)return -1;n+=(size_t)k;}while(0)
 ADD("{\"inspecting\":%d,\"inspect_ticks\":%d,\"eggs\":%d,\"lost\":%s,\"hatchling_ticks\":%d,\"tiers_enabled\":%s,\"clues\":%d,\"recipes\":%d,\"can_edit\":%s,\"dna_balance\":%d,\"discovered\":[",p->inspect_id?2999+p->inspect_id:0,p->inspect_ticks,p->eggs,p->lost?"true":"false",p->hatchling,p->tiers_on?"true":"false",p->clues,(w->recipes.state>=CP_RECIPE_KNOWN),cp_stage_at_nest(w)?"true":"false",w->social.dna_balance);
 int comma=0;for(int i=0;i<CP_STAGE_PART_COUNT;i++)if(p->discovered&(1ULL<<i)){
  const CpStagePartDef *d=&CP_STAGE_PARTS[i];int t=p->tier[i];
  ADD("%s{\"id\":\"%s\",\"index\":%d,\"cost\":%d,\"owned\":%s,\"level\":%d,\"tier\":%d,\"level_price\":%d,\"tier_price\":%d,\"hits\":%u,\"fights\":%u,\"need_hits\":%d,\"need_fights\":%d,\"form\":\"%s\",\"next_form\":\"%s\"}",comma?",":"",d->id,i,d->cost,(p->owned&(1ULL<<i))?"true":"false",p->level[i],t,p->level[i]<5?d->cost*(1<<p->level[i]):0,t<2?(t?150:60):0,p->hits[i],p->wins[i],t?75:25,t?10:3,form_name(d,t),form_name(d,t+1));comma=1;
 }
 ADD("],\"nodes\":[");for(int i=0;i<p->n_nodes;i++)ADD("%s{\"id\":%d,\"x\":%.3f,\"z\":%.3f,\"kind\":%d,\"inspected\":%s,\"clue\":\"%s\"}",i?",":"",3000+i,p->nodes[i].x,p->nodes[i].z,p->nodes[i].kind,p->nodes[i].inspected?"true":"false",i==0?"spined_fossil":i==1?"quill_wounds":"");ADD("]}");
#undef ADD
 return (int)n;
}
