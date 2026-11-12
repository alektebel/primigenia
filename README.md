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
| `harness/`, `web/` | reference LLM harness and Three.js front end (to come) |

## Build

```
make            # core library, tests, bench
make test       # C tests + core dependency check
make smoke      # Python binding smoke test
make bench      # steps/s
make studio     # the SDL creature studio (needs libsdl2-dev libepoxy-dev)
```

The old software renderers were removed (DESIGN.md Q27); their entry points
are still declared in the headers and will be pruned as each stage is reworked.
Python bindings for symbols that no longer exist are skipped at load time.
