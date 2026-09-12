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
	check(not ui.dock.drawer.visible, "game starts with map and icon rail only")
	check(map.size.is_equal_approx(ui.size), "map fills the viewport")
	var ambience = map._ambience
	check(ambience.routes.size() == 2, "two separated boat routes")
	var mask_res: Resource = load("res://assets/boat_clearance.png")
	var mask: Image = mask_res.get_image() if mask_res != null else Image.load_from_file("res://assets/boat_clearance.png")
	if mask == null:
		print("SKIP run_style_tests: boat_clearance.png not loadable in this environment (needs a display import)")
		quit(0)
		return
	check(mask.get_width() * 16 == int(map._meta.width), "boat mask matches native map size")
	check(ambience._lights.texture.get_width() == int(map._meta.width), "night windows match native map size")
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
				separated = separated and a.distance_to(b) >= ambience.ROUTE_SEPARATION
	check(separated, "boat routes retain separation for hulls and wakes")
	var before: float = ambience.followers[0].progress if not ambience.followers.is_empty() else 0.0
	await create_timer(0.3).timeout
	check(not ambience.followers.is_empty() and ambience.followers[0].progress > before, "boats move")
	for index in ambience.followers.size():
		var follow: PathFollow2D = ambience.followers[index]
		var curve: Curve2D = follow.get_parent().curve
		follow.progress = curve.get_baked_length() - 0.15
		var previous := follow.position
		ambience._process(0.02)
		check(follow.position.distance_to(previous) < 2.0, "boat loop has no teleport")
		check(follow.loop and follow.cubic_interp and follow.modulate.a == 1.0, "boat stays visible on a smooth loop")
		check(ambience.boats[index].hframes * ambience.boats[index].vframes == 64, "64 modeled boat headings")
		check(ambience.boats[index].get_rect().size.x * ambience.boats[index].scale.x > 150, "large detailed boat canvas")
		check(ambience.wakes[index].points.size() == 19, "wake trails the actual route")
		var boat: Sprite2D = ambience.boats[index]
		var last_heading: float = boat.material.get_shader_parameter("heading")
		var smooth := true
		for step in range(600):
			ambience._process(1.0 / 60.0)
			var heading: float = boat.material.get_shader_parameter("heading")
			smooth = smooth and absf(wrapf(heading - last_heading, -32.0, 32.0)) < 0.1
			smooth = smooth and boat.frame == 0 and boat.rotation == 0.0 and boat.position == Vector2.ZERO
			last_heading = heading
		check(smooth, "boat headings blend continuously without rotation snaps or bobbing")
	var count: int = map.markers.size()
	var sizes := {}
	for id: String in map.markers:
		sizes[id] = map.markers[id].texture_normal.get_size()
	await map.set_zoom(1.5)
	await create_timer(0.4).timeout
	var stable := true
	for id: String in map.markers:
		var tree: bool = map.markers[id].get_meta("etype") == "tree"
		stable = stable and map.markers[id].scale.is_equal_approx(Vector2(1.5, 1.5) if tree else Vector2.ONE)
		stable = stable and map.markers[id].texture_normal.get_size() == sizes[id]
		if tree:
			stable = stable and map.markers[id].texture_normal.get_image().is_invisible()
	check(stable and count == map.markers.size(), "zoom keeps all markers and fixed icon sizes")
	await map.set_zoom(0.75)
	map.focus_entity(str(ui.selected.id))
	await create_timer(0.3).timeout
	await capture("city-day")
	if not ambience.followers.is_empty():
		var boat_center: Vector2 = ambience.followers[0].position * map._zoom
		map._scroll.scroll_horizontal = int(boat_center.x - map._scroll.size.x / 2)
		map._scroll.scroll_vertical = int(boat_center.y - map._scroll.size.y / 2)
		await process_frame
		await capture("riverboat")
		map.focus_entity(str(ui.selected.id))
	map.play_day_transition(0.5)
	await create_timer(3.05).timeout
	check(float(ambience.light_material.get_shader_parameter("strength")) > 0.8, "window lights turn on at night")
	await capture("city-night")
	await create_timer(3.3).timeout
	check(not map.transition_busy, "visual day transition completes")
	check(ui.game == snapshot, "presentation leaves game state unchanged")
	check(is_zero_approx(float(ambience.light_material.get_shader_parameter("strength"))), "window lights off by day")
	for key: String in ["stats", "day", "chat"]:
		ui.dock.open_page(key)
		await create_timer(0.3).timeout
		check(ui.dock.drawer.visible and ui.dock.pages[key].visible, key + " opens")
		var visible_pages := 0
		for page: Control in ui.dock.pages.values():
			visible_pages += int(page.visible)
		check(visible_pages == 1, "one drawer page visible")
		await capture("dock-" + key)
	var sidebar: ScrollContainer = ui.dock.sidebar
	sidebar.ensure_control_visible(ui.chat.get_node("Rows/Composer/Input"))
	await process_frame
	check(ui.chat.get_node("Rows/Composer").get_global_rect().end.y <= ui.size.y - 20.0, "composer remains reachable inside sidebar")
	check(ui.dock.drawer.get_global_rect().end.x <= ui.size.x - 16, "drawer stays inside viewport")
	await capture("city-layout")
	ui.dock.close()
	await create_timer(0.25).timeout
	check(not ui.dock.drawer.visible, "drawer closes fully")
	ui.dock.open_page("day")
	ui.dock.close()
	ui.dock.open_page("chat")
	await create_timer(0.3).timeout
	check(ui.dock.drawer.visible and ui.dock.active_page == "chat", "rapid toggles keep the latest page")
	map.entity_clicked.emit(str(ui.selected.id), str(ui.selected.type))
	await process_frame
	check(ui.dock.active_page == "chat", "map selection keeps conversation open")
	var marker: Control = map.markers[str(ui.selected.id)]
	check(marker.global_position.x > ui.dock.drawer.get_global_rect().end.x, "selected place stays outside the drawer")
	check(ui.game == snapshot, "drawer controls leave game state unchanged")
	ui.queue_free()
	await process_frame
	print("STYLE failures=", failures)
	quit(1 if failures else 0)
