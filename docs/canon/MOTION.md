# Motion canon

The owner's taste for creature movement, written down so agents can judge their own work without asking. Agreed 2026-11-21 (taste session round 1, tracker D-21). Changing this file is an owner decision.

## 1. Realism level: real mechanics, slightly exaggerated
Weight, balance and real gaits, with enough exaggeration (posture, roll, bob) to read from the strategic camera. Model: the Spore gorilla knuckle-walk (`~/Desarrollo/cpore-refs/videos/spore-gorilla-knucklewalk.mp4`). Not cartoon bounce; not documentary subtlety.

## 2. Size sets the rhythm
Big creatures feel heavy: slow to start and stop, body sways, the ground takes the hit. Small ones feel nervous: quick steps, sudden stops. Use real scaling: stride and cadence follow the Froude number (speed ∝ √(leg length·g)); mass slows acceleration and turning (A29, G78).

## 3. Strange bodies walk clumsily but believably
Impossible builds (legs on one side, huge head on tiny legs) still move: limping, dragging, compensating, leaning the body over the support. Never blocked, never perfectly smooth. Clumsiness must come from the body's real support and balance, not a random wobble.

## 4. Mood later
Mechanics first. Later, a small mood layer: hurt (cautious, favouring a side), alert (head up, quick glances), calm.

## 5. Failures (any of these fails a review)
| Failure | Scorecard metric | Target |
|---|---|---|
| Feet sliding on the ground | `foot_slip_cm` p95 | < 3 cm |
| Legs bending the wrong way | `knee_flip_frac` | 0 |
| Body floating without weight | `torso_bob_cm`, `leg_extension` | bob present at each step; legs carry the body |
| Robotic perfect symmetry | `gait_symmetry`, visual | small natural variation (recorded; target set after measuring references) |
| Spinning on the spot | `pivot_frac` while moving | < 0.05 |
| Legs through the ground | `foot_penetration_cm` p95 | < 1 cm |
| Head staring at the sky | `head_pitch_deg` | within ±12° of level when walking |
| Gallop that is a fast walk | `airborne_frac` in gallop | > 0.05 (0 in walk) |

## 6. References
- Main: Spore gorilla knuckle-walk (above); owner's Spore captures `~/Desarrollo/cpore-refs/spore-captures/`.
- More references to be proposed by Claude and approved by the owner (tracker D-22), each measured with the scorecard like the gorilla.

## How agents use this
Every motion change: run the scorecard (`.claude/skills/cpore-motion`), check §5, compare with the references side by side. If the numbers improve and nothing in §5 fails, it may merge without asking the owner (A33). Taste questions this file does not answer go to the weekly batch.
