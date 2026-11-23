# godot/devtools (DT0)

Dev tools of the creature stage. Module doc: `docs/godot/DEVTOOLS.md`; plans: `docs/godot/PLAN-devtools.md`, `PLAN-heights.md`.

* `dev.gd` autoload `Dev`: owner-question settings as constants (dev tools on in debug builds, console key, feedback folder).
* `legend.{gd,json}` key legend, `time_control.gd`, `console/` (registry, commands, UI), `sites.gd` + `site_picker.gd`,
  `scenario.gd`, `tuning/`, `feedback.gd`, `agent/` (socket server, `client.py`, `PROTOCOL.md`), `tools/make_scenarios.gd`.
* `tests/`: `make godot-devtools-test` (headless), `make godot-devtools-evidence` (3 software screenshots), `make godot-agent-test`.
* `loop/` creature-loop telemetry (T1, `docs/plans/creature-loop.md`): `loop_detector.gd` turns each C state into beats (spawn, first_move,
  fight_start/end, kill, player_death, befriend_start, bond_made, dig, part_found, nest_enter/exit, species_seen, cousin_seen, sample every
  100 ticks), `loop_recorder.gd` (child of `Dev`, always on; `CPORE_LOOP=0` turns it off) writes every `Game.loop_event` as JSONL
  `{n, tick, ms, ts, d}`: `user://loop/<stamp>.jsonl` in play, `test-feedback/<pid>/loop/session.jsonl` in tests, or `CPORE_LOOP_FILE`.
  Other emitters: `select` (game_ui), `editor_open`/`editor_close` (stage_ui), `evolve` (studio nest confirm), `generation_evolve`
  and `first_evolve` (lineage_session), `quest_done:<id>` (first_quest), `island_ready {ms, phases}` (island), `flight_start/end`, `perf`.
  Console: `loop` (summary), `loop dump [n]`, `loop path`; agent socket `{"cmd":"loop","dump":n}`.
  Score it: `make godot-loop-score` (the first-quest bot on 3 seeds) or `python3 tools/loop/score.py --session <file>` for a real session;
  `python3 tools/loop/compare.py <baseline> <label>`; self-tests `python3 tools/loop/test_score.py` and `devtools/tests/test_loop.gd`.
