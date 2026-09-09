extends RefCounted
const Rings := preload("res://world/mirror_rings.gd")
const Rules := preload("res://core/mirror_state.gd")

static func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.size = Vector2i(900,700)
	var stage := Node3D.new()
	var camera := Camera3D.new()
	var rings := Rings.new()
	tree.root.add_child(stage)
	stage.add_child(camera)
	stage.add_child(rings)
	await tree.process_frame
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(5,5,7)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	camera.force_update_transform()
	var state := Rules.normalized({"axis":0,"source":1,"pivot":Vector3.ZERO,"enabled":true,"width":3.0,"height":3.0})
	rings.set_state(state,true,false)
	rings.set_layout(Rect2(0,0,900,700),[Rect2(0,0,100,100)])
	rings.update_view(camera)
	var yaw: Dictionary = rings._arcs[0].duplicate(true)
	var pitch: Dictionary = rings._arcs[1].duplicate(true)
	check.call(is_equal_approx(yaw["radius"],1.85) and is_equal_approx(pitch["radius"],1.85), "Rings use panel dimensions plus gap")
	check.call(yaw["axis"] == Vector3.UP and pitch["axis"].is_equal_approx(Rules.frame(state).x), "Ring axes match yaw and local pitch")
	for ring: Dictionary in [yaw,pitch]:
		for angle: float in [0.0,0.7,2.1]:
			var offset := Rings.world_point(ring,angle) - (ring["pivot"] as Vector3)
			check.call(absf(offset.dot(ring["axis"])) < 0.0001, "Ring points remain on their 3D rotation plane")
			check.call(Rings.screen_point(ring,angle).distance_to(camera.unproject_position(Rings.world_point(ring,angle))) < 0.01, "Ring projection matches world geometry")
	var angles: Array[float] = []
	rings.action_requested.connect(func(action: String,value: Variant) -> void:
		if action == "rotation_angle": angles.append(float(value)))
	var start := Rings.screen_point(yaw,0.7)
	check.call(rings.pointer(start,true,4) and rings._drag["kind"] == "turn", "Nearest projected ring captures input")
	rings.motion(start,4)
	check.call(is_zero_approx(angles.back()), "Press does not change the angle")
	for step: int in range(1,18): rings.motion(Rings.screen_point(yaw,0.7+step*0.5),4)
	check.call(is_equal_approx(angles.back(),8.5), "Pointer angle wraps over repeated turns")
	rings.motion(Rings.screen_point(yaw,0.7+8.0),4)
	check.call(is_equal_approx(angles.back(),8.0), "Reverse travel reverses rotation")
	var captured := rings.get_arc_points("turn")
	rings.set_pose(Transform3D(Basis(Vector3.UP,0.8),Vector3(2,2,2)))
	rings.set_state(state.merged({"width":6.0},true),true,true)
	check.call(rings.get_arc_points("turn") == captured and rings.get_arc_points("tilt").is_empty(), "Gesture freezes the selected ring and hides the other")
	check.call(rings.pointer(Vector2(-50,-50),false,4), "Release outside retains pointer ownership")
	rings.set_pose(Transform3D(Rules.frame(state),Vector3.ZERO))
	rings.set_state(state.merged({"width":6.0,"height":6.0},true),true,false)
	check.call(is_equal_approx(rings._arcs[0]["radius"],3.35), "Resizing grows the ring")
	# Edge-on pitch: camera looks along the plane, so use its captured tangent.
	camera.position = Vector3(6,4,0)
	camera.look_at(Vector3.ZERO)
	camera.force_update_transform()
	rings.set_state(state,true,false)
	rings.update_view(camera)
	pitch = rings._arcs[1].duplicate(true)
	check.call(pitch["edge_on"], "Edge-on pitch selects tangent input")
	start = Rings.screen_point(pitch,0.8)
	check.call(rings.pointer(start,true,7) and rings._drag["kind"] == "tilt", "Edge-on pitch ring accepts input")
	var tangent: Vector2 = rings._drag["tangent"]
	rings.motion(start+tangent*float(pitch["pixel_radius"]),7)
	check.call(is_equal_approx(angles.back(),1.0), "One projected radius requests one radian")
	rings.motion(start-tangent*float(pitch["pixel_radius"]),7)
	check.call(is_equal_approx(angles.back(),-1.0), "Edge-on input supports reversal")
	rings.pointer(start,false,7)
	rings.set_state(state.merged({"pitch":PI/2},true),true,false)
	check.call(rings.get_arc_points("turn").is_empty() and not rings.get_arc_points("tilt").is_empty(), "Horizontal mirror keeps only pitch")
	tree.root.size = Vector2i(390,844)
	await tree.process_frame
	camera.size = 20
	rings.set_layout(Rect2(0,0,390,844),[Rect2(0,740,390,104)])
	rings.set_state(state.merged({"width":1.0,"height":1.0},true),true,false)
	rings.update_view(camera)
	check.call(is_equal_approx(rings._arcs[0]["pixel_radius"],48.0), "Small portrait rings retain minimum touch scale")
	var blocked := Rings.screen_point(rings._arcs[0],0.5)
	rings.set_layout(Rect2(0,0,390,844),[Rect2(blocked-Vector2(30,30),Vector2(60,60))])
	check.call(not rings.blocks_point(blocked) and not rings.pointer(blocked,true,8), "HUD blocks ring input without relocating the ring")
	stage.queue_free()
	await tree.process_frame
