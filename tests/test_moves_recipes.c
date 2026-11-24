#include "cpore/world.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
static CpCombatWorld pair(void){
 CpCombatSetup s={0};s.n=2;s.flat=1;
 for(int i=0;i<2;i++){
  CpCombatSpawn *c=&s.c[i];cp_combat_profile_default(&c->prof);memset(c->prof.extra,3,8);c->prof.carnivore=1;c->prof.hp=1000;c->prof.stamina=1000;
  c->x=10+1.5f*i;c->y=10;c->fx=i?-1:1;c->team=i;c->calcium=100;
  c->has_loadout=1;cp_combat_loadout_default(&c->loadout,&c->prof);c->loadout.known|=1u<<CB_SPINE_VOLLEY;c->loadout.sig_slot=3;c->loadout.slot[3]=CB_SPINE_VOLLEY;
 }
 CpCombatWorld w;cp_combat_reset(&w,&s);return w;
}
static void phase(CpCombatCreature *c,int m,int ph){c->move=m;c->phase=ph;c->ptick=0;c->plen=100;c->dash_x=c->dash_y=0;}
static void rules(void){
 cp_combat_test_hit_variance(1);
 for(int k=7;k<CP_COMBAT_N_COUNTERS;k++){
  const CpCombatCounter *r=&CP_COMBAT_COUNTERS[k];CpCombatWorld w=pair();int m=r->attack<0?CB_QUILL_VOLLEY:r->attack;
  int ph=(r->phases&CB_PH_BIT(CB_PH_ACTIVE))?CB_PH_ACTIVE:CB_PH_WINDUP;
  phase(&w.c[0],m,CB_PH_ACTIVE);phase(&w.c[1],r->defend,ph);
  CpCombatPreview p;cp_combat_preview(&w,0,m,1,&p);assert(p.effect==r->effect);
  cp_combat_step(&w);
  if(r->effect==CB_EFF_NEGATE)assert(w.c[1].hp==1000);
  if(r->effect==CB_EFF_PIERCE){assert(w.c[1].bleed_t>0);assert(w.c[1].dmg_taken==cp_combat_move_damage(&w.c[0].prof,m)*r->mult);assert(w.c[0].move==m);}
  if(r->effect==CB_EFF_INTERRUPT)assert(w.c[1].interrupted==1);
  if(r->effect==CB_EFF_BREAK)assert(w.c[1].move==CB_MOVE_NONE);
 }
 CpCombatWorld w=pair();phase(&w.c[0],CB_ROAR,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].fear_t>0);float x=w.c[1].x;cp_combat_step(&w);assert(w.c[1].x>x);
 w=pair();phase(&w.c[0],CB_STOMP,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].stun_t>0);
 w=pair();phase(&w.c[0],CB_BITE,CB_PH_ACTIVE);w.c[1].mineral=100;cp_combat_step(&w);assert(w.c[1].dmg_taken==cp_combat_move_damage(&w.c[0].prof,CB_BITE)*.75f);
 /* Two nearest targets, even when a farther target has a lower entity id. */
 w=pair();w.n=4;w.c[2]=w.c[1];w.c[3]=w.c[1];w.c[1].x=16;w.c[2].x=14;w.c[3].x=12;
 phase(&w.c[0],CB_SPINE_VOLLEY,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].hp==1000&&w.c[2].hp<1000&&w.c[3].hp<1000);
 /* Resource already paid on start, even when a close bite cancels the volley. */
 w=pair();cp_combat_attack(&w,0,1,CB_SPINE_VOLLEY);cp_combat_step(&w);assert(w.c[0].calcium==80);phase(&w.c[1],CB_BITE,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[0].interrupted==1&&w.c[0].calcium==80);
 /* Same-tick active bite suppresses both spine targets. */
 w=pair();phase(&w.c[0],CB_SPINE_VOLLEY,CB_PH_ACTIVE);phase(&w.c[1],CB_BITE,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].hp==1000);
 w=pair();w.c[1].x=8.5f;phase(&w.c[0],CB_ROAR,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].fear_t>0);
 w=pair();w.c[1].x=8.5f;phase(&w.c[0],CB_STOMP,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].stun_t>0);
 w=pair();w.c[1].fx=1;phase(&w.c[0],CB_BITE,CB_PH_ACTIVE);phase(&w.c[1],CB_CURL_UP,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].dmg_taken==cp_combat_move_damage(&w.c[0].prof,CB_BITE)*1.5f*.25f);
 w=pair();w.c[1].mineral=100;CpCombatAction a={.verb=CB_V_MOVE,.dir=0};cp_combat_order(&w,0,&a);cp_combat_order(&w,1,&a);cp_combat_step(&w);assert(w.c[0].x-10>w.c[1].x-11.5f);
 w=pair();assert(!cp_combat_attack(&w,0,1,CB_SPINE_VOLLEY));w.c[0].calcium=0;cp_combat_step(&w);int no_meter=0;for(int k=0;k<w.n_ev;k++)no_meter|=w.ev[k].type==CB_EV_NO_METER;assert(no_meter);
 w=pair();w.c[1].stamina=0;phase(&w.c[0],CB_SPINE_VOLLEY,CB_PH_ACTIVE);phase(&w.c[1],CB_GUARD,CB_PH_ACTIVE);cp_combat_step(&w);assert(w.c[1].dmg_taken==cp_combat_move_damage(&w.c[0].prof,CB_SPINE_VOLLEY)&&w.c[1].stun_t>0);
 cp_combat_test_hit_variance(0);
}
static void nodes(void){
 CpStageWorld *w=calloc(1,sizeof *w);CpStageSetup s;cp_stage_setup_default(&s,1);s.n=0;s.terrain=CP_STAGE_FLAT;
 for(unsigned seed=1;seed<=200;seed++){
  s.seed=seed;assert(!cp_stage_reset(w,&s));assert(w->recipes.n_stones==6);
  for(int i=0;i<w->recipes.n_stones;i++)assert(cp_stage_walkable_from_nest(w,w->recipes.stones[i].x,w->recipes.stones[i].z));
 }
 CpStagePartNode *n=&w->recipes.stones[0];w->player.x=n->x;w->player.z=n->z;
 assert(!cp_stage_command(w,"eat #4000"));for(int k=0;k<5;k++)cp_stage_step(w,NULL);assert(w->recipes.mineral==25&&n->inspected==1);
 assert(!cp_stage_command(w,"eat #4000"));cp_stage_command(w,"wait");/* movement/order cancellation */
 w->player.x+=5;for(int k=0;k<5;k++)cp_stage_step(w,NULL);assert(w->recipes.mineral==25);
 /* Inspecting an old carcass unlocks eating its two bone units. */
 int old=-1;for(int k=0;k<w->parts.n_nodes;k++)if(w->parts.nodes[k].kind==CP_PART_OLD_CARCASS){old=k;break;}assert(old>=0);
 w->parts.nodes[old].inspected=1;w->player.x=w->parts.nodes[old].x;w->player.z=w->parts.nodes[old].z;
 char cmd[32];snprintf(cmd,sizeof cmd,"eat #%d",3000+old);
 for(int j=0;j<2;j++){assert(!cp_stage_command(w,cmd));for(int k=0;k<5;k++)cp_stage_step(w,NULL);}
 assert(w->recipes.calcium==40&&cp_stage_command(w,cmd)<0);
 free(w);
}

static void edges(void){
 CpStageWorld *w=calloc(1,sizeof *w);CpStageSetup s;cp_stage_setup_default(&s,7);s.n=2;s.terrain=CP_STAGE_FLAT;s.n_obstacles=0;s.wild[0].species=2;s.wild[1].species=1;s.wild[1].profile=CP_STAGE_SPECIES[1].profile;s.wild[1].bot=-1;assert(!cp_stage_reset(w,&s));
 assert(w->recipes.wild_calcium[0]==40&&w->recipes.wild_calcium[1]==0);
 assert(!cp_stage_recipe_ready(w));cp_stage_recipe_clue(w,-1);cp_stage_recipe_clue(w,3);
 cp_stage_meter_add(NULL,0,1);cp_stage_meter_add(w,-1,1);cp_stage_meter_add(w,2,1);
 cp_stage_meter_add(w,0,90);cp_stage_meter_add(w,0,20);assert(w->recipes.calcium==100);cp_stage_meter_add(w,0,-90);cp_stage_meter_add(w,0,-20);assert(w->recipes.calcium==0);
 cp_stage_meter_add(w,1,25);cp_stage_meter_add(w,1,-25);assert(!w->player.profile.extra[6]);
 w->recipes.state=CP_RECIPE_KNOWN;w->player.profile.extra[7]=2;w->player.profile.mouth=1;assert(!cp_stage_recipe_ready(w));w->player.profile.mouth=2;w->player.profile.carnivore=0;assert(!cp_stage_recipe_ready(w));
 w->recipes.state=CP_RECIPE_MASTERED;cp_stage_recipe_clue(w,2);assert(w->recipes.state==CP_RECIPE_MASTERED);
 assert(cp_stage_stone_eat(w,2999)<0&&cp_stage_stone_eat(w,3999)<0&&cp_stage_stone_eat(w,5000)<0);
 w->active=0;assert(cp_stage_stone_eat(w,4000)==CP_STAGE_ERR_IN_FIGHT);w->active=-1;w->respawn_ticks=1;assert(cp_stage_stone_eat(w,4000)==CP_STAGE_ERR_IN_FIGHT);w->respawn_ticks=0;
 assert(cp_stage_stone_eat(w,3001)<0);w->recipes.stones[0].inspected=4;assert(cp_stage_stone_eat(w,4000)<0);w->recipes.stones[0].inspected=0;
 w->player.x=1000;assert(cp_stage_stone_eat(w,4000)<0);w->player.x=w->recipes.stones[0].x;w->player.z=w->recipes.stones[0].z;
 w->recipes.mineral=100;assert(cp_stage_stone_eat(w,4000)==CP_STAGE_ERR_FULL);w->recipes.mineral=0;
 w->parts.nodes[1].inspected=1;w->social.diet=CP_DIET_HERBIVORE;assert(cp_stage_stone_eat(w,3001)==CP_STAGE_ERR_DIET);w->social.diet=CP_DIET_CARNIVORE;
 w->recipes.cd[CB_POUNCE]=30;cp_stage_recipes_step(w);assert(w->recipes.cd[CB_POUNCE]==29);
 for(int cause=0;cause<3;cause++){
  assert(!cp_stage_stone_eat(w,4000));if(cause==0)w->active=0;else if(cause==1)w->respawn_ticks=1;else w->order.verb=CP_STAGE_HEADING;
  cp_stage_recipes_step(w);assert(!w->recipes.eat_node);w->active=-1;w->respawn_ticks=0;
 }
 char out[4096];for(int cap=0;cap<1500;cap++)cp_stage_recipes_json(w,out,cap);assert(cp_stage_recipes_json(w,out,sizeof out)>0);
 /* A sloping dry field and a low field exercise alpine selection and rejection. */
 float height[256];CpStageField f={.n=16,.size_m=400,.cell=25,.half=200,.height=height,.hash=7};
 for(int mode=0;mode<3;mode++){
  for(int i=0;i<256;i++)height[i]=mode==0?100+(i%16)*.5f:mode==1?0:(i%16<8?70:100);
  f.hash=7+mode;s.terrain=CP_STAGE_FIELD;s.n=0;assert(!cp_stage_attach_field(w,&f));assert(!cp_stage_reset(w,&s));
  for(int i=0;i<w->recipes.n_stones;i++){assert(cp_stage_ground(w,w->recipes.stones[i].x,w->recipes.stones[i].z)>=80);uint64_t h=cp_stage_hash(w);assert(cp_stage_route_from_nest(w,w->recipes.stones[i].x,w->recipes.stones[i].z));assert(h==cp_stage_hash(w));}
 }
 float ridge[1024],water[1024];
 for(int j=0;j<32;j++)for(int i=0;i<32;i++){
  float x=-200+(i+.5f)*12.5f;int k=j*32+i;ridge[k]=70+(x>0?x*.2f:0);water[k]=ridge[k]+((i==19||i==20)&&j<29?2:0);
 }
 f=(CpStageField){.n=32,.size_m=400,.cell=12.5f,.half=200,.height=ridge,.water_level=water,.hash=10};
 assert(!cp_stage_attach_field(w,&f));assert(!cp_stage_reset(w,&s));assert(w->recipes.n_stones>0);
 w->n_path=1;w->path[0][0]=3;w->path[0][1]=4;w->blocked_ticks=2;
 for(int i=0;i<w->recipes.n_stones;i++){uint64_t h=cp_stage_hash(w);assert(cp_stage_route_from_nest(w,w->recipes.stones[i].x,w->recipes.stones[i].z));assert(h==cp_stage_hash(w));}
 free(w);
}

static void genome_and_observe(void){
 const char *fmt="{\"schema\":\"cpore.creature/5\",\"name\":\"Spiner\",\"nodes\":[{\"y\":1,\"z\":-2,\"r\":0.1},{\"y\":1,\"z\":-1,\"r\":0.6},{\"y\":1,\"z\":0,\"r\":0.6},{\"y\":1,\"z\":1,\"r\":0.1}],\"parts\":[{\"type\":\"fauces\",\"t\":1,\"ang\":0,\"size\":1,\"level\":2,\"tier\":0},{\"type\":\"espinas_dorsales\",\"t\":0.5,\"ang\":0,\"size\":1,\"level\":2,\"tier\":0}%s],\"skin\":{\"pat\":0,\"wet\":0.3,\"scale\":7,\"cA\":\"#aabbcc\",\"cB\":\"#112233\",\"cC\":\"#ffffff\"},\"regions\":[]}";
 char body[4096];CpLineageForm f;snprintf(body,sizeof body,fmt,"");assert(!cp_stage_genome_form(body,&f));assert(f.profile.carnivore&&f.profile.extra[7]==2);
 snprintf(body,sizeof body,fmt,",{\"type\":\"romo\",\"t\":1,\"ang\":0,\"size\":1,\"level\":1,\"tier\":0}");assert(!cp_stage_genome_form(body,&f));assert(!f.profile.carnivore);
 CpStageWorld *w=calloc(1,sizeof *w);CpStageSetup s;cp_stage_setup_default(&s,42);s.terrain=CP_STAGE_FLAT;s.n=1;s.n_obstacles=0;s.wild[0]=(CpStageSpawn){.x=20,.z=0,.home_x=20,.home_z=0,.species=2,.bot=0,.profile=CP_STAGE_SPECIES[2].profile};assert(!cp_stage_reset(w,&s));w->debug_flags=CP_STAGE_FLAG_AI_OFF;
 assert(!cp_stage_command(w,"observe #1"));for(int i=0;i<150;i++)cp_stage_step(w,NULL);
 assert(w->recipes.state==CP_RECIPE_HINTED&&w->recipes.wild_calcium[0]==0);assert(w->social.learned&(1u<<CB_QUILL_VOLLEY));
 int volleys=0;for(unsigned i=0;i<w->ev_total;i++)if(w->events[i%CP_STAGE_MAX_EVENTS].type==CP_STAGE_EV_VOLLEY)volleys++;assert(volleys==2);
 s.wild[0].x=s.wild[0].home_x=6;s.wild[0].species=3;s.wild[0].profile.hp=1000;assert(!cp_stage_reset(w,&s));w->debug_flags=CP_STAGE_FLAG_AI_OFF;
 w->player.profile.extra[7]=2;w->player.profile.carnivore=1;w->player.profile.mouth=2;w->recipes.state=CP_RECIPE_KNOWN;cp_stage_meter_add(w,0,60);assert(!cp_stage_command(w,"loadout 4 spine_volley"));assert(!cp_stage_command(w,"attack #1 spine_volley"));
 for(int i=0;i<100&&w->recipes.state!=CP_RECIPE_MASTERED;i++)cp_stage_step(w,NULL);
 assert(w->recipes.state==CP_RECIPE_MASTERED&&w->recipes.calcium==40);
 assert(w->recipes.quill_carcass[0]);assert(!cp_stage_command(w,"attack #1 bite"));
 for(int i=0;i<100&&w->recipes.quill_carcass[0];i++)cp_stage_step(w,NULL);assert(!w->recipes.quill_carcass[0]);
 s.wild[0].species=2;s.wild[0].profile.hp=22;assert(!cp_stage_reset(w,&s));w->debug_flags=CP_STAGE_FLAG_AI_OFF;
 w->player.profile.extra[7]=2;w->player.profile.carnivore=1;w->recipes.state=CP_RECIPE_KNOWN;cp_stage_meter_add(w,0,20);
 assert(!cp_stage_command(w,"loadout 4 spine_volley"));assert(!cp_stage_command(w,"attack #1 spine_volley"));
 for(int i=0;i<100&&!w->wild[0].dead;i++)cp_stage_step(w,NULL);assert(w->wild[0].dead&&w->recipes.quill_carcass[0]);
 assert(!cp_stage_command(w,"observe #1"));for(int i=0;i<50;i++)cp_stage_step(w,NULL);assert(w->recipes.clues&4);
 /* Repeated public attacks with meter 60 really launch exactly three volleys. */
 CpCombatWorld fight=pair();fight.c[0].calcium=60;fight.c[1].hp=100000;for(int i=0;i<900;i++){cp_combat_attack(&fight,0,1,CB_SPINE_VOLLEY);cp_combat_step(&fight);}assert(fight.c[0].volleys==3&&fight.c[0].calcium==0);
 free(w);
}

int main(void){
 rules();nodes();edges();genome_and_observe();
 CpStageWorld *w=calloc(1,sizeof *w);CpStageSetup s;cp_stage_setup_default(&s,42);s.n=0;s.terrain=CP_STAGE_FLAT;assert(!cp_stage_reset(w,&s));
 assert(w->recipes.state==CP_RECIPE_UNKNOWN);
 cp_stage_recipe_clue(w,0);assert(w->recipes.state==CP_RECIPE_HINTED);cp_stage_recipe_clue(w,0);assert(w->recipes.state==CP_RECIPE_HINTED);
 cp_stage_recipe_clue(w,1);assert(w->recipes.state==CP_RECIPE_KNOWN);
 assert(!cp_stage_recipe_ready(w));w->player.profile.extra[7]=2;w->player.profile.mouth=2;w->player.profile.carnivore=1;
 assert(cp_stage_recipe_ready(w));cp_stage_meter_add(w,0,200);assert(w->recipes.calcium==100);cp_stage_meter_add(w,0,-200);assert(!w->recipes.calcium);
 cp_stage_meter_add(w,1,45);assert(w->recipes.mineral==45);
 assert(cp_stage_known_moves(w)&(1u<<CB_SPINE_VOLLEY));assert(!cp_stage_command(w,"loadout 4 spine_volley"));
 char buf[65536];assert(cp_stage_observe(w,buf,sizeof buf)>0);assert(strstr(buf,"\"calcium\""));assert(strstr(buf,"\"known\""));
 size_t n=cp_stage_snapshot_size();uint8_t *data=malloc(n);assert(cp_stage_snapshot(w,data,n)>0);uint64_t h=w->hash;assert(!cp_stage_restore(w,data,n,NULL));assert(h==w->hash);free(data);
 CpCombatSetup c={0};c.n=2;c.flat=1;for(int i=0;i<2;i++){cp_combat_profile_default(&c.c[i].prof);c.c[i].x=10+3*i;c.c[i].y=10;c.c[i].fx=i?-1:1;c.c[i].team=i;}
 c.c[0].prof.extra[7]=2;c.c[0].prof.carnivore=1;c.c[0].has_loadout=1;cp_combat_loadout_default(&c.c[0].loadout,&c.c[0].prof);c.c[0].loadout.known|=1u<<CB_SPINE_VOLLEY;c.c[0].loadout.sig_slot=3;assert(!cp_combat_loadout_set(&c.c[0].loadout,3,CB_SPINE_VOLLEY));
 CpCombatWorld fight;cp_combat_reset(&fight,&c);assert(cp_combat_attack(&fight,0,1,CB_SPINE_VOLLEY)==CB_ERR_NO_METER);fight.c[0].calcium=60;
 assert(!cp_combat_attack(&fight,0,1,CB_SPINE_VOLLEY));cp_combat_step(&fight);assert(fight.c[0].calcium==40);assert(fight.c[0].volleys==1);
 assert(fight.c[0].cd[CB_SPINE_VOLLEY]>0);
 printf("recipe hash %016llx; combat hash %016llx\n",(unsigned long long)cp_stage_hash(w),(unsigned long long)cp_combat_hash(&fight));
 free(w);puts("moves/recipes: PASS");return 0;
}
