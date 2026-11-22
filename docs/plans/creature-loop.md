# Creature-stage loop plan (Opus, 2026-11-22)

Owner goal: "tune and perfect the creature stage loop from start to finish". Questions for the owner: `creature-loop-questions.json` (seeded into the in-game queue). Each task below becomes a brief when its wave starts.

## Key findings
1. **Load time is probably GPU shader compilation, not code.** The owner's RTX takes 46 s (stage_setup 15.7 s, creatures 19.9 s); software GL takes 11–18 s (stage_setup 2–11 ms, creatures 2 s). `island.gd` charges each awaited frame to the next phase. Agents can't measure the GPU, so the owner's log is the measurement. nav_warm takes another 4–7 s on the CPU.
2. **Only one cousin fits.** The roster fills 23 of 24 wild slots. Raising `CP_STAGE_MAX_WILD`/`SPECIES_COUNT` needs a C change and a snapshot bump (T9), which also lets new species in.
3. **No game events exist yet.** Add one signal, `Game.loop_event(name, data)`, used by both the question triggers and the scorecard.

## Loop, beat by beat
| Beat | Today | Main problems |
|---|---|---|
| Menu | New game starts as the starter (B, A40); the creator is a separate button | A25 "few parts, small budget" not built (Q12) |
| Load | Veil with phases; re-entry 3–5 s | 46 s cold on the RTX; RadialFauna.plan runs twice; one body build per individual |
| Creator | Studio, edit anywhere | Dev builds keep all parts (A31) |
| Spawn | Quest card, minimap ping | Opening view faces Garfio, not the goal; target shown only on the minimap (Q1, Q4) |
| Move/camera | jog 5.2 / sprint 8.84 today, 2 m/s after A39 | 10 Hz sim, up to 100 ms root lag; pivots on reversals; camera clears only terrain (not trunks, rocks or caves) and the boom snaps |
| Eat | Bite cycle | Mouth may not reach the food |
| Hunt | Bite key 1; prey 85–110 m away | Catchability at 2 m/s unknown; 40–70 s walk (Q5) |
| Befriend | Rhythm 1–4, gift, trust 60 | Generous bot budgets hint at friction (Q6) |
| Dig | X / ring, 2 s | Body doesn't move while digging |
| Wings | Bed 22–48 m away, gives wing_vane and fire_gland | No fly step; flight is a dev mode (Q7) |
| Fire | Editor, fire_gland, flame move | The editor is hard to find |
| Evolve | Spends DNA, new generation | No event or feedback; Garfio difficulty jumps (A31) |
| Cousins | One per generation | Only 1 fits (Q8) |
| Next / end | Chain ends at fire | No chain 2, progress bar or end card (Q9, Q43) |

## Loop scorecard (`make godot-loop-score`, T1); every target is a starting value
- **Time to each beat (owner session, from island_ready):** first input ≤ 10 s, first select ≤ 2 min, hunt ≤ 6, friend ≤ 12, dig ≤ 14, wings ≤ 18, fire ≤ 25, cousin seen ≤ 27 min (MVP Gate 1 "chain in 20–30 min"). The bot must stay inside the e2e budgets and fail on a regression above 20%.
- **Deaths and retries:**
  - deaths before the first evolve: bot 0, owner ≤ 1
  - ≤ 2 fights per kill and ≤ 3 befriend tries
  - Garfio win rate 35–80%
- **Load (owner RTX):** cold ≤ 15 s, re-entry ≤ 5 s, creatures ≤ 2.5 s, stage_setup ≤ 0.3 s.
- **Frames:**
  - high ≥ 60 fps
  - low ≥ 30 (p95 ≤ 33 ms)
  - medium ≥ 45
  - agent script time ≤ 8 ms per frame with 24 creatures
- **Latency:** root p95 ≤ 100 ms, first visual reaction ≤ 50 ms (83 ms today).
- **Camera:** occluded frames < 2% in forest and cliff; 0 snaps per 10 min.
- **Dead time:** no stretch > 90 s without progress or a stimulus; ≤ 10% of the first 30 min (G70).
- **DNA:** ≥ 30 at the fire step without extra kills; a chance to spend DNA every 10 min.
- **Novelty:** at least 1 per 15-min window (G71).
- **Species:**
  - ≥ 4 distinct in the first 10 min
  - ≥ 8 by 30 min, ≥ 12 after the food-web import
- **Creature-bug gates:** MOTION §5 plus creature-fit on all starters and species.

## Backlog (WIP 3, merge in 48 h)
| # | Task | Done when | Depends on |
|---|---|---|---|
| T1 | Loop telemetry (`Game.loop_event`, JSONL recorder, agent cmd, wander bot) + loop scorecard | All metrics filled on 3 seeds; bot runs deterministic; owner session parses | owner-q (signal) |
| T2 | Load time: per-frame stall log, shader warm-up under the veil, one body/materials build per species, plan once, nav_warm overlapped | Owner RTX cold ≤ 15 s, re-entry ≤ 5 s; software entry_bench no worse | — |
| T3 | Controls: starts, stops, turns, latency (root extrapolation, arc turns, mass braking in C) | Latency gates met; pivot < 0.05; stop ≤ 0.4 s; feel suite green | speed-gait, T1 |
| T4 | Camera occlusion and no snaps (sphere-cast, prop colliders, eased boom) | < 2% occluded, 0 snaps | T1 |
| T5 | Creature bugs A: fit and skin for B and the roster (limb UVs, belly cap, horns) | creature-fit all; plastic_shine 0; night ratio ≤ 3 | owner-q |
| T6 | Creature bugs B: eat reach, dig motion | Mouth ≤ 5 cm; dig pitch ≥ 15° + scratch; knee flips 0 | speed-gait |
| T7 | First minute: spawn direction, in-world cue | Owner first select ≤ 2 min; no 90 s dead time in the first 5 min | T1 |
| T8 | Hunt and befriend tuning | ≤ 2 fights per kill, ≤ 3 tries; B beats Rondo ≥ 90%; Garfio 35–80% | speed-gait, T1 |
| T9 | Roster v9 in C: MAX_WILD 32, SPECIES 12, cousin slots kept free, one snapshot | 3 evolves leave 3 cousins; cousin ≤ 40 m from the nest; replays exact | speed-gait, Q8 |
| T10 | Food web phase 1: ambient small life (visual, weights from the pyramid) | ≥ 8 species in 10 min; ≤ 1 ms per frame | T1 |
| T11 | Food web phase 2: 4 C species (Llorona, Bello-pico, Garra marea, Cazanoche) | Win rates in window; ≥ 12 species by 30 min | T9, Q11 |
| T12 | Wings → fly beat; editor discoverability | Per Q7; wings→fire ≤ 7 min | Q7, T1 |
| T13 | Evolve feedback and cousin moment | Cousin within 5 s, visible within 60 s; no Garfio death in the first 2 min | T9 |
| T14 | Close the stage: chain 2, progress bar, end card, save | Bot finishes on 3 seeds; novelty gap ≤ 15 min over 60 min | Q9, T1, T13 |
| T15 | Pacing and frame-time pass | Dead time ≤ 10%; low ≥ 30, medium ≥ 45 fps (owner run) | T10, T14 |

**Waves:**
1. T1, T2, T5 (T2 now)
2. T3, T4, T9, after speed-gait
3. T6, T8, T10
4. T11, T12, T13
5. T14, T15

C work goes to Sonnet only; the GDScript parts can go to Codex.
