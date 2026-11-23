/* Steering for the stage creatures. See core/include/cpore/steer.h and docs/godot/LOCOMOTION.md. */
#include "cpore/steer.h"
#include <math.h>
#define DT .1f
#define RUN_BURST_ACC 1.7f
#define RUN_BURST_EASE 1.2f
static float clampf_(float x,float a,float b){
    return x<a?a:x>b?b:x;
}
static float abf_(float x){
    return x<0?-x:x;
}
static float minf_(float a,float b){
    return a<b?a:b;
}
static float maxf_(float a,float b){
    return a>b?a:b;
}
/* atan on [0,1], Abramowitz & Stegun 4.4.49 (error < 1e-5) */
static float atan01(float x){
    const float x2=x*x;
    return x*(.9998660f+x2*(-.3302995f+x2*(.1801410f+x2*(-.0851330f+x2*.0208351f))));
}
float cp_steer_atan2(float y,float x){
    const float ax=abf_(x),ay=abf_(y);
    float a;
    if(ax==0&&ay==0)return 0;
    if(ay<=ax)a=atan01(ay/ax);
    else a=1.57079633f-atan01(ax/ay);
    if(x<0)a=3.14159265f-a;
    return y<0?-a:a;
}
void cp_steer_body(const CpStageMotion *m,float r,int legs,CpSteerBody *b){
    if(legs<1)legs=4;
    if(legs>8)legs=8;
    const float big=maxf_(r-.6f,0);
    const float grip_legs=clampf_(.7f+.1f*(float)legs,.8f,1.5f);
    b->r=r;
    b->turn0=clampf_(m->turn_k*sqrtf(9.81f/r),m->turn_min,m->turn_max);
    b->alpha=m->ang_k*9.81f/r;
    b->a_lat=m->grip*grip_legs/(1+m->grip_mass*big);
    b->pivot_rate=clampf_(m->pivot_mul*b->turn0,3,m->pivot_max);
    b->acc=m->accel/(1+m->acc_mass*big);
    b->brk=m->brake/(1+m->acc_mass*big);
    b->climb=(m->climb_base+m->climb_legs*((float)legs-2)/6)/(1+.06f*big);
    b->stall=b->climb*m->stall_mul;
    b->slide=b->stall*m->slide_mul;
    b->can_pivot=r<=m->pivot_r;
}
float cp_steer_slope(const CpStageMotion *m,const CpSteerBody *b,float grade){
    if(grade>=0){
        const float t=1-grade/b->stall;
        return t<=0?0:sqrtf(t);
    }
    const float d=-grade;
    if(d<=.2f)return 1+m->down_gain*d/.2f;
    return maxf_(1+m->down_gain-(d-.2f)*(1+m->down_gain)*1.25f,.4f);
}
float cp_steer_slide(const CpStageMotion *m,const CpSteerBody *b,float g){
    return g>b->slide?minf_(m->slide_k*(g-b->slide)+.4f,5):0;
}
float cp_steer_tick(const CpStageMotion *m,const CpSteerBody *b,CpSteer *s,float dx,float dz,float wanted,float jog,float slope){
    const float n=sqrtf(dx*dx+dz*dz),old=s->speed;
    float dot=1,cross=0,err=0;
    const int has=n>.00001f;
    if(has){
        dx/=n;
        dz/=n;
        dot=s->fx*dx+s->fz*dz;
        cross=s->fz*dx-s->fx*dz;
        err=cp_steer_atan2(cross,dot);
    }
    const float pivot_v=m->pivot_k*jog;
    if(has&&!s->pivot&&b->can_pivot&&dot<-.5f&&old<=pivot_v)s->pivot=1;
    if(s->pivot&&(dot>.5f||!has))s->pivot=0;
    /* the speed the creature wants: the order's, less for a sharp turn (it brakes into the corner), nothing while pivoting */
    float wt=wanted*clampf_(n,0,1);
    if(s->pivot)wt=0;
    else if(has){
        float f=dot>=0?(1-m->turn_slow)+m->turn_slow*dot:(1-m->turn_slow)*clampf_(1+2*dot,0,1);
        if(!b->can_pivot)f=maxf_(f,m->creep);       /* a big body keeps rolling through a U-turn */
        wt*=f;
    }
    wt*=slope;
    /* A54: a run (wanted well above the jog) bursts: the acceleration cap and the ease are raised so a creature reaches its gallop speed in
     * about half a second from a walk or a standstill (starting values; measured in docs/evidence/loco/creature-feedback/gallop.md). */
    const int burst=has&&wanted>1.25f*jog&&wt>old;
    float dv=(wt-old)*(burst?minf_(1.f,m->ease*RUN_BURST_EASE):m->ease);
    dv=clampf_(dv,-b->brk*DT,b->acc*(burst?RUN_BURST_ACC:1.f)*DT);
    float v=old+dv;
    if(v<.015f&&wt<.015f)v=0;
    /* yaw: angular acceleration towards a yaw rate that brakes in time for the remaining angle */
    float rate=b->turn0;
    if(s->pivot)rate=b->pivot_rate;
    else if(v>.001f&&b->a_lat/v<rate)rate=b->a_lat/v;
    const float alpha=s->pivot?b->alpha*2:b->alpha;
    float wd=0;
    if(has){
        const float ae=abf_(err);
        wd=minf_(rate,sqrtf(1.7f*alpha*ae));
        wd=minf_(wd,ae/DT);
        if(err<0)wd=-wd;
    }
    s->omega+=clampf_(wd-s->omega,-alpha*DT,alpha*DT);
    if(s->omega>b->pivot_rate)s->omega=b->pivot_rate;
    if(s->omega<-b->pivot_rate)s->omega=-b->pivot_rate;
    float th=s->omega*DT;
    if(has&&abf_(th)>abf_(err)){
        th=err;
        s->omega=err/DT;
    }
    if(th!=0){
        const float t2=th*th,co=1-t2/2+t2*t2/24-t2*t2*t2/720,si=th-th*t2/6+th*t2*t2/120-th*t2*t2*t2/5040;
        const float fx=s->fx*co+s->fz*si;
        s->fz=s->fz*co-s->fx*si;
        s->fx=fx;
        const float k=sqrtf(s->fx*s->fx+s->fz*s->fz);
        s->fx/=k;
        s->fz/=k;
    }
    s->speed=v;
    return v;
}
void cp_steer_carrot(const float (*path)[2],int n,int first,float px,float pz,float look,float *ox,float *oz){
    float ax=px,az=pz;
    for(int i=first;i<n;i++){
        const float bx=path[i][0],bz=path[i][1],len=sqrtf((bx-ax)*(bx-ax)+(bz-az)*(bz-az));
        if(len>=look&&len>.00001f){
            *ox=ax+(bx-ax)*(look/len);
            *oz=az+(bz-az)*(look/len);
            return;
        }
        look-=len;
        ax=bx;
        az=bz;
    }
    *ox=ax;
    *oz=az;
}
