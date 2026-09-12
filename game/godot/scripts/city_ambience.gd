extends Node2D

const STEP := 16
var routes: Array[PackedVector2Array] = []
var followers: Array[PathFollow2D] = []
var light_material: ShaderMaterial
var night_overlay: ColorRect
var _lights: Sprite2D


func _ready() -> void:
	var lights := Sprite2D.new()
	_lights = lights
	lights.texture = load("res://assets/city_windows.png")
	lights.centered = false
	lights.z_index = 5
	light_material = ShaderMaterial.new()
	light_material.shader = load("res://assets/city_lights.gdshader")
	lights.material = light_material
	add_child(lights)
	_build_routes()


func _process(_delta: float) -> void:
	var strength := 0.0
	if is_instance_valid(night_overlay):
		strength = clampf((night_overlay.color.a - 0.45) / 0.33, 0.0, 1.0)
	light_material.set_shader_parameter("strength", strength)
	_lights.visible = strength > 0.01


func _build_routes() -> void:
	var texture: Texture2D = load("res://assets/boat_clearance.png")
	var mask := texture.get_image()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, mask.get_size())
	grid.cell_size = Vector2(STEP, STEP)
	grid.offset = Vector2(STEP, STEP) / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var water: Array[Vector2i] = []
	for y in mask.get_height():
		for x in mask.get_width():
			var point := Vector2i(x, y)
			var blocked := mask.get_pixel(x, y).r < 0.9
			grid.set_point_solid(point, blocked)
			if not blocked:
				water.append(point)
	if water.size() < 20:
		return
	var center := Vector2(mask.get_size()) / 2.0
	water.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	var directions: Array[Vector2i] = [Vector2i(0, 28), Vector2i(28, 0), Vector2i(0, -28), Vector2i(-28, 0)]
	for attempt in range(128):
		if routes.size() == 2:
			break
		var start := water[(attempt * 97) % water.size()]
		var end := start + directions[attempt % directions.size()]
		if not grid.region.has_point(end):
			continue
		if grid.is_point_solid(start) or grid.is_point_solid(end):
			continue
		var points := grid.get_point_path(start, end)
		if points.size() < 16:
			continue
		routes.append(points)
		_add_boat(points, routes.size() - 1)
		for point in points:
			var cell := Vector2i((point - grid.offset) / STEP)
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					var nearby := cell + Vector2i(dx, dy)
					if grid.region.has_point(nearby):
						grid.set_point_solid(nearby)


func _add_boat(points: PackedVector2Array, index: int) -> void:
	var path := Path2D.new()
	path.curve = Curve2D.new()
	for point in points:
		path.curve.add_point(point)
	add_child(path)
	var follow := PathFollow2D.new()
	follow.loop = false
	follow.cubic_interp = false
	path.add_child(follow)
	followers.append(follow)
	var wake := Line2D.new()
	wake.points = PackedVector2Array([Vector2(-13, -2), Vector2(-8, 0), Vector2(-13, 2)])
	wake.width = 1.0
	wake.default_color = Color(0.88, 0.98, 1.0, 0.55)
	follow.add_child(wake)
	var boat := Sprite2D.new()
	boat.texture = load("res://assets/sprites/prop_boat.png")
	boat.rotation = -0.45
	follow.add_child(boat)
	var duration := path.curve.get_baked_length() / (13.0 + index * 2.0)
	var tween := create_tween().set_loops()
	tween.tween_property(follow, "progress_ratio", 1.0, duration).from(0.0)
	tween.tween_property(follow, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: follow.progress_ratio = 0.0)
	tween.tween_property(follow, "modulate:a", 1.0, 0.8)
