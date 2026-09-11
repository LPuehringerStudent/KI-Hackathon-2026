extends RefCounted


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for kind in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", kind, Color("253b33"))
	theme.set_color("font_hover_color", "Button", Color("253b33"))
	theme.set_color("font_pressed_color", "Button", Color("253b33"))
	theme.set_color("font_disabled_color", "Button", Color("7e8a84"))
	theme.set_color("font_uneditable_color", "LineEdit", Color("7e8a84"))
	theme.set_color("caret_color", "LineEdit", Color("238573"))
	for kind in ["Button", "LineEdit"]:
		for state in ["normal", "hover", "pressed", "disabled", "read_only"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("e4eee8") if state == "hover" else Color("ffffff")
			if state == "pressed":
				style.bg_color = Color("c8dfd1")
			if state == "disabled" or state == "read_only":
				style.bg_color = Color("ecf0ed")
			style.border_color = Color("c7d3cb")
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			theme.set_stylebox(state, kind, style)
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = Color("238573")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(4)
		theme.set_stylebox("focus", kind, focus)
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	return theme
