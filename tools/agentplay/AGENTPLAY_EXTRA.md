## Extending to the Godot game

The harness only needs three things from a backend: `reset(seed)`, `command(text) -> code`, `step()` + `observe() -> world-1 JSON`, and a state hash for determinism. To drive the Godot creature game instead of the C sim:

1. Expose the same text verbs through the planned dev-tools console (docs/DEVTOOLS.md): a headless/`--agent` mode where stdin lines are commands (`reset <seed>`, `cmd <verb line>`, `tick N`, `observe`, `hash`), JSON on stdout. Then `env.py` needs only a subprocess adapter instead of `StageWorld`.
2. Scenarios from the console (`spawn`, `teleport`, `set hp`) give targeted episodes: fight-only, nest-only, obstacle courses. That replaces blind seed sweeps for bug repro and lets personas start in interesting states.
3. The Godot observation should keep the world-1 schema (so invariants and prompts are unchanged) and add the missing fields flagged below (outcome events, opponent hp, fight state, walkable bounds), then `TOP_KEYS` in `env.py` is updated once.
4. Determinism check: the Godot build must expose a state hash (or the C core hash through GDExtension); without it only the invariant and usability parts work, not the replay comparison.
5. Frame/visual bugs (clipping, animation, camera) are out of reach of this text interface; those need screenshot capture plus a vision model, a separate harness.
