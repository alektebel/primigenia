extends RefCounted
## The first minutes (docs/godot/UI-DIEGETIC.md 7.15): one hint at a time at the bottom of the screen, a key cap and a short
## phrase. Each hint stays until the player has done the thing twice or 25 s have passed, and never shows in a fight (except
## the one about guarding). Progress is a bitmask in Game.settings["onboarding"]; "Show the hints again" in the menu clears it.

const Strings := preload("res://ui/strings.gd")

const STEPS := [
	{"id": "walk", "text": "hint_walk", "keys": "", "event": "walk"},
	{"id": "look", "text": "hint_look", "keys": "", "event": "look"},
	{"id": "select", "text": "hint_select", "keys": "", "event": "select"},
	{"id": "ring", "text": "hint_ring", "keys": "", "event": "mode", "need": "ring"},
	{"id": "keys", "text": "hint_keys", "keys": "1-4", "event": "ability", "need": "mode"},
	{"id": "fight", "text": "hint_fight", "keys": "Space", "event": "guard", "need": "fight", "in_fight": true},
	{"id": "eat", "text": "hint_eat", "keys": "", "event": "eat", "need": "carcass"},
	{"id": "nest", "text": "hint_nest", "keys": "L", "event": "loadout", "need": "nest"},
	{"id": "f1", "text": "hint_f1", "keys": "F1", "event": "f1"},
]
const PATIENCE := 25.0
const NEEDED := 2

var done_mask := 0
var counts := {}
var current := -1
var shown_for := 0.0
var enabled := true
var ctx := {"ring": false, "mode": false, "fight": false, "carcass": false, "nest": false}
var _game

func _init(game = null) -> void:
	_game = game
	if _game != null:
		done_mask = int(_game.settings.get("onboarding", 0))

func is_done(i: int) -> bool:
	return (done_mask & (1 << i)) != 0

func complete() -> bool:
	return done_mask == (1 << STEPS.size()) - 1

func reset() -> void:
	done_mask = 0
	counts.clear()
	shown_for = 0.0
	current = -1
	_save()

func _save() -> void:
	if _game != null:
		_game.settings["onboarding"] = done_mask
		_game.save_settings()

## The player did something the hints are about ("walk", "look", "select", "mode", "ability", "guard", "eat", "loadout", "f1").
func notify(event: String) -> void:
	for i in STEPS.size():
		if STEPS[i].event == event and not is_done(i):
			counts[i] = int(counts.get(i, 0)) + 1
			if counts[i] >= NEEDED:
				done_mask |= 1 << i
				_save()

func _needed(i: int) -> bool:
	var need: String = STEPS[i].get("need", "")
	return need == "" or bool(ctx.get(need, false))

## Which hint is up now: the first step not done whose situation holds; -1 for none. Never in a fight (except its own).
func pick() -> int:
	if not enabled:
		return -1
	for i in STEPS.size():
		if is_done(i) or not _needed(i):
			continue
		if bool(ctx.get("fight", false)) and not bool(STEPS[i].get("in_fight", false)):
			continue
		return i
	return -1

## Call each frame with the situation; returns {text, keys} for the words layer or {} for none.
func update(dt: float, situation: Dictionary) -> Dictionary:
	ctx = situation
	var i := pick()
	if i != current:
		current = i
		shown_for = 0.0
	if current < 0:
		return {}
	shown_for += dt
	if shown_for > PATIENCE:
		done_mask |= 1 << current
		_save()
		current = -1
		return {}
	return {"text": Strings.t(STEPS[current].text), "keys": STEPS[current].keys}
