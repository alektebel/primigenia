# Agent protocol (version 1)

`godot --path godot [--headless] -- --agent [--agent-port=47110] [--scenario <name>]`

Prints `AGENT_READY {"port":47110,"build":"...","protocol":1}` on stdout when the island is up (or `AGENT_ERROR <text>`
on stderr). TCP 127.0.0.1 only, one client. JSON lines: one request, one response with the same `id`; events have no id.
Lock-step: the stage never advances by itself while the agent mode is on; only `step` advances it.

| request | response |
|---|---|
| `{"id":1,"cmd":"console","text":"tp crater"}` | `{"id":1,"ok":true,"out":".."}` or `{"ok":false,"error":".."}` |
| `{"cmd":"act","order":"attack #1 bite"}` or `{"cmd":"act","input":{"verb":3,"hx":0,"hz":32767,"sprint":1}}` | ok / error; applies on the next tick |
| `{"cmd":"step","ticks":10}` | `{"ok":true,"tick","hash","obs","events":[combat events]}` (1..20000 ticks) |
| `{"cmd":"observe"}` | same without stepping |
| `{"cmd":"screenshot"}` | `{"ok":true,"path":"/abs/shot-000123.png"}`; headless: error "no renderer (run under xvfb without --headless)" |
| `{"cmd":"scenario_save","name":".."}` / `{"cmd":"scenario_load","name":".."}` | ok / the scenario error sentence |
| `{"cmd":"verify"}` | replays the session log from its start in a fresh world: `{"ok":true,"match":true,"ticks":n}` |
| `{"cmd":"quit"}` | ok, then the process exits 0 |

`obs` is `cp_stage_observe` (schema `world-2`; every `observe` command also acknowledges the events it lists, so the next one shows only what happened after it; the same text the Python binding's `StageWorld.observe()` returns) plus `tick`, `fighting`,
`player_rendered {x,y,z}` and `legend_context`.

Pushed events: `{"event":"error","source":"engine|c_input","text":..}` (engine log errors) and
`{"event":"invariant","name":..,"detail":..}` for `non_finite_position`, `stuck` (ordered to move, no motion for 30
ticks) and `verify_mismatch`.
