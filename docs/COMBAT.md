# Creature combat core (P2)

`core/include/cpore/combat.h` and `core/src/combat.c` implement the standalone
creature combat simulation described in DESIGN.md G16 and Q24/Q31/Q50/Q52.
The old land stage is unchanged. Pack orders, nest/egg consequences and Cognition
integration belong to later phases (G18/G23/G36); this module supplies their
movement/combat foundation, not those stage systems.

## Move data

`CP_COMBAT_MOVES` is the authority. One tick is 0.1 seconds. Costs and damage
below are level 1; reach is attacker centre to target surface, except a dash's
reach is its total travel distance. Arcs are full cone widths in radians.

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags / required part |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| bite | 3 | 1 | 3 | 1.8 | 1.00 | 9 | 11 | bleed (15) | mouth |
| charge | 7 | 5 | 4 | 5.0 | 0.70 | 18 | 17 | stun (6) | dash, ground only / charge |
| guard | 1 | 10 | 2 | 0 | 2.40 | 5 | 0 | none | self, frontal guard / guard |
| spit | 4 | 1 | 5 | 6.0 | 0.25 | 12 | 8 | slow (8) | ranged / spit |
| tail_strike | 3 | 2 | 4 | 2.2 | 2.40 | 10 | 10 | slow (15) | sweep / tail |
| dodge | 1 | 2 | 3 | 2.2 | 0 | 8 | 0 | none | self, directional dash, evade / always available |

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
| any attack | dodge / active | Avoid the hit and status, paying 6 additional stamina per avoided hit. If unaffordable, the hit lands normally. |
| charge | guard / active | Break guard, deal 60% damage, drain up to 20 stamina, stagger for 5 ticks; charge's stun also applies. |
| bite | guard / active | Negate damage and bleed; block cost is incoming damage × 0.35 / guard factor. |
| tail_strike | guard / active | Deal 40% damage, suppress slow; block cost is incoming damage × 0.30 / guard factor. |
| spit | charge / wind-up | Interrupt charge and its order, deal normal damage/slow, stagger for 6 ticks. |
| bite | spit / wind-up or active, centre-to-surface gap <= 2 m | Interrupt spit (including its same-tick hit), deal 125% damage and bleed, stagger for 4 ticks. |

The guard factor is `1 + 0.15 * (guard_level - 1)`. An exhausted block fails,
sets stamina to zero and stuns for 6 ticks. Active dodge is checked first.
The tests exercise every row independently, including stamina failure paths,
rear guard bypass and the same-tick bite/spit interruption.

Side hits gain 25% damage and rear hits 50%. Height advantage adds 10% per
metre, capped at 25%; being lower does not subtract damage. Damage variance is
uniform from 0.9 to 1.1 using only the hit RNG stream. Bleed deals 0.6 HP/tick
and refreshes its timer without stacking. Slow halves walking speed. Water
multiplies walking speed by 0.6, halves permitted dash travel and blocks charge.
This is the minimal medium support for P2, not the swimming system of P6.

## Verbs and tick contract

| Verb | Standing-order behaviour |
|---|---|
| `approach id` | Walk and turn until the gap between bodies is <= 0.6 m. |
| `attack id move` | Close to 92% of move reach, align, wait for stamina if necessary, launch once, finish recovery. |
| `guard` | Raise guard once, finish recovery. It uses current facing. |
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
3. Apply active dashes and all planned displacements; clamp to the 40×40 m arena and separate bodies (radius 0.6 m).
4. Gather hits and snapshot counter/flank/height evaluations. Mark explicit interrupt cancellations, then resolve damage/statuses/deaths. Committed attacks can trade lethal hits; explicit interruption cancels the interrupted creature's same-tick hit.
5. Advance phases and decrement status timers; regenerate stamina where permitted. Increment the world tick and calculate its canonical hash.

A wind-up of W means the first hit frame is W ticks after the launch tick;
a completed move occupies W + active + recovery ticks. Status timers include
the application tick and decrement at its end. Thus a newly applied 15-tick
bleed has 14 subsequent damage ticks; it does not deal an extra immediate tick.
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

Core arithmetic avoids transcendental library calls (cones use a polynomial);
only libc/libm is linked. The Makefile retains C99, `-fno-fast-math` and
`-ffp-contract=off`. Native tests compare every one of 10,000 tick hashes on
seeds 0, 1, 42, 987654321 and 4294967295: an eight-creature mixed-medium bot run
against two independent replays of its exact action log. High HP keeps combat
active across the full trajectory. Tests also cover hash padding/outputs,
geometry, phase boundaries, verb completion/queueing, stamina and death.

**TODO — native/WASM parity:** `emcc` is unavailable here; no SDK was downloaded.
Compile the same module with contraction/fast-math disabled and compare all
10,000 per-tick hashes on every dev seed using the same setups/action logs.
Native repeatability and the chosen arithmetic are prerequisites, not proof of
WASM parity. The design's browser integration and short human playtest clip
also remain unverified; no browser or visual-completion claim is made by P2's
C tests.

## Diagnosis and tuning

The failing WIP had several interacting problems:

- Charge travelled 5/3 = 1.67 m per active frame, exceeding the 1.2 m body diameter. A nearby target could be crossed before the post-movement cone/contact check. Five active frames reduce each step to 1 m; a regression test starts charge against guard at 1.6 m centre distance.
- Greedy ranked raw hit damage, so the brawler repeatedly chose an expensive charge even where a bite had better damage per committed tick. It now divides expected damage (including unstacked nominal bleed) by wind-up + active + recovery, preserving the existing reach/aim discount and affordability check.
- Bite's four-tick wind-up lost to spit's three-tick wind-up at close range. Bite is now three, spit four. Charge's seven leaves time for spit after the counter-picker's two-tick reaction delay. Counter rules themselves are unchanged.
- Spit's 25-tick slow exceeded its nine-tick cycle, providing continuous closing denial. Six-metre reach, eight damage and eight-tick slow give melee a closing opportunity. The supplied bots do not kite: spit dominance here came from opening range/status advantage and repeated charge interrupts, not a retreat policy.
- Charge cost/damage fell from 24/22 to 18/17 and recovery from seven to four, making it a closing/guard-breaking commitment rather than the default damage choice. Bite damage/bleed, guard, tail and dodge data stayed intact. Shortening guard was tested and rejected: the original duration preserves its resource advantage over dodge against bite.
- After removing ranged dominance, unequal body pools exposed tank/melee dominance. HP was calibrated against the field alongside the timing changes; no part levels, speeds, stamina pools, counter rules or resolution branches were changed to privilege a named build. Tank still has the largest pool; the brawler pays durability for its high mouth level.

Additional edge tests found two bookkeeping/API defects: integer convenience
helpers could truncate invalid values into legal moves/directions/targets, and
a failed guard drained its remaining stamina without adding that amount to
`stamina_spent`. Both now have regressions and generic fixes. The latter keeps
the printed resource utility consistent with actual stamina loss.

The final scripted profiles are data in `apps/combat_bots.c`:

| Build | Mouth | Charge | Spit | Tail | Guard | HP | Stamina | Speed m/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| brawler | 4 | 3 | 0 | 1 | 1 | 91 | 90 | 3.8 |
| spitter | 2 | 0 | 4 | 0 | 1 | 107 | 110 | 4.2 |
| tank | 2 | 1 | 0 | 3 | 4 | 115 | 100 | 3.4 |
| skirmisher | 3 | 0 | 2 | 2 | 0 | 100 | 100 | 4.6 |
| allrounder | 3 | 2 | 2 | 2 | 2 | 100 | 100 | 4.0 |

## Tournament protocol and measured results

`make tourney` runs the default `./build/combat_tourney` (40 seeds/cell,
400 payoff duels/cell). The original protocol and 65% ceiling are retained:
16,000 strategy duels over every ordered strategy/profile pair, two creatures
facing each other 12 m apart on flat ground, 900-tick cap. A timeout compares
remaining HP fractions, drawing within one percentage point. Draws score 0.5;
printed “win rates” are scores, so the ceiling includes half-credit draws and
is checked separately for greedy and counter, not just their mean.

Payoffs use 14,400 twelve-second duels, 7 m starts, neutral level-3 profiles,
100,000 HP, 100 stamina and deterministic start-delay offsets. Offensive spam
repeats one move; guard/dodge spam reacts to a visible wind-up with a two-tick
reaction delay. The headline utility is **damage margin minus stamina-spend
margin**, at the WIP's unchanged 1 HP/stamina coefficient. Raw HP margins are
also printed: pure defensive moves never gain HP damage, so raw pairwise
dominance over them remains visible. The headline matrix has no pairwise weak
dominance at the printed tolerance; this is a finite-protocol measurement,
not a claim of universal balance. Different delay schedules and hit draws
mean the sampled matrix is not forced to be exactly antisymmetric.

Greedy uses the expected damage rate described above. Counter-picker responds
from an idle phase to visible wind-ups with table-derived interrupts or timed
defences, otherwise using greedy. Random chooses legal attacks or movement/
defence/rest without an opponent model. Idle issues nothing. Bots act through
the public order API and their RNG is outside the core state/action replay.
Elo is a Bradley–Terry fit anchored at mean 1000, with one half-win pseudo-game
per pair to keep perfect records finite.

The following is the complete default output, verbatim, from the final native
build on 2026-11-14 (GCC 16.2.1, x86-64 Linux):

```text
cpore combat tourney  (tick 10 Hz, seeds/cell 40, payoff duels/cell 400)

== Move-vs-move payoff, 400 duels per cell: two creatures repeating one move, 7 m apart,
   random start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)

-- raw: row's damage dealt minus column's (hp)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite               -0.37      100.11        0.00      282.60      110.59        0.00       82.16
charge           -100.54        0.02       85.70      -77.10       44.16       89.34        6.93
guard               0.00      -85.70        0.00     -107.30      -60.06        0.00      -42.18
spit             -277.06       76.66      112.01       -0.14      -37.48        0.00      -21.00
tail_strike      -110.73      -44.25       61.61       40.60       -0.29        0.00       -8.84
dodge               0.00      -89.34        0.00        0.00        0.00        0.00      -14.89

-- resource-adjusted (headline): raw minus 1.0 hp per stamina point the row spent, plus the same for the column
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite               -0.37       78.51      -38.50      314.50       96.68      -33.60       69.54
charge            -78.94        0.02      112.10     -105.90       63.30        7.74       -0.28
guard              38.50     -112.10        0.00       -4.46       -3.87        0.00      -13.66
spit             -309.46      104.70       10.01       -0.14      -49.48      -64.00      -51.40
tail_strike       -96.82      -63.81        7.16       52.60       -0.29       16.00      -14.19
dodge              34.72       -7.74        0.00       66.24      -11.24        0.00       13.66

== Dominance check (tolerance 2*SE + 0.5 hp)
-- raw matrix (informational: defensive rows are bounded by 0 here)
   bite weakly dominates guard
   bite weakly dominates dodge
-- resource-adjusted matrix (the check)
   no move weakly dominates any other
   equilibrium mix (regret matching, 200k iters), game value 0.04:  bite 6%  charge 28%  guard 0%  spit 0%  tail_strike 0%  dodge 65%
  PASS  no move weakly dominates another (resource-adjusted payoff)

== Strategy round robin: 5 profiles x 5 profiles x 40 seeds per ordered pair, both sides, 900-tick cap
   score of row against column (win = 1, draw = 0.5), pooled over all profile pairings

row \ col       idle    random    greedy   counter
idle           0.500     0.000     0.000     0.000
random         1.000     0.494     0.004     0.009
greedy         1.000     0.998     0.501     0.427
counter        1.000     0.995     0.573     0.512

== Elo (strategies; max-likelihood fit with one pseudo-game per pair, mean 1000)
   counter       1788
   greedy        1739
   random         863
   idle          -389

== Strategy dominance (score vs each opponent, tolerance 0.02)
   random weakly dominates idle
   greedy weakly dominates idle
   greedy weakly dominates random
   counter weakly dominates idle
   counter weakly dominates random
   counter weakly dominates greedy
   counter weakly dominates every other strategy (a strict skill ladder, as intended for the reference rows)

== Canaries and ladder
  PASS  greedy and counter beat idle (>99%)
  PASS  greedy and counter beat random (>95%)
  PASS  random beats idle
  PASS  idle never scores against an active bot (0%)
  PASS  random rarely beats greedy or counter (<5%)
   idle  vs greedy 0.0000  vs counter 0.0000 | random vs greedy 0.0040  vs counter 0.0090
   greedy vs counter: greedy scores 0.427

== Builds: profile win rate, same strategy on both sides (profile vs the other four)
   profile        greedy  counter     mean
   brawler         0.431    0.631    0.531
   spitter         0.634    0.141    0.388
   tank            0.359    0.588    0.473
   skirmisher      0.497    0.641    0.569
   allrounder      0.572    0.547    0.559

   build-vs-build score (row beats column), greedy and counter pooled
                    brawler     spitter        tank  skirmisher  allrounder
   brawler                -       0.556       0.494       0.506       0.569
   spitter            0.419           -       0.500       0.525       0.106
   tank               0.506       0.525           -       0.163       0.700
   skirmisher         0.469       0.519       0.819           -       0.469
   allrounder         0.438       0.887       0.375       0.537           -

== Elo (builds, greedy and counter mirror matches pooled)
   brawler         1021
   spitter          934
   tank             980
   skirmisher      1038
   allrounder      1028
  PASS  no build exceeds the 65% win-rate ceiling (worst 64.1%)

tourney checks passed
```

## Verification

All checks below ran on the final code. `make test` now includes the original
core suite, the combat executable **and** the default tournament so balance
acceptance is enforced on later changes.

| Check | Measured result |
|---|---|
| `make test` | Passed: old core suite, combat suite, default tournament. |
| `make check-core` | Passed: libc/libm only, no graphics headers. |
| `./build/combat_tourney 200 800` | Passed: 80,000 strategy duels + 28,800 payoff duels; worst build score 61.8%; random scores 0.0042 vs greedy and 0.0069 vs counter; idle scores 0 against both. |
| Independent test canaries | Per scripted bot: 2,000 idle + 2,000 random duels, both seats and every ordered profile pair. Idle wins 0/2,000 against each; random wins 6/2,000 against greedy and 12/2,000 against counter. |
| GCC AddressSanitizer + UndefinedBehaviorSanitizer | Full combat suite passed with `-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer`. |
| GCC/gcov coverage (`-O0 -g --coverage`) | `combat.c`: 96.46% of 621 executable lines; 94.41% of branches executed, 83.24% taken at least once. |

Instrumentation builds compiled `tests/test_combat.c`, `apps/combat_bots.c`,
`core/src/combat.c` and `core/src/rng.c` directly with C99, no fast-math and
contraction disabled; their output/artifacts were kept under `/tmp`. The larger
tournament changes the deterministic seed schedule as well as increasing its
size; it was checked after tuning, rather than replacing the default protocol.
Native/WASM parity and the human playtest remain the open acceptance checks
listed above.
