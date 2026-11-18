/* Steering and slope rules of the stage creatures (docs/godot/LOCOMOTION.md, "Steering").
 * Pure functions of their arguments: only + - * / and sqrtf, no libm trig, so a replay is bit-exact natively and in WASM.
 * stage_world.c walk() owns the state (CpStageCreature) and the movement; this file owns the decisions. */
#ifndef CPORE_STEER_H
#define CPORE_STEER_H
#include "cpore/world.h"

typedef struct {
    float fx,fz;      /* unit heading */
    float speed;      /* m/s along the heading */
    float omega;      /* yaw rate, rad/s, positive turns towards +cross (see steer.c) */
    int32_t pivot;
} CpSteer;

/* What a body can do, from its radius (mass grows with r^3) and its legs: derived, never stored. */
typedef struct {
    float r;
    float turn0;       /* top yaw rate at a standstill, rad/s */
    float alpha;       /* yaw acceleration, rad/s2: falls with size */
    float a_lat;       /* lateral grip, m/s2: yaw rate <= a_lat / v, so the turn radius is v^2 / a_lat */
    float pivot_rate;  /* rad/s while planted */
    float acc,brk;     /* m/s2 caps, lower for big bodies */
    float climb;       /* grade (rise / run) it plans and walks at; the planner never routes over steeper ground */
    float stall;       /* above this grade it cannot walk up (speed 0) */
    float slide;       /* above this grade it slides down */
    int32_t can_pivot; /* small bodies turn on the spot, big ones take a slow U-turn */
} CpSteerBody;

void cp_steer_body(const CpStageMotion *m,float radius,int legs,CpSteerBody *b);
/* Speed multiplier for walking along `grade` (rise / run, + uphill): 1 flat, 0 at the climb limit, a little above 1 on a
 * mild downhill, braked on a steep one. */
float cp_steer_slope(const CpStageMotion *m,const CpSteerBody *b,float grade);
/* One 0.1 s tick. (dx,dz) is the vector to the point being steered towards (any length; zero = none),
 * `wanted` the speed the order asks for, `jog` the creature's jog, `slope` the cp_steer_slope factor.
 * Updates the heading, yaw rate and pivot flag and returns the speed for this tick. */
float cp_steer_tick(const CpStageMotion *m,const CpSteerBody *b,CpSteer *s,float dx,float dz,float wanted,float jog,float slope);
/* Pure pursuit: the point `look` metres ahead along the polyline (px,pz) -> path[first] -> ... -> path[n-1]. */
void cp_steer_carrot(const float (*path)[2],int n,int first,float px,float pz,float look,float *ox,float *oz);
/* Downhill slide speed (m/s) for a ground gradient magnitude `g`; 0 below the body's slide grade. */
float cp_steer_slide(const CpStageMotion *m,const CpSteerBody *b,float g);
float cp_steer_atan2(float y,float x);
#endif
