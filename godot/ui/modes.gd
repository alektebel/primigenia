extends RefCounted
## Interaction modes (G75) and the abilities each puts on keys 1-4.
## Move data follows docs/COMBAT.md (attack) and docs/P4.md 2.1 (social skills).

const ATTACK := &"attack"
const BEFRIEND := &"befriend"
const OBSERVE := &"observe"
const INTIMIDATE := &"intimidate"
## Eat replaces Attack in the radial of a carcass (it is not one of the four modes of a living creature).
const EAT := &"eat"
## No mode chosen yet: after a selection keys 1-4 do nothing until the player picks one on the ring.
const NONE := &""
const ALL: Array[StringName] = [ATTACK, BEFRIEND, OBSERVE, INTIMIDATE]

const TITLES := {ATTACK: "Attack", BEFRIEND: "Befriend", OBSERVE: "Observe", INTIMIDATE: "Intimidate", EAT: "Eat"}
const HINTS := {
	ATTACK: "Combat moves",
	BEFRIEND: "Sing, dance, charm",
	OBSERVE: "Stay near, unseen",
	INTIMIDATE: "Roar, display",
	EAT: "Feed on it",
}
## C-core verb each mode maps to (agent face).
const VERBS := {ATTACK: "attack", BEFRIEND: "befriend", OBSERVE: "observe", INTIMIDATE: "intimidate", EAT: "eat"}
## C-core verb numbers (core/include/cpore/world.h) and what `move` carries.
const VERB_NUMBERS := {"attack": 5, "befriend": 11, "gift": 12, "observe": 13, "intimidate": 14, "eat": 15}
## Gift items in the C table order (CP_ITEM_*): the C `move` of a gift.
const ITEMS := ["plant", "fruit", "meat", "bone"]

## id, display name, stamina cost (level 1 values).
const ABILITIES := {
	ATTACK: [
		{"id": "bite", "name": "Bite", "stamina": 9},
		{"id": "charge", "name": "Charge", "stamina": 18},
		{"id": "spit", "name": "Spit", "stamina": 12},
		{"id": "tail_strike", "name": "Tail", "stamina": 10},
	],
	BEFRIEND: [
		{"id": "sing", "name": "Sing", "stamina": 6},
		{"id": "dance", "name": "Dance", "stamina": 10},
		{"id": "charm", "name": "Charm", "stamina": 4},
		{"id": "pose", "name": "Pose", "stamina": 8},
	],
	OBSERVE: [
		{"id": "observe", "name": "Observe", "stamina": 0},
	],
	INTIMIDATE: [
		{"id": "roar", "name": "Roar", "stamina": 8},
		{"id": "display", "name": "Display", "stamina": 8},
	],
	EAT: [
		{"id": "eat", "name": "Eat", "stamina": 0},
	],
}

## Moves a loadout can hold that are not one of the four starting attack moves: shown by name on the hotbar when slotted.
const EXTRA_MOVES := {"flame": "Flamethrower"}

static func is_mode(m) -> bool:
	return StringName(m) in ALL or StringName(m) == EAT or StringName(m) == NONE

static func abilities_for(mode) -> Array:
	var out: Array = []
	for a in ABILITIES.get(StringName(mode), []):
		out.append(a.duplicate())
	return out

static func title(mode) -> String:
	return TITLES.get(StringName(mode), String(mode))
