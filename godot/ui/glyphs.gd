extends RefCounted
## The glyph language (docs/godot/UI-DIEGETIC.md section 4): 35 SVG strokes in godot/ui/glyphs, white, tinted when drawn.

const Style := preload("res://ui/style.gd")
const Modes := preload("res://ui/modes.gd")

const NAMES := ["attack", "befriend", "bite", "bone", "charge", "charm", "dance", "display", "dig", "dna", "dodgeL", "dodgeR", "eat",
	"fang", "flame", "fruit", "guard", "health", "hunger", "intimidate", "journal", "leaf", "nest", "observe", "pose", "pounce", "quill",
	"roar", "seed", "sing", "spit", "stamina", "stomp", "tail", "tree"]

static var _cache := {}
static var _warned := {}

static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := "res://ui/glyphs/%s.svg" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]

static func has(name: String) -> bool:
	return tex(name) != null

## Draw a glyph centred at `centre`, `size_u` design units wide, tinted `color`, with a faint dark under-copy for legibility.
static func draw(c: CanvasItem, name: String, centre: Vector2, size_u: float, color: Color) -> void:
	var t := tex(name)
	if t == null:
		return
	var s := Style.u(size_u)
	var r := Rect2(centre - Vector2(s, s) * 0.5, Vector2(s, s))
	c.draw_texture_rect(t, Rect2(r.position + Vector2(0, 1), r.size), false, Color(0.055, 0.09, 0.082, 0.45 * color.a))
	c.draw_texture_rect(t, r, false, color)

## Move / skill id (C name) -> glyph; a move without a glyph falls back to `attack` and logs once.
static func for_move(id: String) -> String:
	var g: String = {"tail_strike": "tail", "bite": "bite", "charge": "charge", "spit": "spit", "pounce": "pounce", "quill": "quill",
		"stomp": "stomp", "guard": "guard", "dodge": "dodgeL", "sing": "sing", "dance": "dance", "charm": "charm", "pose": "pose",
		"roar": "roar", "display": "display", "observe": "observe", "eat": "eat", "flame": "flame"}.get(id, "")
	if g == "":
		if not _warned.has(id):
			_warned[id] = true
			push_warning("no glyph for move '%s', using attack" % id)
		return "attack"
	return g

static func for_skill(id: String) -> String:
	return for_move(id)

## Gift item index (Modes.ITEMS: plant, fruit, meat, bone) -> glyph.
static func for_item(i: int) -> String:
	return ["leaf", "fruit", "fang", "bone"][clampi(i, 0, 3)]

static func for_mode(mode: StringName) -> String:
	return String(mode) if mode in [&"attack", &"befriend", &"observe", &"intimidate", &"eat"] else "attack"
