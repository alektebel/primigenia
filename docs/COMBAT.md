# Creature combat core (P2)

`core/include/cpore/combat.h` and `core/src/combat.c` implement the standalone
creature combat simulation described in DESIGN.md G16 and Q24/Q31/Q50/Q52.
The old land stage is unchanged. Pack orders, nest/egg consequences and Cognition
integration belong to later phases (G18/G23/G36); this module supplies their
movement/combat foundation, not those stage systems.

**Review status:** correctness regressions pass, but combat balance acceptance
still fails. The default tournament reports a 68.5% brawler field mean and
dominance in both payoff matrices. P2 is not merge-ready; native/WASM parity
and the human playtest are also pending.

## Move data

`CP_COMBAT_MOVES` is the authority. One tick is 0.1 seconds. Costs and damage
below are level 1; reach is attacker centre to target surface, except a dash's
reach is its total travel distance. Arcs are full cone widths in radians.

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags / required part |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| bite | 3 | 1 | 3 | 1.8 | 1.00 | 9 | 11 | bleed (15) | mouth |
| charge | 10 | 5 | 4 | 5.0 | 0.70 | 18 | 17 | stun (6) | dash, ground only / charge |
| guard | 1 | 14 | 2 | 0 | 2.40 | 5 | 0 | none | self, frontal guard / guard |
| spit | 6 | 1 | 5 | 6.0 | 0.25 | 12 | 8 | slow (8) | ranged / spit |
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
The test-only `CP_COMBAT_TEST` build exposes `cp_combat_test_hit_variance`: enabling it fixes the damage roll at exactly 1.0 while still consuming the normal RNG draw. It is absent from production libraries and tournament builds. Exact damage tests cover charge 60%, tail 40%, rear 1.5× and the height cap.

The tests exercise every row independently, including stamina failure paths,
rear guard bypass and the same-tick bite/spit interruption.

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
4. Gather hits and snapshot counter/flank/height evaluations. Mark explicit interrupt cancellations. Record each surviving hit's damage, status and defensive payment before applying outcomes. Dodge/guard payments consume a stamina copy in ascending attacker id (then defender id); scarce defence therefore favours the lower attacker id. Apply every landed hit, including full damage credit and status after another hit has crossed zero HP. Resolve each death once after the pass: the lowest-id attacker that landed positive damage on this tick gets the kill. Committed attacks can trade lethal hits; explicit interruption cancels the interrupted creature's same-tick hit.
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
Do not regenerate to hide an unexplained regression. These are native regression
fixtures, not evidence of native/WASM equality.

**TODO — native/WASM parity:** `emcc` is unavailable here; no SDK was downloaded.
Compile the same module with contraction/fast-math disabled and compare all
10,000 per-tick hashes on every dev seed using the same setups/action logs.
Native repeatability and the chosen arithmetic are prerequisites, not proof of
WASM parity. The design's browser integration and short human playtest clip
also remain unverified; no browser or visual-completion claim is made by P2's
C tests.

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
The remaining move values retain the reviewed baseline.

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
Guard is held/reissued, dodge repeated; each completes recovery and restarts
through the same public order API. Deterministic start offsets are paired
with reversed seats (odd requested sample counts round up to a complete
pair). This makes the payoff matrices antisymmetric, including their diagonal.
Standard errors use the independent seat-pair means, with sample variance
across pairs; the two correlated seats are not counted as independent samples.
Raw payoff is damage dealt minus damage received. Resource payoff subtracts
stamina-spend margin times a move-table-derived coefficient:

`mean(offensive L3 total nominal HP / start cost) = 1.312500 HP/stamina`.

Bite contributes `(15.4 + 14*0.6)/10.8`, charge `23.8/21.6`, spit
`11.2/14.4`, tail `14/12`. The mean values a generic offensive stamina point;
it is a diagnostic exchange rate, not an exact value of stamina in every
state. Both raw and resource matrices must independently have no weakly
dominating row at tolerance `2*max(SE_a, SE_b) + 0.5 HP`. Neither gate can
substitute for the other. Both print an equilibrium mix from 200,000 regret
matching iterations. Elo uses a Bradley–Terry fit (mean 1000, one half-win
pseudo-game per pair); Elo is descriptive and does not alter any gate.

### Final native tournament output

The complete default output below is verbatim from GCC 16.2.1 on x86-64 Linux,
2026-11-14. `./build/combat_tourney` exits 1 (`make tourney` exits nonzero).
There are three acceptance failures: raw dominance, resource dominance and
brawler's 68.5% field mean. The worst pooled build pair is 74.4%, below 90%.
The unpooled strategy tables also show 100% cells; those remain visible and
are not claimed to pass a per-strategy build-pair cap. No HP pools or special
resolution branches were adjusted after seeing these results.

```text
cpore combat tourney  (tick 10 Hz, seeds/cell 40, payoff duels/cell 400)

== Move-vs-move payoff, 400 duels per cell: two creatures repeating one move, 7 m apart,
   paired seats and start offsets, 12 s; neutral builds (all parts L3, hp 100000 so nobody dies)

-- raw: row's damage dealt minus column's (hp)
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00      127.47       58.69      282.71      110.63       40.59      103.35
charge           -127.47        0.00       74.63      -66.01      -43.70       98.13      -10.74
guard             -58.69      -74.63        0.00      -98.51      -80.33        0.00      -52.03
spit             -282.71       66.01       98.51        0.00      -52.37        1.60      -28.16
tail_strike      -110.63       43.70       80.33       52.37        0.00      117.31       30.51
dodge             -40.59      -98.13        0.00       -1.60     -117.31        0.00      -42.94

-- resource-adjusted: raw minus 1.312500 hp per stamina point the row spent, plus the same for the column
row \ col           bite      charge       guard        spit tail_strike       dodge    row mean
bite                0.00      104.08      -11.67      316.44       92.38       61.75       93.83
charge           -104.08        0.00       66.87      -94.36      -24.80      120.72       -5.94
guard              11.67      -66.87        0.00       14.85       -0.07      132.26       15.31
spit             -316.44       94.36      -14.85        0.00      -49.22       20.50      -44.28
tail_strike       -92.38       24.80        0.07       49.22        0.00      139.29       20.17
dodge             -61.75     -120.72     -132.26      -20.50     -139.29        0.00      -79.09

== Dominance check (tolerance 2*SE + 0.5 hp)
-- raw matrix (acceptance gate)
   bite weakly dominates guard
   bite weakly dominates dodge
   tail_strike weakly dominates charge
-- resource-adjusted matrix (acceptance gate)
   bite weakly dominates spit
   bite weakly dominates dodge
   guard weakly dominates dodge
   raw equilibrium mix (regret matching, 200k iters), game value -0.00:  bite 100.0%  charge 0.0%  guard 0.0%  spit 0.0%  tail_strike 0.0%  dodge 0.0%
   resource equilibrium mix (regret matching, 200k iters), game value -0.00:  bite 36.9%  charge 6.4%  guard 56.7%  spit 0.0%  tail_strike 0.0%  dodge 0.0%
  FAIL  no move weakly dominates another (raw damage payoff)
  FAIL  no move weakly dominates another (resource-adjusted payoff)

== Strategy round robin: 5 profiles x 5 profiles x 40 seeds per ordered pair, both sides, 900-tick cap
   score of row against column (win = 1, draw = 0.5), pooled over all profile pairings

row \ col       idle    random    greedy   counter
idle           0.500     0.000     0.000     0.000
random         1.000     0.488     0.001     0.001
greedy         1.000     0.998     0.513     0.494
counter        1.000     0.998     0.492     0.499

== Elo (strategies; max-likelihood fit with one pseudo-game per pair, mean 1000)
   greedy        1848
   counter       1847
   random         778
   idle          -472

== Canaries (both seats; draw = half a score, reported separately)
  PASS  idle scores zero vs random on BOTH seats (draws fail)
   idle left vs random  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs greedy on BOTH seats (draws fail)
   idle left vs greedy  score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  idle scores zero vs counter on BOTH seats (draws fail)
   idle left vs counter score 0.0000 draws 0/1000; idle right score 0.0000 draws 0/1000
  PASS  random scores <5% vs greedy on BOTH seats
   random left vs greedy  score 0.0010 draws 0/1000; random right score 0.0020 draws 0/1000
  PASS  random scores <5% vs counter on BOTH seats
   random left vs counter score 0.0010 draws 0/1000; random right score 0.0025 draws 1/1000

== Full build pairwise tables (row score; both seats pooled, draws = 0.5)

   random vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       0.487       0.381       0.281       0.562
   spitter            0.512       0.500       0.550       0.325       0.631
   tank               0.619       0.450       0.500       0.438       0.738
   skirmisher         0.719       0.675       0.562       0.500       0.787
   allrounder         0.438       0.369       0.263       0.212       0.500

   random vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.013       0.000       0.000       0.000       0.000
   spitter            0.000       0.000       0.000       0.000       0.000
   tank               0.000       0.000       0.000       0.000       0.000
   skirmisher         0.000       0.000       0.000       0.000       0.025
   allrounder         0.000       0.000       0.000       0.000       0.000

   random vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.000       0.000       0.000       0.013       0.000
   spitter            0.000       0.013       0.000       0.000       0.000
   tank               0.000       0.000       0.000       0.000       0.013
   skirmisher         0.000       0.006       0.000       0.000       0.000
   allrounder         0.000       0.000       0.000       0.000       0.000

   greedy vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.988       1.000       1.000       1.000       1.000
   spitter            1.000       1.000       1.000       1.000       1.000
   tank               1.000       1.000       1.000       1.000       1.000
   skirmisher         1.000       1.000       1.000       1.000       1.000
   allrounder         1.000       1.000       1.000       0.975       1.000

   greedy vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       1.000       0.713       1.000       1.000
   spitter            0.000       0.500       0.000       0.225       0.200
   tank               0.287       1.000       0.500       0.494       0.994
   skirmisher         0.000       0.775       0.506       0.500       0.419
   allrounder         0.000       0.800       0.006       0.581       0.500

   greedy vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.512       1.000       0.713       1.000       1.000
   spitter            0.000       0.500       0.000       0.231       0.225
   tank               0.237       1.000       0.487       0.556       0.994
   skirmisher         0.000       0.762       0.550       0.450       0.487
   allrounder         0.000       0.781       0.025       0.531       0.481

   counter vs random
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            1.000       1.000       1.000       1.000       1.000
   spitter            1.000       0.988       1.000       0.994       1.000
   tank               1.000       1.000       1.000       1.000       1.000
   skirmisher         0.988       1.000       1.000       1.000       1.000
   allrounder         1.000       1.000       0.988       1.000       1.000

   counter vs greedy
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.487       1.000       0.762       1.000       1.000
   spitter            0.000       0.500       0.000       0.237       0.219
   tank               0.287       1.000       0.512       0.450       0.975
   skirmisher         0.000       0.769       0.444       0.550       0.469
   allrounder         0.000       0.775       0.006       0.512       0.519

   counter vs counter
   row / col        brawler     spitter        tank  skirmisher  allrounder
   brawler            0.500       1.000       0.756       1.000       1.000
   spitter            0.000       0.500       0.000       0.219       0.194
   tank               0.244       1.000       0.500       0.419       0.988
   skirmisher         0.000       0.781       0.581       0.500       0.512
   allrounder         0.000       0.806       0.013       0.487       0.500

== Build scores pooled over ALL nine strategy pairings
   row / col        brawler     spitter        tank  skirmisher  allrounder  field mean
   brawler            0.500       0.721       0.592       0.699       0.729       0.685
   spitter            0.279       0.500       0.283       0.359       0.385       0.327
   tank               0.408       0.717       0.500       0.484       0.744       0.588
   skirmisher         0.301       0.641       0.516       0.500       0.522       0.495
   allrounder         0.271       0.615       0.256       0.478       0.500       0.405

== Elo (builds, all strategy pairings, both seats)
   brawler         1111
   spitter          897
   tank            1052
   skirmisher       997
   allrounder       944
  FAIL  no build field mean exceeds 65% (worst 68.5%)
  PASS  no pooled build pair exceeds 90% (worst 74.4%)

tourney checks FAILED
```

## Verification and open acceptance work

| Command / check | Final result |
|---|---|
| `nice -n 10 make test` | Passed: existing core suite, combat regressions, tournament arithmetic and all five cross-process golden comparisons. Balance acceptance is separate and still fails. |
| `make check-core` | Passed: libc/libm only; no graphics headers. |
| `nice -n 10 make tourney` | Failed acceptance: both dominance checks and the 65% field ceiling. All canaries and the 90% pooled pair cap passed. Full output above. |
| ASan + UBSan, combat tests | Passed with `-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer`, C99, test-only variance hook and deterministic FP flags. |
| GCC/gcov, combat tests | `combat.c`: 96.55% of 638 lines; 94.62% of branches executed, 83.86% taken at least once. |
| Independent `-O0` native golden replay | All five logs matched all 50,000 committed hashes. Default production build is `-O2`. |
| Golden mutation probe | A temporary build omitting HP from the hash failed at seed 0, tick 0 (expected `e02d490b5e2b2b44`, got `afe6616001b52490`). No mutated source was committed. |
| CFLAGS override dry run | `make -Bn CFLAGS='-O3 -ffast-math -ffp-contract=fast' build/core/src/combat.o` ends the compiler flags with `-fno-fast-math -ffp-contract=off`. |

The independent canary unit runs use every ordered build pair and both seats,
40 seeds each. These are their final printed counts:

```text
  canary greedy : idle wins 0 draws 0/2000, random wins 4 draws 2/2000, smart wins 1994/2000
  canary counter: idle wins 0 draws 0/2000, random wins 4 draws 2/2000, smart wins 1994/2000
```

Open work: address the measured balance failures through explicit combat design,
verify native/WASM parity on the stored logs when the toolchain is available,
and record the required human playtest. `emcc` is absent; no SDK or system
packages were installed. No browser test or human playtest was performed.
A green correctness suite does not complete P2 acceptance.
