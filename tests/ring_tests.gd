extends SceneTree

const Rings := preload("res://world/mirror_rings.gd")

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
	rings._pitch["visible"] = false
	rings._yaw["orb_angle"] = 0.0
	rings._refresh()
	var actions: Array[String] = []
	rings.action_requested.connect(func(action: String, _value: Variant) -> void: actions.append(action))
	var point := camera.unproject_position(Vector3.RIGHT * Rings.RADIUS)
	check.call(rings.pointer(point, true, 0) and rings.owns_pointer(0), "The visible world orb captures its pointer")
	rings.motion(camera.unproject_position(Vector3.ZERO), 0)
	check.call(actions == ["rotation_begin"], "The ring dead centre does not change drag angle")
	for angle: float in [PI * 0.6, -PI * 0.8, -PI * 0.2, PI * 0.4]:
		var location := (Vector3.RIGHT * cos(angle) + Vector3.FORWARD * sin(angle)) * Rings.RADIUS
		rings.motion(camera.unproject_position(location), 0)
	check.call(actions.count("turn") == 4, "One ring gesture emits repeated wrapped quarter turns")
	check.call(rings.pointer(Vector2(-50, -50), false, 0) and not rings.is_active() and actions.back() == "rotation_end", "Release outside ends the captured ring gesture")
	stage.queue_free()
	await tree.process_frame
