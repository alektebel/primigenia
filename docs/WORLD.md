# Creature world foundation (G56)

`core/include/cpore/world.h` and `core/src/stage_world.c` implement the P4
world foundation at **10 Hz**. The cell stage already owns `CpWorld` and
`world.c`, so this module uses `CpStageWorld` and `cp_stage_*`. This is the
world portion of P4, not the full social/progression milestone in `P4.md`.

## State and terrain

A world owns its complete setup, player, up to 24 wild creatures, nest,
up to 1,024 circular tree/rock obstacles, standing player input, clock,
encounter, and AI RNG state. Species ids 0–3 are Rondo, Zanco, Espinodo and
Garfio. The const species table supplies sight, temperament, roam radius and
P4 combat profiles. Spawns supply their positions, homes and profiles; explicit
profile/bot overrides preserve the existing P3 Garfio acceptance fixture.
The native default episode uses the P4 Garfio profile and counter bot.

`cp_stage_height` is the replaceable height-source interface. Its analytic
implementation ports the existing valley's value-noise permutation, fBm,
central flattening, lake depression and mountain mask. The permutation is
immutable and derived from `terrain_seed` by the original integer shuffle.
Exponential depressions use a reciprocal polynomial with range reduction.
Simulation arithmetic uses float32 `+ - * / sqrtf`, integer operations and
literal/polynomial constants, with no fast math or FMA contraction.
`atan2f` is used only to format observation bearings, never to update state.

`cp_stage_ground` samples the same 256×256 triangular surface used by the
stage mesh. Both interfaces can be replaced by W11/W12 without changing
movement or AI. The browser builds its visual terrain from C height samples;
its pointer rays, camera clearance and creature grounding query C ground.
The analytic port has maximum error **0.004203 m** against the reviewed hero
source over 961 points in the playable valley; the regression limit is 1 cm.
The hero and reference assets remain byte-identical.

Layouts are setup data: the browser supplies the existing visual scatter's
circle positions/radii, nest and one wild spawn. A native client can supply
its own setup or replay the exact browser layout, which is included in the
world log. Default `terrain_seed` is 7; actor/encounter seed defaults to 42.
A flat test surface with an optional circular deep-water region is also
available. This foundation does not wire in the eroded terrain generator.

## Tick order and locomotion

Each `cp_stage_step`:

1. Validates/applies the optional input; rejected orders preserve the standing
   order. Clears derived last-tick outputs.
2. Advances the active combat through `cp_combat_order`, the existing public
   bot API and one `cp_combat_step`; otherwise advances respawn or roaming
   player movement and stamina/cooldown.
3. Updates every living wild creature outside the active encounter, including
   while the player fights or respawns. Updates perception/roam goals, moves
   the creatures, and starts at most one encounter when eligible.
4. Increments the world tick and clock, then hashes the resulting state.

`CP_STAGE_CONTINUE` or a NULL input preserves an order. `WAIT` brakes to a
stop. Headings have signed int16 x/z components and are normalized using
`sqrtf`; destinations and approach/attack orders steer toward points/entities.
Turning is limited to approximately 0.38 radians/tick, or 0.9 while pivoting
for a sharp reversal. Acceleration and braking use fixed exponential-ease
coefficients. Destination speed reduces with stopping distance. Uphill or
downhill slope reduces speed. Sprint multiplies roaming speed by 1.7 and
spends 1.4 stamina/tick; ordinary roaming recovers 1/tick.

Movement checks the ±195 m world boundary, terrain slope and ground below
−0.7 m. Terrain is checked along each displacement at intervals no longer
than 0.25 m. Swept circle checks prevent tunnelling through obstacles; a
blocked move attempts x then z sliding. Collision uses the profile's body
radius. Setup profiles must fit the combat core's supported ranges (levels
0–5, HP/stamina 1–100,000, speed 0.5–12 m/s, radius 0 or 40–400 cm).

## Wild AI and encounters

Roaming goals lie within the species' home radius. Roam decisions consume
exactly three draws (x, z, duration) even if a reaction overrides the goal.
Timid creatures flee a nearby player and never initiate combat. Territorial
creatures defend an 8 m home territory plus their body radius while the
player is visible. Aggressive creatures approach inside 28 m. Perception is
radius based; terrain line of sight is intentionally omitted.

An attack or hostile approach starts combat at 5.5 m. Arena coordinates map
as in `web/engine/encounter.js`: the creatures' midpoint becomes (20,20) in a
40×40 m flat arena. Existing combat rules, moves and bot policies are called
through their public APIs. Territorial creatures use greedy, aggressive
creatures use counter, and timid creatures use counter until below half HP,
then flee. Setup may override the bot for a fixture. No changes are made to
`core/src/combat.c` or `apps/combat_bots.c`.

Victory leaves an inert carcass with the same stable id. Death starts a
20-tick respawn at the nest and restores the original pools. Escape crosses
an arena edge with more than 8 m separation. After death/escape, the enemy
returns home, and an 80-tick cooldown prevents immediate re-engagement.
Other wild creatures continue simulating. The arena retains the existing
flat combat collision model; landscape collision applies to roaming.

The clock wraps every 12,000 ticks (20 simulated minutes). It is state only;
no nocturnal effects are added here. Egg/hatchling consequences, social
skills, DNA, raids, discovery, tiers and recipes remain subsequent P4 work.
There is direct steering and sliding, not global pathfinding around obstacles.

## Agent API

Stable ids: player **0**, wild creatures **1..n**, nest **1000**, obstacles
**2000+i**. Ids do not recycle after a kill. `cp_stage_observe` builds bounded
JSON (`world-1`); insufficient output capacity returns −1. It exposes own
position/facing, HP and stamina pools, speed, clock, command error, nearby
entities within 40 m (id/type/species/distance/relative bearing), legal verb
names, available attack moves and a short English summary. Bearing is in
degrees, positive clockwise from the player's facing.

`cp_stage_order` accepts a `CpStageInput`; `cp_stage_command` accepts:

| Text | Meaning |
|---|---|
| `go 4,12` (or `go 4 12`) | Walk to a world x/z destination. |
| `heading 30.5` | Walk along a degree bearing; 0 is +z, 90 is +x. |
| `approach #1` | Approach the creature until within the body gap. |
| `attack #1 bite` (or move id `0`) | Approach and attack using a legal combat move. |
| `flee` | Flee the encounter or nearest living creature. |
| `go_nest` | Walk to the nest. |
| `wait` | Stop the standing plan and brake. |

Guard and directional dodge are also available in the input struct for human
combat controls. Missing/dead ids, unavailable moves, invalid headings,
nonfinite coordinates and invalid setups are rejected with error codes;
`cp_stage_order_error` supplies English text. An order is persistent until
replaced, completed or the encounter ends. This module supplies the primitive
standing orders; the broader Q16 macro scheduler and its P4 social/raid
interrupts are not implemented here.

`make build/world_cli` builds a scripted 300-tick native episode:

```sh
./build/world_cli 42
./build/world_cli --replay tests/golden/world-42.log
```

The episode prints observations every ten ticks and its final hash. The
replay command prints every world tick hash. `cp_stage_replay` also accepts
setup + tick-sorted input records directly from a C client. No Python stub is
required; the functions are exported by the native shared library.

## Hashes, logs and WASM

The world hash is FNV-1a 64 over explicit little-endian fields, never struct
memory. It covers version, setup including profiles/obstacles, ticks/clock,
all actor state, standing input, encounter mapping/outcome/timers, spawn and
roam `CpRng` streams, the bot RNG and every bot policy field, and the public
combat canonical hash after an encounter has started. Signed float zero is
canonicalized. Padding, unused slots, derived noise tables, cached hashes,
last-tick orders/errors and render events are excluded.

Spawn, roaming, bot decisions and combat terrain/spawn/hit have isolated RNG
state. Consuming a roam draw changes the world hash without changing terrain
or spawn state. The immutable analytic noise initializer does not consume
any runtime decision stream.

`CPORE_WORLD_LOG 1` contains the full numeric setup, a tick count, then one
input row per tick: verb, target, move, dodge direction, sprint, heading x/z,
destination x/z. It records attempted inputs, including rejected orders.
Setup and input floats are serialized from their **float32 values**: exporting
unrounded JS doubles can change a decimal midpoint's rounding when C parses
it. Committed `.hashes` files accompany the golden `.log` files. Tests never
rewrite them; `node tests/test_wasm_world.mjs --update-goldens` is the explicit
initial-generation/update command.

`apps/world_wasm_api.c` owns one world per modular WASM instance. Its versioned
numeric ABI exposes setup, tick input, snapshots, observation and hash. The
existing combat ABI views the C world's owned encounter for render queries.
`web/engine/cpworld.js` validates inputs and copies snapshots.
`web/stage/simulation.js` owns only the display accumulator, input encoding,
interpolation snapshots and output logs/effects. It never steps combat itself.

## Verification evidence

The new parity test checks three committed 3,000-tick logs (seeds 1, 42,
987654321), 100 random-input runs of 3,000 ticks each native versus WASM,
independent WASM instances, JSON observations, malformed inputs, and complete
30/73 FPS world logs replayed natively. Goldens include three species, combat,
fleeing, roaming, obstacles and destinations. Initial goldens were generated
for this implementation; no existing combat golden was changed.

`tests/stage_play.cjs` additionally records actual software-Chromium sessions
for biter/guard/spitter at 30 and 73 rAF FPS and compares **every world tick**
against `world_cli`, alongside the existing combat replay checks. The pointer
journey test places the predator away through the C setup API during its
movement checks, then restores the real setup for selection/attack checks.
This prevents the new 28 m hostility from killing the player during an input
test. Natural encounters remain covered separately.

Run the browser targets with the repository served on port 8765, existing
Playwright in NODE_PATH, and the required software renderer. All browsers are
closed in `finally`; browser/heavy commands run under `nice -n 10`.

```sh
python3 -m http.server 8765 --bind 127.0.0.1
export NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
make test
make wasm-test
make stage-test
make studio-test
make world-coverage
```

Final x86-64 Linux verification (GCC 16.2.1, Node 26.13.0,
Chromium 158.0.8127.18, SwiftShader):

| Command/check | Result |
|---|---|
| `make test` | PASS, including the existing 50,000 combat golden hashes. |
| `make wasm-test` | PASS, including world goldens, 100 random runs, terrain and combat parity. |
| `make stage-test` | PASS, including every-tick native browser world replay and frozen legacy JS ticks. |
| `make studio-test` | PASS. |
| `make world-coverage` | New C module: 99.51% lines, 91.97% branches taken. |
| World units under AddressSanitizer + UBSan | PASS, no findings. |
| Native scripted CLI episode | PASS, 300 ticks and 30 observations. |

Winnability remains **39/50 (78%) biter, 37/50 (74%) guard,
30/50 (60%) spitter**, each within 35–80%. The stage generator now strips the
reference rules, frame simulation and obsolete benchmark controls. A browser
assertion verifies the inherited reference tick stays at zero.

Machine-readable evidence, including six final browser world replay hashes,
is in [world-foundation.json](evidence/world-foundation.json). Detailed run logs
and software-browser captures are in `build/world-*.log` and
`build/world-stage/` in the working tree.
P2 tournament balance remains outside this task and is not claimed fixed;
G55's merge gate still applies. No normal-browser human playtest or hardware
frame-rate measurement is claimed.
