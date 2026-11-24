# Chase camera and fight readability (G57, G70–G72)

`before.png` and `default.png` show the same frozen nest, heading, terrain and
1280×800 viewport. The before frame uses the original stage module from
`c2ac445^`, served only inside the test browser; no worktree is changed.
`default.png` is the after frame. `zoomed-out.png` shows the wide view;
`fight-framing.png` shows both opponents and the selected creature's name/HP;
`windup.png` shows a real C enemy windup and its coloured ground preview.

The default optical pitch is **0.24 radians (13.75°)** below horizontal. The
flat-ground geometric horizon projects to **22.52%** of viewport height from
the top. Mountains can occupy that horizon in the real valley. The target is
1.5 creature heights above ground, and the default boom is 6 heights. The
initial Merodeador bounds measure 4.892 m, giving a 29.351 m default boom.
Zoom spans 2.8–12 heights, rising to a 0.84 radian pitch at maximum zoom;
manual vertical orbit remains available. Walking follows heading with a
0.4 s time constant after the drag grace ends. Combat eases to a midpoint,
wider boom and side angle, then eases back. Camera-relative input uses the
displayed angle, including the combat angle. Touch orbit/pinch stays in the
existing pointer controller.

Boom samples are spaced at 0.2 m, using the C ground surface. An intersecting
ridge pulls the lens in immediately, and the final lens height is clamped to
at least 0.65 m above ground, including shake. The browser regression uses a
steep ridge to check both pull-in and clearance; unit checks also cover return
from combat, heading follow, scale, zoom limits and the flat horizon.

Bite, charge, spit and tail sweep have separate tell colours and body poses.
Their crouch/rear-back hooks stay in `web/stage`, leaving the shared rig alone.
Hits freeze pose presentation for **45 ms** (about 2–3 frames at 60 Hz), flash
the victim, shake the camera briefly, and show outlined damage numbers.
The fixed C simulation clock continues through the visual stop. Successful
blocks and dodges have blue/mint flashes, labels and their existing audio
samples. Partial blocks retain the block flash; broken guards no longer play
the successful-block cue. Reduced-motion preference suppresses camera shake.

## Firefox diagnosis

Installed **Firefox 159.0**, headless with Marionette, initially opened the
valley on a warm run. Delaying `cpore_world.wasm` by two seconds reproduced the
reported failure: `window.load` arrived before the environment's top-level
`await World.create()` completed. Boot checked for the environment once after
`load`, found none, and displayed the failure message. `firefox-before.json`
records that failure. This was a readiness race rather than an unsupported
WASM or WebGL API.

`boot.js` now waits for the actual environment and C world, with a 30-second
timeout and startup error propagation. The same installed Firefox, fresh
profile and delayed-WASM server now boots and advances the C world one tick;
`firefox-results.json` records readiness with no page errors. The visible
failure message includes the actual error detail. `tests/stage_firefox.py`
uses the built-in Marionette socket protocol, its own temporary server/profile,
a frozen animation clock, and closes Firefox/server in `finally`; no driver
or system package was installed. `firefox.log` includes Firefox's headless
software-compositor diagnostic and shutdown messages, not a page failure.

## Reproduction and checks

From the repo root, using the existing SDK and Playwright installation:

```sh
source ~/emsdk/emsdk_env.sh
export NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
nice -n 10 make wasm stage
nice -n 10 python3 -m http.server 8765 --bind 127.0.0.1
# In another terminal, with the same NODE_PATH:
nice -n 10 node --test --experimental-test-coverage tests/test_stage_camera.mjs tests/test_stage_boot.mjs
CPORE_CAMERA_BEFORE_REF=c2ac445^ nice -n 10 node tests/stage_camera.cjs
nice -n 10 make stage-firefox-test
CPORE_STAGE_EVIDENCE=build/feel-stage CPORE_STAGE_POLISH_EVIDENCE=build/feel-stage/polish CPORE_CAMERA_EVIDENCE=build/feel-stage/camera nice -n 10 make check
```

Chromium checks use the required cached Chromium executable and only
`--use-angle=swiftshader --enable-unsafe-swiftshader`. Browser processes inherit
nice priority and close in `finally`. Only evidence frames render. Detailed
browser measurements are in `results.json`. Natural windup and damage come
from C encounters; the per-move pose checks and defensive audiovisual checks
feed explicit snapshots/events through the presentation hooks to cover all
moves and successful defence without depending on an enemy policy choosing
a particular move. They do not claim a human audio/movement playtest.

The new boot/camera/feedback unit modules have 100% line coverage, with branch
coverage of 100%, 96.30% and 85.19% respectively in Node's coverage report.
The existing desktop/touch pointer, audio, simulation and replay suites remain
part of `make check`. Final full-suite result is recorded below once complete.

No files in `web/creature` or `art/reference` changed. Human feel, a normal
browser playtest, physical touch/gamepad hardware and hardware rendering
performance remain unverified.
