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
