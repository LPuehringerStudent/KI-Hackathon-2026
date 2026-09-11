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

const DAY_TINTS := [
	Color.WHITE,                    # Tag 1 — neutral
	Color(0.92, 0.97, 1.08),        # Tag 2 — cool morning
	Color(1.08, 0.86, 0.70),        # Tag 3 — Hitzetag glow
]

var markers := {}

var _meta := {}
var _scroll: ScrollContainer
var _map_root: Control
var _map_rect: TextureRect
var _dot_cache := {}
var _badges := {}
var _shuttle_markers: Array = []


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
	refresh()


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


## Day tint for the baked map (Tag 1 neutral, Tag 2 cool, Tag 3 Hitzetag).
## Track C calls this on day change; markers stay untinted for readability.
func set_day_tint(day: int) -> void:
	if _map_rect == null:
		return
	var index := clampi(day - 1, 0, DAY_TINTS.size() - 1)
	_map_rect.modulate = DAY_TINTS[index]


func _add_marker(entity: Dictionary, entity_type: String) -> void:
	var id := str(entity.id)
	if markers.has(id):
		return
	var dot := TextureButton.new()
	var marker_size := TREE_MARKER_SIZE if entity_type == "tree" else MARKER_SIZE
	dot.texture_normal = _make_dot(MARKER_COLORS[entity_type], marker_size)
	dot.tooltip_text = str(entity.get("name", id))
	dot.position = latlon_to_pixel(float(entity.lat), float(entity.lon)) - Vector2(marker_size, marker_size) / 2.0
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
	ring.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	ring.position = Vector2.ZERO
	ring.pivot_offset = ring.size / 2.0
	ring.modulate = Color(1.0, 0.62, 0.25, 0.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_child(ring)
	var tween := ring.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2(2.6, 2.6), 1.6).from(Vector2(0.7, 0.7))
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.6).from(0.75)
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
	_scroll.scroll_horizontal = int(dot.position.x - _scroll.size.x / 2.0)
	_scroll.scroll_vertical = int(dot.position.y - _scroll.size.y / 2.0)


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


## Dynamic shuttle markers: purchased shuttles appear on the map.
## Sprites (Astra's prop_shuttle) preferred; amber-dot fallback otherwise.
func update_shuttles(shuttles: Array) -> void:
	for m: Node in _shuttle_markers:
		m.queue_free()
	_shuttle_markers.clear()
	for shuttle: Dictionary in shuttles:
		var px := latlon_to_pixel(float(shuttle.lat), float(shuttle.lon))
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
