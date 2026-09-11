extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	ui.dialogue.voices = null
	await create_timer(0.3).timeout
	var args := OS.get_cmdline_user_args()
	if args.has("--tree"):
		ui.select_entity(ui.data.trees[0].id, "tree")
		await create_timer(0.2).timeout
		ui.chat.add_message("Du", "Wie koennen wir beim Festival genug Schatten bewahren, ohne die Wege zu versperren?")
		ui.chat.add_message(str(ui.selected.get("species", "Baum")), "Meine Krone gehoert zu diesem Ort. Lass uns gemeinsam ueber Schatten und Raum sprechen.")
	if args.has("--verdict"):
		ui.apply_decision("shuttle")
		ui.advance_day()
		ui.select_entity(ui.data.toilets[0].id, "toilet")
		ui.apply_decision("relocate")
		ui.advance_day()
		ui.select_entity(ui.data.trees[0].id, "tree")
		ui.apply_decision("keep")
		ui.advance_day()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var output := args[0] if not args.is_empty() else "user://main.png"
	var error := picture.save_png(output)
	var sample := picture.get_pixel(picture.get_width() / 2, picture.get_height() / 2)
	print("CAPTURE %s %dx%d result=%d center=%s" % [output, picture.get_width(), picture.get_height(), error, sample])
	var issues := 0
	if not ui.finished:
		var panels: Array[Control] = [ui.meters, ui.day_bar, ui.chat]
		for index in range(panels.size() - 1):
			if panels[index].get_global_rect().end.y > panels[index + 1].get_global_rect().position.y + 1:
				issues += 1
		if ui.chat.get_node("Rows/Composer").get_global_rect().end.y > ui.get_global_rect().end.y - 25:
			issues += 1
		print("LAYOUT overlaps=%d" % issues)
	ui.queue_free()
	await process_frame
	quit(1 if error != OK or issues else 0)
