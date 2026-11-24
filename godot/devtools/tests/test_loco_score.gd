extends RefCounted
# L0 scorecard (devtools/zoo/loco_score_core.gd): one body x one scenario runs and every metric key is there, finite or null with a reason.

const KEYS := ["head_pitch_deg", "shoulder_hip_ratio", "back_slope_deg", "torso_roll_deg", "roll_plant_lag", "torso_bob_cm", "foot_slip_cm",
	"limp_index", "limp", "duty_factor", "airborne_frac", "footfall", "stride_len_m", "cadence_hz", "leg_extension", "min_turn_radius_m", "pivot_frac", "stall_frac", "knee_flip_frac", "foot_penetration_cm", "gait_symmetry"]

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
	# Known signals: two drops per stride are even; one drop favours a side.
	var synthetic := {"speed": []}
	var even := []
	var uneven := []
	var roll := []
	for i in 200:
		synthetic.speed.append(1.0)
		even.append(-cos(2.0 * TAU * float(i) / 20.0))
		uneven.append(-cos(TAU * float(i) / 20.0))
		roll.append(-cos(TAU * float(i) / 20.0))
	var pair := [{"side": 1, "pair": 0}, {"side": -1, "pair": 0}]
	var touches := [[40, 60, 80, 100, 120, 140], [50, 70, 90, 110, 130, 150]]
	t.check(core._limp(synthetic, pair, touches, 20, even, roll).index < 1.01, "limp metric accepts two even drops per stride")
	t.check(core._limp(synthetic, pair, touches, 20, uneven, roll).index > 1.15, "limp metric catches one drop per stride")
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
	# Diagram is an exact slice of sampled contacts (not truthiness of "0").
	var ff: Dictionary = res.metrics.footfall
	for j in ff.labels.size():
		var seq: Array = ff.contact[j]
		t.check(seq.has(false) and seq.has(true), "footfall %s has swing and stance" % ff.labels[j])
		var exact := true
		for i in seq.size():
			if bool(seq[i]) != (core.last_rec.contact[int(ff.start_frame) + i][j] == 1):
				exact = false
		t.check(exact, "footfall %s matches recorded contacts" % ff.labels[j])
	var res2: Dictionary = core.run_case(t.root, "hero", "walk", 120)
	t.check(JSON.stringify(res.metrics) == JSON.stringify(res2.metrics), "the same case twice gives identical metrics")
	# a body with one leg pair: no front/rear limbs, so the posture metrics are null with a reason, not made up
	var mite: Dictionary = core.run_case(t.root, "mite", "walk", 120)
	t.check(mite.metrics.shoulder_hip_ratio == null and String(mite.reasons.get("shoulder_hip_ratio", "")) != "", "mite shoulder/hip ratio is null with a reason")
