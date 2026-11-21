extends RefCounted
# L0 scorecard (devtools/zoo/loco_score_core.gd): one body x one scenario runs and every metric key is there, finite or null with a reason.

const KEYS := ["head_pitch_deg", "shoulder_hip_ratio", "back_slope_deg", "torso_roll_deg", "roll_plant_lag", "torso_bob_cm", "foot_slip_cm",
	"duty_factor", "airborne_frac", "footfall", "stride_len_m", "cadence_hz", "leg_extension", "min_turn_radius_m", "pivot_frac", "stall_frac", "knee_flip_frac", "foot_penetration_cm", "gait_symmetry"]

func _finite(v) -> bool:
	if v is float:
		return is_finite(v)
	if v is Dictionary:
		for k in v:
			if not _finite(v[k]):
				return false
		return true
	if v is Array:
		for x in v:
			if not _finite(x):
				return false
	return true

func run(t) -> void:
	var core = load("res://devtools/zoo/loco_score_core.gd")
	var res: Dictionary = core.run_case(t.root, "hero", "walk", 120)
	t.check(not res.is_empty() and res.has("metrics"), "loco score returned metrics")
	if not res.has("metrics"):
		return
	t.eq(res.frames, 360, "120 ticks sampled at 3 frames per tick")
	for k in KEYS:
		t.check(res.metrics.has(k), "metric %s present" % k)
		if res.metrics.has(k):
			var v = res.metrics[k]
			if v == null:
				t.check(String(res.reasons.get(k, "")) != "", "metric %s is null with a reason" % k)
			else:
				t.check(_finite(v), "metric %s is finite" % k)
	var res2: Dictionary = core.run_case(t.root, "hero", "walk", 120)
	t.check(JSON.stringify(res.metrics) == JSON.stringify(res2.metrics), "the same case twice gives identical metrics")
	# a body with one leg pair: no front/rear limbs, so the posture metrics are null with a reason, not made up
	var mite: Dictionary = core.run_case(t.root, "mite", "walk", 120)
	t.check(mite.metrics.shoulder_hip_ratio == null and String(mite.reasons.get("shoulder_hip_ratio", "")) != "", "mite shoulder/hip ratio is null with a reason")
