/* C2 social layer of the creature stage (docs/P4.md sections 2.1-2.3, G75 addendum): befriending skills, gifts, trust and
 * bonds, observe (A22 chains that teach moves), intimidate, and the Q43 loop (ally / dominate per species, DNA).
 *
 * Everything here is integer logic (positions are only compared as floats, as the rest of the stage does). The state lives
 * in CpStageWorld.social, is tracked from tick 0, and is folded into the world hash only once a social verb has been
 * accepted, so runs that never use one keep their hashes (the golden logs). */
#include "cpore/world.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>

const CpStageSkill CP_STAGE_SKILLS[CP_SOC_COUNT]={
    {"sing",2,8,2,8.f,6.f},{"dance",2,10,2,5.f,10.f},{"charm",1,6,2,4.f,4.f},{"pose",4,8,2,10.f,8.f}
};
const char *const CP_STAGE_ITEM_NAMES[CP_ITEM_COUNT]={"plant","fruit","meat","bone"};
#define GIFT_WINDUP 2
#define GIFT_ACTIVE 1
#define GIFT_RECOVERY 3
#define GIFT_RANGE 2.5f
#define GIFT_STAMINA 2.f
#define INT_WINDUP 3
#define INT_ACTIVE 6
#define INT_RECOVERY 4
#define INT_RANGE 12.f
#define INT_STAMINA 8.f
#define INT_COOLDOWN 100
#define EAT_RANGE 1.5f
#define COMBO_WINDOW 20
#define HAB_WINDOW 300
#define DECAY_IDLE 1200
#define DECAY_EVERY 600
#define HERALD_RANGE 6.f
#define HECKLE_PERMILLE 250
#define STAGGER_TICKS 20
#define CALM_TICKS 600
#define LEAVE_TICKS 200
#define AGGRO_TICKS 180
#define ALLY_NEED 3
#define HUNT_NEED 3

/* Trust deltas per skill and per gift class, by species (P4.md 2.1). */
static const struct { int8_t skill[CP_SOC_COUNT],gift[CP_ITEM_COUNT]; } PREF[CP_SOC_SPECIES]={
    {{12,8,6,-2},{6,12,-25,-10}},   /* Rondo, herbivore */
    {{6,12,8,4},{6,12,-25,-10}},    /* Zanco, herbivore */
    {{4,4,6,12},{-2,0,14,8}},       /* Espinodo, carnivore */
    {{-4,2,4,10},{-4,0,16,10}}      /* Garfio, carnivore, heckler */
};
static const uint8_t HERBIVORE[CP_SOC_SPECIES]={1,1,0,0};
static const uint8_t HECKLER[CP_SOC_SPECIES]={0,0,0,1};
/* One A22 chain per species: three things to watch, then the move it teaches. Moves are combat move ids that exist in
 * CP_COMBAT_MOVES (a lore chain that names a move the table does not have is simply not listed here). */
const CpStageChain CP_STAGE_CHAINS[CP_SOC_SPECIES]={
    {"rondo.c1","sprays sap at what chases it",CB_SPIT,{
        "watch it browse the sappy reeds, a hanging droplet on its muzzle",
        "see a herd mate flinch from the spray and leave it alone",
        "watch it purse its mouth and shoot a thread of sap at a pursuer"}},
    {"zanco.c1","flicks its tail to throw off pursuers",CB_TAIL_STRIKE,{
        "watch it stand with its heavy tail low in the tall grass",
        "see a herd mate bolt, and the tail whip behind it as it runs",
        "watch the tail snap sideways at something that got too close"}},
    {"espinodo.c1","lowers its spiny head and rams",CB_CHARGE,{
        "watch it scrape its crown spines on a rock to clean them",
        "see it rear back and dig in its hind legs against a rival",
        "watch it drive forward head down, crown first"}},
    {"garfio.c1","pins its prey with a fast bite",CB_BITE,{
        "watch it lie flat and still, jaws just clear of the ground",
        "see its head snap forward faster than the body follows",
        "watch it hold a bite and shake before letting go"}}
};

static float len2(float x,float z){return sqrtf(x*x+z*z);}
static float dist2(const CpStageCreature *a,const CpStageCreature *b){return len2(a->x-b->x,a->z-b->z);}
static int clampi(int x,int a,int b){return x<a?a:x>b?b:x;}
static int is_dead(const CpStageCreature *e){return e->dead||e->hp<=0;}
static int skill_verb(int v){return v==CP_STAGE_BEFRIEND||v==CP_STAGE_GIFT||v==CP_STAGE_INTIMIDATE||v==CP_STAGE_EAT;}
static void push(CpStageWorld *w,int type,int target,int move,float value,float x,float z){
    w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,0,target,move,value,x,z};
    w->ev_total++;
}

/* --- tiny FNV-1a for the hashed block --- */
static void hu(uint64_t *h,uint32_t v){
    for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}
}
uint64_t cp_stage_social_hash(const CpStageWorld *w){
    const CpStageSocial *s=&w->social;
    uint64_t h=14695981039346656037ULL;
    for(int i=0;i<4;i++)hu(&h,s->rng.s[i]);
    hu(&h,(uint32_t)s->dna_total);hu(&h,(uint32_t)s->dna_balance);
    for(int i=0;i<CP_ITEM_COUNT;i++)hu(&h,(uint32_t)s->items[i]);
    hu(&h,(uint32_t)s->act_verb);hu(&h,(uint32_t)s->act_target);hu(&h,(uint32_t)s->act_arg);hu(&h,(uint32_t)s->act_t);
    hu(&h,(uint32_t)s->act_len);hu(&h,(uint32_t)s->act_rhythm);hu(&h,(uint32_t)s->act_mult);
    hu(&h,(uint32_t)s->food);hu(&h,(uint32_t)s->diet);hu(&h,(uint32_t)s->stagger);hu(&h,(uint32_t)s->intimidate_cd);hu(&h,(uint32_t)s->obs_target);hu(&h,(uint32_t)s->obs_ticks);
    hu(&h,s->learned);hu(&h,s->tested);hu(&h,s->liked);hu(&h,s->species_seen);
    for(int i=0;i<CP_SOC_SPECIES;i++){
        hu(&h,(uint32_t)s->obs_items[i]);hu(&h,(uint32_t)s->kills[i]);hu(&h,(uint32_t)s->latched[i]);
        hu(&h,(uint32_t)s->resolution[i]);hu(&h,(uint32_t)s->first_met[i]);
    }
    for(int i=0;i<CP_DNA_SOURCES;i++)hu(&h,(uint32_t)s->dna_by_source[i]);
    hu(&h,(uint32_t)s->n_explored);
    for(int i=0;i<s->n_explored;i++)hu(&h,(uint32_t)s->explored[i]);
    for(int i=0;i<w->setup.n;i++){
        const CpStageSocialCreature *c=&s->c[i];
        hu(&h,(uint32_t)(uint16_t)c->trust);hu(&h,(uint32_t)(uint16_t)c->mood);
        hu(&h,(uint32_t)c->bonded|(uint32_t)c->ever_bonded<<8|(uint32_t)c->met<<16|(uint32_t)c->combo<<24);
        hu(&h,(uint32_t)c->last_contact);hu(&h,(uint32_t)c->calm_ticks);hu(&h,(uint32_t)c->leave_ticks);hu(&h,(uint32_t)c->aggro_ticks);
        hu(&h,(uint32_t)c->last_skill);hu(&h,(uint32_t)c->last_skill_tick);hu(&h,(uint32_t)c->carcass_seen);hu(&h,(uint32_t)c->eaten);
        for(int k=0;k<CP_SOC_COUNT;k++){hu(&h,(uint32_t)c->hab_tick[k]);hu(&h,c->hab_n[k]);}
    }
    return h;
}

void cp_stage_social_reset(CpStageWorld *w){
    CpStageSocial *s=&w->social;
    memset(s,0,sizeof *s);
    cp_rng_seed(&s->rng,w->setup.seed^0x534f4349u);
    s->food=CP_SOC_FOOD_START;
    s->diet=CP_DIET_OMNIVORE;
    s->items[CP_ITEM_PLANT]=2;
    s->items[CP_ITEM_FRUIT]=2;
    s->obs_target=0;
}

/* --- queries --- */
static int species_of(const CpStageWorld *w,int i){return w->wild[i].species;}
int cp_stage_social_relationship(const CpStageWorld *w,int i){
    const CpStageSocialCreature *c=&w->social.c[i];
    if(c->bonded)return CP_REL_ALLY;
    if(c->trust>=30)return CP_REL_TRUSTED;
    if(c->met||c->trust>0)return CP_REL_NEUTRAL;
    return CP_REL_STRANGER;
}
static int beat_phase(const CpStageWorld *w,int index){
    const uint32_t id=(uint32_t)index+1;
    return (int)((((id*2654435761u)^(w->setup.seed*40503u))>>7)%CP_SOC_BEAT);
}
int cp_stage_social_beat_in(const CpStageWorld *w,int index){
    const int d=(int)((w->tick+(uint32_t)beat_phase(w,index))%CP_SOC_BEAT);
    return d==0?0:CP_SOC_BEAT-d;
}
static int beat_offset(const CpStageWorld *w,int index,uint32_t tick){
    const int d=(int)((tick+(uint32_t)beat_phase(w,index))%CP_SOC_BEAT);
    return d<CP_SOC_BEAT-d?d:CP_SOC_BEAT-d;
}
int cp_stage_social_pacified(const CpStageWorld *w,int i){
    const CpStageSocialCreature *c=&w->social.c[i];
    return c->bonded||w->social.resolution[species_of(w,i)]==CP_RES_ALLY||c->calm_ticks>0||c->leave_ticks>0;
}
int cp_stage_social_leaving(const CpStageWorld *w,int i){
    return w->social.c[i].leave_ticks>0;
}
int cp_stage_social_shielded(const CpStageWorld *w,int i){
    return w->order.verb==CP_STAGE_GIFT&&w->order.target==i+1;
}
/* The stage's own hostility rule (territorial: the player is inside its home; aggressive: within 28 m), minus what the
 * social layer pacifies, plus a pack turned hostile by an attack on one of its bonded members. */
int cp_stage_social_hostile(const CpStageWorld *w,int i){
    const CpStageCreature *e=&w->wild[i];
    if(is_dead(e)||cp_stage_social_pacified(w,i))return 0;
    const CpStageSpecies *sp=&CP_STAGE_SPECIES[e->species];
    const float d=dist2(&w->player,e);
    const float territory=sp->temperament==CP_STAGE_TERRITORIAL?len2(w->player.x-e->home_x,w->player.z-e->home_z):d;
    int h=sp->temperament!=CP_STAGE_TIMID&&d<sp->sight&&territory<sp->hostile+cp_combat_body_radius(&e->profile)&&!w->cooldown_ticks;
    if(!h&&w->social.c[i].aggro_ticks>0&&!w->cooldown_ticks&&d<sp->sight*2)h=1;
    return h;
}
int cp_stage_social_species_present(const CpStageWorld *w){
    int mask=0,n=0;
    for(int i=0;i<w->setup.n;i++)if(!(mask&(1<<w->wild[i].species))){mask|=1<<w->wild[i].species;n++;}
    return n;
}
int cp_stage_social_species_resolved(const CpStageWorld *w){
    int mask=0,n=0;
    for(int i=0;i<w->setup.n;i++){
        const int sp=w->wild[i].species;
        if(!(mask&(1<<sp))){
            mask|=1<<sp;
            if(w->social.resolution[sp]!=CP_RES_OPEN)n++;
        }
    }
    return n;
}
int cp_stage_social_give(CpStageWorld *w,int item,int count){
    if(!w||item<0||item>=CP_ITEM_COUNT||count<=0||count>1000)return -1;
    w->social.items[item]+=count;
    w->social.used=1;
    w->hash=cp_stage_hash(w);
    return 0;
}
int cp_stage_social_spend(CpStageWorld *w,int amount){
    if(!w||amount<0||amount>w->social.dna_balance)return -1;
    w->social.dna_balance-=amount;
    w->social.used=1;
    w->hash=cp_stage_hash(w);
    return 0;
}

int cp_stage_social_set_diet(CpStageWorld *w,int diet){
    if(!w||diet<0||diet>CP_DIET_OMNIVORE)return -1;
    w->social.diet=diet;
    w->hash=cp_stage_hash(w);
    return 0;
}
int cp_stage_social_carcass_meat(const CpStageWorld *w,int i){
    return is_dead(&w->wild[i])?CP_SOC_CARCASS_BITES-w->social.c[i].eaten:0;
}
/* --- DNA --- */
static void award(CpStageWorld *w,int amount,int source,int target){
    CpStageSocial *s=&w->social;
    if(amount<=0)return;
    s->dna_total+=amount;
    s->dna_balance+=amount;
    s->dna_by_source[source]+=amount;
    push(w,CP_STAGE_EV_DNA,target,source,(float)amount,(float)s->dna_total,(float)s->dna_balance);
}
static void resolve_species(CpStageWorld *w,int sp,int how,int target){
    CpStageSocial *s=&w->social;
    s->resolution[sp]=how;
    push(w,CP_STAGE_EV_SPECIES_RESOLVED,target,sp,(float)how,0,0);
    award(w,20,how==CP_RES_ALLY?CP_DNA_ALLY:CP_DNA_DOMINATE,target);
}
static void check_bond(CpStageWorld *w,int i){
    CpStageSocial *s=&w->social;
    CpStageSocialCreature *c=&s->c[i];
    const int sp=species_of(w,i);
    if(c->bonded||c->trust<CP_SOC_BOND_TRUST)return;
    c->bonded=1;
    s->latched[sp]++;
    push(w,CP_STAGE_EV_BOND_MADE,i+1,sp,(float)c->trust,0,0);
    if(!c->ever_bonded){
        c->ever_bonded=1;
        award(w,8,CP_DNA_BOND,i+1);
    }
    if(s->resolution[sp]==CP_RES_OPEN&&s->latched[sp]>=ALLY_NEED)resolve_species(w,sp,CP_RES_ALLY,i+1);
}
static void add_trust(CpStageWorld *w,int i,int delta){
    CpStageSocialCreature *c=&w->social.c[i];
    c->trust=(int16_t)clampi(c->trust+delta,0,100);
    check_bond(w,i);
}
static void add_mood(CpStageSocialCreature *c,int delta){
    c->mood=(int16_t)clampi(c->mood+delta,-50,50);
}
static void contact(CpStageWorld *w,int i){
    CpStageSocialCreature *c=&w->social.c[i];
    c->met=1;
    c->last_contact=(int32_t)w->tick+1;
}

/* --- orders --- */
static int refuses(const CpStageWorld *w,int i){
    const CpStageSocialCreature *c=&w->social.c[i];
    if(c->bonded||w->social.resolution[species_of(w,i)]==CP_RES_ALLY)return c->mood<=-20;
    if(cp_stage_social_hostile(w,i))return 1;
    if(CP_STAGE_SPECIES[w->wild[i].species].temperament==CP_STAGE_AGGRESSIVE&&c->calm_ticks<=0)return 1;
    return c->mood<=-20;
}
float cp_stage_social_reach(const CpStageWorld *w,const CpStageInput *a){
    if(a->target<1||a->target>w->setup.n)return 0;
    const float r=cp_combat_body_radius(&w->wild[a->target-1].profile);
    switch(a->verb){
        case CP_STAGE_BEFRIEND:return CP_STAGE_SKILLS[a->move<0||a->move>=CP_SOC_COUNT?0:a->move].range+r-.4f;
        case CP_STAGE_GIFT:return GIFT_RANGE+r-.4f;
        case CP_STAGE_INTIMIDATE:return INT_RANGE+r-.4f;
        case CP_STAGE_EAT:return EAT_RANGE+r-.2f;
        default:return 1e9f;   /* observe: stay where you are */
    }
}
static float verb_range(const CpStageInput *a){
    if(a->verb==CP_STAGE_BEFRIEND)return CP_STAGE_SKILLS[a->move].range;
    if(a->verb==CP_STAGE_GIFT)return GIFT_RANGE;
    if(a->verb==CP_STAGE_INTIMIDATE)return INT_RANGE;
    if(a->verb==CP_STAGE_EAT)return EAT_RANGE;
    return 1e9f;
}
static float verb_stamina(const CpStageInput *a){
    if(a->verb==CP_STAGE_BEFRIEND)return CP_STAGE_SKILLS[a->move].stamina;
    if(a->verb==CP_STAGE_GIFT)return GIFT_STAMINA;
    if(a->verb==CP_STAGE_INTIMIDATE)return INT_STAMINA;
    return 0;
}
int cp_stage_social_order_check(CpStageWorld *w,const CpStageInput *a){
    if(w->active>=0)return CP_STAGE_ERR_IN_FIGHT;
    if(w->respawn_ticks>0)return CP_STAGE_ERR_IN_FIGHT;
    if(a->target<1||a->target>w->setup.n)return -2;
    const int i=a->target-1;
    if(a->verb==CP_STAGE_OBSERVE)return 0;   /* a living creature or a carcass (its remains hold clues too) */
    if(a->verb==CP_STAGE_EAT){
        if(!is_dead(&w->wild[i])||cp_stage_social_carcass_meat(w,i)<=0)return -2;
        if(w->social.diet==CP_DIET_HERBIVORE)return CP_STAGE_ERR_DIET;
        if(w->social.food>=CP_SOC_FOOD_MAX)return CP_STAGE_ERR_FULL;
        return 0;
    }
    if(is_dead(&w->wild[i]))return -2;
    if(w->social.stagger>0)return CP_STAGE_ERR_STAGGERED;
    if(a->verb==CP_STAGE_BEFRIEND){
        if(a->move<0||a->move>=CP_SOC_COUNT)return CP_STAGE_ERR_BAD_SKILL;
        if(refuses(w,i))return CP_STAGE_ERR_REFUSES;
    }
    else if(a->verb==CP_STAGE_GIFT){
        if(a->move<0||a->move>=CP_ITEM_COUNT)return CP_STAGE_ERR_BAD_SKILL;
        if(w->social.items[a->move]<=0)return CP_STAGE_ERR_NO_ITEM;
    }
    else if(a->verb==CP_STAGE_INTIMIDATE){
        if(w->social.intimidate_cd>0)return CP_STAGE_ERR_BUSY;
    }
    if(w->player.stamina<verb_stamina(a))return CP_STAGE_ERR_NO_STAMINA;
    return 0;
}

/* --- the per-tick rules --- */
static void end_order(CpStageWorld *w){
    w->order=(CpStageInput){0};
}
static void cancel_action(CpStageWorld *w,int reason){
    CpStageSocial *s=&w->social;
    if(s->act_verb)push(w,CP_STAGE_EV_SOCIAL_CANCELLED,s->act_target,s->act_verb,(float)reason,0,0);
    s->act_verb=s->act_target=s->act_arg=s->act_t=s->act_len=s->act_rhythm=s->act_mult=0;
}
void cp_stage_social_on_fight(CpStageWorld *w,int index){
    CpStageSocial *s=&w->social;
    if(s->act_verb)cancel_action(w,3);
    s->obs_target=s->obs_ticks=0;
    if(skill_verb(w->order.verb)||w->order.verb==CP_STAGE_OBSERVE)end_order(w);
    const int attacked=w->order.verb==CP_STAGE_ATTACK&&w->order.target==index+1;
    if(!attacked)return;
    const int sp=species_of(w,index);
    CpStageSocialCreature *c=&s->c[index];
    if(c->bonded){
        c->bonded=0;
        c->trust=0;
        s->latched[sp]--;
        if(s->resolution[sp]==CP_RES_ALLY)s->resolution[sp]=CP_RES_OPEN;   /* the alliance is cancelled */
        push(w,CP_STAGE_EV_BOND_BROKEN,index+1,sp,0,0,0);
        for(int j=0;j<w->setup.n;j++)
            if(j!=index&&w->wild[j].species==sp&&!is_dead(&w->wild[j])&&dist2(&w->wild[j],&w->wild[index])<45.f)s->c[j].aggro_ticks=AGGRO_TICKS;
    }
    /* hunting one herd member lowers the herd's trust */
    for(int j=0;j<w->setup.n;j++)
        if(j!=index&&w->wild[j].species==sp&&!is_dead(&w->wild[j])&&dist2(&w->wild[j],&w->wild[index])<30.f)
            s->c[j].trust=(int16_t)clampi(s->c[j].trust-10,0,100);
}
void cp_stage_social_on_kill(CpStageWorld *w,int index){
    CpStageSocial *s=&w->social;
    const int sp=species_of(w,index);
    s->kills[sp]++;
    award(w,6,CP_DNA_KILL,index+1);
    s->items[CP_ITEM_MEAT]++;     /* a meat chunk from the carcass (gifts need a source until pick/eat exist) */
    if(s->resolution[sp]==CP_RES_OPEN&&s->kills[sp]>=HUNT_NEED)resolve_species(w,sp,CP_RES_HUNTED,index+1);
}

static int next_u32(CpStageSocial *s){
    return (int)(cp_rng_u32(&s->rng)>>1);
}
static void apply_skill(CpStageWorld *w,int i,int sk){
    CpStageSocial *s=&w->social;
    CpStageSocialCreature *c=&s->c[i];
    const int sp=species_of(w,i),t=(int)w->tick;
    /* the rival's roll is drawn whether or not a rival is near (fixed draws per decision) */
    const int roll=next_u32(s)%1000;
    int heckler=0;
    for(int j=0;j<w->setup.n;j++)
        if(j!=i&&HECKLER[w->wild[j].species]&&!is_dead(&w->wild[j])&&dist2(&w->wild[j],&w->wild[i])<HERALD_RANGE)heckler=1;
    if(heckler&&roll<HECKLE_PERMILLE){
        add_mood(c,-5);
        s->stagger=STAGGER_TICKS;
        push(w,CP_STAGE_EV_SOCIAL_CANCELLED,i+1,CP_STAGE_BEFRIEND,2.f,0,0);
        s->act_rhythm=-1;   /* tells the caller the skill was heckled */
        return;
    }
    const int delta=PREF[sp].skill[sk];
    s->tested|=1u<<(sp*8+sk);
    if(delta>0)s->liked|=1u<<(sp*8+sk);else s->liked&=~(1u<<(sp*8+sk));
    int gain,mult=100;
    if(delta<=0)gain=delta;
    else{
        const int rhythm=(sk==CP_SOC_SING||sk==CP_SOC_DANCE)&&s->act_rhythm>0;
        const int timing=rhythm?150:100,combo=c->combo==0?100:c->combo==1?150:200;
        mult=timing*combo/100;
        if(mult>200)mult=200;
        int hab=100;
        if(c->hab_tick[sk]&&t+1-c->hab_tick[sk]<HAB_WINDOW){
            if(c->hab_n[sk]<255)c->hab_n[sk]++;
        }
        else c->hab_n[sk]=0;
        hab=c->hab_n[sk]==0?100:c->hab_n[sk]==1?50:25;
        const int mood=c->mood,moodf=mood>=30?150:mood>=10?125:100;
        gain=(int)((long long)delta*moodf*mult*hab/1000000LL);
        if(gain<1)gain=1;
    }
    c->hab_tick[sk]=t+1;
    contact(w,i);
    add_trust(w,i,gain);
    push(w,CP_STAGE_EV_SKILL,i+1,sk|(s->act_rhythm>0?256:0)|(c->combo<<9),(float)gain,(float)mult,(float)c->trust);
}
static void apply_gift(CpStageWorld *w,int i,int item){
    CpStageSocial *s=&w->social;
    CpStageSocialCreature *c=&s->c[i];
    const int sp=species_of(w,i),delta=PREF[sp].gift[item];
    s->items[item]--;
    s->tested|=1u<<(sp*8+4+item);
    if(delta>0)s->liked|=1u<<(sp*8+4+item);else s->liked&=~(1u<<(sp*8+4+item));
    contact(w,i);
    int calm=0;
    if(item==CP_ITEM_MEAT&&HERBIVORE[sp]){
        /* an insult, and the herd saw it */
        add_mood(c,-15);
        for(int j=0;j<w->setup.n;j++)
            if(j!=i&&w->wild[j].species==sp&&!is_dead(&w->wild[j])&&dist2(&w->wild[j],&w->wild[i])<20.f)
                s->c[j].trust=(int16_t)clampi(s->c[j].trust-5,0,100);
    }
    else if(delta>=10){
        add_mood(c,10);
        c->calm_ticks=CALM_TICKS;
        c->aggro_ticks=0;
        calm=1;
    }
    else if(delta<=-10)add_mood(c,delta/2);
    add_trust(w,i,delta);
    push(w,CP_STAGE_EV_GIFT,i+1,item,(float)delta,(float)calm,(float)c->trust);
}
static void apply_intimidate(CpStageWorld *w,int i){
    CpStageSocial *s=&w->social;
    const CpStageCreature *e=&w->wild[i];
    const CpStageSpecies *sp=&CP_STAGE_SPECIES[e->species];
    const int a=next_u32(s)%20,b=next_u32(s)%20;   /* two draws, always */
    const CpCombatProfile *p=&w->player.profile;
    const int mine=6*(p->mouth+p->charge+p->spit+p->tail+p->guard)+(int)(20.f*w->player.hp/p->hp)+a;
    const int base=sp->temperament==CP_STAGE_TIMID?20:sp->temperament==CP_STAGE_TERRITORIAL?60:80;
    const int theirs=base+(int)(e->profile.hp/4)+b;
    const int win=mine>theirs;
    s->intimidate_cd=INT_COOLDOWN;
    if(win){
        s->c[i].leave_ticks=LEAVE_TICKS;
        s->c[i].aggro_ticks=0;
    }
    push(w,CP_STAGE_EV_INTIMIDATE,i+1,0,(float)win,(float)mine,(float)theirs);
}
static void begin_action(CpStageWorld *w,int i){
    CpStageSocial *s=&w->social;
    const CpStageInput *o=&w->order;
    int windup,active,recovery,sk=-1;
    if(o->verb==CP_STAGE_BEFRIEND){
        sk=o->move;
        windup=CP_STAGE_SKILLS[sk].windup;active=CP_STAGE_SKILLS[sk].active;recovery=CP_STAGE_SKILLS[sk].recovery;
    }
    else if(o->verb==CP_STAGE_GIFT){windup=GIFT_WINDUP;active=GIFT_ACTIVE;recovery=GIFT_RECOVERY;}
    else{windup=INT_WINDUP;active=INT_ACTIVE;recovery=INT_RECOVERY;}
    w->player.stamina-=verb_stamina(o);
    if(w->player.stamina<0)w->player.stamina=0;
    s->act_verb=o->verb;s->act_target=o->target;s->act_arg=o->move;s->act_t=0;s->act_len=windup+active+recovery;
    s->act_rhythm=0;s->act_mult=windup;   /* act_mult doubles as the wind-up length while the action runs */
    if(sk>=0){
        CpStageSocialCreature *c=&s->c[i];
        const int t=(int)w->tick;
        if(c->last_skill>0&&c->last_skill!=sk+1&&t-c->last_skill_tick<=COMBO_WINDOW){if(c->combo<2)c->combo++;}
        else c->combo=0;
        c->last_skill=sk+1;
        c->last_skill_tick=t;
        contact(w,i);
    }
}
static void social_events(CpStageWorld *w){
    CpStageSocial *s=&w->social;
    const int t=(int)w->tick;
    for(int i=0;i<w->setup.n;i++){
        CpStageSocialCreature *c=&s->c[i];
        if(c->calm_ticks>0)c->calm_ticks--;
        if(c->leave_ticks>0)c->leave_ticks--;
        if(c->aggro_ticks>0)c->aggro_ticks--;
        if(c->last_contact>0&&c->trust>0){
            const int idle=t+1-c->last_contact;
            if(idle>=DECAY_IDLE&&(idle-DECAY_IDLE)%DECAY_EVERY==0)c->trust--;
        }
        if((t+i)%30==0){
            const uint32_t d=cp_rng_u32(&s->rng);   /* one draw per drift step, always */
            if(c->mood>0)c->mood--;else if(c->mood<0)c->mood++;
            if(d&1)add_mood(c,(d&2)?1:-1);
        }
        if(!is_dead(&w->wild[i])){
            const int sp=w->wild[i].species;
            if(!(s->species_seen&(1u<<sp))&&dist2(&w->player,&w->wild[i])<=30.f){
                s->species_seen|=1u<<sp;
                s->first_met[sp]=t+1;
                award(w,3,CP_DNA_SEEN,i+1);
            }
        }
    }
    if(t%CP_SOC_FOOD_DECAY==CP_SOC_FOOD_DECAY-1&&s->food>0)s->food--;
    /* exploration: the first entry into each 40 m cell, 40 DNA at most */
    if(s->n_explored<CP_SOC_EXPLORE_MAX){
        const int cx=(int)floorf(w->player.x/40.f),cz=(int)floorf(w->player.z/40.f),id=(cx+1000)*2048+(cz+1000);
        int seen=0;
        for(int k=0;k<s->n_explored;k++)if(s->explored[k]==id)seen=1;
        if(!seen){
            s->explored[s->n_explored++]=id;
            award(w,1,CP_DNA_EXPLORE,0);
        }
    }
}
void cp_stage_social_step(CpStageWorld *w){
    CpStageSocial *s=&w->social;
    if(s->stagger>0)s->stagger--;
    if(s->intimidate_cd>0)s->intimidate_cd--;
    social_events(w);
    const CpStageInput *o=&w->order;
    if(s->act_verb&&(o->verb!=s->act_verb||o->target!=s->act_target))cancel_action(w,1);
    if(s->obs_target&&!(o->verb==CP_STAGE_OBSERVE&&o->target==s->obs_target)){
        if(s->obs_ticks>0)push(w,CP_STAGE_EV_SOCIAL_CANCELLED,s->obs_target,CP_STAGE_OBSERVE,1.f,0,0);
        s->obs_target=s->obs_ticks=0;
    }
    if(w->active>=0)return;
    if(skill_verb(o->verb)){
        const int i=o->target-1;
        if(o->verb==CP_STAGE_EAT&&i>=0&&i<w->setup.n){
            const CpStageCreature *e=&w->wild[i];
            if(!is_dead(e)||cp_stage_social_carcass_meat(w,i)<=0||s->food>=CP_SOC_FOOD_MAX){
                if(s->act_verb)cancel_action(w,6);
                end_order(w);
                return;
            }
            if(!s->act_verb){
                if(dist2(&w->player,e)-cp_combat_body_radius(&e->profile)>EAT_RANGE+.05f)return;
                s->act_verb=CP_STAGE_EAT;s->act_target=o->target;s->act_arg=0;s->act_t=0;s->act_len=0;s->act_rhythm=0;s->act_mult=0;
                return;
            }
            if(dist2(&w->player,e)-cp_combat_body_radius(&e->profile)>EAT_RANGE+2.5f){cancel_action(w,4);end_order(w);return;}
            if(++s->act_t%CP_SOC_BITE_TICKS==0){
                CpStageSocialCreature *c=&s->c[i];
                const int before=s->food;
                s->food=s->food+CP_SOC_BITE_FOOD>CP_SOC_FOOD_MAX?CP_SOC_FOOD_MAX:s->food+CP_SOC_BITE_FOOD;
                c->eaten++;
                if(!c->carcass_seen){c->carcass_seen=1;award(w,3,CP_DNA_CARCASS,i+1);}
                const int left=CP_SOC_CARCASS_BITES-c->eaten;
                if(left<=0)s->items[CP_ITEM_BONE]++;
                push(w,CP_STAGE_EV_EAT,i+1,left,(float)(s->food-before),(float)s->food,(float)s->items[CP_ITEM_BONE]);
            }
            return;
        }
        if(i<0||i>=w->setup.n||is_dead(&w->wild[i])){
            cancel_action(w,-2);
            w->last_error=-2;
            end_order(w);
            return;
        }
        const float gap=dist2(&w->player,&w->wild[i])-cp_combat_body_radius(&w->wild[i].profile),range=verb_range(o);
        if(!s->act_verb){
            if(gap>range+.05f)return;   /* still walking in */
            int rc=0;
            if(o->verb==CP_STAGE_BEFRIEND&&refuses(w,i))rc=CP_STAGE_ERR_REFUSES;
            else if(o->verb==CP_STAGE_GIFT&&s->items[o->move]<=0)rc=CP_STAGE_ERR_NO_ITEM;
            else if(o->verb==CP_STAGE_INTIMIDATE&&s->intimidate_cd>0)rc=CP_STAGE_ERR_BUSY;
            else if(s->stagger>0)rc=CP_STAGE_ERR_STAGGERED;
            else if(w->player.stamina<verb_stamina(o))rc=CP_STAGE_ERR_NO_STAMINA;
            if(rc){
                push(w,CP_STAGE_EV_SOCIAL_CANCELLED,o->target,o->verb,(float)rc,0,0);
                w->last_error=rc;
                end_order(w);
                return;
            }
            begin_action(w,i);
            return;
        }
        if(gap>range+2.5f){cancel_action(w,4);end_order(w);return;}
        s->act_t++;
        const int windup=s->act_mult;
        int active=0;
        if(o->verb==CP_STAGE_BEFRIEND)active=CP_STAGE_SKILLS[s->act_arg].active;
        else if(o->verb==CP_STAGE_GIFT)active=GIFT_ACTIVE;
        else active=INT_ACTIVE;
        if(s->act_t==windup&&o->verb==CP_STAGE_BEFRIEND)s->act_rhythm=beat_offset(w,i,w->tick)<=CP_SOC_WINDOW?1:0;
        if(s->act_t==windup+active){
            if(o->verb==CP_STAGE_BEFRIEND){
                const int sk=s->act_arg;
                apply_skill(w,i,sk);
                if(s->act_rhythm<0){          /* heckled: the skill is lost */
                    s->act_verb=0;s->act_t=s->act_len=s->act_rhythm=s->act_mult=0;
                    end_order(w);
                    return;
                }
            }
            else if(o->verb==CP_STAGE_GIFT)apply_gift(w,i,s->act_arg);
            else apply_intimidate(w,i);
        }
        if(s->act_t>=s->act_len){
            s->act_verb=0;s->act_t=s->act_len=s->act_rhythm=s->act_mult=0;
            end_order(w);
        }
        return;
    }
    if(o->verb==CP_STAGE_OBSERVE){
        const int i=o->target-1;
        if(i<0||i>=w->setup.n){
            w->last_error=-2;
            end_order(w);
            return;
        }
        const int sp=w->wild[i].species;
        if(s->obs_items[sp]>=CP_SOC_CHAIN_ITEMS){
            push(w,CP_STAGE_EV_SOCIAL_CANCELLED,o->target,CP_STAGE_OBSERVE,6.f,0,0);
            end_order(w);
            return;
        }
        const CpStageSpecies *spec=&CP_STAGE_SPECIES[sp];
        const float d=dist2(&w->player,&w->wild[i]);
        const int dead=is_dead(&w->wild[i]);
        const int seen=!dead&&(cp_stage_social_hostile(w,i)||(spec->temperament==CP_STAGE_TIMID&&d<spec->sight*.5f)||d<3.f);
        if(d>CP_SOC_OBSERVE_RANGE||seen||w->player.speed>1.f){
            if(s->obs_ticks>0)push(w,CP_STAGE_EV_SOCIAL_CANCELLED,o->target,CP_STAGE_OBSERVE,5.f,0,0);
            s->obs_ticks=0;
            return;
        }
        s->obs_target=o->target;
        if(++s->obs_ticks>=CP_SOC_OBSERVE_TICKS){
            const int item=s->obs_items[sp]++;
            s->obs_ticks=0;
            push(w,CP_STAGE_EV_OBSERVE,o->target,item,(float)sp,(float)s->obs_items[sp],0);
            if(s->obs_items[sp]>=CP_SOC_CHAIN_ITEMS){
                const int mv=CP_STAGE_CHAINS[sp].move;
                if(mv>=0&&mv<CB_MOVE_COUNT&&!(CP_COMBAT_MOVES[mv].flags&CB_F_SELF))s->learned|=1u<<mv;
                push(w,CP_STAGE_EV_CHAIN_DONE,o->target,mv,(float)sp,0,0);
                s->obs_target=0;
                end_order(w);
            }
        }
    }
}

/* --- text commands: befriend #id <skill>, gift #id <item>, observe #id, intimidate #id --- */
static int find_name(const char *name,const char *const *names,int n){
    for(int i=0;i<n;i++)if(strcasecmp(name,names[i])==0)return i;
    char *end;
    long v=strtol(name,&end,10);
    if(*name&&!*end&&v>=0&&v<n)return (int)v;
    return -1;
}
int cp_stage_social_parse(const char *text,CpStageInput *out,int *rc){
    CpStageInput a={0};
    char extra,word[32];
    const char *skill_names[CP_SOC_COUNT];
    for(int i=0;i<CP_SOC_COUNT;i++)skill_names[i]=CP_STAGE_SKILLS[i].name;
    *rc=0;
    if(sscanf(text,"befriend #%d %31s %c",&a.target,word,&extra)==2){
        a.verb=CP_STAGE_BEFRIEND;
        a.move=find_name(word,skill_names,CP_SOC_COUNT);
        if(a.move<0)*rc=CP_STAGE_ERR_BAD_SKILL;
    }
    else if(sscanf(text,"gift #%d %31s %c",&a.target,word,&extra)==2){
        a.verb=CP_STAGE_GIFT;
        a.move=find_name(word,CP_STAGE_ITEM_NAMES,CP_ITEM_COUNT);
        if(a.move<0)*rc=CP_STAGE_ERR_BAD_SKILL;
    }
    else if(sscanf(text,"observe #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_OBSERVE;
    else if(sscanf(text,"intimidate #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_INTIMIDATE;
    else if(sscanf(text,"eat #%d %c",&a.target,&extra)==1)a.verb=CP_STAGE_EAT;
    else return 0;
    *out=a;
    return 1;
}
int cp_stage_social_legal(const CpStageWorld *w,int verb){
    if(w->active>=0)return 0;
    int any=0;
    if(verb==CP_STAGE_EAT){
        for(int i=0;i<w->setup.n;i++)if(cp_stage_social_carcass_meat(w,i)>0&&dist2(&w->player,&w->wild[i])<40.f)return w->social.diet!=CP_DIET_HERBIVORE&&w->social.food<CP_SOC_FOOD_MAX;
        return 0;
    }
    for(int i=0;i<w->setup.n;i++)if(!is_dead(&w->wild[i]))any=1;
    if(!any)return 0;
    if(verb==CP_STAGE_GIFT){
        for(int k=0;k<CP_ITEM_COUNT;k++)if(w->social.items[k]>0)return 1;
        return 0;
    }
    return 1;
}

/* --- observation --- */
typedef struct { char *out;size_t cap,used;int failed; } Buf;
static void bp(Buf *b,const char *fmt,...){
    if(b->failed)return;
    va_list args;
    va_start(args,fmt);
    const int n=vsnprintf(b->out+b->used,b->cap-b->used,fmt,args);
    va_end(args);
    if(n<0||(size_t)n>=b->cap-b->used){b->failed=1;return;}
    b->used+=(size_t)n;
}
static const char *TEMPER[3]={"timid","territorial","aggressive"};
static const char *REL[4]={"stranger","neutral","trusted","ally"};
static const char *RES[3]={"open","ally","hunted"};
static const char *mood_label(int m){return m<=-20?"upset":m<0?"wary":m<20?"calm":"joyful";}
static const char *trust_band(const CpStageSocialCreature *c){
    return c->bonded?"bonded":c->trust>=40?"high":c->trust>=15?"mid":c->trust>0?"low":"none";
}
int cp_stage_social_creature_json(const CpStageWorld *w,int i,char *out,size_t cap){
    const CpStageSocial *s=&w->social;
    const CpStageSocialCreature *c=&s->c[i];
    const int sp=species_of(w,i);
    Buf b={out,cap,0,0};
    bp(&b,",\"temper\":\"%s\",\"diet\":\"%s\",\"relationship\":\"%s\",\"trust\":%d,\"trust_band\":\"%s\",\"bonded\":%s,\"mood\":\"%s\",\"mood_n\":%d,\"beat_in\":%d,\"hostile\":%s,\"calm\":%s,\"leaving\":%s,\"refuses_social\":%s",
       TEMPER[CP_STAGE_SPECIES[sp].temperament],HERBIVORE[sp]?"herbivore":"carnivore",REL[cp_stage_social_relationship(w,i)],c->trust,trust_band(c),c->bonded?"true":"false",
       mood_label(c->mood),c->mood,cp_stage_social_beat_in(w,i),cp_stage_social_hostile(w,i)?"true":"false",c->calm_ticks>0?"true":"false",c->leave_ticks>0?"true":"false",refuses(w,i)?"true":"false");
    bp(&b,",\"known_likes\":[");
    int n=0;
    for(int k=0;k<8;k++)if((s->tested&(1u<<(sp*8+k)))&&(s->liked&(1u<<(sp*8+k)))){
        bp(&b,"%s\"%s\"",n++?",":"",k<4?CP_STAGE_SKILLS[k].name:CP_STAGE_ITEM_NAMES[k-4]);
    }
    bp(&b,"],\"known_dislikes\":[");
    n=0;
    for(int k=0;k<8;k++)if((s->tested&(1u<<(sp*8+k)))&&!(s->liked&(1u<<(sp*8+k)))){
        bp(&b,"%s\"%s\"",n++?",":"",k<4?CP_STAGE_SKILLS[k].name:CP_STAGE_ITEM_NAMES[k-4]);
    }
    bp(&b,"]");
    return b.failed?-1:(int)b.used;
}
int cp_stage_social_json(const CpStageWorld *w,char *out,size_t cap){
    const CpStageSocial *s=&w->social;
    Buf b={out,cap,0,0};
    bp(&b,"{\"dna_total\":%d,\"dna_balance\":%d,\"dna_sources\":{\"kill\":%d,\"bond\":%d,\"ally\":%d,\"dominate\":%d,\"carcass\":%d,\"explore\":%d,\"species_seen\":%d},",
       s->dna_total,s->dna_balance,s->dna_by_source[CP_DNA_KILL],s->dna_by_source[CP_DNA_BOND],s->dna_by_source[CP_DNA_ALLY],s->dna_by_source[CP_DNA_DOMINATE],
       s->dna_by_source[CP_DNA_CARCASS],s->dna_by_source[CP_DNA_EXPLORE],s->dna_by_source[CP_DNA_SEEN]);
    bp(&b,"\"food\":{\"meter\":%d,\"max\":%d,\"diet\":\"%s\"},",s->food,CP_SOC_FOOD_MAX,s->diet==CP_DIET_HERBIVORE?"herbivore":s->diet==CP_DIET_CARNIVORE?"carnivore":"omnivore");
    bp(&b,"\"inventory\":{");
    for(int k=0;k<CP_ITEM_COUNT;k++)bp(&b,"%s\"%s\":%d",k?",":"",CP_STAGE_ITEM_NAMES[k],s->items[k]);
    bp(&b,"},\"progress\":{\"resolved\":%d,\"total\":%d},\"species\":[",cp_stage_social_species_resolved(w),cp_stage_social_species_present(w));
    int comma=0,mask=0;
    for(int i=0;i<w->setup.n;i++){
        const int sp=w->wild[i].species;
        if(mask&(1<<sp))continue;
        mask|=1<<sp;
        bp(&b,"%s{\"name\":\"%s\",\"temper\":\"%s\",\"seen\":%s,\"bonded\":%d,\"kills\":%d,\"need\":%d,\"resolution\":\"%s\"}",comma?",":"",CP_STAGE_SPECIES[sp].name,
           TEMPER[CP_STAGE_SPECIES[sp].temperament],(s->species_seen&(1u<<sp))?"true":"false",s->latched[sp],s->kills[sp],ALLY_NEED,RES[s->resolution[sp]]);
        comma=1;
    }
    bp(&b,"],\"observe\":[");
    comma=0;
    mask=0;
    for(int i=0;i<w->setup.n;i++){
        const int sp=w->wild[i].species;
        if(mask&(1<<sp))continue;
        mask|=1<<sp;
        const int n=s->obs_items[sp];
        if(n==0&&s->obs_target!=i+1)continue;
        bp(&b,"%s{\"species\":\"%s\",\"chain\":\"%s\",\"revealed\":[",comma?",":"",CP_STAGE_SPECIES[sp].name,CP_STAGE_CHAINS[sp].id);
        for(int k=0;k<n;k++){
            bp(&b,"%s\"%s\"",k?",":"",CP_STAGE_CHAINS[sp].observe[k]);
        }
        bp(&b,"],\"total\":%d,\"complete\":%s,\"progress\":%d,\"progress_max\":%d",CP_SOC_CHAIN_ITEMS,n>=CP_SOC_CHAIN_ITEMS?"true":"false",
           s->obs_target==i+1?s->obs_ticks:0,CP_SOC_OBSERVE_TICKS);
        if(n>=CP_SOC_CHAIN_ITEMS)bp(&b,",\"trait\":\"%s\",\"teaches\":\"%s\"",CP_STAGE_CHAINS[sp].trait,CP_STAGE_CHAINS[sp].move>=0?cp_combat_move_name(CP_STAGE_CHAINS[sp].move):"none");
        bp(&b,"}");
        comma=1;
    }
    bp(&b,"],\"skills\":[");
    for(int k=0;k<CP_SOC_COUNT;k++){
        const CpStageSkill *sk=&CP_STAGE_SKILLS[k];
        bp(&b,"%s{\"id\":%d,\"name\":\"%s\",\"windup_ticks\":%d,\"active_ticks\":%d,\"recover_ticks\":%d,\"range_m\":%.1f,\"stamina_cost\":%.1f}",k?",":"",k,sk->name,sk->windup,sk->active,sk->recovery,sk->range,sk->stamina);
    }
    bp(&b,"],\"beat_ticks\":%d,\"rhythm_window\":%d,\"stagger\":%d,\"intimidate_cooldown\":%d,\"action\":",CP_SOC_BEAT,CP_SOC_WINDOW,s->stagger,s->intimidate_cd);
    if(s->act_verb)bp(&b,"{\"verb\":\"%s\",\"target\":%d,\"t\":%d,\"len\":%d,\"windup\":%d}",s->act_verb==CP_STAGE_BEFRIEND?"befriend":s->act_verb==CP_STAGE_GIFT?"gift":s->act_verb==CP_STAGE_EAT?"eat":"intimidate",s->act_target,s->act_t,s->act_len,s->act_mult);
    else bp(&b,"null");
    bp(&b,"}");
    return b.failed?-1:(int)b.used;
}
static const char *source_name(int k){
    static const char *n[CP_DNA_SOURCES]={"kill","bond","ally","dominate","carcass","explore","species_seen"};
    return k>=0&&k<CP_DNA_SOURCES?n[k]:"unknown";
}
int cp_stage_social_event_json(const CpStageEvent *e,char *out,size_t cap){
    Buf b={out,cap,0,0};
    switch(e->type){
        case CP_STAGE_EV_SKILL:
            bp(&b,"{\"tick\":%u,\"type\":\"skill\",\"target\":%d,\"skill\":\"%s\",\"trust_gain\":%.0f,\"trust\":%.0f,\"multiplier\":%.0f,\"in_rhythm\":%s,\"combo\":%d}",e->tick,e->target,CP_STAGE_SKILLS[e->move&255].name,
               e->value,e->z,e->x,(e->move&256)?"true":"false",(e->move>>9)&3);break;
        case CP_STAGE_EV_GIFT:
            bp(&b,"{\"tick\":%u,\"type\":\"gift\",\"target\":%d,\"item\":\"%s\",\"trust_change\":%.0f,\"trust\":%.0f,\"calmed\":%s}",e->tick,e->target,CP_STAGE_ITEM_NAMES[e->move],e->value,e->z,e->x>0?"true":"false");break;
        case CP_STAGE_EV_BOND_MADE:bp(&b,"{\"tick\":%u,\"type\":\"bond_made\",\"target\":%d,\"species\":\"%s\"}",e->tick,e->target,CP_STAGE_SPECIES[e->move].name);break;
        case CP_STAGE_EV_BOND_BROKEN:bp(&b,"{\"tick\":%u,\"type\":\"bond_broken\",\"target\":%d,\"species\":\"%s\"}",e->tick,e->target,CP_STAGE_SPECIES[e->move].name);break;
        case CP_STAGE_EV_SPECIES_RESOLVED:bp(&b,"{\"tick\":%u,\"type\":\"species_resolved\",\"species\":\"%s\",\"how\":\"%s\"}",e->tick,CP_STAGE_SPECIES[e->move].name,e->value==CP_RES_ALLY?"ally":"dominate");break;
        case CP_STAGE_EV_DNA:bp(&b,"{\"tick\":%u,\"type\":\"dna\",\"amount\":%.0f,\"source\":\"%s\",\"dna_total\":%.0f,\"dna_balance\":%.0f}",e->tick,e->value,source_name(e->move),e->x,e->z);break;
        case CP_STAGE_EV_OBSERVE:bp(&b,"{\"tick\":%u,\"type\":\"observe\",\"target\":%d,\"species\":\"%s\",\"clue_index\":%d,\"revealed\":%.0f,\"clue\":\"%s\"}",e->tick,e->target,CP_STAGE_SPECIES[(int)e->value].name,e->move,e->x,CP_STAGE_CHAINS[(int)e->value].observe[e->move]);break;
        case CP_STAGE_EV_CHAIN_DONE:bp(&b,"{\"tick\":%u,\"type\":\"chain_complete\",\"target\":%d,\"species\":\"%s\",\"chain\":\"%s\",\"learned\":\"%s\"}",e->tick,e->target,CP_STAGE_SPECIES[(int)e->value].name,CP_STAGE_CHAINS[(int)e->value].id,e->move>=0&&e->move<CB_MOVE_COUNT?cp_combat_move_name(e->move):"none");break;
        case CP_STAGE_EV_INTIMIDATE:bp(&b,"{\"tick\":%u,\"type\":\"intimidate\",\"target\":%d,\"success\":%s,\"display\":%.0f,\"resolve\":%.0f}",e->tick,e->target,e->value>0?"true":"false",e->x,e->z);break;
        case CP_STAGE_EV_SOCIAL_CANCELLED:{
            const int r=(int)e->value;
            const char *why=r<0?cp_stage_order_error(r):r==1?"order_changed":r==2?"rival_heckle":r==3?"fight":r==4?"out_of_range":r==5?"seen":r==6?"nothing_to_learn":"cancelled";
            bp(&b,"{\"tick\":%u,\"type\":\"social_cancelled\",\"target\":%d,\"reason\":\"%s\"}",e->tick,e->target,why);
            break;
        }
        case CP_STAGE_EV_EAT:bp(&b,"{\"tick\":%u,\"type\":\"eat\",\"target\":%d,\"bites_left\":%d,\"food_gain\":%.0f,\"food\":%.0f,\"bones\":%.0f}",e->tick,e->target,e->move,e->value,e->x,e->z);break;
        default:return 0;
    }
    return b.failed?0:(int)b.used;
}
int cp_stage_social_carcass_json(const CpStageWorld *w,int i,char *out,size_t cap){
    const int meat=cp_stage_social_carcass_meat(w,i);
    Buf b={out,cap,0,0};
    bp(&b,",\"meat\":%d,\"edible\":%s,\"species_name\":\"%s\"",meat,meat>0&&w->social.diet!=CP_DIET_HERBIVORE?"true":"false",CP_STAGE_SPECIES[w->wild[i].species].name);
    return b.failed?-1:(int)b.used;
}
