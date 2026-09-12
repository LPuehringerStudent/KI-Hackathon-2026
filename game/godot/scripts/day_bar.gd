extends Control

signal advance_requested
signal pricing_selected(id: String)

## [decision id, button label] — ids match GameState.DECISIONS.festival.
const PRICING_OPTIONS := [["fair", "Faire Preise"], ["standard", "Standard"], ["premium", "Premium"]]

var day := 1
var pricing_buttons := {}
var petition_label: Label


func _ready() -> void:
	$Rows/Next.theme_type_variation = "PrimaryButton"
	$Rows/Next.pressed.connect(func() -> void: advance_requested.emit())
	$Rows.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = $Rows.get_combined_minimum_size().y)
	petition_label = Label.new()
	petition_label.name = "Petition"
	petition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	petition_label.add_theme_font_size_override("font_size", 13)
	$Rows.add_child(petition_label)
	$Rows.move_child(petition_label, $Rows/Next.get_index())
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


## The day's Bürgeranliegen, "○" while open and "✓" once fulfilled; {} hides the line.
func set_petition(petition: Dictionary) -> void:
	if petition.is_empty():
		petition_label.text = ""
		return
	var fulfilled: bool = petition.get("fulfilled", false)
	petition_label.text = "%s Anliegen: %s  (%s)" % ["✓" if fulfilled else "○", petition.get("title", ""), petition.get("ask", "")]
	petition_label.add_theme_color_override("font_color", Color("238573") if fulfilled else Color("6b6257"))


## Highlights the pricing in effect today without emitting pricing_selected.
func set_pricing(id: String) -> void:
	for key: String in pricing_buttons:
		pricing_buttons[key].set_pressed_no_signal(key == id)


func set_enabled(enabled: bool) -> void:
	$Rows/Next.disabled = not enabled
	for button: Button in pricing_buttons.values():
		button.disabled = not enabled
