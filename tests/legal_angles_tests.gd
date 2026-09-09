extends SceneTree

const Rules := preload("res://core/mirror_state.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Display := preload("res://core/display_geometry.gd")
const Queries := preload("res://core/solid_queries.gd")
const Navigation := preload("res://core/walk_graph.gd")
const Walker := preload("res://world/walker.gd")
const Game := preload("res://game.gd")
var failures := 0
var checks := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func ramp(angle: float) -> Dictionary:
	var polygons := Display.box_faces(AABB(Vector3(-2,-1,-1), Vector3(4,1,2)))
	var rotation := Basis(Vector3.FORWARD, angle)
	var bounds := AABB()
	var first := true
	for index: int in polygons.size():
		var transformed := PackedVector3Array()
		for point: Vector3 in polygons[index]:
			var value: Vector3 = rotation * point
			bounds = AABB(value, Vector3.ZERO) if first else bounds.expand(value)
			first = false
			transformed.append(value)
		polygons[index] = transformed
	return {"faces":polygons, "bounds":bounds, "kind":"reflected", "id":"ramp"}

func _run() -> void:
	root.size = Vector2i(1152,800)
	for degrees: float in [0, 20, 44, 45, 46, 60]:
		var slope := ramp(deg_to_rad(degrees))
		var points := Queries.floor_points(0, 0, [slope])
		check(not points.is_empty() if degrees <= 45 else points.is_empty(), "Slope limit: %s" % degrees)
		if degrees > 45:
			continue
		check(Geometry.walkable(points[0], [slope]), "Actual slope supports the capsule: %s" % degrees)
		check(Geometry.embedded(points[0] - Vector3.UP * 0.1, [slope]), "Slope penetration rejected: %s" % degrees)
		var a := Queries.floor_points(-0.8, 0, [slope])[0]
		var b := Queries.floor_points(0.8, 0, [slope])[0]
		var nav := Navigation.new()
		nav.rebuild([slope])
		check(not nav.route(a, b).is_empty(), "Slope route connects: %s" % degrees)
	for degrees: float in [20,30,45]:
		var slope := ramp(deg_to_rad(degrees))
		slope["faces"] = Display.clip(slope["faces"], Plane(Vector3.LEFT,0))
		var flat := {"bounds":AABB(Vector3(-2,-1,-1),Vector3(2,1,2)),"kind":"original","id":"flat"}
		var nav := Navigation.new()
		nav.rebuild([flat,slope])
		check(not nav.route(Vector3(-1,0,0), Queries.floor_points(1,0,[slope])[0]).is_empty(), "Flat/slope joint connects: %s" % degrees)
	var gap: Array[Dictionary] = [{"bounds":AABB(Vector3(-2,-1,-1),Vector3(1.9,1,2))}, {"bounds":AABB(Vector3(0.1,-1,-1),Vector3(1.9,1,2))}]
	for solid: Dictionary in gap:
		solid["faces"] = Display.box_faces(solid["bounds"])
	check(not Queries.clear_segment(Vector3(-1,0,0),Vector3(1,0,0),gap), "Convex path cannot cross a gap")
	var overhead: Array[Dictionary] = [{"faces":Display.box_faces(AABB(Vector3(-2,-1,-1),Vector3(4,1,2))),"bounds":AABB(Vector3(-2,-1,-1),Vector3(4,1,2))}, {"bounds":AABB(Vector3(-0.3,0.4,-1),Vector3(0.6,1,2))}]
	check(not Queries.clear_segment(Vector3(-1,0,0),Vector3(1,0,0),overhead), "Convex path rejects low overhead clearance")
	await _physics_ramp()
	game = Game.new()
	root.add_child(game)
	await settle()
	game.begin_preview()
	await settle()
	game.set_edit_mode("rotate")
	await settle()
	game._action("angle_snap", 0.0)
	var initial: Dictionary = game.preview.duplicate(true)
	game._start_rotation({"kind":"turn", "axis":Vector3.UP})
	game._set_rotation_angle(deg_to_rad(13.2))
	game._finish_rotation_drag()
	await settle()
	check(is_equal_approx(game.preview["yaw"], initial["yaw"] + deg_to_rad(13.2)), "No-snap yaw remains legal")
	game._action("angle_snap", 5.0)
	var before: Dictionary = game.preview.duplicate(true)
	game._action("angle_snap", 10.0)
	check(before == game.preview, "Changing snap does not move the mirror")
	game._action("angle_snap", 5.0)
	game._start_rotation({"kind":"turn", "axis":Vector3.UP})
	game._set_rotation_angle(deg_to_rad(3.2))
	game._finish_rotation_drag()
	await settle()
	check(is_equal_approx(rad_to_deg(game.preview["yaw"]), 105.0), "Snap uses absolute five-degree angles")
	game._start_rotation({"kind":"tilt", "axis":Rules.frame(game.preview).x})
	game._set_rotation_angle(deg_to_rad(12))
	game._finish_rotation_drag()
	await settle()
	check(is_equal_approx(rad_to_deg(game.preview["pitch"]), 10), "Pitch release uses selected increment")
	check(game.world.drawn_solids.any(func(solid: Dictionary) -> bool: return solid.has("faces")), "Legal angle keeps polygon geometry after release")
	var frame_before := Rules.frame(game.preview)
	var normal_before := Rules.normal(game.preview)
	game._action("flip", null)
	await settle()
	check(Rules.frame(game.preview).is_equal_approx(frame_before) and Rules.normal(game.preview).is_equal_approx(-normal_before), "Reversal preserves frame and swaps normal")
	for length: float in [4,3,5,3]:
		game.change_preview("height", length)
		await settle()
		var pivot: Vector3 = game.preview["pivot"]
		check(pivot.is_equal_approx(pivot.snapped(Vector3.ONE*0.5)), "Resize settles its centre to world grid")
		check(is_equal_approx(game.preview["height"], length), "Resize keeps whole-unit size")
	var unchanged: Vector3 = game.preview["pivot"]
	var point: Vector2 = game.camera.unproject_position(unchanged)
	game.set_edit_mode("move")
	await settle()
	game._start_drag(point)
	game._drag(point)
	game._finish_drag()
	await settle()
	check(game.preview["pivot"].is_equal_approx(unchanged), "Next drag has no deferred grid correction")
	game.cancel_preview()
	check(game.mirror == {"enabled":false}, "Cancel restores absent mirror")
	game.begin_preview()
	await settle()
	game._start_rotation({"kind":"turn", "axis":Vector3.UP})
	game._set_rotation_angle(deg_to_rad(15))
	game._finish_rotation_drag()
	await settle()
	var proposed_frame := Rules.frame(game.preview)
	check(game.apply_preview(), "An angled mirror can be confirmed")
	await settle()
	check(Rules.frame(game.mirror).is_equal_approx(proposed_frame), "Confirm retains the exact legal frame")
	check(game.world.collision_root.get_children().any(func(body: Node) -> bool: return body.get_child(0).shape is ConvexPolygonShape3D), "Committed angle uses convex collision")
	check(game.undo(), "Angled confirmation can be undone")
	await settle()
	check(game.mirror == {"enabled":false}, "Undo restores state before angled creation")
	game.load_level(0)
	await settle()
	check(game.history.is_empty(), "Reset clears angular history")
	game.queue_free()
	await process_frame
	print("Legal angles: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _physics_ramp() -> void:
	var slope := ramp(deg_to_rad(45))
	slope["faces"] = Display.clip(slope["faces"], Plane(Vector3.LEFT,0))
	var flat := {"bounds":AABB(Vector3(-2,-1,-1),Vector3(2,1,2)),"kind":"original","id":"flat"}
	var flat_body := Queries.body(flat)
	root.add_child(flat_body)
	var floor_body := Queries.body(slope)
	root.add_child(floor_body)
	var actor := Walker.new()
	actor.build_visuals = false
	root.add_child(actor)
	var start := Vector3(-0.8,0,0)
	var finish := Queries.floor_points(0.8, 0, [slope])[0]
	actor.restore(start, Vector3.ZERO)
	for tick: int in 5:
		await physics_frame
	actor.route = Queries.surface_path(start, finish, [flat,slope])
	for tick: int in 100:
		await physics_frame
	check(actor.position.distance_to(finish) < 0.08 and actor.is_on_floor(), "Native capsule crosses downhill joint at 45 degrees")
	actor.route = Queries.surface_path(finish, start, [flat,slope])
	for tick: int in 100:
		await physics_frame
	check(actor.position.distance_to(start) < 0.08 and actor.is_on_floor(), "Native capsule crosses uphill joint at 45 degrees")
	actor.queue_free()
	floor_body.queue_free()
	flat_body.queue_free()
	await process_frame

func settle() -> void:
	for tick: int in 300:
		await physics_frame
		if tick > 5 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	check(false, "Preview settles")
