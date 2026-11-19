/* Prints the trajectory of a creature that runs straight, is re-targeted by `turn` degrees mid-run, and runs on.
 *   steer_trace <radius_cm> <turn_deg> [speed=4]   (FLAT terrain, one GO order each leg)
 * Columns: tick x z heading_deg speed turn_rate. Used for the before/after path plots (docs/godot/LOCOMOTION.md). */
#include "cpore/world.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv){
    const int radius=argc>1?atoi(argv[1]):60;
    const float turn=(argc>2?(float)atof(argv[2]):120.f)*3.14159265f/180.f,speed=argc>3?(float)atof(argv[3]):4.f;
    static CpStageWorld w;
    CpStageSetup s;
    cp_stage_setup_default(&s,1);
    s.terrain=CP_STAGE_FLAT;
    s.n=0;
    s.player.radius_cm=(uint16_t)radius;
    s.player.speed=speed;
    cp_stage_reset(&w,&s);
    w.player.x=0;
    w.player.z=-60;
    CpStageInput in={0};
    in.verb=CP_STAGE_GO;
    in.x=0;
    in.z=150;
    in.sprint=0;
    float tx=0,tz=0;
    for(int t=0;t<260;t++){
        if(t==40){
            /* leave 25 m away at `turn` degrees from the heading (+z) */
            tx=w.player.x+25*sinf(turn);
            tz=w.player.z+25*cosf(turn);
            in.x=tx;
            in.z=tz;
        }
        cp_stage_step(&w,t==0||t==40?&in:NULL);
        printf("%d %.3f %.3f %.2f %.3f %.3f\n",t,w.player.x,w.player.z,atan2f(w.player.fx,w.player.fz)*57.29578f,w.player.speed,w.player.turn_rate);
    }
    return 0;
}
