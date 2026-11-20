# B3 (spine_volley equilibrium weight): diagnosis and plan

Worktree `cpore-wt/c2-moves`, branch `c2/moves-recipes` (HEAD 7fbdc30). Planner output only; no project file was edited.
I ran the experiments with scratch copies of `apps/combat_bots.c`, `apps/combat_tourney.c` and `core/src/combat.c`,
linked against `build/libcpore.a`, in the session scratchpad. Payoff runs used 400 duels per cell, seed offset 0 unless stated.

## 1. Diagnosis

**1a. The row being tested does not represent the move.** In `compute_payoff` each row is `BOT_SPAM` with a single move.
When that move is not available, `bot_decide` does this (combat_bots.c, `case BOT_SPAM`):
`if(!bot_available(me,b->spam_move)){out->verb=CB_V_IDLE;return 1;}`. So the "spine_volley" row means "fire the volley,
then stand still until it is ready again". With cooldown 30 over the 120-tick payoff duel, that is at most 4 volleys.
The commitment is 5+1+3 = 9 ticks per 30, so the creature stands idle for about 70 % of the duel while the column player
keeps using a move with no cooldown. B3 is measuring the cost of standing idle, not the volley. Evidence:
- pounce (also cooldown 30) also gets 0.0 % in the raw equilibrium. quill_volley (cooldown 15) gets only 6.2 %.
- The raw row mean is -30.6. The volley's only positive cells are against guard (+57.8), curl_up (+52.0) and roar (+3.4).
  Those are exactly the columns that do not punish standing still.
- quill_volley does the same job with twice the shots, and beats the volley's row in 11 of 13 columns
  (for example vs guard +99.9 against +57.8, and head to head +20.7).
- **Test:** I made only one change, a harness change: while the volley is unavailable, the row fights with bite
  (the "composite" row). Result: raw weight goes from 0.0 % to **13.0 %** (14.1 % at seed offset 1e6, 14.6 % at 2e6).
  Raw support is 6/14 and neither matrix has a dominance. No stat changed.

**1b. The resource matrix excludes cooldown ranged moves as a family, through how it prices spacing.**
- A ranged row keeps its gap with `spaced_attack`, which issues `CB_V_FLEE` (sprint at 0.5 stamina per tick, and
  regeneration stops while sprinting). The matrix prices every stamina point at 1.764 hp.
- Against guard, the volley row goes from raw +57.8 to resource -103.8. That gap is about 92 more stamina than guard
  spends in 12 s, and only 4 × 6 = 24 of it is the volley's own cost.
- Resource row means: spit -37, quill -70, volley -46. Guard (+56) and curl_up (+73) are the strongest rows.
  quill_volley also falls from 6.2 % raw to 0.0 % in the resource equilibrium.
- With the composite row, the resource weight is still 0.0 %. The composite row against the resource equilibrium mix
  scores about -27 hp. curl_up alone accounts for -27.5 of that (cell -160.8). The row also loses to dodge, which reads
  the 5-tick wind-up (cell -6 where bite alone gets +93).

**1c. Range and fleeing: modelled only crudely, and the volley's niches are invisible.**
- Every column is a fixed-move bot that closes in. No column kites or retreats on purpose, so outranging something
  (reach 7 against spit/quill 6) is never rewarded. The volley against spit is -55 raw.
- `max_targets = 2` never matters in a 1v1 duel.

**1d. Meter: evaluated at full meter, and the price is irrelevant.**
- Both seats start the payoff duel with calcium 100, which is 5 volleys. The cooldown allows only 4 in 120 ticks, so
  the meter never limits anything inside a payoff duel.
- The price is 0.25 × the nominal volley value (6.65 hp per volley). With the composite row I tried prices of 0, 0.25 and
  1.0: the resource weight was 0.0 % every time. A price of 1.0 also makes the resource matrix fail its dominance gate.
- The meter's real limit applies across fights (refill by eating), and B6 already tests that.

**1e. A counter-row niche alone does not help.** I added a pierce row against curl_up, a pierce row against active
dodge, and then both together:
- Idle row (current harness): raw weight still 0.0 %.
- Composite row: raw weight 16.9 % / 23.4 % (raw support drops to 5/14), resource weight still 0.0 %.

This matches the ~150 stat settings the report tried: no stat or row change fixes a harness that idles the move and
charges sprint stamina for spacing.

**1f. The volley does matter in full fights.**
- The spiner's field mean is 0.450 at meter 100 and 0.356 at meter 0: **+9.4 points**, with real deaths and real
  stamina over 900 ticks. Each field mean has an SE of about 0.008.
- B5 shows a surprise premium of 48 points.
- So the move is not useless. The resource lower bound measures the harness, not the move.

## 2. Options

| Option | What | Verdict |
|---|---|---|
| A. A second niche from counter rows (pierce against curl_up and dodge, interrupt spit from range, punish retreat) | New rows in `CP_COMBAT_COUNTERS` | **No.** P4 2.6 forbids new rows as a tuning knob. Tested: the resource weight stays 0 and the idle row stays 0. Also moves the combat goldens. |
| B. Retune stats | windup, damage, cooldown, ... | **No.** About 150 settings already tried. B3 cannot pass together with B4/B5 while the row idles. |
| C. Waiver | Accept B3 failing | Weak. Leaves `make tourney` exiting 1, and the next signature move (P6/P8) has the same problem. |
| **D. Model the signature properly and redefine B3 for meter-limited signatures** | Harness fix plus a gate rewrite, no game change | **Recommended.** |

**D in detail.**

1. **Composite signature row.** A Signature-role row plays the signature when it is available. Otherwise it plays the
   build's basic move, which is bite.
   - Why bite: the recipe requires a carnivore jaw at mouth level 2 or more (`cp_combat_move_available`, line 199), so
     every kit that can hold the volley also has bite.
   - It uses the same spacing policy as every ranged row.
   - The rule is chosen by role, not by move id, so P6/P8 signature moves inherit it.
   - This is how the move is actually used. COMBAT-MOVES §1 defines Signature moves as having "long cooldown", so no one
     can use one as a whole policy.

2. **B3 rewritten** for moves with `role == CB_ROLE_SIGNATURE && meter_cost > 0`:

   | Gate | Rule | Now |
   |---|---|---|
   | B3a | Composite row weight in the **raw** equilibrium in [1 %, 35 %] | 13.0 % |
   | B3b | Composite row weight in the **resource** equilibrium <= 35 % (upper bound only) | 0.0 % |
   | B3c | Field marginal value: spiner field mean at meter 100 minus at meter 0 in [+3, +20] points | +9.4 |
   | (kept) | The no-dominance gates over both matrices, now including the composite row | pass |

   - B3a is the uselessness guard: the kit with spines is a best response to some mixture of the counter matrix.
   - B3c is the uselessness guard with real costs.
   - B3a's upper bound, B3b, B3c's +20 ceiling and B4 together are the dominance guard. The volley is never the centre
     of the game, whether stamina is priced or not.
   - The resource lower bound is dropped for signatures only, for three reasons:
     - in this harness it zeroes every ranged move with a cooldown (quill too);
     - it is unaffected by the move's own price (calcium at 0, 0.25 and 1.0 all give 0 %);
     - inside a payoff duel the meter is not binding, so the matrix cannot express "limited by its meter". B6 covers that.
   - The P2 gates for ordinary moves are unchanged.

## 3. Implementation recipe (for Sonnet)

Files: `apps/combat_bots.h`, `apps/combat_bots.c`, `apps/combat_tourney.c`, `tests/test_combat_tourney.c`,
`docs/P4.md` (B3 row), `docs/MOVES-RECIPES-REPORT.md`. Nothing in `core/`.

1. `combat_bots.h`: add `int filler;` to `CpBot`, with the comment "BOT_SPAM: move used while spam_move is unavailable;
   CB_MOVE_NONE = idle (default)". In `bot_init`, set `b->filler = CB_MOVE_NONE` after the memset. This is required
   because memset sets 0, which is bite.

2. `combat_bots.c`, `case BOT_SPAM`: replace the idle line with:
   ```c
   if(!bot_available(me,b->spam_move)){
     if(b->filler!=CB_MOVE_NONE){
       if(bot_available(me,b->filler)&&me->stamina>=cp_combat_move_stamina(&me->prof,b->filler))
         return spaced_attack(b,w,self,foe,b->filler,out);
       out->verb=CB_V_APPROACH;out->target=(int8_t)foe;return 1;
     }
     out->verb=CB_V_IDLE;return 1;
   }
   ```
   - Every existing caller keeps `filler = CB_MOVE_NONE`, so they behave as before. That covers test_combat.c,
     combat_parity.c and the non-signature rows.
   - This is exactly the variant I measured. Do not change the approach-when-broke branch: the numbers below depend on it.

3. `combat_tourney.c` `compute_payoff`:
   - After each `bot_init(&b0/&b1, BOT_SPAM, ...)`, set
     `bX.filler = CP_COMBAT_MOVES[bX.spam_move].role==CB_ROLE_SIGNATURE ? CB_BITE : CB_MOVE_NONE;`.
     Add a comment saying why bite: the recipe requires mouth level 2 or more on a carnivore.
   - Print one line under the payoff header: "signature rows play the signature when ready, bite otherwise".

4. `combat_tourney.c` gates:
   - Move the B3 check out of the `for r` loop.
   - Keep `mix_raw[CB_SPINE_VOLLEY]` and `mix_res[...]`, then check:
     - `B3a raw signature weight in [1%,35%] (observed x%)`
     - `B3b resource signature weight <=35% (observed x%)`
   - In `report_spines`, keep the spiner mean for mode 0 as well as mode 2. Add
     `check(gain>=.03&&gain<=.20,"B3c spines field gain in [3,20] points (observed ...)")`.
   - Factor the arithmetic into `static int b3_ok(double raw_w,double res_w,double gain)` so it can be unit-tested.

5. `tests/test_combat_tourney.c`, new asserts:
   - `b3_ok` truth table:
     - (0.13, 0, 0.094) passes;
     - raw 0.005 fails;
     - raw 0.36 fails;
     - resource 0.36 fails;
     - gain 0.02 fails;
     - gain 0.21 fails.
   - Regression: a `BOT_SPAM` bot with `spam_move = CB_SPINE_VOLLEY` and the default filler issues no attack order while
     the volley is on cooldown.
   - Composite: run 120 ticks at 7 m with calcium 100 (the `duel_setup` and loadout code from `compute_payoff`, both seats
     neutral L3) and `filler = CB_BITE`:
     - the log contains bite orders between volleys;
     - `r.volleys[row] <= 4`.
   - The existing antisymmetry asserts on `compute_payoff(4)` still apply.

6. Expected `make tourney` output (seed offset 0):
   - raw mix: bite 10.6, spit 34.0, tail 18.6, dodge 13.8, roar 1.0, curl_up 8.9, **spine_volley 13.0 %**; support 6/14;
   - resource mix unchanged in practice: spine 0.0 %, support 6/14;
   - no dominance in either matrix;
   - spine row raw mean -30.6 → about +7.9; resource -46 → about -15.
   - Strategy round robin, build field, B4, B5 and B6 are byte-identical, because they never use `BOT_SPAM`.
   - B3c: +9.4 points.
   - Exit 0.
   - Also run `./build/combat_tourney 40 400 1000000` and `... 2000000`: raw 14.1 % / 14.6 %, all pass.

7. Goldens: **none move.** The change is in apps/ only, `filler` defaults to the old behaviour, and the combat and world
   goldens and `combat_parity` do not use a signature spam row. `make test` must still pass unchanged.

8. Docs:
   - P4.md B3 row: replace it with the B3a/B3b/B3c text above, plus one sentence on why the resource lower bound does
     not apply to meter-limited signatures. Add a decision line (owner approval needed: this is a gate redefinition).
   - MOVES-RECIPES-REPORT: replace the "Unmet gate" paragraph with the diagnosis numbers from §1.

**Follow-up, not in scope.** The resource matrix charges sprint stamina used for spacing at the attack-average exchange
rate, and that zeroes quill_volley too (0.0 %). A separate P2-harness item could price movement stamina separately.
Owner call.
