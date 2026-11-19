/* Narrow world adapter for L0/A13. All award producers share this interface. */
#include "cpore/world.h"
#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
int cp_stage_lineage_begin(CpStageWorld *w){
 if(!w||w->ledger.enabled)return -1;
 cp_ledger_init(&w->ledger);w->hash=cp_stage_hash(w);return 0;
}
int cp_stage_lineage_award(CpStageWorld *w,int deed,uint32_t amount,uint32_t cause){
 if(!w)return -1;
 int rc=cp_ledger_deed(&w->ledger,w->tick,deed,amount,(int32_t)(w->player.x*100),(int32_t)(w->player.z*100),cause);
 if(!rc)w->hash=cp_stage_hash(w);
 return rc;
}
void cp_stage_lineage_tick(CpStageWorld *w,int32_t old_x,int32_t old_z){
 if(!w->ledger.enabled||w->respawn_ticks)return;
 if(w->ancestry.count){
  int32_t x=(int32_t)(w->player.x*100),z=(int32_t)(w->player.z*100);
  int cx=(x+200000)/6400,cz=(z+200000)/6400;
  unsigned i;for(i=0;i<w->ancestry.n_residence;i++)if(w->ancestry.residence[i].cell_x==cx&&w->ancestry.residence[i].cell_z==cz)break;
  if(i<w->ancestry.n_residence){if(w->ancestry.residence[i].ticks<UINT32_MAX)w->ancestry.residence[i].ticks++;}
  else if(i<128){w->ancestry.residence[i]=(CpLineageResidence){cx,cz,x,z,1};w->ancestry.n_residence++;}
 }
 int32_t x=(int32_t)(w->player.x*100),z=(int32_t)(w->player.z*100);
 int64_t dx=(int64_t)x-old_x,dz=(int64_t)z-old_z;
 /* L1 centimetres avoids platform sqrt; jumps/respawns over 5m are excluded. */
 uint32_t d=(uint32_t)((dx<0?-dx:dx)+(dz<0?-dz:dz));
 if(d&&d<=500){cp_ledger_deed(&w->ledger,w->tick,CP_DEED_DISTANCE,d,x,z,0);
  if(w->clock>=CP_STAGE_DAY_TICKS*3/4)cp_ledger_deed(&w->ledger,w->tick,CP_DEED_NIGHT,1,x,z,0);}
 dx=x-(int32_t)(w->setup.nest_x*100);dz=z-(int32_t)(w->setup.nest_z*100);
 if(dx*dx+dz*dz<=1200*1200)cp_ledger_deed(&w->ledger,w->tick,CP_DEED_NEST,1,x,z,0);
}

int cp_stage_cousin_generation(const CpStageWorld *w,int id){
 if(!w||id<=0)return 0;
 for(unsigned i=0;i+1<w->ancestry.count;i++)if(w->ancestry.forms[i].cousin_id==id)return (int)i+1;
 return 0;
}
int cp_stage_species_counts_progress(const CpStageWorld *w,int id){return !cp_stage_cousin_generation(w,id);}
static int valid_form(const CpLineageForm *f){
 if(!f||!memchr(f->body,0,sizeof f->body)||!memchr(f->name,0,sizeof f->name)||f->body[0]!='{')return 0;
 const CpCombatProfile *p=&f->profile;
 return p->mouth<=5&&p->charge<=5&&p->spit<=5&&p->tail<=5&&p->guard<=5&&isfinite(p->hp)&&p->hp>0&&p->hp<=100000&&isfinite(p->stamina)&&p->stamina>0&&p->stamina<=100000&&isfinite(p->speed)&&p->speed>0&&p->speed<=100&&(!p->radius_cm||(p->radius_cm>=40&&p->radius_cm<=400));
}
static void copy_form(CpLineageForm *out,const CpLineageForm *in){
 memset(out,0,sizeof *out);
 memcpy(out->body,in->body,strlen(in->body)+1);memcpy(out->name,in->name,strlen(in->name)+1);
 memcpy(out->parts,in->parts,sizeof out->parts);
 const CpCombatProfile *p=&in->profile;CpCombatProfile *q=&out->profile;
 q->mouth=p->mouth;q->charge=p->charge;q->spit=p->spit;q->tail=p->tail;q->guard=p->guard;
 q->hp=p->hp;q->stamina=p->stamina;q->speed=p->speed;q->radius_cm=p->radius_cm;
}
int cp_stage_lineage_form(CpStageWorld *w,const CpLineageForm *f,int evolve){
 if(evolve)return cp_stage_evolve(w,f);
 if(!w||!valid_form(f)||w->ancestry.count||w->active>=0)return -1;
 if(!w->ledger.enabled)cp_ledger_init(&w->ledger);
 w->ancestry.count=1;
 copy_form(&w->ancestry.forms[0].form,f);w->ancestry.forms[0].generation=1;
 w->ancestry.forms[0].type=-1;
 w->player.profile=w->setup.player=w->ancestry.forms[0].form.profile;w->player.hp=f->profile.hp;w->player.stamina=f->profile.stamina;
 cp_combat_loadout_default(&w->loadout,&f->profile);
 w->hash=cp_stage_hash(w);return 0;
}
int cp_stage_evolve(CpStageWorld *w,const CpLineageForm *f){
 if(!w||!valid_form(f)||!w->ancestry.count||w->ancestry.count>=CP_LINEAGE_GENERATIONS||w->active>=0||w->respawn_ticks||w->setup.n>=CP_STAGE_MAX_WILD)return -1;
 CpLineageGeneration *old=&w->ancestry.forms[w->ancestry.count-1];
 unsigned needed=2;
 for(int i=0;i<CP_LINEAGE_PARTS;i++)if(old->form.parts[i]!=f->parts[i])needed++;
 if(w->ledger.count+needed>CP_LEDGER_CAP)return -1;
 int32_t hx=(int32_t)(w->player.x*100),hz=(int32_t)(w->player.z*100);uint32_t best=0;
 for(unsigned i=0;i<w->ancestry.n_residence;i++)if(w->ancestry.residence[i].ticks>best){const CpLineageResidence *r=&w->ancestry.residence[i];best=r->ticks;hx=r->x;hz=r->z;}
 /* A cousin uses a distinct logical species id (4+generation), with one of the
  * four existing AI templates as its behaviour projection. No new combat AI. */
 int temper=w->ledger.current[CP_DEED_KILLS]+(uint64_t)w->ledger.current[CP_DEED_INTIMIDATIONS]>w->ledger.current[CP_DEED_BEFRIENDS]+(uint64_t)w->ledger.current[CP_DEED_GIFTS]?2:old->form.profile.guard?1:0;
 int diet=old->form.profile.mouth>=2?1:old->form.profile.mouth==1?2:0;
 int base=temper==2?3:temper==1?2:0;
 CpStageDebug d={.op=CP_STAGE_DBG_SPAWN,.a=base,.x=hx/100.f,.z=hz/100.f};
 static const int offsets[8][2]={{3200,0},{0,3200},{-3200,0},{0,-3200},{2400,2400},{-2400,2400},{2400,-2400},{-2400,-2400}};
 int spawned=0;
 for(int k=0;k<8;k++){
  int candidate=(k+(int)w->ancestry.count-1)%8;
  int scale=w->ancestry.count>8?3:2;
  d.x=(hx+offsets[candidate][0]*scale/2)/100.f;d.z=(hz+offsets[candidate][1]*scale/2)/100.f;
  /* Validate the old body's full radius, not just the AI template's radius. */
  int blocked=0;float radius=cp_combat_body_radius(&old->form.profile);
  for(int j=0;j<w->setup.n_obstacles;j++){
   const CpStageObstacle *o=&w->setup.obstacles[j];float dx=d.x-o->x,dz=d.z-o->z,r=radius+o->r;
   if(dx*dx+dz*dz<r*r){blocked=1;break;}
  }
  if(blocked)continue;
  if(cp_stage_debug(w,&d)==0){spawned=1;break;}
 }
 if(!spawned)return -1; /* validates a nearby home-range spawn; atomic failure */
 int id=w->setup.n;
 old->cousin_id=id;old->home_x=hx;old->home_z=hz;old->temperament=temper;old->diet=diet;old->trust_bonus=20;
 old->traits=w->ledger.traits;memcpy(old->deeds,w->ledger.current,sizeof old->deeds);
 w->wild[id-1].profile=old->form.profile;w->wild[id-1].hp=old->form.profile.hp;w->wild[id-1].stamina=old->form.profile.stamina;
 w->setup.wild[id-1].profile=old->form.profile;
 w->wild[id-1].home_x=w->setup.wild[id-1].home_x=hx/100.f;
 w->wild[id-1].home_z=w->setup.wild[id-1].home_z=hz/100.f;
 for(int i=0;i<CP_LINEAGE_PARTS;i++){
  int diff=(int)f->parts[i]-old->form.parts[i];
  if(diff)cp_ledger_append(&w->ledger,w->tick,diff>0?CP_LEDGER_PART_GAINED:CP_LEDGER_PART_LOST,i,diff>0?diff:-diff,hx,hz,w->ledger.generation);
 }
 cp_ledger_append(&w->ledger,w->tick,CP_LEDGER_EVOLVED,w->ledger.generation, w->ledger.generation+1,hx,hz,0);
 int scores[4],previous=w->ancestry.count>1?w->ancestry.forms[w->ancestry.count-2].type:0;
 old->type=cp_type_score(w->ledger.current,previous,scores);
 cp_ledger_append(&w->ledger,w->tick,CP_LEDGER_TYPE,old->type,1,hx,hz,w->ledger.generation);
 w->ledger.generation++;memset(w->ledger.current,0,sizeof w->ledger.current);
 CpLineageGeneration *next=&w->ancestry.forms[w->ancestry.count++];copy_form(&next->form,f);next->generation=w->ledger.generation;next->type=-1;
 memset(w->ancestry.residence,0,sizeof w->ancestry.residence);w->ancestry.n_residence=0;memset(w->ancestry.perk_serial,0,sizeof w->ancestry.perk_serial);
 w->player.profile=next->form.profile;w->player.hp=f->profile.hp;w->player.stamina=f->profile.stamina;
 w->setup.player=next->form.profile;cp_combat_loadout_default(&w->loadout,&f->profile);
 w->hash=cp_stage_hash(w);return 0;
}
static void ah_u32(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(i*8));*h*=1099511628211ULL;}}
static void ah_text(uint64_t *h,const char *s){while(*s){*h^=(uint8_t)*s++;*h*=1099511628211ULL;}ah_u32(h,0);}
static void ah_float(uint64_t *h,float f){uint32_t v=0;if(f!=0)memcpy(&v,&f,4);ah_u32(h,v);}
uint64_t cp_stage_ancestry_hash(const CpStageWorld *w){
 uint64_t h=14695981039346656037ULL;const CpAncestry *a=&w->ancestry;
 ah_u32(&h,a->count);ah_u32(&h,a->n_residence);for(int k=0;k<CP_TYPE_PERKS;k++)ah_u32(&h,a->perk_serial[k]);
 for(unsigned i=0;i<a->n_residence;i++){const CpLineageResidence *r=&a->residence[i];ah_u32(&h,r->cell_x);ah_u32(&h,r->cell_z);ah_u32(&h,r->x);ah_u32(&h,r->z);ah_u32(&h,r->ticks);}
 for(unsigned i=0;i<a->count;i++){const CpLineageGeneration *g=&a->forms[i];ah_text(&h,g->form.body);ah_text(&h,g->form.name);
  for(int k=0;k<CP_LINEAGE_PARTS;k++)ah_u32(&h,g->form.parts[k]);
  const CpCombatProfile *p=&g->form.profile;ah_u32(&h,p->mouth);ah_u32(&h,p->charge);ah_u32(&h,p->spit);ah_u32(&h,p->tail);ah_u32(&h,p->guard);ah_u32(&h,p->radius_cm);ah_float(&h,p->hp);ah_float(&h,p->stamina);ah_float(&h,p->speed);
  ah_u32(&h,g->generation);ah_u32(&h,g->traits);for(int k=0;k<CP_DEED_COUNT;k++)ah_u32(&h,g->deeds[k]);
  ah_u32(&h,g->cousin_id);ah_u32(&h,g->home_x);ah_u32(&h,g->home_z);ah_u32(&h,g->temperament);ah_u32(&h,g->diet);ah_u32(&h,g->trust_bonus);ah_u32(&h,g->type);
 }return h;
}
/* Escape names and body strings rather than interpolating untrusted JSON. */
static int quoted(char *out,size_t cap,size_t *n,const char *s){
 if(*n+2>=cap)return -1;
 out[(*n)++]='"';
 for(;*s;s++){unsigned char c=(unsigned char)*s;char b[8];const char *p=b;
  if(c=='"'||c=='\\'){b[0]='\\';b[1]=(char)c;b[2]=0;}else if(c<32)snprintf(b,sizeof b,"\\u%04x",c);else{b[0]=(char)c;b[1]=0;}
  size_t len=strlen(p);if(*n+len+2>=cap)return -1;memcpy(out+*n,p,len);*n+=len;
 }out[(*n)++]='"';out[*n]=0;return 0;
}
int cp_stage_lineage_export(const CpStageWorld *w,char *out,size_t cap){
 if(!w||!out)return -1;
 int base=cp_ledger_export(&w->ledger,out,cap);if(base<0)return -1;
 size_t n=(size_t)base-1;
#define AJ(...) do{if(n>=cap)return -1;int k=snprintf(out+n,cap-n,__VA_ARGS__);if(k<0||(size_t)k>=cap-n)return -1;n+=(size_t)k;}while(0)
 int scores[4],previous=w->ancestry.count>1?w->ancestry.forms[w->ancestry.count-2].type:0;
 int type=cp_type_score(w->ledger.current,previous,scores);char code[8];cp_type_code(type,code);
 AJ(",\"live_type\":{\"index\":%d,\"code\":\"%s\",\"name\":\"%s\",\"description\":\"%s\",\"scores\":[%d,%d,%d,%d],\"perk\":%d},\"generations\":[",type,code,cp_type_name(type),cp_type_description(type),scores[0],scores[1],scores[2],scores[3],cp_type_perk(type));
 for(unsigned i=0;i<w->ancestry.count;i++){
  const CpLineageGeneration *g=&w->ancestry.forms[i];char name[100];snprintf(name,sizeof name,"%s gen %u",g->form.name,g->generation);
  AJ("%s{\"generation\":%u,\"cousin_id\":%d,\"species_id\":%u,\"counts_progress\":false,\"home_cm\":[%d,%d],\"trust_bonus\":%d,\"temperament\":%d,\"diet\":%d,\"trait_mask\":%u,\"type\":%d,\"name\":",i?",":"",g->generation,g->cousin_id,4+g->generation,g->home_x,g->home_z,g->trust_bonus,g->temperament,g->diet,g->traits,g->type);
  int gt=g->type<0?type:g->type;char gc[8];cp_type_code(gt,gc);
  /* The preceding name key belongs to the generation name. */
  if(quoted(out,cap,&n,name))return -1;
  AJ(",\"type_code\":\"%s\",\"type_name\":\"%s\",\"body_json\":",gc,cp_type_name(gt));if(quoted(out,cap,&n,g->form.body))return -1;AJ("}");
 }
 AJ("]}");
#undef AJ
 return (int)n;
}

int cp_stage_lineage_perk(CpStageWorld *w,int kind,uint32_t serial,int amount){
 if(!w||!w->ledger.enabled||kind<0||kind>=CP_TYPE_PERKS||amount<0)return -1;
 if(!serial||serial<=w->ancestry.perk_serial[kind])return 0;
 int scores[4],prev=w->ancestry.count>1?w->ancestry.forms[w->ancestry.count-2].type:0;
 int type=cp_type_score(w->ledger.current,prev,scores);
 int result=cp_type_adjust(type,kind,amount);
 w->ancestry.perk_serial[kind]=serial;w->hash=cp_stage_hash(w);return result;
}
