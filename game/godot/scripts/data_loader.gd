extends Node
## Autoload singleton "Data" — loads all game data JSONs produced by
## tools/extract_innenstadt.py. Never hand-edit the JSONs; fix extraction instead.

const DATA_PATH := "res://data/"


func load_all(path := DATA_PATH) -> Dictionary:
	var result := {}
	for name in ["venues", "trees", "fountains", "toilets", "streets", "meta"]:
		var records = _load_json(path.path_join(name + ".json"))
		if records == null:
			push_error("data_loader: missing or invalid " + name + ".json")
			return {}
		result[name] = records
	# Optional datasets — present only when generated; consumers must handle absence.
	var airquality = _load_json(path.path_join("airquality.json"))
	if airquality != null:
		result["airquality"] = airquality
	return result


func _load_json(file_path: String):
	if not FileAccess.file_exists(file_path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	return parsed
