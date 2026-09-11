extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func _run() -> void:
	var ui: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	check(ui.menu.visible and not ui.started, "startup menu visible")
	check(ui.menu.get_node_or_null("CenterContainer") == null, "menu is runtime native UI")
	var start: Button = ui.menu.get_child(0).get_child(0).get_child(3)
	start.pressed.emit()
	await process_frame
	check(ui.started and ui.menu.is_queued_for_deletion(), "start opens game")
	check(ui.data.size() > 0 and ui.map_view != null, "game systems load after start")
	ui.queue_free()
	await process_frame
	quit(1 if failures else 0)
