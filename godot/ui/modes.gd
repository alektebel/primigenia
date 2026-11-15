extends RefCounted
## Interaction modes (G75) and the abilities each puts on keys 1-4.
## Move data follows docs/COMBAT.md (attack) and docs/P4.md 2.1 (social skills).

const ATTACK := &"attack"
const BEFRIEND := &"befriend"
const OBSERVE := &"observe"
const INTIMIDATE := &"intimidate"
const ALL: Array[StringName] = [ATTACK, BEFRIEND, OBSERVE, INTIMIDATE]

const TITLES := {ATTACK: "Attack", BEFRIEND: "Befriend", OBSERVE: "Observe", INTIMIDATE: "Intimidate"}
const HINTS := {
	ATTACK: "Combat moves",
	BEFRIEND: "Sing, dance, charm, pose",
	OBSERVE: "Stay near, unseen",
	INTIMIDATE: "Roar and display",
}
## C-core verb each mode maps to (agent face).
const VERBS := {ATTACK: "attack", BEFRIEND: "befriend", OBSERVE: "observe", INTIMIDATE: "intimidate"}

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
		{"id": "display", "name": "Display", "stamina": 6},
	],
}

static func is_mode(m) -> bool:
	return StringName(m) in ALL

static func abilities_for(mode) -> Array:
	var out: Array = []
	for a in ABILITIES.get(StringName(mode), []):
		out.append(a.duplicate())
	return out

static func title(mode) -> String:
	return TITLES.get(StringName(mode), String(mode))
