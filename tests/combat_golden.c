/* Fixed action-log replay in a separate production-linked process.
 * --record is an explicit maintenance command, never invoked by make test. */
#include "combat_bots.h"
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { TICKS = 10000, CAP = CB_MAX_CREATURES*TICKS };
static CpCombatLogEntry log_entries[CAP];
static uint64_t hashes[TICKS];

static void setup(CpCombatSetup *s, uint32_t seed)
{
    memset(s, 0, sizeof(*s)); s->seed = seed; s->n = CB_MAX_CREATURES;
    for (int i = 0; i < s->n; i++) {
        cp_combat_profile_default(&s->c[i].prof);
        s->c[i].prof.hp = 100000;
        s->c[i].x = s->c[i].y = -1;
        s->c[i].team = (uint8_t)(i%2);
        s->c[i].medium = (uint8_t)(i%3 == 0);
    }
}

int main(int argc, char **argv)
{
    int record = argc == 5 && strcmp(argv[1], "--record") == 0;
    if (!record && argc != 2) {
        fprintf(stderr, "usage: combat_golden LOG | --record SEED LOG HASHES\n"); return 2;
    }
    uint32_t seed;
    CpCombatSetup s;
    int n = 0;
    if (record) {
        seed = (uint32_t)strtoul(argv[2], NULL, 10);
        setup(&s, seed);
        CpBot bots[CB_MAX_CREATURES];
        for (int i = 0; i < s.n; i++) bot_init(&bots[i], i%3+BOT_RANDOM, seed+(uint32_t)i);
        CpCombatWorld end;
        bots_run(&s, bots, TICKS, 0, log_entries, CAP, &n, hashes, &end);
        if (n == CAP) return 2;
        FILE *f = fopen(argv[3], "w"); if (!f) { perror(argv[3]); return 2; }
        fprintf(f, "%" PRIu32 "\n", seed);
        /* Strip orders that leave the state unchanged, keeping fixed logs
         * reviewable. Verify that filtering preserves every original hash. */
        CpCombatWorld replay; cp_combat_reset(&replay, &s);
        int j = 0;
        for (int t = 0; t < TICKS; t++) {
            while (j < n && log_entries[j].tick == t) {
                const CpCombatLogEntry *e = &log_entries[j++];
                uint64_t before = cp_combat_hash(&replay);
                cp_combat_order(&replay, e->id, &e->act);
                if (cp_combat_hash(&replay) != before)
                    fprintf(f, "%d %u %u %d %d %d\n", e->tick, e->id, e->act.verb, e->act.move, e->act.target, e->act.dir);
            }
            if (cp_combat_step(&replay) != hashes[t]) return 2;
        }
        if (fclose(f)) return 2;
    } else {
        FILE *f = fopen(argv[1], "r"); if (!f) { perror(argv[1]); return 2; }
        if (fscanf(f, "%" SCNu32, &seed) != 1) return 2;
        int tick, id, verb, move, target, dir, fields;
        while ((fields = fscanf(f, "%d %d %d %d %d %d", &tick, &id, &verb, &move, &target, &dir)) == 6) {
            if (n == CAP || tick < 0 || tick >= TICKS || (n && tick < log_entries[n-1].tick) ||
                id < 0 || id >= CB_MAX_CREATURES || verb < 0 || verb >= CB_V_COUNT ||
                move < -1 || move >= CB_MOVE_COUNT || target < -1 || target >= CB_MAX_CREATURES || dir < 0 || dir > 7) return 2;
            log_entries[n++] = (CpCombatLogEntry){tick, (uint8_t)id, {(uint8_t)verb, (int8_t)move, (int8_t)target, (int8_t)dir, 0, 0}};
        }
        if (fields != EOF || ferror(f) || !n) return 2;
        fclose(f);
        setup(&s, seed);
        cp_combat_replay(&s, log_entries, n, TICKS, hashes);
    }
    FILE *out = record ? fopen(argv[4], "w") : stdout;
    if (!out) return 2;
    for (int t = 0; t < TICKS; t++) fprintf(out, "%016" PRIx64 "\n", hashes[t]);
    return fclose(out) ? 2 : 0;
}
