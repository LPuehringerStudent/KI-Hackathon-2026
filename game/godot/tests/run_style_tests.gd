extends SceneTree

var failures := 0
var output := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			output = arg.trim_prefix("--capture=")
		if arg == "--compact":
			root.content_scale_size = Vector2i(1000, 650)
			root.size = Vector2i(1000, 650)
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func capture(stem: String) -> void:
	if output.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(output.path_join(stem + ".png")) == OK, stem + " capture")


func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	await create_timer(0.4).timeout
	await capture("menu")
	ui._start_game()
	ui.dialogue.voices = null
	await create_timer(0.8).timeout
	var snapshot: Dictionary = ui.game.duplicate(true)
	var map = ui.map_view
	var ambience = map._ambience
	check(ambience.routes.size() == 2, "two separated boat routes")
	var mask: Image = load("res://assets/boat_clearance.png").get_image()
	var safe := true
	for route: PackedVector2Array in ambience.routes:
		for point in route:
			var cell := Vector2i(point / 16.0)
			safe = safe and mask.get_pixelv(cell).r > 0.9
	check(safe, "all routes stay in the eroded water mask")
	var separated := true
	if ambience.routes.size() == 2:
		for a: Vector2 in ambience.routes[0]:
			for b: Vector2 in ambience.routes[1]:
				separated = separated and a.distance_to(b) >= 48.0
	check(separated, "boat routes retain separation for hulls and wakes")
	var before: float = ambience.followers[0].progress if not ambience.followers.is_empty() else 0.0
	await create_timer(0.3).timeout
	check(not ambience.followers.is_empty() and ambience.followers[0].progress > before, "boats move")
	var count: int = map.markers.size()
	var sizes := {}
	for id: String in map.markers:
		sizes[id] = map.markers[id].texture_normal.get_size()
	await map.set_zoom(1.5)
	await create_timer(0.4).timeout
	var stable := true
	for id: String in map.markers:
		stable = stable and map.markers[id].scale.is_equal_approx(Vector2.ONE)
		stable = stable and map.markers[id].texture_normal.get_size() == sizes[id]
	check(stable and count == map.markers.size(), "zoom keeps all markers and fixed icon sizes")
	await map.set_zoom(0.75)
	map.focus_entity(str(ui.selected.id))
	await create_timer(0.3).timeout
	await capture("city-day")
	map.play_day_transition(0.5)
	await create_timer(3.05).timeout
	check(float(ambience.light_material.get_shader_parameter("strength")) > 0.8, "window lights turn on at night")
	await capture("city-night")
	await create_timer(3.3).timeout
	check(not map.transition_busy, "visual day transition completes")
	check(ui.game == snapshot, "presentation leaves game state unchanged")
	check(is_zero_approx(float(ambience.light_material.get_shader_parameter("strength"))), "window lights off by day")
	var panels: Array[Control] = [ui.meters, ui.day_bar, ui.chat]
	for i in range(panels.size() - 1):
		check(panels[i].get_global_rect().end.y <= panels[i + 1].get_global_rect().position.y + 1.0, "sidebar sections do not overlap")
	var sidebar: ScrollContainer = ui.get_node("RootSplit/PanelSlot")
	sidebar.ensure_control_visible(ui.chat.get_node("Rows/Composer/Input"))
	await process_frame
	check(ui.chat.get_node("Rows/Composer").get_global_rect().end.y <= ui.size.y - 20.0, "composer remains reachable inside sidebar")
	check(ui.get_node("RootSplit").position.y >= 16.0, "map stays inside viewport frame")
	await capture("city-layout")
	ui.queue_free()
	await process_frame
	print("STYLE failures=", failures)
	quit(1 if failures else 0)
