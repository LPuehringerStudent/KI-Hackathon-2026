extends SceneTree
var ui: Node
var out_dir := "/tmp/claude-1000/-home-ayan-KI-Hackathon-2026/b5e53e86-8283-40a2-b7a6-7cd24ef789ca/scratchpad/shots/"

func _initialize() -> void:
	_run.call_deferred()

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
	_pick("venue", "Lentos Kunstmuseum"); ui.apply_decision("shuttle")
	_pick("venue", "OK Platz"); ui.apply_decision("shuttle")
	_pick("street", "Hauptplatz"); ui.apply_decision("carfree")
	ui.apply_pricing("fair")
	while not ui.finished:
		ui.advance_day()
		await create_timer(1.8).timeout
		print("day=%s finished=%s" % [ui.game.get("day"), ui.finished])
		if ui.finished:
			break
		ui.apply_pricing("fair")
		if int(ui.game.day) == 2:
			_pick("toilet", "Stadtpark Huemerstraße"); ui.apply_decision("relocate")
			_pick("venue", "Ars Electronica Center"); ui.apply_decision("security")
			_pick("venue", "OK Platz"); ui.apply_decision("security")
		else:
			_pick("venue", "Ars Electronica Center"); ui.apply_decision("plant"); ui.apply_decision("plant")
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	print("CAPTURE verdict result=%d" % root.get_texture().get_image().save_png(out_dir + "09_verdict.png"))
	quit(0)
