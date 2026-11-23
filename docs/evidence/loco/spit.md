# Starter B acid spit, four versions (A62 poke move, starting-4 slot)

Open [spit.html](../../../web/gaitlab/spit.html) with `file://` (local three.js; maths in `spit_core.js`; body rig from `bite2_core.js` and `pounce_core.js`). Same shell as the pounce lab: 2x2 large cells, game / side / front 3/4 cameras, 1x / 0.5x / 0.25x, frame step, loop, timing bars (the hit-pause is a white block), hitbox toggle, click or `F` to enlarge. The game camera stays on the throat during the wind-up, widens at the release and closes in on the prey as the projectile arrives. `?test=1` pauses at t=0; `window.__stylesCheck` holds the self-check. Capture: `NODE_PATH=.../_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/spit_capture.cjs` (SwiftShader), writes `docs/evidence/loco/spit/`.

Starter B gets a small **spit gland in the throat**: a pale-yellow sac that bulges on the neck (pulses travel from shoulder to head), cheeks that puff, and a faint green glow at the throat and mouth.

Game numbers (`core/src/combat.c`, 10 ticks per second): spit is 6 ticks wind-up (0.6 s), 1 active, 4 recovery, range 6.0 m, status SLOW for 20 ticks (2.0 s), role poke, flag RANGED. Prey stands 5.5 m from the creature centre (3.7 m for the spray). Prey hitbox: sphere of 0.52 m (the body plus the face).

## The four versions (anim ms; t=0 is the start of the wind-up)
| Version | wind-up to release | release | projectile | flight to hit | prey hit (tc) | hit-pause | impact |
|---|---|---|---|---|---|---|---|
| 1 Aimed jet (cobra) | 700 (neck rises and pulls back 300, throat pulses 300-490 and 470-660, mouth opens 560-650) | 700 | 41 droplets one every 5 ms, 26 m/s, tapered bright tube (inner core plus glow shell), drops 0.2 m over the flight | 169 ms | 869 | none (continuous stream) | thin splash, small drops, a few specks stuck on the face; light flinch and push |
| 2 Lob (llama) | 640 (head tilts back to 66 deg, cheeks and throat swell, mouth opens at 530) | 640 | one gob (r 9 cm), 6.3 m/s at 54 deg, apex 1.3 m above the mouth (2.4 m above the ground), glowing with a dotted trail | 1126 ms | 1766 | 60 ms | splat on the face, 16 droplets in a ring, medium flinch and hop |
| 3 Spray burst | 520 (draw back, cheeks puff, mouth half open) | 520 to 1160 | about 240 droplets, 7.6-11 m/s, cone half-angle 10 deg, head sweeps +/-14 deg (1.1 cycles, 600 ms), range 2.5-4.5 m | first hit 769 (75 of 240 droplets hit) | 769 | none | spotty tint, many small specks, constant shiver, tiny bounces |
| 4 Charged glob | 1150 (brace and widen stance 300, throat glow ramps and body shudders until the release) | 1210 | one big glob (r 17 cm), 6.3 m/s at 34 deg, apex 0.65 m above the mouth, heavy green halo and trail | 827 ms | 2037 | 100 ms | big splat, 26 droplets, strong flinch, hop and knock-back 0.3 m, **acid puddle** on the ground for about 2.4 s (bubbling) |

After the hit the prey keeps an acid look for the game's slow time: green-yellow tint (ramps in 70 ms, holds 0.35 s, fades over about 2 s), 7 to 16 bubbles that grow and pop on its skin, 5 steam wisps, 3 to 6 drips from the chin, a stagger shudder, and a bar over its head that empties over the 2.0 s slow status.

## How it is built
- **Ballistics:** every projectile is an analytic particle `p0 + v t + g t^2/2` (g = 9.81). Hit time is where it first enters the prey hitbox (found by 1 ms scan plus bisection). The renderer and the self-check read the same function, so what you see is what is tested. The jet is drawn as a chain of segments between consecutive droplets; once a droplet is absorbed by the prey it stays at the impact point, so the stream looks like it flows into the target.
- **Aim:** the head pitch at the release is solved so the mouth axis points along the launch velocity (within 0.01 deg). The projectile starts at the mouth.
- **Timing and contact:** `tc` is the first projectile entering the hitbox; prey flinch (squash, head jerk, recoil), the flash, splash droplets, splats and the status bar all start at that frame. Hit-pause freezes animation time as in the pounce lab (lob 60 ms, glob 100 ms; stream and spray have none).
- **Size scaling:** B is small, so the standard spit uses the game's 0.6 s wind-up plus a little (0.52 to 0.70 s). The charged glob is 1.15 s on purpose; a big body would stretch every wind-up and make the glob heavier and slower.
- **Game note:** the game resolves a spit at the active tick (tick 6, hitscan). The lob (1.1 s) and the glob (0.8 s) fly much longer than that; if the visual is wired to the sim, either delay the damage to the arrival frame (best for the lob) or shorten the flight. The jet (0.17 s) and the spray are close to the sim.

## Self-check (`window.__stylesCheck`): pass (numbers in `spit/check.json`)
Prey 5.5 m (3.7 m spray); a projectile reaches the hitbox surface (error under 1.2 cm; 41, 1, 75 and 1 hits); arcs follow g to 0.0 % in the position function; mouth axis within 6 deg of the launch direction (0.00 to 0.002 deg) and the projectile starts within 3 cm of the mouth; planted feet drift 0 cm and IK reach error 0 (the feet are fully planted, the stance change of versions 3 and 4 is one swing); no geometry below the ground; no particle below the ground (min 0.8 cm); prey finite, above ground, reacts at tc; wind-up 450-800 ms (glob over 900); lob apex at least 0.9 m above the mouth (1.3 m).

## Free-play check (the round-1 freeze lesson): pass
`spit/freeplay.json`: page opened WITHOUT `?test=1` in headless Chromium (SwiftShader), about 4.7 s, zero page errors, the frame counter and the animation clock advance, two screenshots (`freeplay_a.jpg`, `freeplay_b.jpg`) differ. SwiftShader renders only about 4 frames per second with four cells; the clock is capped at 100 ms per frame.

## Evidence (`docs/evidence/loco/spit/`)
`grid_contact_{game,side,front}.jpg` (four versions just after the contact), `strip_{jet,lob,spray,glob}.jpg` (six frames each: wind-up, swell, release, flight, contact, aftermath), `focus_*_contact.jpg`, `check.json`, `freeplay*.{json,jpg}`.

## Real-animal inspiration (from memory, unchecked)
1 spitting cobra: raises the front of the body, spits venom in a fine jet aimed at the eyes from up to 2 m, head wobbles during the spit; 2 llama and alpaca: head tilts back, cheeks swell, a gob of cud is flung; 3 bombardier beetle: pulsed hot spray from the abdomen that can be aimed (here sprayed from the mouth, with the sweep); archerfish: a pressed jet of water from the mouth, aimed with a tongue groove; 4 no direct animal: an exaggerated charged version (the glow and shudder are game language, like the throat glow of the old fire-breath concept; the lore says acid or steam replaces flame at low O2, see `lore/rules/technosphere.md`).

## Weakest
- Frame rate in the capture environment is low, so motion quality (the jet's arc over 0.17 s, the droplet cloud) is judged from stills; check it in a real browser at 0.25x.
- The jet drops only about 0.2 m, so the arc is barely visible at the game camera: it reads as a straight bright line. This is honest at 26 m/s; a slower jet would arc more but be less like a cobra.
- The spray sweep (head side to side) is hard to see from the game camera; the front 3/4 camera shows it better.
- The prey is a placeholder (a bear-like tortoise) and its face is within the hitbox sphere, so splats sit on its snout.
- The throat sac is a plain pale ellipsoid on the neck; it reads as swelling but not as a gland (no veins or translucency).
