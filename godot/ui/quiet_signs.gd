extends Control
## The permanent quiet signs (docs/godot/UI-DIEGETIC.md 7.7, 7.9, 7.13): the seed (menu icon) bottom-left with the three
## vitals lines beside it (stamina, health, hunger), the DNA balance with its species rings top-left. They rest at low
## opacity, brighten when they change and go back after REST. No numbers unless "Numbers: On". The text-free reading is the
## whole point: a thin line, a glyph, a halo. Screen space; the UI feeds the values.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")

signal seed_pressed

const LINE_X := 80.0
const LINE_LEN := 124.0
const LOW_HEALTH := 0.30
const MAX_PIPS := 8

# model (what the tests read)
var hp_frac := 1.0
var calcium := 0
var mineral := 0
var recipe_seen := false
var food_frac := 0.7
var stamina_frac := 1.0
var hp := 0.0
var hp_max := 1.0
var food := 0
var food_max := 100
var stamina_visible := false
var low_health := false
var dna_balance := 0
var dna_total := 0
var pips_total := 4
var pips_filled := 0
var fight := false
var hungry := false
var seed_hover := false
var menu_open := false
var fade_all := 0.0                 # 1 = every sign hidden (the death fog), 0 = visible

var _shown_hp := 1.0
var _shown_food := 0.7
var _shown_stam := 1.0
var _act := {"seed": 0.0, "health": 0.0, "hunger": 0.0, "stamina": 0.0, "dna": 0.0}   # seconds since the last change
var _bright := {"seed": 0.0, "health": 0.0, "hunger": 0.0, "stamina": 0.0, "dna": 0.0}
var _delta := {}                    # sign -> {from, to, t, gain}
var _dna_shown := 0
var _dna_held := 0                  # DNA whose mote is still flying: not yet in the shown number
var _plus := 0
var _plus_t := 0.0
var _stam_full_t := 0.0
var _stam_alpha := 0.0
var _clock := 0.0
var _press_consumed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# --- model ---------------------------------------------------------------------------------------------------------

func dna_text() -> String:
	return str(_dna_shown)

## The text of the DNA number. (A method rather than a property so tests read the shown value, not the target.)
func dna_value() -> int:
	return _dna_shown

func set_player(hp_now: float, hp_cap: float, stamina: float, stamina_cap: float) -> void:
	var f := clampf(hp_now / maxf(hp_cap, 1.0), 0.0, 1.0)
	if absf(f - hp_frac) > 0.004:
		_changed("health", hp_frac, f)
	hp = hp_now
	hp_max = hp_cap
	hp_frac = f
	low_health = f < LOW_HEALTH and hp_now > 0.0
	var sf := clampf(stamina / maxf(stamina_cap, 1.0), 0.0, 1.0)
	if absf(sf - stamina_frac) > 0.004:
		_changed("stamina", stamina_frac, sf)
	stamina_frac = sf

## DNA total (journal only), balance (the number), species resolved of those present, food.
func set_meters(total: int, balance: int, resolved: int, present: int, food_now: int, food_cap: int) -> void:
	dna_total = total
	var ff := clampf(float(food_now) / maxf(food_cap, 1), 0.0, 1.0)
	if absf(ff - food_frac) > 0.004:
		_changed("hunger", food_frac, ff)
	food = food_now
	food_max = food_cap
	food_frac = ff
	hungry = ff < 0.25
	if balance != dna_balance:
		if balance < dna_balance:                       # spent at the nest: the number counts down
			_dna_shown = balance
			_bright["dna"] = 1.0
			_act["dna"] = 0.0
		dna_balance = balance
		if _dna_held <= 0:
			_dna_shown = balance
			_bright["dna"] = 1.0
			_act["dna"] = 0.0
	if resolved > pips_filled and pips_total > 0:
		_bright["dna"] = 1.0
		_act["dna"] = 0.0
	pips_total = present
	pips_filled = resolved

## A mote of DNA is on its way: the number waits for it (`land_dna`).
func hold_dna(amount: int) -> void:
	_dna_held += amount
	_dna_shown = maxi(dna_balance - _dna_held, 0)

func land_dna(amount: int) -> void:
	_dna_held = maxi(_dna_held - amount, 0)
	_dna_shown = maxi(dna_balance - _dna_held, 0)
	_plus += amount
	_plus_t = 1.5
	_bright["dna"] = 1.0
	_act["dna"] = 0.0

func set_fight(on: bool) -> void:
	fight = on

func set_hit() -> void:
	_changed("health", hp_frac, hp_frac)

## A refused order bumps a line (it brightens): the mark first, text second.
func poke(sign: String) -> void:
	_bright[sign] = 1.0
	_act[sign] = 0.0

func mark_seed() -> void:
	_bright["seed"] = 1.0
	_act["seed"] = 0.0

func _changed(sign: String, from: float, to: float) -> void:
	_bright[sign] = 1.0
	_act[sign] = 0.0
	_delta[sign] = {"from": from, "to": to, "t": 0.0}

## Resting alpha of a sign: 0.74, 1.0 while it changed, back after REST.
func sign_alpha(sign: String) -> float:
	var a: float = Style.rest_alpha()
	var b: float = _bright.get(sign, 0.0)
	return lerpf(a, 1.0, b) * (1.0 - fade_all)

func seed_center() -> Vector2:
	return Vector2(Style.u(40.0), size.y - Style.u(40.0))

func dna_center() -> Vector2:
	return Vector2(Style.u(40.0), Style.u(38.0))

func line_y(sign: String) -> float:
	var off: float = {"stamina": 58.0, "health": 46.0, "hunger": 34.0, "calcium": 82.0, "mineral": 94.0}[sign]
	return size.y - Style.u(off)

# --- input ---------------------------------------------------------------------------------------------------------

func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		seed_hover = e.position.distance_to(seed_center()) <= Style.u(22.0)
		return false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and e.position.distance_to(seed_center()) <= Style.u(22.0):
			_press_consumed = true
			seed_pressed.emit()
			return true
		elif not e.pressed and _press_consumed:
			_press_consumed = false
			return true
	return false

# --- per frame -----------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_clock += dt
	_shown_hp = Style.follow(_shown_hp, hp_frac, dt)
	_shown_food = Style.follow(_shown_food, food_frac, dt)
	_shown_stam = Style.follow(_shown_stam, stamina_frac, dt)
	for k in _act:
		_act[k] += dt
		var b: float = _bright[k]
		if _act[k] > Style.REST:
			b = move_toward(b, 0.0, dt / Style.REST_FADE)
		_bright[k] = b
	if seed_hover or menu_open:
		_bright["seed"] = 1.0
		_act["seed"] = 0.0
	for k in _delta.keys():
		_delta[k].t += dt / 0.8
		if _delta[k].t >= 1.0:
			_delta.erase(k)
	if _plus_t > 0.0:
		_plus_t -= dt
		if _plus_t <= 0.0:
			_plus = 0
	# stamina shows below full or in a fight, hides 2 s after it is full again
	var want := fight or stamina_frac < 0.995
	if want:
		_stam_full_t = 0.0
	else:
		_stam_full_t += dt
	stamina_visible = want or _stam_full_t < 2.0
	_stam_alpha = Style.approach(_stam_alpha, 1.0 if stamina_visible else 0.0, dt, Style.IN if stamina_visible else Style.OUT)
	queue_redraw()

func _draw() -> void:
	if fade_all >= 0.999:
		return
	_draw_seed()
	_draw_lines()
	_draw_dna()

func _draw_seed() -> void:
	var a := sign_alpha("seed")
	var c := seed_center()
	var r := Style.u(12.0)
	var col := Color(Palette.BONE, a)
	# an open ring with the gap at the upper right; the gap closes while the menu is open
	var gap := 0.0 if menu_open else 40.0
	Style.arc(self, c, r, 40.0 + gap * 0.5 + 6.0 if gap > 0.0 else 0.0, 360.0 - (40.0 - gap * 0.5) if gap > 0.0 else 359.0, col, Style.u(1.8))
	draw_circle(c, Style.u(2.8) + 1.0, Color(Palette.INK, 0.5 * a))
	draw_circle(c, Style.u(2.8), col)
	if seed_hover and not menu_open:
		Style.text(self, Style.font_sans(), c + Vector2(Style.u(22.0), Style.u(5.0)), Strings.t("menu") + "   Esc", Style.u(16.5), Color(Palette.BONE, a))

func _line(sign: String, frac: float, color: Color, glyph: String, thick := 0.0) -> void:
	var y := line_y(sign)
	var a := sign_alpha(sign)
	var x0 := Style.u(LINE_X)
	var len := Style.u(LINE_LEN)
	Glyphs.draw(self, glyph, Vector2(x0 - Style.u(12.0), y), 10.0, Color(color, a))
	Style.line(self, Vector2(x0, y), Vector2(x0 + len, y), Color(Palette.BONE, Style.TRACK_ALPHA * a), Style.u(1.2))
	Style.line(self, Vector2(x0 + len, y - Style.u(3.0)), Vector2(x0 + len, y + Style.u(3.0)), Color(Palette.BONE, 0.5 * a), Style.u(1.2))
	var w := Style.u(2.4) + Style.u(thick)
	if frac > 0.004:
		Style.line(self, Vector2(x0, y), Vector2(x0 + len * frac, y), Color(color, a), w)
	if _delta.has(sign):
		var d: Dictionary = _delta[sign]
		var lo := minf(d.from, d.to)
		var hi := maxf(d.from, d.to)
		var gain: bool = d.to > d.from
		var dc := Color(Palette.BONE, a * (1.0 - d.t)) if gain else Color(Palette.EMBER_HOT, a * (1.0 - d.t))
		Style.line(self, Vector2(x0 + len * lo, y), Vector2(x0 + len * hi, y), dc, Style.u(4.0 if gain else 3.0))
	if Style.numbers():
		var v: String = {"health": str(ceili(hp)), "hunger": str(food), "stamina": "", "calcium": str(calcium), "mineral": str(mineral)}.get(sign, "")
		if v != "":
			Style.text(self, Style.font_sans(), Vector2(x0 + len + Style.u(8.0), y + Style.u(4.0)), v, Style.u(13.5), Color(Palette.FOG, a))

func _draw_lines() -> void:
	if recipe_seen or calcium > 0:
		_line("calcium", float(calcium) / 100.0, Palette.BONE, "bone")
	if mineral > 0:
		_line("mineral", float(mineral) / 100.0, Palette.MIST, "guard")
	if _stam_alpha > 0.01:
		var old := modulate
		modulate = Color(1, 1, 1, _stam_alpha)
		_line("stamina", _shown_stam, Palette.MIST, "stamina")
		modulate = old
	var pulse := 1.0
	var hcol := Palette.BONE
	var thick := 0.0
	if low_health:
		var period := 0.8 if hp_frac < 0.15 else Style.PULSE
		if Style.reduced_motion():
			pulse = 1.0
			thick = 1.4
		else:
			pulse = 0.8 + 0.2 * sin(TAU * _clock / period)
		hcol = Palette.EMBER_HOT
		thick = maxf(thick, 1.0)
		_bright["health"] = pulse
		_act["health"] = 0.0
	_line("health", _shown_hp, hcol, "health", thick)
	var fcol := Palette.OCHRE
	if food_frac < 0.10:
		fcol = Palette.EMBER_HOT
	elif hungry and not Style.reduced_motion() and fmod(_clock, 8.0) < 0.6:
		_bright["hunger"] = 1.0
		_act["hunger"] = 0.0
	_line("hunger", _shown_food, fcol, "hunger")

func _draw_dna() -> void:
	var a := sign_alpha("dna")
	var c := dna_center()
	Glyphs.draw(self, "dna", c, 24.0, Color(Palette.COPPER, a))
	var x := c.x + Style.u(22.0)
	var f := Style.font_sans(true)
	var s := str(_dna_shown)
	Style.text(self, f, Vector2(x, c.y + Style.u(7.0)), s, Style.u(19.0), Color(Palette.BONE, a))
	x += Style.text_width(f, s, Style.u(19.0)) + Style.u(14.0)
	var per_row := mini(pips_total, MAX_PIPS)
	if pips_total > MAX_PIPS:
		Style.text(self, Style.font_sans(), Vector2(x, c.y + Style.u(6.0)), "%d / %d" % [pips_filled, pips_total], Style.u(14.0), Color(Palette.BONE, a))
		x += Style.u(48.0)
	else:
		for i in per_row:
			var p := Vector2(x + i * Style.u(13.0), c.y)
			if i < pips_filled:
				draw_circle(p, Style.u(3.6) + 1.0, Color(Palette.INK, 0.5 * a))
				draw_circle(p, Style.u(3.6), Color(Palette.COPPER, a))
			else:
				Style.circle_outline(self, p, Style.u(3.6), Color(Palette.BONE, 0.8 * a), Style.u(1.1))
		x += per_row * Style.u(13.0) + Style.u(6.0)
	if _plus > 0:
		Style.text(self, Style.font_sans(true), Vector2(x, c.y + Style.u(6.0)), "+%d" % _plus, Style.u(16.0), Color(Palette.COPPER, minf(_plus_t / 0.4, 1.0)))
