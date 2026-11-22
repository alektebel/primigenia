# Brief: owner questions pop up in the game; starter B; shallows seaweed

Worktree `/home/diego/Desarrollo/cpore-wt/owner-q`, branch `devtools/owner-questions`. Read first:
- `AGENTS.md`
- `docs/godot/DEVTOOLS.md` (F10 options, Shift+F8 notes)
- `godot/devtools/` (options, notes, feedback, legend)
- `tools/feedback/notes.py`
- the Emil UI skills (no animation on keyboard actions; ease-out ≤ 250 ms otherwise; press scale 0.97)

## 1. Starter B (A40)
Set `const STARTER := "b_runner"` in `godot/game/game.gd` and update `play_test.gd` (it expects "Hatchling", around line 635). Then run the Garfio winnability with the B genome (`winnability_c.gd genome=…`) and report it.

## 2. Seaweeds on sea cells (A41)
In `godot/game/tests/test_flora.gd`, about line 140, allow `drifting_ash` and `pozo_de_agua` on sea cells next to `cinta_de_marea` (the owner approved it 2026-11-22). Raise both to chance ≈ 0.3 in `godot/game/data/flora.json` and remove their density-0 note.

## 3. Owner questions inside the game (new)
The owner: "I want the questions to pop up so that I can answer them directly and provide specific feedback."
- **Question queue:** `feedback/questions/pending.json` (git-ignored folder, falling back to `user://`; format `primigenia.questions/1`). Each item:
  - id, text, context (one line)
  - options (2–4, each with a label and a description; one may be marked recommended)
  - allow_free_text
  - optional `where`: a scenario name, an F10 option preset (`opts`) or a world position, so the question can show the thing it asks about
  - optional `when`: `now`, `on_event:<name>` (for example `on_event:first_evolve`, `on_event:quest_done:hunt`), or `after_minutes:N`
- **Popup:** a small card in the bottom-right while playing, no modal. It shows the text, context and numbered options.
  - Keys 1–4 answer; T writes free text; Tab shows the thing (it loads the `opts` preset or flies the camera to `where`); L answers later; Esc dismisses it for this session.
  - Game input is suspended only while typing free text.
  - At most one card at a time, and at most one every 3 minutes unless `when: now`.
  - Style: same look as the F1 sheet and F10 HUD, with readable contrast on a bright sky (add a subtle scrim). The F10 HUD has a known readability issue on bright skies; fix it the same way.
- **Answers:** `feedback/questions/answers.jsonl`. Each line holds the id, the chosen option or text, a timestamp, the C tick, the active F10 options, and a screenshot path.
  - An answer can carry an attached note (opens the Shift+F8 note box pre-tagged with the question id).
- **Tooling:** `tools/feedback/questions.py` with:
  - `add` (from JSON or flags)
  - `list` (pending and answered)
  - `export-md`
  - `pull-answers`, which prints the answers for Claude to copy into the tracker and DESIGN.md
  - `seed-from-tracker <json>`: Claude exports open tracker decisions and tests to JSON, and this turns them into questions; open tests become "Did X pass? yes / no / partly + note"
  - Console: `questions`, `ask <id>`. Agent socket: the same.
- **Also:** a "Questions" entry in the pause menu listing pending items, so the owner can answer them at any time.
- **Tests** in `godot/devtools/tests/`: queue load, the timing rules, answer write, input suspension, `when` triggers (event), `opts` preview, and the questions.py round trip.
- **Evidence:** software-GL screenshots of a card on a bright sky and a dark night, plus the pause-menu list, in `docs/evidence/godot/owner-questions/`. Update DEVTOOLS.md and legend.json.

## Rules
- Software GL only, `timeout`, `nice -n 10`, kill only your own pids.
- Suites: `make godot-devtools-test`, `make godot-test`, `make godot-ui-test`, `make godot-play-test`.
- Commit after each part. Do not merge. Report: keys, files, suites, screenshots, winnability of B.
