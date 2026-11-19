#include "cpore/world.h"
#include "cpore/ledger.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
static CpStageWorld w;
int main(void){
 assert(!strcmp(cp_ledger_deed_name(CP_DEED_KILLS),"kills"));
 assert(!strcmp(cp_ledger_trait_name(CP_TRAIT_SOCIAL),"social"));
 assert(!strcmp(cp_ledger_deed_name(-1),"unknown"));
 assert(!strcmp(cp_ledger_trait_name(99),"unknown"));
 CpStageSetup s; cp_stage_setup_default(&s,42); assert(!cp_stage_reset(&w,&s));
 uint64_t h=cp_stage_hash(&w); assert(!w.ledger.enabled);
 cp_ledger_init(&w.ledger); assert(cp_stage_hash(&w)!=h);
 assert(cp_ledger_deed(&w.ledger,1,CP_DEED_KILLS,3,0,0,1)==0);
 assert(w.ledger.traits&(1u<<CP_TRAIT_HUNTER));
 assert(cp_ledger_deed(&w.ledger,2,CP_DEED_BEFRIENDS,2,1,2,2)==0);
 assert(!(w.ledger.traits&(1u<<CP_TRAIT_SOCIAL)));
 assert(!cp_ledger_deed(&w.ledger,2,CP_DEED_BEFRIENDS,1,1,2,2));
 assert(w.ledger.traits&(1u<<CP_TRAIT_SOCIAL));
 assert(cp_ledger_deed(&w.ledger,3,CP_DEED_NIGHT,599,0,0,0)==0);
 assert(!(w.ledger.traits&(1u<<CP_TRAIT_NOCTURNAL)));
 assert(!cp_ledger_deed(&w.ledger,3,CP_DEED_NIGHT,1,0,0,0));
 assert(w.ledger.traits&(1u<<CP_TRAIT_NOCTURNAL));
 assert(cp_ledger_deed(&w.ledger,3,CP_DEED_DIGGING,19,0,0,0)==0);
 assert(!(w.ledger.traits&(1u<<CP_TRAIT_BURROWER)));
 assert(!cp_ledger_deed(&w.ledger,3,CP_DEED_DIGGING,1,0,0,0));
 assert(w.ledger.traits&(1u<<CP_TRAIT_BURROWER));
 assert(cp_ledger_deed(&w.ledger,3,CP_DEED_SWIMMING,9999,0,0,0)<0);
 assert(!(w.ledger.traits&(1u<<CP_TRAIT_AQUATIC)));
 CpLedgerEntry first=w.ledger.entries[0];
 for(int i=0;i<1000;i++) assert(!cp_ledger_deed(&w.ledger,4+i,CP_DEED_OBSERVATIONS,1,0,0,0));
 assert(!memcmp(&first,w.ledger.entries,sizeof first)); assert(w.ledger.dropped>0);
 char *json=malloc(200000); assert(cp_ledger_export(&w.ledger,json,200000)>0);
 assert(strstr(json,"cpore.lineage/1")); assert(cp_ledger_export(&w.ledger,json,2)<0);
 size_t n=cp_stage_snapshot_size(); unsigned char *snap=malloc(n);
 assert(cp_stage_snapshot(&w,snap,n)>0); uint64_t before=cp_stage_hash(&w);
 cp_stage_step(&w,NULL); assert(!cp_stage_restore(&w,snap,n,NULL)); assert(cp_stage_hash(&w)==before);
 uint64_t hashes[10];
 for(int i=0;i<10;i++)hashes[i]=cp_stage_step(&w,NULL);
 assert(cp_stage_replay_ex(NULL,snap,n,NULL,NULL,0,NULL,0,10,NULL)==hashes[9]);
 CpLedger l;cp_ledger_init(&l);
 assert(!cp_ledger_deed(&l,0,CP_DEED_KILLS,2,0,0,0));assert(!l.traits);
 assert(!cp_ledger_deed(&l,0,CP_DEED_KILLS,1,0,0,0));assert(l.traits==1);
 assert(!cp_ledger_deed(&l,0,CP_DEED_KILLS,UINT32_MAX,0,0,0));assert(l.deeds[0]==UINT32_MAX);
 unsigned count=l.count;assert(!cp_ledger_deed(&l,0,CP_DEED_KILLS,1,0,0,0));assert(l.count==count+1);
 for(int d=CP_DEED_FLIGHT;d<=CP_DEED_VOID;d++)assert(cp_ledger_deed(&l,0,d,600,0,0,0)<0);
 assert(cp_ledger_deed(&l,0,-1,1,0,0,0)<0);assert(cp_ledger_deed(&l,0,0,0,0,0,0)<0);
 free(snap);free(json); puts("lineage ledger: passed");return 0;
}
