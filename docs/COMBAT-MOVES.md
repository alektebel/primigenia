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
