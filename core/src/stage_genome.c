/* Bounded JSON reader for the nest contract. No host parser or profile is trusted. */
#include "cpore/world.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>
#include <ctype.h>
#define TOKENS 8192
typedef struct {int start,end,next,count;char kind;} Token;
typedef struct {const char *s;int pos,n,depth;Token t[TOKENS];} Json;
static void space(Json *j){while(j->s[j->pos]&&isspace((unsigned char)j->s[j->pos]))j->pos++;}
static int value(Json *j){
 space(j);if(j->depth++>32||j->n>=TOKENS)return -1;
 int id=j->n++;Token *t=&j->t[id];t->start=j->pos;t->count=0;t->kind=j->s[j->pos];
 char c=t->kind;
 if(c=='{'||c=='['){
  j->pos++;space(j);char close=c=='{'?'}':']';
  if(j->s[j->pos]!=close)for(;;){
   if(c=='{'&&j->s[j->pos]!='"')return -1;
   if(value(j)<0)return -1;
   t->count++;
   if(c=='{'){space(j);if(j->s[j->pos++]!=':')return -1;if(value(j)<0)return -1;}
   space(j);if(j->s[j->pos]==close)break;
   if(j->s[j->pos++]!=',')return -1;
   space(j);
  }
  j->pos++;
 }else if(c=='"'){
  j->pos++;while(j->s[j->pos]&&j->s[j->pos]!='"'){
   unsigned char ch=j->s[j->pos++];if(ch<32)return -1;
   if(ch=='\\'){char e=j->s[j->pos++];if(!e||!strchr("\"\\/bfnrtu",e))return -1;if(e=='u')for(int k=0;k<4;k++)if(!isxdigit((unsigned char)j->s[j->pos++]))return -1;}
  }if(j->s[j->pos++]!='"')return -1;
 }else if(c=='t'||c=='f'||c=='n'){
  const char *lit=c=='t'?"true":c=='f'?"false":"null";size_t n=strlen(lit);if(strncmp(j->s+j->pos,lit,n))return -1;j->pos+=(int)n;
 }else{
  int p=j->pos;if(j->s[p]=='-')p++;
  if(j->s[p]=='0')p++;else{if(j->s[p]<'1'||j->s[p]>'9')return -1;while(isdigit((unsigned char)j->s[p]))p++;}
  if(j->s[p]=='.'){p++;if(!isdigit((unsigned char)j->s[p]))return -1;while(isdigit((unsigned char)j->s[p]))p++;}
  if(j->s[p]=='e'||j->s[p]=='E'){p++;if(j->s[p]=='+'||j->s[p]=='-')p++;if(!isdigit((unsigned char)j->s[p]))return -1;while(isdigit((unsigned char)j->s[p]))p++;}
  j->pos=p;t->kind='N';
 }
 t->end=j->pos;t->next=j->n;j->depth--;return id;
}
static int eq(const Json *j,int id,const char *s){if(id<0)return 0;const Token *t=&j->t[id];return t->kind=='"'&&t->end-t->start==(int)strlen(s)+2&&!strncmp(j->s+t->start+1,s,strlen(s));}
static int field(const Json *j,int obj,const char *key){if(obj<0||j->t[obj].kind!='{')return -1;for(int i=obj+1;i<j->t[obj].next;){int v=i+1;if(eq(j,i,key))return v;i=j->t[v].next;}return -1;}
static int num(const Json *j,int id,double lo,double hi,double *out){if(id<0||j->t[id].kind!='N')return 0;double v=strtod(j->s+j->t[id].start,NULL);if(!isfinite(v)||v<lo||v>hi)return 0;if(out)*out=v;return 1;}
static int integer(const Json *j,int id,int lo,int hi){double v;return num(j,id,lo,hi,&v)&&v==(int)v;}
static int optional(const Json *j,int obj,const char *key,double lo,double hi){int id=field(j,obj,key);return id<0||num(j,id,lo,hi,NULL);}
static int text(const Json *j,int id,char *out,size_t cap){
 if(id<0||j->t[id].kind!='"')return 0;
 int n=j->t[id].end-j->t[id].start-2;if(n<0||(size_t)n>=cap)return 0;
 /* Names and part ids are plain text; escaped content remains valid in untouched body JSON. */
 memcpy(out,j->s+j->t[id].start+1,n);out[n]=0;return 1;
}
static int keys(const Json *j,int obj,const char *allowed){
 if(obj<0||j->t[obj].kind!='{')return 0;
 for(int i=obj+1;i<j->t[obj].next;){char key[80],needle[84];if(!text(j,i,key,sizeof key))return 0;snprintf(needle,sizeof needle,"|%s|",key);if(!strstr(allowed,needle))return 0;
  for(int k=obj+1;k<i;k=j->t[k+1].next)if(eq(j,k,key))return 0;
  i=j->t[i+1].next;
 }return 1;
}
static int oneof(const Json *j,int id,const char *values){char s[80],needle[84];if(!text(j,id,s,sizeof s))return 0;snprintf(needle,sizeof needle,"|%s|",s);return strstr(values,needle)!=NULL;}
static int hex(const Json *j,int id){char s[8];if(!text(j,id,s,sizeof s)||strlen(s)!=7||s[0]!='#')return 0;for(int k=1;k<7;k++)if(!isxdigit((unsigned char)s[k]))return 0;return 1;}
/* Radial body plan (A24): optional `plan` object. Same rules as creature_genome.gd, studio/genome.gd and web/studio/genome.js. */
static int plan_ok(const Json *j,int plan,int nodes,int parts,int regions){
 if(plan<0)return 1;
 if(!keys(j,plan,"|sym||fold||star||gel||arm|"))return 0;
 if(!oneof(j,field(j,plan,"sym"),"|bilateral||radial|"))return 0;
 int radial=eq(j,field(j,plan,"sym"),"radial"),fold=field(j,plan,"fold");
 if((radial||fold>=0)&&!integer(j,fold,3,8))return 0;
 if(!optional(j,plan,"star",0,1)||!optional(j,plan,"gel",0,1))return 0;
 int arm=field(j,plan,"arm");
 if(arm>=0){
  if(!keys(j,arm,"|len||w||taper||curl||droop||frill||tip||eye||act|"))return 0;
  if(!optional(j,arm,"len",0,6)||!optional(j,arm,"w",.1,1)||!optional(j,arm,"taper",0,1)||!optional(j,arm,"curl",-1,1)||!optional(j,arm,"droop",0,1)||!optional(j,arm,"frill",0,1))return 0;
  int a=field(j,arm,"tip");if(a>=0&&!oneof(j,a,"|point||frill||bulb|"))return 0;
  a=field(j,arm,"eye");if(a>=0&&!integer(j,a,0,1))return 0;
  a=field(j,arm,"act");if(a>=0&&!oneof(j,a,"|peristaltic||hydrostat||tubefeet||cilia|"))return 0;
 }
 if(!radial)return 1;
 double py=0;int first=1;
 for(int i=nodes+1;i<j->t[nodes].next;i=j->t[i].next){double y=0,z=1;num(j,field(j,i,"y"),-5,20,&y);num(j,field(j,i,"z"),-30,30,&z);
  if(z!=0||(!first&&y<=py))return 0;
  first=0;py=y;
 }
 for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){
  const char *legs[]={"pata","zanca","pezuna","leg_sprinter","leg_sucker","foot_spring","foot_hoof","foot_gecko"};
  for(int k=0;k<8;k++)if(eq(j,field(j,i,"type"),legs[k]))return 0;
  double sg=0;if(num(j,field(j,i,"single"),-1,1,&sg)&&sg<0)return 0;
 }
 for(int i=regions+1;i<j->t[regions].next;i=j->t[i].next)if(!eq(j,field(j,i,"surface"),"torso"))return 0;
 return 1;
}
int cp_stage_genome_form(const char *json,CpLineageForm *out){
 if(!json||!out||strlen(json)>=CP_LINEAGE_BODY_CAP)return -1;
 Json *j=calloc(1,sizeof *j);if(!j)return -1;j->s=json;int ok=0;CpLineageForm f={0};
 if(value(j)!=0)goto done;
 space(j);if(j->s[j->pos])goto done;
 if(!keys(j,0,"|schema||name||nodes||parts||skin||regions||migration||plan|"))goto done;
 int version=eq(j,field(j,0,"schema"),"cpore.creature/5")?5:eq(j,field(j,0,"schema"),"cpore.creature/4")?4:0;if(!version)goto done;
 if(!text(j,field(j,0,"name"),f.name,sizeof f.name)||strchr(f.name,'<')||strchr(f.name,'>'))goto done;
 int nodes=field(j,0,"nodes");if(nodes<0||j->t[nodes].kind!='['||j->t[nodes].count<4||j->t[nodes].count>32)goto done;
 double minz=1e9,maxz=-1e9,maxr=0,py=0,pz=0;int first=1;
 for(int i=nodes+1;i<j->t[nodes].next;i=j->t[i].next){double y,z,r;
  if(!keys(j,i,"|y||z||r|")||!num(j,field(j,i,"y"),-5,20,&y)||!num(j,field(j,i,"z"),-30,30,&z)||!num(j,field(j,i,"r"),.03,3,&r))goto done;
  if(!first&&(y-py)*(y-py)+(z-pz)*(z-pz)<.0025)goto done;
  first=0;py=y;pz=z;if(z<minz)minz=z;if(z>maxz)maxz=z;if(r>maxr)maxr=r;
 }
 int parts=field(j,0,"parts");if(parts<0||j->t[parts].kind!='['||j->t[parts].count>256)goto done;
 f.profile=(CpCombatProfile){.hp=100,.stamina=100,.speed=4};
 for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){char name[80];
  if(!keys(j,i,"|type||t||ang||size||len||curve||w||k||f||rot||tilt||act||single||pupil||level||tier|")||!text(j,field(j,i,"type"),name,sizeof name))goto done;
  int id=cp_stage_part_id(name);if(id<0)goto done;
  if(!num(j,field(j,i,"t"),0,1,NULL)||!num(j,field(j,i,"ang"),-3.141592654,3.141592654,NULL))goto done;
  const char *ks[]={"size","len","curve","w","rot","tilt"};double lo[]={.1,.1,-1.5,.05,-3.141592654,-1.5},hi[]={4,5,1.5,.8,3.141592654,1.5};for(int k=0;k<6;k++)if(!optional(j,i,ks[k],lo[k],hi[k]))goto done;
  int leg=!strcmp(name,"pata")||!strcmp(name,"zanca")||!strcmp(name,"pezuna");
  if(leg){if(!num(j,field(j,i,"w"),.05,.8,NULL))goto done;const char *v[]={"k","f"};for(int k=0;k<2;k++){int a=field(j,i,v[k]);if(a<0||j->t[a].kind!='['||j->t[a].count!=3)goto done;for(int b=a+1;b<j->t[a].next;b=j->t[b].next)if(!num(j,b,-20,20,NULL))goto done;}}
  else if(!num(j,field(j,i,"size"),.1,4,NULL))goto done;
  if((!strcmp(name,"cuerno")||!strcmp(name,"asta")||!strcmp(name,"pua")||!strcmp(name,"tallo")||!strcmp(name,"antena"))&&!num(j,field(j,i,"len"),.1,5,NULL))goto done;
  if(!strcmp(name,"cuerno")&&!num(j,field(j,i,"curve"),-1.5,1.5,NULL))goto done;
  int a=field(j,i,"act");if(a>=0&&!oneof(j,a,"|muscle||tendon||spring||hydrostat||hydraulic||peristaltic||tubefeet||cilia|"))goto done;
  a=field(j,i,"pupil");if(a>=0&&!oneof(j,a,"|auto||round||slit||bar|"))goto done;
  a=field(j,i,"single");if(a>=0&&!integer(j,a,-1,1))goto done;
  int level=field(j,i,"level"),tier=field(j,i,"tier");double lv=1;
  if(version==5&&(!integer(j,level,1,5)||!integer(j,tier,0,2)))goto done;
  if(version==4&&(level>=0||tier>=0))goto done;
  if(level>=0)num(j,level,1,5,&lv);
  f.parts[id]++;const CpStagePartDef *d=&CP_STAGE_PARTS[id];
#define STAT(k) f.profile.k=(uint8_t)((int)f.profile.k+d->k*(int)lv>5?5:(int)f.profile.k+d->k*(int)lv)
  STAT(mouth);STAT(charge);STAT(spit);STAT(tail);STAT(guard);
#undef STAT
 }
 int skin=field(j,0,"skin");if(!keys(j,skin,"|pat||cA||cB||cC||wet||scale||cs||ps||pc||ros||act||sk|"))goto done;
 if(!integer(j,field(j,skin,"pat"),0,3)||!num(j,field(j,skin,"wet"),0,1,NULL)||!num(j,field(j,skin,"scale"),3,14,NULL))goto done;
 if(!hex(j,field(j,skin,"cA"))||!hex(j,field(j,skin,"cB"))||!hex(j,field(j,skin,"cC")))goto done;
 if(!optional(j,skin,"cs",0,1)||!optional(j,skin,"ps",.5,2)||!optional(j,skin,"pc",0,1))goto done;
 int a=field(j,skin,"sk");if(a>=0&&!oneof(j,a,"|auto||endo||exo||hydro|"))goto done;
 a=field(j,skin,"act");if(a>=0&&!oneof(j,a,"|auto||muscle||hydraulic||exo|"))goto done;
 a=field(j,skin,"ros");if(a>=0&&!integer(j,a,0,1))goto done;
 int regions=field(j,0,"regions");if(regions<0||j->t[regions].kind!='['||j->t[regions].count>64)goto done;
 for(int i=regions+1;i<j->t[regions].next;i=j->t[i].next){
  if(!keys(j,i,"|id||schema||family||seed||count||length||curve||branches||surface||position||coverage||angle||mirror|"))goto done;
  if(!eq(j,field(j,i,"schema"),"cpore.growth/1")||!oneof(j,field(j,i,"family"),"|horns||plates||tendrils|")||!oneof(j,field(j,i,"surface"),"|torso||neck||tail|"))goto done;
  char rid[65];if(!text(j,field(j,i,"id"),rid,sizeof rid)||!rid[0])goto done;for(int k=0;rid[k];k++)if(!isalnum((unsigned char)rid[k])&&rid[k]!='_'&&rid[k]!='-')goto done;
  for(int b=regions+1;b<i;b=j->t[b].next)if(eq(j,field(j,b,"id"),rid))goto done;
  const char *rk[]={"seed","count","length","curve","branches","position","coverage","angle"};double rl[]={0,1,.2,-1,0,0,0,-3.141592654},rh[]={4294967295.,18,2.4,1,3,1,1,3.141592654};for(int k=0;k<8;k++)if(!num(j,field(j,i,rk[k]),rl[k],rh[k],NULL))goto done;
  if(!integer(j,field(j,i,"count"),1,18)||!integer(j,field(j,i,"branches"),0,3))goto done;
  int m=field(j,i,"mirror");if(m<0||(j->t[m].kind!='t'&&j->t[m].kind!='f'))goto done;
 }
 if(!plan_ok(j,field(j,0,"plan"),nodes,parts,regions))goto done;
 int migration=field(j,0,"migration");
 if(migration>=0){
  if(!keys(j,migration,"|from||warnings||source|")||!integer(j,field(j,migration,"from"),1,4))goto done;
  int warn=field(j,migration,"warnings"),src=field(j,migration,"source");if(warn<0||j->t[warn].kind!='['||src<0||j->t[src].kind!='{')goto done;
  for(int k=warn+1;k<j->t[warn].next;k=j->t[k].next)if(j->t[k].kind!='"')goto done;
 }
 f.profile.hp+=5*f.profile.guard;
 double diameter=maxz-minz>2*maxr?maxz-minz:2*maxr;int cm=(int)(diameter*50+.5);if(cm<40)cm=40;if(cm>400)cm=400;f.profile.radius_cm=cm==60?0:cm;
 if(version==4){
  size_t n=0;int schema=field(j,0,"schema");
  for(int at=0;json[at];at++){
   if(n+24>=sizeof f.body)goto done;
   char c=json[at];if(at==j->t[schema].end-2)c='5';f.body[n++]=c;
   for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next)if(at==j->t[i].start){
    const char *extra="\"level\":1,\"tier\":0,";size_t len=strlen(extra);memcpy(f.body+n,extra,len);n+=len;
   }
  }f.body[n]=0;
 }else memcpy(f.body,json,strlen(json)+1);
 *out=f;ok=1;
 done:free(j);return ok?0:-1;
}
/* Evolve: the only nest action that spends DNA and starts a generation. Everything the genome adds
 * (new parts, higher levels, tiers when enabled) is priced here and charged atomically with the evolve. */
int cp_stage_edit(CpStageWorld *w,const char *genome){
 if(!cp_stage_at_nest(w))return CP_STAGE_ERR_NOT_AT_NEST;
 CpLineageForm f;if(cp_stage_genome_form(genome,&f))return -1;
 if(!w->ancestry.count)return -1;
 Json *j=calloc(1,sizeof *j);if(!j)return -1;j->s=genome;if(value(j)<0){free(j);return -1;}
 CpStageParts *pp=&w->parts;int reqL[CP_STAGE_PART_COUNT]={0},reqT[CP_STAGE_PART_COUNT]={0};
 int parts=field(j,0,"parts"),rc=0;
 for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){
  char id[80];text(j,field(j,i,"type"),id,sizeof id);int p=cp_stage_part_id(id);double level=1,tier=0;
  int a=field(j,i,"level");if(a>=0)num(j,a,1,5,&level);a=field(j,i,"tier");if(a>=0)num(j,a,0,2,&tier);
  if(p<0||!(pp->discovered&(1ULL<<p))){rc=CP_STAGE_ERR_NOT_KNOWN;break;}
  if(reqL[p]&&(reqL[p]!=(int)level||reqT[p]!=(int)tier)){rc=-1;break;}
  reqL[p]=(int)level;reqT[p]=(int)tier;
 }
 free(j);if(rc)return rc;
 int cost=0;
 for(int p=0;p<CP_STAGE_PART_COUNT;p++)if(reqL[p]){
  const CpStagePartDef *d=&CP_STAGE_PARTS[p];int owned=(pp->owned>>p)&1,cur=owned?pp->level[p]:1,ct=owned?pp->tier[p]:0;
  if(!owned)cost+=d->cost;
  if(reqL[p]<cur||reqT[p]<ct)return -1;
  for(int l=cur;l<reqL[p];l++)cost+=d->cost*(1<<l);
  if(reqT[p]>ct){
   if(!pp->tiers_on||!(d->mouth||d->charge||d->spit||d->tail||d->guard))return -1;
   for(int t=ct;t<reqT[p];t++){if(pp->hits[p]<(t?75u:25u)||pp->wins[p]<(t?10u:3u))return -1;cost+=t?150:60;}
  }
 }
 if(cost>w->social.dna_balance)return CP_STAGE_ERR_NO_DNA;
 CpStageParts saved=*pp;int balance=w->social.dna_balance;
 for(int p=0;p<CP_STAGE_PART_COUNT;p++)if(reqL[p]){pp->owned|=1ULL<<p;pp->level[p]=(uint8_t)reqL[p];pp->tier[p]=(uint8_t)reqT[p];}
 w->social.dna_balance-=cost;
 int rc2=cp_stage_evolve(w,&f);
 if(rc2){*pp=saved;w->social.dna_balance=balance;w->hash=cp_stage_hash(w);return rc2;}
 w->social.used=1;pp->used=1;pp->adult_hp=f.profile.hp;
 if(pp->hatchling){w->player.profile.hp=f.profile.hp*3.f/5.f;w->player.hp=w->player.profile.hp;}
 w->events[w->ev_total%CP_STAGE_MAX_EVENTS]=(CpStageEvent){w->tick,CP_STAGE_EV_EDIT_ACCEPTED,0,0,0,(float)cost,w->player.x,w->player.z};w->ev_total++;w->hash=cp_stage_hash(w);return 0;
}

/* Repaint, rearrange and other cosmetic edits: free, any number of times, never a new generation.
 * Rejected when the combat-relevant form (parts, levels, tiers, derived profile) would change. */
int cp_stage_apply(CpStageWorld *w,const char *genome){
 if(!cp_stage_at_nest(w))return CP_STAGE_ERR_NOT_AT_NEST;
 if(!w->ancestry.count)return -1;
 CpLineageForm f;if(cp_stage_genome_form(genome,&f))return -1;
 CpLineageForm *cur=&w->ancestry.forms[w->ancestry.count-1].form;
 const CpCombatProfile *a=&cur->profile,*b=&f.profile;
 uint8_t ta[CB_PART_COUNT],tb[CB_PART_COUNT];cp_stage_genome_tiers(cur->body,ta);cp_stage_genome_tiers(f.body,tb);
 if(memcmp(cur->parts,f.parts,sizeof cur->parts)||memcmp(ta,tb,sizeof ta)||a->mouth!=b->mouth||a->charge!=b->charge||a->spit!=b->spit||a->tail!=b->tail||a->guard!=b->guard||a->hp!=b->hp||a->stamina!=b->stamina||a->speed!=b->speed)return CP_STAGE_ERR_NEEDS_EVOLVE;
 memcpy(cur->body,f.body,strlen(f.body)+1);memcpy(cur->name,f.name,strlen(f.name)+1);
 cur->profile.radius_cm=b->radius_cm;w->player.profile.radius_cm=b->radius_cm;w->setup.player.radius_cm=b->radius_cm;
 w->hash=cp_stage_hash(w);return 0;
}

int cp_stage_start_genome(CpStageWorld *w,const char *genome){
 if(!cp_stage_at_nest(w)||w->ancestry.count)return -1;
 CpLineageForm f;if(cp_stage_genome_form(genome,&f))return -1;
 for(int i=0;i<CP_STAGE_PART_COUNT;i++)if(f.parts[i]&&!(w->parts.owned&(1ULL<<i)))return CP_STAGE_ERR_NOT_KNOWN;
 Json *j=calloc(1,sizeof *j);if(!j)return -1;j->s=genome;if(value(j)<0){free(j);return -1;}
 int parts=field(j,0,"parts");
 for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){
  int level=field(j,i,"level"),tier=field(j,i,"tier");
  if((level>=0&&!integer(j,level,1,1))||(tier>=0&&!integer(j,tier,0,0))){free(j);return -1;}
 }free(j);
 return cp_stage_lineage_form(w,&f,0);
}

/* Combat inherits the confirmed form, including a cousin's older tier choices. */
void cp_stage_genome_tiers(const char *body,uint8_t tiers[CB_PART_COUNT]){
 memset(tiers,0,CB_PART_COUNT);
 if(!body||strlen(body)>=CP_LINEAGE_BODY_CAP)return;
 Json *j=calloc(1,sizeof *j);if(!j)return;j->s=body;
 if(value(j)<0){free(j);return;}int parts=field(j,0,"parts");
 if(parts<0||j->t[parts].kind!='['){free(j);return;}
 for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){
  char id[80];if(!text(j,field(j,i,"type"),id,sizeof id))continue;
  int p=cp_stage_part_id(id);double t=0;if(p<0||!num(j,field(j,i,"tier"),0,2,&t))continue;
  const CpStagePartDef *d=&CP_STAGE_PARTS[p];int has[]={0,d->mouth==2,d->charge,d->spit,d->tail,d->guard};
  for(int k=1;k<CB_PART_COUNT;k++)if(has[k]&&tiers[k]<(int)t)tiers[k]=(uint8_t)t;
 }free(j);
}

/* The rig uses the two bone lengths k and f-k. Legacy setups have no genome;
 * their morphology proxy is a leg length of two collision radii. */
float cp_stage_safe_drop(const CpStageWorld *w){
 float fallback=3*cp_combat_body_radius(&w->player.profile);
 if(!w->ancestry.count)return fallback;
 Json *j=calloc(1,sizeof *j);if(!j)return fallback;
 j->s=w->ancestry.forms[w->ancestry.count-1].form.body;
 if(value(j)!=0){free(j);return fallback;}
 int parts=field(j,0,"parts"),n=0;float sum=0;
 if(parts>=0)for(int i=parts+1;i<j->t[parts].next;i=j->t[i].next){
  if(!oneof(j,field(j,i,"type"),"|pata||zanca||pezuna||leg_sprinter||leg_sucker||foot_spring||foot_hoof||foot_gecko|"))continue;
  double k[3]={0,-.7,0},f[3]={0,-1.5,0};
  int kt=field(j,i,"k"),ft=field(j,i,"f");
  if(kt>=0&&j->t[kt].count==3)for(int a=0,t=kt+1;a<3;a++,t=j->t[t].next)num(j,t,-20,20,&k[a]);
  if(ft>=0&&j->t[ft].count==3)for(int a=0,t=ft+1;a<3;a++,t=j->t[t].next)num(j,t,-20,20,&f[a]);
  float a=0,b=0;for(int d=0;d<3;d++){a+=(float)(k[d]*k[d]);b+=(float)((f[d]-k[d])*(f[d]-k[d]));}
  sum+=sqrtf(a)+sqrtf(b);n++;
 }
 free(j);return n?1.5f*sum/n:fallback;
}
