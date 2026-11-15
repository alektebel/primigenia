/* The existing combat ABI views the encounter owned by CpStageWorld. */
#include "wasm_api.c"
#include "cpore/world.h"
#include <string.h>
static CpStageWorld stage;
static CpStageSetup stage_setup;
static float metadata[24],entities[(CP_STAGE_MAX_WILD+1)*18];
static char observation[65536];
int cw_version(void){return CP_STAGE_VERSION;}
void cw_config(uint32_t seed,uint32_t terrain_seed,int terrain,float nx,float nz,float height,float wx,float wz,float wr,int n){
 cp_stage_setup_default(&stage_setup,seed);stage_setup.terrain_seed=terrain_seed;stage_setup.terrain=terrain;stage_setup.nest_x=nx;stage_setup.nest_z=nz;stage_setup.flat_height=height;stage_setup.water_x=wx;stage_setup.water_z=wz;stage_setup.water_radius=wr;stage_setup.n=n;
}
int cw_profile(int id,int mouth,int charge,int spit,int tail,int guard,float hp,float stamina,float speed,int radius){
 if(id<0||id>CP_STAGE_MAX_WILD||mouth<0||mouth>5||charge<0||charge>5||spit<0||spit>5||tail<0||tail>5||guard<0||guard>5||radius<0||radius>65535)return -1;
 CpCombatProfile p={(uint8_t)mouth,(uint8_t)charge,(uint8_t)spit,(uint8_t)tail,(uint8_t)guard,hp,stamina,speed,(uint16_t)radius};
 if(id==0)stage_setup.player=p;else stage_setup.wild[id-1].profile=p;return 0;
}
int cw_spawn(int id,float x,float z,float hx,float hz,int species,int bot){if(id<1||id>CP_STAGE_MAX_WILD)return -1;CpStageSpawn *s=&stage_setup.wild[id-1];s->x=x;s->z=z;s->home_x=hx;s->home_z=hz;s->species=species;s->bot=bot;return 0;}
int cw_obstacle(int index,float x,float z,float r,int type){if(index<0||index>=CP_STAGE_MAX_OBSTACLES)return -1;stage_setup.obstacles[index]=(CpStageObstacle){x,z,r,type};if(stage_setup.n_obstacles<=index)stage_setup.n_obstacles=index+1;return 0;}
int cw_reset(void){int result=cp_stage_reset(&stage,&stage_setup);if(result==0)combat_world=&stage.combat;return result;}
float cw_height(float x,float z){return cp_stage_height(&stage,x,z);}
float cw_ground(float x,float z){return cp_stage_ground(&stage,x,z);}
int cw_step(int verb,int target,int move,int dir,int sprint,int hx,int hz,float x,float z){
 if(hx< -32768||hx>32767||hz< -32768||hz>32767)return -1;
 CpStageInput a={verb,target,move,dir,sprint,(int16_t)hx,(int16_t)hz,x,z};cp_stage_step(&stage,&a);return stage.last_error;}
uint32_t *cw_hash(void){uint64_t h=cp_stage_hash(&stage);hash_words[0]=(uint32_t)h;hash_words[1]=(uint32_t)(h>>32);return hash_words;}
float *cw_meta(void){float row[]={stage.tick,stage.clock,stage.active,stage.started,stage.outcome,stage.respawn_ticks,stage.cooldown_ticks,stage.arena_x,stage.arena_z,stage.order.verb,stage.order.target,stage.order.move,stage.order.x,stage.order.z,stage.accepted[0],stage.accepted[1],stage.setup.n};memcpy(metadata,row,sizeof row);return metadata;}
float *cw_entities(void){for(int i=0;i<=stage.setup.n;i++){const CpStageCreature *c=i?&stage.wild[i-1]:&stage.player;float row[]={c->x,c->z,c->fx,c->fz,c->hp,c->stamina,c->speed,c->acceleration,c->turn_rate,c->dead,c->returning,c->species,c->home_x,c->home_z,c->pivot,c->goal_x,c->goal_z,c->roam_ticks};memcpy(entities+i*18,row,sizeof row);}return entities;}
int *cw_orders(void){static int rows[16];for(int i=0;i<2;i++){CpCombatAction *a=&stage.combat_orders[i];int row[]={stage.combat.tick-1,i,a->verb,a->move,a->target,a->dir,a->heading_x,a->heading_y};memcpy(rows+i*8,row,sizeof row);}return rows;}
char *cw_observe(void){if(cp_stage_observe(&stage,observation,sizeof observation)<0)return NULL;return observation;}
