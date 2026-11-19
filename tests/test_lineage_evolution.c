#include "cpore/world.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
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
 assert(w.ancestry.forms[0].home_x==10000);
 assert(w.ancestry.forms[0].cousin_id==1);assert(!strcmp(w.ancestry.forms[0].form.body,f.body));
 assert(cp_stage_cousin_generation(&w,1)==1);assert(!cp_stage_species_counts_progress(&w,1));assert(cp_stage_species_counts_progress(&w,0));
 int gains=0,losses=0;for(unsigned i=0;i<w.ledger.count;i++){gains+=w.ledger.entries[i].kind==CP_LEDGER_PART_GAINED;losses+=w.ledger.entries[i].kind==CP_LEDGER_PART_LOST;}
 assert(gains==1&&losses==1);assert(!w.ledger.current[CP_DEED_KILLS]);
 char *json=malloc(400000);assert(cp_stage_lineage_export(&w,json,400000)>0);assert(strstr(json,"Test gen 1"));assert(strstr(json,"generations"));
 uint64_t h=cp_stage_hash(&w);w.active=0;assert(cp_stage_evolve(&w,&f)<0);w.active=-1;assert(cp_stage_hash(&w)==h);
 while(w.ancestry.count<CP_LINEAGE_GENERATIONS)assert(!cp_stage_evolve(&w,&f));
 h=cp_stage_hash(&w);assert(cp_stage_evolve(&w,&f)<0);assert(cp_stage_hash(&w)==h);
 size_t n=cp_stage_snapshot_size();unsigned char *snap=malloc(n);assert(cp_stage_snapshot(&w,snap,n)>0);
 assert(cp_stage_replay_ex(NULL,snap,n,NULL,NULL,0,NULL,0,5,NULL)!=0);
 free(snap);free(json);puts("lineage evolution: passed");return 0;
}
