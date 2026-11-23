/* S1 of the radial-bodies plan: the optional `plan` key of cpore.creature/5 in cp_stage_genome_form.
 * Reads godot/creature/tests/parity/plan_cases.json (one case per line: {"name":..,"error":..,"genome":{..}}),
 * the same table the Godot creature, Godot studio and web validators run. C only reports accept/reject. */
#include "cpore/world.h"
#include "cpore/steer.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static char *without_plan(const char *g){
 /* the same genome with the "plan":{...} member removed (the object holds one nested level at most) */
 char *out=malloc(strlen(g)+1);const char *p=strstr(g,",\"plan\":");assert(p);
 const char *q=p+8;int depth=0;do{if(*q=='{')depth++;else if(*q=='}')depth--;q++;}while(depth>0);
 memcpy(out,g,p-g);strcpy(out+(p-g),q);return out;
}
int main(int argc,char **argv){
 const char *path=argc>1?argv[1]:"godot/creature/tests/parity/plan_cases.json";
 FILE *f=fopen(path,"r");assert(f);
 static char line[CP_LINEAGE_BODY_CAP+256];int n=0,bad=0;static CpLineageForm form,plain;
 while(fgets(line,sizeof line,f)){
  char *name=strstr(line,"{\"name\":\"");if(!name)continue;
  char *gp=strstr(line,"\"genome\":");assert(gp);gp+=9;
  char *end=line+strlen(line)-1;while(end>gp&&*end!='}')end--;           /* last '}' closes the case object */
  char genome[CP_LINEAGE_BODY_CAP];size_t len=(size_t)(end-gp);assert(len<sizeof genome);memcpy(genome,gp,len);genome[len]=0;
  int expect_ok=strstr(line,"\"error\":null")!=NULL;
  int rc=cp_stage_genome_form(genome,&form);
  if((rc==0)!=expect_ok){bad++;fprintf(stderr,"FAIL case %.60s: expected %s\n",name,expect_ok?"accept":"reject");}
  /* Radial replicas remain free and preserve combat stats. A59 adhesive limbs may change grip. */
  if(rc==0&&strstr(genome,"\"sym\":\"radial\"")){
   char *w=without_plan(genome);assert(!cp_stage_genome_form(w,&plain));free(w);
   assert(form.profile.grip_traits==plain.profile.grip_traits || (form.profile.grip_traits^plain.profile.grip_traits)==CP_GRIP_CLING);
   CpCombatProfile combat=form.profile;combat.grip_traits=plain.profile.grip_traits;
   assert(!memcmp(&combat,&plain.profile,sizeof combat));
   assert(!memcmp(form.parts,plain.parts,sizeof form.parts));
   assert(strstr(form.body,"\"plan\""));            /* the body keeps the plan verbatim */
  }
  n++;
 }
 fclose(f);assert(n>=30);
 printf("plan genome cases: %d checked, %d wrong\n",n,bad);
 return bad?1:0;
}
