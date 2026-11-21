#include "cpore/world.h"
#if CP_STAGE_SNAPSHOT_VERSION != 7
#error "Regenerate this historical fixture only with the original v7 core"
#endif
/* Captured before the species-v8 implementation; gzip -n the .snap output. */
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
static CpStageWorld w;
int main(void){
 CpStageSetup s; cp_stage_setup_default(&s,73); s.terrain=CP_STAGE_FLAT;s.n=6;s.start_clock=4000;
 for(int i=0;i<6;i++)s.wild[i]=(CpStageSpawn){.x=50+i*10,.z=30,.home_x=50+i*10,.home_z=30,.species=i,.bot=-1,.profile=CP_STAGE_SPECIES[i].profile};
 assert(!cp_stage_reset(&w,&s));
 for(int i=0;i<713;i++)cp_stage_step(&w,NULL);
 w.social.used=w.parts.used=1;
 w.social.tested=1ULL<<47;w.social.liked=1ULL<<45;w.social.species_seen=63;
 for(int i=0;i<6;i++){w.social.obs_items[i]=i%3;w.social.kills[i]=i+1;w.social.first_met[i]=100+i;w.parts.dry[i]=i+2;w.parts.ally_paid[i]=i%2;}
 w.social.dna_balance=79;w.social.c[5].trust=43;w.parts.eggs=2;w.secrets.found_mask=9;
 size_t n=cp_stage_snapshot_size();unsigned char *p=malloc(n);assert(cp_stage_snapshot(&w,p,n)==(int)n);
 FILE *f=fopen("tests/fixtures/species-v7.snap","wb");assert(f);assert(fwrite(p,1,n,f)==n);fclose(f);printf("v7 fixture %zu bytes, layout %016llx, hash %016llx\n",n,(unsigned long long)cp_stage_layout(),(unsigned long long)cp_stage_hash(&w));free(p);
}
