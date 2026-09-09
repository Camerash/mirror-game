extends SceneTree

const Rings := preload("res://world/mirror_rings.gd")
const Resize := preload("res://ui/mirror_resize.gd")

var _failed := false

func _initialize() -> void:
	_run_standalone.call_deferred()

func _run_standalone() -> void:
	run(func(condition: bool, description: String) -> void:
		if not condition:
			_failed = true
			push_error("FAIL: " + description))
	await _test_pointer(func(condition: bool, description: String) -> void:
		if not condition:
			_failed = true
			push_error("FAIL: " + description))
	quit(1 if _failed else 0)

static func run(check: Callable) -> void:
	check.call(is_equal_approx(Rings.angular_delta(PI * 0.9, -PI * 0.9), PI * 0.2), "Ring angles cross the signed wrap")
	check.call(Rings.quarter_steps(PI * 0.5 - 0.001) == 0 and Rings.quarter_steps(PI * 0.5) == 1, "Ring emits at a quarter turn")
	check.call(Rings.quarter_steps(-PI) == -2, "Ring preserves reverse quarter turns")
	var state := {"axis": 0, "source": 1, "pivot": Vector3(2, 3, 4), "frame_up": Vector3.UP}
	var axes := Rings.ring_axes(state)
	check.call(axes["yaw"] == Vector3.UP and axes["pitch"] == Vector3.FORWARD, "Ring axes use the world yaw and mirror frame pitch")
	var rings := Rings.new()
	rings.set_state(state.merged({"enabled": true}), true, false)
	rings._drag_ring = rings._yaw.duplicate(true)
	rings._active = true
	rings.set_state(state.merged({"axis": 2, "enabled": true}), true, false)
	check.call(rings._drag_ring["axis"] == Vector3.UP and rings.is_active(), "An active ring captures its axis while state changes")
	var captured_center: Vector3 = rings._drag_ring["center"]
	rings.set_pose(Transform3D(Basis.IDENTITY, Vector3(4, 0, 0)))
	check.call(rings._yaw["center"] == Vector3(4, 0, 0) and rings._drag_ring["center"] == captured_center, "Active ring visuals follow the sheet pose without changing the drag capture")
	rings.set_state(state.merged({"enabled": true, "width": 6, "height": 2}), true, true)
	var pose := Transform3D(Basis(Vector3.UP, 0.4), Vector3(4, 0, 0))
	rings.set_pose(pose)
	check.call(rings._orb_point(rings._yaw).is_equal_approx(pose.origin + pose.basis.x * float(rings._yaw["radius"]) * rings._yaw["edge_sign"]), "Yaw knob follows the animated width edge and gap after resizing")
	check.call(rings._orb_point(rings._pitch).is_equal_approx(pose.origin + pose.basis.y * float(rings._pitch["radius"]) * rings._pitch["edge_sign"]), "Pitch knob follows the animated height edge and gap after resizing")
	for visual: MeshInstance3D in [rings._yaw_near, rings._yaw_far, rings._pitch_near, rings._pitch_far, rings._yaw_orb, rings._pitch_orb]:
		visual.free()
	rings.free()

static func _test_pointer(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var stage := Node3D.new()
	var camera := Camera3D.new()
	var rings := Rings.new()
	tree.root.add_child(stage)
	stage.add_child(camera)
	stage.add_child(rings)
	await tree.process_frame
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0, 5, 7)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	camera.force_update_transform()
	var state := {"axis": 0, "source": 1, "pivot": Vector3.ZERO, "frame_up": Vector3.UP, "enabled": true}
	rings.set_state(state, true, false)
	rings.update_view(camera)
	var resize := Resize.new()
	resize.set_state(state, true, false)
	var width_anchor := camera.unproject_position(Vector3.FORWARD * 1.5)
	var height_anchor := camera.unproject_position(Vector3.UP * 1.5)
	resize.update_view(camera, Rect2(-200, -200, 2000, 2000), [], PackedVector2Array([width_anchor, height_anchor]))
	var resize_rects := resize.get_control_rects()
	check.call(resize_rects.has("width") and resize_rects.has("height") and resize_rects.has("height_move"), "Direct edge resize pills and the separate height-move control stay available")
	if not resize_rects.has("width"):
		stage.queue_free()
		await tree.process_frame
		return
	var resize_actions: Array[String] = []
	resize.action_requested.connect(func(action: String, _value: Variant) -> void: resize_actions.append(action))
	var resize_point: Vector2 = resize_rects["width"].get_center()
	check.call(resize_point.is_equal_approx(width_anchor), "The width resize pill stays at the local positive-width edge")
	resize.pointer(resize_point, true, 3)
	resize.set_state(state, true, true)
	check.call(resize.is_active() and resize.owns_pointer(3), "Busy state does not cancel an active resize pointer")
	resize.pointer(Vector2(-50, -50), false, 3)
	resize.set_state(state, true, false)
	var height_move_point: Vector2 = resize_rects["height_move"].get_center()
	resize.pointer(height_move_point, true, 4)
	resize.motion(height_move_point + Vector2.UP, 4)
	resize.pointer(Vector2(-50, -50), false, 4)
	check.call(resize_actions.has("move_height_begin") and resize_actions.has("move_height_move") and resize_actions.back() == "move_height_end", "Height move keeps its own pointer and action contract")
	resize.free()
	rings._pitch["visible"] = false
	rings._refresh()
	var actions: Array[String] = []
	var rotation_begin := {}
	var rotation_angles: Array[float] = []
	rings.action_requested.connect(func(action: String, value: Variant) -> void:
		actions.append(action)
		if action == "rotation_begin":
			rotation_begin.merge(value, true)
		elif action == "rotation_angle":
			rotation_angles.append(float(value)))
	var point := camera.unproject_position(rings._orb_point(rings._yaw))
	check.call(rings.pointer(point, true, 0) and rings.owns_pointer(0), "The visible world orb captures its pointer")
	check.call(rotation_begin["kind"] == "turn" and rotation_begin["axis"] == Vector3.UP, "The ring captures its world turn axis at gesture start")
	rings.motion(camera.unproject_position(Vector3.ZERO), 0)
	check.call(actions == ["rotation_begin"], "The ring dead centre does not change drag angle")
	for angle: float in [-0.5, 0.5, 1.5, 2.5, -2.78, -1.78, -0.78]:
		rings.motion(camera.unproject_position(rings._ring_point(rings._yaw, angle)), 0)
	check.call(actions.count("rotation_angle") == 7 and absf(rotation_angles.back()) > PI, "One ring gesture emits continuous unwrapped angles")
	check.call(rings.pointer(Vector2(-50, -50), false, 0) and not rings.is_active() and actions.back() == "rotation_end", "Release outside ends the captured ring gesture")
	rings.is_obstructed = func(_point: Vector2, _location: Vector3) -> bool: return true
	var edge_sign: int = rings._yaw["edge_sign"]
	rings.choose_edge_ends()
	rings.choose_edge_ends()
	check.call(rings._yaw["edge_sign"] == edge_sign, "Two blocked edge intersections do not cause orb switching")
	stage.queue_free()
	await tree.process_frame
