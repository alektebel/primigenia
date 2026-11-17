extends RefCounted
# Palette C "Current+" (G63): every number of the look, from tools/hero/build_hero.py
# (golden preset + PAL.C + LAND0). Shaders hold the same numbers as constants; a test compares.

const SUN_DIR := Vector3(-0.62, 0.28, -0.72)   # towards the sun, normalised by sun_dir()
const SUN_COLOR := Color(1.0, 0.839, 0.627)     # #ffd6a0 raw (three r128 used hex unconverted)
const SUN_ENERGY := 3.2
const HEMI_SKY := Color(0.659, 0.8, 0.973)      # #a8ccf8
const HEMI_GROUND := Color(0.416, 0.416, 0.361) # #6a6a5c
const HEMI_ENERGY := 0.5
# Lit materials (the creatures) are the only things the world's light and ambient reach (terrain, water, grass
# and sky are unshaded shaders with the numbers above baked in). g-creature tuned them in a preview with sun
# #ffcf9a energy 2.2, ambient 0.75 and ACES at exposure 1.4 with white 1; the world tone map is the calibrated
# 0.926 / white 15.4, which at mid tones needs about twice the light for the same display colour
# (see docs/godot/WIRE.md, docs/evidence/godot/wire/exposure.png).
const CREATURE_SUN_COLOR := Color(1.0, 0.812, 0.604)   # #ffcf9a, sRGB bytes of the preview sun
const CREATURE_SUN_ENERGY := 4.4
const CREATURE_AMBIENT_COLOR := Color(0.62, 0.75, 0.92)
const CREATURE_AMBIENT_ENERGY := 1.5
const GRASS := Vector3(1.03, 0.96, 0.86)
const SH_K := 0.42                               # 1 - 0.58 * 1
const AIR_DENSITY := 0.00052
const AIR_START := 140.0
const AIR_FALLOFF := 240.0
const AIR_COOL := Vector3(0.34, 0.58, 0.88)
const AIR_WARM := Vector3(0.96, 0.74, 0.46)
const SKY_HZ := Vector3(0.95, 0.84, 0.70)
const SKY_MID := Vector3(0.52, 0.70, 0.93)
const SKY_TOP := Vector3(0.13, 0.39, 0.84)
const SKY_GLOW := Vector3(1.0, 0.62, 0.3)
const SKY_DISC := 3.0
const G0 := Vector3(0.090, 0.225, 0.040)
const G1 := Vector3(0.185, 0.335, 0.075)
const LIT := Vector3(1.10, 1.03, 0.90)
const SHADE := Vector3(0.86, 0.92, 1.10)
const S_TINT := Vector3(0.80, 0.86, 1.14)
const TUFT0 := Vector3(0.82, 0.90, 0.78)
const TUFT1 := Vector3(1.04, 1.02, 0.98)
const BLADE_LO := 0.52
const BLADE_HI := 1.28
const R0 := Vector3(0.15, 0.165, 0.19)
const R1 := Vector3(0.28, 0.215, 0.14)
const R2 := Vector3(0.19, 0.135, 0.085)
const SCREE := Vector3(0.27, 0.23, 0.16)
const SNOW := Vector3(0.78, 0.88, 0.95)
const ROCK_SHADE := Vector3(0.68, 0.84, 1.20)
const ROCK_LIT := Vector3(1.30, 1.10, 0.84)
# PROPOSED by the implementer (not in palette C): owner to approve, see docs/godot/M0.md.
const SAND := Vector3(0.42, 0.37, 0.25)
const VOLCANIC_R0 := Vector3(0.075, 0.07, 0.075)
const VOLCANIC_R1 := Vector3(0.13, 0.10, 0.085)
const WET_TINT := Vector3(0.82, 0.90, 0.84)
const CHANNEL := Vector3(0.035, 0.09, 0.13)

# Rock and scree material (docs/godot/PLAN-rock.md): proposed by the implementer, pending owner approval, see docs/godot/ROCK.md.
# Mirrors of shaders/rock.gdshaderinc, compared by test_look.gd.
const ROCK_TILE_MINERAL := 263.0
const ROCK_TILE_MACRO := 41.0
const ROCK_TILE_MESO := 9.7
const ROCK_TILE_MICRO := 2.3
const SCREE_TILE := 6.1
const ROCK_MESO_NEAR := 120.0
const ROCK_MESO_FAR := 380.0
const ROCK_MESO_FAR_HIGH := 500.0
const ROCK_MICRO_NEAR := 25.0
const ROCK_MICRO_FAR := 70.0
const SCREE_NEAR := 150.0
const SCREE_FAR := 450.0
const ROCK_MINERAL_BLUR := 14.0
const ROCK_MINERAL_GAIN := 2.2
const ROCK_MINERAL_BIAS := -0.06
const ROCK_MACRO_SHIFT := 0.37
const ROCK_PLATE_VALUE := 0.22
const ROCK_AO_MID := 0.22
const ROCK_AO_DEEP := 0.16
const ROCK_AO_TINT := 0.62
const ROCK_TOP_LIGHT := 0.10
const SCREE_VALUE := 0.35
const SCREE_GAP_DARK := 0.28
const SCREE_ROCK_MIX := 0.85

# Godot's ACES (compatibility renderer) calibrated to three.js ACESFilmic at exposure 1:
# see docs/evidence/godot/m0/calibration.json (written by make godot-render-test).
const TONEMAP_EXPOSURE := 0.926
const TONEMAP_WHITE := 15.4

static func sun_dir() -> Vector3:
	return SUN_DIR.normalized()

# Linear colour with the same bytes three.js used for a hex value (no sRGB conversion).
static func raw(c: Vector3) -> Color:
	return Color(c.x, c.y, c.z)
