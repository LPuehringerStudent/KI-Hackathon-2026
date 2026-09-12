extends RefCounted


static func surface(color: Color, border: Color, padding := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for kind in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", kind, Color("213d39"))
	theme.set_color("font_hover_color", "Button", Color("253b33"))
	theme.set_color("font_pressed_color", "Button", Color("253b33"))
	theme.set_color("font_focus_color", "Button", Color("253b33"))
	theme.set_color("font_hover_pressed_color", "Button", Color("253b33"))
	theme.set_color("font_disabled_color", "Button", Color("7e8a84"))
	theme.set_color("font_uneditable_color", "LineEdit", Color("7e8a84"))
	theme.set_color("caret_color", "LineEdit", Color("238573"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("77877e"))
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
			style.set_corner_radius_all(6)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			theme.set_stylebox(state, kind, style)
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = Color("238573")
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(6)
		theme.set_stylebox("focus", kind, focus)
	theme.set_type_variation("PrimaryButton", "Button")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var color := Color("17856e") if state == "normal" else Color("106b5a")
		theme.set_stylebox(state, "PrimaryButton", surface(color, color, 18))
		var font_key: String = "font_color" if state == "normal" else "font_" + state + "_color"
		theme.set_color(font_key, "PrimaryButton", Color.WHITE)
	theme.set_color("font_focus_color", "PrimaryButton", Color.WHITE)
	theme.set_stylebox("panel", "Panel", surface(Color("ffffff"), Color("d2e0da"), 0))
	theme.set_stylebox("panel", "PanelContainer", surface(Color("ffffff"), Color("d2e0da"), 0))
	theme.set_stylebox("panel", "TooltipPanel", surface(Color("203e39"), Color("203e39")))
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
