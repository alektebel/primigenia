#include "cpore/world.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static CpStageWorld w,v;
static void reset(int sp,float x){
 CpStageSetup s;cp_stage_setup_default(&s,19);s.terrain=CP_STAGE_FLAT;s.n=1;s.start_clock=4000;
 s.wild[0]=(CpStageSpawn){.x=x,.home_x=x,.species=sp,.bot=-1,.profile=CP_STAGE_SPECIES[sp].profile,.legs=sp==6?5:sp==7?6:0};
 assert(!cp_stage_reset(&w,&s));
}
static void step(int n){for(int i=0;i<n;i++)cp_stage_step(&w,NULL);}
static void migration(void){
 FILE *f=fopen("build/species-v7.snap","rb");assert(f);fseek(f,0,SEEK_END);size_t n=ftell(f);rewind(f);unsigned char *p=malloc(n);assert(fread(p,1,n,f)==n);fclose(f);
 assert(!cp_stage_restore(&w,p,n,NULL));assert(w.tick==713&&w.setup.n==6&&w.clock==4713);
 assert(w.social.dna_balance==79&&w.social.c[5].trust==43&&w.parts.eggs==2&&w.secrets.found_mask==9);
 assert(w.social.tested==(1ULL<<47)&&w.social.liked==(1ULL<<45));
 for(int i=0;i<6;i++){assert(w.social.kills[i]==i+1);assert(w.parts.dry[i]==i+2);assert(w.social.first_met[i]==100+i);}
 for(int i=6;i<8;i++)assert(!w.social.kills[i]&&!w.parts.dry[i]&&!w.social.obs_items[i]);
 assert(cp_stage_hash(&w)==0x38c76a92256c2077ULL);
 const uint64_t before=cp_stage_hash(&w);
 p[40]^=1;assert(cp_stage_restore(&w,p,n,NULL)==CP_STAGE_SNAP_ERR_HASH);p[40]^=1;
 p[16]^=1;assert(cp_stage_restore(&w,p,n,NULL)==CP_STAGE_SNAP_ERR_LAYOUT);p[16]^=1;
 assert(cp_stage_restore(&w,p,n-1,NULL)==CP_STAGE_SNAP_ERR_SIZE);
 p[32]=1;assert(cp_stage_restore(&w,p,n,NULL)==CP_STAGE_SNAP_ERR_FIELD);p[32]=0;
 assert(cp_stage_hash(&w)==before);
 size_t m=cp_stage_snapshot_size();unsigned char *q=malloc(m);assert(cp_stage_snapshot(&w,q,m)==(int)m&&q[8]==8);assert(!cp_stage_restore(&v,q,m,NULL));
 for(int i=0;i<50;i++)assert(cp_stage_step(&w,NULL)==cp_stage_step(&v,NULL));
 free(q);free(p);
 puts("PASS species: genuine v7 snapshot migrates social/parts/secrets and replays as v8");
}
static void social(int sp){
 reset(sp,2);w.debug_flags=CP_STAGE_FLAG_AI_OFF;w.social.c[0].mood=10;
 CpStageInput a={.verb=CP_STAGE_BEFRIEND,.target=1,.move=CP_SOC_CHARM};assert(!cp_stage_order(&w,&a));step(100);assert(w.social.c[0].trust>0);
 reset(sp,2);w.debug_flags=CP_STAGE_FLAG_AI_OFF;a=(CpStageInput){.verb=CP_STAGE_INTIMIDATE,.target=1};assert(!cp_stage_order(&w,&a));step(80);assert(w.social.intimidate_cd>0||w.social.c[0].leave_ticks>0);
 reset(sp,20);w.debug_flags=CP_STAGE_FLAG_AI_OFF;a=(CpStageInput){.verb=CP_STAGE_OBSERVE,.target=1};assert(!cp_stage_order(&w,&a));step(160);assert(w.social.obs_items[sp]==3);assert(CP_STAGE_CHAINS[sp].observe[2][0]);
 reset(sp,2);w.wild[0].dead=1;w.wild[0].hp=0;a=(CpStageInput){.verb=CP_STAGE_EAT,.target=1};assert(!cp_stage_order(&w,&a));step(12);assert(w.social.c[0].eaten>0);
 /* Last species/gift bit is bit 63: exercise it without a signed or narrow shift. */
 reset(sp,2);w.debug_flags=CP_STAGE_FLAG_AI_OFF;w.social.items[CP_ITEM_BONE]=1;a=(CpStageInput){.verb=CP_STAGE_GIFT,.target=1,.move=CP_ITEM_BONE};assert(!cp_stage_order(&w,&a));step(100);assert(w.social.tested&(1ULL<<(sp*8+7)));
}
int main(void){
 assert(CP_STAGE_SPECIES_COUNT==8&&CP_SOC_SPECIES==8);migration();
 assert(CP_STAGE_SPECIES[6].speed==2.f&&CP_STAGE_SPECIES[6].sight==14&&CP_STAGE_SPECIES[6].roam==10);
 assert(CP_STAGE_SPECIES[7].speed==1.4f&&CP_STAGE_SPECIES[7].sight==10&&CP_STAGE_SPECIES[7].roam==8);
 assert(CP_STAGE_SPECIES[6].temperament==CP_STAGE_TERRITORIAL&&CP_STAGE_SPECIES[7].temperament==CP_STAGE_TIMID);
 CpStageSetup pair;cp_stage_setup_default(&pair,2);pair.terrain=CP_STAGE_FLAT;pair.n=2;
 for(int i=0;i<2;i++)pair.wild[i]=(CpStageSpawn){.x=50+i*30,.home_x=50+i*30,.species=6+i,.bot=-1,.legs=5+i,.profile=CP_STAGE_SPECIES[6+i].profile};
 assert(!cp_stage_reset(&w,&pair));assert(cp_stage_social_species_present(&w)==2);step(120);
 for(int i=0;i<2;i++){
  const CpStageCreature *e=&w.wild[i];float dx=e->goal_x-e->home_x,dz=e->goal_z-e->home_z;
  assert(dx*dx+dz*dz<=CP_STAGE_SPECIES[6+i].roam*CP_STAGE_SPECIES[6+i].roam+.001f);
  assert(e->legs==5+i&&e->home_x==pair.wild[i].home_x);
 }
 for(int sp=6;sp<8;sp++)social(sp);
 reset(7,30);w.clock=11000;w.wild[0].fx=1;w.wild[0].goal_x=100;w.wild[0].roam_ticks=1000;step(30);assert(w.wild[0].speed>1.39f&&w.wild[0].speed<=1.401f);
 reset(7,30);w.wild[0].goal_x=100;w.wild[0].roam_ticks=1000;step(30);assert(w.wild[0].speed==0);
 reset(6,30);w.wild[0].goal_x=100;w.wild[0].roam_ticks=1000;step(60);assert(w.wild[0].speed<=.301f&&w.wild[0].speed>.2f);
 reset(6,30);w.social.c[0].leave_ticks=200;w.wild[0].fx=1;step(30);assert(w.wild[0].speed>1.99f&&w.wild[0].speed<=2.01f);
 puts("PASS species: radial tables, roam/flee speed and social verbs including bit 63");
 reset(3,20);float old_x=w.wild[0].x;w.wild[0].goal_x=40;w.wild[0].roam_ticks=1000;w.wild[0].fx=1;step(30);assert(w.wild[0].x>old_x&&w.active<0);
 reset(3,2);assert(!cp_stage_social_hostile(&w,0));step(1);assert(w.active<0);w.tick=599;assert(!cp_stage_social_hostile(&w,0));w.tick=600;assert(cp_stage_social_hostile(&w,0));step(1);assert(w.active==0);
 reset(3,2);CpStageInput a={.verb=CP_STAGE_ATTACK,.target=1};assert(!cp_stage_order(&w,&a));step(1);assert(w.active==0);
 reset(3,2);w.tick=1000;cp_stage_parts_death(&w);assert(w.parts.hatchling>0&&w.respawn_ticks==20);step(20);assert(!cp_stage_social_hostile(&w,0));w.wild[0].x=2;w.wild[0].z=0;step(599);assert(w.active<0);w.wild[0].x=2;w.wild[0].z=0;step(1);assert(w.active==0);
 reset(3,20);w.tick=1000;cp_stage_parts_death(&w);step(20);assert(w.grace_until==w.tick-1+CP_STAGE_GRACE_TICKS);
 size_t grace_n=cp_stage_snapshot_size();unsigned char *grace=malloc(grace_n);assert(cp_stage_snapshot(&w,grace,grace_n)>0);assert(!cp_stage_restore(&v,grace,grace_n,NULL));assert(v.grace_until==w.grace_until);free(grace);
 assert(cp_stage_step(&w,NULL)==cp_stage_step(&v,NULL));
 puts("PASS species: Garfio patrol, grace, expiry, provocation, hatchling respawn and saved clock");
 reset(4,6.01f);assert(cp_stage_creature_hidden(&w,0));assert(cp_stage_command(&w,"observe #1")==-2);step(1);assert(cp_stage_creature_hidden(&w,0));w.player.x=w.wild[0].x-6;step(1);assert(!cp_stage_creature_hidden(&w,0));assert(cp_stage_social_hostile(&w,0));
 w.player.x=-100;step(148);assert(!cp_stage_creature_hidden(&w,0));step(1);assert(cp_stage_creature_hidden(&w,0));
 reset(4,6);step(1);size_t n=cp_stage_snapshot_size();unsigned char *p=malloc(n);assert(cp_stage_snapshot(&w,p,n)>0);assert(!cp_stage_restore(&v,p,n,NULL));assert(cp_stage_step(&w,NULL)==cp_stage_step(&v,NULL));free(p);
 puts("PASS species: Acechalunas day wake radius, temperament, sleep delay and snapshot");return 0;
}
