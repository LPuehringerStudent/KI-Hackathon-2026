extends Control

signal advance_requested
signal pricing_selected(id: String)

## [decision id, button label] — ids match GameState.DECISIONS.festival.
const PRICING_OPTIONS := [["fair", "Faire Preise"], ["standard", "Standard"], ["premium", "Premium"]]

var day := 1
var pricing_buttons := {}


func _ready() -> void:
	$Rows/Next.pressed.connect(func() -> void: advance_requested.emit())
	$Rows.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = $Rows.get_combined_minimum_size().y)
	var label := Label.new()
	label.name = "PricingLabel"
	label.text = "Ticketpreise heute"
	label.add_theme_font_size_override("font_size", 13)
	$Rows.add_child(label)
	var row := HBoxContainer.new()
	row.name = "Pricing"
	for option: Array in PRICING_OPTIONS:
		var button := Button.new()
		button.text = option[1]
		button.toggle_mode = true
		button.custom_minimum_size.y = 32
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: pricing_selected.emit(option[0]))
		row.add_child(button)
		pricing_buttons[option[0]] = button
	$Rows.add_child(row)
	$Rows.move_child(label, $Rows/Next.get_index())
	$Rows.move_child(row, $Rows/Next.get_index())
	set_pricing("standard")


func set_day(value: int, theme_data: Dictionary) -> void:
	day = value
	$Rows/Title.text = str(theme_data.get("title", ""))
	$Rows/Focus.text = str(theme_data.get("focus", ""))
	$Rows/Hint.text = str(theme_data.get("hint", ""))
	$Rows/Next.text = "Abschluss" if day == 3 else "N\u00e4chster Tag  \u2192"


## Highlights the pricing in effect today without emitting pricing_selected.
func set_pricing(id: String) -> void:
	for key: String in pricing_buttons:
		pricing_buttons[key].set_pressed_no_signal(key == id)


func set_enabled(enabled: bool) -> void:
	$Rows/Next.disabled = not enabled
	for button: Button in pricing_buttons.values():
		button.disabled = not enabled
