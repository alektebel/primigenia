# godot/devtools (DT0)

Dev tools of the creature stage. Module doc: `docs/godot/DEVTOOLS.md`; plans: `docs/godot/PLAN-devtools.md`, `PLAN-heights.md`.

* `dev.gd` autoload `Dev`: owner-question settings as constants (dev tools on in debug builds, console key, feedback folder).
* `legend.{gd,json}` key legend, `time_control.gd`, `console/` (registry, commands, UI), `sites.gd` + `site_picker.gd`,
  `scenario.gd`, `tuning/`, `feedback.gd`, `agent/` (socket server, `client.py`, `PROTOCOL.md`), `tools/make_scenarios.gd`.
* `tests/`: `make godot-devtools-test` (headless), `make godot-devtools-evidence` (3 software screenshots), `make godot-agent-test`.
