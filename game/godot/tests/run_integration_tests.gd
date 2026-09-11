extends SceneTree

const State := preload("res://scripts/game_state.gd")

class FakeVoices extends Node:
	var last_error := ""
	var offline := true
	var reply := "Ich hoere dir zu."

	func ask(_messages: Array, _max_tokens := 400) -> String:
		var answer := reply
		await get_tree().create_timer(0.03).timeout
		last_error = "PROXY_DOWN" if offline else ""
		return "" if offline else answer

var failures := 0
var ui: Control
var fake: FakeVoices


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func settle() -> void:
	for frame in range(3):
		await process_frame
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var active = current_scene
		if active != null and not active._voice_busy and not active.selected.is_empty():
			if active.finished or active._resolved.has(active._key(active.selected)) or not active.dialogue_state.is_empty():
				return
		await process_frame
	check(false, "dialogue completed before timeout")


func _run() -> void:
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	current_scene = ui
	await process_frame  # let _ready show the menu
	ui._start_game()  # press "Festival starten" (start menu)
	fake = FakeVoices.new()
	root.add_child(fake)
	ui.dialogue.voices = fake
	await settle()
	check(ui.game.day == 1 and not ui.dialogue_state.opening.is_empty(), "day one starts with offline opening")
	var entity_count := 0
	for key in ["venues", "trees", "fountains", "toilets", "streets"]:
		entity_count += ui.data[key].size()
	check(ui.map_view.markers.size() == entity_count, "all real markers loaded")
	var venue: Dictionary = ui.data.venues[0]
	var other: Dictionary = ui.data.venues[1]
	ui.map_view.focus_entity(venue.id)
	await process_frame
	var marker: Control = ui.map_view.markers[venue.id]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = marker.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await settle()
	check(ui.selected.id == venue.id, "native map click selects entity")
	ui.select_entity(venue.id, "venue")
	ui.select_entity(other.id, "venue")
	await settle()
	check(ui.dialogue_state.entity.id == other.id, "latest selection wins pending opening")
	check(ui.chat.get_node("Rows/Messages/History").get_child_count() == 1, "stale opening absent from chat")
	var opening: String = ui.dialogue_state.opening
	await ui.send_message("Was brauchst du?")
	check(ui.dialogue_state.history[-1].content != opening, "offline replies rotate")
	var before: Dictionary = ui.game.duplicate(true)
	ui.apply_decision("cut")
	check(ui.game == before, "invalid decision cannot mutate game")
	ui.apply_decision("shuttle")
	ui.apply_decision("shuttle")
	check(ui.game.decisions.size() == 1 and ui.game.shuttles.size() == 1, "offline decision and duplicate protection")
	check(not ui.map_view.markers[other.id].disabled and not ui._resolved.has("venue:" + str(other.id)), "venues stay open after a decision (repeatable purchases)")
	fake.offline = false
	ui.select_entity(venue.id, "venue")
	await settle()
	fake.reply = "Einverstanden. [[ENTSCHEID:shuttle]]"
	await ui.send_message("Richte den Shuttle ein.")
	check(ui.game.decisions.size() == 2, "validated model intent applied")
	check(not ui.chat.get_node("Rows/Messages/History").get_child(2).text.contains("[["), "model markers hidden")
	var tree: Dictionary = ui.data.trees[0]
	ui.select_entity(tree.id, "tree")
	await settle()
	fake.reply = "Ja. [[ENTSCHEID:cut]]"
	ui.send_message("Faelle den Baum.")
	ui.advance_day()
	await settle()
	check(ui.game.day == 2 and ui.game.decisions.size() == 2, "day change discards late decision")
	fake.offline = true
	var toilet: Dictionary = ui.data.toilets[0]
	ui.select_entity(toilet.id, "toilet")
	ui.apply_decision("relocate")
	await settle()
	check(ui.game.decisions.size() == 3 and ui.game.decisions[-1].day == 2, "day two decision works during pending voice")
	check(ui.map_view.markers[toilet.id].disabled, "resolved marker disabled")
	ui.advance_day()
	ui.select_entity(tree.id, "tree")
	await settle()
	ui.apply_decision("keep")
	check(ui.game.day == 3 and ui.game.decisions[-1].decision_id == "keep", "day three tree kept")
	ui.select_entity(venue.id, "venue")
	await settle()
	ui.apply_decision("foodtruck")
	ui.apply_decision("foodtruck")
	check(ui.game.purchases.get(str(venue.id), {}).get("foodtruck") == 2 and not ui._resolved.has("venue:" + str(venue.id)), "two food trucks bought through the chat, venue still open")
	ui.day_bar.pricing_buttons.premium.pressed.emit()
	check(State.pricing_for_day(ui.game, 3) == "premium" and ui.day_bar.pricing_buttons.premium.button_pressed and not ui.day_bar.pricing_buttons.standard.button_pressed, "day-bar pricing applies to today")
	ui.advance_day()
	check(ui.finished and ui.verdict.visible, "final verdict visible")
	var score_found := false
	for child: Node in ui.verdict.get_child(0).get_child(0).get_children():
		if child is Label and child.text.begins_with("Gesamtnote"):
			score_found = true
	check(score_found, "verdict shows a 0-100 Gesamtnote")
	before = ui.game.duplicate(true)
	ui.apply_decision("cut")
	ui.advance_day()
	ui.select_entity(venue.id, "venue")
	check(ui.game == before, "finished game cannot mutate")
	for value in [ui.meters.bars.attendance.value, ui.meters.bars.money.value, ui.meters.bars.happiness.value]:
		check(value >= 0 and value <= 100, "final meter in range")
	var restart: Button = ui.verdict.get_child(0).get_child(0).get_children().back()
	restart.pressed.emit()
	await scene_changed
	ui = current_scene
	await process_frame  # fresh scene shows the start menu again
	ui._start_game()
	ui.dialogue.voices = fake
	await settle()
	check(ui.game.day == 1 and ui.game.decisions.is_empty() and not ui.finished, "restart creates a fresh festival")
	ui.queue_free()
	fake.queue_free()
	await process_frame
	quit(1 if failures else 0)
