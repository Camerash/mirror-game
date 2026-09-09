extends RefCounted

const Rings := preload("res://world/mirror_rings.gd")

static func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(900, 700)
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
	rings.set_layout(Rect2(Vector2.ZERO, tree.root.size), [Rect2(0, 0, 120, 80)])
	rings.set_state(state, true, false)
	rings.update_view(camera)
	var turn := rings.get_arc_points("turn")
	check.call(turn.size() == 25, "Turn arc is visible while rotation mode is active")
	var center := Vector2(turn[12].x, turn[0].y)
	check.call(is_equal_approx(turn[0].distance_to(center), 64.0) and is_equal_approx(turn[12].distance_to(center), 64.0), "Turn arc keeps a 64 logical-unit radius")
	camera.size = 16.0
	rings.update_view(camera)
	turn = rings.get_arc_points("turn")
	center = Vector2(turn[12].x, turn[0].y)
	check.call(is_equal_approx(turn[0].distance_to(center), 64.0), "Turn arc size does not follow camera scale")
	check.call(not rings.blocks_point(Vector2(20, 20)), "HUD exclusions do not become world-obstruction checks")
	var controls := rings.get_control_rects()
	check.call(not (controls["turn"] as Rect2).intersects(Rect2(0, 0, 120, 80)) and not (controls["tilt"] as Rect2).intersects(Rect2(0, 0, 120, 80)), "Arc layout keeps touch regions outside HUD exclusions")
	for sample: int in [1, 12, 23]:
		check.call(rings.pointer(turn[sample], true, sample), "Any visible turn arc point starts a drag")
		check.call(rings.pointer(Vector2(-50, -50), false, sample), "A captured drag releases outside its arc")
	var actions: Array[String] = []
	var angles: Array[float] = []
	rings.action_requested.connect(func(action: String, value: Variant) -> void:
		actions.append(action)
		if action == "rotation_angle":
			angles.append(float(value)))
	check.call(rings.pointer(turn[2], true, 9), "Turn arc captures its pointer")
	for angle: float in [0.8, 1.6, 2.4, -3.08, -2.28, -1.48, -0.68, 0.12, 0.92]:
		rings.motion(center + Vector2(cos(angle), sin(angle)) * 64.0, 9)
	var forward: float = angles.back()
	rings.motion(center + Vector2(cos(0.12), sin(0.12)) * 64.0, 9)
	check.call(forward > TAU and angles.back() < forward, "Drag travel wraps through repeated turns and reverses without a jump")
	var count := angles.size()
	rings.motion(center, 9)
	check.call(angles.size() == count, "Samples near the arc centre do not change rotation")
	check.call(rings.pointer(Vector2(-50, -50), false, 9) and actions.back() == "rotation_end", "Release emits rotation_end after an owned drag")
	rings.set_state(state.merged({"yaw": 0.0, "pitch": PI * 0.5}, true), true, false)
	rings.update_view(camera)
	check.call(rings.get_arc_points("turn").is_empty() and not rings.get_arc_points("tilt").is_empty(), "Turn arc hides for a horizontal mirror")
	tree.root.size = Vector2i(390, 844)
	await tree.process_frame
	var portrait_safe := Rect2(0, 0, 390, 844)
	var portrait_excluded: Array[Rect2] = [Rect2(330, 16, 44, 44), Rect2(0, 760, 390, 84)]
	rings.set_layout(portrait_safe, portrait_excluded)
	rings.set_state(state.merged({"width": 1.0, "height": 1.0}, true), true, false)
	rings.update_view(camera)
	var small := rings.get_arc_points("turn")
	var small_center := Vector2(small[12].x, small[0].y)
	rings.set_state(state.merged({"width": 6.0, "height": 6.0}, true), true, false)
	rings.update_view(camera)
	var large := rings.get_arc_points("turn")
	var large_center := Vector2(large[12].x, large[0].y)
	check.call(is_equal_approx(small[0].distance_to(small_center), 64.0) and is_equal_approx(large[0].distance_to(large_center), 64.0), "Portrait arcs keep their radius for small and large panels")
	controls = rings.get_control_rects()
	var turn_rect: Rect2 = controls["turn"]
	var tilt_rect: Rect2 = controls["tilt"]
	check.call(portrait_safe.encloses(turn_rect) and portrait_safe.encloses(tilt_rect) and not turn_rect.intersects(tilt_rect), "Portrait touch regions stay in the safe area and apart")
	check.call(not turn_rect.intersects(portrait_excluded[0]) and not tilt_rect.intersects(portrait_excluded[0]) and not turn_rect.intersects(portrait_excluded[1]) and not tilt_rect.intersects(portrait_excluded[1]), "Portrait arcs avoid gear and bottom actions")
	check.call(rings.pointer(large[12], true, 19), "Portrait turn arc starts a drag")
	var frozen := rings.get_arc_points("turn")
	rings.set_pose(Transform3D(Basis.IDENTITY, Vector3(12, 4, -8)))
	rings.update_view(camera)
	var during_drag := rings.get_arc_points("turn")
	check.call(frozen[0].is_equal_approx(during_drag[0]) and frozen[12].is_equal_approx(during_drag[12]) and frozen[24].is_equal_approx(during_drag[24]), "Active portrait drag keeps arc geometry fixed")
	rings.pointer(Vector2(-50, -50), false, 19)
	stage.queue_free()
	await tree.process_frame
