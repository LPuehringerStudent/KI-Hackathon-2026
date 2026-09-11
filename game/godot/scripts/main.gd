extends Control

const State := preload("res://scripts/game_state.gd")
const Dialogue := preload("res://scripts/dialogue.gd")

## Visible on the start menu and the verdict screen so feedback can always
## name its build. Bump on every merged feature batch; git-tag main to match.
const VERSION := "1.4.0"
const UITheme := preload("res://scripts/ui_theme.gd")
const MapScene := preload("res://scenes/map_view.tscn")
const MetersScene := preload("res://scenes/meters.tscn")
const DayScene := preload("res://scenes/day_bar.tscn")
const ChatScene := preload("res://scenes/chat_panel.tscn")

var data := {}
var game := {}
var selected := {}
var dialogue_state := {}
var finished := false
var dialogue: Node
var map_view: Control
var meters: Control
var day_bar: Control
var chat: Control
var verdict: Control
var _generation := 0
var _voice_busy := false
var _resolved := {}
var menu: Control
var started := false


func _ready() -> void:
	theme = UITheme.create()
	RenderingServer.set_default_clear_color(Color("f3f5f4"))
	_show_menu()
	if OS.get_cmdline_user_args().has("--smoke-test"):
		_smoke_test.call_deferred()


## Release check without the editor: `buergermeister.x86_64 --headless -- --smoke-test`
## starts a festival, verifies data, markers, map texture and meters, prints one SMOKE line and
## exits 0 (ok) or 1.
func _smoke_test() -> void:
	_start_game()
	await get_tree().process_frame
	var meters_ok := false
	if not game.is_empty():
		var m := State.compute_meters(game, data)
		meters_ok = m.has("attendance") and m.has("money") and m.has("happiness")
	var marker_count: int = map_view.markers.size() if map_view != null else 0
	var map_rect: TextureRect = map_view.get_node_or_null("Scroll/MapRoot/Map") if map_view != null else null
	var texture_ok := map_rect != null and map_rect.texture != null
	var ok: bool = data.get("venues", []).size() > 0 and marker_count > 0 and texture_ok and meters_ok
	print("SMOKE %s venues=%d trees=%d fountains=%d toilets=%d streets=%d airquality=%s markers=%d map_texture=%s meters=%s" % [
		"OK" if ok else "FAIL", data.get("venues", []).size(), data.get("trees", []).size(), data.get("fountains", []).size(),
		data.get("toilets", []).size(), data.get("streets", []).size(), data.has("airquality"), marker_count, texture_ok, meters_ok])
	get_tree().quit(0 if ok else 1)


func _start_game() -> void:
	if started:
		return
	started = true
	menu.queue_free()
	dialogue = Dialogue.new()
	add_child(dialogue)
	meters = MetersScene.instantiate()
	day_bar = DayScene.instantiate()
	chat = ChatScene.instantiate()
	$RootSplit/PanelSlot.add_child(meters)
	$RootSplit/PanelSlot.add_child(day_bar)
	$RootSplit/PanelSlot.add_child(chat)
	day_bar.advance_requested.connect(advance_day)
	day_bar.pricing_selected.connect(apply_pricing)
	chat.message_submitted.connect(send_message)
	chat.decision_selected.connect(apply_decision)
	data = get_node("/root/Data").load_all()
	if data.is_empty() or data.get("venues", []).is_empty():
		chat.set_status("Spieldaten fehlen. Bitte Installation pruefen.")
		day_bar.set_enabled(false)
		return
	game = State.create()
	map_view = MapScene.instantiate()
	$RootSplit/MapSlot.add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.entity_clicked.connect(select_entity)
	_refresh()
	_initial_entity.call_deferred()


func _show_menu() -> void:
	menu = ColorRect.new()
	menu.name = "StartMenu"
	menu.color = Color("f3f5f4")
	add_child(menu)
	# Astra's miniature backdrop (Track C art); solid color fallback if absent
	var bg_path := "res://assets/sprites/ui_menu_background.png"
	if ResourceLoader.exists(bg_path):
		menu.color = Color(0, 0, 0, 0)
		var bg := TextureRect.new()
		bg.texture = load(bg_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(bg)
		menu.move_child(bg, 0)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(420, 0)
	rows.add_theme_constant_override("separation", 16)
	center.add_child(rows)
	var title := Label.new()
	title.text = "Bürgermeister:in fürs Festival"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 38)
	rows.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Drei Tage. Eine Stadt. Viele Stimmen."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("238573"))
	subtitle.add_theme_font_size_override("font_size", 19)
	rows.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	rows.add_child(spacer)
	var version_label := Label.new()
	version_label.text = "v" + VERSION
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color("9a9187"))
	rows.add_child(version_label)
	var start := Button.new()
	start.text = "Festival starten"
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_size_override("font_size", 19)
	start.pressed.connect(_start_game)
	rows.add_child(start)
	var help := Button.new()
	help.text = "So funktioniert das Spiel"
	help.custom_minimum_size.y = 42
	rows.add_child(help)
	var help_text := Label.new()
	help_text.text = "Waehle einen Ort auf der Karte, sprich mit ihm und triff Entscheidungen. Deine Werte veraendern sich live."
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.visible = false
	rows.add_child(help_text)
	help.pressed.connect(func() -> void: help_text.visible = not help_text.visible)
	var quit := Button.new()
	quit.text = "Beenden"
	quit.custom_minimum_size.y = 42
	quit.pressed.connect(func() -> void: get_tree().quit())
	rows.add_child(quit)
	start.grab_focus()


func _initial_entity() -> void:
	await get_tree().process_frame
	var first: Dictionary = data.venues[0]
	for venue: Dictionary in data.venues:
		if str(venue.name).contains("Ars Electronica Center"):
			first = venue
	select_entity(str(first.id), "venue")


func select_entity(id: String, kind: String) -> void:
	if finished:
		return
	var entity := State.find_entity(data, id, kind)
	if entity.is_empty():
		return
	_generation += 1
	selected = entity
	dialogue_state = {}
	chat.open_entity(entity, State.available_decisions(entity))
	map_view.focus_entity(id)
	if _resolved.has(_key(entity)):
		chat.set_resolved(true)
		chat.set_status("Entscheidung festgehalten.")
		return
	chat.set_busy(true)
	_start_opening()


func _start_opening() -> void:
	if _voice_busy or finished or selected.is_empty() or _resolved.has(_key(selected)):
		return
	_voice_busy = true
	var ticket := _generation
	var context := {"day": game.day}
	var result: Dictionary = await dialogue.start_dialogue(selected, context)
	_voice_busy = false
	if ticket != _generation:
		_start_opening.call_deferred()
		return
	dialogue_state = result
	chat.add_message(str(selected.get("name", selected.get("species", "Stadtort"))), result.opening)
	chat.set_busy(false)
	chat.set_status("Offline-Stimme" if result.offline else "")


func send_message(text: String) -> void:
	if finished or _voice_busy or dialogue_state.is_empty() or _resolved.has(_key(selected)):
		return
	_voice_busy = true
	var ticket := _generation
	chat.add_message("Du", text)
	chat.set_busy(true)
	var result: Dictionary = await dialogue.send_user_message(game.duplicate(true), dialogue_state, text)
	_voice_busy = false
	if ticket != _generation:
		_start_opening.call_deferred()
		return
	chat.add_message(str(selected.get("name", selected.get("species", "Stadtort"))), result.reply)
	chat.set_busy(false)
	chat.set_status("Offline-Stimme" if dialogue_state.offline else "")
	if result.intent is Dictionary:
		if result.intent.type == "decide":
			apply_decision(str(result.intent.decision_id))
		elif result.intent.type == "next_day":
			advance_day()


func apply_decision(id: String) -> void:
	if finished or selected.is_empty() or _resolved.has(_key(selected)):
		return
	if not State.decide(game, selected, id):
		chat.set_status("Diese Entscheidung ist nicht verfuegbar.")
		return
	_generation += 1
	# Venues stay open: food trucks and security are repeatable, curfew is a toggle.
	var stays_open := str(selected.get("type", "")) == "venue"
	if not stays_open:
		_resolved[_key(selected)] = true
		chat.set_resolved(true)
	chat.set_busy(false)
	for decision: Dictionary in State.available_decisions(selected):
		if decision.id == id:
			chat.add_message("Entscheidung", "%s / %d EUR" % [decision.label, int(decision.cost)])
	chat.set_status(_venue_status(selected) if stays_open else "Entscheidung festgehalten.")
	_refresh()


func apply_pricing(id: String) -> void:
	if finished or game.is_empty():
		return
	if State.decide(game, State.find_entity(data, "festival", "festival"), id):
		for decision: Dictionary in State.available_decisions(State.find_entity(data, "festival", "festival")):
			if decision.id == id:
				chat.set_status("Tag %d: %s" % [game.day, decision.label])
	_refresh()


func _venue_status(venue: Dictionary) -> String:
	var stock := State.stock_status(game, venue)
	if stock.is_empty():
		return "Entscheidung festgehalten."
	return "Foodtrucks %d/%d  ·  Security %d/%d" % [
		mini(stock.demand, stock.baseline + stock.foodtruck), stock.demand,
		mini(stock.demand, stock.baseline + stock.security), stock.demand]


## Synchronous entry point: plays the day/night transition, then the
## callback applies the day change. No coroutines (Godot 4.7 forbids
## fire-and-forget awaits; tweens complete via signal callback instead).
func advance_day(instant := false) -> void:
	if finished or game.is_empty() or map_view.transition_busy:
		return
	_generation += 1
	day_bar.set_enabled(false)
	map_view.play_day_transition(10.0 if instant else 1.0, _after_transition)


func _after_transition() -> void:
	if game.day == 3:
		finished = true
		chat.set_busy(false)
		chat.set_resolved(true)
		_show_verdict()
		return
	State.next_day(game)
	_refresh()
	day_bar.set_enabled(true)
	if not selected.is_empty() and not _resolved.has(_key(selected)):
		select_entity(str(selected.id), str(selected.type))


func _refresh() -> void:
	meters.set_meters(State.compute_meters(game, data))
	meters.set_budget(game.get("budget"))
	day_bar.set_day(game.day, State.day_theme(game.day))
	map_view.set_day_tint(game.day)
	day_bar.set_pricing(State.pricing_for_day(game, game.day))
	map_view.refresh_badges(game.get("purchases", {}))
	map_view.update_purchases(game.get("purchases", {}))
	map_view.update_shuttles(game.get("shuttles", []))
	map_view.rebuild_layers(data, game)
	# Resolve each decision's origin ONCE — the old inner find_entity per
	# marker × decision made refresh O(records × decisions × records) (~50 ms).
	var origins: Array = []
	for decision: Dictionary in game.decisions:
		var origin := State.find_entity(data, decision.entity_id, decision.entity_type)
		if origin.has("lat") and origin.has("lon"):  # the festival pricing entity has no position
			origins.append(origin)
	for kind: String in ["venue", "tree", "fountain", "toilet", "street"]:
		for record: Dictionary in data.get(kind + "s", []):
			var status := "neutral"
			if _resolved.has(kind + ":" + str(record.id)):
				status = "resolved"
			else:
				for origin: Dictionary in origins:
					if State._distance_m(record.lat, record.lon, origin.lat, origin.lon) <= State.CONFIG.walk_radius:
						status = "affected"
						break
			map_view.set_entity_state(str(record.id), status)


func _key(entity: Dictionary) -> String:
	return str(entity.get("type", "")) + ":" + str(entity.get("id", ""))


func _show_verdict() -> void:
	var results := State.compute_meters(game, data)
	verdict = ColorRect.new()
	verdict.name = "Verdict"
	verdict.color = Color(0.95, 0.97, 0.96, 0.98)
	add_child(verdict)
	verdict.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	verdict.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 440
	rows.add_theme_constant_override("separation", 24)
	center.add_child(rows)
	var heading := Label.new()
	heading.text = "Drei Tage Linz"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	rows.add_child(heading)
	var score := Label.new()
	var avg := (float(results.attendance) + float(results.money) + float(results.happiness)) / 3.0
	score.text = "Gesamtnote: %d / 100" % int(round(avg))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 46)
	score.add_theme_color_override("font_color", Color("238573"))
	rows.add_child(score)
	var build := Label.new()
	build.text = "v" + VERSION
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", Color("9a9187"))
	rows.add_child(build)
	var title := Label.new()
	title.text = verdict_title(results)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	var final_meters = MetersScene.instantiate()
	rows.add_child(final_meters)
	final_meters.set_meters(results)
	var budget := Label.new()
	budget.text = "%d Entscheidungen  /  Restbudget: %d EUR" % [game.decisions.size(), roundi(game.budget)]
	budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(budget)
	var restart := Button.new()
	restart.text = "Neues Festival"
	restart.custom_minimum_size.y = 44
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	rows.add_child(restart)
	restart.grab_focus()


## Tier logic lives in GameState.verdict_title (tested there).
static func verdict_title(m: Dictionary) -> String:
	return State.verdict_title(m)
