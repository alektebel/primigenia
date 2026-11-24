# Starter B pounce, four versions (A61 step 3, engage move)

Open [pounce.html](../../../web/gaitlab/pounce.html) with `file://` (local three.js; maths in `pounce_core.js`, body rig reused from `bite2_core.js`). Same shell as the bite lab: 2x2 large cells, camera buttons (game, side, front 3/4; the camera follows the creature and the prey and closes in as they meet), 1x / 0.5x / 0.25x, frame step, loop, timing bars with the hit-pause as a white block, hitbox toggle, click or `F` to enlarge. `?test=1` pauses at t=0; `window.__stylesCheck` holds the self-check. Capture: `NODE_PATH=.../_agent/node_modules timeout 300 nice -n 10 node tools/gaitlab/pounce_capture.cjs` (SwiftShader), writes `docs/evidence/loco/pounce/`.

Game numbers used (`core/src/combat.c`, 10 ticks per second): pounce is 8 ticks wind-up (0.8 s), 4 active (0.4 s), 4 recovery (0.4 s), range 4.8 m, stun 4 ticks (0.4 s), flag DASH, role engage. Prey starts 3.9 to 4.7 m from the creature (centre to centre 4.3 to 4.7 m). Stars show 0.4 s plus a 0.25 s fade. Hit-pause 80 ms at contact, shared with the bite impact effects (flash, spark burst, camera shake).

## The four versions (anim ms; the hit-pause freezes the animation)
| Version | wind-up (crouch, stalk, freeze) | freeze | active (take-off to contact) | flight | contact | after contact | prey |
|---|---|---|---|---|---|---|---|
| 1 Cat pounce | 960 | 280 (plus butt wiggle 5.5 Hz) | 500 | 500 ms arc, apex 0.32 m | beak on the prey's back and both front feet beside it | hind feet land +110, pin 490, step off 350, recovery 550 | flattened under the paws, wobbles up, stars |
| 2 Low dash-tackle | 560 | 260 | 510 | two strides (120+100 ms flights, then 130 ms into the slam), about 8 m/s | chest and shoulder slam, head up | skid 0.3 m, stand over, recovery 500 | knocked 0.6 m and rolled onto its side (1.5 rad), stars |
| 3 High leap dive | 760 | 290 | 730 | 640 ms, apex 0.84 m above the take-off height | beak on the back from above, body pitched 54 deg nose down | pivots over the beak, hind and front feet land +360 with a dust ring, recovery 750 | squashed into the ground (sy 0.54), stars |
| 4 Hop-hop-pounce | 440 to the first hop | 260 | 1330 (three bounds) | 230, 230, 430 ms | lands (front first) at +0, bite 80 ms later | hold on 280, pull out 200, recovery 600 | pushed back 0.18 m, wobbles, stars |

Real-animal inspiration (from memory, unchecked): 1 domestic cat and serval pounce (stalk low, the hips wiggle before the launch, front paws pin); 2 a dog or wolf body-checking and a lion's shoulder hit on a calf; 3 the secretary bird and kestrel/harrier drops, a fox's high mouse-leap (mousing) for the dive, heron for the beak lead; 4 a fox or jackal bounding up to prey, a cat doing quick stalking hops before a final spring.

## How the motion is built
- **Feet:** planted segments sit in world space (they cannot slide); swings use a lift arc; airborne feet blend to a body-relative tuck pose and back to the landing spot (the landing spot is computed from the hip position at landing, so the leg is never overstretched). Flights are exact ballistic arcs of the body centre (g = 9.81, no extra float); gallop flights are short (100 to 130 ms, apex 1 to 2 cm), the leap and dive are long.
- **Contact:** the body position at contact is solved so the beak tip (versions 1, 3, 4) or the chest node (version 2) touches the prey hitbox. After contact the beak stays anchored on the prey while the body pivots or settles, then releases.
- **Landing:** the body dips and the legs compress (hip-to-foot ratio drops), dust puffs at every take-off and landing, a big ring in version 3. Ground collision lifts the body if any node would sink.
- **Size scaling:** B is small-medium; freezes are 260 to 290 ms, wind-ups up to 0.96 s. A big body would stretch the wind-up toward 1.2 s and use a lower apex.

## Self-check (`window.__stylesCheck`): pass (raw numbers in `pounce/check.json`)
Start distance 3 to 5 m; beak or chest within 3 cm of the hitbox at contact (about -0.7, -1.7, -0.6, -0.9 cm); hit-pause 60 to 90 ms and a clean freeze; planted foot drift and reach error under 2 cm (cat 0.8, tackle 0, dive 0 and 1.6, hop 2.0, close to the limit); no geometry below ground; each long flight follows -g within 10 % and has no planted foot; legs compress after landing; freeze 200 to 600 ms; wind-up at most 1100 ms; prey state finite and above ground for any time; tackle prey knocked over (moved 0.62 m, roll 1.5 rad).

## Free-play check (the round-1 freeze lesson): pass
`pounce/freeplay.json`: page opened WITHOUT `?test=1` in headless Chromium (SwiftShader), about 4.7 s, zero page errors, frame counter and animation clock advance, two screenshots (`freeplay_a.jpg`, `freeplay_b.jpg`) differ.

## Evidence (`docs/evidence/loco/pounce/`)
`grid_contact_{game,side,front}.jpg` (four versions at the contact frame), `strip_{cat,tackle,dive,hop}.jpg` (six frames each), `focus_cat_contact.jpg`, `focus_dive_contact.jpg`, `check.json`, `freeplay*.{json,jpg}`.

## Weakest
- Versions 1 and 4 look alike at the contact still (low front landing, beak on the back); they differ in the run-up (stalk and wiggle versus two bounds) and the aftermath (pin versus bite and hold).
- The prey is hidden by the creature body from the game camera at the cat contact; use the side or front camera.
- Hop planted-foot drift is 2.0 cm, right at the limit; the creature's thin starter-B legs fold stiffly in the tackle crouch.
- Camera starts wide (6 m span) so the stalk is small; enlarge a cell (`F`) to judge it.
