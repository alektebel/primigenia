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
| `web/studio/` | the creature studio (Three.js): reference skin and walk, independent horn/plate/tendril regions with surface placement, seeded variants, undo/redo, genome JSON, share links, es/en. `test.html` checks round trips and rejections |
| `harness/` | reference LLM harness (to come) |

The [functional design](docs/CREATURE_VISUAL_PLAN.md) specifies the full
generative creator: anatomy, artistic controls, AI proposals, motion, and
latency requirements. The current regional growth generator is its first
working increment; blended anatomy and AI generation are still pending.

To use the studio, serve the repository with `python3 -m http.server 8765` and
open `http://localhost:8765/web/studio/`. Choose **Coralino** or **Abisal** for
generated examples, or choose a family under **Generar detalles**. Use
**Añadir región** to combine families. Select a region in the list or on the
creature; **Colocar en el cuerpo** attaches it to the torso, neck, or tail. Each
region has its own shape, seed, coverage, and symmetry. **Duplicar**, **Eliminar**,
and placement are undoable. Arrow keys move the selected region, Escape cancels
a drag, and **Nueva variante** changes its seed. Geometry is generated locally;
placement reuses existing meshes and shape edits rebuild only the changed region.
JSON and share links use `cpore.creature/3`, with imports from versions 1 and 2. Artistic growth does not change the gameplay ability values.

Run `node tests/test_growth.cjs` for deterministic geometry checks and a CPU
generation benchmark. Open `/web/studio/test.html` for genome regression checks.
For pointer, keyboard, history, memory, and mobile browser checks, install the
optional runner with `npm install --prefix /tmp/cpore-browser playwright`, then
`node /tmp/cpore-browser/node_modules/playwright/cli.js install chromium`. With
the server running, use `NODE_PATH=/tmp/cpore-browser/node_modules node tests/studio_interaction.cjs`.
For viewport selection and touch dragging, also run
`NODE_PATH=/tmp/cpore-browser/node_modules node tests/studio_touch.cjs`.
Screenshots and the reports go to `/tmp/cpore-studio-evidence/`.

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
