# Context-adaptive attacks study (A72)

Lab: `web/gaitlab/attack_context.html` (core `attack_context_core.js`, sim `attack_context_sim.js`, scenarios `attack_context_scen.js`).
Capture: `NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/attack_context_capture.cjs` (SwiftShader only) writes this folder's JPGs: `docs/evidence/loco/attack_context/`.

Purpose: owner picks, one per attack and context, before C gets an attack-while-moving state and distance bands (A72). Nothing here is selected for the game.

## What the lab shows
4 attacks (rows) x 4 contexts (columns), starter B (lean runner, no arms, beak). Same shell as `bite2.html`: cameras Game / Side / Front 3/4 plus a moving **Follow** camera (Auto = follow in moving cells, game view when standing), 1x / 0.5x / 0.25x, frame step, loop, timing bars with a playhead, hit-pause marker, hitbox toggle. **Option A / B** switches every cell to its second option (cells with one option show A, tagged). **Show** switches between all 16 and one attack in 2x2 large cells. Star one option per cell; **Copy choices** writes `<attack>: <context>=<variant>; ...` (one line per attack; stars live in localStorage, wrapped in try/catch). **From far, B starts** standing or walking rebuilds the four far cells.

Contexts: standing; walking (sprawl walk 1.9 m/s, target walking 1.2 m/s); galloping (rotary gallop at 3.2 m/s, target fleeing at 2.2 m/s); from far (target 11 to 14 m away, B standing or walking, target stationary).

Source animations reused: bite = `bite2` version 3 (lunge + peck hybrid) at the A71 fast timing; charge/tackle and cat pounce = `pounce.html`; jet, glob, lob = `spit.html`; rear-up and bellow = `roar.html`. Legs run the real A42 patterns from `styles2.html` (sprawl walk, rotary gallop; offsets, duty, lift, bob, rock as in the lab) with event-driven feet: a foot lifts when its phase crosses the duty factor and lands on the point where the body will be at mid-stance, so stance feet never slide.

## Grid and options (A = first option, B = second)
| Attack | Standing | Walking | Galloping | From far |
|---|---|---|---|---|
| bite | `lunge-peck` (the bite, 1 option) | A `on-the-move` / B `slow-step` | A `snap-in-passing` / B `bite-drag` | A `charge` (dash-tackle) / B `run-up-snap` |
| pounce / charge | A `cat` / B `quick-spring` | A `gather-leap` / B `leap-off-the-stride` | A `leap-from-gallop` / B `dash-tackle` | A `run-in-leap` / B `run-in-brake-pounce` |
| acid spit | A `jet` / B `glob` | A `jet` / B `glob` | A `sideways-parting-shot` / B `forward-lob` | A `llama-lob` / B `charged-lob` |
| roar | A `rear-up` / B `bellow` | A `bellow-on-the-move` / B `halt-rear-up` | A `bellow-on-the-run` / B `brake-and-rear` | A `run-in-plant-rear` / B `bellow-in-stride` |

31 scenarios (16 cells, 15 with a second option). Key differences the owner is choosing between: layered (legs never stop) against commitment (brake, plant, then the move); head-only against a lunge with body momentum; tackle against bite for the end of a run-up.

## Porting notes for C (starting values, not decisions)

### Attack-while-moving state
- **Gait owns the legs and the root path; the attack is a layer.** Layer channels (all additive on the gait pose, time relative to the anchor = contact / fire / emit): body lunge along heading `bx`, dip `by`, pitch, front-spine `sp`, neck offset `hd` (3D), head pitch, gape, neck stretch, tail pitch/yaw, plus throat / chest / cheeks / glow. Every channel starts and ends at 0, so the recovery blends back into the gait without a stop.
- **Lunge and dip scale with context** (bite): standing 0.40 m / dip 1.0; walking 0.12 to 0.20 m / dip 0.3 (the sprawl walk is already 0.22 m low); galloping 0.06 m / dip 0.3. A foot lunge on top of a moving body over-stretches the planted legs (4 to 9 cm in the lab), so moving lunges stay small and the head does the reach.
- **Head contact is solved every frame** against the moving hit sphere (R 0.27): beak tip to `centre + dir * (R - 0.006)`, neck stretch aimed at about 1.05 (cap 1.08 at the contact frame). Before the contact the head blends from the free carry (S-neck) to the solved pose over the last 70 ms.
- **Feet:** `noForce` windows (standing bite, pounce, tackle, rear-up) stop the gait from stepping while the layer owns the stance; all other cells keep stepping. A stance foot that becomes over-extended (> 97.5 % of the leg) takes a forced step; an idle creature tidies its feet one at a time (0.3 s after stopping).
- **Commitment moves** (allowed to stop the gait): pounce flight and landing (all four feet airborne 0.5 s, pin 0.48 s), charge impact (speed 4.2 to 1.5 m/s in 0.13 s, 0.4 m/s at +0.5 s, walk again by +1.2 s), rear-up roar (stop, 0.62 s crouch and rise, hold 0.6 s, 0.28 s drop), brake before a standing move (gallop 3.2 to 0 m/s in 0.9 s; walk 1.9 to 0 in 0.7 s) with `skid` feet.
- **Hit-pause** 60 to 90 ms as `impact_fx.gd` (bite 70, pounce 80, tackle 90, glob 90, lob 60, jet and roar 0): the whole action layer and both creatures freeze, fx and flash keep running; contact flash 0.32 decaying over 0.11 s; dust at take-off, landing and the tackle; a spark burst at the contact point; acid splash at the projectile impact.

### Distance bands (what the lab used; A72 bands in bold)
| Band | Lab number | Move |
|---|---|---|
| close, standing | target centre 1.5 m from the pivot (1.1 m ahead of the lunged body) | **bite**: lunge + peck |
| 3 to 5 m | pounce start gap 3.5 m (standing, walking), 3.7 to 3.8 m (from the gallop); flight 0.5 s, 5.3 to 8.1 m/s horizontal | **cat pounce** (A64); leap from gallop |
| 5 to 20 m | run-up 11 to 14 m from a standing or walking start | **charge**: burst start, 4.2 m/s at the impact |
| gallop, target ahead 1.1 to 1.3 m | closing speed 1.0 m/s | **bite on the run** |
| spit | jet 5 m (flight 0.16 s at 26 m/s); glob 5 m (0.81 s); lob 9.5 m (1.12 s, apex 2.3 m); glob lob 9.5 m (1.27 s, apex 2.8 m) | jet close to mid, **llama lob** far |
| roar | plant at 3.2 m, ring radius 4 m (game), ring front reaches 3 m in about 0.3 s | rear-up; bellow shown on the move |
A72's table (jet close or mid, lob far, parting shot when galloping) is what the lab shows; the lab's lob range 9.5 m is only a starting value (the game's spit range is 6 m).

### Momentum (starting values)
- **Knockback impulse** (m/s along the hit direction, decaying at mu per second): `v0 = base + 0.5 * closing_speed`, clamp 4.5. Lab: bite standing 2.5 (mu 7, slides 0.36 m); walking 2.6 to 3.4; galloping snap 4.1 (1.6 forward, 3.8 sideways, closing 1.0); charge 3.8 plus the 4.2 m/s run (mu 5, target rolls 1.5 rad, down 1.15 s); dash-tackle from a gallop 3.6 (mu 5).
- **Overshoot and wide turn** after a snap on the run: speed 3.2 to 2.9 in 0.7 s then 2.6; heading change 0.5 rad over 1.4 s. After a charge-end snap (4.2 m/s): 4.2 to 3.4 in 0.8 s, 0.55 rad over 1.5 s.
- **Bite and drag:** hold the contact up to 1.0 s while B brakes 3.2 to 0.2 m/s (skid window), the target is carried rigidly 1.1 to 1.3 m ahead, then 0.16 s to let go; target slides on with B's speed (mu 5).
- **Exposure on a miss** (not animated): a missed snap or charge costs the overshoot distance above plus roughly 0.5 s before the creature can turn (the wide turn is the cost).

### Projectile leading
- One ballistic shot per frame of the 0.2 s stream (jet) or one gob. Muzzle position is the beak at the fire frame; the aim point is the target's predicted position at fire time + time of flight, found by fixed-point iteration (4 passes); launch velocity = the ballistic solution `v = (A - m)/t + g t / 2` for that time of flight (jet: t from a 26 m/s muzzle speed; glob 0.85 s; lob 1.15 s; far glob 1.3 s). The head yaw and pitch follow the launch direction through the 0.2 s stream (the creature moves 0.64 m at gallop during the stream).
- Lead distance measured: walking jet 0.18 m, walking glob 0.97 m, galloping jet 0.40 m, galloping lob 1.89 m. Faint green line = predicted trajectory, ring = intercept point, line from the target to the ring = the lead.

## Self-check (`?test=1`, runs for both far starts)
- Contacts: bite beak tip, pin-pounce beak tip and tackle chest within 3 / 3 / 4 cm of the hit sphere at the contact frame; neck stretch at a beak contact <= 1.08.
- Feet: stance feet stay on their plant within 2 cm (outside the documented `noForce` / skid windows); IK reach error <= 2 cm outside the 0.12 s take-off push-off.
- Projectiles: second derivative of the sampled arc = -9.81 m/s^2 within 2 %; at least 90 % of the shots hit the moving target within 0.30 m; never below the ground.
- Nothing through the ground (body 1.2 cm, targets 1.5 cm); target never inside the creature's body line (0.3 m) outside the contact and pin windows; roar ring reaches the target; hit-pause 60 to 90 ms; hit time exists.
- Result: see `check.json` (pass for both far starts) and `freeplay.json`.

Free play (no `?test=1`): 4.7 s in headless Chromium with SwiftShader, zero page errors, `freeplay_a.jpg` and `freeplay_b.jpg` differ.

## Known weak points
- A hind or front foot can step forward early while the neck is mid-strike at the gallop-to-walk change during a hard brake (bite-drag, roar from far); the skid window excuses it in the check, the eye may still catch it.
- Roar targets flinch and run but have no real "scared" pose; the target is a turtle-like prop, so a fear animation reads small.
- The cat pounce has no step-off back: after the pin the creature stays on top (the lab's step-off was dropped for the moving contexts).
- A miss variant is not animated.
