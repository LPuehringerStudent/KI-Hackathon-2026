extends SceneTree
## Headless test runner: godot --headless --path game/godot -s res://tests/run_tests.gd
## Exits 0 when all checks pass, 1 otherwise.
## Note: checks run deferred — autoloads are only added to the tree after
## this script's _init() returns.

var failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var data: Dictionary = get_root().get_node("Data").load_all()
	check(data.has("venues") and data.venues.size() >= 8 and data.venues.size() <= 20,
		"venues loaded with plausible count (%d)" % data.get("venues", []).size())
	check(data.get("trees", []).size() == 400, "trees capped at 400")
	check(data.trees[0].has("species") and data.trees[0].has("crown_m"),
		"tree records expose species + crown_m")
	check(data.get("fountains", []).size() > 0 and data.get("toilets", []).size() > 0,
		"service points loaded")
	check(data.get("streets", []).size() >= 5, "streets loaded")
	check(data.has("meta") and data.meta.has("bounds"), "meta with bounds loaded")
	check(data.venues[0].has("event_weight"), "venues expose event_weight")
	quit(1 if failures > 0 else 0)
