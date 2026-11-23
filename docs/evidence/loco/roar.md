# Starter B roar, four versions (A61 step 3, control move)

Open [roar.html](../../../web/gaitlab/roar.html) with `file://` (local three.js; maths in `roar_core.js`, body rig from `bite2_core.js`, foot segments and IK from `pounce_core.js`). Same shell as the bite and pounce labs: 2x2 large cells, camera buttons (game, side, front 3/4), 1x / 0.5x / 0.25x, frame step, loop, timing bars (blue tick = the ring reaches 4 m), click or `F` to enlarge, `T` cycles the frame (wide, ring, close on B), `H` toggles the 4 m range circle. `?test=1` pauses at t=0; `window.__stylesCheck` holds the self-check; headless node check: `node tools/gaitlab/roar_node_check.cjs`. Capture: `NODE_PATH=.../_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/roar_capture.cjs` (SwiftShader), writes `docs/evidence/loco/roar/`.

Game numbers (`core/src/combat.c`, 10 ticks per second): roar is 6 ticks wind-up (0.6 s), 1 active tick, 6 recovery, range 4 m, full circle (`CB_F_SWEEP`, arc 2 pi), fear status 12 ticks (1.2 s), role control, part throat. A roar interrupts a charge in its wind-up (`CB_CHARGE` row). In the lab the active tick is drawn as a ring that expands to exactly 4 m (`1-(1-u)^2.2`, 250 to 820 ms by version), and a dummy reacts the moment the front reaches it. Camera is fixed per version.

## Scene
Four dummies around B (distances from B's body centre): a red **charger** that is mid-charge (5 m/s when the ring reaches it at 3 m, so it is clearly stopped by the roar), two tan **timid** animals at 2.9 and 3.3 m, and a **control** animal at 5.0 m that must not react. Reaction: eyes wide, ears pinned back, squash and flinch, a 0.2 m shock push; the charger skids about 1.1 m with dust and a nose dip, rocks, then backs off 0.4 m and stays (about 2.3 m from B at the closest); timid ones hop, turn in about 0.3 s and run for the fear time (1.2 s, 2.5 to 4 m). Ground reads the blast: grass blades bend outward when the ring passes, debris is thrown out and up, dust rides the ring front, thin air-distortion arcs leave the mouth, and the camera micro-shakes at the peak.

## The four versions (anim ms from B's first move; the lab adds a short "watch" lead so the charger is mid-charge at the ring)
| Version | wind-up to roar | roar (mouth open) | ring to 4 m | after | pose and what reads | camera shake |
|---|---|---|---|---|---|---|
| 1 Rear-up | crouch 220, rear up 400 (emit at 620) | 600 (mouth 668 ms) | 460 ms, echo 520 | drop 300, land with dust, recover 430 (end 1950) | hind legs only, fore feet tucked, body and neck about 60 deg up, head 1.7 m high, beak up, chest swells, throat pulses | 3 cm decaying at the peak, small at the landing |
| 2 Low bellow | brace 420 (fore feet step wide), breath 100 (emit at 520) | 1220 rumble (mouth 1160 ms), jaw flutter 7 Hz, throat pulse 10 Hz, 3 rings | 820 ms each, 330 ms apart | ease 220, recover 440 (end 2400) | body 16 cm lower and pitched down, neck extended 13 %, head low and forward, tail low and trembling | sustained 23 Hz rumble |
| 3 Screech | inhale 150 (head cocked back, chest and throat full), snap 45 (emit at 195) | 275 (mouth 278 ms), 30 Hz head tremor | 250 ms, sharp single ring | small hop back 250 ms (0.3 m, apex 7 cm, all four feet off the ground), recover 430 (end 1150) | head snaps forward and up, mouth to 1.3, throat swells | 4.5 cm, 80 ms decay |
| 4 Display | turn side-on 330 (two double-steps, nose faces the charger then flank to it and to the game camera), stand tall 310 (emit at 640) | 800 sweep (mouth 800 ms), head arcs from the threat side across the front (hyaw -0.8 to +0.85), 3 rings | 640 ms | hold display 320, relax and turn back 690 (end 2450) | crest up and flushed, tail raised, chest out, taller stance | 2 cm then a 14 Hz tremor |

Size scaling: B is small-medium, so wind-up is 0.5 to 0.65 s (game 0.6 s) and the voice is short for the screech (under 0.3 s) and long for the bellow. A big body would stretch the rear-up to 0.8 to 1 s and slow the drop. Weight shifts: crouch and rock back before the rear-up, hips forward over the braced front legs for the bellow, a dip before and a dip after the hop.

Real animals (from memory, unchecked): 1 a lion or bear rearing up with the chest out; a horse or stag rearing; 2 a lion's low rumbling roar with the head dropped and the body braced, a crocodile or alligator bellow (water dances on the back); a howler monkey's chest and throat sac; 3 a bird alarm screech (jay, hawk) with a sharp head snap and a hop or wing flick, an owl's hiss; 4 a frilled lizard or a bearded dragon flaring the frill, a cat or an iguana turning side-on to look larger, a rooster or stag throwing its head to sweep the area.

## Self-check (`window.__stylesCheck`): pass (raw numbers in `roar/check.json`)
Ring ends at exactly 4.000 m at its peak and never beyond; every dummy inside range reacts, and only after the ring front reaches it (front within 0.12 m of its distance), the 5 m control never moves or flinches; timid ones do not move before the ring and flee 2.5 to 4 m; the charger is at 5.0 m/s (mid-charge) when hit, is stopped (speed under 0.08 m/s 1.1 s later) and never gets within 1.2 m of B (closest 2.26 m); feet planted: planted-segment drift 0.0 cm (limit 2 cm), IK out of reach under 2 cm, geometry above ground; neck stretch at most 1.20 (cap 1.22); wind-up 520 to 640 ms for the three long versions, the screech 195 ms, the screech mouth open 278 ms (limit 300), rear-up hold 668 ms, bellow 1160 ms; rear-up head at least 1.25 m; display crest and tail raised at the roar; dummies finite and above ground.

## Free-play check (the round-1 freeze lesson): pass
`roar/freeplay.json`: page opened WITHOUT `?test=1` in headless Chromium (SwiftShader), about 4.7 s, zero page errors, frame counter and animation clock advance, two screenshots (`freeplay_a.jpg`, `freeplay_b.jpg`) differ.

## Evidence (`docs/evidence/loco/roar/`)
`grid_peak_{game,side,front}.jpg` (four versions as the ring crosses 2.2 m), `strip_*.jpg` (six frames each, ring framing: before, emit, ring, charger hit, charger stopped, flee), `pose_*.jpg` (six close frames on B only), `focus_*_peak.jpg`, `check.json`, `freeplay*.{json,jpg}`.

## Weakest
- The beak is small, so a wide mouth reads from the dark wedge inside it and the throat sac rather than from the jaws; the rear-up and bellow are the clearest from the game camera, the screech is the subtlest at 1x (its whole voice is 0.28 s).
- Dummy flinches (eyes, ears, squash) are readable only in the ring or close framing; in the wide frame mostly the run-away and the skid read. Timid ones run toward the camera and leave a tight frame.
- Tail counter-balance in the rear-up is modest (the rig's tail pitch sign was tuned by eye); the fore legs tuck as a simple fold.
- Display: the turn is two double-steps (no walking turn), and the sweep is an arc of about 100 degrees of head swing plus air arcs, not a literal 360; the full-circle fear comes from the ring.
- Ring, grass and debris are lab visuals; a real game would drive them from the C event (roar emits fear to everything in 4 m), the reactions here are scripted dummies, not the AI.
