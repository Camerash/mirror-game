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
	game._drag(centre + game.drag_axis * 0.27)
	check.call(is_equal_approx(game.display_preview["offset"], 2.77) and game.preview == original, "Drag keeps continuous display offset separate from snapped proposal")
	check.call(game.solids == committed and is_equal_approx(game.camera.size, size_before), "Drag leaves committed collision and camera scale fixed")
	check.call(not game.apply_preview() and not game.preview_view.ghost.visible, "Manipulation hides stale prediction and blocks confirmation")
	var source := AABB(Vector3(0, -1, 0), Vector3.ONE)
	check.call(is_equal_approx(Geometry.reflect(source, game.display_preview).position.x, 4.54), "Reflected structures follow the continuous plane position")
	game._finish_drag()
	check.call(not game.apply_preview(), "Release settling cannot confirm")
	await _settle(game, tree)
	check.call(game.preview["offset"] == 3.0 and game.display_preview.is_empty(), "Release settles on the nearest half unit")
	var pivot: Vector3 = game.preview["pivot"]
	var before_rotation: Array = game.world.drawn_solids.duplicate(true)
	game._action("rotation_begin", null)
	for index: int in 4:
		game.rotate_mirror(1)
	check.call(game.world.drawn_solids == before_rotation, "Rotation starts without switching geometry ahead of its animation")
	check.call(game.rotation_queue.size() == 3, "Held rotation keeps requests received during animation")
	game._action("rotation_end", null)
	await _settle(game, tree)
	check.call(Rules.normal(game.preview) == Rules.normal(original) and game.preview["pivot"] == pivot, "Queued quarter turns restore normal and preserve pivot")
	var before_tilt := Rules.frame(game.preview)
	for index: int in 4:
		game.tilt_mirror(1)
	await _settle(game, tree)
	check.call(Rules.frame(game.preview).is_equal_approx(before_tilt), "Four signed tilts restore the complete frame")
	var corners: PackedVector3Array = game.sheet.get_corners()
	check.call(is_equal_approx(corners[0].distance_to(corners[1]), 3.0) and is_equal_approx(corners[1].distance_to(corners[2]), 3.0), "Frame retains fixed dimensions after rotations")
	game.turn_camera(1)
	var orbit_scale := -1.0
	var last_yaw: float = game.camera.yaw
	for frame: int in 180:
		await tree.process_frame
		if not is_equal_approx(last_yaw, game.camera.yaw):
			if orbit_scale < 0:
				orbit_scale = game.camera.size
			check.call(is_equal_approx(game.camera.size, orbit_scale), "Camera scale stays fixed during orbital motion")
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
