# Creature combat core (P2)

`core/include/cpore/combat.h` and `core/src/combat.c` implement the standalone
creature combat simulation described in DESIGN.md G16 and Q24/Q31/Q50/Q52.
The old land stage is unchanged. Pack orders, nest/egg consequences and Cognition
integration belong to later phases (G18/G23/G36); this module supplies their
movement/combat foundation, not those stage systems.

**Review status (2026-11-15):** move-level balance acceptance passes on the
fixed development set and a fresh held-out set with four times the samples.
Both raw and resource games have five moves above 1% equilibrium weight and
no weak dominance. All tournament canaries and the 65%/90% build caps pass.
Native correctness and WASM parity pass. Stage calibration is documented below.
This establishes the P2 move-level prerequisite for G53/G55, not the pending
human playtest or the later pack/nest/Cognition systems.

## Move data

`CP_COMBAT_MOVES` is the authority. One tick is 0.1 seconds. Costs and damage
below are level 1; reach is attacker centre to target surface, except a dash's
reach is its total travel distance. Arcs are full cone widths in radians.

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags / required part |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| bite | 3 | 1 | 2 | 1.8 | 1.00 | 9 | 11 | bleed (8) | mouth |
| charge | 10 | 5 | 2 | 5.0 | 0.70 | 18 | 30 | stun (6) | dash, ground only / charge |
| guard | 1 | 14 | 2 | 0 | 2.40 | 1 | 0 | none | self, frontal guard / guard |
| spit | 6 | 1 | 4 | 6.0 | 0.25 | 12 | 13 | slow (20) | ranged / spit |
| tail_strike | 3 | 2 | 4 | 2.2 | 1.60 | 10 | 17 | slow (15) | sweep / tail |
| dodge | 1 | 3 | 2 | 2.2 | 0 | 20 | 0 | none | self, directional dash, evade / always available |

Parts have levels 0–5. Level 0 removes the associated move. For level L >= 1,
damage is `base * (1 + 0.20 * (L - 1))` and start cost is
`base * (1 + 0.10 * (L - 1))`. Dodge has no part and always uses level 1.
The default profile has every part at level 2, 100 HP, 100 stamina and 4 m/s
walking speed. Start cost is paid once; unaffordable orders wait and emit
`CB_EV_NO_STAMINA`. There is no passive HP regeneration.

Attacks apply to enemies in their facing cone, with 0.42 m lateral aim slack.
Bite/charge hit one enemy per use; spit hits the nearest enemy along its cone;
tail hits each enemy in its sweep at most once. Charge checks contact at a
body-surface gap <= 0.35 m after movement, rather than damaging everything
within its full travel reach. Dash direction locks when the move starts.

## Counter matrix

`CP_COMBAT_COUNTERS` is an ordered table; the first matching row wins.
Unlisted match-ups use normal damage and status. Guard rules cover only its
frontal cone, so flanking bypasses them.

| Incoming move | Defender move / phase | Result |
|---|---|---|
| tail_strike | dodge / active | Catch the dodge: full damage and slow, interrupt its move/order, stagger for 3 ticks. |
| any other attack | dodge / active | Avoid the hit and status, paying 2 additional stamina per avoided hit. Release dodge and stagger the attacker for 5 ticks. If unaffordable, the hit lands normally and earns no stagger. |
| charge | guard / active | Break guard, deal 60% damage, drain up to 20 stamina, stagger for 5 ticks; charge's stun also applies. |
| bite | guard / active | Negate damage and bleed; block cost is incoming damage × 0.10 / guard factor. On success release guard and stagger the attacker for 5 ticks. |
| tail_strike | guard / active | Deal 25% damage, suppress slow; block cost is incoming damage × 0.10 / guard factor. On success release guard and stagger the attacker for 5 ticks. |
| spit | charge / wind-up | Interrupt charge and its order, deal normal damage/slow, stagger for 6 ticks. |
| bite | spit / wind-up or active, centre-to-surface gap <= 2 m | Interrupt spit (including its same-tick hit), deal 125% damage and bleed, stagger for 4 ticks. |

The guard factor is `1 + 0.15 * (guard_level - 1)`. An exhausted block fails,
sets stamina to zero and stuns for 6 ticks. The tail exception is checked before wildcard avoidance.
The test-only `CP_COMBAT_TEST` build exposes `cp_combat_test_hit_variance`: enabling it fixes the damage roll at exactly 1.0 while still consuming the normal RNG draw. It is absent from production libraries and tournament builds. Exact damage tests cover charge 60%, tail 25%, rear 1.5× and the height cap.

The tests exercise every row independently, including stamina failure paths,
rear guard bypass and the same-tick bite/spit interruption. Block and funded-avoid ripostes use
`NEGATE`/`REDUCE`/`AVOID` rows' existing `ticks` field: a nonzero value staggers the
attacker and releases the defender. This generic effect adds no move-id branch
or new status. Unfunded or rear blocks earn no stagger. All hits and defence
payments still use the shared snapshot; releasing guard does not remove other
same-tick blocks or erase a guard break already applied by another attacker.

Side hits gain 25% damage and rear hits 50%. Height advantage adds 10% per
metre, capped at 25%; being lower does not subtract damage. Damage variance is
uniform from 0.9 to 1.1 using only the hit RNG stream. Bleed deals 0.6 HP/tick
and refreshes its timer without stacking. Its source changes only when a hit extends the timer; equal-duration hits retain the first extending source. Slow halves walking speed. Water
multiplies walking speed by 0.6, halves permitted dash travel and blocks charge.
This is the minimal medium support for P2, not the swimming system of P6.

## Verbs and tick contract

| Verb | Standing-order behaviour |
|---|---|
| `approach id` | Walk and turn until the gap between bodies is <= 0.6 m. |
| `attack id move` | Close to 92% of move reach, align, wait for stamina if necessary, launch once, finish recovery. |
| `guard` | Raise guard once, finish recovery; a funded counter block releases it early. It uses current facing. |
| `dodge dir` | Dodge once; 0 is forward, then clockwise in 45-degree steps (2 right, 4 back, 6 left). |
| `flee id` | Turn and run away until body gap > 14 m or 50 walking ticks elapse. Sprint costs 0.5 stamina/tick for 1.25× speed when affordable. |
| `idle` | Stop issuing movement/new moves and recover stamina. |

Identical repeated orders do not restart a move or reset the flee timeout.
New orders queue behind committed moves; they do not cancel the current
wind-up/active/recovery. An interrupt/stun clears the move and standing order.
Missing/dead targets end a pending approach/attack/flee when it next plans.
Invalid orders leave state unchanged, including integer helper arguments that
would otherwise wrap into the byte-sized action fields. Death clamps HP to
zero, clears moves/statuses/orders, credits one kill and leaves an inert body.
There is no respawn or egg accounting in this module.

Each `cp_combat_step` executes the following fixed sequence:

1. Apply existing bleed damage and deaths.
2. Plan verbs for living, unstunned creatures in the idle phase: turn, walk or start a move.
3. Apply active dashes and all planned displacements; clamp each body to the 40×40 m arena by its own radius and separate bodies by the sum of their radii. The default radius is 0.6 m.
4. Gather hits and snapshot counter/flank/height evaluations. Mark explicit interrupt cancellations. Record each surviving hit's damage, status and defensive payment before applying outcomes. Dodge/guard payments consume a stamina copy in ascending attacker id (then defender id); scarce defence therefore favours the lower attacker id. Apply every landed hit, including full damage credit and status after another hit has crossed zero HP. Resolve each death once after the pass: the lowest-id attacker that landed positive damage on this tick gets the kill. Committed attacks can trade lethal hits; explicit interruption cancels the interrupted creature's same-tick hit.
5. Advance phases and decrement status timers; regenerate stamina where permitted. Increment the world tick and calculate its canonical hash.

A wind-up of W means the first hit frame is W ticks after the launch tick;
a completed move occupies W + active + recovery ticks. Status timers include
the application tick and decrement at its end. Thus a newly applied 8-tick
bleed has 7 subsequent damage ticks; it does not deal an extra immediate tick.
Stagger timers also advance at the end of the application tick. Events describe
the most recent tick only and cap at 64 entries.

Stamina regenerates after four ticks without spending, when the phase is idle:
1.6 points/tick stationary, 0.8 walking, none while sprinting, capped at the
profile's pool. Being stunned does not itself forbid regeneration. Optional
terrain is up to three smooth seeded hills; uphill walking slows down, with a
40% speed floor. Turning is limited to approximately 0.8 radians/tick.

## Replay and determinism

Use `CpCombatSetup` plus tick-sorted `CpCombatLogEntry` records (orders applied
before their tick) with `cp_combat_replay`. Persist the engine commit/version
alongside a saved setup/log; this API does not define a replay file container.
Hash outputs may be omitted when only the final hash is required.

FNV-1a 64 hashes explicit fields as little-endian bytes: seed, tick, counts,
three CpRng streams (terrain/spawn/hit), used hills and used creatures including
profiles, positions, phases, timers, orders and bookkeeping. Floats hash their
32-bit representations with signed zero canonicalized to zero. Padding, unused
slots, events and the cached hash are excluded. Altering a hit-stream state
changes the hash. Terrain generation cannot consume the spawn or hit stream.

Each profile carries `radius_cm`, an integer body radius in centimetres. Zero
and 60 both mean the literal `CB_RADIUS` (0.6 m). `60 * 0.01f` is not
bit-identical to that constant, so the default path uses the literal. The
canonical hash appends the centimetres as two little-endian bytes only when
the field is neither 0 nor 60. Default-radius profiles therefore keep the five
golden logs and their 50,000 hashes bit-identical. Any other value is clamped
to 40–400 cm and is part of the hash. Separation and flee-done use the sum of
the two radii. Reach and the centre-to-surface gap use the target's radius.
Dash contact uses the sum. Arena clamps use each creature's own radius, so a
larger body can still reach the boundary and flee.

Core arithmetic avoids transcendental library calls (cones use a polynomial);
only libc/libm is linked. The Makefile appends `-fno-fast-math` and
`-ffp-contract=off` with `override`, after user-supplied CFLAGS. Unit tests
compare 10,000 hashes against two replays of bot-generated logs for seeds
0, 1, 42, 987654321 and 4294967295.

`tests/golden/combat-<seed>.log` additionally stores five fixed action logs;
the adjacent `.hashes` files store all 10,000 expected per-tick hashes.
`tests/combat_golden.c` defines their eight-creature, mixed-medium, seeded-hill
setup, with 100,000 HP to keep combat running. Log files start with the seed,
then `tick id verb move target dir`. No-op orders were removed during capture,
with all original per-tick hashes checked unchanged. Golden comparisons use
only these committed orders, independently of future bot-policy changes.
`make test` launches a fresh production-linked replay process for each file
and compares every tick via `tests/test_combat_golden.py`. It never regenerates
fixtures. Unit tests also cover hash padding/outputs and RNG state.

Intentional replay contract changes require review and explicit regeneration:
`./build/combat_golden --record SEED tests/golden/combat-SEED.log tests/golden/combat-SEED.hashes`.
Do not regenerate to hide an unexplained regression. The fixtures also anchor
the WASM and JS checks described below; they were not changed for P3a.

The earlier balance pass changed 49,979 hashes while retaining the fixed
orders. This P2-gates revision deliberately changes **49,961 of 50,000 hashes**
again, because the move/counter rules below change combat outcomes. Before
refresh, `make test` failed at seed 0 tick 9: expected `b4b6fa8b5481e0cb`,
observed `fe0f781de76d693a`. All earlier ticks for that seed still matched.
Only the five `.hashes` files were refreshed using the production-linked runner:
`./build/combat_golden tests/golden/combat-SEED.log > tests/golden/combat-SEED.hashes`.
The five `.log` files remain byte-identical. This is a deliberate rules revision,
not a new hash layout, arithmetic contract or hidden fixture regeneration.
`make test` checks them in fresh processes; `make wasm-test` independently
checks every hash in WASM and through the JS wrapper.

## WASM build and parity (P3a)

Run from the repository root (Node, Python 3, a native C compiler and an existing
Emscripten SDK are required):

```sh
make wasm          # build/wasm/cpore_combat.mjs + cpore_combat.wasm
make wasm-parity   # C goldens in Node/WASM + native/WASM bot duels
make wasm-test     # parity plus the JS wrapper/profile/encounter tests
make test          # native-only; does not look for or invoke emcc
```

If `emcc` is absent from PATH, each WASM recipe sources
`~/emsdk/emsdk_env.sh` when present, otherwise prints an actionable error.
No SDK is downloaded. The module compiles only `core/src/combat.c`, `rng.c`,
`apps/combat_bots.c` and `apps/wasm_api.c`, with `-O2 -std=c99
-fno-fast-math -ffp-contract=off`. There are no SIMD flags. `MODULARIZE`,
`EXPORT_ES6`, `ENVIRONMENT=web,node` and an explicit export list make one
isolated world per module instance. Generated outputs stay under ignored
`build/wasm/`; missing companion `.wasm` files trigger rebuilding.

Rechecked for the final P2-gates rules with Emscripten 7.0.0 and Node 26.13.0 on Linux:

| Check | Exact coverage | Result |
|---|---|---|
| C golden runner compiled for WASM | Five committed logs × 10,000 ticks = **50,000 hashes** | Byte-identical to committed `.hashes` |
| Native vs WASM bot duels | **200 duels, 25,520 tick hashes** | Byte-identical streams, including duel lengths |
| Goldens through JS wrapper | Five logs, **50,000 tick hashes** | All match |
| Two independent JS/WASM instances | **600 ticks**, including seeded random-bot decisions | Hashes, states and events match |
| Encounter frame rates and native replay | **60 seconds at 60 and 37 FPS**, 600 ticks each | Identical orders and every hash; exported log matches native |

Duel coverage is all **25 ordered pairings** of idle, random, greedy, counter,
and spam, across **two profile sets** (default/default and spitter/tank), and
four seeds (0, 1, 42, 4294967295). Duels stop on death or after 600 ticks.
Spam uses bite/charge in set 0 and spit/guard in set 1. The runner prints
counts, so changed bot policies cannot silently inherit these measurements.
`tests/test_wasm_parity.py` compares full output, not just final hashes.

`tests/test_wasm_combat.mjs` also validates fixture documents with the existing
studio validator, checks every exported ABI size/offset, rejects malformed
inputs, exercises arbitrary continuous headings, and checks that walking waits
behind committed moves. Node's coverage runner measured 100% lines/functions
and >90% branches in each of the three engine modules:

```sh
node --test --experimental-test-coverage --test-coverage-exclude='build/**' \
  --test-coverage-exclude='web/studio/**' tests/test_wasm_combat.mjs
```

A headless Chromium 1254 smoke test served the repository over HTTP, imported
the ES modules, fetched WASM, and advanced an encounter ten ticks successfully.
It used only the required SwiftShader arguments. This is a module-loading
check; the walkable page and visual/human playtest remain P3b work. Balance acceptance is established separately by the tournament below; parity
checks determinism rather than balance.

### JS wrapper and C ABI

`web/engine/cpcombat.js` has no bundler or dependencies. Serve the repository
root over HTTP; its default dynamic import resolves to
`build/wasm/cpore_combat.mjs`, whose `.wasm` sits alongside it. Example:

```js
import { Combat, defaultProfile, VERB, MOVE } from './web/engine/cpcombat.js';
const combat = await Combat.create();
combat.reset({ seed: 42, flat: true, creatures: [
  { profile: defaultProfile(), x: 17, y: 20, fx: 1, team: 0 },
  { profile: defaultProfile(), x: 23, y: 20, fx: -1, team: 1 },
] });
combat.order(0, { verb: VERB.ATTACK, move: MOVE.BITE, target: 1 });
const hashHex = combat.step(); // fixed-width, lowercase 16-digit hash
```

`Combat.create(options)` forwards Emscripten options (including `locateFile`
or `wasmBinary` for other hosting arrangements). Each call creates separate
WASM memory. `reset` accepts 1–8 spawns, explicit seed, optional `flat`, and
profiles defaulting to the C baseline. Missing coordinates use seeded spawn;
missing facing is (0,0), normalized by C to +x. JS checks finite values and
integer levels before copying a complete setup into WASM. C applies its normal
profile/position clamps. `step`, `order`, `states`, `events`, `hash`, `preview`,
`botInit` and `botDecision` call the same C simulation and policy code as native.
Order rejection returns the existing negative C error code.

`apps/wasm_api.c` owns static storage: world, setup, bots, action and output
buffers. It allocates nothing. `cb_setup()` exposes `CpCombatSetup` memory;
`cb_reset()` validates it. `cb_layout()` exports ABI version 2, the setup,
spawn, profile and action sizes and every consumed offset, output strides,
limits, tick frequency and arena dimensions. `Combat` asserts all 39 metadata
values against `LAYOUT` before touching memory; a stale build fails on load.
The setup is 364 bytes, spawn 44, profile 24 and action 8. The extra profile
bytes are `radius_cm` (uint16 at offset 20). No JS code reads
padded world structs or serializes their raw bytes.

`stateView()` borrows a `Float32Array` with 17 values per creature:
`x,y,fx,fy,hp,stamina,move,phase,ptick,plen,stun,bleed,slow,alive,medium,team,verb`.
`eventView()` borrows five floats per event: `type,a,b,move,amount` (up to 64).
`states()` and `events()` return independent objects suitable for snapshots.
Borrowed buffers are scratch space; copy to retain them across queries.
`cb_hash()` exposes low/high u32 words; the wrapper preserves all 64 bits as
hex, without converting through a JS Number. `preview()` supplies cone origin,
facing, reach and full arc, plus the core's gap, reach/arc checks, flank,
height, counter, damage and effect. `botDecision()` returns a copied action or
null; it advances only that bot's policy state and does not issue the order.

## Studio parts to combat profile

`web/engine/profile.js` exports `profileFromStudio(creature, manifest)` and
one authoritative `PART_RULES` table. Pass the `cpore.creature/4` document
already validated by `web/studio/genome.js`, plus the parsed
`web/studio/parts.json`. Unknown ids/schemas are rejected. Rules match
**both `c_type` and category**, so new ids with the same semantics need no
new code. Each authored part contributes once (implicit mirrored geometry
contributes no extra level), summing each level and clamping it to 5.
Version 4 has no purchased-level field. Size, length, mesh bounds, skin,
legacy migration payload and procedural growth regions do not change part
levels. Spine nodes are read only for the quantised body radius below.
Part levels stay integer arithmetic; the radius reaches C as centimetres.

| Manifest c_type | Category | Integer contribution per authored part |
|---|---|---|
| CP4_MOUTH_C | mouths | mouth +2 |
| CP4_MOUTH_O | mouths | mouth +1, spit +1 |
| CP4_MOUTH_G | mouths | spit +2 |
| CP4_HORN | weapons | charge +1 |
| CP4_TAIL | weapons | tail +1 |
| CP4_PLATE | details | guard +1 |
| Anything else, including null | any | none |

The combat baseline is zero part levels, 100 HP, 100 stamina, 4 m/s and the
default body radius. After clamping, each guard level adds 5 HP. Part-level
arithmetic is integer arithmetic. `bodyRadiusCm` takes half the horizontal
footprint: the larger of the spine's forward span (`max z − min z`) and its
widest cross-section (`2 × max node radius`). That length is quantised to
centimetres and clamped to 40–400. Exactly 60 cm is stored as 0, which C
treats as the default and omits from the hash. Carnivore mouths specialize in bite; grazer mouths
project to ranged spit; omnivore mouths split between them. These are explicit
P3a combat rules, not abilities inferred from visual resemblance.

The manifest currently labels its mappings as candidates and its studio
output as cosmetic pending full C genome validation. This function projects
those **C-typed candidates into the existing C combat-profile struct only**;
it does not claim to validate a complete creature genome for game entry.
Parts with null C types (e.g. `sac_spitter`, `maza`, `tongue_spring`) grant
nothing; illustrative abilities are never read. Adding an ability for one
requires a C type and an explicit projection rule, rather than a mesh-name
exception. The fixtures under `tests/fixtures/combat/` pin a biter, spitter
and capped guard profile. Full C genome admission remains a separate gate
under DESIGN.md G4; the encounter accepts a combat setup, not a genome.

## Encounter controller contract

`web/engine/encounter.js` is rendering-free and has no DOM, clock or random
source. Construct `Encounter(combat, {point:{x,z}, setup, player:0, enemy:1,
enemyBot:3})` with exactly two distinct creature ids. The point is the arena
centre in valley metres. `toValley({x,y})` maps arena coordinates to
`{x: point.x+x-20, z: point.z+y-20}`; `toArena` is its inverse. There is no
rotation, scaling, terrain mutation or teleporting simulation state in JS.
The arena remains the core's local 40×40 metres.

Call `advance(deltaSeconds, intent)` each frame. A held intent has optional
`move:[x,y]` in arena/valley XZ, `attack:MOVE`, `guard`, `dodge:0..7` (or true
for forward), and `flee`. Priority is flee, dodge, guard, attack, movement,
then idle. A move vector is scaled by its largest absolute component and rounded
into signed int16 components (`hx`, `hy`, range -32767..32767); zero stops.
`CB_V_MOVE` (verb 6) uses `dir=-1` with `heading_x/y`. C normalises the
vector using `sqrtf(x*x+y*y)` under the same no-fast-math/no-contraction flags
as every other combat operation. No browser trig enters C. The standing order
hash appends the two int16 components, little endian, **only while a vector
MOVE is used**. Other orders clear them. Legacy `dir=0..7` remains a replay
compatibility path, using the original literals and serialization. The five
fixed logs and their 50,000 hashes are unchanged. Dodge still uses its existing
facing-relative octants. Movement waits behind committed moves and stun and
uses normal terrain/water/slow speed, collisions and stamina recovery.

The action ABI appends int16 heading fields at offsets 4 and 6; `cb_order`
accepts `(id,verb,move,target,dir,hx,hy)` and validates before narrowing.
10,000 seeded random signed int16 headings compare every native/WASM tick,
including full replay equality. The JS 60/37 Hz timeline also uses arbitrary
headings and replays its complete exported log in native C.

The accumulator advances at exactly 10 Hz and never drops ticks, even for a
long frame. Finite nonnegative deltas are required; pause by withholding
`advance`, rather than injecting elapsed pause time. For prerecorded input,
pass a sampler `(tickTimeSeconds, tick) => intent` instead of a held object.
It is sampled at `tick/10` before each tick, so the same timeline remains
identical even when a frame crosses several tick boundaries. Live held
objects apply to all ticks consumed by that frame; input transition times
must be captured in a timeline if exact cross-FPS playback is required.
This distinction avoids promising that differently sampled live input is
identical. The 60/37 FPS test uses the same time-indexed script and compares
all accepted orders and hashes.

For each tick the player order is applied first, then the C enemy bot observes
and optionally orders, then C steps. `lastOrderError` exposes a rejected player
order. `previous` and `current` are independent tick-state snapshots; render
between them using `alpha` in [0,1), giving the usual one-tick interpolation
latency. UI code may query core previews/events separately. The controller
continues ticking inert dead creatures until its caller stops advancing;
it implements no respawn, nest or other stage consequences.

`log` records every accepted player and bot order (including accepted no-ops),
in tick/application order. `hashes` records every resulting tick hash.
`exportLog()` returns this text format with the original complete setup:

```text
CPORE_COMBAT_LOG 2
seed n flat ticks
mouth charge spit tail guard hp stamina speed x y fx fy medium team radius_cm
... one spawn line per creature ...
tick id verb move target dir hx hy
... accepted actions in application order ...
```

Version 1 logs (six action columns) remain accepted; version 2 has eight.
Replay with `build/combat_parity --replay encounter.log`; it parses the setup
and calls `cp_combat_replay`, printing one hash per tick. The test harness
supports up to 10,000 ticks and 80,000 orders; it does not reconstruct or run
bots during replay. Save the engine commit/version alongside logs, as with
the existing golden format. The renderer and walkable stage belong to P3b;
no files in `web/hero/`, `tools/hero/`, `art/reference/` or DESIGN.md changed.

## Profiles and timing rationale

The published baseline is 100 HP and 100 stamina. Brawler, spitter, skirmisher
and allrounder share those pools: their differences come from equipment and
movement, rather than hidden durability compensation. The armoured tank has
120 HP and 3.4 m/s speed: 20% more health for 15% less speed than the 4 m/s
baseline. Brawler moves at 3.8 m/s with heavy mouth/charge equipment; spitter
at 4.2, skirmisher at 4.6 with no guard, and the generalist at 4.0. These are
round, readable archetype choices, fixed before measuring the revised gate.
They are not calibrated HP pools. Part budgets are not equal; this tournament
measures these reference archetypes, not every possible genome.

| Build | Mouth | Charge | Spit | Tail | Guard | HP | Stamina | Speed m/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| brawler | 4 | 3 | 0 | 1 | 1 | 100 | 100 | 3.8 |
| spitter | 2 | 0 | 4 | 0 | 1 | 100 | 100 | 4.2 |
| tank | 2 | 1 | 0 | 3 | 4 | 120 | 100 | 3.4 |
| skirmisher | 3 | 0 | 2 | 2 | 0 | 100 | 100 | 4.6 |
| allrounder | 3 | 2 | 2 | 2 | 2 | 100 | 100 | 4.0 |

### Structural diagnosis (P2-gates, before tuning)

The inherited failures have two distinct causes. A repeated non-damaging
verb is not a complete strategy in a damage game: blind dodge cannot have a
positive raw payoff, so an offensive row can dominate it. A defensive move
must be measured with the attack opportunity it actually earns, paid through
the public API, not with invented block/evade damage. Holding guard outside
bite range also wastes a successful block's short punish window. Policies
should close to punish range and use a visible defensive read before taking
an affordable, aligned bite during a genuinely helpless window. All offensive
policies retain their own selected attack and ranged spacing.

The table also needs a costed counter to that defensive read: tail sweeps
catch active dodge, while other funded avoids may release the defender and
stagger an overcommitted attacker. This creates a possible cycle through
guard > bite, charge > guard, spit > charge, dodge > spit, tail > dodge;
measurements must establish the actual cycle and support, not assume it.
In an antisymmetric game, generic nondegenerate support is odd, so the
unchanged four-move threshold practically asks for five viable policies.

Review of 7a3204b: retain the generic AVOID ticks mechanism and real punish
idea, but verify its boundaries and correct approach/turn assumptions.
Review of 05c7d5c: restore the published **mean** stamina coefficient; the
unjustified minimum exchange rate is rejected. Retain reaction delays 0..3
as an explicit scenario factor and test tail's dodge exception independently.
Dominance tolerance, regret iterations/support, build caps and canaries stay
unchanged. Fixed action logs are not policy training data and remain intact.

Wind-ups retain the 0..3-tick reaction budget: bite can interrupt spit's
same-tick active hit, spit can interrupt charge before its active phase, and
charge can visibly commit to break a 14-tick guard. Dash travel remains
1 m per active frame. Neither move data nor profiles have seed-, build-identity-
or matrix-cell-specific exceptions.

### Final rule changes and reasoning

Relative to the table before this branch (39e2a0a):

| Data | Before → final | Role and cost |
|---|---|---|
| bite damage | 10 → 11 HP | A fast punish also competes with the slower sweep. Guard still negates it; bleed remains eight ticks. |
| charge damage | 34 → 30 HP | Breaking guard remains consequential, while charge no longer suppresses bite's role. Wind-up, stun, travel and stamina stay unchanged. |
| spit damage; slow | 14 → 13 HP; 12 → 20 ticks | Reduce spitter's field strength while preserving room to retreat between shots and the existing ranged exchange regression. |
| tail damage; guard multiplier | 16 → 17 HP; 0.40 → 0.25 | Sweep punishes evasion, but funded frontal guard earns a positive raw tail matchup after paying for its follow-up. |
| tail vs active dodge | avoid → full hit, 3-tick interrupt | A sweep catches evasion, so defensive reads have a counter. The existing ordered rule mechanism implements this. |
| dodge start; funded avoid stagger | 3 → 20 stamina; 0 → 5 ticks | Dodge is a real resource commitment. Funded avoidance releases dodge and grants application tick + bite wind-up + hit = five ticks, exactly the existing block punish budget. The per-hit payment, distance and duration stay unchanged. |

No reference build equipment, HP, stamina pool or speed changed. Twenty-point
dodge prevents cheap evasion savings from dominating the resource game. Trials
moving its cost onto avoided hits left three-move games. Increasing start cost
alone passed the tournament but broke the ranged regression; that candidate
was rejected. Longer spit slow preserves its range role, while the small
attack/guard adjustments establish the final measured cycle. At 7 m, spit now
beats bite by +15.83 HP in the existing 80-duel regression; at 1.6 m it loses
by -65.46 HP. Both signs remain asserted.

The five-tick avoid/block stagger is minimal: after its application tick, a
bite launched on the next tick hits on the last helpless frame. Failed or
unfunded defence earns no release or stagger. Tail's catch is anticipatory:
reacting with a three-tick tail only after observing a one-tick dodge cannot
guarantee active-phase contact. Its reactive execution row is zero at every
delay; pinned active-phase tests separately verify full damage, slow and
interruption. Other execution rows are avoid 1/1/1/0 (bite; charge/spit allow
all four delays), charge/guard 1/1/1/1, bite/guard and tail/guard 1/1/1/0,
spit/charge and bite/spit 1/1/1/1.

### Policy game and uncertainty

Literal repeated non-damaging verbs cannot value defence in a damage matrix:
a dodge-only row is nonpositive against every row. The gate therefore compares
**implementable move policies**, including defence's actual continuation.
Guard closes to bite launch range, raises guard, then bites only during a safe
window. Dodge approaches, reads an avoidable visible threat, evades forward,
then takes the same funded bite opportunity. It does not dodge the tail
exception. Its dash read estimates contact during charge's active travel,
rather than assuming the first active frame hits a distant target.

A defensive bite requires current launch reach, close alignment, enough
stamina, no pending enemy hit or active counter, and at least four remaining
locked ticks. Approximate walk/turn estimates were removed from the inherited
policy: they did not guarantee the promised punish. The bite uses public
orders, ordinary damage/bleed and stamina, and completes recovery. A visible
recovery window can also be punished. No artificial damage or score is awarded
for blocking, dodging or waiting. Offensive policies repeat their chosen
attack with shared ranged spacing. This measures real continuations, rather
than relabelling stamina savings as damage, and applies equally to G53's
future moves. Tests cover exact safe boundaries, refusal of short windows,
walk-in, turn or unfunded bites, scarce simultaneous payments and rear bypass.

`make tourney` runs 400 duels per ordered move cell (14,400 total), 120 ticks
at 7 m, all parts L3, 100 stamina, 4 m/s and 100,000 HP to avoid damage censoring.
Each independent scenario has two reversed seats at one seed, with start lags
cycling 0..3 and 0..6, and both reaction delays cycling 0..3. Odd duel counts
round up to complete a pair. Standard errors use sample variance of independent
**seat-pair means**; correlated seats are not independent observations.
Antisymmetry, including zero diagonal, is regression-tested.

Raw payoff is damage dealt minus received. Resource payoff subtracts the
row's stamina-spend margin times the unchanged mean offensive exchange formula:

`K = ((15.4 + 7*0.6)/10.8 + 42/21.6 + 18.2/14.4 + 23.8/12) / 4`
`  = 1.751620 HP/stamina` (printed from float32 move data).

This is a nominal L3 damage/start-cost exchange rate, not an exact value of
stamina in every state. It is never fitted to dominance or the solver.
Both games independently require no weak dominance at
`2*max(SE_a, SE_b) + 0.5 HP`. Each uses 200,000 regret-matching iterations
and requires >=4 moves at >=1% weight, excluding initialization dust.
A synthetic five-action cycle checks the solver independently of measured
balance. Dodge beats spit in raw play and enters the resource mix; tail beats
dodge in both games and enters the raw mix. These finite policy games do not
prove balance across every genome, starting distance or possible strategy.

The field protocol remains all 16 ordered idle/random/greedy/counter pairs,
all 25 ordered build pairs, 40 seeds per cell (16,000 duels), 12 m starts and
a 900-tick cap. Death wins; timeout HP fraction needs more than a one-percentage-
point lead, otherwise a draw scores 0.5. Idle must score zero on both seats
(draws fail). Random must score <5% on both seats against greedy and counter.
This measured tolerance does not establish DESIGN.md's stronger literal
never-win wording. Correctness tests also use their existing independent seeds.

All nine random/greedy/counter pairings enter build pooling with equal weight
and both build perspectives. Same-build cells are diagnostic; field means
against the other four builds must be <=65%, every pooled ordered pair <=90%.
Elo is descriptive: Bradley–Terry fit, mean 1000, one half-win pseudo-game per
pair. No acceptance threshold changed. Future P4 B1–B3 inherit these games,
tolerance, stamina formula and support gate; B4/B7 inherit both build caps,
B5/B6 add surprise/resource checks and B8 prints Elo. This pass does not claim
that the future seven-move gates already pass.

### Held-out confirmation

An earlier offset-1,000,000 validation exposed a 65.5% field mean and, after
an intermediate damage change, a 5.2% random canary score. That set became
development data. After committing the final combat table, the fresh run was:

```sh
nice -n 10 ./build/combat_tourney 160 1600 3000000
```

Offset 3,000,000 was unused in tuning. It supplies 64,000 field duels and
57,600 payoff duels, four times each default sample count. Payoff seeds are
3,001,000..3,001,799; field seeds 3,005,001..3,069,000. Default payoff seeds
are 1,000..1,199 and field seeds 5,001..21,000. Start/reaction factors, duration,
policies and all gates are identical. Full stdout is committed in
[p2-heldout.txt](evidence/combat/p2-heldout.txt).

| Check | Default | Fresh held-out |
|---|---:|---:|
| Raw dominance relations | 0 | 0 |
| Resource dominance relations | 0 | 0 |
| Raw support at >=1% | 5/6 | 5/6 |
| Resource support at >=1% | 5/6 | 5/6 |
| Worst field mean | 62.3% | 62.1% |
| Worst pooled pair | 72.2% | 73.3% |
| Worst random score vs greedy, either seat | 4.45% | 4.10% |
| Worst random score vs counter, either seat | 1.45% | 1.34% |
| Idle wins or draws vs active bots | 0 | 0 |

Held-out mixes in move order bite/charge/guard/spit/tail/dodge:
raw **1.6/8.3/2.4/23.8/63.9/0.0%**;
resource **17.8/29.9/11.5/11.1/0.0/29.7%**.
Both pass the unchanged support and dominance rules. Held-out matrices and
standard errors:

```text
-- raw: row's damage dealt minus column's (hp)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00       -2.01     -136.58      -14.25       10.65      106.69       -5.92
charge              2.01        0.00      151.51     -117.49       37.94        0.00       12.33
guard             136.58     -151.51        0.00      -90.54       49.14        0.00       -9.39
spit               14.25      117.49       90.54        0.00      -19.20      -57.05       24.34
tail_strike       -10.65      -37.94      -49.14       19.20        0.00       49.31       -4.87
dodge            -106.69        0.00        0.00       57.05      -49.31        0.00      -16.49

-- resource-adjusted: raw minus 1.751620 hp per stamina point the row spent, plus the same for the column
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00      -46.70     -178.61       65.97      -41.24       91.77      -18.13
charge             46.70        0.00      131.25     -165.69       63.16      -16.82        9.77
guard             178.61     -131.25        0.00      106.79       91.01      -14.71       38.41
spit              -65.97      165.69     -106.79        0.00     -110.45      -85.97      -33.91
tail_strike        41.24      -63.16      -91.01      110.45        0.00       26.19        3.95
dodge             -91.77       16.82       14.71       85.97      -26.19        0.00       -0.08

-- raw standard errors (independent seat-pair means)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00        0.24        0.15        0.76        0.28        3.40        0.81
charge              0.24        0.00        0.12        1.05        0.24        0.00        0.28
guard               0.15        0.12        0.00        0.12        0.22        0.00        0.10
spit                0.76        1.05        0.12        0.00        1.48        0.29        0.62
tail_strike         0.28        0.24        0.22        1.48        0.00        0.19        0.40
dodge               3.40        0.00        0.00        0.29        0.19        0.00        0.65

-- resource standard errors (independent seat-pair means)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00        0.38        0.17        0.83        0.30        2.14        0.64
charge              0.38        0.00        0.13        1.46        0.24        0.00        0.37
guard               0.17        0.13        0.00        0.35        0.25        0.00        0.15
spit                0.83        1.46        0.35        0.00        1.41        0.22        0.71
tail_strike         0.30        0.24        0.25        1.41        0.00        0.19        0.40
dodge               2.14        0.00        0.00        0.22        0.19        0.00        0.43
```

### Stage calibration

The changed combat rules require recalibrating only Garfio's species data;
the three player fixtures, their projections, the scripted player policy and
the 35–80% acceptance window stay unchanged. Garfio is now a small, fast
predator: mouth/spit/tail L2, no charge or guard, 90 HP, 20 stamina and
5.5 m/s. Its short stamina pool permits individual attacks but forces pauses
between commitments. The studio geometry is uniformly scaled by 5/12,
including leg offsets and part dimensions, so its visible body and projected
50 cm collision radius agree rather than hiding a radius override.

`nice -n 10 node tests/stage_winnability.mjs` runs the actual stage simulation
and C/WASM combat over the unchanged seeds 0..49 for each player fixture:

| Player fixture | Victories / 50 | Win rate | Deaths | Unfinished / fled |
|---|---:|---:|---:|---:|
| biter | 21 | 42% | 29 | 0 / 0 |
| guard | 29 | 58% | 21 | 0 / 0 |
| spitter | 38 | 76% | 12 | 0 / 0 |

Every fixture remains within the required window and every fight finishes
within 900 ticks. This calibrates the fixed scripted policy, not human
difficulty. The browser polish test also honours the same optional
`CPORE_STAGE_URL` and `CPORE_STAGE_EVIDENCE` settings as the stage play test,
allowing isolated local runs without overwriting reviewed screenshots.

### Final default tournament output

GCC 16.2.1, x86-64 Linux, 2026-11-15. `make tourney` exits 0.
Full stdout is also in [p2-default.txt](evidence/combat/p2-default.txt).

```text
cpore combat tourney  (tick 10 Hz, seeds/cell 40, payoff duels/cell 400)

seed offset 0 (payoff base 1000; field base 5000)

== Move-vs-move payoff, 400 duels per cell: move policies, 7 m apart,
   paired seats and start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)
   guard closes and blocks; dodge reads contact; both take funded bite punishes; ranged moves space

-- raw: row's damage dealt minus column's (hp)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00       -2.81     -136.44      -14.50       11.01      104.94       -6.30
charge              2.81        0.00      151.24     -117.28       37.63        0.00       12.40
guard             136.44     -151.24        0.00      -90.55       49.25        0.00       -9.35
spit               14.50      117.28       90.55        0.00      -19.07      -56.88       24.40
tail_strike       -11.01      -37.63      -49.25       19.07        0.00       48.95       -4.98
dodge            -104.94        0.00        0.00       56.88      -48.95        0.00      -16.17

-- resource-adjusted: raw minus 1.751620 hp per stamina point the row spent, plus the same for the column
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00      -47.64     -178.51       65.72      -40.88       93.26      -18.01
charge             47.64        0.00      130.99     -165.48       62.85      -16.82        9.86
guard             178.51     -130.99        0.00      106.89       90.75      -14.71       38.41
spit              -65.72      165.48     -106.89        0.00     -110.32      -85.83      -33.88
tail_strike        40.88      -62.85      -90.75      110.32        0.00       25.83        3.91
dodge             -93.26       16.82       14.71       85.83      -25.83        0.00       -0.29

-- raw standard errors (independent seat-pair means)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00        0.43        0.35        1.49        0.57        6.69        1.59
charge              0.43        0.00        0.26        2.12        0.52        0.00        0.55
guard               0.35        0.26        0.00        0.24        0.41        0.00        0.21
spit                1.49        2.12        0.24        0.00        2.99        0.59        1.24
tail_strike         0.57        0.52        0.41        2.99        0.00        0.41        0.82
dodge               6.69        0.00        0.00        0.59        0.41        0.00        1.28

-- resource standard errors (independent seat-pair means)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00        0.81        0.39        1.64        0.61        4.27        1.29
charge              0.81        0.00        0.27        2.94        0.52        0.00        0.76
guard               0.39        0.27        0.00        0.70        0.46        0.00        0.30
spit                1.64        2.94        0.70        0.00        2.84        0.45        1.43
tail_strike         0.61        0.52        0.46        2.84        0.00        0.41        0.81
dodge               4.27        0.00        0.00        0.45        0.41        0.00        0.85

== Dominance check (tolerance 2*SE + 0.5 hp)
-- raw matrix (acceptance gate)
   no move weakly dominates any other
-- resource-adjusted matrix (acceptance gate)
   no move weakly dominates any other
   raw equilibrium mix (regret matching, 200k iters), game value 0.00:  bite 1.8%  charge 8.0%  guard 2.7%  spit 24.1%  tail_strike 63.3%  dodge 0.0%
  PASS  raw equilibrium uses >=4 moves at >=1% weight (observed 5/6)
   resource equilibrium mix (regret matching, 200k iters), game value 0.00:  bite 17.6%  charge 29.9%  guard 11.7%  spit 11.3%  tail_strike 0.0%  dodge 29.5%
  PASS  resource equilibrium uses >=4 moves at >=1% weight (observed 5/6)
  PASS  no move weakly dominates another (raw damage payoff)
  PASS  no move weakly dominates another (resource-adjusted payoff)

== Strategy round robin: 5 profiles x 5 profiles x 40 seeds per ordered pair, both sides, 900-tick cap
   score of row against column (win = 1, draw = 0.5), pooled over all profile pairings

row \ col       idle    random    greedy   counter
idle           0.500     0.000     0.000     0.000
random         1.000     0.462     0.044     0.015
greedy         1.000     0.959     0.503     0.312
counter        1.000     0.987     0.684     0.507

== Elo (strategies; max-likelihood fit with one pseudo-game per pair, mean 1000)
   counter       1696
   greedy        1557
   random        1003
   idle          -257

== Canaries (both seats; draw = half a score, reported separately)
  PASS  idle scores zero vs random on BOTH seats (draws fail)
   idle left vs random  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs greedy on BOTH seats (draws fail)
   idle left vs greedy  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs counter on BOTH seats (draws fail)
   idle left vs counter score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  random scores <5% vs greedy on BOTH seats
   random left vs greedy  score 0.0445 draws 5/1000; random right score 0.0415 draws 3/1000
  PASS  random scores <5% vs counter on BOTH seats
   random left vs counter score 0.0145 draws 3/1000; random right score 0.0130 draws 2/1000

== Full build pairwise tables (row score; both seats pooled, draws = 0.5)

   random vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.613       0.406       0.512       0.469
   spitter            0.388       0.500       0.500       0.362       0.450
   tank               0.594       0.500       0.500       0.569       0.669
   skirmisher         0.487       0.637       0.431       0.500       0.644
   allrounder         0.531       0.550       0.331       0.356       0.500

   random vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.025       0.037       0.019       0.212       0.037
   spitter            0.075       0.006       0.013       0.119       0.025
   tank               0.013       0.000       0.000       0.131       0.050
   skirmisher         0.025       0.013       0.013       0.025       0.025
   allrounder         0.019       0.037       0.000       0.138       0.019

   random vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.006       0.000       0.037       0.031       0.037
   spitter            0.013       0.031       0.000       0.031       0.000
   tank               0.025       0.025       0.000       0.000       0.013
   skirmisher         0.025       0.000       0.000       0.000       0.050
   allrounder         0.000       0.000       0.000       0.000       0.019

   greedy vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.975       0.925       0.988       0.975       0.981
   spitter            0.963       0.994       1.000       0.988       0.963
   tank               0.981       0.988       1.000       0.988       1.000
   skirmisher         0.787       0.881       0.869       0.975       0.863
   allrounder         0.963       0.975       0.950       0.975       0.981

   greedy vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.000       0.975       1.000       0.381
   spitter            1.000       0.500       1.000       1.000       1.000
   tank               0.025       0.000       0.500       1.000       0.013
   skirmisher         0.000       0.000       0.000       0.500       0.500
   allrounder         0.619       0.000       0.988       0.500       0.500

   greedy vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.000       0.963       0.000       0.400
   spitter            0.212       0.500       0.000       1.000       1.000
   tank               0.062       0.000       0.500       0.000       0.013
   skirmisher         0.000       0.000       0.000       0.500       0.500
   allrounder         0.694       0.000       0.000       0.500       0.500

   counter vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.994       0.988       0.975       0.975       1.000
   spitter            1.000       0.969       0.975       1.000       1.000
   tank               0.963       1.000       1.000       1.000       1.000
   skirmisher         0.969       0.969       1.000       1.000       1.000
   allrounder         0.963       1.000       0.988       0.950       0.981

   counter vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.787       0.938       1.000       0.306
   spitter            1.000       0.500       1.000       1.000       1.000
   tank               0.037       1.000       0.500       1.000       1.000
   skirmisher         1.000       0.000       1.000       0.500       0.500
   allrounder         0.600       0.000       0.988       0.500       0.500

   counter vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.662       0.938       0.000       0.381
   spitter            0.338       0.500       0.000       1.000       1.000
   tank               0.062       1.000       0.500       0.000       0.025
   skirmisher         1.000       0.000       1.000       0.500       0.500
   allrounder         0.619       0.000       0.975       0.500       0.500

== Build scores pooled over ALL nine strategy pairings
   row / col        brawler     spitter        tank  skirmisher  allrounder  field mean
   brawler            0.500       0.446       0.693       0.523       0.444       0.526
   spitter            0.554       0.500       0.499       0.722       0.715       0.623
   tank               0.307       0.501       0.500       0.521       0.420       0.437
   skirmisher         0.477       0.278       0.479       0.500       0.509       0.436
   allrounder         0.556       0.285       0.580       0.491       0.500       0.478

== Elo (builds, all strategy pairings, both seats)
   brawler         1015
   spitter         1070
   tank             965
   skirmisher       964
   allrounder       987
  PASS  no build field mean exceeds 65% (worst 62.3%)
  PASS  no pooled build pair exceeds 90% (worst 72.2%)

tourney checks passed
```
