#include "cpore/world.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include <inttypes.h>
static CpStageWorld w;
static void reset(unsigned seed){CpStageSetup s;cp_stage_setup_default(&s,seed);s.terrain=CP_STAGE_FLAT;s.n_obstacles=0;s.n=4;for(int i=0;i<4;i++){s.wild[i].profile=CP_STAGE_SPECIES[0].profile;s.wild[i].species=0;s.wild[i].x=80+i*10;s.wild[i].z=80;}assert(!cp_stage_reset(&w,&s));}
static const char *body="{\"schema\":\"cpore.creature/4\",\"name\":\"Starter\",\"nodes\":[{\"y\":1,\"z\":-2,\"r\":0.1},{\"y\":1,\"z\":-1,\"r\":0.5},{\"y\":1,\"z\":0,\"r\":0.6},{\"y\":1,\"z\":1,\"r\":0.1}],\"parts\":[{\"type\":\"pico\",\"t\":1,\"ang\":0,\"size\":1}],\"skin\":{\"pat\":0,\"wet\":0.3,\"scale\":7,\"cA\":\"#aabbcc\",\"cB\":\"#112233\",\"cC\":\"#ffffff\",\"sk\":\"endo\"},\"regions\":[]}";
static void genomes(void){
 reset(77);CpLineageForm f;assert(!cp_stage_genome_form(body,&f));assert(f.profile.mouth==1&&f.profile.spit==1);
 assert(strstr(f.body,"cpore.creature/5")&&strstr(f.body,"\"level\":1"));
 CpLineageForm normalized;assert(!cp_stage_genome_form(f.body,&normalized));assert(!strcmp(normalized.body,f.body));
 assert(!cp_stage_start_genome(&w,body));assert(cp_stage_start_genome(&w,body)<0);
 uint8_t tier_values[CB_PART_COUNT];cp_stage_genome_tiers(f.body,tier_values);assert(tier_values[CB_PART_SPIT]==0);
 int total=w.social.dna_total;
 assert(!cp_stage_edit(&w,f.body));assert(w.ancestry.count==2&&w.ancestry.forms[0].cousin_id>0);assert(w.social.dna_total==total);
 int gained=0;for(unsigned i=0;i<w.ledger.count;i++)if(w.ledger.entries[i].kind==CP_LEDGER_EVOLVED)gained++;assert(gained==1);
 w.player.x=w.setup.nest_x+13;assert(cp_stage_edit(&w,f.body)==CP_STAGE_ERR_NOT_AT_NEST);
 /* edit_anywhere: the 12 m rule stays, the flag is explicit, never hashed, and fights still block it. */
 {uint64_t h0=cp_stage_hash(&w);assert(!cp_stage_can_edit(&w)&&!cp_stage_at_nest(&w));
  cp_stage_set_edit_anywhere(&w,1);assert(cp_stage_hash(&w)==h0);assert(cp_stage_can_edit(&w)&&!cp_stage_at_nest(&w));
  w.active=0;assert(!cp_stage_can_edit(&w));assert(cp_stage_edit(&w,f.body)==CP_STAGE_ERR_NOT_AT_NEST);w.active=-1;
  assert(!cp_stage_edit(&w,f.body));assert(w.ancestry.count==3);
  cp_stage_set_edit_anywhere(&w,0);assert(!cp_stage_can_edit(&w)&&cp_stage_edit(&w,f.body)==CP_STAGE_ERR_NOT_AT_NEST);}
 reset(78);assert(!cp_stage_lineage_form(&w,&f,0));char changed[CP_LINEAGE_BODY_CAP];strcpy(changed,f.body);char *name=strstr(changed,"pico");memcpy(name,"romo",4);int romo=cp_stage_part_id("romo");assert(!cp_stage_part_find(&w,romo,CP_PART_FOSSIL));w.social.dna_balance=100;assert(!cp_stage_part_buy(&w,romo,0));
 assert(cp_stage_edit(&w,"{\"schema\":\"cpore.creature/5\"}")<0);
 assert(!cp_stage_edit(&w,changed));int diff=0;for(unsigned i=0;i<w.ledger.count;i++)if(w.ledger.entries[i].kind==CP_LEDGER_PART_GAINED||w.ledger.entries[i].kind==CP_LEDGER_PART_LOST)diff++;assert(diff==2);
 strcpy(changed,f.body);name=strstr(changed,"\"level\":1");name[8]='9';assert(cp_stage_genome_form(changed,&normalized)<0);
 assert(cp_stage_genome_form("{\"schema\":\"cpore.creature/5\",\"schema\":null}",&normalized)<0);
 printf("evolution hash %016" PRIx64 "\n",cp_stage_hash(&w));
}
static void tiers(void){
 static CpCombatWorld c;CpCombatSetup s={0};s.n=2;s.flat=1;s.seed=1;
 for(int i=0;i<2;i++){cp_combat_profile_default(&s.c[i].prof);s.c[i].x=10+i*2;s.c[i].y=10;s.c[i].fx=i?-1:1;s.c[i].team=i;}
 cp_combat_reset(&c,&s);CpCombatPreview a,b;cp_combat_preview(&c,0,CB_CHARGE,1,&a);uint64_t old=cp_combat_hash(&c);
 c.c[0].tiers[CB_PART_CHARGE]=2;cp_combat_preview(&c,0,CB_CHARGE,1,&b);assert(fabsf(b.damage-a.damage-4)<.001f);assert(cp_combat_hash(&c)!=old);
 cp_combat_reset(&c,&s);c.c[0].tiers[CB_PART_SPIT]=2;assert(!cp_combat_attack(&c,0,1,CB_SPIT));cp_combat_step(&c);assert(c.c[0].plen==7);
 reset(81);CpLineageForm f;assert(!cp_stage_genome_form(body,&f));assert(!cp_stage_lineage_form(&w,&f,0));int pico=cp_stage_part_id("pico");cp_stage_parts_usage(&w,CB_SPIT,0);assert(w.parts.hits[pico]==1);cp_stage_parts_usage(&w,CB_CHARGE,0);assert(w.parts.hits[pico]==1);cp_stage_parts_win(&w);assert(w.parts.wins[pico]==1);
}
static void saved_inspection(void){
 reset(91);w.setup.n=0;CpStagePartNode *n=&w.parts.nodes[0];w.player.x=n->x;w.player.z=n->z;
 assert(!cp_stage_command(&w,"inspect #3000"));for(int i=0;i<9;i++)cp_stage_step(&w,NULL);
 size_t bytes=cp_stage_snapshot_size();uint8_t *buf=malloc(bytes);assert(buf);assert(cp_stage_snapshot(&w,buf,bytes)>0);
 static CpStageWorld restored;assert(!cp_stage_restore(&restored,buf,bytes,NULL));free(buf);
 for(int i=0;i<30;i++)assert(cp_stage_step(&w,NULL)==cp_stage_step(&restored,NULL));
 assert(w.parts.nodes[0].inspected&&w.social.dna_total>=8);
 printf("inspection hash %016" PRIx64 "\n",cp_stage_hash(&w));
}

/* A25 owner adjustments */
static void a25(void){
 /* 1. limited starter parts */
 reset(200);assert(w.parts.discovered==w.parts.starter&&w.parts.owned==w.parts.starter);int n=0;for(int i=0;i<CP_STAGE_PART_COUNT;i++)if(w.parts.discovered>>i&1)n++;assert(n==3);
 assert(w.parts.starter==((1ULL<<cp_stage_part_id("pico"))|(1ULL<<cp_stage_part_id("pata"))|(1ULL<<cp_stage_part_id("ojo"))));
 CpLineageForm f;assert(!cp_stage_genome_form(body,&f));assert(!cp_stage_start_genome(&w,body));
 char locked[CP_LINEAGE_BODY_CAP];strcpy(locked,f.body);memcpy(strstr(locked,"pico"),"romo",4);
 assert(cp_stage_edit(&w,locked)==CP_STAGE_ERR_NOT_KNOWN);assert(w.ancestry.count==1);
 /* 2. editing only at the nest, for both Evolve and the free apply */
 w.player.x=w.setup.nest_x+13;assert(cp_stage_edit(&w,f.body)==CP_STAGE_ERR_NOT_AT_NEST);assert(cp_stage_apply(&w,f.body)==CP_STAGE_ERR_NOT_AT_NEST);
 w.player.x=w.setup.nest_x;
 /* 3. repaint/rearrange is free and never evolves */
 char painted[CP_LINEAGE_BODY_CAP];strcpy(painted,f.body);char *c=strstr(painted,"#aabbcc");assert(c);memcpy(c,"#ff0000",7);
 int bal=w.social.dna_balance;uint64_t ah=cp_stage_ancestry_hash(&w);
 assert(!cp_stage_apply(&w,painted));assert(w.ancestry.count==1&&w.social.dna_balance==bal&&strstr(w.ancestry.forms[0].form.body,"#ff0000"));assert(cp_stage_ancestry_hash(&w)!=ah);
 assert(!cp_stage_apply(&w,painted));assert(w.ancestry.count==1&&w.ledger.generation==1);
 char moved[CP_LINEAGE_BODY_CAP];strcpy(moved,f.body);c=strstr(moved,"\"t\":1");assert(c);c[4]='0';c[5]='.';c[6]='5';memmove(c+7,c+6,strlen(c+6)+1);
 /* an apply that adds a part changes the profile: it needs Evolve */
 int romo=cp_stage_part_id("romo");assert(!cp_stage_part_find(&w,romo,CP_PART_FOSSIL));w.social.dna_balance=100;
 assert(cp_stage_apply(&w,locked)==CP_STAGE_ERR_NEEDS_EVOLVE);assert(w.ancestry.count==1&&w.social.dna_balance==100);
 /* 3b. Evolve buys what is new, once, with one generation and a cousin */
 int total=w.social.dna_total;assert(!cp_stage_edit(&w,locked));
 assert(w.ancestry.count==2&&w.ancestry.forms[0].cousin_id>0&&w.parts.owned>>romo&1);
 assert(w.social.dna_balance==100-CP_STAGE_PARTS[romo].cost&&w.social.dna_total==total);
 int evolves=0;for(unsigned i=0;i<w.ledger.count;i++)if(w.ledger.entries[i].kind==CP_LEDGER_EVOLVED)evolves++;assert(evolves==1);
 /* unaffordable Evolve leaves everything untouched */
 CpLineageForm g;assert(!cp_stage_genome_form(locked,&g));char lv[CP_LINEAGE_BODY_CAP];strcpy(lv,g.body);c=strstr(lv,"\"level\":1");c[8]='5';
 uint64_t before=cp_stage_hash(&w);assert(cp_stage_edit(&w,lv)==CP_STAGE_ERR_NO_DNA);assert(cp_stage_hash(&w)==before&&w.ancestry.count==2&&w.parts.level[romo]==1);
 w.social.dna_balance=1000;assert(!cp_stage_edit(&w,lv));assert(w.parts.level[romo]==5&&w.ancestry.count==3);
 /* 5. tiers off by default: milestone met but no purchase, genome tier refused */
 reset(201);int p=cp_stage_part_id("fauces");assert(!cp_stage_part_find(&w,p,CP_PART_FOSSIL));w.social.dna_balance=5000;assert(!cp_stage_part_buy(&w,p,0));
 w.parts.hits[p]=25;w.parts.wins[p]=3;assert(cp_stage_part_buy(&w,p,2)<0);assert(!w.parts.tier[p]);
 char tiered[CP_LINEAGE_BODY_CAP];assert(!cp_stage_genome_form(body,&g));strcpy(tiered,g.body);memcpy(strstr(tiered,"pico"),"fauces",6);memmove(strstr(tiered,"fauces")+6,strstr(tiered,"fauces")+4,strlen(strstr(tiered,"fauces")+4)+1);
 assert(!cp_stage_start_genome(&w,body));strcpy(lv,tiered);c=strstr(lv,"\"tier\":0");if(c){c[7]='1';assert(cp_stage_edit(&w,lv)<0);assert(w.ancestry.count==1);}
 cp_stage_set_tiers(&w,1);assert(!cp_stage_part_buy(&w,p,2)&&w.parts.tier[p]==1);
 /* 6. fossil/bone clues: two unlock a recipe */
 reset(202);assert(w.parts.clues==0&&w.parts.n_nodes>=2);for(int k=0;k<2;k++){CpStagePartNode *nd=&w.parts.nodes[k];w.player.x=nd->x;w.player.z=nd->z;w.setup.n=0;assert(!cp_stage_command(&w,k?"inspect #3001":"inspect #3000"));for(int i=0;i<20;i++)cp_stage_step(&w,NULL);}
 assert(w.parts.clues==2);char pj[16384];assert(cp_stage_parts_json(&w,pj,sizeof pj)>0&&strstr(pj,"\"clues\":2")&&strstr(pj,"\"recipes\":1")&&strstr(pj,"\"tiers_enabled\":false"));
 /* 4. zero eggs: the stage freezes (the host returns to the last save) and DNA is kept */
 reset(203);int dna=w.social.dna_balance;for(int k=0;k<3;k++)cp_stage_parts_death(&w);assert(w.parts.lost&&!w.parts.eggs&&w.social.dna_balance==dna);assert(cp_stage_command(&w,"wait")==CP_STAGE_ERR_BUSY);
 puts("A25 adjustments PASS");
}

int main(void){
 genomes();a25();tiers();saved_inspection();
 reset(1);char json[16384];assert(cp_stage_parts_json(&w,json,sizeof json)>0&&strstr(json,"discovered"));assert(w.parts.eggs==3);assert(cp_stage_at_nest(&w));
 int p=cp_stage_part_id("cuerno");assert(p>=0);assert(cp_stage_part_buy(&w,p,0)<0);
 assert(!cp_stage_part_find(&w,p,CP_PART_FOSSIL));int total=w.social.dna_total;
 assert(cp_stage_part_buy(&w,p,0)<0);w.social.dna_balance=10000;
 assert(!cp_stage_part_buy(&w,p,0));assert(w.social.dna_total==total);
 int before=w.social.dna_balance;assert(!cp_stage_part_buy(&w,p,1));assert(w.parts.level[p]==2);assert(before-w.social.dna_balance==2*CP_STAGE_PARTS[p].cost);
 assert(cp_stage_part_buy(&w,p,2)<0);cp_stage_set_tiers(&w,1);assert(cp_stage_part_buy(&w,p,2)<0);w.parts.hits[p]=25;w.parts.wins[p]=3;assert(!cp_stage_part_buy(&w,p,2));assert(w.parts.tier[p]==1);
 assert(!cp_stage_part_find(&w,p,CP_PART_FOSSIL));assert(w.social.dna_total==total+CP_STAGE_PARTS[p].cost/4);
 w.player.x+=12.f;assert(cp_stage_at_nest(&w));w.player.x+=.01f;assert(!cp_stage_at_nest(&w));assert(cp_stage_part_buy(&w,p,1)==CP_STAGE_ERR_NOT_AT_NEST);
 int drops[2]={0};for(int rare=0;rare<2;rare++)for(unsigned seed=1;seed<=2000;seed++){reset(seed);w.wild[0].species=rare?3:0;cp_stage_parts_kill(&w,0);if(w.parts.discovered!=w.parts.starter)drops[rare]++;}
 printf("drop rates /2000 common=%d rare=%d\n",drops[0],drops[1]);assert(drops[0]>320&&drops[0]<480);assert(drops[1]>600&&drops[1]<800);
 for(unsigned seed=1;seed<100;seed++){reset(seed);for(int i=0;i<4;i++)cp_stage_parts_kill(&w,i);assert(w.parts.discovered!=w.parts.starter);}
 reset(2);for(int k=0;k<3;k++){cp_stage_parts_death(&w);assert(w.parts.eggs==2-k);}assert(w.parts.lost);assert(!w.respawn_ticks);
 reset(2);cp_stage_parts_death(&w);assert(w.parts.hatchling==1200);assert(w.player.profile.hp==60);for(int i=0;i<1200;i++)cp_stage_parts_step(&w);assert(w.player.profile.hp==100);
 reset(3);assert(w.parts.n_nodes>0);for(int i=0;i<w.parts.n_nodes;i++)assert(cp_stage_walkable_from_nest(&w,w.parts.nodes[i].x,w.parts.nodes[i].z));CpStagePartNode *n=&w.parts.nodes[0];w.player.x=n->x;w.player.z=n->z;assert(!cp_stage_command(&w,"inspect #3000"));for(int i=0;i<20;i++)cp_stage_parts_step(&w);assert(n->inspected);assert(w.social.dna_total==8);assert(cp_stage_command(&w,"inspect #3000")<0);
 reset(11);int ally=cp_stage_part_id("romo");cp_stage_parts_ally(&w,0);assert(w.parts.discovered&(1ULL<<ally));int bank=w.social.dna_balance;cp_stage_parts_ally(&w,0);assert(w.social.dna_balance==bank);
 reset(12);cp_stage_set_tiers(&w,1);int pico=cp_stage_part_id("pico");w.social.dna_balance=100000;int costs[]={0,2,4,8,16};for(int lv=2;lv<=5;lv++){int old=w.social.dna_balance;assert(!cp_stage_part_buy(&w,pico,1));assert(old-w.social.dna_balance==CP_STAGE_PARTS[pico].cost*costs[lv-1]);}assert(cp_stage_part_buy(&w,pico,1)<0);
 w.parts.hits[pico]=74;w.parts.wins[pico]=10;w.parts.tier[pico]=1;assert(cp_stage_part_buy(&w,pico,2)<0);w.parts.hits[pico]=75;bank=w.social.dna_balance;assert(!cp_stage_part_buy(&w,pico,2));assert(bank-w.social.dna_balance==150);
 /* the cell's legacy (A32): a diet and one owned starter part, both optional; none = untouched */
 reset(13);{uint64_t h0=cp_stage_hash(&w);int pua=cp_stage_part_id("pua");assert(cp_stage_legacy_apply(&w,-1,-1)==0&&cp_stage_hash(&w)==h0);assert(!(w.parts.owned&(1ULL<<pua)));
  assert(cp_stage_legacy_apply(&w,CP_DIET_CARNIVORE,pua)==0);assert(w.social.diet==CP_DIET_CARNIVORE);assert((w.parts.owned&(1ULL<<pua))&&(w.parts.discovered&(1ULL<<pua))&&(w.parts.starter&(1ULL<<pua))&&w.parts.level[pua]==1);assert(cp_stage_hash(&w)!=h0);
  assert(cp_stage_legacy_apply(&w,7,-1)<0&&cp_stage_legacy_apply(&w,-1,CP_STAGE_PART_COUNT)<0);}
 printf("shop hash %016" PRIx64 "\n",cp_stage_hash(&w));
 puts("parts/nest rules PASS");return 0;
}
