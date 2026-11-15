# Stage polish: G57 / G59

Run from the repository root with the existing SDK and Playwright installation:

```sh
source ~/emsdk/emsdk_env.sh
nice -n 10 make wasm stage
nice -n 10 python3 -m http.server 8765 --bind 127.0.0.1
# Other terminal:
export NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
nice -n 10 make test
nice -n 10 make wasm-test
nice -n 10 make stage-test
nice -n 10 make studio-test
```

Open `http://127.0.0.1:8765/web/stage/`. Click the ground to walk to the small
gold ring; hold the left button to keep following the pointer. Click Garfio
to select it (ring and name), then press an available move key/button to
approach and attack. Keyboard/stick movement overrides the destination or
attack order. Attacks remain standing orders until movement or a ground click
replaces them, or the encounter ends. No social actions are implemented here.

WASD/arrows and left stick are camera-relative, with continuous directions.
Shift/Sprint runs. Right/middle drag or right stick orbits; the wheel zooms
within 8–30 m. After 2.5 s without manual orbit, walking eases the camera behind
the creature. The camera boom tests the terrain and shortens before a ridge;
the lens stays at least 0.65 m above the sampled ground. On touch, tap to walk,
hold to follow, use two fingers to orbit and pinch to zoom. The optional stick
and combat buttons remain. Space guards when equipped; Q/E or a movement-key
double tap dodges. Escape/P/Pause opens the pause menu. Master, music/ambience,
sound-effects and mute settings persist locally. Music/ambience currently
controls meadow and wind loops; there is no musical score.

## Evidence and verified behavior

- `click-marker.png`: an actual ground click, before walking. The marker's
  ray intersection is checked within 2 cm of the intended valley point.
- `selection-ring.png`: an actual ray selection of Garfio, followed by a real
  move-key press. C's accepted attack log verifies approach and attack.
- `curve-1.png` through `curve-6.png`, and `curved-walk-strip.png`: six successive
  frames, 0.4 simulated seconds apart, of the roaming controller following a
  changing continuous heading. The strip only resizes/assembles those captures.
  This locomotion capture isolates the player at the real nest with the enemy
  disabled after the separate real interaction checks. It is not combat evidence.
- `mobile-pause.png`: the 390×844 pause menu and audio controls.
- `results.json`: exact browser version, arrival error, held-pointer target
  changes, WebAudio graph checks, foot measurements and curved-walk poses.
- `touch-results.json`: tap/hold, two-finger orbit, pinch zoom and menu bounds.

The browser harness uses headless Chromium at the prescribed cached path,
`--use-angle=swiftshader --enable-unsafe-swiftshader`, inherited nice priority,
and closes every browser in `finally`. No hardware rendering is requested.
The frame clock is controlled; only evidence frames render. These are
functional checks, not measured rendering FPS.

Click-to-move arrives within 0.25 m (the recorded run is approximately 0.128 m).
Holding and moving the pointer changes the sampled destination and moves the
player. Selection followed by a move key creates a real C attack order.
Right/middle orbit and wheel limits are checked separately. Touch tap/hold,
two-finger orbit and pinch use real dispatched touch events.

The shared rig is exercised for 240 updates on a curved path over a sloping
height function. For consecutive stance frames, the test measures the actual
foot mesh's world position and checks that its rotation stays planted. Maximum
stance displacement must be below **0.03 m**; exact samples and maximum are in
`results.json`. Contacts are counted, and a stationary pose's gait phase must
not advance with elapsed time. This covers the default four-legged Merodeador,
not all possible creator anatomies, extreme terrain or toe deformation.

WebAudio must have no context before a gesture. After a real gesture, all 15
local Ogg files decode, the master/music/sfx graph exists, three environmental
loops have positional panners, and the context is running without errors.
Pause-menu volume and mute changes are exercised. Foot contacts trigger three
grass-step variants, with speed/size gain and size pitch. Wind gain increases
with elevation; rustle follows movement on the valley's low, gentle ground.
C hit/block/dodge/death events and move-phase transitions trigger combat sounds;
idle calls and encounter aggro are separate cues. Audio consumes tick events
without changing any canonical simulation state or RNG stream. Sources, edits
and per-file licences are in [assets/audio/CREDITS.md](../../../../assets/audio/CREDITS.md).
The shipped audio is 2,137,173 bytes, below 6 MB.

## Regression checks

`make test`, `make wasm-test`, `make stage-test` and `make studio-test` pass.
The five native, WASM and JS golden replays retain all **50,000** fixed hashes.
10,000 random signed-int16 headings match native/WASM at every tick and replay
identically. The arbitrary-heading encounter timeline matches at 60/37 Hz and
its exported version-2 log replays in native C. Version-1 encounter logs and
legacy octants remain readable for compatibility; live movement uses vectors.

The existing stage suite retains identical complete encounter logs/final hashes
at 30/73 forced rAF Hz, real damage/death/victory captures and native replay.
The unchanged competent policy on seeds 0–49 wins 78% biter, 74% guard and 60%
spitter; all remain within 35–80%. Movement now changes the guard's approach
trajectory (the earlier pass was 42%); enemy/player profiles were not retuned.
Studio checks include document/growth contracts, 470 interaction contracts,
138 placements, touch interaction and the G48 geometry/animation checks.

`python3 tools/hero/build_hero.py` regenerates `web/hero/index.html` byte-identically:
SHA-256 `672e4c1da9a867b03a5761deff836bbdbf5b167fe3f5eb23cd5340e223cdd00a`.
No files under `art/reference/` changed.

## Still for the owner

Movement/camera feel, audible mix, suitability of the sampled creature cries,
loop seams and the G58 ten-minute normal-browser playtest remain unverified.
No real-GPU performance, hardware gamepad or physical-device audio claim is
made. Click movement is direct steering with the existing collision/slide
controller, without route planning around obstacles. Roaming stays in JS for
this P3 slice; G56's whole-world C migration remains P4. The separate existing
P2 tournament balance failures are unchanged; this work does not close them.
