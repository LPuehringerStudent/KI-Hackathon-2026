extends Control

const LABELS := {"attendance": "Besucher:innen", "money": "Geld", "happiness": "Zufriedenheit"}
const COLORS := {"attendance": Color("cb5755"), "money": Color("a87821"), "happiness": Color("238573")}
var bars := {}
var values := {}


func _ready() -> void:
	for key: String in LABELS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		$Rows.add_child(row)
		var heading := HBoxContainer.new()
		row.add_child(heading)
		var label := Label.new()
		label.text = LABELS[key]
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		heading.add_child(label)
		var value := Label.new()
		value.custom_minimum_size.x = 56
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		heading.add_child(value)
		values[key] = value
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 8
		bar.show_percentage = false
		bar.max_value = 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLORS[key]
		bar.add_theme_stylebox_override("fill", fill)
		var background := StyleBoxFlat.new()
		background.bg_color = Color("dce3df")
		bar.add_theme_stylebox_override("background", background)
		row.add_child(bar)
		bars[key] = bar
	set_meters({})


func set_meters(m: Dictionary) -> void:
	for key: String in bars:
		var value := clampf(float(m.get(key, 0.0)), 0.0, 100.0)
		bars[key].value = value
		values[key].text = "%d / 100" % roundi(value)
