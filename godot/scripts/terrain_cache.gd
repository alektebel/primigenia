extends RefCounted
## FileAccess Variant decoding never allows objects. A full parameter digest
## prevents low-resolution tests or future tuning from poisoning W20 worlds.

func cache_path(params: Dictionary, directory := "user://terrain") -> String:
	var keys := params.keys()
	keys.sort()
	var canonical: Array = []
	for key in keys:
		canonical.append([key, params[key]])
	var version: int = ClassDB.instantiate("Cpore").terrain_version()
	return "%s/island-%s-v%d-%s.bin" % [directory, params.seed, version, JSON.stringify(canonical).sha256_text()]

func load_or_generate(native: RefCounted, params: Dictionary, directory := "user://terrain") -> Dictionary:
	var path := cache_path(params, directory)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file and file.get_length() > 4 and file.get_32() == 0x43504d30:
			var data = file.get_var(false)
			if valid(data, params, native.terrain_version()):
				data.cache_hit = true
				return data
	var data: Dictionary = native.generate(params)
	data.cache_hit = false
	if data.get("error", -1) != 0:
		return data
	DirAccess.make_dir_recursive_absolute(directory)
	# Temp + rename keeps interrupted generation from leaving a partial hit.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_32(0x43504d30)
		file.store_var(data, false)
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)
	return data

func valid(data: Variant, params: Dictionary, version: int) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != version or data.get("seed") != params.seed or data.get("n") != params.n:
		return false
	for key in ["height", "flow", "sediment"]:
		if not data.get(key) is PackedFloat32Array or data[key].size() != params.n * params.n:
			return false
	return data.get("material") is PackedByteArray and data.material.size() == params.n * params.n and data.get("hash") is String and data.get("caves") is Array
