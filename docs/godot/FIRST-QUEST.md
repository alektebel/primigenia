# The first quest: kill, befriend, dig, wings, fire (branch `c2/first-quest`)

The owner: "let's try making the whole e2e gameplay: kill a creature, befriend another one, dig a hole, get wings by digging and
lastly, editing the creature to get the flamethrower, as in tasks." This is that chain, as data, with the three things it needed
that the game did not have: a dig verb, fossil beds, and a fire gland with a flamethrower.

## How to play it (you, with the mouse and keyboard)

```
make godot            # builds the GDExtension in this worktree (copy the main checkout's .so into godot/bin first if you only want to play)
godot --path godot    # Play -> a new game, hatchling, 08:00
```

A small note sits top-left (the task card, journal paper and ink): the chain's five marks, the current task and its hint.
**K** folds it to a tab and back, at once (a key press is not animated). A copper dot on the round map (top-right) is the task's
ping, never a route. Each completion is a whisper and a moment line, and pays DNA (10, 10, 5, 20, 25). The J journal has a
**Tareas / Tasks** tab (last): done, now, later.

1. **Caza / Hunt.** A Rondo herd lives about 85 m from the nest (Zanco 110 m). Click-walk to one, click it, choose Attack (east
   of the ring), press 1 (bite) until it falls. The hatchling beats them. Garfio (60 m, aggressive) is the one to avoid.
2. **Haz un amigo / Make a friend.** Befriend a creature of another species than the one you killed: choose Befriend (west of
   the ring), then keys 1-4 (sing, dance, charm, pose) in time with its beat, or G for a gift. A bond is trust 60.
3. **Excava / Dig.** Press **X** anywhere dry (A54: no button stays on screen; a one-time hint "X: dig" shows the first time). Stand
   still: 2 s on soft soil, 3.5 s on hard ground (steep, shore sand), 5 s on rock (cliffs, caves). A hairline ring fills at your feet
   while you dig. It costs 12 stamina. Only water refuses. Fossil beds (cracked dry soil) still decide the finds; elsewhere it is
   soil, a grub or a pebble.
4. **Alas del pasado / Wings of the past.** The wing bed is 22 to 62 m from the nest, always on a walkable line: cracked dry soil,
   a paler grass, bone splinters and black glassy flecks sticking out, a faint dust puff now and then, and a key label within
   7 m. Digging it unearths a winged ancestor (`wing_vane`) and, in the same seam of burnt rock, a scorched throat gland
   (`fire_gland`). Lore: the island is volcanic (lore/flora zonation: "volcanic fractures"); the vents cooked the sediment, so
   the bed holds both. Two more bone beds lie further out and give old parts.
5. **Fuego / Fire.** Menu > Edit creature (edit anywhere is on), put the gland on the body (it sits under the jaw), Evolve (30
   DNA). The Flamethrower joins your loadout (slot 3), pick a creature, press 3.

Console (backtick): `quest status | skip | reset` (skip completes the current task without its reward), `dig`, `order dig`.

## What is in C (`core/src/stage_dig.c`, combat.c, stage_parts.c; snapshot 10)

* **Verb `CP_STAGE_DIG` (20)**, text `dig`. Digs anywhere dry (A54; A38 allowed soft soil only). `cp_stage_dig_hardness`: soft soil
  (dry, outside the cave, ground at least 0.3 m, slope at most 0.35) 0, hard ground 1, rock (slope over 0.8, caves) 2, water -1 (the
  only refusal, error -27). The time is a pure function of the position: `CP_DIG_TICKS` 20 (soft), `CP_DIG_TICKS_HARD` 35, `CP_DIG_TICKS_ROCK` 50,
  standing still (a move or any order but CONTINUE cancels it; the stamina, 12, is gone),
  hole list of 16 (ring), events `CP_STAGE_EV_DUG` (target = hole, move = find, -1 = interrupted, value = bed) and
  `CP_STAGE_EV_MOVE_USED`. Errors `-27` hard ground and `-28` already dug; events DUG=30, MOVE_USED=31; flame is move 14.
* **Beds** are derived at reset from the seed and the field with their own RNG stream (no other stream is touched): bed 0 is the
  wing bed, 22 to 48 m from the nest by random candidates (two draws each, a budget of 96) then a deterministic ring scan, on
  soft soil and a straight walkable line (`cp_stage_walkable_from_nest`), 6 m from any surface find; up to two bone beds
  55 to 105 m out. Small finds in plain soil: 14 % grub (+12 food), 10 % pebble, otherwise soil.
* **Parts** 46 -> 48: `wing_vane`, `fire_gland` (cost 30). The wing bed discovers both and pays 10 DNA (source fossil).
* **Combat.** `CB_FLAME` (move 6, part `CB_PART_FIRE`, profile field `fire`, last in the struct): wind-up 6, active 6, recovery
  5 ticks, reach 3.5 m, arc 0.9 rad, 14 stamina, 5 damage, sweep (every enemy in the cone, once per use), status `CB_ST_BURN`
  (0.5 hp per tick for 40 ticks, credited to the user), cooldown 60 ticks, role Poke. Counter rows: guard reduces it (x0.5, no
  burn), a bite interrupts it while it winds up or burns (like the spit). The part is `fire_gland` (`profile.fire` = level).
* **Reward**: `cp_stage_quest_award(step, dna)`: once per step (bitmask in the dig block), source `CP_DNA_TASK` (11).
* **Hash and goldens.** The dig block and the new profile/burn/part/move state are hashed only once used or nonzero, and the
  part and move tallies skip the new slots while zero, so every committed golden is byte-identical (world-1/42/987654321,
  world-debug-42, world-field-1, combat goldens, routes 288/288). The tournament keeps its six base moves (no tournament build has a
  gland): `CB_TOURNEY_MOVES = CB_FLAME` in apps/combat_tourney.c; `make tourney` passes unchanged.
* **Snapshot 10** (renumbered at integration; was 9) (digging, beds, holes, quest bitmask, burn state, `profile.fire`). The integrator renumbers if species v8 bumps too.
  Migration: `Scenario.load_into` now rebuilds from the scenario's recipe on a format mismatch as it already did for engine
  and layout mismatches (`-2`), so older saves with a recipe load.

## What is in Godot

| File | What |
|---|---|
| `game/data/quests/first.json` | the chain (ES/EN): id, title, hint, done whisper, `cond`, `marker`, `reward` |
| `game/stage/quest.gd` | the model: live conditions, order, one completion per tick, markers, save |
| `game/stage/first_quest.gd` | glue: card model, whispers, DNA via `quest_award`, dig key and chip, burn flames, minimap ping |
| `ui/quest_card.gd`, `ui/dig_chip.gd`, `ui/minimap.gd` (ping) | the card, the dig entry at your feet, the quiet ping |
| `game/stage/dig_site.gd` | bed cues, holes (dark floor, rolled lip, soil piles), soil burst while digging |
| `game/actors/flame_fx.gd`, `actions/data/flame.json` | cone of fire, heat shimmer (screen-reading shader), warm light, burn flames; the creature's mouth opens, head rises |
| `creature/creature_parts.gd` | procedural `fire_gland`: a warm sac under the jaw, glowing seam, horny nozzle with an ember |
| `ui/journal_view.gd`, `ui/journal_model.gd` | the Tareas tab |

Saved with the game: `scenario.quest` (step, completion ticks, remembered species, folded flag).

## Tests and evidence

| Suite | Result |
|---|---|
RESULTS_PLACEHOLDER

`make godot-first-quest-e2e` plays the whole chain with a bot that uses only the verbs a player has (see the header of
`godot/game/tests/first_quest_e2e.gd`) and runs it twice to compare the final tick and world hash. Evidence (xvfb, software GL):
`docs/evidence/godot/first-quest/` (`make godot-first-quest-evidence`), one frame per task and a contact sheet.

## Decisions the owner may want to change

* The quest is Godot-side data over C state; only the DNA payment is a C call (`quest_award`, a direct call like `nest_edit`,
  once per step, not an input-log entry).
* The wing bed also gives the fire gland (the brief had the gland unlocked "as the reward of step 4 to 5"; paying it from the
  bed keeps the unlock deterministic and in C, and the journal shows both parts found together).
* The flamethrower is role Poke, not Signature (Signature needs the signature slot and an unlock path, C5). The grass does not
  burn yet (C5).
* `X` and `K` are new keys (legend entries added); the dig also has the ring at the feet, since there is no creature to open
  the mode ring around. A dig entry inside the mode ring was not added.
