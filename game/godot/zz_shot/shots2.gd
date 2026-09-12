extends SceneTree

var ui: Node
var out_dir := "/tmp/claude-1000/-home-ayan-KI-Hackathon-2026/b5e53e86-8283-40a2-b7a6-7cd24ef789ca/scratchpad/shots/"

func _initialize() -> void:
	_run.call_deferred()

func _shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	print("CAPTURE %s result=%d" % [name, root.get_texture().get_image().save_png(out_dir + name + ".png")])

func _id(type: String, wanted: String) -> String:
	for r: Dictionary in ui.data.get(type + "s", []):
		if str(r.get("name", "")) == wanted:
			return str(r.id)
	return ""

func _pick(type: String, name: String) -> void:
	ui.select_entity(_id(type, name), type)

func _run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	await create_timer(0.4).timeout
	ui._start_game()
	ui.dialogue.voices = null
	await create_timer(1.0).timeout

	# security layer on day 2, city untouched: red where the crowd is unguarded
	ui.advance_day()
	await create_timer(1.6).timeout
	ui.map_view.set_layer_mode("sicherheit")
	await create_timer(1.0).timeout
	await _shot("06_security_layer")

	ui.map_view.set_layer_mode("stadt")
	ui.dock.open_page("day")
	await create_timer(0.8).timeout
	await _shot("07_day")

	# play to the verdict
	_pick("venue", "Lentos Kunstmuseum"); ui.apply_decision("shuttle")
	_pick("venue", "OK Platz"); ui.apply_decision("shuttle")
	_pick("venue", "Ars Electronica Center"); ui.apply_decision("security")
	ui.advance_day()
	await create_timer(1.6).timeout
	_pick("venue", "Ars Electronica Center"); ui.apply_decision("plant")
	ui.apply_decision("plant")
	ui.advance_day()
	await create_timer(2.2).timeout
	await _shot("08_verdict")
	quit(0)
