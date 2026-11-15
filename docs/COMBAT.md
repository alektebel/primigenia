# Creature combat core (P2)

`core/include/cpore/combat.h` and `core/src/combat.c` implement the standalone
creature combat simulation described in DESIGN.md G16 and Q24/Q31/Q50/Q52.
The old land stage is unchanged. Pack orders, nest/egg consequences and Cognition
integration belong to later phases (G18/G23/G36); this module supplies their
movement/combat foundation, not those stage systems.

**Review status:** correctness regressions pass; balance acceptance still fails.
Guard earns a real riposte, spaced spit beats bite from 7 m, and the maximum
build field mean is now 62.4% (brawler 50.9%). Both matrices still have one
weak-dominance relation, and each equilibrium uses only three moves. This is
the best configuration retained from this pass, not P2 acceptance or proof that
the requested targets are impossible. Native/WASM parity is verified by P3a below; the human playtest
remains pending.

## Move data

`CP_COMBAT_MOVES` is the authority. One tick is 0.1 seconds. Costs and damage
below are level 1; reach is attacker centre to target surface, except a dash's
reach is its total travel distance. Arcs are full cone widths in radians.

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags / required part |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| bite | 3 | 1 | 2 | 1.8 | 1.00 | 9 | 10 | bleed (8) | mouth |
| charge | 10 | 5 | 2 | 5.0 | 0.70 | 18 | 34 | stun (6) | dash, ground only / charge |
| guard | 1 | 14 | 2 | 0 | 2.40 | 1 | 0 | none | self, frontal guard / guard |
| spit | 6 | 1 | 4 | 6.0 | 0.25 | 12 | 14 | slow (12) | ranged / spit |
| tail_strike | 3 | 2 | 4 | 2.2 | 1.60 | 10 | 16 | slow (15) | sweep / tail |
| dodge | 1 | 3 | 2 | 2.2 | 0 | 3 | 0 | none | self, directional dash, evade / always available |

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
| any attack | dodge / active | Avoid the hit and status, paying 2 additional stamina per avoided hit. If unaffordable, the hit lands normally. |
| charge | guard / active | Break guard, deal 60% damage, drain up to 20 stamina, stagger for 5 ticks; charge's stun also applies. |
| bite | guard / active | Negate damage and bleed; block cost is incoming damage × 0.10 / guard factor. On success release guard and stagger the attacker for 5 ticks. |
| tail_strike | guard / active | Deal 40% damage, suppress slow; block cost is incoming damage × 0.10 / guard factor. On success release guard and stagger the attacker for 5 ticks. |
| spit | charge / wind-up | Interrupt charge and its order, deal normal damage/slow, stagger for 6 ticks. |
| bite | spit / wind-up or active, centre-to-surface gap <= 2 m | Interrupt spit (including its same-tick hit), deal 125% damage and bleed, stagger for 4 ticks. |

The guard factor is `1 + 0.15 * (guard_level - 1)`. An exhausted block fails,
sets stamina to zero and stuns for 6 ticks. Active dodge is checked first.
The test-only `CP_COMBAT_TEST` build exposes `cp_combat_test_hit_variance`: enabling it fixes the damage roll at exactly 1.0 while still consuming the normal RNG draw. It is absent from production libraries and tournament builds. Exact damage tests cover charge 60%, tail 40%, rear 1.5× and the height cap.

The tests exercise every row independently, including stamina failure paths,
rear guard bypass and the same-tick bite/spit interruption. Block ripostes use
`NEGATE`/`REDUCE` rows' existing `ticks` field: a nonzero value staggers the
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

This balance pass deliberately refreshed **only the five `.hashes` files**,
using the existing fixed `.log` orders with the production-linked replay:
`./build/combat_golden tests/golden/combat-SEED.log > tests/golden/combat-SEED.hashes`.
49,979 of the 50,000 hashes changed. The pre-refresh test failed at seed 0, tick 0:
`e02d490b5e2b2b44` became `221cf685db942e91`; that log raises guard at tick 0,
so the new start cost immediately changes hashed stamina. Move durations,
damage, statuses and ripostes then change later states. Action logs remain
byte-identical; new bot policies are exercised separately by generated-log
replay tests. `make test` passed after this explicit refresh.

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

Verified with Emscripten 7.0.0 and Node 26.13.0 on Linux:

| Check | Exact coverage | Result |
|---|---|---|
| C golden runner compiled for WASM | Five committed logs × 10,000 ticks = **50,000 hashes** | Byte-identical to committed `.hashes` |
| Native vs WASM bot duels | **200 duels, 22,432 tick hashes** | Byte-identical streams, including duel lengths |
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
check; the walkable page and visual/human playtest remain P3b work. Existing
P2 balance failures remain open; parity does not establish balance acceptance.

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

Wind-ups follow the counter table over reaction delays 0..3, rather than a
single bot setting. Bots observe between ticks, so delay 0 and 1 both first
see a launched move at tick 1. Bite's 3-tick wind-up can meet spit's 6-tick
wind-up even at delay 3: bite interrupts an active spit, cancelling its
same-tick hit. Spit's 6 ticks fit strictly before charge's 10-tick wind-up at
delay 3. Guard lasts 14 active ticks, enough to visibly commit and be broken
by charge at all four delays. Charge's five active frames move 1 m/frame,
below the 1.2 m body diameter, so contact cannot step over a nearby defender.
The table above contains the balance pass changes. Every numerical change
from the previous committed table is accounted for here:

| Data | Previous → retained | Reason |
|---|---|---|
| bite damage; bleed | 11 → 10 HP; 15 → 8 ticks | Reduce the unconditional bite/bleed throughput that produced a pure-bite raw equilibrium. An 8-tick bleed supplies seven future ticks and still rewards landing a fast punish. |
| bite recovery | 3 → 2 ticks | After a riposte it can raise guard for the next 3-tick bite wind-up, rather than being hit while still committed to recovery. Wind-up/active stay 3/1. |
| block stagger | 0 → 5 ticks on bite and tail rows | Application tick + bite wind-up + active = `1 + 3 + 1`. A guarder launches on the following tick and hits on the last helpless tick; the attacker becomes free immediately afterward. Four ticks would allow it to act on the hit tick. Tests assert both boundaries; no extra safety padding. Reach, facing and stamina still constrain the follow-up. |
| guard start; block coefficients | 5 → 1 stamina; bite 0.35 → 0.10, tail 0.30 → 0.10 | Raising, blocking and then paying for an actual bite formerly exhausted guard before the attacker. Make the defensive commitment affordable without making blocks free. Exhaustion and charge's 20-point break drain remain meaningful. |
| spit damage; slow; recovery | 8 → 14 HP; 8 → 12 ticks; 5 → 4 ticks | Pay for a long ranged wind-up with a stronger hit and time to retreat after contact. Twelve slow ticks cover its remaining recovery and an initial spacing step; the shorter recovery frees the spitter before the gap collapses. Bite still interrupts it at close range. |
| charge damage; recovery | 17 → 34 HP; 4 → 2 ticks | Reward a successful, long telegraphed commitment and make breaking guard consequential. Its 10-tick wind-up, contact travel and vulnerability to spit remain; the retained matrix has charge beating guard but losing to spit. |
| tail damage; arc | 10 → 16 HP; 2.40 → 1.60 rad | Give the slower sweep competitive contact damage against bite and spit, while allowing lateral movement to escape its narrower cone. It retains greater reach and a wider arc than bite, two active frames, slow and multi-target hits. |
| dodge active; recovery; start; avoidance payment | 2 → 3 ticks; 3 → 2 ticks; 8 → 3 stamina; 6 → 2 stamina/hit | Keep the six-tick commitment, shift one frame into evasion, and reduce the double start/avoid tax. Counter-picker reads the payment from the rule table. This improves practical defence but overvalues dodge against bite in the resource matrix; that failure is reported. |

No profile equipment, speed, HP or stamina pool changed. Values were tested
against the same protocol and thresholds; they are not conditional on seed,
profile identity or tournament cell.

The bot tests launch real orders, observe the resulting state, call the picker
and step until contact. They isolate the equipment needed by each row; the
full tournament uses the complete profile equipment and default delay 2.
A dodge can avoid through displacement as well as the avoid rule; pinned
active-phase unit tests separately assert the avoid payment for every attack.
This table is printed by the unit test (row order is `CP_COMBAT_COUNTERS`):

```text
  counter execution (reaction delays 0..3; 1 = executed):
    row 0: 1 1 1 0
    row 1: 1 1 1 1
    row 2: 1 1 1 0
    row 3: 1 1 1 0
    row 4: 1 1 1 1
    row 5: 1 1 1 1
```

Row 0 is dodge against **every** offensive move: bite/tail require delay <=2;
spit/charge permit all four delays. Rows 2/3 (guard vs bite/tail) likewise
require <=2. Row 1 is charge breaking guard; rows 4/5 are spit interrupting
charge and bite interrupting spit. Those three rows work at every tested
delay. The picker honours the active-phase exception for bite and the
close-range constraint; guard reduction is preferred over dodge for tail.
Out-of-range, facing, commitment, equipment and stamina can still prevent a
counter; these timing windows assume an idle, aligned, funded reactor at
1.6 m. They are not a guarantee from every world state.

Greedy scores expected damage per committed tick. It credits only
`max(0, (new_timer - 1) - remaining_damage_ticks)` future bleed ticks, and only
when the timer grows. Counter-picker falls back to greedy when it cannot
counter. Random picks legal attacks, movement, defence or rest without an
opponent model. Idle issues no orders.

Greedy and counter fallback step back with `flee` when a selected ranged move
has less than 85% of its reach in space (5.1 m for spit); they re-evaluate each
idle tick and use a sideways dodge toward room at a wall (0.5 m margin outside
body radius). This leaves a band below the public attack launch threshold of
92% reach. A selected shot stays committed through turning/approach until it
launches, avoiding retreat/turn oscillation while the enemy walks closer.
Busy smart/fixed policies retain their current move. These policies use only
public orders and no build identity. Tests verify retreat, firing, and a shot
against a real chase; 80 paired-seat exchanges give spit -11.91 HP at 1.6 m
and +19.19 HP at 7 m. The full payoff protocol below gives +18.30 HP at 7 m.

## Tournament protocol and measured results

`make tourney` runs 40 seeds per ordered strategy/profile cell and 400 payoff
duels per move cell. Acceptance is still open: the revised tournament may fail
and exits 1 on failure. `make test` checks simulation correctness, canaries,
and acceptance arithmetic with synthetic fixtures; it does not claim that
balance acceptance has passed. Both commands must be checked before merging.
This separation lets correctness remain green while exposing design failures.

The strategy protocol runs 16,000 duels over idle/random/greedy/counter and all
ordered build pairs, 12 m apart, with a 900-tick cap. Death wins; at timeout,
HP fraction wins only by more than one percentage point, otherwise a draw.
Draws score 0.5. Both seats are checked for idle (any draw fails) and random
(score <5% against greedy/counter, including draws). Draw counts are printed.
The random canary remains a measured <5% tolerance, not a claim of zero wins;
DESIGN.md's stronger literal never-win wording is not established.

Build scores pool **all nine** random/greedy/counter strategy pairings with
equal weight and both seat perspectives. The 65% ceiling applies to each
build's mean against the other four builds. The additional 90% sanity cap
applies to each ordered build pair pooled over the same nine strategy pairs.
The nine unpooled pairwise tables are diagnostic: a smart strategy crushing
random is not itself a build imbalance. Same-build cells are printed but
excluded from field means and the pair cap. Every played active duel enters
both build perspectives, so pooled pair rates are complementary.

The payoff protocol runs 14,400 duels of 120 ticks, 7 m starts, all parts at
level 3, 100 stamina, 4 m/s and 100,000 HP to measure uncensored damage.
These are **move policies**, not isolated one-shot move damage. Guard is
held/reissued and takes an in-reach, aligned bite when its block has left the
enemy helpless. That bite pays its normal stamina and completes recovery.
Dodge repeats. Offensive policies repeat their selected move, with the same
spacing helper used by greedy/counter for ranged moves. All of this uses the
public order API, including finite-arena walls; no damage is credited merely
for blocking or retreating. Deterministic start offsets are paired
with reversed seats (odd requested sample counts round up to a complete
pair). This makes the payoff matrices antisymmetric, including their diagonal.
Standard errors use the independent seat-pair means, with sample variance
across pairs; the two correlated seats are not counted as independent samples.
Raw payoff is damage dealt minus damage received. Resource payoff subtracts
stamina-spend margin times a move-table-derived coefficient:

`mean(offensive L3 total nominal HP / start cost) = 1.779167 HP/stamina`.

Bite contributes `(14 + 7*0.6)/10.8`, charge `47.6/21.6`, spit
`19.6/14.4`, tail `22.4/12`. The mean values a generic offensive stamina point;
it is a diagnostic exchange rate, not an exact value of stamina in every
state. Both raw and resource matrices must independently have no weakly
dominating row at tolerance `2*max(SE_a, SE_b) + 0.5 HP`. Neither gate can
substitute for the other. Both print an equilibrium mix from 200,000 regret
matching iterations. Each mix also has an explicit gate requiring at least
four moves with >=1% weight. This conservative numerical support threshold
excludes tiny positive weights from the solver's uniform initialization;
counting that dust as a six-move equilibrium would be misleading. Elo uses a
Bradley–Terry fit (mean 1000, one half-win pseudo-game per pair); Elo is descriptive and does not alter any gate.

### P2-gates rule revision (2026-11-15)

The current candidate changes bite damage 10 → 11, charge damage 34 → 30,
spit damage 14 → 13 and slow 12 → 20 ticks, tail damage 16 → 17,
guard's tail multiplier 0.40 → 0.25, dodge start cost 3 → 20, and funded
avoid stagger 0 → 5 ticks. Tail catches active dodge and interrupts for
3 ticks (the inherited WIP row, now covered by tests). The offensive damage
adjustments give fast bite a place against the sweep without letting charge
suppress that role. Longer spit slow preserves its ranged exchange while
reducing its build field strength. Guard's better tail mitigation pays for
closing to follow-up range. Dodge's 20-point commitment prevents its cheap
resource savings from dominating damage; its existing distance and six-tick
duration stay intact. A successful funded avoid earns the same minimal
five-tick punish window as a block; failed avoidance earns nothing.

These are deliberate replay-affecting changes. The five fixed action logs
will remain byte-identical; only their hash expectations will be regenerated
after rule validation. Hash serialization, arithmetic, RNG streams and
native/WASM determinism requirements are unchanged. Default and offset
1,000,000 runs pass all tournament gates; offset 1,000,000 is now development
data because an earlier candidate failed its build cap. A fresh offset will
be checked after freezing the table. Stage calibration is still pending.

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

### Remaining balance conflict

The previous default was pure bite in raw damage, with brawler at 68.5%.
The retained result implements G16's guard advantage (+138.80 raw HP against
bite) and ranged spit (+18.30 against bite, +127.06 against charge), with
brawler down to 50.9%, worst field mean 62.4%, worst pooled pair 73.5%, and
all measured canaries passing. Acceptance nevertheless remains **failed**:

- Raw: spit weakly dominates dodge. Repeated dodge deals no damage and still
  takes 75.14 HP from tail; spit's small loss to tail (-8.57) does not give
  dodge a column that defeats that dominance relation within the stated tolerance.
- Resource: dodge weakly dominates bite. In particular, their tail columns
  are +36.77 versus -46.24 HP after stamina adjustment. Cheap evasion saves
  enough stamina to outweigh bite's damage in this diagnostic exchange rate.
- Raw mix: charge 3.9%, spit 38.6%, tail 57.5%; resource mix: charge 34.1%,
  guard 10.0%, dodge 55.9%. Both have three substantial weights, not four.
  Guard beats bite but a held guard still loses heavily to an uncontested
  ranged policy; it does not enter the raw mix just because the riposte works.

A reproduced comparison with the final bots removes both dominance relations
by changing only charge damage 34 → 26, tail damage 16 → 14, dodge active
3 → 2, dodge start cost 3 → 5, and avoidance payment 2 → 1. The full default
run then puts spitter at 73.2%, with worst pooled pair 75.5% and three moves
in each mix. Other defensive timing/cost trials produced pure-spit raw mixes
or failed the random canary. The retained table prioritizes functional
counter/range behaviour, passing canaries, both build caps and mixed rather
than pure outcomes. This is a measured unresolved tradeoff within this pass,
not an exhaustive search or a mathematical impossibility claim. The dominance
and support gates remain enabled and failing; no tables, samples or HP pools
were hidden or substituted to claim acceptance.

### Native verification

- `make test`: passed, including all counter windows, exact riposte boundaries,
  close/ranged exchanges, canaries, generated-log replays and the five fixed
  10,000-tick golden comparisons.
- `make check-core`: passed (libc/libm only).
- `make tourney`: failed honestly with the four checks shown below.
- GCC `-O0 --coverage` combat test run and `gcov -b -c`: core lines 96.57%,
  branches taken 84.90%; bot lines 98.25%, branches taken 87.54%.
- The final application stdout is checked byte-for-byte against this document.
  Fixed `.log` files and `art/reference/` have no changes. No WASM or human
  playtest verification is claimed.

### Final native tournament output

The complete default application stdout below is verbatim from GCC 16.2.1 on
x86-64 Linux, 2026-11-14. `./build/combat_tourney` exits 1 (`make tourney`
exits nonzero). Four checks fail: both dominance checks and both support
checks. All nine strategy/build tables, draw counts and canaries are retained.

```text
cpore combat tourney  (tick 10 Hz, seeds/cell 40, payoff duels/cell 400)

== Move-vs-move payoff, 400 duels per cell: move policies, 7 m apart,
   paired seats and start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)
   guard takes an earned bite riposte; ranged moves retreat and sidestep walls; dodge repeats

-- raw: row's damage dealt minus column's (hp)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00      -54.68     -138.80      -18.30        6.46        0.00      -34.22
charge             54.68        0.00      175.61     -127.06       83.84       95.87       47.16
guard             138.80     -175.61        0.00     -176.49     -104.83        0.00      -53.02
spit               18.30      127.06      176.49        0.00       -8.57        0.00       52.22
tail_strike        -6.46      -83.84      104.83        8.57        0.00       75.14       16.37
dodge               0.00      -95.87        0.00        0.00      -75.14        0.00      -28.50

-- resource-adjusted: raw minus 1.779167 hp per stamina point the row spent, plus the same for the column
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00     -100.22     -165.55       -7.85      -46.24     -152.74      -78.77
charge            100.22        0.00      149.32     -180.94      109.46      -26.37       25.28
guard             165.55     -149.32        0.00       38.70       85.37       90.99       38.55
spit                7.85      180.94      -38.70        0.00      -58.05     -125.30       -5.54
tail_strike        46.24     -109.46      -85.37       58.05        0.00      -36.77      -21.22
dodge             152.74       26.37      -90.99      125.30       36.77        0.00       41.70

== Dominance check (tolerance 2*SE + 0.5 hp)
-- raw matrix (acceptance gate)
   spit weakly dominates dodge
-- resource-adjusted matrix (acceptance gate)
   dodge weakly dominates bite
   raw equilibrium mix (regret matching, 200k iters), game value 0.00:  bite 0.0%  charge 3.9%  guard 0.0%  spit 38.6%  tail_strike 57.5%  dodge 0.0%
  FAIL  raw equilibrium uses >=4 moves at >=1% weight (observed 3/6)
   resource equilibrium mix (regret matching, 200k iters), game value -0.00:  bite 0.0%  charge 34.1%  guard 10.0%  spit 0.0%  tail_strike 0.0%  dodge 55.9%
  FAIL  resource equilibrium uses >=4 moves at >=1% weight (observed 3/6)
  FAIL  no move weakly dominates another (raw damage payoff)
  FAIL  no move weakly dominates another (resource-adjusted payoff)

== Strategy round robin: 5 profiles x 5 profiles x 40 seeds per ordered pair, both sides, 900-tick cap
   score of row against column (win = 1, draw = 0.5), pooled over all profile pairings

row \ col       idle    random    greedy   counter
idle           0.500     0.000     0.000     0.000
random         1.000     0.485     0.032     0.015
greedy         1.000     0.963     0.504     0.313
counter        1.000     0.983     0.682     0.506

== Elo (strategies; max-likelihood fit with one pseudo-game per pair, mean 1000)
   counter       1702
   greedy        1568
   random         994
   idle          -265

== Canaries (both seats; draw = half a score, reported separately)
  PASS  idle scores zero vs random on BOTH seats (draws fail)
   idle left vs random  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs greedy on BOTH seats (draws fail)
   idle left vs greedy  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs counter on BOTH seats (draws fail)
   idle left vs counter score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  random scores <5% vs greedy on BOTH seats
   random left vs greedy  score 0.0320 draws 6/1000; random right score 0.0375 draws 5/1000
  PASS  random scores <5% vs counter on BOTH seats
   random left vs counter score 0.0155 draws 1/1000; random right score 0.0175 draws 3/1000

== Full build pairwise tables (row score; both seats pooled, draws = 0.5)

   random vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.519       0.425       0.394       0.450
   spitter            0.481       0.500       0.469       0.381       0.525
   tank               0.575       0.531       0.500       0.463       0.550
   skirmisher         0.606       0.619       0.537       0.500       0.688
   allrounder         0.550       0.475       0.450       0.312       0.500

   random vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.025       0.013       0.019       0.062       0.037
   spitter            0.075       0.025       0.013       0.081       0.062
   tank               0.056       0.037       0.013       0.050       0.050
   skirmisher         0.050       0.025       0.025       0.000       0.037
   allrounder         0.019       0.000       0.000       0.056       0.037

   random vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.019       0.013       0.031       0.013       0.025
   spitter            0.037       0.000       0.025       0.013       0.025
   tank               0.050       0.000       0.006       0.000       0.037
   skirmisher         0.025       0.013       0.000       0.000       0.050
   allrounder         0.019       0.000       0.000       0.000       0.013

   greedy vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.975       0.925       0.944       0.950       0.981
   spitter            0.988       0.975       0.963       0.975       1.000
   tank               0.981       0.988       0.988       0.975       1.000
   skirmisher         0.938       0.919       0.950       1.000       0.944
   allrounder         0.963       0.938       0.950       0.963       0.963

   greedy vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.000       0.938       0.000       0.381
   spitter            1.000       0.500       1.000       1.000       1.000
   tank               0.062       0.000       0.500       0.000       0.000
   skirmisher         1.000       0.000       1.000       0.500       0.550
   allrounder         0.619       0.000       1.000       0.450       0.500

   greedy vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.506       0.000       0.925       0.000       0.406
   spitter            0.188       0.500       0.000       1.000       1.000
   tank               0.150       0.000       0.494       0.000       0.000
   skirmisher         0.031       0.000       0.000       0.506       0.512
   allrounder         0.631       0.000       0.000       0.581       0.450

   counter vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.981       0.963       0.950       0.975       0.981
   spitter            0.988       1.000       1.000       0.988       1.000
   tank               0.969       0.975       0.994       1.000       1.000
   skirmisher         0.988       0.988       1.000       1.000       1.000
   allrounder         0.975       0.975       0.963       0.950       0.988

   counter vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.494       0.812       0.850       0.969       0.369
   spitter            1.000       0.500       1.000       1.000       1.000
   tank               0.075       1.000       0.506       1.000       1.000
   skirmisher         1.000       0.000       1.000       0.494       0.419
   allrounder         0.594       0.000       1.000       0.487       0.550

   counter vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.819       0.887       0.906       0.394
   spitter            0.181       0.500       0.000       1.000       1.000
   tank               0.113       1.000       0.500       1.000       0.000
   skirmisher         0.094       0.000       0.000       0.500       0.463
   allrounder         0.606       0.000       1.000       0.537       0.500

== Build scores pooled over ALL nine strategy pairings
   row / col        brawler     spitter        tank  skirmisher  allrounder  field mean
   brawler            0.500       0.451       0.663       0.474       0.447       0.509
   spitter            0.549       0.500       0.497       0.715       0.735       0.624
   tank               0.337       0.503       0.500       0.499       0.404       0.436
   skirmisher         0.526       0.285       0.501       0.500       0.518       0.457
   allrounder         0.553       0.265       0.596       0.482       0.500       0.474

== Elo (builds, all strategy pairings, both seats)
   brawler         1005
   spitter         1070
   tank             964
   skirmisher       976
   allrounder       985
  PASS  no build field mean exceeds 65% (worst 62.4%)
  PASS  no pooled build pair exceeds 90% (worst 73.5%)

tourney checks FAILED
```

Legacy replay only: the diagonal `CB_V_MOVE` octants use the float32 literal 0.70710678, whose squared length is 1 − 2⁻²⁴, so diagonal walking covers 0.399999988 m per tick instead of 0.4. Both compilers use the same literal, so parity is unaffected.
