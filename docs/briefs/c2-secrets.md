# Brief: C2 world secrets and roster: 5 meteor shards, the hidden cave interior, nocturnal Acechalunas, a 6th species, day/night shift

Worktree `/home/diego/Desarrollo/cpore-wt/c2-secrets`, branch `c2/secrets-roster` (from main `claude/v0.1-restore`). Work only here.
Commit per slice (clear messages, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); do not merge.
Never touch the main checkout, other worktrees, `.codex/`, `.kimi-code/` or ~/Desarrollo/cpore-refs/.

Read: `docs/CREATURE-ROADMAP.md` C2, `docs/DESIGN.md` G65, G68, W8, W10, A24, `docs/P4.md`, `docs/TERRAIN.md` (caves are only notches
today; v4 rivers; v5 visual heightfield), `docs/ROUTES-REPORT.md` and `tests/routes/` (cave approach apron, certified routes),
`docs/creatures/acechalunas.md` + `lore/creatures/acechalunas.json` (the nocturnal creature), the island lore in `lore/creatures/*.json`
with world primigenia, `docs/lore/` and `lore/worlds/primigenia*` (meteor/crater canon), `core/src/stage_world.c`, `godot/game/island/island.gd`,
`godot/game/data/{rondo,zanco,espinodo}.json` (how the species bodies were just built from existing parts).

Other agents now: `c2/moves-recipes` (Codex: combat moves, recipes, meters, rock-armour stones; files `core/src/combat*`, new
`stage_recipes.c`) and `c2/journal-polish` (Sonnet: Godot UI journal; it will read `state().shards` and species lists you expose:
document the field names in your report early). Keep `stage_world.c` hooks small and isolated.

## Slices
S1 **Meteor shards (W10, G68).** 5 shards placed deterministically per seed, reachable on foot (add them to the route certification
set and keep 144/144 → more trips), one line of story each (draft from the primigenia canon; Spanish + English; mark DRAFT for the owner),
the five lead toward the crater. Pick-up verb/event `shard_found`, saved state, world-2 `shards`, Python binding, a whisper line, DNA award
per P4 tables if any. Simple shard mesh (glowing metal, Hierroflor violet can grow near them later).
S2 **The hidden cave interior (G65, G68).** Today the cave is a notch. Make one real walkable chamber behind the hidden entrance (sim
walk grid + visual), dark inside, with one fossil node or shard inside, reachable by the certified cave route. Keep TERRAIN.md limits and
goldens (document any regeneration once).
S3 **Nocturnal Acechalunas + day/night shift (W8, G68).** Its own body from existing parts (like Rondo/Zanco/Espinodo), its home range,
active at dusk/night (hidden/sleeping by day), a befriending bonus in the dark, it counts as a species for the Q43 loop. Nocturnal species
shift at dusk (P4 line 143).
S4 **A 6th species** from the island lore that fits existing parts (your pick among primigenia creatures, e.g. babosa, sifon, ecolumbre; NOT the
radial ones, which need a generator that does not exist yet), own body, temperament, diet, home range. Roadmap wants 6–8 species.
S5 Tests (C + Godot headless), routes still all reached, `make test`, `make smoke`, `make tourney`, Godot suites, soak (`make godot-soak`).
Evidence: xvfb JPG (not PNG) in `docs/evidence/godot/secrets/`: each shard with its line, the cave interior, Acechalunas at night and hidden
by day, the 6th species, a lineup. Look at every image and fix what is visibly wrong. Update CREATURE-ROADMAP "Where we are", P4.md and a
report `docs/SECRETS-REPORT.md`.

Godot: always `timeout`, `--check-only` first, headless/xvfb software rendering, `nice -n 10`. Kill only processes you started, by pid;
never `pkill -f`. The owner may be playing from the main checkout.
