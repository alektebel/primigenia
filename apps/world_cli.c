/* Setup + tick-input replay container shared with web/engine/cpworld.js. */
#include "cpore/world.h"
#include "cpore/terrain.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <math.h>
static CpStageWorld world;
static CpStageSetup setup;
/* --- island field (PLAN-heights H3): the log names the terrain (seed, n, size, hash); the CLI regenerates it
 * with the default parameters and refuses to replay when the hash differs (another generator version). --- */
static CpTerrain terrain;
static CpTerrainWorkspace workspace;
static CpStageField field;
static int field_ready;
static int make_field(uint32_t seed,int n,float size_m,uint64_t expect,int check){
    CpTerrainParams p;
    cp_terrain_params_default(&p);
    p.seed=seed;
    p.n=n;
    p.size_m=size_m;
    const size_t count=(size_t)n*(size_t)n;
    memset(&terrain,0,sizeof terrain);
    terrain.material=calloc(count,1);
    terrain.river=calloc(count,1);   /* hashed with the terrain, so this hash equals the Godot and terrain_cli ones */
    terrain.height=calloc(count,sizeof(float));
    terrain.flow=calloc(count,sizeof(float));
    terrain.sediment=calloc(count,sizeof(float));
    workspace.scratch=calloc(count,sizeof(float));
    workspace.recv=calloc(count,sizeof(int32_t));
    workspace.ups=calloc(count,sizeof(int32_t));
    workspace.queue=calloc(count,sizeof(int32_t));
    if(!terrain.material||!terrain.river||!terrain.height||!terrain.flow||!terrain.sediment||!workspace.scratch||!workspace.recv||!workspace.ups||!workspace.queue){
        fputs("out of memory\n",stderr);
        return -1;
    }
    if(cp_terrain_generate(&p,&terrain,&workspace,NULL,NULL)){
        fputs("terrain generation failed\n",stderr);
        return -1;
    }
    const uint64_t hash=cp_terrain_hash(&terrain);
    if(check&&hash!=expect){
        fprintf(stderr,"terrain hash mismatch: log made with generator v%d hash %016"PRIx64", this build gives %016"PRIx64"\n",CP_TERRAIN_VERSION,expect,hash);
        return -1;
    }
    field=(CpStageField){n,size_m,size_m/(float)n,size_m*.5f,terrain.height,workspace.scratch,hash};
    field_ready=1;
    return cp_stage_attach_field(&world,&field);
}
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
 * `tick op id a x z v` lines (absolute world ticks; applied before that tick's input). Log v4 is v3 with a tenth column
 * on every input line, `run` (0/1: the run toggle wanted at that tick, set before the step like the Godot session does). */
static int replay(const char *path){
    FILE *f=fopen(path,"r");
    if(!f)return 1;
    char magic[32],snapshot_path[1024]="",word[32];
    int version,ticks;
    CpStageDebugEntry *debug=NULL;
    int n_debug=0,legs_n=-1,legs[CP_STAGE_MAX_WILD+1]={0};
    int grip_n=-1,grip_traits[CP_STAGE_MAX_WILD+1]={0},grip_legs[CP_STAGE_MAX_WILD+1]={0};
    int sec_bits=0,sec_clock=0,sec_cave=0;
    float sec_v[7]={0};   /* C2 secrets header line: `secrets <bits> <start_clock> <cave_on> <x z fx fz half length radius>` */
    if(fscanf(f,"%31s%d",magic,&version)!=2||strcmp(magic,"CPORE_WORLD_LOG")||(version<2||version>5))goto invalid;
    if(version>=3){
        long mark;
        for(;;){
            mark=ftell(f);
            if(fscanf(f,"%31s",word)!=1)goto invalid;
            if(!strcmp(word,"snapshot")){
                if(fscanf(f,"%1023s",snapshot_path)!=1)goto invalid;
            }
            else if(!strcmp(word,"grip")){
                if(fscanf(f,"%d",&grip_n)!=1||grip_n<0||grip_n>CP_STAGE_MAX_WILD)goto invalid;
                for(int i=0;i<=grip_n;i++)if(fscanf(f,"%d%d",&grip_traits[i],&grip_legs[i])!=2||grip_traits[i]<0||grip_traits[i]>63||grip_legs[i]<0||grip_legs[i]>255)goto invalid;
            }
            else if(!strcmp(word,"legs")){
                /* legs <n_wild> <player> <wild...>: leg counts (0 = 4), written only when one is set */
                if(fscanf(f,"%d",&legs_n)!=1||legs_n<0||legs_n>CP_STAGE_MAX_WILD)goto invalid;
                for(int i=0;i<=legs_n;i++)if(fscanf(f,"%d",&legs[i])!=1)goto invalid;
            }
            else if(!strcmp(word,"secrets")){
                if(fscanf(f,"%d%d%d",&sec_bits,&sec_clock,&sec_cave)!=3||sec_bits<0||sec_bits>3||sec_clock<0||sec_clock>=CP_STAGE_DAY_TICKS)goto invalid;
                for(int i=0;i<7;i++)if(fscanf(f,"%f",&sec_v[i])!=1)goto invalid;
            }
            else if(!strcmp(word,"field")){
                unsigned seed;
                int n;
                float size;
                unsigned long long hash;
                if(fscanf(f,"%u%d%f%16llx",&seed,&n,&size,&hash)!=4||n<8||n>2048||!(size>0))goto invalid;
                if(make_field(seed,n,size,hash,1))goto invalid_quiet;
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
    if(grip_n>=0){
        if(grip_n!=setup.n)goto invalid;
        setup.player.grip_traits=grip_traits[0];setup.player.grip_legs=grip_legs[0];
        for(int i=0;i<setup.n;i++){setup.wild[i].profile.grip_traits=grip_traits[i+1];setup.wild[i].profile.grip_legs=grip_legs[i+1];}
    }
    setup.secrets=sec_bits;
    setup.start_clock=sec_clock;
    if(sec_cave)setup.cave=(CpStageCave){1,sec_v[0],sec_v[1],sec_v[2],sec_v[3],0,sec_v[4],sec_v[5],sec_v[6]};
    if(legs_n==setup.n){
        setup.player_legs=legs[0];
        for(int i=0;i<setup.n;i++)setup.wild[i].legs=legs[i+1];
    }
    if(snapshot_path[0]){
        char full[2048];
        const char *slash=strrchr(path,'/');
        if(slash&&snapshot_path[0]!='/')snprintf(full,sizeof full,"%.*s/%s",(int)(slash-path),path,snapshot_path);
        else snprintf(full,sizeof full,"%s",snapshot_path);
        FILE *sf=fopen(full,"rb");
        static uint8_t blob[48+offsetof(CpStageWorld,field)];
        size_t len=sf?fread(blob,1,sizeof blob,sf):0;
        if(sf)fclose(sf);
        int rc=cp_stage_restore(&world,blob,len,field_ready?&field:NULL);
        if(rc){
            fprintf(stderr,"snapshot %s: %s\n",full,cp_stage_snapshot_error(rc));
            goto invalid_quiet;
        }
    }
    else if(cp_stage_reset(&world,&setup))goto invalid;
    if(fscanf(f,"%d",&ticks)!=1||ticks<0||ticks>1000000)goto invalid;
    CpStageInput *inputs=calloc((size_t)ticks+1,sizeof *inputs);
    int *runs=calloc((size_t)ticks+1,sizeof *runs);   /* v4: the run toggle wanted at each tick (set before the step) */
    if(!inputs||!runs){free(inputs);free(runs);goto invalid;}
    for(int i=0;i<ticks;i++){
        CpStageInput *a=&inputs[i];
        int hx,hz;
        if(fscanf(f,"%d%d%d%d%d%d%d%f%f",&a->verb,&a->target,&a->move,&a->dir,&a->sprint,&hx,&hz,&a->x,&a->z)!=9||hx< -32768||hx>32767||hz< -32768||hz>32767||(version>=4&&(fscanf(f,"%d",&runs[i])!=1||(runs[i]&~(version==5?3:1))))){
            free(inputs);free(runs);
            goto invalid;
        }
        a->hx=hx;
        a->hz=hz;
    }
    if(version>=3){
        if(fscanf(f,"%d",&n_debug)!=1||n_debug<0||n_debug>1000000){
            free(inputs);free(runs);
            goto invalid;
        }
        debug=calloc((size_t)n_debug+1,sizeof *debug);
        if(!debug){
            free(inputs);free(runs);
            goto invalid;
        }
        for(int i=0;i<n_debug;i++){
            CpStageDebugEntry *e=&debug[i];
            if(fscanf(f,"%"SCNu32"%d%d%d%f%f%f",&e->tick,&e->d.op,&e->d.id,&e->d.a,&e->d.x,&e->d.z,&e->d.v)!=7||(i&&e->tick<debug[i-1].tick)){
                free(inputs);free(runs);
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
        free(inputs);free(runs);
        goto invalid;
    }
    int cursor=0;
    if(n_debug&&debug[0].tick<world.tick){
        fprintf(stderr,"debug op at tick %"PRIu32" is before the first replayed tick %"PRIu32"\n",debug[0].tick,world.tick);
        free(inputs);free(runs);
        goto invalid_quiet;
    }
    for(int i=0;i<ticks;i++){
        while(cursor<n_debug&&debug[cursor].tick==world.tick){
            int rc=cp_stage_debug(&world,&debug[cursor].d);
            if(rc){
                fprintf(stderr,"debug op %d at tick %"PRIu32" was rejected: %s (a log only holds accepted ops)\n",debug[cursor].d.op,debug[cursor].tick,cp_stage_debug_error(rc));
                free(inputs);free(runs);
                goto invalid_quiet;
            }
            cursor++;
        }
        if(version>=4){cp_stage_set_run(&world,runs[i]&1);if(runs[i]&2)cp_stage_jump(&world);}
        printf("%016"PRIx64"\n",cp_stage_step(&world,&inputs[i]));
    }
    free(inputs);free(runs);
    free(debug);
    fclose(f);
    return 0;
    invalid:fputs("invalid world replay\n",stderr);
    invalid_quiet:fclose(f);
    free(debug);
    return 1;
}
/* --- recording on the island: world_cli --field <seed> <n> <out.log>  (hashes go to stdout) ---
 * The scripted 300-tick run of the default mode, on the generated terrain. The nest is the first dry spot
 * (valley centre, then rings), Garfio's home the first of 64 directions 60 m away whose straight path is dry,
 * gentle and walkable: the same rules as godot/game/stage/stage_setup.gd. */
static float ground_at(float x,float z){
    return cp_stage_ground(&world,x,z);
}
static int dry(float x,float z){
    return ground_at(x,z)>1&&cp_stage_water_depth(&world,x,z)==0;
}
static float normal_y(float x,float z){
    const float c=field.cell,dx=ground_at(x+c,z)-ground_at(x-c,z),dz=ground_at(x,z+c)-ground_at(x,z-c);
    return 2*c/sqrtf(dx*dx+4*c*c+dz*dz);
}
static void putprofile(FILE *f,const CpCombatProfile *p){
    fprintf(f,"%u %u %u %u %u %.9g %.9g %.9g %u\n",p->mouth,p->charge,p->spit,p->tail,p->guard,p->hp,p->stamina,p->speed,p->radius_cm);
}
static int record_field(uint32_t seed,int n,const char *out){
    CpTerrainParams d;
    cp_terrain_params_default(&d);
    world.setup.terrain=CP_STAGE_FIELD;
    if(make_field(seed,n,d.size_m,0,0))return 1;
    cp_stage_setup_default(&setup,seed);
    setup.terrain=CP_STAGE_FIELD;
    setup.n=1;
    float nx=0,nz=0;
    if(!dry(0,0)){
        int found=0;
        for(int r=5;r<190&&!found;r+=5)for(int k=0;k<32&&!found;k++){
            float a=k*6.2831853f/32,x=sinf(a)*r,z=cosf(a)*r;
            if(dry(x,z)){nx=x;nz=z;found=1;}
        }
    }
    int homed=0;
    float hx=0,hz=0;
    for(int k=0;k<64&&!homed;k++){
        float a=k*6.2831853f/64,tx=nx+sinf(a)*60,tz=nz+cosf(a)*60;
        if(fabsf(tx)>cp_stage_bound(&world)-1||fabsf(tz)>cp_stage_bound(&world)-1)continue;
        int ok=1;
        for(int s=0;s<=20&&ok;s++){
            float px=nx+(tx-nx)*s/20,pz=nz+(tz-nz)*s/20;
            if(!dry(px,pz)||normal_y(px,pz)<=.8f)ok=0;
        }
        if(ok&&cp_stage_can_walk(&world,nx,nz,tx,tz,.6f)){hx=tx;hz=tz;homed=1;}
    }
    if(!homed){fputs("no dry gentle home for Garfio on this island\n",stderr);return 1;}
    setup.nest_x=nx;setup.nest_z=nz;
    setup.wild[0].x=setup.wild[0].home_x=hx;
    setup.wild[0].z=setup.wild[0].home_z=hz;
    if(cp_stage_reset(&world,&setup)){fputs("reset failed\n",stderr);return 1;}
    enum{TICKS=300};
    static CpStageInput inputs[TICKS];
    static uint64_t hashes[TICKS];
    for(int i=0;i<TICKS;i++){
        const char *cmd=i==0?"approach #1":i==30?"attack #1 0":i==150?"flee":i==220?"go_nest":NULL;
        if(cmd){
            CpStageWorld *tmp=malloc(sizeof *tmp);
            if(!tmp)return 1;
            *tmp=world;
            if(cp_stage_command(tmp,cmd)==0)inputs[i]=tmp->order;
            free(tmp);
        }
        hashes[i]=cp_stage_step(&world,&inputs[i]);
    }
    FILE *f=fopen(out,"w");
    if(!f)return 1;
    fprintf(f,"CPORE_WORLD_LOG 3\nfield %"PRIu32" %d %.9g %016"PRIx64"\n",seed,n,field.size_m,field.hash);
    fprintf(f,"%"PRIu32" %"PRIu32" %d %.9g %.9g %.9g %.9g %.9g %.9g %d %d\n",setup.seed,setup.terrain_seed,setup.terrain,setup.nest_x,setup.nest_z,setup.flat_height,setup.water_x,setup.water_z,setup.water_radius,setup.n,setup.n_obstacles);
    putprofile(f,&setup.player);
    for(int i=0;i<setup.n;i++){
        const CpStageSpawn *c=&setup.wild[i];
        fprintf(f,"%.9g %.9g %.9g %.9g %d %d\n",c->x,c->z,c->home_x,c->home_z,c->species,c->bot);
        putprofile(f,&c->profile);
    }
    fprintf(f,"%d\n",TICKS);
    for(int i=0;i<TICKS;i++){
        const CpStageInput *a=&inputs[i];
        fprintf(f,"%d %d %d %d %d %d %d %.9g %.9g\n",a->verb,a->target,a->move,a->dir,a->sprint,a->hx,a->hz,a->x,a->z);
    }
    fputs("0\n",f);
    fclose(f);
    for(int i=0;i<TICKS;i++)printf("%016"PRIx64"\n",hashes[i]);
    return 0;
}
int main(int argc,char **argv){
    if(argc==3&&!strcmp(argv[1],"--replay"))return replay(argv[2]);
    if(argc==5&&!strcmp(argv[1],"--field"))return record_field((uint32_t)strtoul(argv[2],NULL,10),atoi(argv[3]),argv[4]);
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
