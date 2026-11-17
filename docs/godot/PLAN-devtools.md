# PLAN-devtools: DT0 for the creature stage (C0)

Status: **plan, 2026-11-17.** Source: `docs/DEVTOOLS.md` §5 row DT0, `docs/CREATURE-ROADMAP.md` C0.
Planner: Opus. Implementer: Sonnet, step by step, in order. Steps marked **[CORE]** touch `core/` or
`apps/` C code and may be routed to Codex; they need `make test` (all C tests and goldens) green.
Companion plan: `PLAN-heights.md` (F4). The core steps of both plans share `stage_world.c`; the
order is fixed in §6.

Scope: D13 key legend, D1 console, D2 sites + bookmarks, D3 scenarios (= game saves), D4 live
tuning + A/B, D5 F8 feedback, D7 time control, and an **agent interface** (console + scenarios over a
local socket for `tools/agentplay`). Not in scope: D6 scrubber, D8 overlays, D9 free camera (DT1),
D10-D12 (DT2). Keys for those are reserved, not bound.

Godot rules (`_agent/briefs/godot-common.md`): every godot run is wrapped in `timeout`, run
`--check-only` on each new script first, renders only under `xvfb-run -a` with
`LIBGL_ALWAYS_SOFTWARE=1 --rendering-driver opengl3`, always `nice -n 10`, at most 3 screenshots
for the whole plan.

---

## 1. Decisions

### 1.1 Determinism contract (Q24)

* The C world (`CpStageWorld`) is the only simulation state. Everything that changes it goes through
  C: player orders (`cp_stage_order`, existing) and **debug ops** (`cp_stage_debug`, new). Both are
  logged per tick. Presentation (camera, interpolation, timescale, tuning of GDScript params) never
  flows back into C.
* Per-tick order inside the bridge, the same in Godot, `world_cli` and `cp_stage_replay_ex`:
  **debug ops of tick t, then the order input of tick t, then `cp_stage_step`.**
* **Snapshot/restore is a raw copy of the POD struct**, not a field-by-field serialiser.
  Why: `CpStageWorld` (22 328 bytes today, `bindings/python/cpore/world.py` `_WORLD_BYTES`) holds no
  pointers and no heap state; a byte copy restores *every* bit (RNG streams, bot timers, combat
  bookkeeping, derived last-tick outputs), so "restore then run == original run" holds by
  construction instead of by a long serialiser that could forget a field. Portability is guarded
  instead of assumed: the header carries a **layout fingerprint** (FNV-1a over `sizeof` and the
  `offsetof` of every member of `CpStageWorld`, `CpStageSetup`, `CpStageCreature`, `CpCombatWorld`,
  `CpCombatCreature`, `CpStageBot`, `CpStageMotion`), `CP_STAGE_VERSION`, and the state hash. All our
  desktop targets (x86-64 Linux/Windows/macOS, arm64 macOS) are little-endian with the same
  alignment for int8..int64/float, so the fingerprint matches across them; if it ever does not, the
  load fails loudly. Engine changes (`CP_STAGE_VERSION` bump) make old blobs unloadable by design;
  scenarios therefore also keep a **recipe** (setup + log from reset) that re-derives the state under
  a new engine (§1.4).
* The heightfield (F4) is **not** in the snapshot. It is referenced by a pointer kept as the **last
  member** of `CpStageWorld`; the payload is `offsetof(CpStageWorld, field)` bytes. The header stores
  the field hash; restore requires the caller to pass a field with the same hash.
* **Hash compatibility.** New state (debug flags, the per-world copy of the motion parameters, the
  field hash) is folded into `cp_stage_hash` **only when it differs from the default** (flags != 0,
  motion != `CP_STAGE_MOTION`, terrain == FIELD). So the three committed golden logs
  (`tests/golden/world-{1,42,987654321}`) and `make tourney` keep their hashes; no golden is
  re-recorded. A test asserts this.
* **ABI.** `CpStageSetup`, `CpStageInput` and `CpStageLogEntry` keep their layout (the Python
  binding asserts 17 604 / 32 / 36 bytes). `CpStageWorld` grows; add `size_t cp_stage_world_size(void)`
  and switch the Python binding's `_WORLD_BYTES` to it (one line in `bindings/python/cpore/world.py`;
  that file is also edited on branch `e2e-agents`, so tell the coordinator; until then the binding
  would allocate too few bytes: **this must land in the same merge**).

### 1.2 GDScript vs C

| Lives in C (`core/src/stage_world.c`, `core/include/cpore/world.h`) | Lives in GDScript (`godot/devtools/`) |
|---|---|
| snapshot/restore, layout fingerprint, readable error strings | console UI, registry, autocomplete, history |
| debug ops: teleport, spawn, kill, heal, set clock, flags (god, ai off), set motion param | command parsing into debug ops / orders |
| per-world motion params (`w->motion`) + a param table (name, offset, min, max) | tuning registry for C params (via the table) and GDScript params, panel, A/B, diffs |
| `cp_stage_replay_ex` (setup or snapshot + orders + debug ops) | scenario files, saves, sites, bookmarks, feedback bundles, legend, time control, agent socket |
| `world_cli` log v3 (`apps/world_cli.c`) | `world_log.gd` v3 writer/parser |

Timescale, pause and single-step are GDScript only: they change *when* `cp_stage_step` is called,
not what it computes.

### 1.3 Folder and gating

* New folder `godot/devtools/` (scripts, scenes, `tests/`, `README.md`). Library of scenarios:
  `godot/scenarios/creature/*.json` + `*.cpstate`. Tuning diffs: `godot/tuning/*.json`.
* New autoload `Dev="*res://devtools/dev.gd"` in `project.godot`. `Dev.enabled` =
  `OS.is_debug_build() or "--dev" in OS.get_cmdline_user_args()`, and false with `--no-dev`.
  The editor and `godot --path godot` are debug builds, so tools are on while developing; an exported
  release has them off. **Always on** (player build too): key legend (D13), save/load game (D3 slot).
* Feedback folder: in dev builds running from the source tree, `<repo>/feedback/<YYYYMMDD-HHMMSS>/`
  (`ProjectSettings.globalize_path("res://").path_join("../feedback")`, add `feedback/` to
  `.gitignore`); otherwise `user://feedback/<time>/` (`~/.local/share/primigenia/feedback`).
  Overridable with `-- --feedback-dir=<path>`.

### 1.4 Scenario format (D3) and saves

One scenario = `<name>.json` + `<name>.cpstate` (raw snapshot, ~22 KB) + optional `<name>.log`
(recipe, `CPORE_WORLD_LOG 3` from reset). JSON:

```json
{
  "format": "primigenia.scenario/1",
  "name": "creature/garfio_fight", "stage": "creature", "kind": "scenario|save|feedback",
  "note": "free text", "created": "2026-11-17T21:04:00",
  "engine": {"stage_version": 2, "snapshot_version": 1, "layout": "hex16", "build": "git short hash or 'unknown'"},
  "island": {"seed": 1, "terrain_version": 3, "terrain_hash": "hex16"},
  "setup": { "...": "CporeWorld setup dict at reset (get_setup())" },
  "state": "garfio_fight.cpstate", "tick": 1234, "hash": "hex16",
  "recipe": "garfio_fight.log",
  "genome": { "...": "player cpore.creature/4 document, embedded" },
  "wild_bodies": {"3": "res://game/data/garfio.json"},
  "lineage": {"format": "cpore.lineage/0", "traits": []},
  "camera": {"yaw": 0.0, "pitch": 0.24, "distance": 10.0, "orbit_pitch": 0.0},
  "tuning": {"active": "A", "A": {}, "B": {}},
  "time": {"timescale": 1.0, "paused": false}
}
```

Loading rules (in this order; each failure is one readable sentence naming the file and the fix):
1. `format` unknown -> "scenario X: format primigenia.scenario/2 is newer than this build (reads /1)".
2. island seed/hash: if the current island differs, load that island first (cache or generate, the
   boot flow in `main.gd`) then continue; a terrain hash that still differs -> "made on island version
   ..., this build generates ...".
3. `cp_stage_restore` error -> its message (`cp_stage_snapshot_error`). If the error is ENGINE or
   LAYOUT **and** a recipe exists, replay the recipe instead, show a yellow toast "state rebuilt from
   the recipe under engine vN; check it still shows what it should", and offer F5 to re-save.
4. genome rejected by the creature module -> name the genome error (Q11), do not substitute.

**Game saves are scenarios** with `kind: "save"` in `user://saves/slot1.json` (+ `.cpstate`, recipe
omitted for size). UI: two buttons in the pause menu, "Save game" and "Load game" (one slot; Load is
disabled when the slot is empty; overwriting asks nothing in C0). CLI:
`godot --path godot -- --scenario creature/garfio_fight` (resolved under `res://scenarios/`, or an
absolute path / `user://` path); implies `--play`.

### 1.5 Key bindings

Checked against `project.godot` (WASD/arrows, Shift, LMB, RMB/MMB, wheel), `godot/ui/game_ui.gd`
(1-4, Space, Q, E, Tab, Esc), `godot/ui/radial_menu.gd` (A, B, O, I, Esc), the studio (Ctrl+Z/Y/S/O,
Del, Backspace, arrows; studio scene only). All new bindings are InputMap actions using
**physical keycodes** (position, not label: the owner's keyboard is Spanish, where the backtick and
brackets are dead/other keys); the legend shows the real label via
`DisplayServer.keyboard_get_label_from_physical()`.

| Action | Physical key | Context | Build |
|---|---|---|---|
| `legend_hold` | F1 (hold = full sheet, tap = toggle corner hint) | all | all |
| `dev_console` | key left of 1 (`KEY_QUOTELEFT`; "º" on ES, "`" on US) | island, studio | dev |
| `dev_sites` | F2 | island | dev (sandbox later) |
| `dev_bookmark` | Ctrl+B | island, not while modal | dev |
| `dev_tuning` | F3 | island | dev |
| `dev_ab_swap` | F4 | island | dev |
| `dev_quicksave` | F5 | island | dev |
| `dev_quickload` | F6 (opens the scenario picker) | island | dev |
| `dev_feedback` | F8 | island, studio | dev |
| `time_pause` | P | island | dev |
| `time_step` | `.` (period), only while paused | island | dev |
| `time_slower` / `time_faster` | physical `[` / `]` | island | dev |
| reserved, not bound | F7 (free camera), F9 (scrubber), F10 (overlays) | | |

Fix found while checking: the radial maps `KEY_B` with no modifier check, so Ctrl+B with the radial
open would choose Befriend. Step 1 makes the radial ignore events with Ctrl/Alt/Meta, and the
bookmark action is ignored while `Game.modal_open`.

---

## 2. C API added (steps 3 and 4) — exact surface

```c
/* world.h additions */
#define CP_STAGE_SNAPSHOT_VERSION 1
enum { CP_STAGE_ANALYTIC, CP_STAGE_FLAT, CP_STAGE_FIELD };          /* FIELD: F4, PLAN-heights */
typedef struct CpStageField CpStageField;                           /* defined by PLAN-heights H1 */
enum { CP_STAGE_SNAP_OK=0, CP_STAGE_SNAP_ERR_MAGIC=-1, CP_STAGE_SNAP_ERR_FORMAT=-2,
       CP_STAGE_SNAP_ERR_ENGINE=-3, CP_STAGE_SNAP_ERR_LAYOUT=-4, CP_STAGE_SNAP_ERR_SIZE=-5,
       CP_STAGE_SNAP_ERR_FIELD=-6, CP_STAGE_SNAP_ERR_HASH=-7 };
size_t   cp_stage_world_size(void);
size_t   cp_stage_snapshot_size(void);           /* header (48) + offsetof(CpStageWorld, field) */
uint64_t cp_stage_layout(void);                  /* the fingerprint */
int      cp_stage_snapshot(const CpStageWorld *w, uint8_t *out, size_t cap);   /* bytes or -5 */
int      cp_stage_restore(CpStageWorld *w, const uint8_t *in, size_t len, const CpStageField *field);
const char *cp_stage_snapshot_error(int code);   /* one sentence each */

enum { CP_STAGE_DBG_TELEPORT=1, CP_STAGE_DBG_SPAWN, CP_STAGE_DBG_KILL, CP_STAGE_DBG_HEAL,
       CP_STAGE_DBG_CLOCK, CP_STAGE_DBG_FLAGS, CP_STAGE_DBG_PARAM };
enum { CP_STAGE_FLAG_GOD=1, CP_STAGE_FLAG_AI_OFF=2 };
typedef struct { int32_t op,id,a; float x,z,v; } CpStageDebug;              /* 24 bytes */
typedef struct { uint32_t tick; CpStageDebug d; } CpStageDebugEntry;
int  cp_stage_debug(CpStageWorld *w, const CpStageDebug *d);   /* 0 or <0; recomputes w->hash */
const char *cp_stage_debug_error(int code);
typedef struct { const char *name,*group; size_t offset; float min,max; } CpStageParam;
extern const CpStageParam CP_STAGE_PARAMS[]; extern const int CP_STAGE_PARAM_COUNT;
uint64_t cp_stage_replay_ex(const CpStageSetup *setup, const uint8_t *snapshot, size_t snap_len,
                            const CpStageField *field,
                            const CpStageLogEntry *log, int count,
                            const CpStageDebugEntry *dbg, int dbg_count,
                            uint32_t ticks, uint64_t *hashes);   /* snapshot NULL = from setup */
```

Struct changes to `CpStageWorld` (append, in this order, before `field`): `CpStageMotion motion;`
`int32_t debug_flags;` `uint64_t field_hash;` then `const CpStageField *field;` **last**.
`cp_stage_reset` copies `CP_STAGE_MOTION` into `w->motion`, keeps the `field` pointer across its
`memset` (save it, memset, put it back), and `walk()` / `wild_tick()` / `cp_stage_step` read
`w->motion` instead of `CP_STAGE_MOTION`.

Debug op semantics (all validated; a rejected op changes nothing):

| op | fields | rule |
|---|---|---|
| TELEPORT | id (0 player, 1..n wild), x, z | rejected during a fight for the two fighters (-2 "not during a fight"); target must be inside the bound and walkable (`cp_stage_ground` > -0.7, F4: water depth <= 0.7); sets x,z, zero speed; a wild creature's goal = its new position |
| SPAWN | a = species 0..3, x, z | appends `setup.wild[n++]` with the species profile, home = position, bot -1, `roam_ticks = 40` (**no RNG draw**, so other streams are untouched); -3 when n == 24 |
| KILL | id 1..n | `dead = 1`; rejected for the active fighter (-2) |
| HEAL | id, x = hp, z = stamina (negative = to max) | clamped to the profile max; allowed during a fight (also writes the combat creature) |
| CLOCK | a = clock tick 0..11999 | sets `w->clock` |
| FLAGS | a = new flag mask | GOD: after `cp_combat_step` the player's combat hp is kept >= 1 and its stamina refilled, and `finish(DEATH)` cannot fire; AI_OFF: `wild_tick` skips walking and engagement for every wild creature |
| PARAM | a = index into `CP_STAGE_PARAMS`, v = value | clamped to [min, max], written at `offset` into `w->motion` |

`CP_STAGE_PARAMS` lists the 14 `CpStageMotion` fields (group "movement") with ranges ~0.25x..4x of
the default (turn rates 0.5..10 rad/s, accel/brake 2..60 m/s2, ease 0.05..1, ks 0.2..3).

---

## 3. Steps

Each step: one commit (or a few), its acceptance tests green, `make godot-play-test` and
`make godot-ui-test` still green from step 1 on. Tests are headless GDScript under
`godot/devtools/tests/` run by one runner `run_devtools_tests.gd` (pattern of
`game/tests/run_m0_tests.gd`: `t.check(cond, msg)`, exit code = failures), Makefile:

```make
godot-devtools-test: godot
	nice -n 10 timeout 600 $(GODOT) --headless --fixed-fps 60 --path godot --script res://devtools/tests/run_devtools_tests.gd
godot-devtools-evidence: godot
	@mkdir -p docs/evidence/godot/devtools
	LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 600 xvfb-run -a $(GODOT) --rendering-driver opengl3 --max-fps 15 \
	  --resolution 1280x720 --path godot --script res://devtools/tests/evidence.gd -- $(CURDIR)/docs/evidence/godot/devtools
godot-agent-test: godot
	nice -n 10 timeout 300 python3 godot/devtools/agent/test_agent.py --godot $(GODOT)
```

### Step 1 · InputMap migration (GDScript)
Files: `godot/project.godot`, `godot/ui/game_ui.gd`, `godot/ui/radial_menu.gd`, `godot/game/game.gd`.
* Add actions `ability_1..4` (1-4), `guard` (Space), `dodge_left` (Q), `dodge_right` (E),
  `radial_reopen` (Tab), `pause_menu` (Esc), `radial_attack/befriend/observe/intimidate` (A/B/O/I),
  plus every action of §1.5 (physical keycodes). Replace the `match e.keycode` blocks with
  `e.is_action_pressed(...)`. Radial: ignore events with ctrl/alt/meta pressed.
* Add `Game.legend_context() -> StringName` returning `&"console"`, `&"radial"`, `&"paused"`,
  `&"fight"` (`stage.cur.active >= 0`), `&"studio"`, `&"walk"` (first match wins); the console sets
  `Game.console_open`.
Tests: `make godot-ui-test` and `make godot-play-test` unchanged-green (they push key events: if they
use `keycode` only, make the new events match by also setting `physical_keycode` in the test helper);
new `test_inputmap.gd`: every action named in `legend.json` (step 2) exists, no two actions in the same
context share an event, Ctrl+B with the radial open leaves the mode unchanged.

### Step 2 · D13 key legend (GDScript, all builds)
Files: `godot/devtools/legend.json`, `godot/devtools/legend.gd` (CanvasLayer 20), `dev.gd` (adds it).
* `legend.json`: `{"actions": {"move_forward": {"label": "Move", "contexts": ["walk","fight"], "group": "Move", "corner": ["walk"]}, ...}, "mouse": {...}}`;
  dev-only actions carry `"dev": true` and are hidden when `Dev.enabled` is false.
* Text per action generated from `InputMap.action_get_events()` (keys through
  `keyboard_get_label_from_physical`, mouse buttons by name, modifiers prefixed). Nothing is typed by
  hand except the label.
* Corner hint: 3-4 entries flagged `corner` for the current context, bottom-left, palette colours
  (`ui/palette.gd`). F1 held: full sheet grouped by `group`, current context first. Studio: the sheet
  lists the studio context (studio keys are still hard-coded in `studio.gd`; list them in
  `legend.json` with `"fixed": "Ctrl+Z"` until the studio migrates; a test flags any `fixed` entry so
  it is not forgotten).
Tests: generation matches InputMap for every entry; context switch walk -> fight -> radial changes the
corner hint; `Dev.enabled=false` hides dev rows; a rebound action (change InputMap at runtime) shows the
new key. Evidence: none yet (shared screenshot in step 13).

### Step 3 · [CORE] Snapshot / restore, world size, layout fingerprint
Files: `core/include/cpore/world.h`, `core/src/stage_world.c`, `tests/test_world.c`,
`bindings/python/cpore/world.py` (only `_WORLD_BYTES = lib.cp_stage_world_size()`; coordinate, §1.1).
* Append to `CpStageWorld` exactly as §2 (motion, debug_flags, field_hash, field last). Reset copies
  motion and preserves `field`. `walk`/`step` read `w->motion`. Hash: fold motion only if
  `memcmp(&w->motion,&CP_STAGE_MOTION,sizeof)`, flags only if nonzero, field_hash only if terrain ==
  FIELD.
* Snapshot header (48 bytes, little-endian): `"CPSTAGE\0"`, u32 snapshot version, u32
  `CP_STAGE_VERSION`, u64 layout, u32 payload bytes, u32 0, u64 field_hash, u64 state hash. Restore:
  validate in the order of the error enum, copy into a temporary `CpStageWorld`, set `field`,
  recompute `cp_stage_hash`, compare, then copy to `*w`.
Tests (C, in `make test`): (a) the three golden logs still give their committed hashes; (b) for seeds
1/42/987654321: run 3000 ticks of the golden inputs, snapshot at ticks 0, 1, 777 (mid-fight if the log
has one; pick the tick from `started`), restore into a fresh world, continue with the same inputs:
every per-tick hash and the final `cp_stage_observe` text equal; (c) `snapshot(restore(blob)) == blob`
byte for byte; (d) each error code: wrong magic, version, engine, layout (patch the header), short
length, hash (flip a payload byte), field mismatch; (e) `cp_stage_world_size() == sizeof`.
Also run `make tourney` (unchanged) and `python3 bindings/python/world_smoke.py`.

### Step 4 · [CORE] Debug ops, param table, replay_ex, log v3
Files: `world.h`, `stage_world.c`, `apps/world_cli.c`, `tests/test_world.c`, `tests/golden/` (new
file only: `world-debug-42.log` + `.hashes`).
* Implement §2 debug ops, `CP_STAGE_PARAMS`, `cp_stage_replay_ex` (old `cp_stage_replay` becomes a
  wrapper with no snapshot and no debug entries).
* `CPORE_WORLD_LOG 3`: v2 body, then `<n_debug>` and lines `tick op id a x z v`; optional line
  `snapshot <file>` right after the header (path relative to the log) meaning "restore this first";
  F4 adds a `field` line (PLAN-heights H3). `world_cli --replay` accepts v2 and v3, prints the same
  per-tick hash lines as today.
Tests: each op's accept/reject cases; god survives a fight he would lose (golden 42's fight, seed with
a known death) and its hash differs from the plain run; ai_off: wild positions frozen 100 ticks; a
PARAM change mid-run replays identically through `cp_stage_replay_ex` and through `world_cli`;
spawn does not change `roam_rng`/`spawn_rng` state; new golden `world-debug-42` (justified: new
feature, nothing re-recorded).

### Step 5 · Extension + bridge: snapshot, debug, params, log v3
Files: `godot/extension/cpore_world.{h,cpp}`, `godot/game/stage/stage_world.gd`,
`godot/game/stage/world_log.gd`, `godot/game/tests/test_world.gd`.
* `CporeWorld`: `snapshot() -> PackedByteArray`, `restore(bytes) -> int` (passes the attached field),
  `static snapshot_error(code)`, `debug(dict {op,id,a,x,z,v}) -> int`, `static debug_error(code)`,
  `static params() -> Array[{index,name,group,min,max,default}]`, `param(index) -> float` (reads
  `w->motion`), `layout() -> String`.
* `StageWorld`: `queue_debug(op_dict)` queues the op; queued ops are applied at the start of the next
  `step_once()` (rule §1.1) and each result is emitted via `signal debug_applied(op, rc)` (the console
  prints rejections); accepted ops go to `log_debug: Array[{tick, op}]`. Add
  `log_start_tick` and `start_snapshot` (set by `restore_from(bytes)`), `export_log()` writes v3 and,
  when started from a snapshot, the `snapshot` line. Add a ring of snapshots every 100 ticks (8 kept)
  for D5 (step 11).
Tests (`make godot-test` gets the new checks): restore in Godot then 600 ticks == uninterrupted run
(hashes); a session with tp + god + param exports a v3 log that `world_cli --replay` verifies; the
existing golden replays still pass.

### Step 6 · D7 time control (GDScript)
Files: `godot/devtools/time_control.gd`, `stage_world.gd` (`timescale`, `paused`, `step_ticks(n)`),
`dev.gd`.
* `advance(delta)` adds `minf(delta,0.25) * timescale`; `paused` adds nothing; steps per frame capped at
  60 (beyond that the achieved rate is shown, e.g. "x100 (x37 achieved)"). Ladder for `[`/`]`:
  0.1, 0.25, 0.5, 1, 2, 5, 10, 100. `.` steps one tick when paused. HUD chip top-right
  "PAUSED · tick 1234" / "x0.25". Pause menu (Esc) still disables the stage node as today.
Tests: 2 s at x0.5 = 10 ticks; paused + 3 steps = 3 ticks; x100 for 1 s under `--fixed-fps 60` steps
60 per frame cap; hashes identical to an x1 run with the same inputs (input provider driven by tick
index, not time).

### Step 7 · D1 console (GDScript)
Files: `godot/devtools/console/console.gd` (CanvasLayer 30, LineEdit + RichTextLabel log),
`godot/devtools/console/registry.gd`, `godot/devtools/console/commands_creature.gd`.
* Registry: `register(name, args_spec, help, fn, {dev=true, sandbox=false, changes_sim=false})`;
  `execute(text) -> {ok, out, error}` (pure, used by the UI, the agent socket and tests);
  `complete(prefix) -> Array` (command names, then per-argument completers: site names, species names,
  param names, scenario names); history (50, saved to `user://console_history.txt`); `help [cmd]`.
  While open: `Game.console_open = true` (movement blocked through `Game.movement_blocked()`),
  Tab completes, Up/Down history, Esc closes.
* Commands in C0 (sim-changing ones build a debug op or an order; nothing writes C state otherwise):

| command | does |
|---|---|
| `tp <site>` / `tp <x> <z>` / `tp #id <x> <z>` | TELEPORT (site from D2, step 9) |
| `spawn <species> [count]` | SPAWN at 8 m steps on a ring 12 m ahead of the player; only species with a body (`wild_bodies`: Garfio today), else "no body for species X yet" |
| `kill #id` / `kill radius <m>` | KILL |
| `heal [#id]` / `give hp <n>` / `give stamina <n>` | HEAL; `give dna` -> "DNA arrives with C2 (P4)" |
| `time <hh:mm>` | CLOCK (day = 12000 ticks) |
| `timescale <x>` / `pause` / `step [n]` | D7 |
| `ai on|off`, `god [on|off]` | FLAGS |
| `reveal` | shows hidden sites in the picker (presentation only) |
| `tune <param> <value>` / `tune list` / `ab` | D4 |
| `save <name>` / `load <name>` / `scenarios` | D3 |
| `order <text>` | `cp_stage_command` text (`attack #1 bite`, `go 10 20`) as the next order |
| `trait add <name>` / `stage <name>` | registered, answer "lineage traits arrive with L0 (C2)" / "stage jump is DT2" |
| `hash` / `tick` / `obs` | print `world.hash()`, tick, `observe()` |

Tests: parse/complete/history units; `tp 30 40` moves the C player (after one tick) and is in the v3
log; `god` + `kill radius 100` path; an invalid command returns the readable error and changes no hash.

### Step 8 · D3 scenarios + saves (GDScript)
Files: `godot/devtools/scenario.gd` (`save(path, kind, note) -> err`, `load(path) -> err`,
`validate(dict) -> String`), `godot/game/island/island.gd` (`_build_stage` takes `Game.pending_scenario`:
reset with its setup, restore its state, build `ActorHost`s **from the restored entities** so spawned
creatures get bodies; camera from `camera`), `godot/game/main.gd` (`--scenario`), `godot/ui/pause_menu.gd`
(Save game / Load game), `godot/scenarios/creature/` (3 curated: `nest_start`, `garfio_close`
(player 8 m from Garfio, not fighting), `far_meadow` (after F4: a slope far from the valley; before F4
a valley edge)).
* F5 saves `<scenario dir>/quick-<time>.json` (dev builds: `godot/scenarios/creature/` from source,
  else `user://scenarios/`), F6 opens a picker (the D2 picker widget reused, step 9).
* `recipe`: the session's v3 log from reset (scenarios), omitted for saves and when the session itself
  started from a snapshot (then the recipe is the parent's recipe + this log; if no parent recipe,
  omitted and documented).
Tests: save -> load -> 300 ticks == continuing the original (hashes); every error of §1.4 produces its
sentence (fixtures with a patched header, wrong format, unknown island hash, broken genome); ENGINE
mismatch with a recipe rebuilds and toasts; CLI `--scenario creature/garfio_close` reaches the island at
the saved tick (`play_test`-style run, headless); pause-menu save/load round-trip in `user://play-test`.

### Step 9 · D2 sites + bookmarks + picker (GDScript)
Files: `godot/devtools/sites.gd`, `godot/devtools/site_picker.gd`, `game/stage/stage_setup.gd` (expose
nest/home), `extension` untouched (caves/volcano already in the terrain entry).
* `Sites.for_island(data, setup) -> Array[{id, name, kind, pos: Vector3, hidden, source}]`, pure and
  deterministic for a seed: nest, Garfio's home (`wild[i].home`), each cave entrance (`data.caves`,
  "waterfall cave" when `waterfall`), volcano and crater rim, lake (largest pond centroid), pass and
  col (terrain params `pass_x/y`, `col_x/y` on the ring radius), the 3 highest local maxima >200 m apart
  ("viewpoint 1..3"), shoreline sand point nearest the nest. Later stages add species dens, meteor
  shards, fossils (marked `hidden` = shown only after `reveal`).
* Bookmarks: Ctrl+B stores `{name: "bookmark N", pos, camera}` in `user://bookmarks/<seed>.json`;
  rename/delete in the picker.
* Picker (F2): search field (substring, fuzzy by token), list with kind icon (no thumbnails in DT0:
  thumbnails need renders; listed as DT1), distance from the player, Enter = `tp`. Before F4 lands,
  sites outside the C bound are listed greyed with "outside the playable valley (F4)".
Tests: same seed -> same list (ids stable); every non-hidden site is on land; tp to each reachable
site moves the player there (C position within 0.5 m after one tick); bookmark persists across
restarts.

### Step 10 · D4 live tuning + A/B (GDScript)
Files: `godot/devtools/tuning/registry.gd`, `tuning/panel.gd`, `godot/tuning/` (diffs),
`godot/game/player/chase_camera.gd` (turn `LEAD, POS_TAU, VEL_TAU, YAW_TAU, YAW_MAX, YAW_ACC,
AWAY_MAX, PIVOT_RATE, ENGAGE_TIME, ENGAGE_TOL` from `const` into `var` with the same defaults),
`godot/locomotion/loco_controller.gd` (only reads; its tunables are already `var`).
* Registry entry: `{key: "camera/yaw_max", group, min, max, step, default, get: Callable, set: Callable,
  sim: bool}`. C entries come from `CporeWorld.params()` (key `sim/<name>`, `sim=true`): setting one
  queues a PARAM debug op (logged, replayable). GDScript entries: chase camera (above), loco
  (`vault_gain, leg_axis_torque, bank_gain, stability_gain, girdle_gain`), `Game.settings` controls.
* Panel (F3): groups movement / camera / locomotion / combat (empty in DT0) / look, slider + value +
  reset per row, "changed only" filter. Diff = entries != default: `{"format":"primigenia.tuning/1",
  "base_build":"...", "values":{key:value}, "reason":""}`; Save writes `godot/tuning/<name>.json`
  (dev source tree) else `user://tuning/`.
* A/B: two diffs held at once; F4 applies the other one (all entries reset to default then the slot's
  values; sim entries as PARAM ops); chip "Tuning B: turn-240" in the HUD corner and in the legend
  header; feedback and scenarios record both slots and the active one.
Tests: set/get round trip for each GDScript entry; a sim entry changes `CporeWorld.param()` after one
tick and appears in the v3 log; swap A/B twice returns to identical values; diff file round trip;
defaults load leaves the world hash equal to an untuned run (hash rule §1.1).

### Step 11 · D5 F8 feedback (GDScript)
Files: `godot/devtools/feedback.gd`, `.gitignore` (`feedback/`).
* F8: freeze input, small dialog (multiline note, Enter saves, Esc cancels; the sim stays paused while
  it is open). Writes to the folder of §1.3: `screenshot.png` (viewport image, skipped in headless with
  `"screenshot": null`), `scenario.json` + `.cpstate` (now), `replay.log` (v3, starting from the ring
  snapshot >= 600 ticks old, with its `replay_start.cpstate`) + `replay.hashes`, `tuning.json` (both
  slots + active), `meta.json` `{build, godot version, seed, tick, timescale, legend_context, fps avg,
  note, os}`, `log.txt` (last 200 engine log lines through an `OS.add_logger` ring, as play_test does).
  Build hash: `git rev-parse --short HEAD` at export/`make godot` time written to
  `godot/devtools/build.txt` (gitignored); missing -> "unknown".
Tests: F8 in a headless session writes all files; `world_cli --replay replay.log` reproduces
`replay.hashes`; restoring `scenario.cpstate` gives the hash in `meta.json`.

### Step 12 · Agent interface: socket protocol (GDScript)
Files: `godot/devtools/agent/agent_server.gd`, `godot/devtools/agent/PROTOCOL.md` (short), `dev.gd`.
Purpose: `tools/agentplay` (branch `e2e-agents`; cheap LLMs that already play the C sim through
`bindings/python` `StageWorld`) drives the **real Godot game** with the same commands as the human
console.
* Start: `godot --path godot [--headless] -- --agent [--agent-port=47110] [--scenario <name>] [--play]`.
  Prints one stdout line `AGENT_READY {"port":47110,"build":"...","protocol":1}` when the island is
  up. `TCPServer` bound to 127.0.0.1 only, one client, polled in `_process`.
* **Lock-step:** in agent mode the stage never advances on its own (`paused`), the agent steps it. The
  agent's input replaces the stage's input provider while connected (logged exactly like player
  input); console commands go through `registry.execute` (same code path, so the same debug ops and
  log).
* JSON lines, one request -> one response with the same `id`; asynchronous events have no `id`:

| request | response |
|---|---|
| `{"id":1,"cmd":"console","text":"tp crater"}` | `{"id":1,"ok":true,"out":"..."}` or `{"ok":false,"error":"..."}` |
| `{"cmd":"act","order":"attack #1 bite"}` or `{"cmd":"act","input":{"verb":3,"hx":0,"hz":32767,"sprint":1}}` | ok / error (validated with `CporeWorld.order` on the next tick) |
| `{"cmd":"step","ticks":10}` | `{"ok":true,"tick":..,"hash":"..","obs":{...},"events":[...]}` |
| `{"cmd":"observe"}` | same `obs` without stepping |
| `{"cmd":"screenshot"}` | `{"ok":true,"path":"/abs/shot-000123.png"}`; headless -> `{"ok":false,"error":"no renderer (run under xvfb without --headless)"}` |
| `{"cmd":"scenario_save","name":..}` / `{"cmd":"scenario_load","name":..}` | ok / the §1.4 error sentence |
| `{"cmd":"verify"}` | replays the session log from its start in a fresh `CporeWorld`: `{"ok":true,"match":true,"ticks":n}` |
| `{"cmd":"quit"}` | ok, then the process exits 0 |

* `obs` = `JSON.parse(world.observe())` (the **same** `cp_stage_observe` text the Python binding's
  `StageWorld.observe()` returns, so policies are shared) plus `{"tick","fighting","player_rendered":
  {x,y,z}, "legend_context"}`. `events` = combat events of the stepped ticks.
* Pushed events: `{"event":"error","source":"engine|c_input|console","text":..}` (engine errors from
  the `OS.add_logger` hook), `{"event":"invariant","name":..,"detail":..}` for: non-finite entity
  position, sim y vs rendered y > 0.05 m (after F4), C rejected an input, an entity that was ordered to
  move but did not move for 30 ticks ("stuck"), `verify` mismatch.
Tests: covered by step 13's client test.

### Step 13 · Agent client + evidence + docs
Files: `godot/devtools/agent/client.py` (stdlib only, ~80 lines: spawn Godot, wait for
`AGENT_READY`, `send(cmd)`), `godot/devtools/agent/test_agent.py`, `godot/devtools/README.md`,
`docs/godot/DEVTOOLS.md` (the module doc: interfaces, keys, formats, what is verified), Makefile
targets of §3, `godot/devtools/tests/evidence.gd`.
* `test_agent.py` (headless, `timeout 300` inside): start with `--scenario creature/garfio_close`,
  `console "god on"`, act heading, step 50, attack until the fight ends or 600 ticks, `verify` -> match,
  `scenario_save`, `quit`; asserts no `error` events. The harness on `e2e-agents` imports `client.py`
  or copies it; tell the coordinator.
* Evidence (`make godot-devtools-evidence`, **3 software screenshots total**, in
  `docs/evidence/godot/devtools/`): `legend.png` (F1 sheet over the walk context), `console.png`
  (console with completion list + tuning panel open with B active), `picker.png` (site picker with
  search text).

---

## 4. Gate (owner, C0)

`godot --path godot`: F2 -> type "crater" -> Enter: there. F3 -> movement -> jog_k up: faster at once.
Save as B, F4 swaps A/B, chip shows the slot. F8 with a note -> folder appears with all files. F5/F6
round trip. Esc -> Save game / Load game. F1 shows the right keys in walk, fight, radial.

## 5. Risks

* **Python ABI**: `CpStageWorld` grows; `_WORLD_BYTES` must switch to `cp_stage_world_size()` in the
  same merge as step 3 or the Python binding overflows its buffer. Shared file with `e2e-agents`.
* Raw-struct snapshots tie scenario files to `CP_STAGE_VERSION` + layout. Mitigated by recipes and loud
  errors; curated scenarios must keep a recipe (test: every file in `godot/scenarios/` has one).
* Agent lock-step vs the human loop: one flag (`Dev.agent`) decides who advances time; tests cover both.
* `--fixed-fps` tests with timescale x100 can be slow under llvmpipe; x100 is unit-tested on the
  `StageWorld` without the island.
* Hard-coded studio keys stay until the studio migrates (flagged by the legend test).

## 6. Core sequencing with PLAN-heights

One series of commits on `stage_world.c`, in this order: **DT step 3** (struct tail incl. the `field`
slot, snapshot) -> **H1** (field mode) -> **H2** (bound + fight clamp) -> **DT step 4** (debug ops,
replay_ex, log v3) -> **H3** (`world_cli` field line, field golden). GDScript steps 1, 2, 6, 7 (without
sim commands) can run in parallel with the core series.
