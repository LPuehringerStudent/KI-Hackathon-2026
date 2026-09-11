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
	$Rows/Composer/Send.text = "Senden"
	$Rows/Composer/Send.tooltip_text = "Nachricht senden"
	# decisions live in a height-capped ScrollContainer so the composer never
	# gets pushed off-screen on entities with many options
	var decisions_box: VBoxContainer = $Rows/Decisions
	$Rows.remove_child(decisions_box)
	var scroll := ScrollContainer.new()
	scroll.name = "DecisionsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(decisions_box)
	$Rows.add_child(scroll)
	$Rows.move_child(scroll, 4)  # where Decisions sat: after Typing
	# header row: title only (no icon — read as an emoji in playtests)
	var title: Label = $Rows/Title
	$Rows.remove_child(title)
	var header := HBoxContainer.new()
	header.name = "Header"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # tscn flag was FILL-only
	header.add_child(title)
	$Rows.add_child(header)
	$Rows.move_child(header, 0)
	set_busy(false)


func open_entity(value: Dictionary, decisions: Array) -> void:
	entity = value
	_resolved = false
	$Rows/Header/Title.text = str(entity.get("name", entity.get("species", "Stadtort")))
	$Rows/Composer/Input.clear()
	for child in $Rows/Messages/History.get_children():
		child.free()
	set_decisions(decisions)
	set_status("")
	set_busy(false)


## Rebuilds the decision chips without touching the conversation. A decision's optional "preview"
## (GameState.preview_text, e.g. "≈ +2.4 Zuf · −800 €") follows the label on the chip.
func set_decisions(decisions: Array) -> void:
	for child in $Rows/DecisionsScroll/Decisions.get_children():
		child.free()
	for decision: Dictionary in decisions:
		var button := Button.new()
		var preview := str(decision.get("preview", ""))
		button.text = "%s   %s" % [decision.label, preview] if not preview.is_empty() else "%s  /  %s EUR" % [decision.label, int(decision.cost)]
		button.custom_minimum_size.y = 34
		button.add_theme_font_size_override("font_size", 14)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = _resolved
		button.pressed.connect(func() -> void: decision_selected.emit(str(decision.id)))
		$Rows/DecisionsScroll/Decisions.add_child(button)
	# cap the visible chip area (5 chips ≈ 250 px); scrolls inside beyond that
	$Rows/DecisionsScroll.custom_minimum_size.y = minf(
		$Rows/DecisionsScroll/Decisions.get_combined_minimum_size().y, 250.0)


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
	for button: Button in $Rows/DecisionsScroll/Decisions.get_children():
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
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		$Rows/Messages.scroll_vertical = int($Rows/Messages.get_v_scroll_bar().max_value)
