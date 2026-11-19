extends Control
## The journal (J) and the family tree (T): their entry points exist, the pages are a later design. A veil, a title, and
## (journal) the DNA earned in total, which the DNA sign no longer shows. Esc, the same key or a click closes it.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const Glyphs := preload("res://ui/glyphs.gd")

signal closed

var kind := ""                       # "journal" or "tree"
var dna_total := 0
var discovered: Array = []
var open := false
var _alpha := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func open_view(k: String, total: int = 0) -> void:
	kind = k
	dna_total = total
	open = true
	visible = true

func close_view() -> void:
	if open:
		open = false
		closed.emit()

func handle_input(e: InputEvent) -> bool:
	if not open:
		return false
	if e is InputEventMouseButton and e.pressed:
		close_view()
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("pause_menu") or e.is_action_pressed("journal") or e.is_action_pressed("family_tree"):
			close_view()
		return true
	return e is InputEventMouseMotion

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if open else 0.0, dt, Style.OUT if open else Style.OUT)
	if _alpha <= 0.003 and not open:
		visible = false
		return
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var title := Strings.t("journal_title" if kind == "journal" else "tree_title")
	Glyphs.draw(self, "journal" if kind == "journal" else "tree", c + Vector2(0, -Style.u(70.0)), 36.0, Color(Palette.BONE, _alpha))
	var f := Style.font_italic()
	var w := Style.text_width(f, title, Style.u(30.0))
	Style.text(self, f, c + Vector2(-w * 0.5, -Style.u(16.0)), title, Style.u(30.0), Color(Palette.BONE, _alpha))
	var y := c.y + Style.u(18.0)
	if kind == "journal":
		var line := "%s  %d" % [Strings.t("journal_total"), dna_total]
		var lw := Style.text_width(Style.font_sans(true), line, Style.u(19.0))
		Style.text(self, Style.font_sans(true), Vector2(c.x - lw * 0.5, y), line, Style.u(19.0), Color(Palette.COPPER, _alpha))
		y += Style.u(30.0)
	var s := Strings.t("journal_stub")
	if kind == "journal" and not discovered.is_empty():
		var names: PackedStringArray = []
		for part in discovered:
			names.append(str(part.id))
		s = ", ".join(names)
	var sw := Style.text_width(Style.font_sans(), s, Style.u(16.0))
	Style.text(self, Style.font_sans(), Vector2(c.x - sw * 0.5, y), s, Style.u(16.0), Color(Palette.FOG, _alpha * 0.9))
	var h := Strings.t("close_hint")
	var hw := Style.text_width(Style.font_sans(), h, Style.u(13.5))
	Style.text(self, Style.font_sans(), Vector2(c.x - hw * 0.5, y + Style.u(34.0)), h, Style.u(13.5), Color(Palette.FOG, _alpha * 0.8))
