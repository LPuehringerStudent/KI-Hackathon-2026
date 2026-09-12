extends Sprite2D

var pivot: Node3D
var model_view: SubViewport


func _ready() -> void:
	model_view = SubViewport.new()
	model_view.name = "ModelViewport"
	model_view.size = Vector2i(384, 256)
	model_view.transparent_bg = true
	model_view.own_world_3d = true
	model_view.msaa_3d = Viewport.MSAA_4X
	model_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(model_view)
	pivot = Node3D.new()
	model_view.add_child(pivot)
	var model_path := "res://assets/sprites/riverboat.glb"
	var model: Node3D
	if ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			model = packed.instantiate()
	if model == null:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(model_path, state) == OK:
			model = document.generate_scene(state)
	if model != null:
		pivot.add_child(model)
	else:
		push_warning("Riverboat model could not be loaded")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.3 / 1.5
	camera.position = Vector3(0, 6.928203, 12)
	model_view.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.4
	model_view.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -25, 0)
	key.light_energy = 0.65
	key.shadow_enabled = true
	model_view.add_child(key)
	texture = model_view.get_texture()
	scale = Vector2(0.4, 0.4)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_heading(angle: float) -> void:
	pivot.rotation.y = atan2(-sin(angle) / 0.5, cos(angle))
