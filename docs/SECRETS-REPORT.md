# C2 secrets and roster: report

Branch `c2/secrets-roster` (from `claude/v0.1-restore`). Slices S1 to S5 of `_agent/briefs/c2-secrets.md`: five meteor shards, the hidden
cave as a real chamber, the nocturnal Acechalunas with a day and night cycle, a sixth species (Babosa), tests and evidence.
Everything below is **DRAFT for the owner** where it is writing (story lines, names, numbers).

## What it is

| Slice | What the player gets | Where it lives |
|---|---|---|
| S1 Shards (W10, G68) | Five glowing iron-nickel clusters along one bent ray that leaves the valley; `E` collects within 2.5 m, one whisper line of story each (es/en), +5 DNA each, +10 for the set | `core/src/stage_secrets.c`, `godot/game/stage/shard_nodes.gd` |
| S2 Cave (G65, G68) | The first cave entrance leads into a 14 m passage and a round 10 m chamber (dark, cold light, glowing floor patches) with a fossil to inspect | `stage_secrets.c` (ground rule), `godot/game/island/cave_site.gd` (same rule + interior mesh) |
| S3 Night (W8, G68) | A clock that matters: dusk 18:00 to 20:00, night to 05:00. **Acechalunas** sleep hidden by day, wake at dusk, trust you 50% more in the dark | `stage_secrets.c`, `stage_social.c`, `godot/game/island/day_night.gd` |
| S4 Sixth species | **Babosa**, a slow herbivore slug that hunkers into its mucus sphere in the noon light and moves at dusk, night and dawn | `stage_world.c` species table, `stage_social.c`, `godot/game/data/babosa.json` |

## Design in the C core (deterministic: integer or + - * / sqrtf, no libm trig)

**Setup.** `setup.secrets` is a bit set (1 shards, 2 cave), `setup.start_clock` is the clock at tick 0 (the game uses 4000 = 08:00),
`setup.cave` is the terrain's first cave record (`x, z, fx, fz`; optional `half, length, radius`). All zero = off, and then nothing in the
simulation or its hash changes: the five world goldens, the combat goldens and the n=32 terrain hashes are untouched. Snapshot format is 7.

**Shard placement.** A flood fill over 8 m cells (dry, gradient under 0.42, no water within 6 m, edge steps under 0.42) from the nest gives
the reachable land. The five shards lie along **one bent ray** (the canon, `lore/worlds/primigenia.json` F22: "the 5 shards lie along one bent
ejecta ray"): sixteen unit directions (a table, no trig), the start direction chosen from the field hash, the direction rotating one sixteenth
every second shard, ideal radii 110, 330, 650, 1000 and 1400 m scaled down (1.0, 0.85, 0.7, 0.55, 0.4) until all five fit. Each ideal point
snaps to the nearest reachable cell that is a good site: fine slopes under 0.30 at the site and 2 m around it (the planner's 0.25 m stencil), at
least 70 m from the other shards, and no steep face within 4 m of the straight line to the nest (a big body swings wide of the planner's straight
line and stalls). `state().shards.toward_crater` is the end of the ray (the crater itself is C5). The direction comes from the field hash, so an
island always has the same trail.

**Cave.** The heightfield cannot hold a hollow, so the chamber is a region where the walkable ground is **flat at the entrance floor**:
`cp_stage_secrets_ground` overrides the height inside a passage (half-width 4 m, length 14 m, hard step at the entrance plane after a 4 m lead
that keeps the trail's 0.30 slope, 3 m blend) and inside a round chamber (radius 10 m). The planner, the gradient rule, `can_walk` and the walker
all read the same function, so no other code knows about the cave. The rock beside the passage keeps its steep heights and blocks like a cliff.
The fossil is an extra part node (the ninth slot), id `3000 + n_nodes - 1`, inspected with the normal 20 tick rule.

**Day and night.** `cp_stage_daylight` is permille light from the world clock (500 ticks an hour): 0 from 20:00 to 05:00, a linear dawn 05:00 to
07:00, 1000 by day, a linear dusk 18:00 to 20:00. A **nocturnal** species is *hidden* while the light is 500 or more: it is not in `nearby`, orders
on it fail with `invalid or unavailable target`, it does not roam, is never hostile, and is not counted as seen. A **crepuscular** one *hunkers*
(does not roam, state `hunkered`) at light 900 or more. In the dark (light under 250) a nocturnal creature's trust gains are x1.5 and its mood
drifts up; in bright light (750 or more) it drifts down ("nocturnal species shift at dusk", P4).

**Species.** `CP_STAGE_SPECIES_COUNT` and `CP_SOC_SPECIES` are 6. `social.tested/liked` are 64 bit. Hash blocks include species 4 and 5 only
once they carry state. Preferences, observe chains (Acechalunas teaches `bite`, Babosa `spit` with the moves that exist today; the moves agent can
retarget them), kill drops and the ally signature part (Acechalunas `lure_lantern`, Babosa `sac_spitter`) are tables in `stage_social.c` and `stage_parts.c`.

## The shard lines (DRAFT, one each, both languages; canon F22: the second capsule, ~12,000 years old, one bent ejecta ray)

| # | Name | English | Español |
|---|---|---|---|
| 1 | Spark / Chispa | A warm iron stone, humming faintly. It did not grow here. It fell, and it fell in a line. | Una piedra de hierro, tibia, que zumba apenas. No nacio aqui. Cayo, y cayo en linea. |
| 2 | Trail / Estela | Its edge is glassy and bent, the way a thing melts when it arrives too fast. The line bends with it. | Su borde es vitreo y torcido, como lo que se funde al llegar demasiado deprisa. La linea se curva con el. |
| 3 | Seed / Semilla | Inside the metal runs a seam of tiny cells, long dead and still in order. A seed, thrown with the stone. | Dentro del metal corre una veta de celulas diminutas, muertas hace mucho y aun en orden. Una semilla lanzada con la piedra. |
| 4 | Echo / Eco | The humming is a pattern, not a noise: counted, patient, repeating. Someone made this to be found. | El zumbido es un patron, no un ruido: contado, paciente, repetido. Alguien hizo esto para que lo encontraran. |
| 5 | Threshold / Umbral | The stone is cold toward the crater and warm away from it. The second capsule is still there. | La piedra esta fria hacia el crater y tibia al otro lado. La segunda capsula sigue alli. |

(The Spanish lines are written without accents in the C table so the JSON stays ASCII; the Godot strings carry the accented names.)

## State fields exposed (for the journal agent)

All come from `CporeWorld.state()` (Godot) and the `world-2` observation (Python, text agents; `secrets` object):

* `state().shards` : `{total: 5, found: n, mask: bits, items: [{id: 3100+k, index: k, name: "Spark", found: bool, x, z, line, line_es}], toward_crater: {x, z}}`. `line` and `line_es` exist only once found.
* `state().cave` : `{enabled, entered, chamber_entered, inside: 0|1|2, x, z, fx, fz, floor, half, length, radius, chamber_x, chamber_z}`.
* `state().day` : `{light: 0..1000, phase: "dawn"|"day"|"dusk"|"night", night: bool, hour: 0..24}`; `state().clock` is the raw tick of the day.
* `state().species` (new, one entry per species 0..5): `{id, name, activity: 0|1|2, temperament, seen, resolution: "open"|"ally"|"hunted", bonded, kills, observed, present, hidden_now}`. `state().social.species` keeps its older shape (six entries now).
* `CporeWorld.species()` (static): the six species with `activity`, `activity_name`, `nocturnal`, `diet`, `chain`, profile and AI numbers. `CporeWorld.chains()` has six chains.
* Per entity in `state().entities[i]`: `hidden` (asleep by day: draw nothing, not targetable), `hunkered`, `activity`.
* Events in `state().social_events`: type 25 `shard_found` (`target` 3100+k, `move` k, `value` found so far), type 26 `cave` (`move` 1 passage, 2 chamber). DNA events carry source index 10 = `shard`.
* Orders: `inspect #3100` to `#3104` (shards), `inspect #3008` or the last node (the chamber fossil).

## Tests and gates

| Gate | Result |
|---|---|
| `make test` (C) | passes. New: `make secrets-test` (`tests/test_secrets.c`): the flat-world rules (clock curve and start clock, hidden by day, +50% trust in the dark, Babosa hunker, Q43 ally for Acechalunas, old species unchanged) and, on each certified island (seeds 1, 7, 42), shard placement and determinism, **every shard walked to with the real planner and collected once**, the story and DNA events, snapshot and restore with a found shard, the chamber walked into by the real planner, the cave events once, the chamber fossil inspected, the cave walls blocking, the cave-only mode, the hash only changing when secrets are on. 35 `PASS secrets:` lines in all |
| Routes (`make routes-test`) | **288/288 trips on each of seeds 1, 7 and 42** (was 144): the new places are the Acechalunas and Babosa homes, `shard-1` to `shard-5` and `cave-chamber`, all nine bodies, both directions; every trajectory replayed to the same tick-hash digest. The gate also checks that the pinned shard and chamber places are what the C world derives from the field |
| `make tourney` | passes (`tourney checks passed`); combat is untouched |
| `make smoke` | passes (lineage, social, parts/nest Python smokes; the binding gained `StageWorld(start_clock=...)` and the `CpStageCave` setup struct) |
| `make godot-test` (M0 runner) | 628 checks, 0 failures; 35 of them are the new `game/tests/test_secrets.gd` (island setup with species 4 and 5, state fields, the GDScript cave ground equal to the C ground at 120 points, chamber zone, shard pickup, hidden flag at day and night) |
| Other Godot suites | parts-nest PASS; route events 0 failures; lineage 0 failures (two suites); ui 556 checks; heights 15; actions 345; loco 216; creature 1471 + realism 64; studio 824 + web cross-check 8 files. `godot-social-test`: the first full run had 22 checks and one failure, the old "all four species are present", now "all six" (and the test uses the fresh terrain cache folder); the rerun hit the Makefile's 900 s timeout under load 20 to 37 after 70-plus `ok` checks and no FAIL, including the six-species check |
| `make godot-soak` | **Not completed in full.** The machine ran at load 20 to 37 from other agents (median frame 1.6 s in software GL), and the ten-minute soak got through stages 1 to 3 in 45 minutes before it was stopped (stages 1 to 3 had 0 failures). I added a stage 9 (a shard collected with the real `E` key, Acechalunas hidden by day and out at night, the player in the cave chamber) and two options (`[WxH] [quick]`); `quick` skips stages 1 to 8 and runs stage 9 plus free play: `island_soak.gd -- <out> 3 640x360 quick` gave **11 checks, 0 failures, 3.2 simulated minutes, no NaN or script error**. The full 10 minute soak still needs a quiet machine |
| Pre-existing failures, identical on the base commit (checked in a scratch worktree of `763447d`) | `godot-devtools-test`: `test_feedback.gd` (2 checks) and `test_curated.gd` (the 9 curated scenarios, made on an older island, hash `2811...`, not the current one). `godot-agent-test` could not listen on port 47110 while other agents ran |

Goldens: **no regeneration of any terrain or simulation golden.** The five world replay goldens, the combat goldens and the n=32
terrain hashes are bit-identical (the new state is hashed only when a secrets bit is on). The route fixtures `tests/routes/seed{1,7,42}.json/.txt`
gained places (shards, chamber, the two homes); their terrain hashes are unchanged. Snapshot format is 7 (an older save is refused by
the layout fingerprint, as before). `docs/TERRAIN.md` limits are untouched: the cave interior is a stage-world rule over the unchanged heights.

## Evidence

All JPG, `docs/evidence/godot/secrets/` (xvfb software GL, `godot/game/tests/secrets_evidence.gd`, `cave_preview.gd` and
`creature/tools/species_shots.gd` regenerate them):

* `shard_1_line.jpg` to `shard_5_line.jpg`: each shard picked up, with its story line as the whisper and the moment line. `shard_1_day.jpg`, `shard_1_night_glow.jpg`, `shard_4_night_glow.jpg`: the cluster by day and in the dark.
* `cave_mouth.jpg`, `cave_passage.jpg`, `cave_chamber.jpg`, `cave_fossil.jpg`: the rock arch and dark mouth on the graded apron, the cold passage, the chamber with its glow patches, the fossil on the chamber floor.
* `acechalunas_day_hidden.jpg` (the same spot by day: nobody there), `acechalunas_night_wide.jpg`, `acechalunas_night_close.jpg` (three of them at the cave mouth at 23:00).
* `babosa_noon_herd.jpg`, `babosa_dusk_close.jpg`; `lineup.jpg`, `lineup_side.jpg` (all six species and the player), `acechalunas_side.jpg`, `babosa_side.jpg`.

What the images showed and was fixed on the way: the first mouth was a concrete-looking box (now an arch of cliff rock with a dark portal that hides the unchanged cliff face behind it);
the first cave camera sat above the roof and showed the sky through the terrain (a dedicated close cave camera now); creatures
set to hidden stayed hidden at night when the chase camera was off (visibility no longer depends on it); the cave fossil was buried in the rock above the chamber (the cave floor rule is now installed before the part nodes are placed).
Known soft spots: the glow patches are plain discs; at noon Babosa's wet skin reads pale; the night grade only dims (the terrain and grass shaders use their own sun), there are no stars.

## Open questions for the owner

1. Approve (or rewrite) the five shard names and lines above, and the DNA they pay: 5 each, +10 for the set (P4 has no table entry for shards).
2. Day length: 20 real minutes a day, the game starts at 08:00, so dusk falls about 8 minutes in and the night lasts about 7.5 minutes. `StageSetup.CLOCK_START` and `CP_STAGE_DAY_TICKS` are the knobs.
3. **Stale terrain cache.** `~/.local/share/primigenia/terrain/island-1-t4-r5-*.bin` holds the island from before the route-certification terrain curation (terrain hash `4d0d207c890bf378`, first cave at (747, 378) with no graded apron; the generator now gives `7137e3ea79830ad7` and the first cave at (61.5, 620.5)). The cache key has the terrain version but no generator revision, so the owner's game can still load the old island, where the Acechalunas find no flat spot near the cave. Delete that folder, or add a generator revision to the key. The secrets evidence and soak use their own cache folder (`user://terrain-secrets`).
4. The shard ray ends 500 to 750 m from the nest (`state().shards.toward_crater`), where the reachable valley ends; the real crater is C5 (the volcano and crater generator is off by default).
5. Acechalunas teaches `bite` and Babosa `spit` (moves that exist today); the moves agent can retarget them (pounce, peck). The lineage cousins use logical species ids `4 + generation` in their JSON, which now overlap numerically with the new species ids 4 and 5 in the journal's id space; they are unrelated (a cousin's C species is one of the four AI templates).
6. By day the Acechalunas are simply not there. If you would rather they wake when you come within a few metres of their den, that is a small rule in `cp_stage_creature_hidden`.
7. The WASM world and web stage were not rebuilt (no emcc run here); the goldens are unchanged, so parity should hold, but it is unverified.
8. Commit trailers say `Claude Sonnet 5.5` (the session's attribution rule) rather than `Opus 5.5` as in the brief.
