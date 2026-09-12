extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var boat = load("res://scripts/riverboat_view.gd").new()
	root.add_child(boat)
	boat.position = Vector2(200, 150)
	var previous: Image
	var nonblank := true
	var unclipped := true
	var aligned := true
	var max_change := 0.0
	var changed_frames := 0
	var camera: Camera3D = boat.model_view.get_camera_3d()
	var capture_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	for frame in range(721):
		var angle := deg_to_rad(frame * 0.5)
		boat.set_heading(angle)
		await RenderingServer.frame_post_draw
		var pixels: Image = boat.model_view.get_texture().get_image()
		var bounds := pixels.get_used_rect()
		nonblank = nonblank and bounds.get_area() > 1000
		unclipped = unclipped and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < pixels.get_width() and bounds.end.y < pixels.get_height()
		var bow := camera.unproject_position(boat.pivot.to_global(Vector3(3, 0, 0)))
		var center := camera.unproject_position(boat.pivot.global_position)
		aligned = aligned and absf(wrapf((bow - center).angle() - angle, -PI, PI)) < 0.001
		if frame % 180 == 0 and not capture_dir.is_empty():
			check(pixels.save_png(capture_dir.path_join("boat-turn-%03d.png" % frame)) == OK, "turn capture %d" % frame)
		pixels.resize(96, 64, Image.INTERPOLATE_LANCZOS)
		if previous != null:
			var change := 0.0
			for y in pixels.get_height():
				for x in pixels.get_width():
					change += absf(pixels.get_pixel(x, y).a - previous.get_pixel(x, y).a)
			change /= pixels.get_width() * pixels.get_height()
			max_change = maxf(max_change, change)
			if change > 0.00001:
				changed_frames += 1
		previous = pixels
	check(nonblank, "boat renders throughout a full turn")
	check(unclipped, "full-turn silhouette stays within its canvas")
	check(aligned, "bow follows screen heading through all quadrants")
	check(changed_frames == 720, "every fractional heading produces a new rendered silhouette")
	check(max_change < 0.015, "no abrupt full-turn silhouette jumps")
	print("BOAT max_alpha_change=", max_change, " failures=", failures)
	quit(1 if failures else 0)
