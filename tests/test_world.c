#include "cpore/world.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
static CpStageWorld w, other;
static CpStageSetup setup;
static void reset(void) {
    cp_stage_setup_default(&setup,42); setup.terrain=CP_STAGE_FLAT;
    setup.n=1; setup.nest_x=setup.nest_z=0;
    setup.wild[0].x=setup.wild[0].home_x=0;
    setup.wild[0].z=setup.wild[0].home_z=18;
    assert(cp_stage_reset(&w,&setup)==0);
}
int main(void) {
    reset(); CpStageInput a={0}; a.verb=CP_STAGE_HEADING;a.hx=32767;a.sprint=1;
    for(int i=0;i<10;i++)cp_stage_step(&w,&a);
    assert(w.player.x>4 && w.player.stamina<100);
    reset(); setup.n_obstacles=1; setup.obstacles[0]=(CpStageObstacle){2,0,1,0};
    assert(cp_stage_reset(&w,&setup)==0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&a);
    assert(w.player.x<1);
    reset(); a=(CpStageInput){0};a.verb=CP_STAGE_GO;a.x=5;a.z=6;
    for(int i=0;i<70;i++)cp_stage_step(&w,i==0?&a:NULL);
    assert(sqrtf((w.player.x-5)*(w.player.x-5)+(w.player.z-6)*(w.player.z-6))<.25f);
    reset(); uint64_t h=cp_stage_hash(&w); a.verb=CP_STAGE_ATTACK;a.target=999;
    assert(cp_stage_order(&w,&a)<0 && cp_stage_hash(&w)==h);
    a.verb=CP_STAGE_GO;a.x=NAN;assert(cp_stage_order(&w,&a)<0 && cp_stage_hash(&w)==h);
    reset(); other=w;
    for(int i=0;i<3000;i++){a=(CpStageInput){0};a.verb=CP_STAGE_HEADING;a.hx=(i%101)*600-30000;a.hz=20000;
        assert(cp_stage_step(&w,&a)==cp_stage_step(&other,&a));}
    char obs[16384];assert(cp_stage_observe(&w,obs,sizeof obs)>0);assert(strstr(obs,"nearby"));
    assert(cp_stage_observe(&w,obs,4)<0);
    puts("PASS world movement, collision, arrival, atomic rejection, replay and observation");
}
