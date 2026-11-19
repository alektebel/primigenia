class_name RenderChoice
extends RefCounted
## Picks the renderer at launch (A24): Forward+ (Vulkan) automatically on a discrete GPU, GL Compatibility everywhere
## else, with a manual override. The renderer cannot change inside a running Godot, so when the running one is not the
## wanted one the game relaunches itself once with `--rendering-method forward_plus` and quits.
##
## How it decides (first match wins):
##   1. never relaunch: headless, an editor/script/import run, an explicit --rendering-method / --rendering-driver, or a
##      process that is already the relaunched child (`--cpore-relaunched`, which also stops any loop);
##   2. override: env CPORE_RENDERER = compat | forward_plus, else the setting `renderer` in user://settings.cfg
##      ([game] renderer = auto | forward_plus | compatibility);
##   3. auto: relaunch when the video adapter of the running (GL) context looks like a discrete GPU: adapter type
##      DISCRETE_GPU, or a name with NVIDIA / GeForce / RTX / GTX / Radeon RX / Radeon PRO / Arc; software rasterisers
##      (llvmpipe, SwiftShader) and integrated parts stay on Compatibility.
## No crash where Vulkan is absent: the child asks for Vulkan, Godot's own fallback (rendering/rendering_device/
## fallback_to_opengl3, on by default) starts it on OpenGL 3 instead, and the child never relaunches again.
## A hybrid laptop whose GL context sits on the integrated GPU stays on Compatibility until the setting is forced.
## Not verified on a GPU here (no Vulkan in the build environment); make godot-play-hq is the manual route.

const SETTINGS_PATH := "user://settings.cfg"
const SOFTWARE := ["llvmpipe", "softpipe", "swiftshader", "software", "microsoft basic"]
const DISCRETE := ["nvidia", "geforce", "rtx", "gtx", "radeon rx", "radeon pro", "radeon vii", "arc(tm)", "intel(r) arc", "arc a", "arc b"]


static func setting() -> String:
	var v := OS.get_environment("CPORE_RENDERER").to_lower()
	if v in ["compat", "compatibility"]:
		return "compatibility"
	if v in ["forward_plus", "forwardplus", "hq"]:
		return "forward_plus"
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var s := str(cfg.get_value("game", "renderer", "auto"))
		if s in ["auto", "forward_plus", "compatibility"]:
			return s
	return "auto"


static func looks_discrete(adapter_name: String, adapter_type: int) -> bool:
	var n := adapter_name.to_lower()
	for w in SOFTWARE:
		if n.contains(w):
			return false
	if adapter_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		return true
	for w in DISCRETE:
		if n.contains(w):
			return true
	return false


static func blocked() -> bool:
	if DisplayServer.get_name() == "headless" or Engine.is_editor_hint():
		return true
	for a in OS.get_cmdline_args():
		if a in ["--rendering-method", "--rendering-driver", "--script", "-s", "--check-only", "--import", "--cpore-relaunched", "--headless", "--editor", "-e", "--quit", "--quit-after"]:
			return true
	return false


## The decision as data (tests, the settings screen): {relaunch, reason}.
static func decide(adapter_name := "", adapter_type := -1) -> Dictionary:
	if blocked():
		return {"relaunch": false, "reason": "blocked (headless, script, explicit method or already relaunched)"}
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		return {"relaunch": false, "reason": "already Forward+"}
	var mode := setting()
	if mode == "compatibility":
		return {"relaunch": false, "reason": "setting: compatibility"}
	if mode == "forward_plus":
		return {"relaunch": true, "reason": "setting: forward_plus"}
	var an := adapter_name if adapter_name != "" else RenderingServer.get_video_adapter_name()
	var at := adapter_type if adapter_type >= 0 else int(RenderingServer.get_video_adapter_type())
	if looks_discrete(an, at):
		return {"relaunch": true, "reason": "auto: discrete GPU (%s)" % an}
	return {"relaunch": false, "reason": "auto: no discrete GPU (%s)" % an}


## Relaunches into Forward+ when wanted. Returns true when the caller must quit.
static func maybe_relaunch() -> bool:
	var d := decide()
	print("renderer: %s (%s)" % [RenderingServer.get_current_rendering_method(), d["reason"]])
	if not d["relaunch"]:
		return false
	var args := PackedStringArray(OS.get_cmdline_args())
	args.append_array(["--rendering-method", "forward_plus", "--rendering-driver", "vulkan", "--cpore-relaunched"])
	return OS.create_process(OS.get_executable_path(), args) > 0
