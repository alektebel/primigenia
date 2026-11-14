# cpore

A Spore-like evolution arc (cell → creature → tribe → civ → space) written as a
deterministic C simulation, built to be an **RL environment and an LLM
benchmark**: how fast can an agent beat the whole arc? Independent fan-made
tribute; not affiliated with Maxis or EA.

Status: restoring and reorganising (milestone v0.1, creature stage first). The
design, every decision and why, is in [docs/DESIGN.md](docs/DESIGN.md).

## Layout

| dir | what |
|---|---|
| `core/` | the simulation, libc + libm only, no graphics (`make check-core` enforces it) |
| `bindings/python/` | ctypes binding, Gymnasium envs, `Campaign`, the `TextLand` LLM face |
| `bindings/puffer/` | PufferLib-native binding |
| `tests/`, `apps/` | C test suite and throughput bench |
| `studio-sdl/` | transitional SDL2/GL creature studio, moving to `web/` |
| `art/reference/` | the visual and rules references (`valle-primigenio.html`, `taller-de-criaturas.html`) |
| `web/studio/` | Primigenia creator: sculptable spine, Build/Paint/Test, 3D part palette, procedural IK legs, 24 Blender GLBs, growth regions, undo/redo, JSON, sharing, es/en |
| `harness/` | reference LLM harness (to come) |

The [functional design](docs/CREATURE_VISUAL_PLAN.md) specifies the full
generative creator: anatomy, artistic controls, AI proposals, motion, and
latency requirements. The current regional growth generator is its first
working increment; blended anatomy and AI generation are still pending.

To use the studio, serve the repository with `python3 -m http.server 8765` and
open `http://localhost:8765/web/studio/`. The owner's
`art/reference/creador-de-criaturas.html` is the base; references stay untouched.
**Build / Paint / Test** keep spine sculpting, patterned skin, jaw/eye animation,
and a gait derived from the procedural legs. Hover over the body to reveal the
spine; drag a vertebra or scroll over it to change its radius.

The nine palette categories contain the original procedural parts, a procedural
digging claw, and all 24 original Blender GLBs. Drag a thumbnail onto the body,
or select it and click/tap the body. Enter activates a focused palette item;
arrow keys move the selected part. GLBs remain rigid, including imported limbs
and wings. Their material slots adopt the creature's skin, bone/beak, translucent
membrane and eye materials. The copied assets and manifest live in
`web/studio/parts/`; no Blender scene is shipped. The versioned `parts.json`
records costs, categories, illustrative abilities, candidate C types, material
inference and cosmetic status. All designs are currently **cosmetic**, with no
C validation or gameplay abilities granted.

In **Build**, **Regions** adds independent horn, plate and tendril recipes on
torso, neck or tail. Add, duplicate, delete, vary and place regions; arrow keys
move the selected region. **Orbit** provides an explicit camera tool for touch.
Escape cancels a gesture. Undo/redo preserve exact designs and seeds; placement
reuses growth geometry. Spine edits stay in the vertical plane with mirrored
parts, as scoped for P1.

JSON downloads, file/pasted imports and Unicode share links use
`cpore.creature/4`: `nodes`, `parts`, `skin`, `name`, `regions`. `/1`, `/2` and `/3`
imports preserve the source document and report body/slot approximations,
legacy motion and level differences, and discarded gameplay estimates. Invalid
imports leave the creature and history unchanged. The studio autosaves `/4`.
Three.js r128 comes from cdnjs; cdnjs does not distribute its examples, so the
official matching GLTFLoader is vendored with its license. Fonts and Three.js
still need network access.

Run the checks without installing anything:

```bash
node tests/test_growth.cjs
node tests/test_studio_genome.cjs
python3 tests/check_studio_glbs.py
export NODE_PATH=/tmp/claude-1000/-home-diego-Desarrollo-cpore/52130491-4ef1-4633-b55d-8ccffceb2b8f/scratchpad/node_modules
nice -n 10 node tests/studio_interaction.cjs
nice -n 10 node tests/studio_touch.cjs
```

Browser tests require the local server and the installed Chromium at
`~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome`, using only the
specified SwiftShader arguments. They check all presets and 20 seeded random
creatures, every catalog part on every preset, migrations, atomic rejection,
mouse/keyboard/touch interactions, modes, history, language and sharing.
`/web/studio/test.html` runs the document and placement contracts interactively.
Evidence goes to `docs/evidence/studio-v4-*`. No offline Khronos validator was
found; the Python script checks GLB structure and buffers, **not full glTF
conformance**. Khronos Sample Viewer comparison and owner visual acceptance
remain unverified; see [P1 evidence](docs/evidence/studio-v4-validation.md).

## Build

```
make            # core library, tests, bench
make test       # C tests + core dependency check
make smoke      # Python binding smoke test
make bench      # steps/s
make studio     # the SDL creature studio (needs libsdl2-dev libepoxy-dev)
make blender    # Blender with the local LLM/MCP design bridge
```

To let Kimi or another vision-capable MCP model inspect, model, render, revise,
and export Blender assets, see [docs/BLENDER_MCP.md](docs/BLENDER_MCP.md). The
project-level Kimi MCP configuration is included; run `make blender` first.

The old software renderers were removed (DESIGN.md Q27); their entry points
are still declared in the headers and will be pruned as each stage is reworked.
Python bindings for symbols that no longer exist are skipped at load time.
