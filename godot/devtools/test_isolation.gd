extends RefCounted
## Test isolation for the owner's live feedback folders (feedback/questions, feedback/notes, feedback/<stamp>).
## A harness run must never read or write the owner's repo-root feedback/: a pending question card eats key 1 in the play test.
## Harness detection (any one is enough): the CPORE_TEST=1 env var (the Makefile exports it), the --test-isolated flag, or a
## --script / -s entry point (the game itself always starts from its main scene, never from --script).
## An explicit --questions-dir= / --notes-dir= / --feedback-dir= still wins. Isolated dir: <user data>/test-feedback/<pid>/<kind>.

static func active() -> bool:
	if OS.get_environment("CPORE_TEST") == "1":
		return true
	var all := OS.get_cmdline_args()
	for a in all:
		if a == "--test-isolated" or a == "--script" or a == "-s":
			return true
	for a in OS.get_cmdline_user_args():
		if a == "--test-isolated":
			return true
	return false

static func dir_for(kind: String) -> String:
	return OS.get_user_data_dir().path_join("test-feedback").path_join(str(OS.get_process_id())).path_join(kind)

## The owner's per-user state (settings.cfg, studio saves, tuning presets, scenarios, saves, bookmarks, legacy sheet, console
## history) must never leak into a test: a studio creature or a changed setting steers the first-quest e2e (the "friend" step
## fails with the owner's lean-runner body). Under a harness every such path resolves to user://test-user/<pid>/<rel>, a fresh
## empty folder per process; in the real game it is plain user://<rel>. Shared, content-addressed caches (terrain, shaders) are
## deliberately not routed through here.
static func user(rel: String) -> String:
	if not active():
		return "user://" + rel
	var p := "user://test-user/%d/%s" % [OS.get_process_id(), rel]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p).get_base_dir())
	return p
