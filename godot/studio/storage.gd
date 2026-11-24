extends RefCounted
## Saves cpore.creature/4 JSON (format unchanged, readable by the web studio) in the user data folder.

const Genome := preload("genome.gd")

const TestIsolation := preload("res://devtools/test_isolation.gd")
var dir := ""

func _init(base_dir := "") -> void:
	dir = base_dir if base_dir != "" else TestIsolation.user("studio")
	DirAccess.make_dir_recursive_absolute(dir)

static func slug(name: String) -> String:
	var out := ""
	for c in name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif out != "" and not out.ends_with("-"):
			out += "-"
	out = out.trim_suffix("-")
	return out if out != "" else "criatura"

func path_for(name: String) -> String:
	return dir.path_join(slug(name) + ".json")

## Write a document. Returns the path ("" on failure).
func save(doc: Dictionary, name := "") -> String:
	return export_to(doc, path_for(name if name != "" else str(doc.get("name", ""))))

func export_to(doc: Dictionary, path: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(doc, " ", true))
	f.close()
	return path

func list() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out

## Read + validate (+ migrate) a file. Returns Genome.parse's result.
func import_from(path: String, types: Dictionary) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "open", "genome": null, "warnings": []}
	return Genome.parse(f.get_as_text(), types)

func load_named(file: String, types: Dictionary) -> Dictionary:
	return import_from(dir.path_join(file), types)

func delete(file: String) -> void:
	DirAccess.remove_absolute(dir.path_join(file))
