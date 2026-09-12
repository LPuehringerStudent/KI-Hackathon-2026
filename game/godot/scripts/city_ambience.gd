extends Node2D

const STEP := 16
const ROUTE_SEPARATION := 224.0
var routes: Array[PackedVector2Array] = []
var followers: Array[PathFollow2D] = []
var boats: Array[Sprite2D] = []
var wakes: Array[Line2D] = []
var light_material: ShaderMaterial
var night_overlay: ColorRect
var _lights: Sprite2D
var _elapsed := 0.0


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


func _process(delta: float) -> void:
	_elapsed += delta
	var strength := 0.0
	if is_instance_valid(night_overlay):
		strength = clampf((night_overlay.color.a - 0.45) / 0.33, 0.0, 1.0)
	light_material.set_shader_parameter("strength", strength)
	_lights.visible = strength > 0.01
	for index in followers.size():
		var follow := followers[index]
		var curve: Curve2D = follow.get_parent().curve
		var length := curve.get_baked_length()
		follow.progress += delta * (24.0 + index * 2.0)
		var direction := curve.sample_baked(fposmod(follow.progress + 6, length), true) - curve.sample_baked(fposmod(follow.progress - 6, length), true)
		boats[index].material.set_shader_parameter("heading", fposmod(direction.angle() / TAU * 64, 64.0))
		var trail := PackedVector2Array()
		for point in range(19):
			trail.append(curve.sample_baked(fposmod(follow.progress - 90 + point * 4, length)))
		wakes[index].points = trail


func _cruise_curve(center: Vector2, angle: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 3.0
	var major := 210.0
	var minor := 115.0
	var k := 0.55228475
	var points := [Vector2(major, 0), Vector2(0, minor), Vector2(-major, 0), Vector2(0, -minor), Vector2(major, 0)]
	var handles := [Vector2(0, minor * k), Vector2(-major * k, 0), Vector2(0, -minor * k), Vector2(major * k, 0), Vector2(0, minor * k)]
	for i in points.size():
		curve.add_point(center + points[i].rotated(angle), -handles[i].rotated(angle), handles[i].rotated(angle))
	return curve


func _build_routes() -> void:
	# guard like _add_boat: an unimported asset must not abort ambience
	var texture: Texture2D = null
	if ResourceLoader.exists("res://assets/boat_clearance.png"):
		texture = load("res://assets/boat_clearance.png")
	if texture == null:
		var img := Image.load_from_file("res://assets/boat_clearance.png")
		if img != null:
			texture = ImageTexture.create_from_image(img)
	if texture == null:
		push_warning("city_ambience: boat_clearance.png not loadable — boats disabled")
		return
	var mask := texture.get_image()
	var water: Array[Vector2i] = []
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).r > 0.9:
				water.append(Vector2i(x, y))
	var center := Vector2(mask.get_size()) / 2.0
	water.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	for attempt in mini(300, water.size()):
		if routes.size() == 2:
			break
		var origin := Vector2(water[(attempt * 37) % water.size()]) * STEP + Vector2.ONE * STEP / 2.0
		for angle in [60, 75, 45, 90, 30, 120]:
			var curve := _cruise_curve(origin, deg_to_rad(angle))
			var samples := PackedVector2Array()
			var clear := true
			for distance in range(0, ceili(curve.get_baked_length()), 4):
				var point := curve.sample_baked(distance)
				var cell := Vector2i((point / STEP).floor())
				if not Rect2i(Vector2i.ZERO, mask.get_size()).has_point(cell) or mask.get_pixelv(cell).r < 0.9:
					clear = false
					break
				for route: PackedVector2Array in routes:
					for other: Vector2 in route:
						if point.distance_squared_to(other) < ROUTE_SEPARATION * ROUTE_SEPARATION:
							clear = false
							break
				if not clear:
					break
				samples.append(point)
			if clear:
				routes.append(samples)
				_add_boat(curve, routes.size() - 1)
				break


func _add_boat(curve: Curve2D, index: int) -> void:
	var path := Path2D.new()
	path.curve = curve
	add_child(path)
	var wake := Line2D.new()
	wake.width = 17
	wake.antialiased = true
	wake.gradient = Gradient.new()
	wake.gradient.set_color(0, Color(0.8, 0.96, 1, 0))
	wake.gradient.set_color(1, Color(0.93, 0.99, 1, 0.38))
	wake.width_curve = Curve.new()
	wake.width_curve.add_point(Vector2(0, 1))
	wake.width_curve.add_point(Vector2(1, 0.25))
	path.add_child(wake)
	wakes.append(wake)
	var follow := PathFollow2D.new()
	follow.loop = true
	follow.rotates = false
	follow.cubic_interp = true
	path.add_child(follow)
	follow.progress = curve.get_baked_length() * (0.15 + index * 0.2)
	followers.append(follow)
	var boat := Sprite2D.new()
	# graceful degradation: a stale import cache must not spam errors —
	# fall back to the raw file, and skip the boat if it cannot be read
	var boat_path := "res://assets/sprites/riverboat_directions.png"
	var boat_tex: Texture2D = null
	if ResourceLoader.exists(boat_path):
		boat_tex = load(boat_path)
	if boat_tex == null:
		# unimported (stale cache / fresh clone): read the raw file instead
		var img := Image.load_from_file(boat_path)
		if img != null:
			boat_tex = ImageTexture.create_from_image(img)
	if boat_tex == null:
		push_warning("city_ambience: riverboat_directions.png not loadable — run 'godot --headless --path game/godot --import'")
		return
	boat.texture = boat_tex
	boat.hframes = 8
	boat.vframes = 8
	boat.scale = Vector2(0.8, 0.8)
	boat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var heading_material := ShaderMaterial.new()
	heading_material.shader = preload("res://assets/boat_heading.gdshader")
	boat.material = heading_material
	follow.add_child(boat)
	boats.append(boat)
