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
    assert(fabsf(w.player.speed/walk-1.8f)<.005f);assert(w.run_stamina<1000);
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
    int slid=0;for(int i=0;i<40;i++){cp_stage_step(&w,&east);slid|=w.falling;}
    assert(slid);
    /* The confirmed body's actual bone lengths determine safe drop. */
    reset(0);w.ancestry.count=1;
    strcpy(w.ancestry.forms[0].form.body,"{\"parts\":[{\"type\":\"pata\",\"k\":[0,-1,0],\"f\":[0,-2,0]}]}");
    assert(fabsf(cp_stage_safe_drop(&w)-3)<.001f);
    CpStageEvent small=fall(1.5f);assert(small.value==0);
    CpStageEvent big=fall(6);assert(big.move>=590&&big.move<=610);assert(big.value>0);
    float damage=big.value;big=fall(9);assert(fabsf(big.value-damage-60)<2);
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
    assert(huge&&fabsf(huge->value-(6000-cp_stage_safe_drop(&w))*20)<(6000-cp_stage_safe_drop(&w))*20*.01f);
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
    puts("PASS run/fall");return 0;
}
