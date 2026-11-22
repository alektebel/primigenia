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
