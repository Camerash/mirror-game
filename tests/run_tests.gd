extends SceneTree

const Contact := preload("res://world/mirror_contact.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const NavigationTests := preload("res://tests/navigation_tests.gd")
const InteractionTests := preload("res://tests/mirror_interaction_tests.gd")
const GestureTests := preload("res://tests/gesture_tests.gd")
const SmoothTests := preload("res://tests/smooth_controls_tests.gd")
const PreviewTests := preload("res://tests/preview_tests.gd")
const Game := preload("res://game.gd")
var failures: Array[String] = []
var checks := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)

func _run() -> void:
	root.size = Vector2i(1152, 800)
	GestureTests.run(_check)
	_test_geometry()
	NavigationTests.run(_check)
	game = Game.new()
	root.add_child(game)
	await _frames(5)
	await _test_lifecycle()
	await _test_route()
	await _test_progression()
	await _test_sweep_cancel()
	await _test_reveal()
	await _test_support()
	await _test_wall()
	await _test_horizontal()
	await _test_failure_undo()
	await _test_pointer_input()
	await _test_fixtures_and_layout()
	await PreviewTests.run(game, _check, self)
	await InteractionTests.run(game, _check, self)
	await SmoothTests.run(game, _check, self)
	print("Mirror tests: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_geometry() -> void:
	var source := AABB(Vector3(-2, -1, -1), Vector3(4, 1, 2))
	var mirror := {"enabled": true, "axis": 0, "source": 1, "offset": 0.5}
	var clipped := Geometry.source_part(source, mirror)
	_check(clipped.end.x == 0.5 and clipped.position.x == -2, "Partial cut retains only the source side")
	_check(Geometry.reflect(clipped, mirror).position.x == 0.5, "Reflected cut meets the plane")
	_check(Geometry.reflect(Geometry.reflect(source, mirror), mirror).is_equal_approx(source), "Reflection twice restores the bounds")
	mirror["source"] = -1
	_check(Geometry.source_part(source, mirror).position.x == 0.5, "Source direction reverses the retained side")
	mirror.merge({"axis": 1, "source": 1, "offset": 1.5}, true)
	_check(Geometry.reflect(source, mirror).end.y == 4.0, "Horizontal reflection creates the expected upper surface")
	var pieces := Geometry.subtract(source, AABB(Vector3(-1, -1, -1), Vector3(2, 1, 2)))
	var volume := 0.0
	for piece: AABB in pieces:
		volume += piece.get_volume()
	_check(is_equal_approx(volume, 4.0), "Absolute subtraction preserves only non-overlapping volume")
	var level := Levels.load_level("res://levels/01_route.json")
	var active: Dictionary = level["mirror"].duplicate(true)
	active["enabled"] = true
	var world := Geometry.generate(level, active)
	var effect := Contact.new()
	root.add_child(effect)
	var contact_state := active.duplicate(true)
	contact_state["pivot"] = Vector3(5,0,0)
	var contacts := effect._contours(world, contact_state, preload("res://core/mirror_state.gd").frame(contact_state))
	_check(not contacts.is_empty(), "Panel intersection includes the absolute resting platform")
	for contact: Dictionary in contacts:
		_check(is_equal_approx(contact["a"].x, 5.0) and is_equal_approx(contact["b"].x, 5.0), "Contact contour follows the exact panel plane")
	effect.free()
	_check(Geometry.walkable(Vector3(3, 0, 0), world), "Reflection creates walkable support")
	_check(not Geometry.embedded(Vector3(3, 0, 0), world), "Floor contact is not an embedded character")
	_check(Geometry.embedded(Vector3(3, -0.4, 0), world), "Real capsule penetration is rejected")
	for solid: Dictionary in world:
		if solid["kind"] != "absolute":
			for absolute: Dictionary in level["absolutes"]:
				_check(not Geometry.has_volume(solid["bounds"].intersection(Geometry.box(absolute))), "Generated solids do not overlap an absolute")
	_check(not Levels.validate({}).is_empty(), "Malformed level data has a clear error")
	var invalid := level.duplicate(true)
	invalid["originals"][0]["size"] = [0, 1, 1]
	_check(not Levels.validate(invalid).is_empty(), "Zero-size geometry is rejected")

func _test_lifecycle() -> void:
	# This test's pivot checks are tuned to 01_route's placement area, so load
	# it by path. Do not rely on Game._ready() having loaded it as level 0.
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await _frames(5)
	await _preview_ready()
	_check(game.mirror == {"enabled": false}, "An initial absent mirror has no transform")
	var point: Vector2 = game.camera.unproject_position(Vector3(4, 0, 1))
	game.create_mirror(point)
	await _preview_ready()
	_check(game.preview.get("pivot", Vector3.INF).is_equal_approx(Vector3(4, 0, 1)), "Creation projects the press, snaps and clamps the pivot: " + str(game.preview.get("pivot")))
	game.cancel_preview()
	_check(game.mirror == {"enabled": false}, "Cancel creation keeps the mirror absent")
	game.begin_preview()
	await _preview_ready()
	_check(game.apply_preview(), "Fresh default creation can be placed")
	await _frames(5)
	var placed: Dictionary = game.mirror.duplicate(true)
	game.create_mirror(point)
	_check(game.phase == "play" and game.mirror == placed, "Creation cannot add a second mirror")
	game.edit_mirror()
	game.remove_mirror()
	await _preview_ready()
	_check(game.preview.has("pivot") and not game.preview["enabled"], "Removal retains only its preview outline")
	_check(game.apply_preview(), "Removal can be confirmed on original support")
	await _frames(5)
	_check(game.mirror == {"enabled": false} and game.preview_origin.is_empty(), "Confirmed removal discards the live transform")
	game.create_mirror(point)
	await _preview_ready()
	_check(game.preview.get("pivot", Vector3.INF).is_equal_approx(Vector3(4, 0, 1)), "Creation after removal uses the new press: " + str(game.preview.get("pivot")))
	game.cancel_preview()
	_check(game.undo(), "Removal can be undone")
	await _frames(5)
	_check(game.mirror == placed, "Undo restores the removed mirror from history")
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await _frames(5)

func _test_route() -> void:
	# This test inspects "complete" state at length (undo/redo, cancel), so the
	# stage sweep must not carry it away the instant the goal is reached.
	game.auto_advance = false
	_check(not game.request_walk(Vector3(8, 0, 0)), "Goal is unreachable before a reflection")
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", true)
	await _preview_ready()
	_check(game.apply_preview(), "First mirror placement is accepted")
	await _frames(5)
	_check(game.request_walk(Vector3(5, 0, 0)), "Tap-to-walk finds a route across the mirror boundary")
	await _walk_finished()
	_check(game.walker.position.distance_to(Vector3(5, 0, 0)) < 0.04, "Character reaches the absolute resting point")
	var before: Vector3 = game.walker.position
	game.begin_preview()
	await _preview_ready()
	game.change_preview("offset", 4.0)
	await _preview_ready()
	_check(game.apply_preview(), "Second placement is accepted on an absolute")
	await _frames(5)
	_check(game.walker.position.distance_to(before) < 0.01, "Mirror adjustment does not move the character")
	_check(game.request_walk(Vector3(8, 0, 0)), "Second reflected route reaches the goal")
	await _walk_finished()
	_check(game.phase == "complete", "Shared input actions complete Level 1")
	game.begin_preview()
	await _preview_ready()
	game.cancel_preview()
	_check(game.phase == "complete", "Cancel preserves the completed goal state")
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.apply_preview(), "Goal absolute supports another mirror change")
	await _frames(5)
	_check(game.undo(), "Mirror change after completion can be undone")
	await _frames(5)
	_check(game.phase == "complete" and game.mirror["enabled"], "Undo restores the pre-edit goal state")
	_check(game.undo(), "Goal completion can be undone")
	await _frames(5)
	_check(game.phase == "play" and game.walker.position.x < 5.1, "Undo restores the pre-walk position and goal state")

func _test_progression() -> void:
	# 01_route is currently loaded (from the previous test). Find its own index
	# in PUZZLE_PATHS, so this check keeps working if a stage is inserted
	# before it and the puzzle no longer sits at index 0.
	var route_index := Game.PUZZLE_PATHS.find("res://levels/01_route.json")
	var next_index := route_index + 1
	_check(not game.advance_level(), "Next level cannot skip an unfinished puzzle")
	game.auto_advance = true
	_check(game.request_walk(Vector3(8, 0, 0)), "Level 1 can be completed again after Undo")
	await _walk_finished()
	_check(game.phase == "transition", "Reaching the goal with auto_advance starts the stage sweep")
	_check(not game.can_edit(), "Editing is blocked during the sweep")
	_check(not game.request_walk(Vector3(0, 0, 0)), "Walking is blocked during the sweep")
	_check(not game.undo(), "Undo is blocked during the sweep")
	var settled := false
	for tick: int in range(300):
		if game.phase == "play":
			settled = true
			break
		await physics_frame
	_check(settled, "The sweep finishes within 300 physics frames")
	_check(game.level_index == next_index, "The sweep advances to the next puzzle")
	_check(game.history.is_empty() and game.walker.route.is_empty(), "The sweep starts the new stage with clean history and movement")
	_check(game.walker.position.distance_to(Geometry.vector(game.level["start"])) < 0.05, "The walker stands at the new stage's start")
	_check(not game.sweep.active, "The sweep view is no longer active")
	_check(game.world.clip_plane == Plane(), "The main world clip is cleared after the sweep")
	_check(game.goal_root.visible, "The new goal ring shows again")
	_check(game.hud._level_picker.selected == next_index, "Level picker follows progression")
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1152, 800)]:
		root.size = dimensions
		await _frames(3)
		_check(not game.hud.get_touch_control_bounds().has("next_level"), "No Next control exists at " + str(dimensions))
	root.size = Vector2i(1152, 800)
	await _frames(3)

func _test_sweep_cancel() -> void:
	var reveal_index := Game.LEVEL_PATHS.find("res://levels/08_reveal.json")
	game.load_level(reveal_index)
	await _frames(5)
	game.auto_advance = true
	game.phase = "complete"
	game._start_advance_pause()
	await _frames(50)
	_check(game.sweep.active, "Sweep test setup: the sweep is running mid-transition")
	game.load_level(reveal_index)
	await _frames(3)
	_check(not game.sweep.active, "Reset during the sweep cancels it")
	_check(game.sweep._old_view == null, "Cancel frees the old stage's ghost view")
	_check(game.world.clip_plane == Plane(), "Cancel clears the main world's clip")
	_check(game.goal_root.visible and game.contact.visible, "Cancel restores the goal ring and the contact seams")
	# The sheet's own visibility then follows the reloaded level's mirror
	# state (Level 2's default mirror is disabled, so the sheet stays
	# hidden for that reason, not because the sweep still holds it down).
	_check(game.sweep._sheet == null, "Cancel releases the sweep's hold on the mirror sheet")
	_check(game.phase == "play", "Cancel-through-load_level leaves the game in play")
	game.auto_advance = false

func _test_reveal() -> void:
	# Same reason as _test_route: this test keeps completing and undoing
	# Level 2, and the sweep would carry it to Level 3 mid-check.
	game.auto_advance = false
	_check(not game.request_walk(Vector3(8, 0, 0)), "Level 2 goal is blocked by the original gap")
	game.begin_preview()
	await _preview_ready()
	_check(game.phase == "preview" and not game.dragging, "Level 2 opens preview without starting a drag")
	game.change_preview("offset", 4.0)
	await _preview_ready()
	_check(game.preview["offset"] == 4.0, "Level 2 allows placements beyond the old fixed offset")
	game.change_preview("offset", 2.5)
	await _preview_ready()
	game.change_preview("enabled", true)
	await _preview_ready()
	_check(game.apply_preview(), "Level 2 reflection can be enabled")
	await _frames(5)
	_check(not Geometry.supported(Vector3(6, 0, 0), game.solids), "Reflection removes the original final approach")
	_check(not game.request_walk(Vector3(8, 0, 0)), "Reflection alone cannot reach the goal")
	_check(game.request_walk(Vector3(3.5, 0, 0)), "Player can try an unsafe point above the original gap")
	await _walk_finished()
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.status.begins_with("Will fall"), "Unsafe restoration gives a fall preview")
	game.apply_preview()
	await _frames(100)
	_check(game.phase == "failure" and game.undo(), "Unsafe Level 2 experiment can be undone after failure")
	await _frames(5)
	_check(game.request_walk(Vector3(5, 0, 0)), "Reflection reaches the safe replacement point")
	await _walk_finished()
	var before: Vector3 = game.walker.position
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.status.begins_with("Supported"), "Original ground gives a supported preview without an absolute")
	game.cancel_preview()
	_check(game.mirror["enabled"] and not Geometry.supported(Vector3(6, 0, 0), game.solids), "Cancel keeps the final approach replaced")
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.apply_preview(), "Restoration on an original platform is accepted")
	await _frames(20)
	_check(game.walker.position.distance_to(before) < 0.01 and game.walker.is_on_floor(), "Support returns without moving or dropping the character")
	_check(game.request_walk(Vector3(8, 0, 0)), "Restored approach connects to the visible absolute goal")
	await _walk_finished()
	_check(game.phase == "complete", "Shared player commands complete Level 2")
	# Level 2 used to be the last puzzle, so this asked whether it advanced at
	# all. The sequence is longer now, and the property worth protecting was
	# never "Level 2 is last" but "the sequence never runs into a test room".
	for path: String in game.PUZZLE_PATHS:
		_check(not Levels.load_level(path).get("is_test", false),
			"The puzzle sequence holds no test fixture: " + path)
	_check(game.PUZZLE_PATHS.size() < game.LEVEL_PATHS.size()
		and game.LEVEL_PATHS.slice(0, game.PUZZLE_PATHS.size()) == game.PUZZLE_PATHS,
		"The puzzles are the front of the level list, so Next never reaches a fixture")
	_check(game.undo(), "Level 2 completion can be undone")
	await _frames(5)
	_check(game.phase == "play" and not game.mirror["enabled"] and game.walker.position.distance_to(before) < 0.01, "Undo restores the pre-goal state")
	game._action("reset", null)
	await _frames(5)
	_check(game.history.is_empty() and not game.mirror["enabled"] and game.walker.position.distance_to(Vector3.ZERO) < 0.01, "Level 2 reset restores its initial state")

func _test_support() -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/05_restore.json"))
	await _frames(5)
	_check(game.request_walk(Vector3(4, 0, 0)), "Restoration fixture target is reachable")
	await _walk_finished()
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.apply_preview(), "Original ground can replace reflected support")
	await _frames(20)
	_check(absf(game.walker.position.y) < 0.01, "No fall occurs when original support returns")
	game.begin_preview()
	await _preview_ready()
	game.change_preview("offset", 3.0)
	await _preview_ready()
	game.cancel_preview()
	_check(game.mirror == {"enabled": false}, "Cancel leaves no retained mirror transform")

func _test_wall() -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/06_wall.json"))
	await _frames(5)
	_check(game.request_walk(Vector3(3, 0, 0)), "Reflected route replaces the original wall")
	await _walk_finished()
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(not game.apply_preview(), "A returning wall through the character is rejected")
	_check(game.mirror["enabled"] and game.phase == "preview", "Rejected placement leaves committed world intact")
	game.cancel_preview()

func _test_horizontal() -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/07_horizontal.json"))
	await _frames(5)
	_check(game.request_walk(Vector3(0, 4, 0)), "Character can enter reflected high ground")
	await _walk_finished()
	_check(absf(game.walker.position.y - 4.0) < 0.02, "Horizontal reflection supports the character at the correct height")
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	_check(game.status.begins_with("Will fall"), "Preview identifies unsupported placement")
	_check(game.apply_preview(), "A planned fall is permitted")
	await _frames(15)
	_check(game.walker.position.y < 4.0 and game.walker.velocity.y < 0, "Gravity remains downward")
	await _frames(90)
	_check(absf(game.walker.position.y) < 0.02 and game.phase == "play", "Long fall lands safely on lower original support")
	_check(game.undo(), "Useful fall can be undone")
	await _frames(5)
	_check(absf(game.walker.position.y - 4.0) < 0.02 and game.mirror["enabled"], "Undo restores high ground and character together")

func _test_failure_undo() -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await _frames(5)
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", true)
	await _preview_ready()
	game.apply_preview()
	await _frames(5)
	_check(game.request_walk(Vector3(3.5, 0, 0)), "Failure test can reach unsupported original space")
	await _walk_finished()
	game.begin_preview()
	await _preview_ready()
	game.change_preview("enabled", false)
	await _preview_ready()
	game.apply_preview()
	await _frames(100)
	_check(game.phase == "failure", "Falling below the lower boundary causes failure")
	_check(game.undo(), "Undo is available after failure")
	await _frames(5)
	_check(game.phase == "play" and absf(game.walker.position.y) < 0.02, "Undo after failure restores support and character")

func _test_fixtures_and_layout() -> void:
	for index: int in range(Game.LEVEL_PATHS.size()):
		_check(game.load_level(index), "Fixture %d loads" % index)
		await _frames(3)
		for solid_index: int in range(game.solids.size()):
			var mesh_node: MeshInstance3D = game.world.visual_root.get_child(solid_index)
			var body: StaticBody3D = game.world.collision_root.get_child(solid_index)
			var shape: CollisionShape3D = body.get_child(0)
			_check(mesh_node.mesh.size.is_equal_approx(shape.shape.size) and mesh_node.position.is_equal_approx(body.position), "Visible and collision box agree")
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1152, 800)]:
		root.size = dimensions
		game.begin_preview()
		await _preview_ready()
		await _frames(3)
		_check(not game.hud.get_touch_control_bounds().has("level_picker"), "Debug panels are hidden during normal editing")
		var rect: Rect2 = game.hud.get_play_rect()
		_check(rect.size.x > 100 and rect.size.y > 100, "Layout retains a usable play area at " + str(dimensions))
		for key: String in game.hud.get_touch_control_bounds():
			var bounds: Rect2 = game.hud.get_touch_control_bounds()[key]
			_check(bounds.size.x >= 48 and bounds.size.y >= 48, "Touch target is at least 48 units: " + key)
			_check(bounds.position.x >= 0 and bounds.end.x <= dimensions.x, "Control fits the window width: " + key)
		game.cancel_preview()

func _test_pointer_input() -> void:
	root.size = Vector2i(1152, 800)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await _frames(5)
	var target: Vector2 = game.camera.unproject_position(Vector3(1, 0, 0))
	_mouse(target, true)
	_mouse(target, false)
	await _walk_finished()
	_check(absf(game.walker.position.x - 1.0) < 0.04, "Screen click resolves a top surface and walks there")
	var empty_point := _empty_point()
	game._pointer(empty_point, true, 0)
	game.gesture.advance(0.46)
	game._pointer(empty_point, false, 0)
	await _preview_ready()
	_check(game.phase == "preview", "Long press creates a mirror preview without a walk")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = _sheet_point()
	touch.pressed = true
	root.push_input(touch)
	_check(not game.dragging, "Touch press alone does not translate or confirm")
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	var drag_normal := Vector3.ZERO
	drag_normal[int(game.preview["axis"])] = 1.0
	var screen_axis: Vector2 = game.camera.unproject_position(game.preview["pivot"] + drag_normal) - game.camera.unproject_position(game.preview["pivot"])
	var original_offset: float = game.preview["offset"]
	motion.position = touch.position + screen_axis
	root.push_input(motion)
	_check(game.preview["offset"] == original_offset and is_equal_approx(game.display_target["offset"], minf(original_offset + 1.0, game.level["limits"]["max"][0])), "Touch drag selects a snapped target without committing")
	touch.position = game.hud.get_touch_control_bounds()["cancel"].get_center()
	touch.pressed = false
	root.push_input(touch)
	_check(not game.dragging, "Drag release over controls ends the drag")
	game.cancel_preview()

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)

func _walk_finished() -> void:
	for tick: int in range(600):
		await physics_frame
		if game.walker.route.is_empty():
			await _frames(3)
			return
	_check(false, "Walking completes within ten seconds")

func _frames(count: int) -> void:
	for tick: int in range(count):
		await physics_frame

func _preview_ready() -> void:
	for tick: int in range(120):
		if game.prediction["status"] != "pending" and not game.sheet.is_transitioning() and not game.camera.busy:
			return
		await physics_frame
	_check(false, "Fall prediction finishes within two seconds")

func _sheet_point() -> Vector2:
	var rect: Rect2 = game.hud.get_play_rect()
	for y: int in range(int(rect.position.y + 10), int(rect.end.y - 10), 10):
		for x: int in range(int(rect.position.x + 10), int(rect.end.x - 10), 10):
			var point := Vector2(x, y)
			if game.sheet_hit(point) and not Array(game.rings.get_orb_points()).any(func(orb: Vector2) -> bool: return orb.distance_to(point) <= 24):
				return point
	_check(false, "Visible sheet has a touchable point")
	return Vector2.ZERO

func _empty_point() -> Vector2:
	var rect: Rect2 = game.hud.get_play_rect().grow(-30)
	for y: int in range(int(rect.position.y), int(rect.end.y), 24):
		for x: int in range(int(rect.position.x), int(rect.end.x), 24):
			var point := Vector2(x, y)
			if not game._solid_hit(point) and not game.hud.blocks_world_input(point):
				return point
	_check(false, "Empty space is available for mirror creation")
	return rect.get_center()
