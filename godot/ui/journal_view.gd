extends Control
## The field journal (G38, key J or the menu): a naturalist's notebook laid open over the paused world. Four sections
## (tabs on the top edge): Species, Parts, Secrets, Recipes. Each is a spread of two pages with its own paging; what
## the player has not met or found is a silhouette and a "?". Paper, ink and the Alegreya faces; no panels or boxes of
## the HUD, because this is a thing in the world's hands, not a sign. What each page reads is in journal_model.gd.
##
## Mouse: the tabs, the arrows beside the page number, the wheel, a click outside closes. Keys: Left / Right turn the
## page, Tab / Shift+Tab change section, Esc or J (or T) close.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Model := preload("res://ui/journal_model.gd")
const Art := preload("res://ui/journal_art.gd")

signal opened
signal closed

const TABS := ["species", "parts", "secrets", "recipes"]

# Paper and ink (a naturalist's notebook in the game's thick air: warm paper, iron-gall ink, one copper accent).
const PAPER := Color("#E9DFC6")
const PAPER_DARK := Color("#D6C8A5")
const PAPER_EDGE := Color("#B9A982")
const INK_T := Color("#2A2820")
const INK_SOFT := Color("#5A5444")
const INK_FAINT := Color("#8D8670")
const COPPER_D := Color("#9A5222")
const LICHEN_D := Color("#2D7555")
const EMBER_D := Color("#B04228")

var open := false
var tab := 0
var page := 0                         # the spread shown (two pages each)
var model: Dictionary = {}
var source := Callable()              # () -> model Dictionary; read when the journal opens
var art: Node
var truncated := 0                    # lines cut with an ellipsis in the last draw (a test and the evidence read it)
var _alpha := 0.0
var _hits: Array = []                 # [{rect, kind, arg}] of the last draw
var _page_fade := 1.0
var _sheet := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	art = Art.new()
	add_child(art)
	art.changed.connect(queue_redraw)

# --- state -----------------------------------------------------------------------------------------------------------

func open_view() -> void:
	if source.is_valid():
		model = source.call()
	open = true
	visible = true
	page = clampi(page, 0, maxi(page_count() - 1, 0))
	_request_art()
	opened.emit()

func close_view() -> void:
	if open:
		open = false
		closed.emit()

func set_model(m: Dictionary) -> void:
	model = m
	page = clampi(page, 0, maxi(page_count() - 1, 0))

func set_tab(i: int) -> void:
	tab = posmod(i, TABS.size())
	page = 0
	_page_fade = 0.0
	_request_art()

func turn(delta: int) -> void:
	var n := clampi(page + delta, 0, maxi(page_count() - 1, 0))
	if n != page:
		page = n
		_page_fade = 0.0
		_request_art()

## Spreads in the current section.
func page_count(t: int = -1) -> int:
	var name: String = TABS[tab if t < 0 else t]
	match name:
		"species":
			return maxi(int(ceil(model.get("species", []).size() / 2.0)), 1)
		"parts":
			return maxi(int(ceil(model.get("parts", []).size() / float(2 * parts_per_page()))), 1)
		"recipes":
			return maxi(int(ceil(model.get("recipes", []).size() / 4.0)), 1)
		"secrets":
			return maxi(int(ceil(secret_pages().size() / 2.0)), 1)
	return 1

func _request_art() -> void:
	if art == null or model.is_empty():
		return
	match TABS[tab]:
		"species":
			var sp: Array = model.get("species", [])
			for k in range(page * 2, mini(page * 2 + 2, sp.size())):
				art.request_portrait(String(sp[k].body))
		"parts":
			var tiles: Array = model.get("parts", [])
			var per := parts_per_page()
			var ids: Array = []
			for k in range(page * 2 * per, mini((page + 1) * 2 * per, tiles.size())):
				ids.append(String(tiles[k].id))
			art.request_parts(ids)

# --- input -----------------------------------------------------------------------------------------------------------

func handle_input(e: InputEvent) -> bool:
	if not open:
		return false
	if e is InputEventMouseMotion:
		return true
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			turn(1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			turn(-1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_click(e.position)
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("pause_menu") or e.is_action_pressed("journal") or e.is_action_pressed("family_tree"):
			close_view()
		elif e.keycode == KEY_RIGHT or e.keycode == KEY_PAGEDOWN:
			turn(1)
		elif e.keycode == KEY_LEFT or e.keycode == KEY_PAGEUP:
			turn(-1)
		elif e.keycode == KEY_TAB:
			set_tab(tab + (-1 if e.shift_pressed else 1))
		return true
	return false

func _click(p: Vector2) -> void:
	for h in _hits:
		if Rect2(h.rect).has_point(p):
			match String(h.kind):
				"tab":
					set_tab(int(h.arg))
				"prev":
					turn(-1)
				"next":
					turn(1)
			return
	if not _sheet.has_point(p):
		close_view()

## For tests: the hit rectangle of a control ("tab", i), ("prev", 0) or ("next", 0) in the last draw.
func hit_rect(kind: String, arg: int = 0) -> Rect2:
	for h in _hits:
		if String(h.kind) == kind and int(h.arg) == arg:
			return h.rect
	return Rect2()

# --- layout ----------------------------------------------------------------------------------------------------------

func _compute_sheet() -> Rect2:
	var w := minf(size.x - Style.u(56.0), Style.u(1120.0))
	var h := minf(size.y - Style.u(112.0), Style.u(620.0))
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5 + Style.u(14.0), w, h)

## The two inner page rectangles of the sheet.
func pages_rects(sheet: Rect2) -> Array:
	var top := sheet.position.y + Style.u(78.0)
	var bottom := sheet.end.y - Style.u(54.0)
	var cx := sheet.position.x + sheet.size.x * 0.5
	var m := Style.u(46.0)
	var g := Style.u(32.0)
	return [Rect2(sheet.position.x + m, top, cx - g - (sheet.position.x + m), bottom - top),
		Rect2(cx + g, top, sheet.end.x - m - (cx + g), bottom - top)]

const PART_CELL_W := 150.0
const PART_CELL_H := 128.0

func _part_grid(p: Rect2) -> Vector2i:
	return Vector2i(maxi(int(p.size.x / Style.u(PART_CELL_W)), 2), maxi(int((p.size.y - Style.u(30.0)) / Style.u(PART_CELL_H)), 2))

## Tiles per page for the sheet as laid out (before the first draw, for the default 1280 x 720 canvas).
func parts_per_page() -> int:
	var sheet := _compute_sheet() if size.x > 0.0 else Rect2(0, 0, Style.u(1120.0), Style.u(608.0))
	var g := _part_grid(pages_rects(sheet)[0])
	return g.x * g.y

# --- drawing ---------------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if open else 0.0, dt, Style.IN if open else Style.OUT)
	_page_fade = Style.approach(_page_fade, 1.0, dt, 0.18)
	if _alpha <= 0.003 and not open:
		visible = false
		return
	modulate.a = Style.ease_out(_alpha)
	queue_redraw()

func _draw() -> void:
	truncated = 0
	_hits.clear()
	var sheet := _compute_sheet()
	_sheet = sheet
	var pages := pages_rects(sheet)
	_draw_sheet(sheet)
	_draw_tabs(sheet)
	_draw_header(sheet, pages)
	var content_alpha := Style.ease_out(_page_fade)
	var ink_mod := Color(1, 1, 1, content_alpha)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	match TABS[tab]:
		"species":
			_draw_species(pages, ink_mod)
		"parts":
			_draw_parts(pages, ink_mod)
		"secrets":
			_draw_secrets(pages, ink_mod)
		"recipes":
			_draw_recipes(pages, ink_mod)
	_draw_footer(sheet)

func _c(col: Color, mod: Color) -> Color:
	return Color(col.r, col.g, col.b, col.a * mod.a)

func _draw_sheet(s: Rect2) -> void:
	# a soft shadow on the veil, the paper, ruled lines, the fold and the copper margin
	draw_rect(Rect2(s.position + Vector2(0, Style.u(6.0)), s.size + Vector2(Style.u(3.0), 0)), Color(Palette.INK, 0.35))
	draw_rect(s, PAPER)
	draw_rect(s, PAPER_EDGE, false, 1.5)
	var cx := s.position.x + s.size.x * 0.5
	var y := s.position.y + Style.u(78.0)
	while y < s.end.y - Style.u(40.0):
		draw_line(Vector2(s.position.x + Style.u(20.0), y), Vector2(s.end.x - Style.u(20.0), y), Color(PAPER_EDGE, 0.16), 1.0)
		y += Style.u(28.0)
	# the fold: a darker band that fades out on both sides
	for i in 14:
		var k := float(i) / 14.0
		var a := (1.0 - k) * 0.20
		draw_rect(Rect2(cx - Style.u(26.0) * (1.0 - k) - 1.0, s.position.y, Style.u(26.0) * (1.0 - k) * 2.0 + 2.0, s.size.y), Color(0.35, 0.28, 0.18, a * 0.18))
	draw_line(Vector2(cx, s.position.y + Style.u(10.0)), Vector2(cx, s.end.y - Style.u(10.0)), Color(PAPER_EDGE, 0.8), 1.5)
	draw_line(Vector2(s.position.x + Style.u(30.0), s.position.y + Style.u(8.0)), Vector2(s.position.x + Style.u(30.0), s.end.y - Style.u(8.0)), Color(COPPER_D, 0.28), 1.0)

func _draw_tabs(s: Rect2) -> void:
	var f := Style.font_italic()
	var x := s.position.x + Style.u(46.0)
	var th := Style.u(34.0)
	for i in TABS.size():
		var label := Strings.t("jt_" + TABS[i])
		var w := Style.text_width(f, label, Style.u(20.0)) + Style.u(38.0)
		var active := i == tab
		var r := Rect2(x, s.position.y - th + (0.0 if active else Style.u(6.0)), w, th + 2.0 - (0.0 if active else Style.u(6.0)))
		draw_rect(r, PAPER if active else PAPER_DARK)
		draw_rect(r, PAPER_EDGE, false, 1.5)
		if active:
			draw_line(Vector2(r.position.x + 1.5, s.position.y + 1.0), Vector2(r.end.x - 1.5, s.position.y + 1.0), PAPER, 3.0)
		var col := INK_T if active else INK_SOFT
		var tw := Style.text_width(f, label, Style.u(20.0))
		draw_string(f, Vector2(r.position.x + (w - tw) * 0.5, r.end.y - Style.u(10.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(20.0)), col)
		if not active:
			# a thin copper tick on the tab under the pointer
			var mp := get_local_mouse_position()
			if r.has_point(mp):
				draw_line(Vector2(r.position.x + Style.u(8.0), r.position.y + 3.0), Vector2(r.end.x - Style.u(8.0), r.position.y + 3.0), COPPER_D, 2.0)
		_hits.append({"rect": r, "kind": "tab", "arg": i})
		x += w + Style.u(6.0)

func _draw_header(s: Rect2, pages: Array) -> void:
	var f := Style.font_italic()
	var base := s.position.y + Style.u(50.0)
	_ink(f, Vector2(pages[0].position.x, base), Strings.t("journal_book"), 30.0, INK_T)
	var line := "%s  %d" % [Strings.t("journal_total"), int(model.get("dna_total", 0))]
	var fs := Style.font_sans(true)
	var w := Style.text_width(fs, line, Style.u(18.0))
	_ink(fs, Vector2(pages[1].end.x - w, base), line, 18.0, COPPER_D)
	var y := s.position.y + Style.u(62.0)
	draw_line(Vector2(pages[0].position.x, y), Vector2(pages[0].end.x, y), Color(INK_FAINT, 0.7), 1.0)
	draw_line(Vector2(pages[1].position.x, y), Vector2(pages[1].end.x, y), Color(INK_FAINT, 0.7), 1.0)

func _draw_footer(s: Rect2) -> void:
	var n := page_count()
	var cx := s.position.x + s.size.x * 0.5
	var y := s.end.y - Style.u(22.0)
	var f := Style.font_sans()
	var label := Strings.t("j_page", [page + 1, n])
	var w := Style.text_width(f, label, Style.u(16.0))
	_ink(f, Vector2(cx - w * 0.5, y), label, 16.0, INK_SOFT)
	var r := Style.u(15.0)
	for side in [-1, 1]:
		var enabled: bool = (page > 0) if side < 0 else (page < n - 1)
		var c := Vector2(cx + side * (w * 0.5 + Style.u(34.0)), y - Style.u(5.0))
		var col := COPPER_D if enabled else Color(INK_FAINT, 0.45)
		var pts := PackedVector2Array([c + Vector2(-side * Style.u(5.0), -Style.u(8.0)), c + Vector2(side * Style.u(5.0), 0), c + Vector2(-side * Style.u(5.0), Style.u(8.0))])
		draw_polyline(pts, col, 2.2, true)
		if enabled:
			_hits.append({"rect": Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), "kind": "prev" if side < 0 else "next", "arg": 0})
	# the keys, on the veil under the sheet
	var hint := Strings.t("j_hint")
	var hw := Style.text_width(f, hint, Style.u(15.0))
	Style.text(self, f, Vector2(cx - hw * 0.5, s.end.y + Style.u(26.0)), hint, Style.u(15.0), Color(Palette.FOG, 0.85))

# --- text ------------------------------------------------------------------------------------------------------------

func _ink(font: Font, pos: Vector2, s: String, size_u: float, col: Color) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(Style.u(size_u))), col)

## Greedy word wrap into at most `max_lines` lines of `width` px; the last line ends with an ellipsis when cut.
func wrap_text(font: Font, s: String, size_u: float, width: float, max_lines: int) -> Array:
	var px := int(round(Style.u(size_u)))
	var lines: Array = []
	var words := s.replace("\n", " \n ").split(" ", false)
	var cur := ""
	var cut := false
	for i in words.size():
		var wd: String = words[i]
		if wd == "\n":
			lines.append(cur)
			cur = ""
			continue
		var tryline := wd if cur == "" else cur + " " + wd
		if font.get_string_size(tryline, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width or cur == "":
			cur = tryline
		else:
			lines.append(cur)
			cur = wd
		if lines.size() >= max_lines:
			cut = true
			break
	if not cut and cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		lines.resize(max_lines)
		cut = true
	if cut and not lines.is_empty():
		truncated += 1
		var last: String = lines[lines.size() - 1]
		while last.length() > 1 and font.get_string_size(last + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			last = last.substr(0, last.length() - 1)
		lines[lines.size() - 1] = last.rstrip(" ,.;:") + "…"
	return lines

func line_height(font: Font, size_u: float) -> float:
	return font.get_height(int(round(Style.u(size_u)))) * 1.02

## Wrap and draw a paragraph; returns the height used. `max_h` caps it (lines are cut, not overflowed).
func _para(font: Font, pos: Vector2, s: String, size_u: float, width: float, max_h: float, col: Color) -> float:
	var lh := line_height(font, size_u)
	var n := maxi(int(floor(max_h / lh)), 0)
	if n == 0:
		return 0.0
	var lines := wrap_text(font, s, size_u, width, n)
	for i in lines.size():
		draw_string(font, pos + Vector2(0, lh * (i + 0.8)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(Style.u(size_u))), col)
	return lh * lines.size()

## One line, shortened with an ellipsis to fit `width`.
func _fit(font: Font, s: String, size_u: float, width: float) -> String:
	var px := int(round(Style.u(size_u)))
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
		return s
	truncated += 1
	var t := s
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		t = t.substr(0, t.length() - 1)
	return t + "…"

func _lang() -> String:
	return Strings.language()

# --- picture frames and marks ------------------------------------------------------------------------------------------

func _picture(rect: Rect2, tex: Texture2D, silhouette: bool, mod: Color) -> void:
	if tex != null:
		var ts := tex.get_size()
		var k := minf(rect.size.x / ts.x, rect.size.y / ts.y)
		var sz := ts * k
		var r := Rect2(rect.position + (rect.size - sz) * 0.5, sz)
		draw_texture_rect(tex, r, false, Color(1, 1, 1, mod.a))
		return
	# nothing rendered (headless, or still baking): a quiet placeholder shape
	var c := rect.get_center()
	var rad := minf(rect.size.x, rect.size.y) * 0.3
	draw_arc(c, rad, 0.0, TAU, 40, _c(INK_FAINT if silhouette else INK_SOFT, mod), 1.6, true)
	if silhouette:
		var f := Style.font_italic()
		var w := Style.text_width(f, "?", Style.u(34.0))
		draw_string(f, c + Vector2(-w * 0.5, Style.u(11.0)), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(34.0)), _c(INK_FAINT, mod))

func _photo_frame(r: Rect2, mod: Color) -> void:
	draw_rect(r, _c(Color(PAPER_DARK, 0.55), mod))
	var l := Style.u(14.0)
	var col := _c(INK_SOFT, mod)
	for corner in [[r.position, 1, 1], [Vector2(r.end.x, r.position.y), -1, 1], [Vector2(r.position.x, r.end.y), 1, -1], [r.end, -1, -1]]:
		var p: Vector2 = corner[0]
		draw_line(p, p + Vector2(l * corner[1], 0), col, 1.6)
		draw_line(p, p + Vector2(0, l * corner[2]), col, 1.6)

## `n` pips of which `have` are filled; a circle (social) or a triangle (aggressive), as the rings do.
func _pips(at: Vector2, n: int, have: int, shape: String, col: Color, mod: Color) -> float:
	var step := Style.u(17.0)
	for i in n:
		var c := at + Vector2(step * i + Style.u(6.0), -Style.u(5.0))
		var filled := i < have
		if shape == "circle":
			if filled:
				draw_circle(c, Style.u(5.5), _c(col, mod))
			else:
				draw_arc(c, Style.u(5.0), 0.0, TAU, 20, _c(col, mod), 1.4, true)
		else:
			var pts := PackedVector2Array([c + Vector2(-Style.u(6.0), Style.u(5.0)), c + Vector2(0, -Style.u(6.5)), c + Vector2(Style.u(6.0), Style.u(5.0))])
			if filled:
				draw_colored_polygon(pts, _c(col, mod))
			else:
				pts.append(pts[0])
				draw_polyline(pts, _c(col, mod), 1.4, true)
	return step * n + Style.u(8.0)

# --- species ---------------------------------------------------------------------------------------------------------

func _draw_species(pages: Array, mod: Color) -> void:
	var sp: Array = model.get("species", [])
	if sp.is_empty():
		_empty(pages[0], mod)
		return
	for k in 2:
		var i := page * 2 + k
		if i < sp.size():
			_species_page(pages[k], sp[i], mod)

func _species_page(p: Rect2, e: Dictionary, mod: Color) -> void:
	var seen := bool(e.seen)
	var fi := Style.font_italic()
	var fs := Style.font_sans()
	var fm := Style.font_sans(true)
	var ph := minf(Style.u(200.0), p.size.y * 0.42)
	var pic := Rect2(p.position, Vector2(p.size.x, ph))
	_photo_frame(pic, mod)
	_picture(pic.grow(-Style.u(6.0)), art.portrait(String(e.body), not seen) if art != null else null, not seen, mod)
	var y := p.position.y + ph + Style.u(36.0)
	var name := String(e.name) if seen else "? ? ?"
	_ink(fi, Vector2(p.position.x, y), _fit(fi, name, 32.0, p.size.x), 32.0, _c(INK_T, mod))
	y += Style.u(26.0)
	if not seen:
		_ink(fm, Vector2(p.position.x, y), Strings.t("j_unseen"), 17.0, _c(INK_SOFT, mod))
		y += Style.u(14.0)
		_para(fs, Vector2(p.position.x, y), Strings.t("j_unseen_note"), 16.0, p.size.x, p.end.y - y, _c(INK_SOFT, mod))
		return
	_ink(fm, Vector2(p.position.x, y), "%s  ·  %s" % [Strings.t("j_temper_%d" % clampi(int(e.temperament), 0, 2)), Strings.t("j_diet_%d" % clampi(int(e.diet), 0, 2))], 17.0, _c(INK_SOFT, mod))
	y += Style.u(32.0)
	# the Q43 state: how far the two paths are walked (befriended / hunted), and where it stands
	var x := p.position.x
	var lab := Strings.t("j_befriended")
	_ink(fs, Vector2(x, y), lab, 16.0, _c(LICHEN_D, mod))
	x += Style.text_width(fs, lab, Style.u(16.0)) + Style.u(8.0)
	x += _pips(Vector2(x, y), int(e.need), mini(int(e.bonded), int(e.need)), "circle", LICHEN_D, mod) + Style.u(18.0)
	lab = Strings.t("j_hunted")
	_ink(fs, Vector2(x, y), lab, 16.0, _c(EMBER_D, mod))
	x += Style.text_width(fs, lab, Style.u(16.0)) + Style.u(8.0)
	_pips(Vector2(x, y), int(e.need), mini(int(e.kills), int(e.need)), "triangle", EMBER_D, mod)
	y += Style.u(24.0)
	var path: String = ["j_path_open", "j_path_ally", "j_path_hunted"][clampi(int(e.resolution), 0, 2)]
	_ink(fi, Vector2(p.position.x, y), Strings.t(path), 18.0, _c(COPPER_D if int(e.resolution) > 0 else INK_SOFT, mod))
	y += Style.u(12.0)
	y += _para(fs, Vector2(p.position.x, y), Strings.t("j_range", [int(e.roam)]), 16.0, p.size.x, minf(Style.u(44.0), p.end.y - y), _c(INK_SOFT, mod)) + Style.u(8.0)
	if int(e.activity) > 0:
		y += _para(fi, Vector2(p.position.x, y), Strings.t("j_activity_%d" % clampi(int(e.activity), 1, 2)), 16.0, p.size.x, minf(Style.u(44.0), p.end.y - y), _c(INK_SOFT, mod)) + Style.u(8.0)
	# observation clues, then likes
	_ink(fm, Vector2(p.position.x, y + Style.u(16.0)), Strings.t("j_clues", [e.clues.size(), int(e.clue_total)]), 16.0, _c(INK_T, mod))
	y += Style.u(24.0)
	var left := p.end.y - y - Style.u(44.0)
	for c in e.clues:
		if left < line_height(fi, 15.5):
			break
		var h := _para(fi, Vector2(p.position.x + Style.u(14.0), y), Strings.clue(String(c)), 15.5, p.size.x - Style.u(14.0), minf(left, line_height(fi, 15.5) * 2.0), _c(INK_SOFT, mod))
		draw_circle(Vector2(p.position.x + Style.u(4.0), y + Style.u(10.0)), Style.u(2.2), _c(COPPER_D, mod))
		y += h + Style.u(3.0)
		left -= h + Style.u(3.0)
	y += Style.u(6.0)
	var likes := ""
	if e.likes.is_empty() and e.dislikes.is_empty():
		likes = Strings.t("j_likes_unknown")
	else:
		var parts: PackedStringArray = []
		if not e.likes.is_empty():
			parts.append(Strings.t("j_likes", [", ".join(e.likes)]))
		if not e.dislikes.is_empty():
			parts.append(Strings.t("j_dislikes", [", ".join(e.dislikes)]))
		likes = ". ".join(parts)
	_para(fs, Vector2(p.position.x, y), likes, 15.5, p.size.x, maxf(p.end.y - y, 0.0), _c(INK_SOFT, mod))

# --- parts -----------------------------------------------------------------------------------------------------------

func _draw_parts(pages: Array, mod: Color) -> void:
	var tiles: Array = model.get("parts", [])
	if tiles.is_empty():
		_empty(pages[0], mod)
		return
	var fs := Style.font_sans()
	var head := Strings.t("j_parts_head", [int(model.get("parts_found", 0)), tiles.size(), int(model.get("parts_owned", 0))])
	_ink(Style.font_sans(true), Vector2(pages[0].position.x, pages[0].position.y + Style.u(14.0)), head, 17.0, _c(COPPER_D, mod))
	var grid := _part_grid(pages[0])
	var per := grid.x * grid.y
	var lang := _lang()
	for k in 2:
		var p: Rect2 = pages[k]
		var cw := p.size.x / grid.x
		var top := p.position.y + Style.u(30.0)
		var ch := (p.size.y - Style.u(30.0)) / grid.y
		for j in per:
			var i := (page * 2 + k) * per + j
			if i >= tiles.size():
				break
			var t: Dictionary = tiles[i]
			var cell := Rect2(p.position.x + (j % grid.x) * cw, top + (j / grid.x) * ch, cw, ch)
			var found := bool(t.found)
			var ts := minf(cw - Style.u(30.0), ch - Style.u(54.0))
			var pic := Rect2(cell.position + Vector2((cw - ts) * 0.5, Style.u(4.0)), Vector2(ts, ts))
			if found:
				draw_rect(pic, _c(Color(PAPER_DARK, 0.5), mod))
			_picture(pic, art.part(String(t.id), not found) if art != null else null, not found, mod)
			var nm: String = String(t.name.get(lang, t.id)) if found else "?"
			var nw := cw - Style.u(10.0)
			var shown := _fit(Style.font_italic(), nm, 17.0, nw)
			var w := Style.text_width(Style.font_italic(), shown, Style.u(17.0))
			_ink(Style.font_italic(), Vector2(cell.position.x + (cw - w) * 0.5, pic.end.y + Style.u(20.0)), shown, 17.0, _c(INK_T if found else INK_FAINT, mod))
			if found:
				var sub := Strings.t("j_level", [maxi(int(t.level), 1)]) if bool(t.owned) else Strings.t("j_found")
				var sw := Style.text_width(fs, sub, Style.u(14.0))
				_ink(fs, Vector2(cell.position.x + (cw - sw) * 0.5, pic.end.y + Style.u(37.0)), sub, 14.0, _c(COPPER_D if bool(t.owned) else INK_SOFT, mod))
				if bool(t.owned):
					draw_circle(pic.position + Vector2(Style.u(5.0), Style.u(5.0)), Style.u(3.4), _c(COPPER_D, mod))

# --- secrets ---------------------------------------------------------------------------------------------------------

func _heading(p: Rect2, y: float, s: String, mod: Color) -> float:
	var f := Style.font_italic()
	_ink(f, Vector2(p.position.x, y + Style.u(20.0)), s, 24.0, _c(INK_T, mod))
	draw_line(Vector2(p.position.x, y + Style.u(30.0)), Vector2(p.position.x + minf(Style.text_width(f, s, Style.u(24.0)) + Style.u(24.0), p.size.x), y + Style.u(30.0)), _c(COPPER_D, mod), 1.4)
	return Style.u(44.0)

const SHARDS_PER_PAGE := 5

## The pages of the Secrets section in reading order: shards five to a page, then one page of fossils and the cave
## (a section the world does not report is left out).
func secret_pages() -> Array:
	var out: Array = []
	var n: int = model.get("shards", []).size()
	for from in range(0, n, SHARDS_PER_PAGE):
		out.append({"kind": "shards", "from": from, "to": mini(from + SHARDS_PER_PAGE, n)})
	if not model.get("fossils", []).is_empty() or String(model.get("cave", "")) != "":
		out.append({"kind": "rest"})
	return out

func _draw_secrets(pages: Array, mod: Color) -> void:
	var sp := secret_pages()
	if sp.is_empty():
		_empty(pages[0], mod)
		return
	for k in 2:
		var i := page * 2 + k
		if i >= sp.size():
			break
		var p: Rect2 = pages[k]
		var e: Dictionary = sp[i]
		if e.kind == "shards":
			_draw_shards(p, p.position.y, model.shards.slice(e.from, e.to), mod, e.from == 0)
		else:
			var y := p.position.y
			var fossils: Array = model.get("fossils", [])
			if not fossils.is_empty():
				y += _draw_fossils(p, y, fossils, mod)
			if String(model.get("cave", "")) != "":
				_draw_cave(p, y + Style.u(10.0), String(model.cave), mod)

func _draw_shards(p: Rect2, y: float, shards: Array, mod: Color, first: bool) -> float:
	var y0 := y
	y += _heading(p, y, Strings.t("j_shards") if first else Strings.t("j_shards_more"), mod)
	var fi := Style.font_italic()
	var fs := Style.font_sans()
	var lang := _lang()
	var row := minf((p.end.y - y) / shards.size(), Style.u(92.0))
	for s in shards:
		var found := bool(s.found)
		var c := Vector2(p.position.x + Style.u(12.0), y + Style.u(14.0))
		var pts := PackedVector2Array([c + Vector2(0, -Style.u(10.0)), c + Vector2(Style.u(8.0), -Style.u(1.0)), c + Vector2(Style.u(3.0), Style.u(10.0)), c + Vector2(-Style.u(7.0), Style.u(5.0)), c + Vector2(-Style.u(8.0), -Style.u(3.0))])
		if found:
			draw_colored_polygon(pts, _c(COPPER_D, mod))
		else:
			pts.append(pts[0])
			draw_polyline(pts, _c(INK_FAINT, mod), 1.4, true)
		var tx := p.position.x + Style.u(34.0)
		var w := p.size.x - Style.u(34.0)
		# the world names a shard in English only: the string table has the Spanish name
		var nm := Strings.t("shard_%d" % int(s.index)) if Strings.TABLE.has("shard_%d" % int(s.index)) else (String(s.name) if String(s.name) != "" else Strings.t("j_shard_n", [int(s.index) + 1]))
		if found:
			_ink(Style.font_sans(true), Vector2(tx, y + Style.u(18.0)), _fit(Style.font_sans(true), nm, 16.5, w), 16.5, _c(COPPER_D, mod))
			var line := Model.text_of(s.line, lang)
			_para(fi, Vector2(tx, y + Style.u(22.0)), line, 16.5, w, row - Style.u(26.0), _c(INK_T, mod))
		else:
			_ink(Style.font_sans(true), Vector2(tx, y + Style.u(18.0)), "?", 17.0, _c(INK_FAINT, mod))
			_ink(fs, Vector2(tx + Style.u(16.0), y + Style.u(18.0)), Strings.t("j_shard_unknown"), 15.5, _c(INK_FAINT, mod))
		y += row
	return y - y0

func _draw_fossils(p: Rect2, y: float, fossils: Array, mod: Color) -> float:
	var y0 := y
	y += _heading(p, y, Strings.t("j_fossils"), mod)
	var done := 0
	for f in fossils:
		if bool(f.studied):
			done += 1
	_ink(Style.font_sans(), Vector2(p.position.x, y + Style.u(14.0)), Strings.t("j_fossil_count", [done, fossils.size()]), 16.5, _c(INK_SOFT, mod))
	y += Style.u(32.0)
	var step := Style.u(30.0)
	var per_row := maxi(int(p.size.x / step), 1)
	for i in fossils.size():
		var c := Vector2(p.position.x + step * (i % per_row) + Style.u(12.0), y + step * (i / per_row) + Style.u(12.0))
		var studied := bool(fossils[i].studied)
		var old := int(fossils[i].kind) == Model.NODE_OLD_CARCASS
		var icon := "bone" if old else "fang"
		if studied:
			Glyphs.draw(self, icon, c, 24.0, _c(COPPER_D, mod))
		else:
			draw_arc(c, Style.u(9.0), 0.0, TAU, 20, _c(INK_FAINT, mod), 1.4, true)
			var f := Style.font_italic()
			draw_string(f, c + Vector2(-Style.u(3.5), Style.u(5.5)), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(15.0)), _c(INK_FAINT, mod))
	var rows := int(ceil(float(fossils.size()) / per_row))
	return y + step * rows - y0 + Style.u(8.0)

func _draw_cave(p: Rect2, y: float, cave: String, mod: Color) -> void:
	y += _heading(p, y, Strings.t("j_cave"), mod)
	var key: String = {"chamber": "j_cave_chamber", "entered": "j_cave_found"}.get(cave, "j_cave_unknown")
	var known := cave != "unknown"
	var fi := Style.font_italic()
	var text := Strings.t(key) if known else "?  " + Strings.t(key)
	_para(fi, Vector2(p.position.x, y + Style.u(10.0)), text, 18.0, p.size.x, maxf(p.end.y - y - Style.u(10.0), 0.0), _c(INK_T if known else INK_FAINT, mod))

# --- recipes ---------------------------------------------------------------------------------------------------------

func _draw_recipes(pages: Array, mod: Color) -> void:
	var rs: Array = model.get("recipes", [])
	if rs.is_empty():
		_empty(pages[0], mod)
		return
	for k in 2:
		var p: Rect2 = pages[k]
		var slot_h := p.size.y / 2.0
		for j in 2:
			var i := page * 4 + k * 2 + j
			if i >= rs.size():
				break
			_recipe(Rect2(p.position.x, p.position.y + slot_h * j, p.size.x, slot_h - Style.u(10.0)), rs[i], mod)

func _recipe(r: Rect2, e: Dictionary, mod: Color) -> void:
	var fi := Style.font_italic()
	var fs := Style.font_sans()
	var fm := Style.font_sans(true)
	var lang := _lang()
	var st := String(e.state)
	var known := st == "known" or st == "mastered"
	var name := Model.text_of(e.name, lang)
	if name == "":
		name = Strings.t("j_recipe_spines") if String(e.id) == "bone_spines" else (String(e.id).replace("_", " ").capitalize() if String(e.id) != "" else Strings.t("j_recipe_name_unknown"))
	if st == "unknown":
		name = Strings.t("j_recipe_name_unknown") if String(e.id) != "bone_spines" else "? ? ?"
	var y := r.position.y
	_ink(fi, Vector2(r.position.x, y + Style.u(26.0)), _fit(fi, name, 26.0, r.size.x * 0.66), 26.0, _c(INK_T if st != "unknown" else INK_FAINT, mod))
	var tag := Strings.t("j_recipe_" + st)
	var tw := Style.text_width(fm, tag, Style.u(16.0))
	var col: Color = {"unknown": INK_FAINT, "hinted": INK_SOFT, "known": LICHEN_D, "mastered": COPPER_D}[st]
	_ink(fm, Vector2(r.end.x - tw, y + Style.u(26.0)), tag, 16.0, _c(col, mod))
	draw_line(Vector2(r.position.x, y + Style.u(36.0)), Vector2(r.end.x, y + Style.u(36.0)), _c(Color(INK_FAINT, 0.7), mod), 1.0)
	y += Style.u(50.0)
	# the clue slots: seen ones written, missing ones a "?"
	var total := maxi(int(e.clues_total), 1)
	var seen := mini(int(e.clues_seen), total)
	var texts: Array = e.clues
	_ink(fs, Vector2(r.position.x, y + Style.u(10.0)), Strings.t("j_recipe_clues", [seen, total]), 15.5, _c(INK_SOFT, mod))
	y += Style.u(20.0)
	var avail := r.end.y - y - Style.u(48.0)
	var per := minf(Style.u(40.0), avail / total)
	for k in total:
		var yy := y + per * k
		if yy + per > r.end.y:
			break
		if k < seen:
			var line := Model.text_of(texts[k], lang) if k < texts.size() else Strings.t("j_recipe_clue_generic")
			draw_circle(Vector2(r.position.x + Style.u(5.0), yy + Style.u(10.0)), Style.u(2.6), _c(COPPER_D, mod))
			_para(fi, Vector2(r.position.x + Style.u(16.0), yy), line, 16.0, r.size.x - Style.u(16.0), per, _c(INK_T, mod))
		else:
			_ink(fm, Vector2(r.position.x, yy + Style.u(14.0)), "?", 16.0, _c(INK_FAINT, mod))
	y += per * total + Style.u(2.0)
	if known:
		var note := Model.text_of(e.note, lang)
		if note == "" and String(e.id) == "bone_spines":
			note = Strings.t("j_recipe_spines_note")
		var facts: PackedStringArray = []
		if int(e.parts_need) >= 0:
			facts.append(Strings.t("j_recipe_parts", [int(e.parts_have), int(e.parts_need)]))
		if e.diet_ok != null:
			facts.append(Strings.t("j_recipe_diet_ok" if bool(e.diet_ok) else "j_recipe_diet_no"))
		if note != "":
			y += _para(fs, Vector2(r.position.x, y), note, 15.5, r.size.x, maxf(r.end.y - y, 0.0), _c(INK_SOFT, mod)) + Style.u(2.0)
		if not facts.is_empty():
			_para(fs, Vector2(r.position.x, y), "  ·  ".join(facts), 15.5, r.size.x, maxf(r.end.y - y, 0.0), _c(INK_SOFT, mod))

func _empty(p: Rect2, mod: Color) -> void:
	var f := Style.font_italic()
	var s := Strings.t("j_empty")
	_ink(f, Vector2(p.position.x, p.position.y + Style.u(60.0)), s, 22.0, _c(INK_FAINT, mod))
