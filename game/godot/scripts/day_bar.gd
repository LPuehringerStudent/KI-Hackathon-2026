extends Control

signal advance_requested

var day := 1


func _ready() -> void:
	$Rows/Next.pressed.connect(func() -> void: advance_requested.emit())
	$Rows.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = $Rows.get_combined_minimum_size().y)


func set_day(value: int, theme_data: Dictionary) -> void:
	day = value
	$Rows/Title.text = str(theme_data.get("title", ""))
	$Rows/Focus.text = str(theme_data.get("focus", ""))
	$Rows/Hint.text = str(theme_data.get("hint", ""))
	$Rows/Next.text = "Abschluss" if day == 3 else "N\u00e4chster Tag  \u2192"


func set_enabled(enabled: bool) -> void:
	$Rows/Next.disabled = not enabled
