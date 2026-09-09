extends SceneTree
const Targets := preload("res://core/mirror_targets.gd")
const Rules := preload("res://core/mirror_state.gd")
const Game := preload("res://game.gd")
const Rings := preload("res://world/mirror_rings.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var limits := {"min":[-4,-4,-4],"max":[4,4,4]}
	var centre := Vector3(0.2,0.5,0.3)
	var ground := Targets.position_dots(centre,centre,limits,false)
	check(not ground.is_empty(), "Ground has nearby legal targets")
	for dot: Dictionary in ground:
		var point: Vector3 = dot["position"]
		check(point.y == 0.5 and point.x == snappedf(point.x,0.5) and point.z == snappedf(point.z,0.5) and point.distance_to(centre) < 2, "Ground dots stay on the captured world lattice")
	var vertical := Targets.position_dots(centre,centre,limits,true)
	for dot: Dictionary in vertical:
		var point: Vector3 = dot["position"]
		check(point.x == centre.x and point.z == centre.z and point.y == snappedf(point.y,0.5), "Height dots stay on the captured column")
	check(Targets.spatial_weight(0) > Targets.spatial_weight(1) and Targets.spatial_weight(2) == 0, "Distance fades the dots to zero")
	var state := Rules.normalized({"enabled":true,"axis":2,"source":1,"pivot":Vector3.ZERO,"width":3,"height":3})
	state = Rules.rotated(state,"turn",deg_to_rad(35))
	var resized := Targets.resize_state(state,"width",5,limits)
	var expected: Vector3 = Rules.snapped_pivot(Rules.resized(state,"width",5)["pivot"],limits)
	check(resized["pivot"] == expected, "Resize shares the world-centre correction")
	var edge: Vector3 = Targets.edge_position(resized,"width")
	var found := false
	for dot: Dictionary in Targets.resize_dots(state,resized,"width",limits):
		found = found or (dot["position"] as Vector3).is_equal_approx(edge)
	check(found, "Angled resize includes the actual selected edge location")
	check(Targets.rotation_angles(0,0).is_empty(), "No snap has no discrete angle dots")
	var angle := deg_to_rad(725)
	for dot: Dictionary in Targets.rotation_angles(angle,deg_to_rad(25)):
		check(absf(float(dot["angle"])-angle) < PI and is_equal_approx(float(dot["angle"]),snappedf(float(dot["angle"]),deg_to_rad(25))), "Angle dots use legal unwrapped targets across multiple turns")
	await _integration()
	print("Constellation checks: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _settle(game: Node3D) -> void:
	for tick: int in 300:
		await physics_frame
		if tick > 5 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending": return
	check(false,"Interaction settles")

func _integration() -> void:
	root.size = Vector2i(1152,800)
	var game := Game.new()
	root.add_child(game)
	await _settle(game)
	game.begin_preview()
	await _settle(game)
	var point := Vector2.INF
	for y: int in range(80,700,12):
		for x: int in range(40,1100,12):
			if game.sheet_hit(Vector2(x,y)):
				point = Vector2(x,y)
				break
		if point.is_finite(): break
	check(point.is_finite(),"A visible sheet press can be found")
	var before: Dictionary = game.preview.duplicate(true)
	var collision: Array = game.solids.duplicate(true)
	game._pointer(point,true,9)
	check(game.guide_kind == "ground" and not game.dragging, "Sheet press shows guides before starting movement")
	check(game.preview == before and game.solids == collision and game.history.is_empty(), "Guide display leaves world and history unchanged")
	game.gesture.advance(0.5)
	game._pointer(point,false,9)
	await create_timer(0.25).timeout
	check(game.placement_guide.get_visible_marks().is_empty() and game.phase == "preview", "Held release fades without confirming")
	game.set_edit_mode("rotate")
	await _settle(game)
	var ring := game.rings.get_ring_frame("turn")
	var captured := false
	for index: int in 48:
		var position := Rings.screen_point(ring,TAU*index/48)
		if game.rings.pointer(position,true,9):
			captured = true
			break
	check(captured and game.guide_kind in ["turn","tilt"],"Ring capture shows angle guides")
	game.cancel_preview()
	check(game.guide_kind.is_empty() and game.placement_guide.get_visible_marks().is_empty(),"Cancel clears guides immediately")
	await _settle(game)
	game.begin_preview()
	await _settle(game)
	game.set_edit_mode("resize")
	await _settle(game)
	var pill: Rect2 = game.resize_controls.get_control_rects()["width"]
	game.resize_controls.pointer(pill.get_center(),true,9)
	game._set_resize_length(4)
	await create_timer(0.15).timeout
	var visual: Rect2 = game.resize_controls.get_visual_rects()[0]
	var edge_screen: Vector2 = game.camera.unproject_position(Targets.edge_position(game._display_state(),"width"))
	check(visual.has_point(edge_screen),"Pill occlusion follows its displayed position during resizing")
	var hidden := true
	for mark: Dictionary in game.placement_guide.get_visible_marks():
		hidden = hidden and not visual.has_point(mark["screen"])
	check(hidden,"Markers do not draw over the moving pill")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.guide_kind.is_empty() and game.placement_guide.get_visible_marks().is_empty(),"Focus loss clears active guides")
	game.queue_free()
	await process_frame
