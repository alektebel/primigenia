/* First quest: digging (docs/godot/FIRST-QUEST.md). The player stands still for CP_DIG_TICKS ticks (soft soil; harder ground takes
 * longer, A54) and leaves a hole; what it holds is decided here, deterministically.
 *
 * Fossil beds. A few spots, derived at reset from the seed and the field (never from the other RNG streams), each with a
 * cue the Godot side draws (cracked dry soil, bone splinters, a different grass, a dust puff). Bed 0 is the wing bed and is
 * guaranteed near the start valley, 22 to 48 m from the nest and on a straight walkable line from it; the others are bone
 * beds further out. Digging the wing bed unearths a winged ancestor (wing_vane) and, in the same seam of burnt, glassy rock,
 * the throat gland of a vent-dwelling animal (fire_gland): the lore is that the old island's vents cooked the sediment, so the
 * bed holds both. Ordinary soil gives a grub (food) or a pebble now and then.
 *
 * Integers and + - * / only. The block is hashed only once a dig was accepted, so worlds that never dig keep their hashes. */
#include "cpore/world.h"
#include <math.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

static float fabs_(float x){return x<0?-x:x;}
static void event(CpStageWorld *w,int type,int target,int move,float value,float x,float z){
    w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,type,0,target,move,value,x,z};w->ev_total++;
}
static float len2(float x,float z){return sqrtf(x*x+z*z);}

int cp_stage_soft_soil(const CpStageWorld *w,float x,float z){
    if(!isfinite(x)||!isfinite(z)||fabs_(x)>cp_stage_bound(w)||fabs_(z)>cp_stage_bound(w))return 0;
    if(cp_stage_in_cave(w,x,z))return 0;
    if(cp_stage_water_depth(w,x,z)>0.f)return 0;
    const float h=cp_stage_ground(w,x,z);
    if(w->setup.terrain==CP_STAGE_FIELD&&h<.3f)return 0;                 /* the shore sand is not soil */
    const float gx=(cp_stage_ground(w,x+1.f,z)-cp_stage_ground(w,x-1.f,z))*.5f,gz=(cp_stage_ground(w,x,z+1.f)-cp_stage_ground(w,x,z-1.f))*.5f;
    return gx*gx+gz*gz<=.35f*.35f;                                       /* rock and cliffs are steep */
}

/* A54: X digs anywhere dry. Ground hardness only changes the time: 0 soft soil, 1 hard (steep ground, shore sand), 2 rock (cliffs,
 * caves). -1 = cannot dig (water, outside the island). A pure function of the position, so the dig needs no state of its own. */
int cp_stage_dig_hardness(const CpStageWorld *w,float x,float z){
    if(!isfinite(x)||!isfinite(z)||fabs_(x)>cp_stage_bound(w)||fabs_(z)>cp_stage_bound(w))return -1;
    if(cp_stage_water_depth(w,x,z)>0.f)return -1;
    if(cp_stage_soft_soil(w,x,z))return 0;
    if(cp_stage_in_cave(w,x,z))return 2;
    const float gx=(cp_stage_ground(w,x+1.f,z)-cp_stage_ground(w,x-1.f,z))*.5f,gz=(cp_stage_ground(w,x,z+1.f)-cp_stage_ground(w,x,z-1.f))*.5f;
    return gx*gx+gz*gz>.8f*.8f?2:1;
}
int cp_stage_dig_ticks(const CpStageWorld *w,float x,float z){
    const int h=cp_stage_dig_hardness(w,x,z);
    return h>=2?CP_DIG_TICKS_ROCK:h==1?CP_DIG_TICKS_HARD:CP_DIG_TICKS;
}

/* 16 unit directions at 22.5 degree steps (literals: the core uses no libm trigonometry). */
static const float DIR16[16][2]={{1,0},{.92387953f,.38268343f},{.70710678f,.70710678f},{.38268343f,.92387953f},{0,1},{-.38268343f,.92387953f},{-.70710678f,.70710678f},{-.92387953f,.38268343f},
                                 {-1,0},{-.92387953f,-.38268343f},{-.70710678f,-.70710678f},{-.38268343f,-.92387953f},{0,-1},{.38268343f,-.92387953f},{.70710678f,-.70710678f},{.92387953f,-.38268343f}};

static int clear_of_nodes(const CpStageWorld *w,float x,float z){
    for(int i=0;i<w->parts.n_nodes;i++){float a=x-w->parts.nodes[i].x,b=z-w->parts.nodes[i].z;if(a*a+b*b<36.f)return 0;}
    for(int i=0;i<w->dig.n_beds;i++){float a=x-w->dig.bed[i].x,b=z-w->dig.bed[i].z;if(a*a+b*b<900.f)return 0;}
    return 1;
}
static int bed_ok(const CpStageWorld *w,float x,float z){
    return cp_stage_soft_soil(w,x,z)&&cp_stage_walkable_from_nest(w,x,z)&&clear_of_nodes(w,x,z)&&len2(x-w->setup.nest_x,z-w->setup.nest_z)>=CP_STAGE_NEST_RADIUS+4.f;
}
static void add_bed(CpStageWorld *w,float x,float z,int kind){
    CpStageDig *d=&w->dig;if(d->n_beds>=CP_STAGE_BEDS)return;
    d->bed[d->n_beds++]=(CpStageBed){x,z,CP_BED_RADIUS,kind,0};
}
void cp_stage_dig_reset(CpStageWorld *w){
    CpStageDig *d=&w->dig;memset(d,0,sizeof *d);
    cp_rng_seed(&d->rng,w->setup.seed^0x44494747u);
    CpRng place;cp_rng_seed(&place,w->setup.seed^0x42454453u);
    const float nx=w->setup.nest_x,nz=w->setup.nest_z;
    /* bed 0: random candidates first (two draws each, a fixed budget), then a deterministic ring scan so it always exists */
    for(int k=0;k<96&&!d->n_beds;k++){
        const unsigned a=cp_rng_u32(&place),b=cp_rng_u32(&place);
        const float r=22.f+(float)(a%27u),ux=DIR16[b%16u][0],uz=DIR16[b%16u][1];
        const float x=nx+ux*r,z=nz+uz*r;
        if(bed_ok(w,x,z))add_bed(w,x,z,CP_BED_WING);
    }
    for(int r=22;r<=60&&!d->n_beds;r+=2)for(int k=0;k<16&&!d->n_beds;k++){
        const float x=nx+DIR16[k][0]*(float)r,z=nz+DIR16[k][1]*(float)r;
        if(bed_ok(w,x,z))add_bed(w,x,z,CP_BED_WING);
    }
    if(!d->n_beds)return;
    for(int k=0;k<192&&d->n_beds<3;k++){
        const unsigned a=cp_rng_u32(&place),b=cp_rng_u32(&place);
        const float r=55.f+(float)(a%50u),x=nx+DIR16[b%16u][0]*r,z=nz+DIR16[b%16u][1]*r;
        if(bed_ok(w,x,z))add_bed(w,x,z,CP_BED_BONE);
    }
}

static int bed_at(const CpStageWorld *w,float x,float z){
    for(int i=0;i<w->dig.n_beds;i++){const CpStageBed *b=&w->dig.bed[i];if(!b->dug&&len2(x-b->x,z-b->z)<=b->r)return i;}
    return -1;
}
int cp_stage_dig_order(CpStageWorld *w,const CpStageInput *a){
    (void)a;
    CpStageDig *d=&w->dig;
    if(w->active>=0||w->respawn_ticks||w->parts.lost||w->falling)return CP_STAGE_ERR_IN_FIGHT;
    if(cp_stage_dig_hardness(w,w->player.x,w->player.z)<0)return CP_STAGE_ERR_HARD_GROUND;      /* only water (or outside the island) refuses */
    for(int i=0;i<d->n_holes&&i<CP_STAGE_HOLES;i++)if(len2(w->player.x-d->hole[i].x,w->player.z-d->hole[i].z)<1.2f)return CP_STAGE_ERR_ALREADY_DUG;
    if(d->act_t)return 0;                                  /* already digging: the same order again is a no-op */
    if(w->player.stamina<CP_DIG_STAMINA)return CP_STAGE_ERR_NO_STAMINA;
    w->player.stamina-=CP_DIG_STAMINA;
    w->order=(CpStageInput){.verb=CP_STAGE_WAIT};
    w->n_path=w->path_i=0;
    d->act_t=1;d->act_x=w->player.x;d->act_z=w->player.z;d->used=1;
    return 0;
}
static void find(CpStageWorld *w,int find_kind,int bed){
    CpStageDig *d=&w->dig;const int slot=d->n_holes%CP_STAGE_HOLES;
    d->hole[slot]=(CpStageHole){d->act_x,d->act_z,find_kind};
    const int index=d->n_holes++;d->dug_total++;
    event(w,CP_STAGE_EV_DUG,index,find_kind,(float)bed,d->act_x,d->act_z);
}
void cp_stage_dig_step(CpStageWorld *w){
    CpStageDig *d=&w->dig;
    if(!d->act_t)return;
    if(w->active>=0||w->respawn_ticks||w->falling||w->order.verb!=CP_STAGE_WAIT||len2(w->player.x-d->act_x,w->player.z-d->act_z)>.8f){
        event(w,CP_STAGE_EV_DUG,-1,-1,-1.f,w->player.x,w->player.z);d->act_t=0;return;   /* interrupted: the stamina is gone */
    }
    if(++d->act_t<=cp_stage_dig_ticks(w,d->act_x,d->act_z))return;
    d->act_t=0;
    const int bed=bed_at(w,d->act_x,d->act_z);
    const unsigned roll=cp_rng_u32(&d->rng)%100u,pick=cp_rng_u32(&d->rng);
    if(bed>=0){
        CpStageBed *b=&d->bed[bed];b->dug=1;
        if(b->kind==CP_BED_WING){
            find(w,CP_FIND_WING_FOSSIL,bed);
            d->wing_found=1;d->fire_found=1;
            cp_stage_part_find(w,cp_stage_part_id("wing_vane"),CP_PART_FOSSIL);
            cp_stage_part_find(w,cp_stage_part_id("fire_gland"),CP_PART_FOSSIL);
        }else{
            static const char *const bones[]={"shell_plate","tail_hammer","jaw_nipper","cuerno"};
            find(w,CP_FIND_BONE_FOSSIL,bed);
            cp_stage_part_find(w,cp_stage_part_id(bones[pick%4u]),CP_PART_FOSSIL);
        }
        w->social.used=1;
        w->social.dna_total+=10;w->social.dna_balance+=10;w->social.dna_by_source[CP_DNA_FOSSIL]+=10;
        event(w,CP_STAGE_EV_DNA,0,CP_DNA_FOSSIL,10.f,(float)w->social.dna_total,(float)w->social.dna_balance);
    }else if(roll<14u){
        find(w,CP_FIND_GRUB,-1);
        w->social.food+=12;if(w->social.food>CP_SOC_FOOD_MAX)w->social.food=CP_SOC_FOOD_MAX;w->social.used=1;
    }else if(roll<24u)find(w,CP_FIND_PEBBLE,-1);
    else find(w,CP_FIND_NONE,-1);
    w->hash=cp_stage_hash(w);
}
void cp_stage_dig_flame(CpStageWorld *w){w->dig.flames++;w->dig.used=1;}
int cp_stage_quest_award(CpStageWorld *w,int step,int dna){
    if(!w||step<0||step>=32||dna<=0||dna>1000||(w->dig.quest_paid&(1u<<step)))return -1;
    CpStageDig *d=&w->dig;
    d->quest_paid|=1u<<step;d->used=1;
    w->social.used=1;w->social.dna_total+=dna;w->social.dna_balance+=dna;w->social.dna_by_source[CP_DNA_TASK]+=dna;
    event(w,CP_STAGE_EV_DNA,0,CP_DNA_TASK,(float)dna,(float)w->social.dna_total,(float)w->social.dna_balance);
    w->hash=cp_stage_hash(w);return 0;
}

static void hu(uint64_t *h,uint32_t v){for(int i=0;i<4;i++){*h^=(uint8_t)(v>>(8*i));*h*=1099511628211ULL;}}
static void hf(uint64_t *h,float v){uint32_t b=0;if(v!=0.f)memcpy(&b,&v,4);hu(h,b);}
uint64_t cp_stage_dig_hash(const CpStageWorld *w){
    const CpStageDig *d=&w->dig;uint64_t h=14695981039346656037ULL;
    for(int i=0;i<4;i++)hu(&h,d->rng.s[i]);
    hu(&h,(uint32_t)d->n_beds);hu(&h,(uint32_t)d->n_holes);hu(&h,(uint32_t)d->dug_total);hu(&h,(uint32_t)d->act_t);hu(&h,(uint32_t)d->flames);
    hu(&h,(uint32_t)d->wing_found);hu(&h,(uint32_t)d->fire_found);hu(&h,d->quest_paid);hf(&h,d->act_x);hf(&h,d->act_z);
    for(int i=0;i<d->n_beds;i++){hf(&h,d->bed[i].x);hf(&h,d->bed[i].z);hu(&h,(uint32_t)d->bed[i].kind);hu(&h,(uint32_t)d->bed[i].dug);}
    for(int i=0;i<d->n_holes&&i<CP_STAGE_HOLES;i++){hf(&h,d->hole[i].x);hf(&h,d->hole[i].z);hu(&h,(uint32_t)d->hole[i].find);}
    return h;
}
int cp_stage_dig_json(const CpStageWorld *w,char *out,size_t cap){
    const CpStageDig *d=&w->dig;size_t n=0;
#define ADD(...) do{int k=snprintf(out+n,cap>n?cap-n:0,__VA_ARGS__);if(k<0||(size_t)k>=cap-n)return -1;n+=(size_t)k;}while(0)
    ADD("{\"digging\":%d,\"ticks\":%d,\"hardness\":%d,\"dug\":%d,\"flames\":%d,\"wing_found\":%s,\"fire_found\":%s,\"soft\":%s,\"beds\":[",d->act_t,
        d->act_t?cp_stage_dig_ticks(w,d->act_x,d->act_z):cp_stage_dig_ticks(w,w->player.x,w->player.z),cp_stage_dig_hardness(w,w->player.x,w->player.z),d->dug_total,d->flames,
        d->wing_found?"true":"false",d->fire_found?"true":"false",cp_stage_soft_soil(w,w->player.x,w->player.z)?"true":"false");
    for(int i=0;i<d->n_beds;i++)ADD("%s{\"id\":%d,\"x\":%.3f,\"z\":%.3f,\"r\":%.2f,\"kind\":%d,\"dug\":%s}",i?",":"",i,d->bed[i].x,d->bed[i].z,d->bed[i].r,d->bed[i].kind,d->bed[i].dug?"true":"false");
    ADD("],\"holes\":[");
    const int shown=d->n_holes<CP_STAGE_HOLES?d->n_holes:CP_STAGE_HOLES;
    for(int i=0;i<shown;i++){
        const int idx=d->n_holes<=CP_STAGE_HOLES?i:(d->n_holes+i)%CP_STAGE_HOLES;
        ADD("%s{\"x\":%.3f,\"z\":%.3f,\"find\":%d}",i?",":"",d->hole[idx].x,d->hole[idx].z,d->hole[idx].find);
    }
    ADD("]}");
#undef ADD
    return (int)n;
}

int cp_stage_dig_observe(const CpStageWorld *w,char *out,size_t cap){
    const CpStageDig *d=&w->dig;size_t n=0;
#define ADD(...) do{int k=snprintf(out+n,cap>n?cap-n:0,__VA_ARGS__);if(k<0||(size_t)k>=cap-n)return -1;n+=(size_t)k;}while(0)
    ADD("{\"digging\":%d,\"dug\":%d,\"soft_here\":%s,\"hardness_here\":%d,\"clues\":[",d->act_t,d->dug_total,cp_stage_soft_soil(w,w->player.x,w->player.z)?"true":"false",cp_stage_dig_hardness(w,w->player.x,w->player.z));
    int comma=0;
    for(int i=0;i<d->n_beds;i++){
        const CpStageBed *b=&d->bed[i];const float dist=len2(b->x-w->player.x,b->z-w->player.z);
        if(b->dug||dist>30.f)continue;
        ADD("%s{\"x\":%.2f,\"z\":%.2f,\"distance\":%.2f,\"text\":\"%s\"}",comma?",":"",b->x,b->z,dist,
            b->kind==CP_BED_WING?"cracked, dry soil with glassy flecks and a few pale bone splinters sticking out; the grass is a different green":"bone splinters sticking out of the soil");
        comma=1;
    }
    ADD("]}");
#undef ADD
    return (int)n;
}
