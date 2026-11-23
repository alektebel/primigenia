#include "cpore/world.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
static CpStageWorld w;
int main(void){
 CpStageSetup s;cp_stage_setup_default(&s,42);s.terrain=CP_STAGE_FLAT;s.n=0;assert(!cp_stage_reset(&w,&s));
 CpLineageForm f={0};f.profile=s.player;strcpy(f.body,"{\"schema\":\"cpore.creature/4\",\"parts\":[]}");strcpy(f.name,"Test");f.parts[1]=2;
 assert(!cp_stage_lineage_form(&w,&f,0));assert(w.ledger.generation==1);
 cp_stage_lineage_award(&w,CP_DEED_KILLS,3,0);for(int i=0;i<20;i++)cp_stage_step(&w,NULL);
 assert(w.ancestry.forms[0].type==-1);
 w.player.x=100;for(int i=0;i<40;i++)cp_stage_step(&w,NULL);
 CpLineageForm invalid=f;invalid.profile.speed=-1;uint64_t original=cp_stage_hash(&w);
 assert(cp_stage_evolve(&w,&invalid)<0&&cp_stage_hash(&w)==original);
 unsigned saved_count=w.ledger.count;w.ledger.count=CP_LEDGER_CAP;
 original=cp_stage_hash(&w);assert(cp_stage_evolve(&w,&f)<0&&cp_stage_hash(&w)==original);w.ledger.count=saved_count;
 CpLineageForm next=f;next.parts[1]=1;next.parts[2]=1;
 assert(!cp_stage_evolve(&w,&next));assert(w.ledger.generation==2);assert(w.setup.n==1);
 assert(w.ancestry.forms[0].type>=0);
 assert(w.ancestry.forms[0].trust_bonus==20);
 /* the player was 100 m from the nest: the cousin ring is anchored on the nest, not there (T9) */
 assert(w.ancestry.forms[0].home_x==(int32_t)(w.setup.nest_x*100));assert(w.ancestry.forms[0].home_z==(int32_t)(w.setup.nest_z*100));
 assert(hypotf(w.wild[0].x-w.setup.nest_x,w.wild[0].z-w.setup.nest_z)<=CP_STAGE_COUSIN_MAX_DIST);
 assert(w.ancestry.forms[0].cousin_id==1);assert(!strcmp(w.ancestry.forms[0].form.body,f.body));
 assert(cp_stage_cousin_generation(&w,1)==1);assert(!cp_stage_species_counts_progress(&w,1));assert(cp_stage_species_counts_progress(&w,0));
 int gains=0,losses=0;for(unsigned i=0;i<w.ledger.count;i++){gains+=w.ledger.entries[i].kind==CP_LEDGER_PART_GAINED;losses+=w.ledger.entries[i].kind==CP_LEDGER_PART_LOST;}
 assert(gains==1&&losses==1);assert(!w.ledger.current[CP_DEED_KILLS]);
 char *json=malloc(400000);assert(cp_stage_lineage_export(&w,json,400000)>0);assert(strstr(json,"Test gen 1"));assert(strstr(json,"generations"));
 uint64_t h=cp_stage_hash(&w);w.active=0;assert(cp_stage_evolve(&w,&f)<0);w.active=-1;assert(cp_stage_hash(&w)==h);
 while(w.ancestry.count<CP_LINEAGE_GENERATIONS)assert(!cp_stage_evolve(&w,&f));
 for(int i=0;i<w.setup.n;i++)assert(hypotf(w.wild[i].x-w.setup.nest_x,w.wild[i].z-w.setup.nest_z)<=CP_STAGE_COUSIN_MAX_DIST);
 h=cp_stage_hash(&w);assert(cp_stage_evolve(&w,&f)<0);assert(cp_stage_hash(&w)==h);
 /* T9: a full island roster (ROSTER_CAP animals) still leaves room for three evolves: three cousins alive, each within 40 m of the nest,
  * and the world survives a snapshot round trip and replays exactly. */
 {static CpStageWorld r;CpStageSetup s2;cp_stage_setup_default(&s2,7);s2.terrain=CP_STAGE_FLAT;s2.n=CP_STAGE_ROSTER_CAP;
  for(int i=0;i<s2.n;i++){s2.wild[i].species=i%CP_STAGE_SPECIES_DEFINED;s2.wild[i].bot=-1;s2.wild[i].x=s2.wild[i].home_x=-150+(i%6)*8.f;s2.wild[i].z=s2.wild[i].home_z=-150+(i/6)*8.f;s2.wild[i].profile=CP_STAGE_SPECIES[s2.wild[i].species].profile;}
  assert(!cp_stage_reset(&r,&s2));
  CpLineageForm g=f;g.profile=s2.player;assert(!cp_stage_lineage_form(&r,&g,0));
  for(int e=0;e<3;e++){CpLineageForm nx=g;nx.parts[1]=(uint8_t)(1+e);assert(!cp_stage_evolve(&r,&nx));g=nx;for(int t=0;t<20;t++)cp_stage_step(&r,NULL);}
  assert(r.setup.n==CP_STAGE_ROSTER_CAP+3&&r.setup.n<=CP_STAGE_MAX_WILD-CP_STAGE_RESERVE_FAMILY-1+1);
  int cousins=0;for(int i=0;i<r.setup.n;i++){int id=i+1;if(cp_stage_cousin_generation(&r,id)){cousins++;assert(!r.wild[i].dead);assert(hypotf(r.wild[i].x-r.setup.nest_x,r.wild[i].z-r.setup.nest_z)<=CP_STAGE_COUSIN_MAX_DIST);}}
  assert(cousins==3);
  size_t rn=cp_stage_snapshot_size();unsigned char *rs=malloc(rn);assert(cp_stage_snapshot(&r,rs,rn)>0);
  static CpStageWorld r2;assert(!cp_stage_restore(&r2,rs,rn,NULL));assert(cp_stage_hash(&r2)==cp_stage_hash(&r));
  for(int t=0;t<200;t++){cp_stage_step(&r,NULL);cp_stage_step(&r2,NULL);assert(cp_stage_hash(&r)==cp_stage_hash(&r2));}
  free(rs);}
 size_t n=cp_stage_snapshot_size();unsigned char *snap=malloc(n);assert(cp_stage_snapshot(&w,snap,n)>0);
 assert(cp_stage_replay_ex(NULL,snap,n,NULL,NULL,0,NULL,0,5,NULL)!=0);
 free(snap);free(json);puts("lineage evolution: passed");return 0;
}
