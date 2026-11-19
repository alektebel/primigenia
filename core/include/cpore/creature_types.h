#ifndef CPORE_CREATURE_TYPES_H
#define CPORE_CREATURE_TYPES_H
#include "cpore/ledger.h"
enum { CP_TYPE_TRUST, CP_TYPE_MEAT, CP_TYPE_NEST, CP_TYPE_OBSERVE, CP_TYPE_PERKS };
/* Axis order: Approach, Diet, Way of life, Temper. Positive bits S,G,I,W.
* Scores within [-10,+10] leave the axis undetermined ("?"). A type value holds the letters in bits 0-3 and the
 * determined axes in bits 4-7; a fresh creature is 0. Name, description and perk exist only when all four axes
 * are determined (perk -1 otherwise). */
int cp_type_score(const uint32_t deeds[CP_DEED_COUNT],int previous,int scores[4]);
void cp_type_code(int type,char out[8]);
const char *cp_type_name(int type);
const char *cp_type_description(int type);
int cp_type_perk(int type);
int cp_type_adjust(int type,int kind,int amount);
#endif
