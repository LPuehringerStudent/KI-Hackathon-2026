extends SceneTree

var ui: Node
var out_dir := "/tmp/claude-1000/-home-ayan-KI-Hackathon-2026/b5e53e86-8283-40a2-b7a6-7cd24ef789ca/scratchpad/shots/"

func _initialize() -> void:
	_run.call_deferred()

func _shot(name: String) -> void:
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var err := picture.save_png(out_dir + name + ".png")
	print("CAPTURE %s result=%d" % [name, err])

func _id(type: String, wanted: String) -> String:
	for r: Dictionary in ui.data.get(type + "s", []):
		if str(r.get("name", "")) == wanted:
			return str(r.id)
	return ""

func _run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	await create_timer(0.4).timeout
	ui._start_game()
	ui.dialogue.voices = null
	await create_timer(0.9).timeout
	await _shot("01_map")

	# a venue with its decision chips and previews
	ui.select_entity(_id("venue", "Ars Electronica Center"), "venue")
	ui.dock.open_page("chat")
	await create_timer(0.9).timeout
	await _shot("02_venue")

	# the meters page
	ui.dock.open_page("stats")
	await create_timer(0.7).timeout
	await _shot("02b_stats")

	# the day page with the citizen wish
	ui.dock.open_page("day")
	await create_timer(0.7).timeout
	await _shot("02c_day")

	# a tree speaking
	ui.select_entity(str(ui.data.trees[0].id), "tree")
	ui.dock.open_page("chat")
	await create_timer(0.8).timeout
	await _shot("03_tree")

	# demo route -> day 2 incident
	ui.select_entity(_id("venue", "Lentos Kunstmuseum"), "venue")
	ui.apply_decision("shuttle")
	ui.select_entity(_id("venue", "OK Platz"), "venue")
	ui.apply_decision("shuttle")
	ui.advance_day()
	ui.dock.open_page("chat")
	await create_timer(1.4).timeout
	await _shot("04_incident")

	ui.select_entity(_id("venue", "Ars Electronica Center"), "venue")
	ui.apply_decision("security")
	ui.advance_day()
	await create_timer(0.8).timeout
	ui.select_entity(_id("venue", "Ars Electronica Center"), "venue")
	ui.apply_decision("plant")
	ui.advance_day()
	await create_timer(1.4).timeout
	await _shot("05_verdict")
	quit(0)
