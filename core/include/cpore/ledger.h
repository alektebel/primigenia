#ifndef CPORE_LEDGER_H
#define CPORE_LEDGER_H
#include <stdint.h>
#include <stddef.h>
#define CP_LEDGER_CAP 1536
#define CP_LEDGER_DEED_CAP 384
#define CP_LINEAGE_GENERATIONS 16
#define CP_LINEAGE_BODY_CAP 16384
#define CP_LINEAGE_PARTS 64
/* Coordinates are centimetres, counters are unsigned saturating integers. */
enum { CP_LEDGER_TRAIT, CP_LEDGER_PART_GAINED, CP_LEDGER_PART_LOST, CP_LEDGER_EVOLVED, CP_LEDGER_DEED, CP_LEDGER_TYPE };
enum { CP_TRAIT_HUNTER, CP_TRAIT_SOCIAL, CP_TRAIT_NOCTURNAL, CP_TRAIT_BURROWER, CP_TRAIT_AQUATIC, CP_TRAIT_FLYER, CP_TRAIT_VOID, CP_TRAIT_COUNT };
enum { CP_DEED_KILLS, CP_DEED_BEFRIENDS, CP_DEED_INTIMIDATIONS, CP_DEED_MEAT, CP_DEED_PLANTS,
 CP_DEED_OBSERVATIONS, CP_DEED_DISTANCE, CP_DEED_NEST, CP_DEED_DIGGING, CP_DEED_BUILDING,
 CP_DEED_FIGHTS, CP_DEED_FLED, CP_DEED_NIGHT, CP_DEED_GIFTS, CP_DEED_HUNTS, CP_DEED_FORAGING,
 CP_DEED_PLACES, CP_DEED_HOARDING, CP_DEED_BIG_APPROACH, CP_DEED_DEEP_DIVES, CP_DEED_STEALTH,
 CP_DEED_SWIMMING, CP_DEED_FLIGHT, CP_DEED_VOID, CP_DEED_COUNT };
typedef struct { uint32_t tick,kind,id,value; int32_t x,z; uint32_t cause; } CpLedgerEntry;
typedef struct {
 uint32_t enabled,count,dropped,traits,generation;
 uint32_t deeds[CP_DEED_COUNT],current[CP_DEED_COUNT];
 CpLedgerEntry entries[CP_LEDGER_CAP];
} CpLedger;
void cp_ledger_init(CpLedger *l);
int cp_ledger_append(CpLedger *l,uint32_t tick,uint32_t kind,uint32_t id,uint32_t value,int32_t x,int32_t z,uint32_t cause);
/* Social integration interface: call once at the successful award point, never on attempts.
 * Future-media deeds reject until those mechanics exist. */
int cp_ledger_deed(CpLedger *l,uint32_t tick,int deed,uint32_t amount,int32_t x,int32_t z,uint32_t cause);
uint64_t cp_ledger_hash(const CpLedger *l);
int cp_ledger_export(const CpLedger *l,char *out,size_t cap);
const char *cp_ledger_deed_name(int id);
const char *cp_ledger_trait_name(int id);
#endif
