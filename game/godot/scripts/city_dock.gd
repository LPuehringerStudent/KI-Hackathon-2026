extends Control

const UITheme := preload("res://scripts/ui_theme.gd")
var sidebar: ScrollContainer
var drawer: Panel
var rail: PanelContainer
var pages := {}
var buttons := {}
var active_page := ""
var motion: Tween
var heading: Label
var close_button: Button
var map: Control


func setup(scroll: ScrollContainer, meters: Control, day: Control, chat: Control, city: Control) -> void:
	name = "CityDock"
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map = city
	map.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for tool: Control in map._map_tools:
		tool.hide()
	pages = {"stats": meters, "day": day, "chat": chat}
	drawer = Panel.new()
	drawer.name = "Drawer"
	drawer.clip_contents = true
	var surface := UITheme.surface(Color("f5faf7"), Color("d8e6df"), 0)
	surface.set_corner_radius_all(22)
	surface.shadow_color = Color(0.06, 0.19, 0.15, 0.14)
	surface.shadow_size = 14
	drawer.add_theme_stylebox_override("panel", surface)
	add_child(drawer)
	sidebar = scroll
	sidebar.reparent(drawer)
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sidebar.offset_left = 20
	sidebar.offset_top = 66
	sidebar.offset_right = -20
	sidebar.offset_bottom = -20
	heading = Label.new()
	heading.position = Vector2(22, 22)
	heading.add_theme_font_size_override("font_size", 18)
	drawer.add_child(heading)
	close_button = _button("x", "Schliessen", close)
	drawer.add_child(close_button)
	rail = PanelContainer.new()
	rail.name = "IconRail"
	var rail_style := UITheme.surface(Color("ffffff"), Color("d8e6df"), 8)
	rail_style.set_corner_radius_all(25)
	rail_style.shadow_color = Color(0.06, 0.19, 0.15, 0.14)
	rail_style.shadow_size = 12
	rail.add_theme_stylebox_override("panel", rail_style)
	add_child(rail)
	var rail_scroll := ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail.add_child(rail_scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	rail_scroll.add_child(column)
	for spec in [["stats", "chart-no-axes-combined", "Stadtwerte"], ["day", "calendar-days", "Festival"], ["chat", "messages-square", "Stadtgespraech"]]:
		var key: String = spec[0]
		var button := _button(spec[1], spec[2], func() -> void: open_page(key, true))
		button.toggle_mode = true
		buttons[key] = button
		column.add_child(button)
	column.add_child(HSeparator.new())
	var layers := ButtonGroup.new()
	for spec in [["stadt", "map", "Stadt"], ["sicherheit", "shield-check", "Sicherheit"], ["luft", "wind", "Luft"], ["versorgung", "utensils", "Versorgung"]]:
		var mode: String = spec[0]
		var button := _button(spec[1], spec[2], func() -> void: map.set_layer_mode(mode))
		button.toggle_mode = true
		button.button_group = layers
		button.button_pressed = mode == "stadt"
		column.add_child(button)
	column.add_child(HSeparator.new())
	column.add_child(_button("plus", "Vergroessern", map.zoom_in))
	column.add_child(_button("minus", "Verkleinern", map.zoom_out))
	resized.connect(_layout)
	drawer.hide()
	_layout()
	_layout.call_deferred()


func _button(icon_name: String, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = icon_name.to_pascal_case()
	button.icon = load("res://assets/icons/" + icon_name + ".svg")
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	button.custom_minimum_size = Vector2(44, 44)
	button.tooltip_text = label
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var color := Color("ffffff")
		if state == "hover":
			color = Color("e5f2ec")
		elif state == "pressed" or state == "hover_pressed":
			color = Color("bfe3d2")
		var style := UITheme.surface(color, color, 10)
		style.set_corner_radius_all(15)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button


func _layout() -> void:
	if rail == null:
		return
	if motion != null and motion.is_running():
		motion.kill()
	rail.position = Vector2(16, maxf(16, (size.y - 482) / 2.0))
	rail.size = Vector2(62, minf(482, size.y - 32))
	var height: float = {"stats": 210.0, "day": 320.0}.get(active_page, size.y - 32)
	drawer.size = Vector2(minf(440, maxf(250, size.x - 112)), minf(height, size.y - 32))
	drawer.position = Vector2(94, 16)
	drawer.modulate.a = 1.0
	drawer.visible = not active_page.is_empty()
	close_button.position = Vector2(drawer.size.x - 54, 10)
	close_button.size = Vector2(36, 36)


func open_page(key: String, toggle := false) -> void:
	if not pages.has(key):
		return
	if active_page == key and toggle:
		close()
		return
	var was_open := drawer.visible
	active_page = key
	_layout()
	map.set_meta("focus_left_inset", drawer.size.x + 94)
	for page: String in pages:
		pages[page].visible = page == key
		buttons[page].set_pressed_no_signal(page == key)
	heading.text = {"stats": "Stadtwerte", "day": "Festival", "chat": "Stadtgespraech"}[key]
	sidebar.scroll_vertical = 0
	if motion != null:
		motion.kill()
	drawer.show()
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	if not was_open:
		drawer.position.x = 70
		drawer.modulate.a = 0
	motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(drawer, "position:x", 94.0, 0.26)
	motion.tween_property(drawer, "modulate:a", 1.0, 0.20)


func close() -> void:
	active_page = ""
	map.set_meta("focus_left_inset", 0.0)
	for button: Button in buttons.values():
		button.set_pressed_no_signal(false)
	if motion != null:
		motion.kill()
	buttons.chat.grab_focus()
	motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_property(drawer, "position:x", 70.0, 0.20)
	motion.tween_property(drawer, "modulate:a", 0.0, 0.16)
	motion.chain().tween_callback(drawer.hide)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not active_page.is_empty():
		close()
		get_viewport().set_input_as_handled()
