#include <stdlib.h>
/* Steering and slope rules of the stage creatures (core/src/steer.c, docs/godot/LOCOMOTION.md "Steering").
 * Everything goes through the public world API, so the tests cover what a replay sees.
 *   build/steer_test */
#include "cpore/world.h"
#include "cpore/steer.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
static CpStageWorld w,twin;
static float height_grid[160*160];
static CpStageField field;
static int checks;
#define CHECK(c) do{checks++;if(!(c)){fprintf(stderr,"FAIL %s:%d %s\n",__FILE__,__LINE__,#c);return 1;}}while(0)

static void flat_world(CpStageWorld *world,int radius_cm,float speed,int legs){
    CpStageSetup s;
    cp_stage_setup_default(&s,1);
    s.terrain=CP_STAGE_FLAT;
    s.n=0;
    s.player.radius_cm=(uint16_t)radius_cm;
    s.player.speed=speed;
    s.player_legs=legs;
    memset(world,0,sizeof *world);
    assert(cp_stage_reset(world,&s)==0);
    world->player.x=0;
    world->player.z=-60;
}
static float yaw_of(const CpStageCreature *c){
    return cp_steer_atan2(c->fx,c->fz);
}
static float wrap(float a){
    while(a>3.14159265f)a-=6.2831853f;
    while(a<-3.14159265f)a+=6.2831853f;
    return a;
}
/* Runs straight for 40 ticks, then GO to a point 25 m away `deg` degrees off the heading. Fills extent (max sideways
 * distance from the original line), the worst per-tick heading change, yaw-rate change and speed change, and whether
 * the creature ever pivoted. Returns ticks until the heading is within 5 degrees of the new bearing. */
typedef struct {
    float extent,max_dyaw,max_domega,max_dv,first_dyaw,min_speed,moved_while_pivot;
    int ticks_to_face,pivoted;
} Turn;
static Turn run_turn(int radius_cm,float speed,int legs,float deg){
    Turn t={0};
    t.min_speed=1e9f;
    flat_world(&w,radius_cm,speed,legs);
    CpStageInput in={.verb=CP_STAGE_GO,.x=0,.z=150};
    for(int i=0;i<40;i++)cp_stage_step(&w,i==0?&in:NULL);
    const float rad=deg*3.14159265f/180.f,px=w.player.x,pz=w.player.z;
    in.x=px+25*sinf(rad);
    in.z=pz+25*cosf(rad);
    const float bearing=cp_steer_atan2(in.x-px,in.z-pz);
    float prev_yaw=yaw_of(&w.player),prev_omega=w.player.omega,prev_speed=w.player.speed;
    for(int i=0;i<150;i++){
        cp_stage_step(&w,i==0?&in:NULL);
        const float dyaw=fabsf(wrap(yaw_of(&w.player)-prev_yaw));
        if(i==0)t.first_dyaw=dyaw;
        if(dyaw>t.max_dyaw)t.max_dyaw=dyaw;
        const float dom=fabsf(w.player.omega-prev_omega);
        if(dom>t.max_domega)t.max_domega=dom;
        const float dv=prev_speed-w.player.speed;
        if(dv>t.max_dv)t.max_dv=dv;
        if(!t.ticks_to_face){
            /* until the creature faces the new bearing: how far it strays, how slow it gets, whether it pivots */
            if(fabsf(w.player.x-px)>t.extent)t.extent=fabsf(w.player.x-px);
            if(w.player.speed<t.min_speed)t.min_speed=w.player.speed;
            if(w.player.pivot)t.pivoted=1;
            if(fabsf(wrap(yaw_of(&w.player)-bearing))<.0873f)t.ticks_to_face=i+1;
        }
        prev_yaw=yaw_of(&w.player);
        prev_omega=w.player.omega;
        prev_speed=w.player.speed;
    }
    return t;
}
static int test_turns(void){
    /* a bigger body and a faster body both take a wider arc (the sideways extent of a 120 degree retarget) */
    const int radii[]={50,60,120,200,300,400};
    float last=0;
    for(unsigned i=0;i<sizeof radii/sizeof *radii;i++){
        Turn t=run_turn(radii[i],4,0,120);
        printf("  r=%.2f m: extent %.2f m, faces the target after %d ticks, min speed %.2f, pivot %d\n",radii[i]/100.f,t.extent,t.ticks_to_face,t.min_speed,t.pivoted);
        CHECK(t.ticks_to_face>0);
        CHECK(t.extent>=last-.3f);
        last=t.extent;
    }
    CHECK(run_turn(400,4,0,120).extent>run_turn(60,4,0,120).extent+1.5f);
    const Turn slow=run_turn(300,2.5f,0,90),fast=run_turn(300,8,0,90);
    printf("  r=3 m 90 degrees: extent %.2f m at speed 2.5, %.2f m at speed 8\n",slow.extent,fast.extent);
    CHECK(fast.extent>slow.extent+1.f);
    /* grip: more legs turn tighter */
    CHECK(run_turn(300,4,8,90).extent<run_turn(300,4,2,90).extent);
    return 0;
}
static int test_no_snap(void){
    const int radii[]={60,300};
    for(int k=0;k<2;k++){
        flat_world(&w,radii[k],4,0);
        CpSteerBody b;
        cp_steer_body(&w.motion,cp_combat_body_radius(&w.player.profile),4,&b);
        const float max_rate=b.pivot_rate>b.turn0?b.pivot_rate:b.turn0;
        Turn t=run_turn(radii[k],4,0,120);
        /* the first tick after a retarget turns by at most one acceleration step (alpha dt, then alpha dt^2 of heading) */
        CHECK(t.first_dyaw<=b.alpha*.1f*.1f*2+.01f);
        CHECK(t.max_dyaw<=max_rate*.1f+.002f);
        CHECK(t.max_domega<=b.alpha*2*.1f+.01f);
        CHECK(t.max_dv<=b.brk*.1f+.01f);
        printf("  r=%.2f: first-tick yaw %.3f rad, max yaw/tick %.3f, max d(omega)/tick %.2f (alpha %.2f), max speed drop/tick %.2f\n",radii[k]/100.f,t.first_dyaw,t.max_dyaw,t.max_domega,b.alpha,t.max_dv);
    }
    return 0;
}
static int test_pivot(void){
    /* a small body running at full speed is told to go back: it brakes, then pivots on the spot */
    Turn s=run_turn(60,4,0,180);
    CHECK(s.pivoted);
    /* a big one never pivots: it rolls through a slow U-turn */
    Turn big=run_turn(400,4,0,180);
    CHECK(!big.pivoted);
    CHECK(big.min_speed>.5f);
    CHECK(big.ticks_to_face>s.ticks_to_face);
    printf("  U-turn: small %d ticks (pivot), big %d ticks (min speed %.2f)\n",s.ticks_to_face,big.ticks_to_face,big.min_speed);
    /* from rest, planted */
    flat_world(&w,60,4,0);
    CpStageInput in={.verb=CP_STAGE_GO,.x=0,.z=-100};
    for(int i=0;i<25;i++)cp_stage_step(&w,i==0?&in:NULL);
    CHECK(w.player.fz<-.9f);
    float fz0=w.player.fz;
    CHECK(fz0<0);
    in.z=100;
    in.x=0;
    float x0=w.player.x,z0=w.player.z;
    (void)x0;
    cp_stage_step(&w,&in);
    (void)z0;
    return 0;
}
/* A synthetic island: flat at 5 m, a ramp of the given grade starting at x = 20 and rising 6 m, then a plateau. */
static void make_field(float grade,float down){
    const int n=160;
    for(int j=0;j<n;j++)for(int i=0;i<n;i++){
        const float x=(float)i+.5f-80;
        float h=5;
        if(x>20)h=5+fminf((x-20)*grade,6);
        if(x<-20)h=5+fminf((-20-x)*down,6);
        height_grid[j*n+i]=h;
    }
    memset(&field,0,sizeof field);
    field.n=n;
    field.size_m=160;
    field.cell=1;
    field.half=80;
    field.height=height_grid;
    field.hash=12345;
}
static void field_world(CpStageWorld *world,int legs,int radius_cm,float x,float z){
    CpStageSetup s;
    cp_stage_setup_default(&s,1);
    s.terrain=CP_STAGE_FIELD;
    s.n=0;
    s.nest_x=x;
    s.nest_z=z;
    s.player.radius_cm=(uint16_t)radius_cm;
    s.player_legs=legs;
    memset(world,0,sizeof *world);
    assert(cp_stage_attach_field(world,&field)==0);
    assert(cp_stage_reset(world,&s)==0);
}
/* Walks along +-x for `ticks`; steady = mean speed while x is between lo and hi (the whole last 10 ticks when lo == hi). */
static float walk_heading_in(CpStageWorld *world,float hx,float hz,int ticks,float lo,float hi,float *steady,float *end_x){
    CpStageInput a={.verb=CP_STAGE_HEADING,.hx=(int16_t)(hx*32767),.hz=(int16_t)(hz*32767)};
    float sum=0;
    int n=0;
    for(int i=0;i<ticks;i++){
        cp_stage_step(world,&a);
        if(lo==hi?i>=ticks-10:(world->player.x>lo&&world->player.x<hi)){
            sum+=world->player.speed;
            n++;
        }
    }
    *steady=n?sum/n:0;
    *end_x=world->player.x;
    return world->player.speed;
}
static float walk_heading(CpStageWorld *world,float hx,float hz,int ticks,float *steady,float *end_x){
    return walk_heading_in(world,hx,hz,ticks,0,0,steady,end_x);
}
static int test_slopes(void){
    float flat=0,e;
    make_field(0,0);
    field_world(&w,4,60,-50,0);
    walk_heading(&w,1,0,60,&flat,&e);
    printf("  flat jog %.2f m/s\n",flat);
    /* uphill is slower, more so the steeper it is; downhill is a little faster, steep downhill is braked */
    const float grades[]={.176f,.364f,.577f,.839f};
    float last=flat,steady,x_end;
    for(int g=0;g<4;g++){
        make_field(grades[g],0);
        field_world(&w,4,60,10,0);                 /* the ramp starts at x = 20 and is 6 m high */
        walk_heading_in(&w,1,0,45,24,20+6/grades[g]-2,&steady,&x_end);   /* mean speed on the ramp */
        printf("  4 legs up grade %.3f: %.2f m/s, x %.1f\n",grades[g],steady,x_end);
        CHECK(steady<last+.001f);
        last=steady;
    }
    CHECK(last<flat*.7f);
    make_field(.176f,0);
    field_world(&w,4,60,20+6/.176f+4,0);          /* on the plateau at the top, walking down */
    walk_heading_in(&w,-1,0,60,24,20+6/.176f-2,&steady,&x_end);
    printf("  4 legs down grade 0.176: %.2f m/s\n",steady);
    CHECK(steady>flat*1.02f);
    make_field(.839f,0);
    field_world(&w,4,60,20+6/.839f+4,0);
    walk_heading_in(&w,-1,0,60,23,20+6/.839f-1,&steady,&x_end);
    printf("  4 legs down grade 0.839: %.2f m/s\n",steady);
    CHECK(steady<flat*.8f);
    /* legs set the steepest grade: 8 legs cross the 40 degree ramp, 2 legs stall on it */
    make_field(.839f,0);
    field_world(&w,8,60,10,0);
    walk_heading(&w,1,0,200,&steady,&x_end);
    CHECK(x_end>45);
    float stall_x;
    field_world(&w,2,60,10,0);
    walk_heading(&w,1,0,200,&steady,&stall_x);
    printf("  40 degrees: 8 legs reach x %.1f, 2 legs stop at x %.1f (speed %.2f)\n",x_end,stall_x,steady);
    CHECK(stall_x<x_end-15&&steady<.5f);
    /* sliding: beyond the slide grade a body goes down the fall line without being asked; a body that holds does not */
    make_field(1.19f,0);
    field_world(&w,2,60,23,0);
    CpStageInput wait={.verb=CP_STAGE_WAIT};
    const float x0=w.player.x;
    int slid=0;
    for(int i=0;i<30;i++){
        cp_stage_step(&w,&wait);
        slid|=w.player.sliding;
    }
    printf("  2 legs placed on grade 1.19: x %.1f -> %.1f, slid %d\n",x0,w.player.x,slid);
    CHECK(w.player.x<x0-1&&slid);
    field_world(&w,8,60,23,0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&wait);
    CHECK(w.player.x==x0&&!w.player.sliding);
    make_field(.364f,0);
    field_world(&w,2,60,30,0);
    for(int i=0;i<30;i++)cp_stage_step(&w,&wait);
    CHECK(w.player.x==30&&!w.player.sliding);
    /* the planner never routes over ground the body cannot climb: the whole width is a 40 degree ramp, so a 2 legged
     * body is refused (-4 unreachable) while an 8 legged one gets a path */
    make_field(.839f,0);
    CpStageInput go={.verb=CP_STAGE_GO,.x=50,.z=0};
    field_world(&w,2,60,0,0);
    CHECK(cp_stage_order(&w,&go)==-4);
    field_world(&w,8,60,0,0);
    CHECK(cp_stage_order(&w,&go)==0);
    make_field(.364f,0);
    field_world(&w,2,60,0,0);
    CHECK(cp_stage_order(&w,&go)==0);
    return 0;
}
/* The player must obey the same full-gradient ceiling as wildlife, even when
 * walking along a contour (zero directional grade). */
static int test_player_ceiling(void){
    make_field(1.35f,0);
    field_world(&w,8,60,23,0);
    CpStageInput wait={.verb=CP_STAGE_WAIT};
    int slid=0;
    for(int i=0;i<30;i++){cp_stage_step(&w,&wait);slid|=w.player.sliding;}
    CHECK(slid);
    field_world(&w,8,60,23,0);
    CpStageInput contour={.verb=CP_STAGE_GO,.x=23,.z=30};
    CHECK(cp_stage_order(&w,&contour)==-4);
    return 0;
}
static int test_route_feedback(void){
    char obs[16384];
    make_field(0,0);
    field_world(&w,4,60,0,0);
    CpStageInput go={.verb=CP_STAGE_GO,.x=50,.z=0};
    CHECK(cp_stage_order(&w,&go)==0);
    /* Turn an accepted path into an impassable water wall, without moving the body. */
    for(int j=0;j<160;j++)for(int i=100;i<110;i++)height_grid[j*160+i]=-2;
    field.hash++;
    for(int i=0;i<600&&w.order.verb==CP_STAGE_GO;i++)cp_stage_step(&w,NULL);
    CHECK(w.order.verb!=CP_STAGE_GO&&w.last_error==-4);
    cp_stage_step(&w,NULL); /* event reason survives the transient blocked flag */
    CHECK(cp_stage_observe(&w,obs,sizeof obs)>0);
    CHECK(strstr(obs,"\"type\":\"path_failed\"")&&strstr(obs,"\"reason\":\"unreachable\""));
    cp_stage_ack_events(&w);
    CHECK(cp_stage_observe(&w,obs,sizeof obs)>0&&!strstr(obs,"path_failed"));
    make_field(0,0);
    field_world(&w,4,60,0,0);
    go.x=10;
    CHECK(cp_stage_order(&w,&go)==0);
    for(int i=0;i<200&&w.order.verb==CP_STAGE_GO;i++)cp_stage_step(&w,NULL);
    CHECK(w.order.verb!=CP_STAGE_GO&&fabsf(w.player.x-10)<.3f);
    CHECK(cp_stage_observe(&w,obs,sizeof obs)>0&&strstr(obs,"\"type\":\"arrived\""));
    return 0;
}
static uint64_t run_script(CpStageWorld *world,uint64_t *out_hashes){
    uint64_t h=0;
    CpStageInput a={.verb=CP_STAGE_GO,.x=40,.z=30};
    for(int i=0;i<600;i++){
        if(i==0||i==80||i==200||i==330){
            a.x=(float)((i*37)%100)-50;
            a.z=(float)((i*53)%100)-50;
        }
        h=cp_stage_step(world,(i==0||i==80||i==200||i==330)?&a:NULL);
        if(out_hashes)out_hashes[i]=h;
    }
    return h;
}
static int test_determinism(void){
    static uint64_t a[600],b[600];
    make_field(.577f,.364f);
    field_world(&w,4,100,0,0);
    field_world(&twin,4,100,0,0);
    CHECK(run_script(&w,a)==run_script(&twin,b));
    CHECK(!memcmp(a,b,sizeof a));
    flat_world(&w,300,4,6);
    flat_world(&twin,300,4,6);
    CHECK(run_script(&w,a)==run_script(&twin,b));
    /* and a snapshot taken mid-turn replays to the same hashes */
    uint8_t *blob=malloc(cp_stage_snapshot_size());
    flat_world(&w,300,4,6);
    CpStageInput g={.verb=CP_STAGE_GO,.x=30,.z=40};
    for(int i=0;i<30;i++)cp_stage_step(&w,i==0?&g:NULL);
    g.x=-30;g.z=-20;
    cp_stage_step(&w,&g);
    CHECK(w.player.omega!=0);
    const int len=cp_stage_snapshot(&w,blob,cp_stage_snapshot_size());
    CHECK(len>0&&cp_stage_restore(&twin,blob,(size_t)len,NULL)==0);
    for(int i=0;i<200;i++)CHECK(cp_stage_step(&w,NULL)==cp_stage_step(&twin,NULL));
    return 0;
}
int main(void){
    int rc=0;
    printf("turns\n");rc|=test_turns();
    printf("no heading snap\n");rc|=test_no_snap();
    printf("pivot rule\n");rc|=test_pivot();
    printf("slopes\n");rc|=test_slopes();
    printf("player ceiling\n");rc|=test_player_ceiling();
    printf("route feedback\n");rc|=test_route_feedback();
    printf("determinism\n");rc|=test_determinism();
    if(rc){fprintf(stderr,"steer_test FAILED\n");return 1;}
    printf("PASS steer (%d checks)\n",checks);
    return 0;
}
