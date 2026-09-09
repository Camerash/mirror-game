extends RefCounted
const Rules := preload("res://core/mirror_state.gd")
const Geometry := preload("res://core/world_geometry.gd")

static func run(game: Node3D, check: Callable, tree: SceneTree) -> void:
	game.load_level(0)
	await _settle(game, tree)
	check.call(game.level["limits"]["min"][0] < 0 and game.level["limits"]["max"][0] > 8, "Placement spans both ends of the stage")
	game.begin_preview()
	await _settle(game, tree)
	var original: Dictionary = game.preview.duplicate(true)
	var committed: Array = game.solids.duplicate(true)
	var size_before: float = game.camera.size
	var centre: Vector2 = game.camera.unproject_position(original["pivot"])
	game._start_drag(centre)
	game._drag(centre + game.drag_axis * 0.35)
	await tree.create_timer(0.04).timeout
	check.call(game.display_target["offset"] == 3.0 and game.display_preview["offset"] > 2.5 and game.display_preview["offset"] < 3.0 and game.preview == original, "Drag interpolates toward a snapped target without committing")
	check.call(game.solids == committed and is_equal_approx(game.camera.size, size_before), "Drag leaves committed collision and camera scale fixed")
	check.call(not game.apply_preview() and not game.preview_view.ghost.visible, "Manipulation hides stale prediction and blocks confirmation")
	var source := AABB(Vector3(0, -1, 0), Vector3.ONE)
	check.call(is_equal_approx(Geometry.reflect(source, game.display_preview).position.x, 2.0 * game.display_preview["offset"] - 1.0), "Reflected structures follow the continuous plane position")
	game._finish_drag()
	check.call(not game.apply_preview(), "Release settling cannot confirm")
	await _settle(game, tree)
	check.call(game.preview["offset"] == 3.0 and game.display_preview.is_empty(), "Release settles on the nearest half unit")
	game.set_edit_mode("rotate")
	await _settle(game, tree)
	var pivot: Vector3 = game.preview["pivot"]
	var before_rotation: Array = game.world.drawn_solids.duplicate(true)
	game._action("rotation_begin", {"kind":"turn", "axis":Vector3.UP})
	game._action("rotation_angle", 0.2)
	await tree.create_timer(0.12).timeout
	check.call(game.world.drawn_solids != before_rotation and game.preview["pivot"] == pivot, "Rotation updates visual geometry immediately without moving its pivot")
	check.call(game.rotation_display and not game.apply_preview(), "Continuous rotation blocks confirmation")
	game._action("rotation_angle", TAU)
	game._action("rotation_end", null)
	await _settle(game, tree)
	check.call(Rules.normal(game.preview).is_equal_approx(Rules.normal(original)) and game.preview["pivot"] == pivot, "Full held rotation restores normal and preserves pivot")
	var before_tilt := Rules.frame(game.preview)
	for index: int in 4:
		game.tilt_mirror(1)
	await _settle(game, tree)
	check.call(Rules.frame(game.preview).is_equal_approx(before_tilt), "Four signed tilts restore the complete frame")
	var corners: PackedVector3Array = game.sheet.get_corners()
	check.call(is_equal_approx(corners[0].distance_to(corners[1]), 3.0) and is_equal_approx(corners[1].distance_to(corners[2]), 3.0), "Frame retains fixed dimensions after rotations")
	var start_scale: float = game.camera.size
	var end_scale: float = game.camera._pose(game.camera.yaw + PI * 0.5)["size"]
	game.turn_camera(1)
	var last_yaw: float = game.camera.yaw
	for frame: int in 180:
		await tree.process_frame
		if not is_equal_approx(last_yaw, game.camera.yaw):
			check.call(game.camera.size >= minf(start_scale,end_scale)-0.001 and game.camera.size <= maxf(start_scale,end_scale)+0.001, "Camera scale blends between captured endpoints")
		last_yaw = game.camera.yaw
		if not game.camera.busy:
			break
	game.cancel_preview()
	await _settle(game, tree)
	check.call(game.mirror == {"enabled": false}, "Cancel after manipulation preserves absence")
	game.begin_preview()
	await _settle(game, tree)
	game._start_drag(game.camera.unproject_position(game.preview["pivot"]))
	game._drag(game.drag_origin + game.drag_axis * 0.3)
	tree.root.size = Vector2i(390, 844)
	await _settle(game, tree)
	check.call(not game._manipulating() and game.display_preview.is_empty(), "Resize cancels active manipulation")
	game.cancel_preview()
	tree.root.size = Vector2i(1152, 800)

static func _settle(game: Node3D, tree: SceneTree) -> void:
	for frame: int in 240:
		await tree.physics_frame
		if frame > 3 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
