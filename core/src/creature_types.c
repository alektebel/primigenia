#include "cpore/creature_types.h"
#include <limits.h>
static const char *names[16]={"Flint Stalker","Hearth Fang","Bramble Runner","Orchard Sentinel","Den Forger","Hearth Keeper","Root Mason","Grove Tender","Dusk Tracker","Quiet Companion","Seed Wanderer","Meadow Listener","Burrow Warden","Lantern Host","Moss Architect","Patient Gardener"};
static const char *descriptions[16]={
 "Ranges far and meets danger head on.","Shares the hunt and stands beside companions.","Forages boldly and defends each find.","Gathers a circle and guards its harvest.",
 "Builds a strong den with a hunter's resolve.","Welcomes companions into a well-stocked den.","Shapes the land and keeps intruders at bay.","Builds a home around shared abundance.",
 "Tracks prey across the land with patient caution.","Travels with companions and watches before acting.","Carries seeds between safe paths.","Finds company by listening at the meadow's edge.",
 "Guards the den through watchful hunting.","Keeps a warm home and a careful welcome.","Builds shelter quietly and guards the stores.","Tends a shared home with patient attention."};
static int axis(uint64_t neg,uint64_t pos){uint64_t sum=neg+pos;return sum?(int)(((int64_t)pos-(int64_t)neg)*100/(int64_t)sum):0;}
int cp_type_score(const uint32_t d[CP_DEED_COUNT],int previous,int s[4]){
 s[0]=axis((uint64_t)d[CP_DEED_KILLS]*3+d[CP_DEED_INTIMIDATIONS],(uint64_t)d[CP_DEED_BEFRIENDS]*3+d[CP_DEED_GIFTS]);
 s[1]=axis((uint64_t)d[CP_DEED_MEAT]+d[CP_DEED_HUNTS],(uint64_t)d[CP_DEED_PLANTS]+d[CP_DEED_FORAGING]);
 s[2]=axis(d[CP_DEED_DISTANCE]/1000+(uint64_t)d[CP_DEED_PLACES]*10,d[CP_DEED_NEST]/100+((uint64_t)d[CP_DEED_DIGGING]+d[CP_DEED_BUILDING]+d[CP_DEED_HOARDING])*10);
 s[3]=axis((uint64_t)d[CP_DEED_FIGHTS]*3+((uint64_t)d[CP_DEED_BIG_APPROACH]+d[CP_DEED_DEEP_DIVES])*2,(uint64_t)d[CP_DEED_OBSERVATIONS]*2+d[CP_DEED_STEALTH]+(uint64_t)d[CP_DEED_FLED]*3);
 int type=previous>=0&&previous<16?previous:15;
 for(int i=0;i<4;i++){if(s[i]>10)type|=1<<i;else if(s[i]<-10)type&=~(1<<i);}return type;
}
void cp_type_code(int t,char out[8]){out[0]=t&1?'S':'A';out[1]='-';out[2]=t&2?'G':'H';out[3]='-';out[4]=t&4?'I':'R';out[5]='-';out[6]=t&8?'W':'B';out[7]=0;}
const char *cp_type_name(int t){return t>=0&&t<16?names[t]:"Unknown";}
const char *cp_type_description(int t){return t>=0&&t<16?descriptions[t]:"";}
/* Exactly one perk per type; no combat stat or tournament rules change. */
int cp_type_perk(int t){return t&8?CP_TYPE_OBSERVE:t&4?CP_TYPE_NEST:t&1?CP_TYPE_TRUST:CP_TYPE_MEAT;}
int cp_type_adjust(int t,int kind,int amount){
 if(amount<0||kind<0||kind>=CP_TYPE_PERKS)return -1;
 if(kind!=cp_type_perk(t))return amount;
 int64_t v=amount;
 if(kind==CP_TYPE_TRUST)v+=10;
 if(kind==CP_TYPE_MEAT)v=v*110/100;
 if(kind==CP_TYPE_NEST)v=(v*85+99)/100;
 if(kind==CP_TYPE_OBSERVE)v=(v*80+99)/100;
 return v>INT_MAX?INT_MAX:(int)v;
}
