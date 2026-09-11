extends Control

signal message_submitted(text: String)
signal decision_selected(id: String)

var entity := {}
var _busy := false
var _resolved := false


func _ready() -> void:
	$Rows.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = $Rows.get_combined_minimum_size().y)
	$Rows/Composer/Send.pressed.connect(_submit)
	$Rows/Composer/Input.text_submitted.connect(func(_text: String) -> void: _submit())
	$Rows/Composer/Send.text = "\u2191"
	$Rows/Composer/Send.tooltip_text = "Nachricht senden"
	set_busy(false)


func open_entity(value: Dictionary, decisions: Array) -> void:
	entity = value
	_resolved = false
	$Rows/Title.text = str(entity.get("name", entity.get("species", "Stadtort")))
	$Rows/Composer/Input.clear()
	for child in $Rows/Messages/History.get_children():
		child.free()
	for child in $Rows/Decisions.get_children():
		child.free()
	for decision: Dictionary in decisions:
		var button := Button.new()
		button.text = "%s  /  %s EUR" % [decision.label, int(decision.cost)]
		button.custom_minimum_size.y = 36
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: decision_selected.emit(str(decision.id)))
		$Rows/Decisions.add_child(button)
	set_status("")
	set_busy(false)


func add_message(speaker: String, text: String) -> void:
	if text.is_empty():
		return
	var message := RichTextLabel.new()
	message.bbcode_enabled = false
	message.fit_content = true
	message.scroll_active = false
	message.selection_enabled = true
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = SIZE_EXPAND_FILL
	message.text = speaker + "\n" + text
	message.add_theme_color_override("default_color", Color("42685f") if speaker == "Du" else Color("263b35"))
	$Rows/Messages/History.add_child(message)
	_scroll_bottom.call_deferred()


func set_busy(value: bool) -> void:
	_busy = value
	$Rows/Typing.text = "Antwort kommt ..." if value else ""
	$Rows/Composer/Input.editable = not value and not entity.is_empty() and not _resolved
	$Rows/Composer/Send.disabled = value or entity.is_empty() or _resolved
	for button: Button in $Rows/Decisions.get_children():
		button.disabled = _resolved


func set_resolved(value: bool) -> void:
	_resolved = value
	set_busy(_busy)


func set_status(text: String) -> void:
	$Rows/Status.text = text


func _submit() -> void:
	var text: String = $Rows/Composer/Input.text.strip_edges()
	if _busy or _resolved or entity.is_empty() or text.is_empty():
		return
	$Rows/Composer/Input.clear()
	message_submitted.emit(text)


func _scroll_bottom() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		$Rows/Messages.scroll_vertical = int($Rows/Messages.get_v_scroll_bar().max_value)
