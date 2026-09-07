extends SceneTree

const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
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
	_test_geometry()
	game = Game.new()
	root.add_child(game)
	await _frames(5)
	await _test_route()
	await _test_support()
	await _test_wall()
	await _test_horizontal()
	await _test_failure_undo()
	await _test_pointer_input()
	await _test_fixtures_and_layout()
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

func _test_route() -> void:
	_check(not game.request_walk(Vector3(8, 0, 0)), "Goal is unreachable before a reflection")
	game.begin_preview()
	game.change_preview("enabled", true)
	_check(game.apply_preview(), "First mirror placement is accepted")
	await _frames(5)
	_check(game.request_walk(Vector3(5, 0, 0)), "Tap-to-walk finds a route across the mirror boundary")
	await _walk_finished()
	_check(game.walker.position.distance_to(Vector3(5, 0, 0)) < 0.04, "Character reaches the absolute resting point")
	var before: Vector3 = game.walker.position
	game.begin_preview()
	game.change_preview("offset", 4.0)
	_check(game.apply_preview(), "Second placement is accepted on an absolute")
	await _frames(5)
	_check(game.walker.position.distance_to(before) < 0.01, "Mirror adjustment does not move the character")
	_check(game.request_walk(Vector3(8, 0, 0)), "Second reflected route reaches the goal")
	await _walk_finished()
	_check(game.phase == "complete", "Shared input actions complete Level 1")
	game.begin_preview()
	game.cancel_preview()
	_check(game.phase == "complete", "Cancel preserves the completed goal state")
	game.begin_preview()
	game.change_preview("enabled", false)
	_check(game.apply_preview(), "Goal absolute supports another mirror change")
	await _frames(5)
	_check(game.undo(), "Mirror change after completion can be undone")
	await _frames(5)
	_check(game.phase == "complete" and game.mirror["enabled"], "Undo restores the pre-edit goal state")
	_check(game.undo(), "Goal completion can be undone")
	await _frames(5)
	_check(game.phase == "play" and game.walker.position.x < 5.1, "Undo restores the pre-walk position and goal state")

func _test_support() -> void:
	game.load_level(4)
	await _frames(5)
	_check(game.request_walk(Vector3(4, 0, 0)), "Restoration fixture target is reachable")
	await _walk_finished()
	game.begin_preview()
	game.change_preview("enabled", false)
	_check(game.apply_preview(), "Original ground can replace reflected support")
	await _frames(20)
	_check(absf(game.walker.position.y) < 0.01, "No fall occurs when original support returns")
	game.begin_preview()
	game.change_preview("offset", 3.0)
	game.cancel_preview()
	_check(not game.mirror["enabled"] and game.mirror["offset"] == 2.0, "Cancel leaves committed state unchanged")

func _test_wall() -> void:
	game.load_level(5)
	await _frames(5)
	_check(game.request_walk(Vector3(3, 0, 0)), "Reflected route replaces the original wall")
	await _walk_finished()
	game.begin_preview()
	game.change_preview("enabled", false)
	_check(not game.apply_preview(), "A returning wall through the character is rejected")
	_check(game.mirror["enabled"] and game.phase == "preview", "Rejected placement leaves committed world intact")
	game.cancel_preview()

func _test_horizontal() -> void:
	game.load_level(6)
	await _frames(5)
	_check(game.request_walk(Vector3(0, 4, 0)), "Character can enter reflected high ground")
	await _walk_finished()
	_check(absf(game.walker.position.y - 4.0) < 0.02, "Horizontal reflection supports the character at the correct height")
	game.begin_preview()
	game.change_preview("enabled", false)
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
	game.load_level(0)
	await _frames(5)
	game.begin_preview()
	game.change_preview("enabled", true)
	game.apply_preview()
	await _frames(5)
	_check(game.request_walk(Vector3(3.5, 0, 0)), "Failure test can reach unsupported original space")
	await _walk_finished()
	game.begin_preview()
	game.change_preview("enabled", false)
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
		await _frames(3)
		var rect: Rect2 = game.hud.get_play_rect()
		_check(rect.size.x > 100 and rect.size.y > 100, "Layout retains a usable play area at " + str(dimensions))
		for key: String in game.hud.get_touch_control_bounds():
			var bounds: Rect2 = game.hud.get_touch_control_bounds()[key]
			_check(bounds.size.x >= 48 and bounds.size.y >= 48, "Touch target is at least 48 units: " + key)
		var popup: PopupMenu = game.hud._level_picker.get_popup()
		var row_height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
		_check(row_height >= 48, "Menu rows also meet the touch target size")
		game.cancel_preview()

func _test_pointer_input() -> void:
	root.size = Vector2i(1152, 800)
	game.load_level(0)
	await _frames(5)
	var target: Vector2 = game.camera.unproject_position(Vector3(1, 0, 0))
	_mouse(target, true)
	_mouse(target, false)
	await _walk_finished()
	_check(absf(game.walker.position.x - 1.0) < 0.04, "Screen click resolves a top surface and walks there")
	_mouse(game.hud.get_touch_control_bounds()["edit"].get_center(), true)
	_mouse(game.hud.get_touch_control_bounds()["edit"].get_center(), false)
	await _frames(3)
	_check(game.phase == "preview", "HUD click enters preview without moving the character")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = game.handle.position + Vector2(28, 28)
	touch.pressed = true
	root.push_input(touch)
	_check(game.dragging, "Touch starts a mirror handle drag")
	var motion := InputEventScreenDrag.new()
	motion.index = 0
	motion.position = touch.position + game.drag_axis
	root.push_input(motion)
	_check(game.preview["offset"] == 3.5, "Touch drag snaps by world offset")
	touch.position = game.hud.get_touch_control_bounds()["edit"].get_center()
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
