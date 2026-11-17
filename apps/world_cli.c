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
/* Log v2: header, setup, one input per tick. Log v3 (PLAN-devtools step 4) adds, right after the header, an
 * optional `snapshot <file>` line (path relative to the log: restore it instead of resetting from the setup;
 * the per-tick inputs then start at the snapshot's tick) and, after the inputs, `<n_debug>` followed by
 * `tick op id a x z v` lines (absolute world ticks; applied before that tick's input). */
static int replay(const char *path){
    FILE *f=fopen(path,"r");
    if(!f)return 1;
    char magic[32],snapshot_path[1024]="",word[32];
    int version,ticks;
    CpStageDebugEntry *debug=NULL;
    int n_debug=0;
    if(fscanf(f,"%31s%d",magic,&version)!=2||strcmp(magic,"CPORE_WORLD_LOG")||(version!=2&&version!=3))goto invalid;
    if(version==3){
        long mark;
        for(;;){
            mark=ftell(f);
            if(fscanf(f,"%31s",word)!=1)goto invalid;
            if(!strcmp(word,"snapshot")){
                if(fscanf(f,"%1023s",snapshot_path)!=1)goto invalid;
            }
            else{
                fseek(f,mark,SEEK_SET);
                break;
            }
        }
    }
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
    if(snapshot_path[0]){
        char full[2048];
        const char *slash=strrchr(path,'/');
        if(slash&&snapshot_path[0]!='/')snprintf(full,sizeof full,"%.*s/%s",(int)(slash-path),path,snapshot_path);
        else snprintf(full,sizeof full,"%s",snapshot_path);
        FILE *sf=fopen(full,"rb");
        static uint8_t blob[1<<16];
        size_t len=sf?fread(blob,1,sizeof blob,sf):0;
        if(sf)fclose(sf);
        int rc=cp_stage_restore(&world,blob,len,NULL);
        if(rc){
            fprintf(stderr,"snapshot %s: %s\n",full,cp_stage_snapshot_error(rc));
            goto invalid_quiet;
        }
    }
    else if(cp_stage_reset(&world,&setup))goto invalid;
    if(fscanf(f,"%d",&ticks)!=1||ticks<0||ticks>1000000)goto invalid;
    CpStageInput *inputs=calloc((size_t)ticks+1,sizeof *inputs);
    if(!inputs)goto invalid;
    for(int i=0;i<ticks;i++){
        CpStageInput *a=&inputs[i];
        int hx,hz;
        if(fscanf(f,"%d%d%d%d%d%d%d%f%f",&a->verb,&a->target,&a->move,&a->dir,&a->sprint,&hx,&hz,&a->x,&a->z)!=9||hx< -32768||hx>32767||hz< -32768||hz>32767){
            free(inputs);
            goto invalid;
        }
        a->hx=hx;
        a->hz=hz;
    }
    if(version==3){
        if(fscanf(f,"%d",&n_debug)!=1||n_debug<0||n_debug>1000000){
            free(inputs);
            goto invalid;
        }
        debug=calloc((size_t)n_debug+1,sizeof *debug);
        if(!debug){
            free(inputs);
            goto invalid;
        }
        for(int i=0;i<n_debug;i++){
            CpStageDebugEntry *e=&debug[i];
            if(fscanf(f,"%"SCNu32"%d%d%d%f%f%f",&e->tick,&e->d.op,&e->d.id,&e->d.a,&e->d.x,&e->d.z,&e->d.v)!=7||(i&&e->tick<debug[i-1].tick)){
                free(inputs);
                goto invalid;
            }
        }
    }
    int ch;
    do{
        ch=fgetc(f);
    }
    while(ch==' '||ch=='\n'||ch=='\t'||ch=='\r');
    if(ch!=EOF){
        free(inputs);
        goto invalid;
    }
    int cursor=0;
    if(n_debug&&debug[0].tick<world.tick){
        fprintf(stderr,"debug op at tick %"PRIu32" is before the first replayed tick %"PRIu32"\n",debug[0].tick,world.tick);
        free(inputs);
        goto invalid_quiet;
    }
    for(int i=0;i<ticks;i++){
        while(cursor<n_debug&&debug[cursor].tick==world.tick){
            int rc=cp_stage_debug(&world,&debug[cursor].d);
            if(rc){
                fprintf(stderr,"debug op %d at tick %"PRIu32" was rejected: %s (a log only holds accepted ops)\n",debug[cursor].d.op,debug[cursor].tick,cp_stage_debug_error(rc));
                free(inputs);
                goto invalid_quiet;
            }
            cursor++;
        }
        printf("%016"PRIx64"\n",cp_stage_step(&world,&inputs[i]));
    }
    free(inputs);
    free(debug);
    fclose(f);
    return 0;
    invalid:fputs("invalid world replay\n",stderr);
    invalid_quiet:fclose(f);
    free(debug);
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
