class_name MapView
extends PanelContainer
## Interactive map: baked Innenstadt PNG with clickable entity markers.
## Track A owns this file; main.tscn integration is Track C's job.

signal entity_clicked(id: String, type: String)

const META_PATH := "res://data/map_meta.json"
const MAP_TEXTURE_PATH := "res://assets/innenstadt_map.png"
const MARKER_SIZE := 18

# marker colors match the plan: venue red, tree green, fountain blue,
# toilet purple, street gray
const MARKER_COLORS := {
	"venue": Color("#e5484d"),
	"tree": Color("#46a758"),
	"fountain": Color("#3e8fde"),
	"toilet": Color("#8e4ec6"),
	"street": Color("#9ba1ab"),
}

var markers := {}

var _meta := {}
var _scroll: ScrollContainer
var _map_root: Control
var _dot_cache := {}


func _ready() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	_scroll = $Scroll
	_map_root = $Scroll/MapRoot
	var map_rect: TextureRect = $Scroll/MapRoot/Map
	var img := Image.load_from_file(MAP_TEXTURE_PATH)
	if img == null:
		push_error("map_view: cannot load " + MAP_TEXTURE_PATH)
	else:
		map_rect.texture = ImageTexture.create_from_image(img)
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


## WGS84 -> pixel coords. MUST mirror tools/render_map.py project():
## equirectangular corrected for lat 48.3, scale = width / max(w_km, h_km).
func latlon_to_pixel(lat: float, lon: float) -> Vector2:
	var km_per_deg_lon := 111.32 * cos(deg_to_rad(48.3))
	var km_per_deg_lat := 110.57
	var x := (lon - float(_meta.lon_min)) * km_per_deg_lon
	var y := (float(_meta.lat_max) - lat) * km_per_deg_lat
	var w_km := (float(_meta.lon_max) - float(_meta.lon_min)) * km_per_deg_lon
	var h_km := (float(_meta.lat_max) - float(_meta.lat_min)) * km_per_deg_lat
	var scale := float(_meta.width) / maxf(w_km, h_km)
	return Vector2(x * scale, y * scale)


func _add_marker(entity: Dictionary, entity_type: String) -> void:
	var id := str(entity.id)
	if markers.has(id):
		return
	var dot := TextureButton.new()
	dot.texture_normal = _make_dot(MARKER_COLORS[entity_type])
	dot.tooltip_text = str(entity.get("name", id))
	dot.position = latlon_to_pixel(float(entity.lat), float(entity.lon)) - Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
	dot.pressed.connect(func() -> void: entity_clicked.emit(id, entity_type))
	_map_root.add_child(dot)
	markers[id] = dot


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


func _make_dot(color: Color) -> ImageTexture:
	var key := color.to_html()
	if _dot_cache.has(key):
		return _dot_cache[key]
	var img := Image.create_empty(MARKER_SIZE, MARKER_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(MARKER_SIZE, MARKER_SIZE) / 2.0
	var radius := MARKER_SIZE / 2.0 - 1.5
	for x in MARKER_SIZE:
		for y in MARKER_SIZE:
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_dot_cache[key] = tex
	return tex
