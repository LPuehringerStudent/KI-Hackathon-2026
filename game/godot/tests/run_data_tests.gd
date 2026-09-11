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
	await _check_map_view(data)
	quit(1 if failures > 0 else 0)


func _check_map_view(data: Dictionary) -> void:
	var mv = preload("res://scenes/map_view.tscn").instantiate()
	get_root().add_child(mv)
	await process_frame
	check(mv.markers.size() > 400, "map_view created markers (%d)" % mv.markers.size())
	check(mv.has_signal("entity_clicked"), "map_view exposes entity_clicked signal")
	var mm = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_meta.json"))
	var sample: Vector2 = mv.latlon_to_pixel(float(mm.lat_min), float(mm.lon_min))
	check(sample.x >= -0.5 and sample.y <= float(mm.height) + 0.5,
		"latlon_to_pixel maps bounds corner into image")
	mv.set_entity_state(data.venues[0].id, "affected")
	mv.set_entity_state(data.venues[0].id, "resolved")
	mv.focus_entity(data.venues[0].id)
	mv.set_entity_state("unknown-id", "affected")
	mv.focus_entity("unknown-id")
	check(true, "set_entity_state/focus_entity tolerate known and unknown ids")
	# mentor-pack purchase badges (contract: Opus round 6/6.1)
	mv.refresh_badges({ data.venues[0].id: { "foodtruck": 2, "security": 1 } })
	await process_frame
	check(mv._badges.size() == 1 and mv._badges.has(data.venues[0].id),
		"badge appears for stocked venue only")
	check(mv._badges[data.venues[0].id].text == "2 · 1", "badge shows unit counts")
	mv.refresh_badges({ "unknown-venue": { "foodtruck": 1 } })
	await process_frame
	check(mv._badges.is_empty(), "badges ignore unknown venue ids")
	mv.refresh_badges({})
	await process_frame
	check(mv._badges.is_empty(), "badges clear on empty purchases")
	# purchased shuttles appear on the map, clear on empty
	var venue: Dictionary = data.venues[0]
	mv.update_shuttles([{ "lat": venue.lat, "lon": venue.lon }])
	await process_frame
	check(mv._shuttle_markers.size() == 1, "shuttle marker appears after purchase")
	mv.update_shuttles([])
	await process_frame
	check(mv._shuttle_markers.is_empty(), "shuttle markers clear when none")
	# mentor-pack purchase sprites (fallback dots while Astra's v3 is pending)
	mv.update_purchases({ data.venues[0].id: { "foodtruck": 2, "security": 1 } })
	await process_frame
	check(mv._purchase_markers.size() == 2, "food+security sprites appear at stocked venue")
	mv.update_purchases({ "unknown": { "foodtruck": 1 } })
	await process_frame
	check(mv._purchase_markers.is_empty(), "purchase sprites ignore unknown venues")
	mv.update_purchases({})
	await process_frame
	check(mv._purchase_markers.is_empty(), "purchase sprites clear when none")
	# zoom: positions scale, map root resizes, 1.0 restores
	var before: Vector2 = mv.markers[data.venues[0].id].position
	mv.set_zoom(2.0)
	await process_frame
	check(mv.markers[data.venues[0].id].position != before, "zoom repositions markers")
	check(mv._map_root.custom_minimum_size.x > 2000, "zoom enlarges map root")
	mv.set_zoom(1.0)
	await process_frame
	var restored: Vector2 = mv.markers[data.venues[0].id].position
	check(restored.distance_to(before) < 0.5, "zoom 1.0 restores positions (~0.01px float32 drift)")
	mv.queue_free()
