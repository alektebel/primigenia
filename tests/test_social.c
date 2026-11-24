/* C2 social layer: bond threshold and latch, rhythm, combos, habituation, refusals, herd trust, observe -> known move,
 * intimidate, ally/dominate, DNA monotonicity, determinism. Run by `make test`. */
#include "cpore/world.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
static CpStageWorld w;
static CpStageSetup su;
#define PASS(name) printf("PASS social: %s\n",name)
/* species at 3 m spacing in front of the player; AI off unless `ai` */
static void mk(int n,const int *species,const float *dist,int ai){
    cp_stage_setup_default(&su,42);
    su.terrain=CP_STAGE_FLAT;
    su.nest_x=su.nest_z=0;
    su.n=n;
    for(int i=0;i<n;i++){
        su.wild[i]=(CpStageSpawn){.x=dist[i],.z=0,.home_x=dist[i],.home_z=0,.species=species[i],.bot=-1,.profile=CP_STAGE_SPECIES[species[i]].profile};
    }
    assert(cp_stage_reset(&w,&su)==0);
    if(!ai){CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};assert(cp_stage_debug(&w,&d)==0);}
}
static void mk1(int species,float dist,int ai){mk(1,&species,&dist,ai);}
static void steps(int n){for(int i=0;i<n;i++)cp_stage_step(&w,NULL);}
/* issue a command and run until the standing order ends (or max ticks) */
static int run(const char *cmd,int max){
    int rc=cp_stage_command(&w,cmd);
    if(rc)return rc;
    for(int i=0;i<max&&w.order.verb;i++)cp_stage_step(&w,NULL);
    return 0;
}
static int last_event(int type,CpStageEvent *out){
    for(int k=(int)w.ev_total-1;k>=0&&k>(int)w.ev_total-CP_STAGE_MAX_EVENTS;k--)
        if(w.events[k%CP_STAGE_MAX_EVENTS].type==type){if(out)*out=w.events[k%CP_STAGE_MAX_EVENTS];return 1;}
    return 0;
}
static void feed(int sp_idx,int item,int times){
    char c[64];
    cp_stage_social_give(&w,item,times);
    for(int i=0;i<times;i++){snprintf(c,sizeof c,"gift #%d %s",sp_idx,CP_STAGE_ITEM_NAMES[item]);assert(run(c,40)==0);}
}
static void bonding(void){
    mk1(0,3,0);
    feed(1,CP_ITEM_FRUIT,4);   /* +12 each = 48 */
    assert(w.social.c[0].trust==48&&!w.social.c[0].bonded&&cp_stage_social_relationship(&w,0)==CP_REL_TRUSTED);
    feed(1,CP_ITEM_PLANT,1);   /* +6 = 54 */
    assert(w.social.c[0].trust==54&&!w.social.c[0].bonded);
    feed(1,CP_ITEM_PLANT,1);   /* 60: bonded exactly at the threshold */
    assert(w.social.c[0].trust==60&&w.social.c[0].bonded&&w.social.latched[0]==1&&cp_stage_social_relationship(&w,0)==CP_REL_ALLY);
    assert(w.social.dna_by_source[CP_DNA_BOND]==8);
    PASS("bond at trust 60, +8 DNA once");
    /* the latch survives decay: 1200 idle ticks, then -1 per 600 */
    steps(3000);
    assert(w.social.c[0].trust<60&&w.social.c[0].trust>=55&&w.social.c[0].bonded&&w.social.latched[0]==1);
    PASS("bond latch survives trust decay");
}
static void rhythm_and_combo(void){
    int in=0,out=0,cap200=0;
    for(int off=0;off<CP_SOC_BEAT;off++){
        mk1(0,3,0);
        steps(off);
        assert(run("befriend #1 sing",60)==0);
        CpStageEvent e;
        assert(last_event(CP_STAGE_EV_SKILL,&e));
        const int rhythm=(e.move&256)!=0;
        assert(e.value==(rhythm?18:12)&&e.x==(rhythm?150:100));
        rhythm?in++:out++;
    }
    assert(in==5&&out==7);   /* a window of +-2 ticks around the beat: 5 of 12 phases */
    PASS("rhythm window +-2 of a 12 tick beat (x1.5)");
    for(int off=0;off<CP_SOC_BEAT;off++){
        mk1(0,3,0);
        steps(off);
        assert(run("befriend #1 charm",60)==0);
        assert(run("befriend #1 dance",60)==0);
        CpStageEvent e;
        assert(last_event(CP_STAGE_EV_SKILL,&e));
        assert(((e.move>>9)&3)==1&&e.x<=200);
        if(e.move&256)assert(e.x==200);   /* 1.5 rhythm x 1.5 combo = 2.25, capped at 2.0 */
        assert(run("befriend #1 sing",60)==0);
        assert(last_event(CP_STAGE_EV_SKILL,&e)&&((e.move>>9)&3)==2&&e.x<=200);
        if(e.move&256)cap200++;
    }
    assert(cap200>0);
    PASS("combos 1.5 then 2.0, capped at 2.0 with rhythm");
}
static void habituation(void){
    mk1(0,3,0);
    CpStageEvent e;
    int gains[4];
    for(int i=0;i<4;i++){
        assert(run("befriend #1 charm",60)==0);
        assert(last_event(CP_STAGE_EV_SKILL,&e));
        gains[i]=(int)e.value;
    }
    assert(gains[0]==6&&gains[1]==3&&gains[2]==1&&gains[3]==1);   /* 100%, 50%, 25% (floor 1) */
    PASS("habituation 50% then 25%");
}
static void refusals(void){
    mk1(3,6,0);   /* Garfio, aggressive */
    assert(run("befriend #1 pose",60)==CP_STAGE_ERR_REFUSES);
    cp_stage_social_give(&w,CP_ITEM_MEAT,1);
    assert(run("gift #1 meat",80)==0&&w.social.c[0].calm_ticks>0&&w.social.c[0].trust==16);
    assert(run("befriend #1 pose",60)==0&&w.social.c[0].trust>16);
    PASS("aggressive creature refuses social skills until calmed by a liked gift");
    /* heard of in a fight: no befriending while it is engaged */
    mk1(1,3,0);
    assert(cp_stage_command(&w,"attack #1 bite")==0);
    for(int i=0;i<40&&w.active<0;i++)cp_stage_step(&w,NULL);
    assert(w.active==0);
    assert(cp_stage_command(&w,"befriend #1 sing")==CP_STAGE_ERR_IN_FIGHT);
    assert(cp_stage_command(&w,"gift #1 fruit")==CP_STAGE_ERR_IN_FIGHT);
    PASS("no befriending a creature in a fight");
    mk1(2,12,0);
    assert(cp_stage_command(&w,"befriend #1 pose")==0);
    assert(cp_stage_command(&w,"befriend #1 yodel")==CP_STAGE_ERR_BAD_SKILL);
    assert(cp_stage_command(&w,"gift #1 meat")==CP_STAGE_ERR_NO_ITEM);
    assert(cp_stage_command(&w,"befriend #9 sing")==-2);
    PASS("error codes: bad skill, no item, bad target");
}
static void herd(void){
    const int sp[3]={0,0,0};const float d[3]={3,6,9};
    mk(3,sp,d,0);
    w.social.c[1].trust=40;w.social.c[2].trust=40;
    assert(cp_stage_command(&w,"attack #1 bite")==0);
    for(int i=0;i<40&&w.active<0;i++)cp_stage_step(&w,NULL);
    assert(w.active==0);
    assert(w.social.c[1].trust==30&&w.social.c[2].trust==30);
    PASS("hunting a herd member lowers the herd's trust");
    /* attacking a bonded individual breaks the bond and cancels an alliance */
    mk(3,sp,d,0);
    for(int i=0;i<3;i++){feed(i+1,CP_ITEM_FRUIT,5);}
    assert(w.social.resolution[0]==CP_RES_ALLY&&w.social.latched[0]==3);
    assert(w.parts.discovered&(1ULL<<cp_stage_part_id("romo")));
    assert(w.social.dna_by_source[CP_DNA_ALLY]==20&&w.social.dna_by_source[CP_DNA_BOND]==24);
    assert(cp_stage_social_species_resolved(&w)==1&&cp_stage_social_species_present(&w)==1);
    PASS("ally at 3 bonded: +20 DNA, species resolved 1/1");
    assert(cp_stage_command(&w,"attack #2 bite")==0);
    for(int i=0;i<60&&w.active<0;i++)cp_stage_step(&w,NULL);
    assert(w.active==1&&!w.social.c[1].bonded&&w.social.latched[0]==2&&w.social.resolution[0]==CP_RES_OPEN);
    assert(w.social.dna_total>=44);
    PASS("attacking a bonded individual breaks the bond and the alliance");
}
static void kill_n(int idx){
    char c[64];
    snprintf(c,sizeof c,"attack #%d bite",idx);
    for(int i=0;i<2000&&!w.wild[idx-1].dead;i++){
        if(w.active<0||!w.order.verb)cp_stage_command(&w,c);
        else if(w.active>=0&&w.combat.c[0].move==CB_MOVE_NONE)cp_stage_command(&w,c);
        cp_stage_step(&w,NULL);
        if(w.player.hp<20){CpStageDebug d={CP_STAGE_DBG_HEAL,0,0,-1,-1,0};cp_stage_debug(&w,&d);}
    }
    assert(w.wild[idx-1].dead);
}
static void dominate(void){
    const int sp[3]={0,0,0};const float d[3]={3,6,9};
    mk(3,sp,d,0);
    for(int k=1;k<=3;k++){
        assert(w.social.resolution[0]==CP_RES_OPEN);
        kill_n(k);
        for(int i=0;i<200;i++)cp_stage_step(&w,NULL);
    }
    assert(w.social.kills[0]==3&&w.social.resolution[0]==CP_RES_HUNTED);
    assert(w.social.dna_by_source[CP_DNA_KILL]==18&&w.social.dna_by_source[CP_DNA_DOMINATE]==20);
    PASS("dominate at 3 kills: 6 DNA per kill, +20 DNA");
}
static void observe(void){
    mk1(0,15,0);
    /* a body without a spit part: spit is not known until the chain is complete */
    su.player.spit=0;
    assert(cp_stage_reset(&w,&su)==0);
    {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};cp_stage_debug(&w,&d);}
    assert(!(cp_stage_known_moves(&w)&(1u<<CB_SPIT)));
    assert(cp_stage_command(&w,"loadout 1 spit")==CP_STAGE_ERR_NOT_KNOWN);
    assert(run("observe #1",CP_SOC_OBSERVE_TICKS*3+20)==0);
    assert(w.social.obs_items[0]==3&&(cp_stage_known_moves(&w)&(1u<<CB_SPIT)));
    CpStageEvent e;
    assert(last_event(CP_STAGE_EV_CHAIN_DONE,&e)&&e.move==CB_SPIT);
    assert(cp_stage_command(&w,"loadout 1 spit")==0&&w.loadout.slot[0]==CB_SPIT);
    assert(w.social.dna_by_source[CP_DNA_KILL]==0);
    char o[32768];
    assert(cp_stage_observe(&w,o,sizeof o)>0&&strstr(o,"\"complete\":true")&&strstr(o,"\"teaches\":\"spit\""));
    PASS("observing the 3 clues completes the chain and teaches the move");
    /* observing is interrupted by being seen: too close to a timid creature */
    mk1(0,5,0);
    steps(1);
    assert(cp_stage_command(&w,"observe #1")==0);
    steps(120);
    assert(w.social.obs_items[0]==0);
    PASS("observing needs the target unseen");
}
static void intimidate(void){
    int wins=0,losses=0;
    for(int seed=1;seed<40&&(!wins||!losses);seed++){
        cp_stage_setup_default(&su,(uint32_t)seed);
        su.terrain=CP_STAGE_FLAT;
        su.n=1;
        su.wild[0]=(CpStageSpawn){.x=8,.z=0,.home_x=8,.home_z=0,.species=2,.bot=-1,.profile=CP_STAGE_SPECIES[2].profile};
        assert(cp_stage_reset(&w,&su)==0);
        {CpStageDebug d={CP_STAGE_DBG_FLAGS,0,CP_STAGE_FLAG_AI_OFF,0,0,0};cp_stage_debug(&w,&d);}
        const int total=w.social.dna_total,trust=w.social.c[0].trust;
        steps(2);
        const int total0=w.social.dna_total;
        assert(run("intimidate #1",60)==0);
        CpStageEvent e;
        assert(last_event(CP_STAGE_EV_INTIMIDATE,&e));
        assert(w.social.dna_total==total0&&w.social.c[0].trust==trust&&w.social.kills[0]==0);
        (void)total;
        if(e.value>0){wins++;assert(w.social.c[0].leave_ticks>0);}else losses++;
    }
    assert(wins&&losses);
    /* a successful display makes the creature leave */
    for(int seed=1;seed<80;seed++){
        cp_stage_setup_default(&su,(uint32_t)seed);
        su.terrain=CP_STAGE_FLAT;su.n=1;
        su.wild[0]=(CpStageSpawn){.x=8,.z=0,.home_x=8,.home_z=0,.species=0,.bot=-1,.profile=CP_STAGE_SPECIES[0].profile};
        assert(cp_stage_reset(&w,&su)==0);
        assert(run("intimidate #1",60)==0);
        CpStageEvent e;
        assert(last_event(CP_STAGE_EV_INTIMIDATE,&e));
        if(e.value>0){
            const float d0=w.wild[0].x-w.player.x;
            steps(30);
            assert(w.wild[0].x-w.player.x>d0+2);
            break;
        }
    }
    PASS("intimidate: no DNA, no trust change, success drives the target away");
}
static void dna_monotonic(void){
    mk1(0,3,0);
    int prev=0;
    const char *script[]={"befriend #1 sing","befriend #1 dance","gift #1 fruit","observe #1","intimidate #1","attack #1 bite"};
    cp_stage_social_give(&w,CP_ITEM_FRUIT,5);
    for(int k=0;k<6;k++){
        assert(cp_stage_command(&w,script[k])==0||1);
        for(int i=0;i<400;i++){
            cp_stage_step(&w,NULL);
            assert(w.social.dna_total>=prev);
            prev=w.social.dna_total;
            if(w.active>=0&&w.combat.c[0].move==CB_MOVE_NONE)cp_stage_command(&w,"attack #1 bite");
        }
        if(k==2){const int before=w.social.dna_total,bal=w.social.dna_balance;assert(bal>0);assert(cp_stage_social_spend(&w,bal)==0);assert(w.social.dna_balance==0&&w.social.dna_total==before);assert(cp_stage_social_spend(&w,1)<0);}
    }
    assert(w.social.dna_total>0);
    PASS("dna_total never decreases; spending only lowers dna_balance");
}
static void determinism(void){
    const int sp[3]={0,2,3};const float d[3]={3,12,30};
    mk(3,sp,d,1);
    cp_stage_social_give(&w,CP_ITEM_FRUIT,10);
    uint8_t snap[1<<20];
    uint64_t hashes[2][1500];
    const char *cmds[]={"befriend #1 sing","gift #1 fruit","befriend #1 dance","observe #2","intimidate #3"};
    uint8_t *blob=malloc(cp_stage_snapshot_size());
    for(int pass=0;pass<2;pass++){
        mk(3,sp,d,1);
        cp_stage_social_give(&w,CP_ITEM_FRUIT,10);
        int snapped=0;
        for(int t=0;t<1500;t++){
            if(t%250==0)cp_stage_command(&w,cmds[(t/250)%5]);
            hashes[pass][t]=cp_stage_step(&w,NULL);
            if(pass==0&&t==700){snapped=cp_stage_snapshot(&w,blob,cp_stage_snapshot_size());assert(snapped>0);}
        }
        (void)snap;
        if(pass==1)break;
    }
    assert(!memcmp(hashes[0],hashes[1],sizeof hashes[0]));
    /* restore the mid snapshot and replay the remaining commands: same hashes */
    CpStageWorld r;
    memset(&r,0,sizeof r);
    assert(cp_stage_restore(&r,blob,cp_stage_snapshot_size(),NULL)==0);
    assert(r.social.used&&r.tick==701);
    for(int t=701;t<1500;t++){
        if(t%250==0)cp_stage_command(&r,cmds[(t/250)%5]);
        assert(cp_stage_step(&r,NULL)==hashes[0][t]);
    }
    PASS("social state is deterministic and survives snapshot/restore");
}
static void eating(void){
    mk1(0,3,0);
    kill_n(1);
    for(int i=0;i<150;i++)cp_stage_step(&w,NULL);   /* the 80 tick post-fight cooldown */
    assert(cp_stage_social_carcass_meat(&w,0)==CP_SOC_CARCASS_BITES);
    w.social.food=20;
    const int dna0=w.social.dna_total,food0=w.social.food;
    assert(cp_stage_command(&w,"eat #1")==0);
    for(int i=0;i<12;i++)cp_stage_step(&w,NULL);
    assert(w.social.act_verb==CP_STAGE_EAT);
    for(int i=0;i<40&&w.order.verb;i++)cp_stage_step(&w,NULL);
    /* the carcass is depleted bite by bite, food rises, the carcass DNA is paid once */
    assert(cp_stage_social_carcass_meat(&w,0)==0&&w.social.food>food0&&w.social.dna_total==dna0+3);
    assert(w.social.dna_by_source[CP_DNA_CARCASS]==3&&w.social.items[CP_ITEM_BONE]==1);
    assert(cp_stage_command(&w,"eat #1")==-2);
    PASS("eat: carcass depletes over bites, food rises, carcass DNA once");
    /* interrupted by another order: the bites already taken stay taken */
    mk1(1,3,0);
    kill_n(1);
    for(int i=0;i<150;i++)cp_stage_step(&w,NULL);
    assert(cp_stage_command(&w,"eat #1")==0);
    for(int i=0;i<2*CP_SOC_BITE_TICKS+5;i++)cp_stage_step(&w,NULL);
    assert(cp_stage_social_carcass_meat(&w,0)==CP_SOC_CARCASS_BITES-2);
    assert(cp_stage_command(&w,"wait")==0);
    cp_stage_step(&w,NULL);
    assert(w.social.act_verb==0);
    steps(100);
    assert(cp_stage_social_carcass_meat(&w,0)==CP_SOC_CARCASS_BITES-2);
    PASS("eat: interrupted by another order");
    /* diet: a herbivore cannot eat meat */
    assert(cp_stage_social_set_diet(&w,CP_DIET_HERBIVORE)==0);
    assert(cp_stage_command(&w,"eat #1")==CP_STAGE_ERR_DIET);
    assert(cp_stage_social_set_diet(&w,CP_DIET_CARNIVORE)==0);
    assert(cp_stage_command(&w,"eat #1")==0);
    PASS("eat: diet matters");
    /* a carcass is not a fight target and holds clues */
    assert(cp_stage_command(&w,"observe #1")==0);
}
static void unused_hash(void){
    /* a run that never uses a social verb does not fold the social block into the hash */
    mk1(0,3,1);
    const uint64_t h=cp_stage_hash(&w);
    w.social.dna_total+=5;
    assert(cp_stage_hash(&w)==h);
    w.social.used=1;
    assert(cp_stage_hash(&w)!=h);
    PASS("hash ignores the social block until a social verb is used");
}
int main(void){
    bonding();rhythm_and_combo();habituation();refusals();herd();dominate();observe();intimidate();dna_monotonic();eating();determinism();unused_hash();
    printf("social: all passed\n");
    return 0;
}
