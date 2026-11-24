# Starter B befriend, four pages x four versions (A76 step 1)

Open [befriend.html](../../../web/gaitlab/befriend.html) with `file://` (maths in `befriend_core.js`, body rig from `bite2_core.js`). Pages SING, DANCE, CHARM, POSE (tabs, or `Space` / `Shift+Space`); each page is 2x2 large cells. Controls: game / side / front 3/4 camera, 1x / 0.5x / 0.25x, frame step, loop, `T` frame (both, close on B, close on target), star one version per page (localStorage in try/catch), **Copy choices** gives `sing=trill; dance=hop; charm=...; pose=...`. `?test=1` pauses at t=0; `window.__stylesCheck` holds the self-check; headless: `node tools/gaitlab/befriend_node_check.cjs rows`. Capture: `NODE_PATH=.../_agent/node_modules timeout 500 nice -n 10 node tools/gaitlab/befriend_capture.cjs` (SwiftShader, about 4 min, run it in the background) writes `docs/evidence/loco/befriend/`.

## Game numbers (core/include/cpore/world.h, core/src/stage_social.c, 10 ticks/s)
Beat `CP_SOC_BEAT` = 12 ticks = **1200 ms**, window `CP_SOC_WINDOW` = +-2 ticks = **+-200 ms**. The rhythm is sampled once, at the **end of the wind-up** (`act_t == windup`); the skill applies (trust, our "success frame") at wind-up + active.
| skill | wind-up | active | recovery | range | success at |
|---|---|---|---|---|---|
| sing | 200 ms | 800 | 200 | 8 m | 1000 ms |
| dance | 200 | 1000 | 200 | 5 m | 1200 |
| charm | 100 | 600 | 200 | 4 m | 700 |
| pose | 400 | 800 | 200 | 10 m | 1200 |
Timing bar: green = window, white ticks = beats (1.2 s), gold = success, plus a dial per cell (hand at top = on the beat). B and the target (Zanco-like: stilt legs, long neck, trumpet snout, ear scoops, amber back fringe, 2.8 m centre to centre) start at rest; lead-in 0.8 to 1.7 s, then the order, then 3.6 s of reaction and the walk back, so every version loops cleanly (the target steps 0.5 m closer on success and drifts back at the end).

## Target reaction (fires on the success frame in every cell)
Ears snap up (about 85 ms), head tilt about 0.36 rad that settles, tail swish, fringe flares, a **step closer** (0.5 m, two diagonal steps, feet planted), a subtle gold ground ring under it (no hearts, no sparkle), and a small mirror of the gesture: sing = head up and a soft answer with ripples; dance = two small body bounces and tail wag; charm = head lowered toward B, sniffing; pose = stands taller, fringe fully flared. Nuzzle has no step (B is at its side; it leans in and turns its head); offer food has the target bend its neck to the fruit and take it. Before success it only gets attentive (ears under 0.6) or does the scripted answer (call-and-answer, duet, mirror).

## Versions (real-animal inspiration from memory, unchecked)
| page | version | what you see | animals |
|---|---|---|---|
| SING | 1 Bird trill | head up, beak flutters in three bursts on 200 / 500 / 800, throat pulses, arc ripples | songbird, wren |
| SING | 2 Low hum with sway | head low, slow throat pulse, body sways on planted feet, ground rings | cat purr, bull elephant rumble |
| SING | 3 Call and answer | B calls twice, cocks the head, target answers (ripples from its snout), B answers back | duetting birds, wolf howl |
| SING | 4 Duet chirp | short chirps, head bobs down on each, tail flicks, target bobs along | pigeon bob, finches |
| DANCE | 1 Stomp | fore feet lift and slam left/right on 200/500/800/1100, body drops, dust | prairie chicken, ostrich-like foot drumming |
| DANCE | 2 Hop | crouch then three hops left, right, centre, last landing on the success frame | gazelle pronking, jumping spider |
| DANCE | 3 Circle | trot on an arc round the target, footfall every 200 ms, turn in place to face it, walks back | courting cranes, dogs circling |
| DANCE | 4 Bob and weave | crouched sway with a dip every 300 ms, tail and head counter-swing | manakins, boxing hares |
| CHARM | 1 Offer food | bows and picks a fruit (lead-in), walks up, sets it down before the target, backs off | gift-giving birds, dog bringing a toy |
| CHARM | 2 Nuzzle | slow approach along its side, head rubs its neck, roll, soft eyes | giraffe necking, horses grooming |
| CHARM | 3 Preen / show off | puffs up, shiver, crest and tail up, slow turn side-on, hold | peacock, bird fluffing |
| CHARM | 4 Play bow | forelegs drop, rear up, fast tail wag, two bounces, open mouth | dog play bow |
| POSE | 1 Crest display | crest snaps up and flushes on the beat, chest out, quiver on 700 / 1000, hold | cockatoo, hoatzin |
| POSE | 2 Stand tall | slow rise onto straight legs, neck stretched, dead still | meerkat/secretary bird sentinel |
| POSE | 3 Side-on display | two double-steps turn it flank-on (about 70 degrees so the game camera still sees it), tail lifted, freeze | cats, iguana, frilled lizard |
| POSE | 4 Mirror pose | copies the target's head tilt and raised foreleg as a mirror image, arriving on the beat | mimicry in social animals, parrots |

## Self-check (`check.json`): pass
Per version: planted-foot drift at most 1.0 cm (limit 2 cm), IK out of reach at most 1.2 cm, geometry above ground, neck stretch within the rig cap, target feet and IK likewise; beat alignment: the first accent (peak, or the moment the pose reaches 90 %) lies within +-60 ms of the wind-up end (measured -24 to +8 ms; the oscillating gestures hit 0 ms) and every further accent lies on a 200 / 300 / 400 / 600 ms subdivision within 60 ms; target ears under 0.7 before success and above 0.9 within 150 ms after (80 to 84 ms); target steps at least 0.4 m (0.5 m); loop: B and target end within 3 cm / 0.05 rad and every foot within 4 cm of where it began.

## Free-play check: pass
`befriend/freeplay.json`: opened WITHOUT `?test=1` in headless Chromium (SwiftShader), about 4.7 s, zero page errors, frame counter and animation clock advance, two screenshots (`freeplay_a.jpg`, `freeplay_b.jpg`) differ.

## Evidence
`grid_<page>_{game,side,front,beat}.jpg` (success frame +150 ms in three cameras; the beat frame), `strip_<page>_<id>.jpg` (both animals, six frames), `close_<page>_<id>.jpg` (close on B), `check.json`, `freeplay*`.

## Weakest
- B is small in the "both" frame (about 150 px long in a 2x2 cell); use `F` to enlarge or `T` close on B. The beak is tiny, so sing reads from the head-up pose, throat sac and ripples more than the jaws.
- POSE versions 1 to 3 differ mainly in crest, height and facing; at 1x they are close cousins. Mirror pose is the subtlest (the raised foreleg and head tilt are small).
- Play bow and bob-and-weave are both low, bouncy poses; bow's pitch is best seen from the side camera.
- Circle dance is an arc of about 30 degrees (the game's 1 s dance cannot cover a full circle at a believable trot), toward the camera; the in-place turns are stepped, not a smooth pivot.
- Offer food: the long-necked target cannot reach the ground, so it bends its legs and neck (about 0.3 m nose height) and the fruit is taken a little above the fruit; the pick-up bow happens in the lead-in, before the order.
- Reactions are scripted (no AI); the beat dial is per cell and phased to the check frame, the game phases the beat per creature.
