class_name MapView
extends PanelContainer
## Interactive map: baked isometric 2.5D Innenstadt PNG with clickable entity
## markers. Track A owns this file; main.tscn integration is Track C's job.
## The lat/lon->pixel transform mirrors tools/render_map.py (iso30) via
## map_meta.json format_version 2.

signal entity_clicked(id: String, type: String)

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
var _shuttle_markers: Array = []
var _purchase_markers: Array = []
var _last_shuttles: Array = []
var _last_purchases: Dictionary = {}
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
	_add_zoom_controls()
	refresh()


## Zoom: 0.6x..3.0x via on-map buttons or Ctrl+wheel. Marker sprites keep a
## constant screen size; only their map positions scale. The visible center
## is preserved across zoom changes.
func set_zoom(z: float) -> void:
	if _meta.is_empty():
		return
	var old_zoom := _zoom
	_zoom = clampf(z, 0.6, 3.0)
	if is_equal_approx(old_zoom, _zoom):
		return
	var base := Vector2(float(_meta.width), float(_meta.height))
	var view := _scroll.size
	var center_px := (Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical) + view / 2.0) / old_zoom
	_map_root.custom_minimum_size = base * _zoom
	_map_root.size = base * _zoom
	_relayout_markers()
	update_shuttles(_last_shuttles)
	update_purchases(_last_purchases)
	await get_tree().process_frame
	_scroll.scroll_horizontal = int(center_px.x * _zoom - view.x / 2.0)
	_scroll.scroll_vertical = int(center_px.y * _zoom - view.y / 2.0)


func zoom_in() -> void:
	set_zoom(_zoom * 1.25)


func zoom_out() -> void:
	set_zoom(_zoom / 1.25)


func _relayout_markers() -> void:
	for id: String in markers:
		var dot: Control = markers[id]
		var ll: Vector2 = dot.get_meta("latlon")
		var msize: float = dot.get_meta("msize")
		dot.position = latlon_to_pixel(ll.x, ll.y) * _zoom - Vector2(msize, msize) / 2.0


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()


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


func _add_marker(entity: Dictionary, entity_type: String) -> void:
	var id := str(entity.id)
	if markers.has(id):
		return
	var dot := TextureButton.new()
	var marker_size := TREE_MARKER_SIZE if entity_type == "tree" else MARKER_SIZE
	dot.texture_normal = _make_dot(MARKER_COLORS[entity_type], marker_size)
	dot.tooltip_text = str(entity.get("name", id))
	dot.set_meta("latlon", Vector2(float(entity.lat), float(entity.lon)))
	dot.set_meta("msize", float(marker_size))
	dot.position = latlon_to_pixel(float(entity.lat), float(entity.lon)) * _zoom - Vector2(marker_size, marker_size) / 2.0
	dot.pressed.connect(func() -> void: entity_clicked.emit(id, entity_type))
	dot.mouse_entered.connect(func() -> void: _hover(dot, true))
	dot.mouse_exited.connect(func() -> void: _hover(dot, false))
	_map_root.add_child(dot)
	markers[id] = dot
	_pop_in(dot)
	if entity_type == "venue":
		_add_pulse_ring(dot)


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
	tween.tween_property(dot, "scale", Vector2.ONE, 0.35)


func _hover(dot: TextureButton, on: bool) -> void:
	if dot.disabled:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SPRING)
	tween.tween_property(dot, "scale", Vector2(1.35, 1.35) if on else Vector2.ONE, 0.18)


## state: "neutral" | "affected" | "resolved"
func set_entity_state(id: String, state: String) -> void:
	if not markers.has(id):
		return
	var dot: TextureButton = markers[id]
	match state:
		"affected":
			dot.modulate = Color(1.0, 0.62, 0.2)
		"resolved":
			dot.modulate = Color(0.55, 0.55, 0.55, 0.55)
			dot.disabled = true
		_:
			dot.modulate = Color.WHITE
			dot.disabled = false


func focus_entity(id: String) -> void:
	if not markers.has(id):
		return
	var dot: TextureButton = markers[id]
	var w: float = dot.get_meta("msize")
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
				rect.position = base + Vector2(-18 + slot * 14, -tex.get_height() - 6)
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
