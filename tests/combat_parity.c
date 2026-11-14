/* Same executable compiled native and WASM: print every bot-duel hash, or
 * replay the setup + orders exported by the rendering-free JS encounter. */
#include "combat_bots.h"
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

enum { MAX_TICKS = 10000, LOG_CAP = MAX_TICKS * CB_MAX_CREATURES };
static uint64_t hashes[MAX_TICKS];
static CpCombatLogEntry entries[LOG_CAP];

static int duels(void)
{
    int count = 0, ticks = 0;
    const uint32_t seeds[] = {0, 1, 42, UINT32_MAX};
    for (int set = 0; set < 2; set++)
        for (int a = 0; a < BOT_KIND_COUNT; a++)
            for (int b = 0; b < BOT_KIND_COUNT; b++)
                for (int k = 0; k < 4; k++) {
                    CpCombatSetup s;
                    CpCombatProfile p, q;
                    if (set == 0) { cp_combat_profile_default(&p); q = p; }
                    else { p = PROFILES[1]; q = PROFILES[2]; }
                    duel_setup(&s, seeds[k], &p, &q, 7.0f);
                    CpBot bots[2];
                    bot_init(&bots[0], a, seeds[k]); bot_init(&bots[1], b, seeds[k]+1u);
                    /* Exercise different spam moves as well as all bot kinds. */
                    bots[0].spam_move = set ? CB_SPIT : CB_BITE;
                    bots[1].spam_move = set ? CB_GUARD : CB_CHARGE;
                    CpDuelResult result;
                    duel_run(&s, &bots[0], &bots[1], 600, NULL, 0, NULL, hashes, &result);
                    printf("duel %d %d %d %" PRIu32 " %d\n", set, a, b, seeds[k], result.ticks);
                    for (int t = 0; t < result.ticks; t++) printf("%016" PRIx64 "\n", hashes[t]);
                    count++; ticks += result.ticks;
                }
    printf("counts %d %d\n", count, ticks);
    return 0;
}
static int replay(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); return 2; }
    CpCombatSetup s = {0};
    int version, flat, ticks;
    if (fscanf(f, "CPORE_COMBAT_LOG %d", &version) != 1 || version != 1 ||
        fscanf(f, "%" SCNu32 " %d %d %d", &s.seed, &s.n, &flat, &ticks) != 4 ||
        s.n < 1 || s.n > CB_MAX_CREATURES || flat < 0 || flat > 1 || ticks < 0 || ticks > MAX_TICKS) goto bad;
    s.flat = (uint8_t)flat;
    for (int i = 0; i < s.n; i++) {
        CpCombatSpawn *c = &s.c[i];
        int mouth, charge, spit, tail, guard, medium, team;
        if (fscanf(f, "%d %d %d %d %d %f %f %f %f %f %f %f %d %d",
            &mouth, &charge, &spit, &tail, &guard, &c->prof.hp, &c->prof.stamina,
            &c->prof.speed, &c->x, &c->y, &c->fx, &c->fy, &medium, &team) != 14 ||
            mouth < 0 || mouth > 5 || charge < 0 || charge > 5 || spit < 0 || spit > 5 ||
            tail < 0 || tail > 5 || guard < 0 || guard > 5 || medium < 0 || medium > 1 || team < 0 || team > 255) goto bad;
        c->prof.mouth = (uint8_t)mouth; c->prof.charge = (uint8_t)charge; c->prof.spit = (uint8_t)spit;
        c->prof.tail = (uint8_t)tail; c->prof.guard = (uint8_t)guard;
        c->medium = (uint8_t)medium; c->team = (uint8_t)team;
    }
    int n = 0, fields, tick, id, verb, move, target, dir;
    while ((fields = fscanf(f, "%d %d %d %d %d %d", &tick, &id, &verb, &move, &target, &dir)) == 6) {
        if (n == LOG_CAP || tick < 0 || tick >= ticks || (n && tick < entries[n-1].tick) ||
            id < 0 || id >= s.n || verb < 0 || verb >= CB_V_COUNT || move < -1 || move >= CB_MOVE_COUNT ||
            target < -1 || target >= s.n || dir < 0 || dir > 7) goto bad;
        entries[n++] = (CpCombatLogEntry){tick, (uint8_t)id, {(uint8_t)verb, (int8_t)move, (int8_t)target, (int8_t)dir}};
    }
    if (fields != EOF || ferror(f)) goto bad;
    fclose(f);
    cp_combat_replay(&s, entries, n, ticks, hashes);
    for (int t = 0; t < ticks; t++) printf("%016" PRIx64 "\n", hashes[t]);
    return 0;
bad:
    fprintf(stderr, "invalid encounter log: %s\n", path); fclose(f); return 2;
}
int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], "--duels")) return duels();
    if (argc == 3 && !strcmp(argv[1], "--replay")) return replay(argv[2]);
    fprintf(stderr, "usage: combat_parity --duels | --replay LOG\n"); return 2;
}
