extends CanvasLayer
## D5 F8 feedback: freezes input, asks for a note (Enter saves, Shift+Enter is a new line, Esc cancels) and writes a
## folder an agent can open: screenshot, the scenario of this moment, a replay that reproduces the last ~minute,
## both tuning slots, meta and the last 200 engine log lines.

const Palette := preload("res://ui/palette.gd")
const Scenario := preload("res://devtools/scenario.gd")
const WorldLog := preload("res://game/stage/world_log.gd")

const REPLAY_MIN_TICKS := 600
const LOG_KEEP := 200

## Keeps the last LOG_KEEP engine messages (add with OS.add_logger).
class LogRing extends Logger:
	var lines: Array = []
	func _log_message(message: String, error: bool) -> void:
		_push(("ERR " if error else "") + message.strip_edges())
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		_push("ERROR %s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
	func _push(s: String) -> void:
		lines.append(s)
		if lines.size() > LOG_KEEP:
			lines.pop_front()

static var log_ring: LogRing = null

static func install_logger() -> void:
	if log_ring == null:
		log_ring = LogRing.new()
		OS.add_logger(log_ring)

## The folder for this bundle: --feedback-dir=<path>, else <repo>/feedback/<stamp> when writable, else user://feedback/<stamp>.
static func output_dir(stamp: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--feedback-dir="):
			return a.substr(15).path_join(stamp)
	var repo := ProjectSettings.globalize_path("res://").path_join("../" + "feedback").simplify_path()
	if OS.is_debug_build() and not OS.has_feature("template"):
		var real := repo.path_join(stamp)
		if DirAccess.make_dir_recursive_absolute(real) == OK and FileAccess.open(real.path_join(".w"), FileAccess.WRITE) != null:
			DirAccess.remove_absolute(real.path_join(".w"))
			return real
	return ProjectSettings.globalize_path("user://feedback").path_join(stamp)

static func stamp_now() -> String:
	return Time.get_datetime_string_from_system(false).replace("-", "").replace(":", "").replace("T", "-")

## Writes the bundle. Returns "" or one sentence. `ctx` is Island.scenario_ctx(); `image` may be null (headless).
static func write(stage, ctx: Dictionary, note: String, dir: String, meta_extra: Dictionary = {}, image: Image = null) -> String:
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return "cannot create %s" % dir
	var shot = null
	if image != null and image.save_png(dir.path_join("screenshot.png")) == OK:
		shot = "screenshot.png"
	var err := Scenario.save(stage, ctx, dir.path_join("scenario"), "feedback", note)
	if err != "":
		return err
	# Replay: from the newest ring snapshot at least REPLAY_MIN_TICKS old, else from the start of the session.
	var cur_tick := int(stage.cur.tick)
	var start = null
	for r in stage.snapshot_ring:
		if int(r.tick) <= cur_tick - REPLAY_MIN_TICKS:
			start = r
	var first_tick: int = int(stage.log_start_tick)
	var opts := {}
	var field := {}
	var setup: Dictionary = stage.get("_setup")
	if stage.world.has_field() and int(setup.get("terrain", 0)) == 2:
		var info: Dictionary = stage.world.field_info()
		opts["field"] = {"seed": info.seed, "n": info.n, "size_m": info.size_m, "hash": info.hash}
	var inputs: Array = stage.log_inputs
	var hashes: PackedStringArray = stage.hashes
	var dbg: Array = stage.log_debug
	var replay_start := ""
	if start != null:
		var idx: int = int(start.tick) - first_tick
		inputs = inputs.slice(idx)
		hashes = hashes.slice(idx)
		dbg = dbg.filter(func(e): return int(e.tick) >= int(start.tick))
		var f := FileAccess.open(dir.path_join("replay_start.cpstate"), FileAccess.WRITE)
		f.store_buffer(start.bytes)
		f.close()
		replay_start = "replay_start.cpstate"
	elif stage.start_snapshot.size() > 0:
		var f2 := FileAccess.open(dir.path_join("replay_start.cpstate"), FileAccess.WRITE)
		f2.store_buffer(stage.start_snapshot)
		f2.close()
		replay_start = "replay_start.cpstate"
	if not dbg.is_empty():
		opts["debug"] = dbg
	if replay_start != "":
		opts["snapshot"] = replay_start
	var rl := FileAccess.open(dir.path_join("replay.log"), FileAccess.WRITE)
	rl.store_string(WorldLog.write(setup, inputs, opts))
	rl.close()
	var rh := FileAccess.open(dir.path_join("replay.hashes"), FileAccess.WRITE)
	rh.store_string("\n".join(hashes) + "\n")
	rh.close()
	var tf := FileAccess.open(dir.path_join("tuning.json"), FileAccess.WRITE)
	tf.store_string(JSON.stringify(ctx.get("tuning", {}), "\t"))
	tf.close()
	var meta := {"build": Scenario.build_text(), "godot": Engine.get_version_info().string, "seed": ctx.get("island", {}).get("seed", 0),
		"tick": cur_tick, "hash": stage.world.state().hash, "timescale": stage.timescale, "paused": stage.paused,
		"legend_context": String(meta_extra.get("legend_context", "")), "fps_avg": meta_extra.get("fps_avg", 0.0), "note": note,
		"os": OS.get_name(), "options": ctx.get("tuning", {}).get("options", {}), "screenshot": shot, "replay_from_tick": int(start.tick) if start != null else first_tick}
	var mf := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(meta, "\t"))
	mf.close()
	var lf := FileAccess.open(dir.path_join("log.txt"), FileAccess.WRITE)
	lf.store_string("\n".join(PackedStringArray(log_ring.lines if log_ring != null else [])) + "\n")
	lf.close()
	return ""

# --- the dialog --------------------------------------------------------------------------------------

var panel: PanelContainer
var edit: TextEdit
var is_open := false
var last_dir := ""
var _was_paused := false

func _init() -> void:
	layer = 40

func _ready() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL_SOLID, 0.97), 16, Palette.GOLD, 16))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 220)
	panel.visible = false
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := Label.new()
	l.text = "Feedback: what do you see? (Enter saves, Shift+Enter new line, Esc cancels)"
	l.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(l)
	edit = TextEdit.new()
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(edit)
	add_child(panel)

func open() -> void:
	if is_open or Game.stage == null:
		return
	is_open = true
	panel.visible = true
	Game.console_open = true
	_was_paused = Game.stage.paused
	Game.stage.paused = true      # the sim stays paused while the dialog is open
	edit.text = ""
	edit.grab_focus()

func close(save: bool) -> void:
	if not is_open:
		return
	is_open = false
	panel.visible = false
	Game.console_open = false
	var note := edit.text.strip_edges()
	edit.release_focus()
	Game.stage.paused = _was_paused
	if save:
		var res := save_now(note)
		var scene := get_tree().current_scene
		var gui = scene.get("stage_ui") if scene != null else null
		if gui != null:
			gui.ui.show_message(res if res != "" and not res.begins_with("saved ") else (res if res != "" else "feedback saved"), "info")

## Captures the bundle for the running game. Returns "saved <dir>" or an error sentence.
func save_now(note: String) -> String:
	var scene := get_tree().current_scene
	var ctx: Dictionary = scene.scenario_ctx() if scene != null and scene.has_method("scenario_ctx") else {}
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		image = get_viewport().get_texture().get_image()
	var dir := output_dir(stamp_now())
	var err := write(Game.stage, ctx, note, dir, {"legend_context": Game.legend_context(), "fps_avg": Performance.get_monitor(Performance.TIME_FPS)}, image)
	if err != "":
		return err
	last_dir = dir
	return "saved " + dir

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or not Dev.enabled:
		return
	if e.is_action_pressed("dev_feedback") and not is_open and not Game.console_open:
		open()
		get_viewport().set_input_as_handled()
	elif is_open and e.keycode == KEY_ESCAPE:
		close(false)
		get_viewport().set_input_as_handled()
	elif is_open and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and not e.shift_pressed:
		close(true)
		get_viewport().set_input_as_handled()
