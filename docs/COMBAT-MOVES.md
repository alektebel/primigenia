# Creature moves: roles, loadout and learning (A21)

Status: **design, 2026-11-18** (owner approved). Builds on the C combat core (`docs/COMBAT.md`, `core/src/combat.c`).

## 1. Roles

Every move has one role. The role sets its colour in the UI, its place in the loadout screen and roughly its numbers.

| Role | Job | Shape of the numbers |
|---|---|---|
| **Basic** | cheap, reliable damage | short wind-up, low stamina, no cooldown |
| **Engage** | close the gap, open the fight | long wind-up, a dash, big hit, stun |
| **Poke** | hurt from range | ranged, narrow, long recovery |
| **Control** | slow, stun, scare, hold in place | area or status first, damage second |
| **Defence** | survive | self moves (guard, dodge and their variants) |
| **Signature** | the "ultimate" | strong, long cooldown, unlocked by a deep secret |

## 2. Roster (target for the whole creature stage)

| Move | Role | Part | Status | Phase | Source |
|---|---|---|---|---|---|
| bite | Basic | mouth | bleed | today | start |
| claw swipe | Basic | hands/claws | bleed | C2 | parts |
| peck | Basic | beak | — | C2 | parts |
| charge | Engage | horns/body | stun | today | start |
| pounce | Engage | strong legs | stun | C2 | parts / observe |
| burrow ambush | Engage | digging claws | stun | C5 | digging |
| spit | Poke | spit gland | slow | today | start |
| quill volley | Poke | quills | bleed | C2 | parts |
| thrown claws | Poke | claws (deep) | bleed | C5 | deep secret |
| tail strike | Control | tail | slow | today | start |
| roar | Control | throat/crest | **fear** (target flees) | C2 | intimidate mode |
| stomp | Control | heavy legs | stun around you | C2 | parts |
| web shot | Control | silk sac | **held in place** | C3 | deep secret (webs) |
| guard | Defence | shield parts | — | today | start |
| dodge | Defence | none | — | today | always |
| curl up | Defence | rock armour | — | C2 | deep secret |
| ink cloud | Defence | ink sac | **blind** | C4 | deep secret |
| flamethrower | Signature | fire gland | **burn** | C5 | deep secret |
| evolved bombs | Signature | bomb sacs | stun around | C5 | deep secret |
| bone-spine frenzy | Signature | bone spines | bleed | C2 | deep secret |

Every new move adds counter rows, so the counter triangle stays readable: each move should beat one thing and lose to one thing.

## 3. Loadout (the League-style kit)

- **The body is the champion.** Parts decide which moves you *can* have (part level 0 removes a move, as today).
- **Four slots** on keys 1–4, plus **guard and dodge always on** (Space, Q/E). One of the four can be the **signature** slot once a signature move is unlocked; a signature move can only sit in that slot.
- **Chosen at the nest** (like champion select): changing the loadout is only allowed near your nest. A fight is played with the kit you brought.
- **Ranks**: part levels 0–5 (+10 % per level, already in C) are the move's rank; DNA buys ranks.
- **Cooldowns**: a new per-move value. Today's moves have cooldown 0 (stamina is their limit); Signature moves get long cooldowns.

## 4. Learning moves

1. **From parts**: adding a part in the creator/at the nest makes its move known.
2. **By observing, from first principles** (A22): each trait is a causal chain from the planet's physics to the move (e.g. low hum ← dense air carries sound ← fog blinds eyes ← cold sea on warm volcanic ground). Observe mode reveals the chain one link at a time in the journal (watch the move, watch the habitat, watch the weakness); completing the chain makes the move learnable at the nest. Other creatures become teachers, and the journal becomes a book of reasons, not just names.
3. **From deep secrets**: each one unlocks a move (most of the Signature and Defence variants).
4. **Combos** (later): short timing windows, e.g. a tail sweep right after a bite does more.

## 5. Rules for the engine

- All of it lives in C (loadout, known moves, cooldowns), validated like any order, hashed, in snapshots and replays (Q24).
- The observation lists the loadout, known moves and cooldowns, so LLM players and the benchmark see the same kit as a human.
- The default loadout reproduces today's behaviour exactly, so existing replays and goldens stay valid.

## 6. Implementation (C2-loadout, 2026-11-18)

The infrastructure of sections 3 and 5 is in; no move or status was added.

**C core (`core/include/cpore/combat.h`, `core/src/combat.c`)**
- `CpCombatMove` has `role` (`CB_ROLE_BASIC .. CB_ROLE_SIGNATURE`) and `cooldown` (ticks, 0 for all six shipped moves). A move's cooldown starts when it starts (`begin_move`) and each fighter's counter `cd[move]` drops by one at the end of every tick, so it is part of the state and deterministic.
- `CpCombatLoadout` = four slots (move id or `CB_MOVE_NONE`), `sig_slot` (-1 until a signature move is unlocked: that slot holds only Signature-role moves and nothing else), `known` bitmask. Guard and dodge are never in a slot. The default loadout is the known attack moves in table order (bite, charge, spit, tail_strike); `known` is the moves whose part level is above 0 (`cp_combat_known_default`, and `cp_stage_known_moves` in the stage is the hook where moves learned by observing will be OR-ed in).
- Attack orders check, in this order: bad move, `unavailable` (part/medium), `not_equipped`, `on_cooldown`. A standing attack on a recharging move waits instead of firing.
- Hash: the loadout is written only when it differs from the default, and `cd` only while some counter is nonzero, so every existing golden hash is unchanged. `cp_combat_loadout_set` validates slot, move and knownness and moves a move that is already slotted elsewhere.

**Stage (`core/include/cpore/world.h`, `core/src/stage_world.c`)**
- The player's loadout lives in `CpStageWorld.loadout` (a fight is a fresh combat world; the loadout is copied into it at the start). New order `CP_STAGE_LOADOUT` (verb 10; `target` = slot 1..4, `move` = id or -1) and text `loadout SLOT MOVE` (move by name, index, or `none`). It is instant (it does not replace the standing order), so a replay logs it as one input at its tick.
- Rules and errors: `invalid slot` (-10), `unknown_move` (-12: not an attack move id; guard and dodge included), `in_fight` (-14), `not_at_nest` (-13; within `CP_STAGE_NEST_RADIUS` = 12 m of the nest), `not_known` (-11). Attack errors added: `not_equipped` (-9), `on_cooldown` (-8). `cp_stage_parse` parses a command text without touching a world.
- Snapshot version 3 (new `loadout` member and `lo`/`cd` in the combat creature; the LAY fingerprint covers them). The 9 curated scenarios were regenerated in a separate "Golden change" commit; their state hashes are unchanged.

**Observation world-2 (`legal_verbs` and the new keys)**: `loadout` {`slots` (4 names or null), `signature_slot` (1..4 or null), `can_edit`, `nest_radius_m`}, `known_moves`, and every `attack_moves` entry has `role`, `cooldown_ticks`, `cooldown_left`, `equipped`, `slot`; `usable` now also requires equipped and ready. `legal_verbs` lists `loadout` only when it would be accepted (at the nest, no fight). world-1 is unchanged. The Python binding (`CP_STAGE_LOADOUT`, verb name `loadout`), `tools/agentplay` (checks, errors, prompt, scripted and random policies) and the GDExtension (`CporeWorld.moves()`, `state().loadout`, per-fighter `cooldowns`) carry it.

**Godot**
- Keys 1-4 fire the move in loadout slots 1-4 (`godot/game/stage/stage_ui.gd` maps the hotbar entry to its C move id; an empty slot does nothing). The hotbar is the existing move bar at the bottom centre: each slot shows key and name, a border in the role colour (`Palette.ROLE_COLORS`: basic green, engage orange, poke yellow, control purple, defence blue, signature pink) and a clock-style cooldown sweep (`godot/ui/cooldown_sweep.gd`) fed from the fighter's `cooldowns`.
- The loadout panel (`godot/ui/loadout_panel.gd`) opens with **L** (InputMap action `loadout`, listed in `legend.json`), only at the nest outside a fight (otherwise a toast says so), and closes by itself if a fight starts or the player walks away. One drop-down per slot lists the known moves; a choice is sent as the C order, never written by the UI. Moves the body cannot do are disabled in the list and refused by C (`not_known`) if sent anyway.
- Console: `loadout <slot 1-4> <move|none>` (goes through C and the input log, replayed to the same hash).
- Evidence: `docs/evidence/godot/loadout/` (`make godot-loadout-evidence`; `hotbar_real.png` is the real two-move loadout, `hotbar.png` feeds the HUD a four-role kit and a 60 % sweep by hand because no shipped move has a cooldown yet).

**Not done (by scope)**: no new moves or statuses, no learning by observing (only the hook), no signature unlock, no cooldown on any shipped move, so the cooldown rejection and sweep are exercised by tests with a test-only override (`cp_combat_test_cooldown`) and by poking the counter, not by gameplay.
