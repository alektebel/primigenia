/* L0/A13 wired into the C2 social loop: deeds, cousin +20 trust, type perks. Run by `make test`. */
#include "cpore/world.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static CpStageWorld w;
static CpStageSetup su;
#define PASS(name) printf("PASS lineage social: %s\n",name)
static void mk1(int species,float dist,int ledger){
    cp_stage_setup_default(&su,42);
    su.terrain=CP_STAGE_FLAT;su.nest_x=su.nest_z=0;su.n=1;
    su.wild[0]=(CpStageSpawn){.x=dist,.z=0,.home_x=dist,.home_z=0,.species=species,.bot=-1,.profile=CP_STAGE_SPECIES[species].profile};
    assert(cp_stage_reset(&w,&su)==0);
    {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
    if(ledger)assert(cp_stage_lineage_begin(&w)==0);
}
static void run(const char *cmd,int max){
    assert(cp_stage_command(&w,cmd)==0);
    for(int i=0;i<max&&w.order.verb;i++)cp_stage_step(&w,NULL);
}
static int type_of(void){int sc[4];return cp_type_score(w.ledger.current,0,sc);}
static void deeds(void){
    mk1(0,3,1);
    cp_stage_social_give(&w,CP_ITEM_FRUIT,4);
    for(int i=0;i<4;i++)run("gift #1 fruit",40);
    assert(w.ledger.current[CP_DEED_GIFTS]==4&&w.ledger.current[CP_DEED_BEFRIENDS]==0);
    run("gift #1 plant",40);run("gift #1 plant",40);
    assert(w.social.c[0].bonded&&w.ledger.current[CP_DEED_BEFRIENDS]==1&&w.ledger.current[CP_DEED_GIFTS]==6);
    PASS("gifts and the first bond are ledger deeds");
    mk1(0,15,1);
    run("observe #1",400);
    assert(w.ledger.current[CP_DEED_OBSERVATIONS]>=1);
    PASS("observed clues are deeds");
    mk1(0,3,0);run("gift #1 fruit",40);
    assert(w.ledger.count==0&&!w.ledger.enabled);
    PASS("no ledger, no deeds");
}
static void perks(void){
    /* a zero-deed creature is undetermined: no perk, 50 ticks per clue */
    mk1(0,15,1);
    assert(cp_type_perk(type_of())==-1);
    assert(cp_stage_command(&w,"observe #1")==0);
    {int t=0;while(w.social.obs_items[0]==0&&t<200){cp_stage_step(&w,NULL);t++;}assert(t>=50&&t<=52);}
    /* all four axes decided as S-G-I-W: the Wary perk, 50 -> 40 ticks per clue */
    mk1(0,15,1);
    cp_stage_lineage_award(&w,CP_DEED_BEFRIENDS,20,0);cp_stage_lineage_award(&w,CP_DEED_PLANTS,20,0);
    cp_stage_lineage_award(&w,CP_DEED_BUILDING,20,0);cp_stage_lineage_award(&w,CP_DEED_OBSERVATIONS,20,0);
    assert(cp_type_perk(type_of())==CP_TYPE_OBSERVE);
    assert(cp_stage_command(&w,"observe #1")==0);
    int ticks=0;
    while(w.social.obs_items[0]==0&&ticks<200){cp_stage_step(&w,NULL);ticks++;}
    assert(w.social.obs_items[0]==1&&ticks<=45&&ticks>=40);
    PASS("Wary type watches 20% faster");
    /* Social type: +10 trust on the first meeting only */
    mk1(0,3,1);
    cp_stage_lineage_award(&w,CP_DEED_BEFRIENDS,20,0);cp_stage_lineage_award(&w,CP_DEED_FIGHTS,20,0);
    cp_stage_lineage_award(&w,CP_DEED_DISTANCE,50000,0);cp_stage_lineage_award(&w,CP_DEED_PLANTS,20,0);
    assert(cp_type_perk(type_of())==CP_TYPE_TRUST);
    cp_stage_social_give(&w,CP_ITEM_FRUIT,2);
    run("gift #1 fruit",40);
    const int first=w.social.c[0].trust;
    run("gift #1 fruit",40);
    assert(first==22&&w.social.c[0].trust==34);   /* 10 + 12 on the first, 12 on the second */
    PASS("Social type adds +10 trust on first meeting only");
    /* Hunter type: +10% carcass food per bite */
    mk1(0,3,1);
    cp_stage_lineage_award(&w,CP_DEED_KILLS,20,0);cp_stage_lineage_award(&w,CP_DEED_FIGHTS,20,0);
    cp_stage_lineage_award(&w,CP_DEED_DISTANCE,50000,0);cp_stage_lineage_award(&w,CP_DEED_HUNTS,20,0);
    assert(cp_type_perk(type_of())==CP_TYPE_MEAT);
    w.wild[0].dead=1;w.wild[0].hp=0;w.social.food=0;
    assert(cp_stage_command(&w,"eat #1")==0);
    for(int i=0;i<60&&w.social.c[0].eaten<1;i++)cp_stage_step(&w,NULL);
    assert(w.social.c[0].eaten==1&&w.social.food==(CP_SOC_BITE_FOOD*110/100));
    assert(w.ledger.current[CP_DEED_MEAT]==1);
    PASS("Hunter-line type gets +10% food per bite; meat is a deed");
}
static void cousin(void){
    cp_stage_setup_default(&su,42);su.terrain=CP_STAGE_FLAT;su.n=0;assert(!cp_stage_reset(&w,&su));
    CpLineageForm f={0};f.profile=su.player;strcpy(f.body,"{\"schema\":\"cpore.creature/4\",\"parts\":[]}");strcpy(f.name,"Test");
    assert(!cp_stage_lineage_form(&w,&f,0));
    assert(!cp_stage_evolve(&w,&f)&&w.setup.n==1&&cp_stage_cousin_generation(&w,1)==1);
    w.player.x=w.wild[0].x-3;w.player.z=w.wild[0].z;
    {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
    cp_stage_social_give(&w,CP_ITEM_FRUIT,2);
    run("gift #1 fruit",60);
    const int t=w.social.c[0].trust;
    run("gift #1 fruit",60);
    assert(t>=20&&w.social.c[0].trust-t<=12);
    PASS("a cousin starts with +20 trust, once");
}
int main(void){deeds();perks();cousin();puts("lineage social: all passed");return 0;}
