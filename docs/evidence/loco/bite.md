# Starter B bite, four versions (A60 step 1)

Open [bite.html](../../../web/gaitlab/bite.html) with `file://` (local three.js, `bite_core.js` holds the maths). 2x2 grid, one version per cell, game camera by default. Controls: Space play, `,` `.` frame step, 1/2/3 speed (1x, 0.5x, 0.25x), L loop, C or buttons for the camera (game, side, front three-quarter), H hitbox, F or click a cell to enlarge it, Esc back. `?test=1` pauses at t=0; `window.__stylesCheck` holds the self-check.

Body: `godot/game/data/starters/b_runner.json`, no arms, beak "pico" (two mandibles that open and snap). Prey: a Rondo-sized dummy (about 0.7 m long, rump toward the attacker) with a hitbox sphere (r 0.27 m). It flashes and jitters during the hit-pause, squashes (flinch), is knocked back along the beak's horizontal velocity at contact, and its eyes widen. Gold dot = contact point, gold rings = planted feet, a spark burst and a dust puff mark the impact.

Pattern for all four (owner's green-heron notes, video kept local, no frames committed): wind-up, then a clear **hold** (frozen, locked on the target, 300 to 350 ms), then a very short **strike** (110 to 170 ms, the fastest part), **hit-pause** (70 to 80 ms), **hold on** the prey (250 ms) and only then **pull out**, then recovery. Counterbalance with no wings: the tail lifts at the strike (A58 armless rule), the body pitches and plunges after the head, the hind legs extend as it goes.

## The four versions
1. **Peck-snap.** Body stays tall, neck cocked in an S, body rises a little in the wind-up, then the head stabs down from above with a small lean; beak opens at 55 ms before contact and snaps shut on it. Real animal (from memory, unchecked): herons, cranes and ostriches stab with a cocked neck; the freeze is the stalking hold.
2. **Lunge-bite.** Coil low on the hind legs (hips drop 24 cm, head low and back, jaws open), then the whole body drives forward 37 cm over planted feet, front legs braced stiff, the head leads. Real animal (unchecked): crocodilians and theropod reconstructions; dogs lunge with braced forelegs.
3. **Grab-shake.** Bite and hold, then five half-swings of the head (about 4 Hz, body yaw and roll counter-rotating, tail whipping), then the head snaps up and throws the prey about 0.4 m; it bounces once. Real animal (unchecked): terriers shaking rats, Komodo dragons and crocodile death rolls.
4. **Hop-pounce bite.** Deep crouch and hold, a small hop (0.5 m, 170 ms flight, tucked feet, beak first), landing front feet first, the bite lands with the weight; the prey is pinned down. After the hold-on the feet hop back. Real animal (unchecked): foxes mousing, cats, secretary birds stomping.

## Timings (ms, animation time; hit-pause freezes it)
| Version | wind-up | hold | strike | hit-pause | hold on | pull out / shake+throw | recovery | beak to hitbox at contact | planted foot drift | prey knock |
|---|---|---|---|---|---|---|---|---|---|---|
| Peck-snap | 200 | 350 | 110 | 70 | 250 | 120 | 350 | -0.7 cm | 0.0 cm | 12 cm |
| Lunge-bite | 270 | 300 | 150 | 80 | 250 | 170 | 530 | -0.7 cm | 0.0 cm | 26 cm |
| Grab-shake | 220 | 350 | 110 | 80 | - | 760 | 470 | -0.7 cm | 0.0 cm | 8 cm |
| Hop-pounce bite | 250 | 350 | 170 | 80 | 250 | 180 | 440 | -0.7 cm | 0.0 cm | 5 cm |

Sizes scale with the animal: this is small-medium (strike about 0.1 to 0.17 s, whole commitment from wind-up to contact 0.5 to 0.7 s); a big body would stretch the wind-up and hold toward 0.8 to 1 s.

## Self-check (`window.__stylesCheck`)
Contact: closed beak tip within 3 cm of the prey hitbox at the contact frame; hit-pause 60 to 90 ms and a clean freeze; planted feet drift under 2 cm (IK reach never exceeded); no body, knee, foot or beak point below the ground; prey stays above ground; knockback within 0.1 rad-ish (cos at least 0.9) of the horizontal beak velocity; strike 80 to 150 ms (the pounce's hop is longer by design); hold 300 to 600 ms. Result: **pass**. Raw numbers in `bite/check.json`.

## Evidence (`docs/evidence/loco/bite/`)
`grid_contact_game.jpg`, `grid_contact_side.jpg`, `grid_contact_front.jpg` (the four versions at the contact frame, inside the hit-pause), `strip_peck.jpg`, `strip_lunge.jpg`, `strip_grab.jpg`, `strip_pounce.jpg` (six frames each, wind-up to recovery), `focus_grab.jpg`. Regenerate with `NODE_PATH=.../_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/bite_capture.cjs` (SwiftShader).

## Known weak points
Lunge and pounce look alike in the hold (both low coils); the neck is long and thin (starter B data) and stretches up to 1.25x at the strike; front-leg splay as counterbalance is not modelled because feet stay planted.

# Round 2: lunge refinements (A63)

Open [bite2.html](../../../web/gaitlab/bite2.html) (maths in `bite2_core.js`; same controls as round 1). Capture: `tools/gaitlab/bite2_capture.cjs` writes `docs/evidence/loco/bite2/` (`grid_contact_{game,side,front}.jpg`, `strip_{lunge,boom,hybrid,chain}.jpg`, `focus_chain_peck.jpg`, `check.json`, `freeplay.json`, `freeplay_a/b.jpg`).

## The four versions (anim ms; each hit-pause freezes the animation)
| Version | wind-up | hold | strike | pause | hold on | pull out | recovery | beak speed (tip, peak) | prey knock | neck stretch | front-leg lean at contact |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 Lunge (round 1, unchanged) | 270 | 300 | 150 | 80 | 250 | 170 | 530 | 10.7 m/s | 26 cm | 1.18 | 45 deg |
| 2 Explosive lunge | 320 | 300 | 110 | 80 | 200 | 170 | 580 | 15.3 m/s | 32 cm | 1.00 | 39 deg |
| 3 Lunge + peck hybrid | 310 | 310 | 140 | 80 | 230 | 160 | 550 | 15.4 m/s | 30 cm | 1.04 | 32 deg |
| 4 Lunge, then peck-snap | 240 | 300 | 130 + 85 | 80 + 60 | 90 + 60 | cock 130 | 425 | 7.2 m/s | 10 + 10 cm | 1.00 | 32 / 41 deg |

- **2 Explosive:** hips drop 34 cm (round 1: 24), body drives 46 cm in 110 ms, tail counter-lifts 0.72 rad (round 1: 0.4) after a deeper tail tuck, prey knocked 32 cm with a bigger hop, squash and tilt, dust kicked from both hind feet at drive-off, front feet skid forward 20 cm.
- **3 Hybrid:** the neck stays cocked in an S and carried low (head 10 cm below rest) through the hold and the body drive, then the head whips forward the last 15 cm in 50 ms (cubic ease) while the jaws open; lunge body drive is a little shorter (43 cm), front feet skid 16 cm.
- **4 Chain:** lunge-bite, a 90 ms hold on, then the head cocks back (130 ms) and a light peck (85 ms) hits the prey that was knocked loose (second hit-pause 60 ms, second flinch). The peck follow-up from cock to recovery plus its pause is 760 ms (limit 800).

## Fixes to round-1 weak spots
- Neck stretch capped at 1.08 (checked on versions 2 to 4, they peak at 1.00 to 1.04): the body moves more (bx up to 0.5 m) and the contact point sits on the prey's low rear (flatter beak angle), so the neck folds instead of stretching. Round 1 stays as the reference at 1.18.
- Neck carriage: contact is lower and flatter, the neck no longer rises like a giraffe at the hit (side-camera grid); the rest and recovery pose is still the long starter B neck.
- Front-leg splay: front feet skid forward 12 to 22 cm during the drive (dust, gold ring turns dim while swinging) and stay put, then return in recovery; lean at contact drops from 45 to 32 to 39 deg. Hind feet stay planted (checked: zero slide, drift 0).

## Self-check (`window.__stylesCheck`): pass
Per hit: beak within 3 cm of the hitbox (all about -0.5 cm), hit-pause 60 to 90 ms clean freeze, knockback along the beak velocity (cos 1.0), no reach error. Per version: planted hind feet never move, nothing below ground, strike 80 to 150 ms, hold 300 to 600 ms, neck stretch at most 1.08 (not applied to the round-1 reference), chain peck follow-up at most 800 ms, prey state finite for every integer animation ms.

## Free-play check (the round-1 freeze lesson): pass
`freeplay.json`: page loaded WITHOUT `?test=1` in headless Chromium (SwiftShader) for 4.7 s, zero page errors, the frame counter and the animation clock advance, and two screenshots (`freeplay_a.jpg` at 433 ms, `freeplay_b.jpg` at 1650 ms) show different poses. Also fixed a negative first frame dt in the tick loop.

## Weakest
- In the hold of versions 1, 2 and 4 the head is tucked low behind the shoulders and is partly hidden in the game camera; the lock-on gaze reads best in version 3 (cocked S neck, head visible).
- Versions 2, 3 and 4 look alike in the single contact still (same body, same prey): they differ in motion (depth of coil, dust, the head whip, the second hit), so judge them in play or in the strips.
- The chain's peck is a light dip on a prey that slides only 10 cm; a bigger second target move would show the follow-up more clearly.
