extends RefCounted
# Weather globals for clouds.gdshaderinc (project.godot [shader_globals]). The sun direction is fixed by the hero look, so the
# time-of-day preset only tints clouds and fog; cloud_time (the wind) is advanced by the island every frame.

const PRESETS := {
	"dawn": {"tod": 0.0, "cover": 0.55, "fog": 0.8},
	"midday": {"tod": 0.5, "cover": 0.55, "fog": 0.0},
	"evening": {"tod": 1.0, "cover": 0.55, "fog": 0.0},
	"clear": {"tod": 0.5, "cover": 0.0, "fog": 0.0},
	"overcast": {"tod": 0.5, "cover": 1.0, "fog": 0.0},
}
const DEFAULT := {"tod": 0.75, "cover": 0.5, "fog": 0.0}

static func apply(preset) -> void:
	var p: Dictionary = PRESETS.get(preset, DEFAULT) if typeof(preset) == TYPE_STRING else preset
	RenderingServer.global_shader_parameter_set("sky_tod", float(p.tod))
	RenderingServer.global_shader_parameter_set("cloud_cover", float(p.cover))
	RenderingServer.global_shader_parameter_set("fog_amount", float(p.fog))

static var frozen_time := -1.0   # tests and evidence pin the wind phase here (>= 0)

static func set_time(seconds: float) -> void:
	RenderingServer.global_shader_parameter_set("cloud_time", seconds if frozen_time < 0.0 else frozen_time)
