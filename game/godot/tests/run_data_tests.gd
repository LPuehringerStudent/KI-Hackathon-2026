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
	check(mv._map_rect.modulate == Color.WHITE, "gameplay lighting constant (no per-day tint)")
	mv.play_day_transition(10.0)
	for i in 60:
		if not mv.transition_busy:
			break
		await process_frame
	check(not mv.transition_busy, "day transition completes and clears busy flag")
	# map modes: layer switch builds an overlay; inverse transform roundtrips
	var venue2: Dictionary = data.venues[0]
	var px: Vector2 = mv.latlon_to_pixel(float(venue2.lat), float(venue2.lon))
	var ll: Vector2 = mv.pixel_to_latlon(px)
	check(ll.distance_to(Vector2(float(venue2.lat), float(venue2.lon))) < 0.0005,
		"pixel_to_latlon inverts latlon_to_pixel")
	mv.rebuild_layers(data, {})
	mv.set_layer_mode("sicherheit")
	await process_frame
	check(mv._layer_rect.visible and mv._layer_rect.texture != null,
		"security layer builds a visible overlay")
	check(mv._layer_value_at(float(venue2.lat), float(venue2.lon)).contains("Sicherheit"),
		"layer hover reports the venue security value")
	mv.set_layer_mode("stadt")
	await process_frame
	check(not mv._layer_rect.visible, "stadt mode hides the overlay")
	# multi-select API: selection set drives the bulk bar (ctrl-path itself
	# needs a held key, so the selection is populated directly)
	var trees: Array = data.trees.slice(0, 5)
	for t: Dictionary in trees:
		mv._selection[str(t.id)] = mv.markers[str(t.id)]
		mv._selection_type = "tree"
		mv.markers[str(t.id)].modulate = Color(1.0, 0.62, 0.2)
	mv._update_bulk_bar()
	check(mv.get_selection_ids().size() == 5, "multi-select holds five trees")
	check(mv._bulk_bar.visible, "bulk action bar appears for multi-selection")
	check(mv._bulk_decisions().size() > 0, "bulk decisions resolve for the selection type")
	mv.clear_selection()
	check(mv.get_selection_ids().is_empty() and not mv._bulk_bar.visible,
		"clear_selection empties selection and hides the bar")
	# planted trees (Opus contract: state.planted_trees) appear as sprites
	var tree0: Dictionary = data.trees[0]
	mv.update_planted_trees([{ "lat": tree0.lat, "lon": tree0.lon, "crown_m": 6.0, "age": 0 }])
	await process_frame
	check(mv._planted_markers.size() == 1, "planted tree appears on the map")
	mv.update_planted_trees([])
	await process_frame
	check(mv._planted_markers.is_empty(), "planted trees clear when none")
	# custom hover tip: shows entity info, hides again
	var dot: TextureButton = mv.markers[data.venues[0].id]
	mv._show_tip(dot)
	check(mv._tip.visible and mv._tip.get_node("L").text.contains(str(data.venues[0].name)),
		"hover tip shows the entity name and info")
	mv._hide_tip()
	check(not mv._tip.visible, "hover tip hides on exit")
	mv.queue_free()
