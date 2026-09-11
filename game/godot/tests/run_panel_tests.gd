extends SceneTree

var failures := 0
var submitted := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func _run() -> void:
	var meters = load("res://scenes/meters.tscn").instantiate()
	root.add_child(meters)
	meters.set_meters({"attendance": -1, "money": 55, "happiness": 120})
	check(meters.bars.attendance.value == 0 and meters.bars.money.value == 55 and meters.bars.happiness.value == 100, "meters clamp and update")
	var day = load("res://scenes/day_bar.tscn").instantiate()
	root.add_child(day)
	day.set_day(3, {"title": "Tag 3", "focus": "Schatten", "hint": ""})
	check(day.get_node("Rows/Next").text == "Abschluss", "day three offers verdict")
	var picked := []
	day.pricing_selected.connect(func(id: String) -> void: picked.append(id))
	day.set_pricing("premium")
	check(day.pricing_buttons.premium.button_pressed and not day.pricing_buttons.fair.button_pressed and picked.is_empty(), "set_pricing highlights without emitting")
	day.pricing_buttons.fair.pressed.emit()
	check(picked == ["fair"], "pricing button emits its decision id")
	var chat = load("res://scenes/chat_panel.tscn").instantiate()
	root.add_child(chat)
	chat.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chat.size = Vector2(440, 500)
	chat.open_entity({"id": "tree-1", "name": "Linde", "type": "tree"}, [{"id": "keep", "label": "Stehen lassen", "cost": 0}])
	chat.message_submitted.connect(func(_text: String) -> void: submitted += 1)
	chat.get_node("Rows/Composer/Input").text = " "
	chat._submit()
	check(submitted == 0, "blank message ignored")
	chat.get_node("Rows/Composer/Input").text = "Hallo"
	chat.set_busy(true)
	chat._submit()
	check(submitted == 0, "busy composer blocked")
	check(not chat.get_node("Rows/Decisions").get_child(0).disabled, "decisions remain usable while voice pending")
	chat.set_busy(false)
	chat._submit()
	check(submitted == 1 and chat.get_node("Rows/Composer/Input").text == "", "send clears composer")
	chat.set_resolved(true)
	check(chat.get_node("Rows/Decisions").get_child(0).disabled, "resolved entity blocks duplicate decisions")
	chat.add_message("Du", "[url=https://example.com]literal text[/url]")
	check(not chat.get_node("Rows/Messages/History").get_child(0).bbcode_enabled, "chat text never interpreted as BBCode")
	await process_frame
	await process_frame
	meters.queue_free()
	day.queue_free()
	chat.queue_free()
	await process_frame
	quit(1 if failures else 0)
