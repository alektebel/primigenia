#include "cpore/world.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static CpStageWorld w,t;
static float heights[256*256];
static CpStageField field={256,128,.5f,64,heights,NULL,987};
static CpStageInput east={.verb=CP_STAGE_HEADING,.hx=32767};
static void reset(float drop){
    CpStageSetup s;cp_stage_setup_default(&s,1);s.n=0;s.nest_x=-3;s.nest_z=0;
    s.terrain=CP_STAGE_FIELD;s.player.radius_cm=60;
    for(int j=0;j<256;j++)for(int i=0;i<256;i++)heights[j*256+i]=i<128?drop:0;
    memset(&w,0,sizeof w);assert(!cp_stage_attach_field(&w,&field));assert(!cp_stage_reset(&w,&s));
    w.player.fx=1;w.player.fz=0;
}
static int32_t ground_mm0(void){return (int32_t)lroundf(cp_stage_ground(&w,w.player.x,w.player.z)*1000);}
static CpStageEvent fall(float drop){
    reset(drop);int saw=0;
    for(int i=0;i<150;i++){
        cp_stage_step(&w,&east);saw|=w.falling;
        for(unsigned k=0;k<w.ev_total;k++)if(w.events[k%CP_STAGE_MAX_EVENTS].type==CP_STAGE_EV_FELL){assert(saw);return w.events[k%CP_STAGE_MAX_EVENTS];}
    }
    assert(!"never landed");return (CpStageEvent){0};
}
int main(void){
    reset(0);for(int i=0;i<30;i++)cp_stage_step(&w,&east);float walk=w.player.speed;
    cp_stage_set_run(&w,1);assert(w.running);
    for(int i=0;i<30;i++)cp_stage_step(&w,&east);
    assert(fabsf(w.player.speed/walk-sqrtf(w.motion.sprint_k/.24f))<.005f);   /* run Fr / walk Fr (A39) */assert(w.run_stamina<1000);
    cp_stage_set_run(&w,0);int stamina=w.run_stamina;
    CpStageInput wait={.verb=CP_STAGE_WAIT};for(int i=0;i<20;i++)cp_stage_step(&w,&wait);
    assert(w.run_stamina>stamina);
    w.run_stamina=149;cp_stage_set_run(&w,1);assert(!w.running);
    w.run_stamina=150;cp_stage_set_run(&w,1);assert(w.running);
    for(int i=0;i<100;i++)cp_stage_step(&w,&east);
    assert(!w.running);
    /* A repeated request below threshold cannot restart; standing still restores stamina. */
    reset(0);w.run_stamina=149;cp_stage_set_run(&w,1);assert(!w.running);
    cp_stage_step(&w,&wait);assert(w.run_stamina==154);
    cp_stage_set_run(&w,1);cp_stage_step(&w,&wait);assert(w.run_stamina==159);
    /* Full gradient matters even for contour motion; morphology sets the limit, capped at 1.26. */
    for(int j=0;j<256;j++)for(int i=0;i<256;i++)heights[j*256+i]=10+1.4f*(i*.5f-64);
    w.player.x=0;w.player.z=0;w.player.legs=8;
    CpStageInput contour={.verb=CP_STAGE_HEADING,.hz=32767};
    cp_stage_step(&w,&contour);assert(w.falling&&w.player.sliding&&w.player.x<0);
    reset(0);
    for(int j=0;j<256;j++)for(int i=0;i<256;i++)heights[j*256+i]=10+.8f*(i*.5f-64);
    w.player.x=0;w.player.legs=2;cp_stage_step(&w,&contour);assert(w.falling);
    reset(0);
    for(int j=0;j<256;j++)for(int i=0;i<256;i++)heights[j*256+i]=10+.8f*(i*.5f-64);
    w.player.x=0;w.player.legs=8;cp_stage_step(&w,&contour);assert(!w.falling);
    /* Entering an uphill steep facet slides too; direct input has no slope wall exemption. */
    reset(0);for(int j=0;j<256;j++)for(int i=0;i<256;i++)heights[j*256+i]=i<128?0:6;
    /* a hero-size body at its run (5 m/s, about the old jog); a slow walker stops at the foot of the facet instead (A39) */
    w.player.profile.radius_cm=300;CpStageInput east_run=east;east_run.sprint=1;
    int slid=0;for(int i=0;i<80;i++){cp_stage_step(&w,&east_run);slid|=w.falling;}
    assert(slid);
    /* The confirmed body's actual bone lengths determine safe drop. */
    reset(0);w.ancestry.count=1;
    strcpy(w.ancestry.forms[0].form.body,"{\"parts\":[{\"type\":\"pata\",\"k\":[0,-1,0],\"f\":[0,-2,0]}]}");
    assert(fabsf(cp_stage_safe_drop(&w)-3)<.001f);
    CpStageEvent small=fall(1.5f);assert(small.value==0);
    CpStageEvent big=fall(6);assert(big.move>=590&&big.move<=610);assert(big.value>0);
    /* A31: 10 HP per metre of equivalent drop beyond the safe drop (3 m here): 6 m -> ~42 (the impact is a little faster than the geometric drop), 9 m -> +30 (a free fall, not capped). */
    assert(big.value>25&&big.value<50);float damage=big.value;big=fall(9);assert(fabsf(big.value-damage-30)<2);
    /* D8: damage follows the vertical impact speed (v^2/2g), so a flare that slows the descent reduces it. */
    reset(0);w.falling=1;w.fall_y_mm=w.fall_start_mm=8000;
    for(int i=0;i<20&&w.falling;i++)cp_stage_step(&w,NULL);
    reset(0);w.falling=1;w.fall_y_mm=w.fall_start_mm=8000;
    for(int i=0;i<10&&w.falling;i++)cp_stage_step(&w,NULL);
    w.fall_v_mm_s/=3;
    while(w.falling)cp_stage_step(&w,NULL);
    float flared=w.player.hp;
    reset(0);w.falling=1;w.fall_y_mm=w.fall_start_mm=8000;
    while(w.falling)cp_stage_step(&w,NULL);
    assert(flared>w.player.hp);
    /* Damage follows the same curve for large drops; it is not capped to maximum body HP. */
    reset(0);w.falling=1;w.fall_y_mm=w.fall_start_mm=6000000;
    for(int i=0;i<1000&&w.falling;i++)cp_stage_step(&w,NULL);
    CpStageEvent *huge=NULL;
    for(unsigned k=0;k<w.ev_total&&k<CP_STAGE_MAX_EVENTS;k++)if(w.events[k].type==CP_STAGE_EV_FELL)huge=&w.events[k];
    assert(huge&&fabsf(huge->value-(6000-cp_stage_safe_drop(&w))*10)<(6000-cp_stage_safe_drop(&w))*10*.01f);
    /* A31 cap: 60 % of max HP unless the air since the last ground contact exceeds 2x the safe drop (a slide keeps touching ground). */
    reset(0);assert(w.player.profile.hp>0);float cap=w.player.profile.hp*.6f;
    w.falling=1;w.fall_y_mm=w.fall_start_mm=ground_mm0()+100;w.fall_v_mm_s=-60000;
    while(w.falling)cp_stage_step(&w,NULL);
    assert(fabsf((w.player.profile.hp-w.player.hp)-cap)<.01f&&w.outcome==0);   /* a slide-like landing at huge speed: capped, survives */
    reset(0);w.falling=1;w.fall_y_mm=w.fall_start_mm=ground_mm0()+100000;w.fall_v_mm_s=-60000;
    while(w.falling)cp_stage_step(&w,NULL);
    assert(w.player.hp<=0||w.outcome==CP_STAGE_DEATH||w.player.hp<w.player.profile.hp-cap-1);   /* real free fall: uncapped */
    /* A lethal landing consumes an egg through the existing death path. */
    reset(8);w.player.hp=1;int eggs=w.parts.eggs;
    for(int i=0;i<100&&!w.respawn_ticks&&!w.parts.lost;i++)cp_stage_step(&w,&east);
    assert(w.outcome==CP_STAGE_DEATH);assert(w.parts.eggs==eggs-1||w.parts.lost);
    assert(w.respawn_ticks>0);
    while(w.respawn_ticks)cp_stage_step(&w,&wait);
    assert(w.player.hp==w.player.profile.hp&&w.player.x==w.setup.nest_x&&!w.falling);
    reset(8);w.parts.eggs=1;w.player.hp=1;
    for(int i=0;i<100&&!w.parts.lost;i++)cp_stage_step(&w,&east);
    assert(w.parts.lost&&!w.respawn_ticks&&w.player.hp==0);
    /* Snapshot and every tick hash agree while airborne; running was active at takeoff. */
    reset(8);cp_stage_set_run(&w,1);
    for(int i=0;i<100&&!w.falling;i++)cp_stage_step(&w,&east);
    assert(w.falling);
    size_t n=cp_stage_snapshot_size();uint8_t *blob=malloc(n);assert(cp_stage_snapshot(&w,blob,n)>0);
    assert(!cp_stage_restore(&t,blob,n,&field));free(blob);
    for(int i=0;i<80;i++)assert(cp_stage_step(&w,&wait)==cp_stage_step(&t,&wait));
    reset(0);cp_stage_set_run(&w,1);
    for(int i=0;i<10;i++)cp_stage_step(&w,&east);
    blob=malloc(n);assert(cp_stage_snapshot(&w,blob,n)>0);
    assert(!cp_stage_restore(&t,blob,n,&field));free(blob);
    for(int i=0;i<20;i++)assert(cp_stage_step(&w,&east)==cp_stage_step(&t,&east));
    /* Observe a completed fall, including the landing event. */
    fall(6);
    char out[32768];assert(cp_stage_observe(&w,out,sizeof out)>0);assert(strstr(out,"\"running\"")&&strstr(out,"\"falling\"")&&strstr(out,"\"drop_cm\""));
    /* Input log v4: cp_stage_replay_run applies run entries before the step of their tick, like the Godot session; no entries = cp_stage_replay_ex. */
    {
        CpStageSetup su;cp_stage_setup_default(&su,7);su.n=0;
        CpStageLogEntry ent[1]={{0,east}};CpStageRunEntry runs[3]={{20,1},{60,0},{90,1}};
        uint64_t h1[150],h2[150],h3[150];
        uint64_t end=cp_stage_replay_run(&su,NULL,0,NULL,ent,1,NULL,0,runs,3,150,h1);
        CpStageWorld *m=calloc(1,sizeof *m);assert(m&&!cp_stage_reset(m,&su));
        for(int i=0;i<150;i++){
            if(i==0)cp_stage_order(m,&ent[0].input);
            if(i==20||i==90)cp_stage_set_run(m,1);
            if(i==60)cp_stage_set_run(m,0);
            h2[i]=cp_stage_step(m,NULL);
        }
        assert(end&&end==cp_stage_hash(m));for(int i=0;i<150;i++)assert(h1[i]==h2[i]);
        assert(cp_stage_replay_run(&su,NULL,0,NULL,ent,1,NULL,0,NULL,0,150,h3)==cp_stage_replay_ex(&su,NULL,0,NULL,ent,1,NULL,0,150,h2));
        int differ=0;for(int i=0;i<150;i++)differ|=h1[i]!=h3[i];assert(differ);
        assert(cp_stage_replay_run(&su,NULL,0,NULL,ent,1,NULL,0,runs,-1,150,NULL)==0);
        free(m);
    }
    /* Jump (Space): apex 0.8 x hip height, no damage on flat ground, the run-up speed carries over, one jump per landing, stamina cost. */
    {
        reset(0);for(int i=0;i<5;i++)cp_stage_step(&w,&wait);
        float st0=w.player.stamina,apex=cp_stage_jump_height(&w);
        assert(fabsf(apex-.8f*.56f*.6f)<.01f);
        assert(cp_stage_jump(&w)==0&&w.falling&&w.jumping);
        assert(fabsf(st0-w.player.stamina-w.player.profile.stamina*CP_JUMP_STAMINA_PCT*.01f)<.01f);
        assert(cp_stage_jump(&w)!=0);                       /* no double jump */
        int32_t top=0,x0=(int32_t)(w.player.x*1000);float hp=w.player.hp;int ticks=0;
        while(w.falling&&ticks<100){cp_stage_step(&w,&wait);if(w.fall_y_mm>top)top=w.fall_y_mm;ticks++;}
        assert(!w.falling&&!w.jumping&&w.player.hp==hp);
        float rise=(top-ground_mm0())*.001f;assert(rise>apex*.9f&&rise<apex*1.2f);
        assert((int32_t)(w.player.x*1000)==x0);              /* standing jump: straight up */
        assert(cp_stage_jump(&w)!=0);                        /* cooldown */
        for(int i=0;i<CP_JUMP_COOLDOWN_TICKS;i++)cp_stage_step(&w,&wait);
        assert(cp_stage_jump(&w)==0);
        while(w.falling)cp_stage_step(&w,&wait);
        /* a running jump travels further and lands still moving */
        reset(0);for(int i=0;i<30;i++)cp_stage_step(&w,&east);
        float sp=w.player.speed,xa=w.player.x;assert(sp>.3f);
        assert(cp_stage_jump(&w)==0);hp=w.player.hp;
        while(w.falling)cp_stage_step(&w,&east);
        assert(w.player.x-xa>sp*.3f&&w.player.hp==hp&&fabsf(w.player.speed-sp)<sp*.5f);
        /* exhausted, in a fight and in the water: refused */
        reset(0);w.player.stamina=1;assert(cp_stage_jump(&w)==CP_STAGE_ERR_NO_STAMINA);
        reset(0);w.player.stamina=w.player.profile.stamina;w.active=0;assert(cp_stage_jump(&w)!=0);
        /* big bodies are clamped; the apex never exceeds half the safe drop */
        reset(0);w.player.profile.radius_cm=300;assert(cp_stage_jump_height(&w)<=1.2f+1e-4f);
        w.player.profile.radius_cm=20;assert(cp_stage_jump_height(&w)<=.5f*cp_stage_safe_drop(&w)+1e-4f);
    }
    puts("PASS run/fall");return 0;
}
