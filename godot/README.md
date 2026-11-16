# Primigenia, Godot 4 desktop frontend (G76)

Godot 4.7.2, GL Compatibility renderer, GDScript for game code, C++ GDExtension over the C core.
Desktop only (Linux built and tested; the Windows/macOS lines of `cpore.gdextension` are
placeholders and are not built in M0).

## Build and run

```sh
make godot && godot --path godot
```

`make godot` compiles `build/libcpore.a` (the C99 core, unchanged flags), builds the extension
`godot/bin/libcpore.linux.template_debug.x86_64.so` with SCons, seeds `godot/.godot/extension_list.cfg`
(without it the first import aborts) and imports the project.

Dependencies live outside the repository (nothing is downloaded by the build):

| What | Where | Pin |
|---|---|---|
| godot-cpp | `/home/diego/Desarrollo/cpore-wt/_agent/godot-cpp` (`GODOT_CPP=`) | master at `2a4c066e1e8c121046e9d35fe91cc8e726861c48`, built with `api_version=4.7` |
| SCons 4.11.1 | `/home/diego/Desarrollo/cpore-wt/_agent/godot-venv/bin/scons` (`SCONS=`) | |
| Godot | `godot` on `PATH` (`GODOT=`) | 4.7.2 stable |

If godot-cpp is missing: `git clone https://github.com/godotengine/godot-cpp.git`, check out the pinned commit,
`python3 -m venv` + `pip install scons==4.11.1`.

First run generates the island (about 3.4 s, loading screen with progress) and caches it in
`~/.local/share/primigenia/terrain/` (about 8.7 MB, zstd); later runs load it in about 40 ms.

## Make targets

| Target | What |
|---|---|
| `make godot` | build the extension and import the project |
| `make godot-test` | headless GDScript tests (`godot/game/tests/run_m0_tests.gd`) |
| `make godot-render-test` | software-GL render tests (tone-map calibration gate, sky, contact shadow, LOD cracks); writes `docs/evidence/godot/m0/calibration.json` |
| `make godot-evidence` | screenshots and `timings.json` into `docs/evidence/godot/m0/` (xvfb + llvmpipe, never the GPU) |

`make test` (core tests) is independent and unchanged.

## Controls

| Input | Action |
|---|---|
| W A S D / arrows | move, camera-relative (rebindable actions `move_*`) |
| Shift | sprint |
| Left click, hold | walk to the pointer; clicking a creature selects it (`Game.creature_clicked`) |
| Right or middle drag | orbit the camera |
| Mouse wheel | zoom (pitch rises as the camera pulls back) |

Combat keys (1-4, Space, Q/E, Tab, Esc) belong to the UI module and are not consumed here.
Options after `--`: `--genome=<path>` loads another `cpore.creature/4` genome.

## Layout

See `docs/godot/M0.md` for interfaces, what is verified and not, the colours the owner must approve and the
open issues. Folders: `extension/` (C++ glue), `game/` (everything else in M0), plus `ui/ audio/ studio/ creature/
locomotion/` owned by other branches and loaded only if present.
