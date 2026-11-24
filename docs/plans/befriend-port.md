# Befriend port plan: social duel, animations, mood card (Opus, 2026-11-24)

Goal: bring the approved befriending design (DESIGN A76–A81, `docs/design/repertoire.md` "Social evolution", "Social duel", "Special charms", "Easter eggs") from the labs into the game, in small mergeable steps. This plan names the work; each step becomes a brief in `docs/briefs/befriend-<step>.md` when it starts. Owner picks are listed at the end. Each default applies after 48 h unless the owner answers.

Sources:
- labs (all in `web/gaitlab/`):
  - `social_duel_core.js`: pure sim, self-check passes. Bot bond times from 20 m are 24.0 / 27.6 / 31.2 s for tiers 1/2/3.
  - `social_duel.html`: the A81 mood card.
  - `befriend.html` + `befriend_core.js`: starter B picks, A77.
  - `befriend_bodies.html` + `bb_*.js`: 4 actions × armed, bird, octopus, snake.
  - `sing_notes.js`: A80.
- node checks: `tools/gaitlab/social_duel_node_check.cjs`, `befriend_node_check.cjs`.

## 1. What exists vs what the lab adds
| Area | Game today (`core/src/stage_social.c`, snapshot 16) | Lab (approved) |
|---|---|---|
| Target state | `trust` 0..100, `mood` −50..50; bond latch at trust 60 | mood point `mx` fear↔trust and `my` calm↔excited; `agg`, `startle`, `flee`, `noticed`, `bond_hold`. Bonded = in the trust-calm corner for `hold` beats |
| Beat | `CP_SOC_BEAT` 12 ticks, ±2 window, per-creature phase (`beat_phase`) | same numbers (lab uses one global beat) |
| Gain | `PREF` per species × timing × combo × habituation × mood | per-action push vector `eff[dx,dy]` × band × timing × tier gain × favourite ×1.4 × streak × chain |
| Distance | each skill has a range; the order walks into range | bands far (>10 m) / approach / close (<4 m); only sing carries at far range |
| Movement reaction | none (timid species flee at 12 m) | run within 14 m scares; sneak and stillness build trust; the target keeps a preferred distance by mood; it bolts at `mx ≤ −0.85` for 7 s; the herd alarms |
| Combos | combo 0..2 for different skills within 20 ticks | call-and-answer chains (length 2/3/4 by tier); wrong or missed answers cost trust |
| Difficulty | species `PREF` rows | tier table: gain, loss, fear, bondX/Y, hold, chain, wrong, off, fav, gate, cd |
| Brain gate | none (no brain organ exists) | `gate` cognitive level: tier 3 needs brain ≥ 3; below it, gain ×0.1 and `mx` is capped at 0.1 |
| Easter eggs | nocturnal ×1.5 at night | `night` (cap 0.15 by day), `fruit` (cap 0.5 until given), `raid` (cap 0.5; defending it bonds instantly) |
| Observe | 3 A22 clues per species teach a move | 3 field notes: favourite gesture, reading, egg hint |
| HUD | beat ring + trust arc on the ground (`ui.set_rings`) | mood card at the top left (A81): portrait, 2D grid, eased dot with a trail; brain 1 fuzzy, 2 sharp, 3 drift arrow + predicted arrow per action |
| Animation | `godot/actions/data/{sing,dance,charm,pose}.json` (older generic) | A77 picks for B and 16 body cells (A80: all accepted) |
| Sing notes | none | glyph notes, one per trill pulse, rise ~1 s, sway, species tint, cracked when wrong |

## 2. The split: C owns the duel, Godot shows it
**C (deterministic, 10 Hz, hashed):**
- mood axes `mx`, `my`
- `agg`, `startle`, `alarm`, `flee`
- noticed, `bond_hold`
- beat read (existing per-creature phase)
- distance band
- tier and cognitive gate
- streak, mistakes, chain state (sequence, phase, index, right/wrong/miss)
- observe hint count
- egg conditions: night from `cp_stage_daylight`, fruit given, raid defended
- herd alarm
- the target's preferred distance and flee steering
- bonding through the existing `check_bond` path (latch, DNA, deeds, ally resolution)

The A81 card axes (`moodAxes`) are a pure read. C computes them for the JSON so Godot never re-derives rules.

**Godot (visual only):**
- action JSON per body type
- the target's reaction poses (ears, posture, step)
- sing notes
- the mood card and its precision by brain level (the card reads `cognition` from JSON; it never decides it)
- predicted arrows, drawn from C's `predict` values in JSON
- camera framing of both creatures
- chain call cues: the target performs the called action, the HUD shows the pattern
- strings, sounds

**Units in C:** mood in 1/10000 (int32). Lab per-second rates divided by 10 become exact integers per tick: sneak +0.05/s → +50, still +0.015/s → +15, run fear 0.28/s → 280. Push vectors are permille × 10 (charm `[.14,−.16]` → `[1400,−1600]`). Tier multipliers are permille. No floats in the rules. Distances stay float compares, as the rest of the stage does.

**Compatibility:**
- One flag, `social.duel_on`, set like `parts.tiers_on`. With the flag off the legacy path runs unchanged, so `tests/test_social.c`, `tests/golden/*` and `tests/test_lineage_social.c` stay green.
- The duel block is hashed only when `duel_on` is set.
- `trust` stays as a derived value, `max(0, mx)·100/10000`, written each beat, so `relationship`, the quest condition `bond_other`, lineage cousin trust and the old HUD keep working.
- The cousin +20 trust perk becomes `mx += 0.2` when the duel is on.

## 3. Snapshot, events, data
- **Snapshot 17** (main is 16; renumber at merge if another branch takes 17): `CpStageDuelCreature duel[CP_STAGE_MAX_WILD]` and `CpStageDuel` (streak, chain, mistakes, hints, raid) inside `CpStageSocial`. Add `LAY` entries in `stage_world.c` and update the version comment in `world.h:25`.
- **Events from 32** (STATUS: next free 32):
  - 32 `DUEL_READ`: value = error in ticks, move = skill, x = hit
  - 33 `DUEL_CHAIN`: move = phase (call / your turn / win / lose / miss), value = index
  - 34 `DUEL_FLEE`: also covers the alarm (value 0 = alarm, 1 = bolt)
  - 35 `DUEL_EGG`: move = fruit / raid / night / gate hint
  - Bonding reuses `BOND_MADE`. Record the ids in STATUS.
- **C data, in code:** a per-species duel table in `core/src/stage_social_duel.c` (tier, favourite, egg, preferred-distance profile) for the 8 defined species, with zero rows for 8..11. The actions table `ACT` (W/A/R already in `CP_STAGE_SKILLS`, plus `eff`) and the tier table go there too.
- **JSON (`cp_stage_social_creature_json`):** `duel:{x,y,state,band,noticed,flee,hold,need,chain:{seq,phase,idx},pred:[[dx,dy]×4]}`. Send `pred` only when cognition ≥ 3. Add `cognition` to the `social` object.
- **Godot data:**
  - `godot/actions/data/{sing,dance,charm,pose}*.json`, regenerated by a new `tools/actions/gen_social_actions.py`, as was done for the context attacks
  - `godot/actions/data/react_{curious,wary,bonded,alarm}.json`
  - `godot/game/data/social/notes.json`: glyph set, rise, sway, life, size by body
  - strings in `godot/ui/strings.gd`

## 4. Steps (one agent each; WIP ≤ 3; C steps by Sonnet 5.5 or Codex)
Every step merges main first and must keep the base gates green:
- `make test`
- `make godot-first-quest-e2e` (30/0)
- `make godot-social-test`
- the snapshot round trip

Steps after S6 also run `make godot-loop-score` on 3 seeds.

| # | Step | Files | Tests | Gate (measurable) |
|---|---|---|---|---|
| **S0** | **Lab at the C clock.** Add `tick:0.1, int:true` to `social_duel_core.js`: 10 Hz step, 1/10000 integer mood, the same rules. Export 8 scripted scenarios as fixtures: per-tick inputs (distance, mode, press, roar), expected per-beat `mx`/`my`/state | `web/gaitlab/social_duel_core.js`, `tools/gaitlab/social_duel_export.cjs`, `tests/fixtures/social_duel/*.json` | selfCheck in both modes | selfCheck passes at 10 Hz int; tier bond times within ±10% of the 60 Hz run (24.0/27.6/31.2 s) |
| **S1** | **C duel kernel (pure).** `cp_duel_tick(CpStageDuelCreature*, CpStageDuel*, const CpDuelIn*)`: passive (run/walk/still), beat read, band multiplier, push with tier cap (`capX`), gate, flee trigger and reset, `bond_hold`, `moodAxes`, `predict`. No world access | `core/src/stage_social_duel.c`, `core/include/cpore/world.h` (types only), Makefile | `tests/test_social_duel.c`: port selfCheck §1–4, §8, plus fixture parity | parity with the S0 fixtures exact at every beat; `make test` green; golden hashes unchanged |
| **S2** | **Wire the kernel into the stage behind `duel_on`.** Inputs: distance from positions; mode from player speed (sprint = run, moving = walk, still = still); the befriend order's existing beat read feeds `press`; `INTIMIDATE` and the roar move near the target feed `roar`; a fruit `GIFT` within 4 m is the charm fruit offer. Bond calls `check_bond`. Trust is derived. Snapshot 17, events 32–35, JSON | `stage_social.c`, `stage_world.c` (LAY, snapshot), `world.h`, `cp_stage_set_duel` | `test_social_duel.c` stage cases via `run()`; snapshot save/load mid-duel; legacy `test_social.c` untouched | a scripted world bonds a Zanco from 20 m in ≤ 40 s of sim; save/load mid-duel gives the same hash; `make test` green |
| **S3** | **Target movement in C.** Preferred distance by mood (9.5 / 6.5 / 3 / 1.8 m; bonded follows at 1.9); facing away when afraid; a 7 s bolt at 4.2 m/s through the existing flee steering; herd alarm (same species within 20 m: alert, then flee) | `stage_world.c` wild AI (the duel only adds a goal; nav and steer do the moving) | `test_social_duel.c` (run at it → flee, herd alarm); `make nav-test` | the lab's run → flee and sneak → approach both hold in C; nav gate 20/20; no stuck creature in `godot-soak` (10 min) |
| **S4** | **Chains, observe hints, night and fruit eggs.** Call-and-answer (seq from the `social` RNG; fixed draws per decision); missed answers; chain cooldown; 3 duel field notes via the observe verb (see Q4); night cap; special-fruit cap and offer | `stage_social_duel.c`, `stage_social.c` (observe) | port selfCheck §5–7 (night, fruit); determinism over 3 seeds | right chain → bonus, wrong → trust loss (same signs as the lab); eggs bond only under their condition; hash stable across 3 runs |
| **S5** | **Mood card HUD (A81).** Top-left card: portrait (reuse the journal portrait render), 204 px grid with 4 corner labels, dot eased with k = 1−e^(−7dt) and a 12-point trail, distance, bond bar. Brain 1 fuzzy dot, 2 sharp, 3 drift arrow; predicted arrows on verb hover. Shown only while a befriend target is locked; it replaces the trust arc in `set_rings` when `duel_on` | `godot/ui/mood_card.gd` (new), `godot/ui/game_ui.gd`, `godot/game/stage/stage_ui.gd` | `godot/tests/ui_test.gd` case on fake JSON (4 corners, 3 brain levels); evidence JPG in `docs/evidence/befriend/card/` | `make godot-ui-test` green; card draw ≤ 0.2 ms per frame; Emil rules (≤ 250 ms, ease-out); owner eyeball |
| **S6** | **Turn the duel on in the game + first-quest bot.** `stage_setup.gd` calls `set_duel(1)`. `first_quest_e2e.gd _friend()`: walk, not sprint, inside 14 m; press on `beat_in`; answer chains from `duel.chain`; keep the sprint catch-up beyond 14 m. Update `social_flow.gd` the same way | `godot/game/stage/stage_setup.gd`, `godot/game/tests/first_quest_e2e.gd`, `social_flow.gd`, `tools/loop/score.py` (bond reason, mistakes) | first-quest e2e, social flow, loop score on 3 seeds | first-quest 30/0 on 3 seeds; bot friend task ≤ 6000 ticks (budget 12000); `befriend_tries` ≤ 3; loop `t_friend_s` no worse than baseline |
| **S7** | **Starter B animations (A77 picks).** Port the trill, bob-and-weave, preen/show-off and crest display from `befriend_core.js` to action JSON (channels: `head.*`, `body.inflate`, `jaw.open`, `display`, `tail.*`, legs `gesture`/`hop`). Emit a `pulse` event per trill note. Add target reactions `react_*` driven by `DUEL_READ` / `DUEL_FLEE` / `BOND_MADE` and by `duel.state` | `tools/actions/gen_social_actions.py`, `godot/actions/data/*.json`, `godot/actions/action_layer.gd` (react hookup) | `godot/actions/test/run_tests.gd`; `capture.gd` side by side with the lab (cpore-media) | action tests green; W/A/R ticks identical to `CP_STAGE_SKILLS`; root drift 0 (`legs` plant/gesture); side-by-side JPG strip for the owner |
| **S8** | **Sing notes in Godot (A80).** Own glyphs (eighth, beamed pair, quarter, plus a cracked set) baked once into an `ImageTexture` atlas from code. Pooled `Sprite3D` or a MultiMesh at the mouth socket, one per `pulse`: rise ~1 s, sway, fade, tint from the species colour. Cracked/dull when `DUEL_READ` misses or the push went against the target | `godot/game/fx/sing_notes.gd` (new), `godot/game/data/social/notes.json`, island hookup | headless test: notes spawned = pulses, all freed by 1.2 s, cracked when x = 0 | ≤ 0.3 ms per frame at 3 singers; owner eyeball against the lab |
| **S9** | **Body-type variants + the pose organ rule.** The `bb_armed`/`bird`/`octo`/`snake` cells become `variants` keyed by caps (`arms`, `wings`, `legless`, `tentacles`) in the 4 social actions. C: pose needs a display organ (cresta, frill_fan, wing_glider/insect/vane, a future colour skin) → reject with `CP_STAGE_ERR_BAD_SKILL` and hide it from `legal_verbs`; the verb bar greys it | `gen_social_actions.py`, `stage_social.c`, `godot/ui/verb_bar.gd` | `test_social_duel.c` (pose without crest rejected); action tests per body; `make godot-creature-fit` | 16-cell capture in the game vs the lab; creature-fit all green |
| **S10** | **Cognition (brain) and tier-3 gate.** Source per Q1. `cp_stage_social_cognition(w)` replaces the S1 stub (1). Card precision and `pred` follow it. Editor shows "unlocks: emotion map" | `stage_parts.c`, `stage_social_duel.c`, editor strings | gate cases: tier 3 at brain 1/2 never bonds and shows the hint once; at brain 3 it bonds | lab §4 gate results hold in C |
| **S11** | **Raid egg.** Spawn or redirect 2 predators from the existing roster to attack the herd; roaring or a fight drives them off; defended = instant bond (egg) or a gratitude push (no egg); 25 s timeout | `stage_social_duel.c`, `stage_world.c` (wild AI goal) | port lab §6 raid cases; first-quest unaffected (the raid species is not a first-quest target) | the 3 raid cases match the lab; no deaths of the player in the raid test over 3 seeds |
| **S12** | **Camera focus during a duel.** While a befriend order is active and the target is within 14 m, ease the boom to frame both creatures (mid-point look, small zoom-out); release on cancel or bond | `godot/game/island/` camera rig | camera suite | 0 snaps / 10 min; occluded frames < 2% (T4 gates) |

**Order:**
- S0 → S1 → S2 → (S3, S4) → S6.
- S5, S7 and S8 need only the existing befriend order and can start right after S0 (S5 against fake JSON).
- S9 after S7. S10 after the Q1 answer. S11 after S3 and the Q5 answer.
- Running 3 at a time: S1 + S7 + S5, then S2 + S8, then S3/S4 + S9, then S6.

**Follow-ups (not in this port):**
- the social evolution tiers (throat sac boom, stomp/hop dance, groom, frill flare…): one brief per organ, after A60 picks
- intelligent-species charms (play, teaching, tool gift, shared language, memory)
- herd leader (A79 Q2)
- allies that fight or scout

## 5. Risks
1. **Float lab → fixed C drift.** Mitigation: S0 makes the lab itself run on the C clock and units, and S1 is gated on exact parity. Same pattern as `tests/combat_parity.c`.
2. **First-quest time.** Lab bonds take 24–31 s from 20 m, but in the game the bot sprints through 85–110 m and a Zanco bolts if sprinted at within 14 m. If the bot misses chains it can regress past 12000 ticks. Mitigations: tier 1 for the first-quest species; S6 gate ≤ 6000 ticks; the sprint catch-up stays outside 14 m.
3. **Movement fights steering.** The S3 preferred-distance goal can fight the timid-flee and herd code. Keep a single wild goal arbitration in `stage_world.c`, and run the nav gate and soak.
4. **Two observe meanings.** The A22 move clues and the duel field notes share the verb (Q4).
5. **Order model vs free movement.** The lab player walks freely. The game's befriend order walks into range and then stands. Chains need repeated presses on specific beats, so each answer is a new befriend order sent on the beat. Check that order re-issue latency (UI → C, 1 tick) fits the ±2-tick window. The S6 bot proves it.
6. **Hash and golden churn.** Hash the duel block only when `duel_on` is set; legacy tests keep the flag off.
7. **HUD clutter.** The ground rings, verb petals and card all compete for attention. With the duel on, the card replaces the trust arc, and the beat ring stays.
8. **No brain organ yet.** The tier-3 gate is untestable in play until Q1 is answered. The S1 stub returns 1, so tier-3 species cannot bond until S10. Do not give a first-quest species tier 3.

## 6. Owner picks (defaults after 48 h)
| Q | Question | Default proposal |
|---|---|---|
| Q1 | Where does **cognitive level** come from? | A new part **`cerebro`** (brain) with levels 1–3 through the existing part levels. The starter is level 1; it is bought in the editor ("unlocks: emotion map, then predicted moves"). |
| Q2 | **Species tiers** | Rondo, Zanco, Babosa, Corona: 1. Espinodo, Brujula: 2. Acechalunas: 3 (night egg). Garfio: 2 (it stays aggressive, and befriending needs calm first, as today). |
| Q3 | **Sneak** has no input in the game | No new key. A39 walk (about 1–2 m/s) counts as the patient approach, sprint scares, standing still builds trust slowly. A crouch key can come later if playtests ask for it. |
| Q4 | **Observe**: duel notes vs A22 move clues | One cycle. The first 3 observations give the duel notes (favourite gesture, reading, egg hint), and further ones give the A22 clues that teach the move. |
| Q5 | **Which eggs in v1, on which species** | Night: Acechalunas. Fruit: Babosa, with a new "golden fruit" item from one flora patch. Raid: Zanco herd, in step S11. |
| Q6 | Keep showing the **old trust number** anywhere? | No. The card's bond bar replaces it; the journal keeps "bonded / trusted / neutral". |
| Q7 | **Rewards equal to hunting** (A78) | Keep the C numbers: bond 8 DNA (a kill gives 6), and an alliance at 3 bonds gives 20 plus the signature part. Revisit after loop score. |
| Q8 | Is **intimidate** the "roar at it" mistake? | Yes. Intimidate, or the roar move within 14 m of the duel target, counts as a roar. |
| Q9 | **Chains in tier 1** (first quest) | Yes, length 2. The S6 bot must answer them. |
