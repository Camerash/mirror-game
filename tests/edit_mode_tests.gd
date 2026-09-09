extends SceneTree
const Game := preload("res://game.gd")
const Targets := preload("res://core/mirror_targets.gd")
const Gesture := preload("res://ui/world_gesture.gd")
var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func settle() -> void:
	for tick: int in 300:
		await physics_frame
		if tick > 5 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	check(false, "Interaction settles and predicts")

func _run() -> void:
	check(Targets.step(0.29, 0.0, 0.5) == 0.0, "Snap hysteresis retains current target near midpoint")
	check(Targets.step(0.31, 0.0, 0.5) == 0.5, "Crossing the threshold selects next target")
	check(Targets.step(0.21, 0.5, 0.5) == 0.5 and Targets.step(0.19, 0.5, 0.5) == 0, "Reverse travel uses the same hysteresis")
	check(Targets.step(0.123, 0, 0) == 0.123, "No snap keeps continuous targets")
	var gesture := Gesture.new()
	var actions: Array[String] = []
	gesture.action_requested.connect(func(action: String, _value: Variant) -> void: actions.append(action))
	gesture.begin(Vector2(100,100), 0, "sheet", true, false)
	gesture.move(Vector2(150,100), 0)
	gesture.release(Vector2(150,100), 0)
	check(actions.is_empty(), "Dragging the sheet in a different mode does not move or confirm")
	gesture.begin(Vector2(100,100), 0, "sheet", true, false)
	gesture.release(Vector2(100,100), 0)
	check(actions == ["apply"], "Short sheet tap can confirm in every mode")
	root.size = Vector2i(1152,800)
	game = Game.new()
	root.add_child(game)
	await settle()
	game.begin_preview()
	await settle()
	check(game.edit_mode == "move" and game.angle_snap == 15, "Editing starts in Move with 15-degree angle targets")
	var initial: Dictionary = game.preview.duplicate(true)
	var committed: Array = game.solids.duplicate(true)
	var start: Vector3 = initial["pivot"]
	var camera_pose: Transform3D = game.camera.transform
	game._start_drag(game.camera.unproject_position(start))
	game._drag(game.camera.unproject_position(start + Vector3(0.8,0,0.4)))
	check(game.display_target["pivot"] == start + Vector3(1,0,0.5), "Ground movement selects a half-unit X/Z target during drag")
	game.set_edit_mode("rotate")
	check(game.edit_mode == "move", "Mode switching is blocked during a drag")
	await create_timer(0.04).timeout
	check(game.display_preview["pivot"] != initial["pivot"] and game.preview == initial, "Displayed geometry follows while proposal stays separate")
	check(game.solids == committed and game.camera.transform == camera_pose, "Collision and camera remain frozen")
	game._drag(game.camera.unproject_position(start + Vector3(0.35,0,0.4)))
	var latest: Vector3 = game.display_target["pivot"]
	game._finish_drag()
	check(not game.apply_preview(), "Release never confirms during settling")
	await settle()
	check(game.preview["pivot"] == latest, "Release reaches the indicated latest target")
	game.set_edit_mode("rotate")
	await settle()
	var yaw: float = game.preview["yaw"]
	game._action("rotation_begin", {"kind":"turn", "axis":Vector3.UP})
	game._action("rotation_angle", deg_to_rad(14))
	check(is_equal_approx(game.display_target["yaw"], yaw + deg_to_rad(15)), "Rotation selects 15 degrees during the drag")
	game._action("rotation_end", null)
	await settle()
	check(is_equal_approx(game.preview["yaw"], yaw + deg_to_rad(15)), "Release preserves the rotation target")
	game.set_edit_mode("resize")
	await settle()
	game._start_resize({"key":"width", "point":Vector2.ZERO})
	game._set_resize_length(4.7)
	check(game.display_target["width"] == 5 and game.display_target["pivot"].is_equal_approx(game.display_target["pivot"].snapped(Vector3.ONE*0.5)), "Resize targets whole size and world-grid centre together")
	game._finish_resize()
	await settle()
	check(game.preview["width"] == 5, "Resize completes at its indicated size")
	game.cancel_preview()
	await settle()
	check(game.mirror == {"enabled":false} and game.history.is_empty(), "Cancel restores absence without mode history")
	game.begin_preview()
	await settle()
	check(game.edit_mode == "move", "A new editing session returns to Move")
	await _camera_check()
	game.queue_free()
	await process_frame
	print("Edit mode checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _camera_check() -> void:
	var start_angle: float = game.camera.yaw
	var start_size: float = game.camera.size
	var target_size: float = game.camera._pose(start_angle + PI * 0.5)["size"]
	game.turn_camera(1)
	await create_timer(0.06).timeout
	check(not is_equal_approx(game.camera.yaw, start_angle), "Camera starts turning without a pre-zoom phase")
	check(game.camera.size >= minf(start_size,target_size)-0.001 and game.camera.size <= maxf(start_size,target_size)+0.001, "Blended scale stays between start and destination")
	await settle()
	check(is_equal_approx(game.camera.size, target_size) and is_equal_approx(game.camera.yaw, start_angle + PI*0.5), "Camera reaches the captured destination")
