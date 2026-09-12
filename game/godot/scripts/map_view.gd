class_name MapView
extends PanelContainer
## Interactive map: baked isometric 2.5D Innenstadt PNG with clickable entity
## markers. Track A owns this file; main.tscn integration is Track C's job.
## The lat/lon->pixel transform mirrors tools/render_map.py (iso30) via
## map_meta.json format_version 2.

signal entity_clicked(id: String, type: String)
signal bulk_action_requested(action_id: String)

const State := preload("res://scripts/game_state.gd")
const META_PATH := "res://data/map_meta.json"
const MAP_TEXTURE_PATH := "res://assets/innenstadt_map.png"
const MARKER_SIZE := 18
const TREE_MARKER_SIZE := 12  # smaller dots: baked sprite trees must stay visible

# marker colors tuned for the light iso map (darker cores, white ring drawn in
# _make_dot): venue red, tree green, fountain blue, toilet purple, street gray
const MARKER_COLORS := {
	"venue": Color("#d3362c"),
	"tree": Color("#2e7d32"),
	"fountain": Color("#1a6fc4"),
	"toilet": Color("#7b3fb3"),
	"street": Color("#5f6b78"),
}

const TRANSITION_NIGHT := Color(0.05, 0.09, 0.22, 0.78)
const TRANSITION_DUSK := Color(0.45, 0.30, 0.38, 0.45)
const TRANSITION_DAWN := Color(0.95, 0.82, 0.62, 0.35)

var markers := {}

var _meta := {}
var _scroll: ScrollContainer
var _map_root: Control
var _map_rect: TextureRect
var _dot_cache := {}
var _badges := {}
const LAYER_MODES := ["stadt", "sicherheit", "luft", "versorgung"]
const LAYER_LABELS := {"stadt": "Stadt", "sicherheit": "Sicherheit", "luft": "Luft", "versorgung": "Versorgung"}

var _shuttle_markers: Array = []
var _layer_mode := "stadt"
var _layer_rect: TextureRect = null
var _layer_readout: Label = null
var _layer_data := {}
var _layer_game := {}
var _selection := {}          # id -> dot, multi-select via Ctrl+click
var _selection_type := ""
var _bulk_bar: HBoxContainer = null
var _tip: Label = null
var _purchase_markers: Array = []
var _last_shuttles: Array = []
var _last_purchases: Dictionary = {}
var _planted_markers: Array = []
var _last_planted: Array = []
var _zoom := 1.0


func _ready() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	_scroll = $Scroll
	_map_root = $Scroll/MapRoot
	_map_rect = $Scroll/MapRoot/Map
	# ResourceLoader first: required for export builds (res:// PNGs are imported
	# at export time). ResourceLoader.exists() guards the headless `-s` case,
	# where load() on an unimported resource stalls instead of returning null.
	var tex: Texture2D = null
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		tex = load(MAP_TEXTURE_PATH)
	if tex == null:
		var img := Image.load_from_file(MAP_TEXTURE_PATH)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_error("map_view: cannot load " + MAP_TEXTURE_PATH)
	else:
		_map_rect.texture = tex
	_add_layer_controls()
	_add_zoom_controls()
	refresh()


## Zoom: 0.6x..3.0x via on-map buttons or Ctrl+wheel. Marker sprites keep a
## constant screen size; only their map positions scale. The visible center
## is preserved across zoom changes.
func set_zoom(z: float) -> void:
	set_zoom_at(z, null)


## Zoom keeping the given MAP point (4096-space) stationary; null keeps the
## view center (button zoom).
func set_zoom_at(z: float, anchor_map_px) -> void:
	if _meta.is_empty():
		return
	var old_zoom := _zoom
	_zoom = clampf(z, 0.3, 3.0)
	if is_equal_approx(old_zoom, _zoom):
		return
	var base := Vector2(float(_meta.width), float(_meta.height))
	var view := _scroll.size
	var anchor_view := Vector2(view.x / 2.0, view.y / 2.0)
	var anchor: Vector2
	if anchor_map_px == null:
		anchor = (Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical) + view / 2.0) / old_zoom
	else:
		anchor = anchor_map_px
		anchor_view = anchor * old_zoom - Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)
	_map_root.custom_minimum_size = base * _zoom
	_map_root.size = base * _zoom
	_relayout_markers()
	update_shuttles(_last_shuttles)
	update_purchases(_last_purchases)
	update_planted_trees(_last_planted)
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(anchor.x * _zoom - anchor_view.x)
	_scroll.scroll_vertical = int(anchor.y * _zoom - anchor_view.y)


func zoom_in() -> void:
	set_zoom(_zoom * 1.25)


func zoom_out() -> void:
	set_zoom(_zoom / 1.25)


## Ctrl+wheel: smooth zoom toward the cursor; plain wheel pans (ScrollContainer).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom_at(_zoom * 1.15, _event_to_map(event.position))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_at(_zoom / 1.15, _event_to_map(event.position))


func _event_to_map(view_pos: Vector2) -> Vector2:
	var local := _scroll.get_local_mouse_position()
	return (local + Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)) / _zoom


func _relayout_markers() -> void:
	for id: String in markers:
		var dot: Control = markers[id]
		var ll: Vector2 = dot.get_meta("latlon")
		var msize: float = dot.get_meta("msize")
		dot.position = latlon_to_pixel(ll.x, ll.y) * _zoom - Vector2(msize, msize) * _zoom / 2.0
		dot.scale = Vector2(_zoom, _zoom)


## ---- Map modes (HOI4-style layers) ------------------------------------
## Runtime-rendered heat overlays from live game state; v1: Sicherheit
## (coverage vs venue demand), Luft (PM10 modulated by nearby canopy),
## Versorgung (walk-radius bubbles of open services). Hover shows the value.

func set_layer_mode(mode: String) -> void:
	if not LAYER_MODES.has(mode):
		return
	_layer_mode = mode
	if _layer_rect != null:
		_layer_rect.visible = mode != "stadt"
		if _layer_readout != null:
			_layer_readout.visible = mode != "stadt"
	rebuild_layers(_layer_data, _layer_game)


func pixel_to_latlon(px: Vector2) -> Vector2:
	var scale := float(_meta.scale) * _zoom
	var sx := (px.x - float(_meta.offset_x) * _zoom) / scale
	var sy := (px.y - float(_meta.offset_y) * _zoom) / scale
	var gsum := sy / float(_meta.sin_a)   # gx + gy
	var gdiff := sx / float(_meta.cos_a)  # gx - gy
	var gx := (gsum + gdiff) / 2.0
	var gy := (gsum - gdiff) / 2.0
	var lon := gx / float(_meta.km_per_deg_lon) + float(_meta.lon_min)
	var lat := gy / float(_meta.km_per_deg_lat) + float(_meta.lat_min)
	return Vector2(lat, lon)


## Rebuilds the overlay for the active mode. Called from main.gd::_refresh
## and on mode switches; safe with empty data (hides the overlay).
func rebuild_layers(data: Dictionary, game: Dictionary) -> void:
	_layer_data = data
	_layer_game = game
	if _layer_rect == null or data.is_empty():
		return
	if _layer_mode == "stadt":
		_layer_rect.visible = false
		return
	var img := Image.create_empty(1024, 1024, false, Image.FORMAT_RGBA8)
	match _layer_mode:
		"sicherheit":
			_build_security_layer(img, data, game)
		"luft":
			_build_air_layer(img, data, game)
		"versorgung":
			_build_service_layer(img, data, game)
	_layer_rect.texture = ImageTexture.create_from_image(img)
	_layer_rect.visible = true


func _stamp(img: Image, center: Vector2, radius_px: float, color: Color, strength: float) -> void:
	var lut: Array[float] = []
	var r := int(radius_px)
	for i in range(r + 1):
		lut.append((1.0 - float(i) / max(1.0, radius_px)) * strength)
	var x0: int = max(0, int(center.x) - r)
	var x1: int = min(1023, int(center.x) + r)
	var y0: int = max(0, int(center.y) - r)
	var y1: int = min(1023, int(center.y) + r)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var d := Vector2(x, y).distance_to(center)
			if d > radius_px:
				continue
			var a := lut[int(d)]
			if a <= 0.0:
				continue
			var existing := img.get_pixel(x, y)
			if a > existing.a:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))


## half-res overlay position for a lat/lon
func _layer_px(lat: float, lon: float) -> Vector2:
	# overlay image is 1024² covering the (meta.width) map: quarter-res at 4096
	return latlon_to_pixel(lat, lon) * _zoom * (1024.0 / float(_meta.width))


func _purchases_at(game: Dictionary, venue_id: String) -> Dictionary:
	return game.get("purchases", {}).get(venue_id, {})


func _build_security_layer(img: Image, data: Dictionary, game: Dictionary) -> void:
	for venue: Dictionary in data.get("venues", []):
		var demand: int = maxi(1, int(round(float(venue.get("event_weight", 5)) / 8.0)))
		var units := int(_purchases_at(game, str(venue.id)).get("security", 0))
		var coverage := clampf(float(units) / float(demand), 0.0, 1.0)
		var color := Color("#e5484d").lerp(Color("#46a758"), coverage)
		_stamp(img, _layer_px(float(venue.lat), float(venue.lon)), 46.0, color, 0.55)


func _build_air_layer(img: Image, data: Dictionary, game: Dictionary) -> void:
	var pm10 := float(data.get("airquality", {}).get("pm10", 20.0))
	var base := clampf((pm10 - 10.0) / 50.0, 0.0, 1.0)  # 10..60 ug/m3 -> 0..1
	var good := Color("#3e8fde")
	var bad := Color("#e58e3f")
	for tree: Dictionary in data.get("trees", []):
		if str(_layer_game.get("latest", {})) == "cut":
			continue
		_stamp(img, _layer_px(float(tree.lat), float(tree.lon)), 14.0, good, 0.30 * (1.0 - base))
	var city_color: Color = good.lerp(bad, base)
	_stamp(img, Vector2(512, 512), 500.0, city_color, 0.22)


func _build_service_layer(img: Image, data: Dictionary, game: Dictionary) -> void:
	var closed := {}
	for decision: Dictionary in game.get("decisions", []):
		if decision.decision_id == "close":
			closed[str(decision.entity_id)] = true
		elif decision.decision_id in ["keep", "reopen"]:
			closed.erase(str(decision.entity_id))
	for key: String in ["fountains", "toilets"]:
		for service: Dictionary in data.get(key, []):
			if closed.has(str(service.id)):
				continue
			_stamp(img, _layer_px(float(service.lat), float(service.lon)), 38.0, Color("#2e9e6b"), 0.5)


func _layer_value_at(lat: float, lon: float) -> String:
	var data := _layer_data
	var game := _layer_game
	match _layer_mode:
		"sicherheit":
			var best := ""
			var best_d := 1e9
			for venue: Dictionary in data.get("venues", []):
				var d := _dist_m(lat, lon, float(venue.lat), float(venue.lon))
				if d < best_d:
					best_d = d
					var demand: int = maxi(1, int(round(float(venue.get("event_weight", 5)) / 8.0)))
					var units := int(_purchases_at(game, str(venue.id)).get("security", 0))
					best = "%s: Sicherheit %d%% (%d/%d Einheiten)" % [venue.name, int(100.0 * units / demand), units, demand]
			return best if best_d <= 250.0 else "kein Handlungsort in der Nähe"
		"luft":
			var pm := float(data.get("airquality", {}).get("pm10", -1.0))
			if pm < 0.0:
				return "keine Luftdaten"
			var trees := 0
			for tree: Dictionary in data.get("trees", []):
				if _dist_m(lat, lon, float(tree.lat), float(tree.lon)) <= 100.0:
					trees += 1
			return "PM10 %.1f µg/m³ — %d Bäume im 100-m-Radius" % [pm, trees]
		"versorgung":
			var nearest := 1e9
			for key: String in ["fountains", "toilets"]:
				for service: Dictionary in data.get(key, []):
					nearest = min(nearest, _dist_m(lat, lon, float(service.lat), float(service.lon)))
			if nearest <= 300.0:
				return "versorgt (nächste Anlage %d m)" % int(nearest)
			return "keine Versorgung im Umkreis (nächste %d m)" % int(nearest)
	return ""


static func _dist_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var d_lat := deg_to_rad(lat2 - lat1)
	var d_lon := deg_to_rad(lon2 - lon1)
	var a := sin(d_lat / 2.0) ** 2 + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(d_lon / 2.0) ** 2
	return 2.0 * 6371000.0 * asin(minf(1.0, sqrt(a)))


var _dragging := false


func _on_layer_hover(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _scroll != null:
			_scroll.gui.release_focus()
	if event is InputEventMouseMotion:
		_hide_tip()  # any motion over empty map dismisses a stuck marker bubble
		if _dragging:
			_scroll.scroll_horizontal -= int(event.relative.x)
			_scroll.scroll_vertical -= int(event.relative.y)
		if _layer_readout != null:
			var latlon := pixel_to_latlon(event.position)
			_layer_readout.text = _layer_value_at(latlon.x, latlon.y)


func _add_layer_controls() -> void:
	if _map_root == null:
		return
	_layer_rect = TextureRect.new()
	_layer_rect.name = "LayerOverlay"
	_layer_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_layer_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_layer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_rect.visible = false
	_map_root.add_child(_layer_rect)
	_layer_rect.move_to_front()
	# interactivity: an invisible full-rect control above the map, below markers
	var probe := Control.new()
	probe.set_anchors_preset(Control.PRESET_FULL_RECT)
	probe.mouse_filter = Control.MOUSE_FILTER_PASS
	probe.mouse_exited.connect(func() -> void:
		if _layer_readout != null:
			_layer_readout.text = "")
	_map_root.add_child(probe)
	probe.move_to_front()
	probe.gui_input.connect(_on_layer_hover)
	_layer_readout = Label.new()
	_layer_readout.position = Vector2(8, 8)
	_layer_readout.add_theme_font_size_override("font_size", 12)
	_layer_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	probe.add_child(_layer_readout)


func _add_zoom_controls() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-46, 8)
	box.add_theme_constant_override("separation", 4)
	overlay.add_child(box)
	for spec in [["+", "zoom_in"], ["−", "zoom_out"]]:
		var btn := Button.new()
		btn.text = spec[0]
		btn.tooltip_text = "Zoom (Strg+Mausrad)"
		btn.custom_minimum_size = Vector2(38, 32)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(Callable(self, spec[1]))
		box.add_child(btn)
	_tip = Label.new()
	_tip.add_theme_font_size_override("font_size", 11)
	_tip.add_theme_color_override("font_color", Color.WHITE)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(240, 0)  # cap width; wraps instead
	var tip_bg := StyleBoxFlat.new()
	tip_bg.bg_color = Color(0.13, 0.15, 0.19, 0.92)
	tip_bg.set_corner_radius_all(4)
	tip_bg.content_margin_left = 6.0
	tip_bg.content_margin_right = 6.0
	tip_bg.content_margin_top = 4.0
	tip_bg.content_margin_bottom = 4.0
	_tip.add_theme_stylebox_override("normal", tip_bg)
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_tip)  # plain Control: manual size/position survive
	var layers := HBoxContainer.new()
	layers.set_anchors_preset(Control.PRESET_TOP_LEFT)
	layers.position = Vector2(8, 8)
	layers.add_theme_constant_override("separation", 4)
	overlay.add_child(layers)
	_bulk_bar = HBoxContainer.new()
	_bulk_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bulk_bar.position = Vector2(8, -40)
	_bulk_bar.add_theme_constant_override("separation", 6)
	_bulk_bar.visible = false
	overlay.add_child(_bulk_bar)
	var group := ButtonGroup.new()
	for mode: String in LAYER_MODES:
		var btn := Button.new()
		btn.text = LAYER_LABELS[mode]
		btn.name = "Layer_" + mode
		btn.toggle_mode = true
		btn.button_group = group  # exclusive: a filter is always accounted for
		btn.button_pressed = mode == _layer_mode
		btn.custom_minimum_size = Vector2(0, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				set_layer_mode(mode))
		layers.add_child(btn)


## (Re)build all markers from the loaded data.
func refresh() -> void:
	var data := _load_game_data()
	if data.is_empty():
		push_error("map_view: no data loaded")
		return
	for key: String in ["venues", "trees", "fountains", "toilets", "streets"]:
		var entity_type: String = key.trim_suffix("s")
		for entity: Dictionary in data[key]:
			_add_marker(entity, entity_type)


## Resolve the Data autoload via the scene tree (works in headless -s mode
## where autoloads are not available as compile-time identifiers).
func _load_game_data() -> Dictionary:
	var node := get_node_or_null("/root/Data")
	if node == null:
		push_error("map_view: Data autoload not found")
		return {}
	return node.load_all()


## WGS84 -> pixel coords. Mirrors tools/render_map.py iso30 projection:
## gx/gy in km from the west/south edges, then the 30-degree iso transform.
## Constants come from map_meta.json (single source of truth).
func latlon_to_pixel(lat: float, lon: float) -> Vector2:
	var gx := (lon - float(_meta.lon_min)) * float(_meta.km_per_deg_lon)
	var gy := (lat - float(_meta.lat_min)) * float(_meta.km_per_deg_lat)
	var scale := float(_meta.scale)
	var sx := (gx - gy) * float(_meta.cos_a) * scale + float(_meta.offset_x)
	var sy := (gx + gy) * float(_meta.sin_a) * scale + float(_meta.offset_y)
	return Vector2(sx, sy)


## Gameplay lighting stays constant by design (playtest feedback): no
## per-day tint jumps. Day changes are signalled by play_day_transition()
## instead. Kept as an API no-op so main.gd's refresh contract is unchanged.
func set_day_tint(_day: int) -> void:
	if _map_rect != null:
		_map_rect.modulate = Color.WHITE


var transition_busy := false


## Day/night cycle interlude played when "Nächster Tag" is pressed: dusk ->
## night -> dawn -> day. Await it; callers advance the game state after it
## returns. Input stays live, but re-entries are ignored while playing.
## Synchronous: drives a scene-tree tween and invokes on_finished when the
## cycle ends. No coroutines anywhere — safe from fire-and-forget GC and from
## Godot 4.7's "async functions must be awaited" runtime check (signals and
## tests call this directly).
func play_day_transition(speed := 1.0, on_finished := Callable()) -> void:
	if transition_busy:
		return
	transition_busy = true
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var tween := overlay.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(overlay, "color", TRANSITION_DUSK, 0.7 / speed)
	tween.tween_property(overlay, "color", TRANSITION_NIGHT, 0.7 / speed)
	tween.tween_interval(0.45 / speed)  # hold the night
	tween.tween_property(overlay, "color", TRANSITION_DAWN, 0.6 / speed)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.6 / speed)
	tween.finished.connect(func() -> void:
		overlay.queue_free()
		transition_busy = false
		if on_finished.is_valid():
			on_finished.call()
	)


## Astra's prop sprites as marker art where they exist (crisp at any zoom);
## tree variant by id hash. Returns null where only the dot fallback fits.
func _marker_texture(entity_type: String, id: String) -> Texture2D:
	match entity_type:
		"tree":
			var variants := ["prop_tree_broad_a", "prop_tree_broad_b", "prop_tree_broad_c", "prop_tree_conifer"]
			return _load_sprite(variants[abs(hash(id)) % variants.size()])
		"fountain":
			return _load_sprite("prop_fountain")
		"toilet":
			return _load_sprite("prop_toilet")
	return null


func _add_marker(entity: Dictionary, entity_type: String) -> void:
	var id := str(entity.id)
	if markers.has(id):
		return
	var dot := TextureButton.new()
	var tex: Texture2D = _marker_texture(entity_type, id)
	var marker_size: float
	if tex != null:
		dot.texture_normal = tex
		marker_size = tex.get_width()
	else:
		marker_size = TREE_MARKER_SIZE if entity_type == "tree" else MARKER_SIZE
		dot.texture_normal = _make_dot(MARKER_COLORS[entity_type], int(marker_size))
	var display_name := str(entity.get("name", ""))
	if display_name.is_empty() or display_name == id:
		display_name = str(entity.get("species", entity_type.capitalize()))
	dot.set_meta("ename", display_name)
	dot.set_meta("latlon", Vector2(float(entity.lat), float(entity.lon)))
	dot.set_meta("msize", marker_size)
	dot.set_meta("etype", entity_type)
	dot.scale = Vector2(_zoom, _zoom)
	dot.position = latlon_to_pixel(float(entity.lat), float(entity.lon)) * _zoom - Vector2(marker_size, marker_size) * _zoom / 2.0
	dot.pressed.connect(func() -> void: _on_marker_pressed(id, entity_type, dot))
	dot.mouse_entered.connect(func() -> void:
		_hover(dot, true)
		_show_tip(dot))
	dot.mouse_exited.connect(func() -> void:
		_hover(dot, false)
		_hide_tip())
	# PASS: clicks still fire, but motion propagates to the layer probe behind
	# (native tooltips were too flaky — the custom tip replaces them)
	dot.mouse_filter = Control.MOUSE_FILTER_PASS
	dot.set_meta("info", _info_line(entity, entity_type))
	_map_root.add_child(dot)
	markers[id] = dot
	_pop_in(dot)
	if entity_type == "venue":
		_add_pulse_ring(dot)


## One-line fact per entity type for the hover tip.
func _info_line(entity: Dictionary, entity_type: String) -> String:
	match entity_type:
		"venue":
			return "%d Veranstaltungen im Programm" % int(entity.get("events", 0))
		"tree":
			var age: Variant = entity.get("age_estimate")
			return "%s%s" % [entity.get("species", "Baum"),
				" · ca. %d Jahre" % int(age) if age != null else ""]
		"fountain":
			return "Trinkbrunnen"
		"toilet":
			return "Öffentliche Toilette"
		"street":
			return "Straße mit Geschichte"
	return ""


## Immediate custom tooltip following the cursor (native tooltips were
## unreliable: stillness-gated, and markers blocked them in layer modes).
func _show_tip(dot: TextureButton) -> void:
	if _tip == null:
		return
	var text := str(dot.get_meta("ename", ""))
	var info := str(dot.get_meta("info", ""))
	if not info.is_empty():
		text += "\n" + info
	if _layer_mode != "stadt":
		var ll: Vector2 = dot.get_meta("latlon")
		var layer_value := _layer_value_at(ll.x, ll.y)
		if not layer_value.is_empty():
			text += "\n" + layer_value
	_tip.text = text
	_tip.visible = true
	_position_tip()


func _hide_tip() -> void:
	if _tip != null:
		_tip.visible = false


func _process(_delta: float) -> void:
	if _tip != null and _tip.visible:
		_position_tip()


func _position_tip() -> void:
	var p := get_global_mouse_position() - global_position + Vector2(16, 18)
	p.x = minf(p.x, size.x - _tip.size.x - 8.0)
	p.y = minf(p.y, size.y - _tip.size.y - 8.0)
	_tip.position = p


## Ctrl+click toggles an entity in the multi-selection; plain click selects
## single (and clears the multi-selection).
func _on_marker_pressed(id: String, entity_type: String, dot: TextureButton) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		if _selection.has(id):
			_selection.erase(id)
			dot.modulate = Color.WHITE
			if _selection.is_empty():
				_selection_type = ""
		else:
			if _selection.is_empty():
				_selection_type = entity_type
			if entity_type == _selection_type:
				_selection[id] = dot
				dot.modulate = Color(1.0, 0.62, 0.2)
		_update_bulk_bar()
	else:
		clear_selection()
		entity_clicked.emit(id, entity_type)


func get_selection_ids() -> Array:
	return _selection.keys()


func selection_type() -> String:
	return _selection_type


func clear_selection() -> void:
	for id: String in _selection:
		if is_instance_valid(_selection[id]):
			_selection[id].modulate = Color.WHITE
	_selection.clear()
	_selection_type = ""
	_update_bulk_bar()


## Bulk action bar: applies one shared decision to every selected entity.
## Includes a "select all <type> in view" button for the 20-trees-at-once feel.
func _update_bulk_bar() -> void:
	if _bulk_bar == null:
		return
	for child: Node in _bulk_bar.get_children():
		child.queue_free()
	if _selection.size() < 2:
		_bulk_bar.visible = false
		return
	_bulk_bar.visible = true
	var count := Label.new()
	count.text = "%d × %s:" % [_selection.size(), _selection_type]
	_bulk_bar.add_child(count)
	for decision: Dictionary in _bulk_decisions():
		var btn := Button.new()
		btn.text = decision.label
		btn.tooltip_text = "%d EUR" % int(decision.cost)
		btn.pressed.connect(func() -> void:
			bulk_action_requested.emit(str(decision.id)))
		_bulk_bar.add_child(btn)
	var all := Button.new()
	all.text = "alle sichtbaren"
	all.tooltip_text = "Alle %s im sichtbaren Bereich auswählen" % _selection_type
	all.pressed.connect(_select_visible_of_type)
	_bulk_bar.add_child(all)
	var clear := Button.new()
	clear.text = "×"
	clear.tooltip_text = "Auswahl aufheben"
	clear.pressed.connect(clear_selection)
	_bulk_bar.add_child(clear)


## Common decisions of the selected entities (same-type selection by design).
func _bulk_decisions() -> Array:
	var data := _load_game_data()
	var first: String = str(_selection.keys()[0]) if not _selection.is_empty() else ""
	for record: Dictionary in data.get(_selection_type + "s", []):
		if str(record.id) == first:
			var entity := record.duplicate(true)
			entity["type"] = _selection_type
			return State.available_decisions(entity)
	return []


func _select_visible_of_type() -> void:
	var view := Rect2(Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical), _scroll.size)
	for id: String in markers:
		var dot: Control = markers[id]
		if dot.get_meta("etype") != _selection_type:
			continue
		var center: Vector2 = dot.position + Vector2(dot.get_meta("msize"), dot.get_meta("msize")) * _zoom / 2.0
		if view.has_point(center):
			_selection[id] = dot
			dot.modulate = Color(1.0, 0.62, 0.2)
	_update_bulk_bar()


## Expanding glow ring behind venue markers — makes festival venues findable
## at a glance on the dense iso map. Ignores mouse; independent of state
## modulate so set_entity_state keeps working.
func _add_pulse_ring(dot: Control) -> void:
	var ring := TextureRect.new()
	ring.texture = _make_ring()
	# native texture size, centered on the dot (no squish), scale around center
	ring.size = ring.texture.get_size()
	ring.position = -ring.size / 2.0 + Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.pivot_offset = ring.size / 2.0
	ring.modulate = Color(1.0, 0.62, 0.25, 0.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(ring)
	var tween := ring.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 1.6).from(Vector2(0.8, 0.8))
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.6).from(0.55)
	tween.tween_interval(0.7)


func _make_ring() -> ImageTexture:
	var key := "__ring"
	if _dot_cache.has(key):
		return _dot_cache[key]
	var size := MARKER_SIZE * 2
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var r := MARKER_SIZE * 0.85
	for x in size:
		for y in size:
			var d := Vector2(x, y).distance_to(center)
			if r - 1.6 <= d and d <= r:
				img.set_pixel(x, y, Color(1.0, 0.72, 0.35, 0.9))
	var tex := ImageTexture.create_from_image(img)
	_dot_cache[key] = tex
	return tex


func _pop_in(dot: TextureButton) -> void:
	dot.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(dot, "scale", Vector2(_zoom, _zoom), 0.35)


func _hover(dot: TextureButton, on: bool) -> void:
	if dot.disabled:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SPRING)
	var target := _zoom * 1.35 if on else _zoom
	tween.tween_property(dot, "scale", Vector2(target, target), 0.18)


## state: "neutral" | "affected" | "resolved"
func set_entity_state(id: String, state: String) -> void:
	if not markers.has(id):
		return
	var dot: TextureButton = markers[id]
	if state != "resolved" and _selection.has(id):
		return  # selection tint wins over neutral/affected
	match state:
		"affected":
			if not _selection.has(id):
				dot.modulate = Color(1.0, 0.62, 0.2)
		"resolved":
			_selection.erase(id)
			dot.modulate = Color(0.55, 0.55, 0.55, 0.55)
			dot.disabled = true
		_:
			dot.modulate = Color.WHITE
			dot.disabled = false


func focus_entity(id: String) -> void:
	if not markers.has(id):
		return
	var dot: TextureButton = markers[id]
	var w: float = dot.get_meta("msize") * _zoom
	_scroll.scroll_horizontal = int(dot.position.x + w / 2.0 - _scroll.size.x / 2.0)
	_scroll.scroll_vertical = int(dot.position.y + w / 2.0 - _scroll.size.y / 2.0)


func _make_dot(color: Color, size := MARKER_SIZE) -> ImageTexture:
	var key := color.to_html() + ":" + str(size)
	if _dot_cache.has(key):
		return _dot_cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var outer := size / 2.0 - 0.5
	var inner := size / 2.0 - 3.0
	for x in size:
		for y in size:
			var d := Vector2(x, y).distance_to(center)
			if d <= outer:
				img.set_pixel(x, y, Color.WHITE)      # ring for contrast on the light map
			if d <= inner:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_dot_cache[key] = tex
	return tex


## Mentor-pack purchase sprites: food truck / security appear at venues with
## units > 0 (badges show counts; sprites show presence). Same fallback logic
## as shuttles. Wired from main.gd::_refresh alongside refresh_badges.
func update_purchases(purchases: Dictionary) -> void:
	_last_purchases = purchases
	for m: Node in _purchase_markers:
		m.queue_free()
	_purchase_markers.clear()
	for venue_id: String in purchases:
		if not markers.has(venue_id):
			continue
		var counts: Dictionary = purchases[venue_id]
		var dot: TextureButton = markers[venue_id]
		var ll: Vector2 = dot.get_meta("latlon")
		var base := latlon_to_pixel(ll.x, ll.y) * _zoom
		var slot := 0
		for kind: String in ["foodtruck", "security"]:
			if int(counts.get(kind, 0)) <= 0:
				continue
			var tex := _load_sprite("prop_" + kind)
			var marker: Control
			if tex != null:
				var rect := TextureRect.new()
				rect.texture = tex
				rect.scale = Vector2(_zoom, _zoom)
				rect.position = base + Vector2(-18 + slot * 14, -tex.get_height()) * _zoom
				marker = rect
			else:
				var fb := TextureRect.new()
				fb.texture = _make_dot(Color("#e58e3f") if kind == "foodtruck" else Color("#4a6fa5"), 10)
				fb.position = base + Vector2(-18 + slot * 14, -16)
				marker = fb
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_map_root.add_child(marker)
			_purchase_markers.append(marker)
			slot += 1


## Planted trees (Opus's mentor-pack contract: state.planted_trees with
## {lat, lon, crown_m, age}) rendered as young-tree sprites; zoom-scaled.
func update_planted_trees(planted: Array) -> void:
	_last_planted = planted
	for m: Node in _planted_markers:
		m.queue_free()
	_planted_markers.clear()
	for tree: Dictionary in planted:
		var px := latlon_to_pixel(float(tree.lat), float(tree.lon)) * _zoom
		var tex := _load_sprite("prop_tree_broad_b")
		var marker: Control
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.scale = Vector2(_zoom, _zoom)
			rect.position = px - Vector2(tex.get_width() / 2.0, tex.get_height()) * _zoom
			marker = rect
		else:
			var dot := TextureRect.new()
			dot.texture = _make_dot(Color("#3f7d3a"), 12)
			dot.position = px - Vector2(6, 6) * _zoom
			marker = dot
		marker.tooltip_text = "Gepflanzter Baum"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_root.add_child(marker)
		_planted_markers.append(marker)


## Dynamic shuttle markers: purchased shuttles appear on the map.
## Sprites (Astra's prop_shuttle) preferred; amber-dot fallback otherwise.
func update_shuttles(shuttles: Array) -> void:
	_last_shuttles = shuttles
	for m: Node in _shuttle_markers:
		m.queue_free()
	_shuttle_markers.clear()
	for shuttle: Dictionary in shuttles:
		var px := latlon_to_pixel(float(shuttle.lat), float(shuttle.lon)) * _zoom
		var marker: Control
		var tex := _load_sprite("prop_shuttle")
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.position = px - Vector2(tex.get_width() / 2.0, tex.get_height())
			marker = rect
		else:
			var dot := TextureButton.new()
			dot.texture_normal = _make_dot(Color("#e58e3f"))
			dot.position = px - Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
			marker = dot
		marker.tooltip_text = "Shuttle-Haltestelle"
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_root.add_child(marker)
		_shuttle_markers.append(marker)


func _load_sprite(stem: String) -> Texture2D:
	var path := "res://assets/sprites/" + stem + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		var img := Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
	return tex


## Mentor-pack badges: unit counts per venue. Contract (Opus, round 6/6.1):
## purchases := { "<venue_id>": { "foodtruck": n, "security": n } }
## Called from main.gd on every refresh; absent/malformed data is ignored.
func refresh_badges(purchases: Dictionary) -> void:
	for id: String in _badges:
		_badges[id].queue_free()
	_badges.clear()
	for venue_id: String in purchases:
		if not markers.has(venue_id):
			continue
		var counts: Dictionary = purchases[venue_id]
		var food := int(counts.get("foodtruck", 0))
		var security := int(counts.get("security", 0))
		if food == 0 and security == 0:
			continue
		var dot: TextureButton = markers[venue_id]
		var badge := Label.new()
		badge.text = "%d · %d" % [food, security]
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color("#5a4a2f"))
		badge.tooltip_text = "Food-Trucks · Security"
		badge.position = Vector2(dot.texture_normal.get_width() + 2, -6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(badge)
		_badges[venue_id] = badge
