extends PanelContainer
## Card shown when a creature is selected (G75): species, temperament, diet,
## relationship (stranger > neutral > trusted > ally), species resolved count
## and a hint of what it likes.

const Palette := preload("res://ui/palette.gd")

const TEMPERAMENTS := ["Timid", "Territorial", "Aggressive"]
const DIETS := ["Herbivore", "Carnivore", "Omnivore"]
const RELATIONSHIPS := ["Stranger", "Neutral", "Trusted", "Ally"]
const TEMPERAMENT_NOTES := [
	"Wary; easy to scare, easy to calm.",
	"Defends its ground; warn before approaching.",
	"Refuses social play until calmed.",
]

var info: Dictionary = {}
var _species: Label
var _name: Label
var _temper: Label
var _diet: Label
var _rel_label: Label
var _pips: Array[Panel] = []
var _resolved: Label
var _trust: Label
var _trust_bar: ProgressBar
var _mood: Label
var _beat: Label
var _likes: Label
var _note: Label

func _ready() -> void:
	if _species == null:
		_build()

func _build() -> void:
	add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 16, Palette.BORDER, 14))
	custom_minimum_size = Vector2(250, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_species = Label.new()
	_species.add_theme_font_size_override("font_size", 20)
	_species.add_theme_color_override("font_color", Palette.GOLD)
	v.add_child(_species)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Palette.MUTED)
	v.add_child(_name)
	_temper = _row(v, "Temperament")
	_diet = _row(v, "Diet")
	_rel_label = _row(v, "Relationship")
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 5)
	for i in 4:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(0, 8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pips.add_child(p)
		_pips.append(p)
	v.add_child(pips)
	_trust = _row(v, "Trust")
	_trust_bar = Palette.bar(Palette.LEAF, 8)
	_trust_bar.max_value = 100.0
	v.add_child(_trust_bar)
	_mood = _row(v, "Mood")
	_resolved = _row(v, "Species resolved")
	_note = Label.new()
	_note.add_theme_color_override("font_color", Palette.MUTED)
	_note.add_theme_font_size_override("font_size", 12)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	_likes = Label.new()
	_likes.add_theme_color_override("font_color", Palette.LEAF)
	_likes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_likes)

func _row(parent: Control, caption: String) -> Label:
	var h := HBoxContainer.new()
	var c := Label.new()
	c.text = caption
	c.add_theme_color_override("font_color", Palette.MUTED)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	parent.add_child(h)
	return val

static func _index_of(value, names: Array) -> int:
	if value is int or value is float:
		return clampi(int(value), 0, names.size() - 1)
	var s := String(value).to_lower()
	for i in names.size():
		if String(names[i]).to_lower() == s:
			return i
	return 0

func set_info(d: Dictionary) -> void:
	if _species == null:
		_build()
	info = d
	var t := _index_of(d.get("temperament", 0), TEMPERAMENTS)
	var diet := _index_of(d.get("diet", 0), DIETS)
	var rel := _index_of(d.get("relationship", 0), RELATIONSHIPS)
	_species.text = String(d.get("species", "Unknown"))
	_name.text = String(d.get("name", ""))
	_name.visible = _name.text != ""
	_temper.text = TEMPERAMENTS[t]
	_diet.text = DIETS[diet]
	_rel_label.text = RELATIONSHIPS[rel]
	_rel_label.add_theme_color_override("font_color", [Palette.MUTED, Palette.TEXT, Palette.EMBER, Palette.LEAF][rel])
	for i in 4:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(4)
		s.bg_color = Palette.LEAF if i <= rel else Color("ffffff22")
		_pips[i].add_theme_stylebox_override("panel", s)
	var res := int(d.get("resolved", 0))
	var total := int(d.get("resolved_total", 4))
	_resolved.text = "%d / %d" % [res, total]
	_note.text = TEMPERAMENT_NOTES[t]
	var trust := int(d.get("trust", 0))
	_trust.text = "%d / 100%s" % [trust, "  (bonded)" if bool(d.get("bonded", false)) else ""]
	_trust_bar.value = clampf(trust, 0, 100)
	var mood := int(d.get("mood", 0))
	_mood.text = "%s (%d)" % [("Upset" if mood <= -20 else "Wary" if mood < 0 else "Calm" if mood < 20 else "Joyful"), mood]
	var likes = d.get("likes", "")
	var likes_text := ", ".join(likes) if likes is Array else String(likes)
	var dislikes = d.get("dislikes", [])
	var dislikes_text := ", ".join(dislikes) if dislikes is Array else String(dislikes)
	_likes.text = ("Likes: " + likes_text) if likes_text != "" else "Likes: unknown yet. Try a skill or a gift, or observe it."
	if dislikes_text != "":
		_likes.text += "\nDislikes: " + dislikes_text
	if int(d.get("carcass_meat", -1)) >= 0:
		_note.text = "Remains: %d bites of meat left." % int(d.carcass_meat)
		for n in [_temper, _diet, _rel_label, _trust, _mood]:
			n.get_parent().visible = false
		_trust_bar.visible = false
		for p in _pips:
			p.visible = false
	else:
		for n in [_temper, _diet, _rel_label, _trust, _mood]:
			n.get_parent().visible = true
		_trust_bar.visible = true
		for p in _pips:
			p.visible = true

## Strings currently displayed (used by tests).
func snapshot() -> Dictionary:
	return {
		"species": _species.text, "name": _name.text, "temperament": _temper.text, "diet": _diet.text,
		"relationship": _rel_label.text, "resolved": _resolved.text, "likes": _likes.text, "note": _note.text,
		"trust": _trust.text, "mood": _mood.text,
	}
