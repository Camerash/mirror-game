extends RefCounted
const Rules := preload("res://core/mirror_state.gd")

static func run(game: Node3D, check: Callable, tree: SceneTree) -> void:
	game.load_level(0)
	await _settle(game, tree)
	game.begin_preview()
	await _settle(game, tree)
	var initial: Dictionary = game.preview.duplicate(true)
	for turn: int in range(4):
		game.rotate_mirror(1)
		check.call(game.preview["pivot"] == initial["pivot"], "Quarter turn keeps its world pivot")
		check.call(not game.apply_preview(), "Confirm waits for sheet rotation")
		await _settle(game, tree)
	check.call(Rules.normal(game.preview) == Rules.normal(initial), "Four quarter turns restore source direction")
	game.rotate_mirror(1)
	await _settle(game, tree)
	game.rotate_mirror(1)
	await _settle(game, tree)
	check.call(Rules.normal(game.preview) == -Rules.normal(initial), "Half turn reverses the source side")
	var vertical: Vector3 = Rules.normal(game.preview)
	game.tilt_mirror()
	await _settle(game, tree)
	check.call(game.preview["axis"] == 1 and game.preview["pivot"] == initial["pivot"], "Lay flat uses the same pivot")
	game.tilt_mirror(-1)
	await _settle(game, tree)
	check.call(Rules.normal(game.preview) == vertical, "Stand up restores the previous vertical direction")
	game.cancel_preview()
	await _settle(game, tree)
	check.call(game.mirror == {"enabled": false}, "Cancel creation leaves no mirror")
	game.begin_preview()
	await _settle(game, tree)
	for orientation: int in [0, 1, 2]:
		game.change_preview("axis", orientation)
		await _settle(game, tree)
		for view: int in range(4):
			var before: Dictionary = game.preview.duplicate(true)
			var points := _sheet_points(game)
			check.call(points.size() >= 2, "Sheet has multiple touch points in axis %d view %d" % [orientation, view])
			if points.size() >= 2:
				for sample_index: int in [0, -1]:
					# Refit after the previous gesture changes screen coordinates.
					var point: Vector2 = _sheet_points(game)[sample_index]
					game._pointer(point, true, 0)
					game.gesture.move(point + Vector2(14, 0), 0)
					check.call(game.dragging, "Visible sheet starts dragging at axis %d view %d (hit=%s busy=%s target=%s)" % [orientation, view, game.sheet_hit(point), game.camera.busy, game.gesture.target])
					var size_before: float = game.camera.size
					game._drag(point + game.drag_axis * 0.5)
					check.call(is_equal_approx(game.camera.size, size_before), "Mirror dragging keeps zoom steady")
					var release := InputEventScreenTouch.new()
					release.index = 0
					release.pressed = false
					release.position = Vector2(-20, -20)
					game._input(release)
					check.call(not game.dragging, "Release outside the sheet ends dragging")
					await _settle(game, tree)
					game.change_preview("offset", before["offset"])
					await _settle(game, tree)
			var ui_point: Vector2 = game.hud.get_touch_control_bounds()["cancel"].get_center()
			check.call(not game.sheet_hit(ui_point), "Sheet picking ignores UI")
			game.turn_camera(1)
			await _settle(game, tree)
			check.call(game.preview == before, "Camera rotation does not change mirror state")
	game.cancel_preview()
	await _settle(game, tree)
	check.call(is_equal_approx(fposmod(game.camera.yaw, TAU), PI * 0.25), "Four camera views return to the initial angle")
	game.turn_camera(1)
	await tree.physics_frame
	game._fit_camera(Rect2(Vector2.ZERO, Vector2(1100, 760)), true)
	check.call(is_equal_approx(fposmod(game.camera.yaw - PI * 0.25, PI * 0.5), 0.0), "Camera refit during rotation ends on a quarter view")
	for path: String in game.LEVEL_PATHS:
		var data: Dictionary = game.Levels.load_level(path)
		check.call(data["limits"]["axes"] == [0, 1, 2], "Every level permits all mirror orientations")

static func _settle(game: Node3D, tree: SceneTree) -> void:
	for frame: int in range(120):
		await tree.physics_frame
		if frame > 2 and not game.camera.busy and not game.sheet.is_transitioning() and game.prediction["status"] != "pending":
			return

static func _sheet_points(game: Node3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var rect: Rect2 = game.hud.get_play_rect()
	for y: int in range(int(rect.position.y + 8), int(rect.end.y - 8), 18):
		for x: int in range(int(rect.position.x + 8), int(rect.end.x - 8), 18):
			if game.sheet_hit(Vector2(x, y)) and not Array(game.rings.get_orb_points()).any(func(orb: Vector2) -> bool: return orb.distance_to(Vector2(x,y)) <= 24):
				points.append(Vector2(x, y))
	return points
