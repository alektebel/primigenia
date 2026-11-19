#include "cpore/world.h"
#include "cpore/creature_types.h"
#include <assert.h>
#include <string.h>
#include <stdio.h>
static CpStageWorld w;
int main(void){
 uint32_t d[CP_DEED_COUNT]={0};int scores[4];assert(cp_type_score(d,15,scores)==15);for(int i=0;i<4;i++)assert(!scores[i]);
 for(int type=0;type<16;type++){
  memset(d,0,sizeof d);
  d[type&1?CP_DEED_BEFRIENDS:CP_DEED_KILLS]=20;
  d[type&2?CP_DEED_PLANTS:CP_DEED_MEAT]=20;
  d[type&4?CP_DEED_BUILDING:CP_DEED_PLACES]=20;
  d[type&8?CP_DEED_OBSERVATIONS:CP_DEED_FIGHTS]=20;
  assert(cp_type_score(d,15,scores)==type);
  for(int i=0;i<4;i++)assert(scores[i]>=-100&&scores[i]<=100);
  char code[8];cp_type_code(type,code);assert(strlen(code)==7);assert(cp_type_name(type));
  int perk=cp_type_perk(type);assert(perk>=0&&perk<4);
  cp_ledger_init(&w.ledger);memset(&w.ancestry,0,sizeof w.ancestry);memcpy(w.ledger.current,d,sizeof d);
  for(int kind=0;kind<4;kind++){
   int result=cp_type_adjust(type,kind,100);
   assert(cp_stage_lineage_perk(&w,kind,1,100)==result);assert(cp_stage_lineage_perk(&w,kind,1,100)==0);
   assert(result==(kind!=perk?100:kind==CP_TYPE_TRUST?110:kind==CP_TYPE_MEAT?110:kind==CP_TYPE_NEST?85:80));
  }
 }
 memset(d,0,sizeof d);d[CP_DEED_KILLS]=10;d[CP_DEED_BEFRIENDS]=11;
 assert(cp_type_score(d,0,scores)==0);assert(scores[0]>0&&scores[0]<=10);
 d[CP_DEED_KILLS]=UINT32_MAX;assert(!(cp_type_score(d,15,scores)&1));
 CpStageSetup setup;cp_stage_setup_default(&setup,42);assert(!cp_stage_reset(&w,&setup));cp_stage_lineage_begin(&w);
 int kind=cp_type_perk(15);assert(cp_stage_lineage_perk(&w,kind,1,100)>0);assert(cp_stage_lineage_perk(&w,kind,1,100)==0);
 assert(cp_stage_lineage_perk(&w,kind,0,100)==0);assert(cp_stage_lineage_perk(&w,kind,2,100)>0);
 assert(cp_stage_lineage_perk(&w,-1,3,100)<0);
 puts("creature types: 16 vectors, dead zone, saturation and perk idempotence passed");return 0;
}
