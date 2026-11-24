extends RefCounted
## Ambient flier species (visual-only, no C entities; the real C species come later, DESIGN A59). Numbers are starting values:
## sizes and masses from docs/creatures/*.md, speeds from the flight lab polar (docs/evidence/loco/flight.md, wing loading 26..40 N/m2 gives
## stall 4.6..6 m/s for the small ones; the alariz soars at loading ~60 N/m2). The flock test (test_fliers.gd) checks the numbers hold together.
## `beat` is Hz of the drawn wingbeat (f = 4.8 m^-1/3 as the lab, capped for a 60 Hz screen).

const ALARIZ := 0       # soaring scavenger, highlands, circles over ridges
const PICO := 1         # bello-pico, gull-sized, flocks over the meadow and the shore, flap-glide
const ZANCUILLA := 2    # green dart, dawn and dusk, fast straight flight over water and shore
const ALASUCENA := 3    # 12 cm hoverer, flits between perches on low ground
const COUNT := 4

const DATA := [
	{"id": "alariz", "span": 4.6, "mass": 85.0, "cruise": 13.0, "stall": 9.0, "vmax": 20.0, "beat": 1.6, "alt": Vector2(35.0, 90.0),
		"flee": 45.0, "flock": Vector2i(1, 2), "flocks": 2, "clear": 14.0, "foot": 0.5, "bank": 0.6, "burst_len": 2.0, "glide_len": 14.0,
		"turn": 0.35, "perch_wait": Vector2(25.0, 70.0), "fly_wait": Vector2(70.0, 150.0), "climb": 0.22},
	{"id": "pico", "span": 0.52, "mass": 0.15, "cruise": 9.0, "stall": 6.0, "vmax": 13.0, "beat": 6.5, "alt": Vector2(5.0, 22.0),
		"flee": 14.0, "flock": Vector2i(4, 8), "flocks": 3, "clear": 3.5, "foot": 0.11, "bank": 0.7, "burst_len": 0.9, "glide_len": 1.6,
		"turn": 1.1, "perch_wait": Vector2(10.0, 35.0), "fly_wait": Vector2(25.0, 70.0), "climb": 0.35},
	{"id": "zancuilla", "span": 0.66, "mass": 0.28, "cruise": 11.0, "stall": 6.4, "vmax": 16.0, "beat": 8.0, "alt": Vector2(3.0, 14.0),
		"flee": 18.0, "flock": Vector2i(2, 4), "flocks": 2, "clear": 2.5, "foot": 0.26, "bank": 0.8, "burst_len": 1.4, "glide_len": 0.8,
		"turn": 1.4, "perch_wait": Vector2(8.0, 25.0), "fly_wait": Vector2(25.0, 60.0), "climb": 0.3},
	{"id": "alasucena", "span": 0.3, "mass": 0.02, "cruise": 4.0, "stall": 0.0, "vmax": 7.0, "beat": 13.0, "alt": Vector2(0.6, 3.0),
		"flee": 7.0, "flock": Vector2i(2, 5), "flocks": 3, "clear": 0.5, "foot": 0.075, "bank": 0.3, "burst_len": 99.0, "glide_len": 0.0,
		"turn": 3.0, "perch_wait": Vector2(2.0, 8.0), "fly_wait": Vector2(2.0, 6.0), "climb": 0.8},
]

static func get_data(species: int) -> Dictionary:
	return DATA[species]


## Wingbeat and glide share a flap cycle: flapping shares are DOWNSTROKE 0.58 of the beat (loco_wing.gd).
static func hover_capable(species: int) -> bool:
	return species == ALASUCENA
