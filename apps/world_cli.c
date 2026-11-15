/* Setup + tick-input replay container shared with web/engine/cpworld.js. */
#include "cpore/world.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
static CpStageWorld world;
static CpStageSetup setup;
static int profile(FILE *f,CpCombatProfile *p){
    unsigned a,b,c,d,e,r;
    int n=fscanf(f,"%u%u%u%u%u%f%f%f%u",&a,&b,&c,&d,&e,&p->hp,&p->stamina,&p->speed,&r);
    if(n!=9||a>5||b>5||c>5||d>5||e>5||r>65535)return -1;
    p->mouth=a;
    p->charge=b;
    p->spit=c;
    p->tail=d;
    p->guard=e;
    p->radius_cm=r;
    return 0;
}
static int replay(const char *path){
    FILE *f=fopen(path,"r");
    if(!f)return 1;
    char magic[32];
    int version,ticks;
    if(fscanf(f,"%31s%d",magic,&version)!=2||strcmp(magic,"CPORE_WORLD_LOG")||version!=CP_STAGE_VERSION)goto invalid;
    memset(&setup,0,sizeof setup);
    if(fscanf(f,"%"SCNu32"%"SCNu32"%d%f%f%f%f%f%f%d%d",&setup.seed,&setup.terrain_seed,&setup.terrain,&setup.nest_x,&setup.nest_z,&setup.flat_height,&setup.water_x,&setup.water_z,&setup.water_radius,&setup.n,&setup.n_obstacles)!=11||setup.n<0||setup.n>CP_STAGE_MAX_WILD||setup.n_obstacles<0||setup.n_obstacles>CP_STAGE_MAX_OBSTACLES||profile(f,&setup.player))goto invalid;
    for(int i=0;i<setup.n;i++){
        CpStageSpawn *c=&setup.wild[i];
        if(fscanf(f,"%f%f%f%f%d%d",&c->x,&c->z,&c->home_x,&c->home_z,&c->species,&c->bot)!=6||profile(f,&c->profile))goto invalid;
    }
    for(int i=0;i<setup.n_obstacles;i++){
        CpStageObstacle *o=&setup.obstacles[i];
        if(fscanf(f,"%f%f%f%d",&o->x,&o->z,&o->r,&o->type)!=4)goto invalid;
    }
    if(cp_stage_reset(&world,&setup)||fscanf(f,"%d",&ticks)!=1||ticks<0||ticks>1000000)goto invalid;
    for(int i=0;i<ticks;i++){
        CpStageInput a={
            0
        };
        int hx,hz;
        if(fscanf(f,"%d%d%d%d%d%d%d%f%f",&a.verb,&a.target,&a.move,&a.dir,&a.sprint,&hx,&hz,&a.x,&a.z)!=9||hx< -32768||hx>32767||hz< -32768||hz>32767)goto invalid;
        a.hx=hx;
        a.hz=hz;
        printf("%016"PRIx64"\n",cp_stage_step(&world,&a));
    }
    int ch;
    do{
        ch=fgetc(f);
    }
    while(ch==' '||ch=='\n'||ch=='\t'||ch=='\r');
    if(ch!=EOF)goto invalid;
    fclose(f);
    return 0;
    invalid:fclose(f);
    fputs("invalid world replay\n",stderr);
    return 1;
}
int main(int argc,char **argv){
    if(argc==3&&!strcmp(argv[1],"--replay"))return replay(argv[2]);
    uint32_t seed=argc>1?(uint32_t)strtoul(argv[1],NULL,10):42;
    cp_stage_setup_default(&setup,seed);
    if(cp_stage_reset(&world,&setup))return 1;
    for(int i=0;i<300;i++){
        if(i==0)cp_stage_command(&world,"approach #1");
        if(i==30)cp_stage_command(&world,"attack #1 0");
        if(i==150)cp_stage_command(&world,"flee");
        if(i==220)cp_stage_command(&world,"go_nest");
        cp_stage_step(&world,NULL);
        if(i%10==0){
            char obs[65536];
            if(cp_stage_observe(&world,obs,sizeof obs)<0)return 1;
            puts(obs);
        }
    }
    printf("{\"final_hash\":\"%016"PRIx64"\"}\n",world.hash);
    return 0;
}
