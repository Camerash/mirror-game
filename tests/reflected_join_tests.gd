extends SceneTree

const Display := preload("res://core/display_geometry.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const Queries := preload("res://core/solid_queries.gd")
const Graph := preload("res://core/walk_graph.gd")
const Rules := preload("res://core/mirror_state.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	_check_reflected_row()
	_check_coplanar_support()
	_check_rejections()
	_check_closed_caps()
	print("Reflected joins: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_reflected_row() -> void:
	var level := Levels.load_level("res://levels/01_route.json")
	var state := Rules.normalized(level["mirror"])
	state["enabled"] = true
	state = Rules.rotated(state, "tilt", deg_to_rad(15))
	var split := Geometry.generate(level, state)
	var merged_level := level.duplicate(true)
	merged_level["originals"] = [{"id":"merged", "center":[1,-0.5,0], "size":[3,1,1]}]
	var merged := Geometry.generate(merged_level, state)
	var split_start := _highest_floor(3.25, split)
	var split_finish := _highest_floor(4.25, split)
	var merged_start := _highest_floor(3.25, merged)
	var merged_finish := _highest_floor(4.25, merged)
	check(split_start.is_equal_approx(merged_start) and split_finish.is_equal_approx(merged_finish), "Split reflected row matches merged floor heights")
	check(not Queries.surface_path(split_start, split_finish, split).is_empty(), "Split reflected row crosses its join forward")
	check(not Queries.surface_path(split_finish, split_start, split).is_empty(), "Split reflected row crosses its join backward")
	check(_highest_floor(4.0, split).is_equal_approx(_highest_floor(4.0, merged)), "Support height agrees at the block join")
	var navigation := Graph.new()
	navigation.rebuild(split)
	var joined_point := _highest_floor(4.0, merged)
	check(Array(navigation.graph.get_point_ids()).any(func(id: int) -> bool: return navigation.graph.get_point_position(id).is_equal_approx(joined_point)), "Walking graph includes continuous support at the join")

func _check_coplanar_support() -> void:
	var pieces := _split_ramp()
	var right: Dictionary = pieces[1]
	var single := Queries.floor_points(0.05, 0.0, [right])[0]
	var joined := Queries.floor_points(0.05, 0.0, [right], pieces)[0]
	var floor_face := _floor_face(right)
	var boundary := Queries.plane(floor_face)
	var normal := boundary.normal
	var surface := Vector3(0.05, (boundary.d - normal.x * 0.05) / normal.y, 0.0)
	var ideal := surface.y + Queries.RADIUS * (1.0 / normal.y - 1.0)
	check(absf(joined.y - ideal) < Queries.EPS and joined.y > single.y + Queries.EPS, "Coplanar neighbour restores ideal capsule support")

func _check_rejections() -> void:
	var gap: Array[Dictionary] = [
		{"faces":Display.box_faces(AABB(Vector3(-2,-1,-1), Vector3(1.9,1,2))), "bounds":AABB(Vector3(-2,-1,-1), Vector3(1.9,1,2))},
		{"faces":Display.box_faces(AABB(Vector3(0.1,-1,-1), Vector3(1.9,1,2))), "bounds":AABB(Vector3(0.1,-1,-1), Vector3(1.9,1,2))},
	]
	var overhead: Array[Dictionary] = [
		{"faces":Display.box_faces(AABB(Vector3(-2,-1,-1), Vector3(4,1,2))), "bounds":AABB(Vector3(-2,-1,-1), Vector3(4,1,2))},
		{"bounds":AABB(Vector3(-0.3,0.4,-1), Vector3(0.6,1,2))},
	]
	check(not Queries.clear_segment(Vector3(-1,0,0), Vector3(1,0,0), gap), "A gap remains blocked")
	check(not Queries.clear_segment(Vector3(-1,0,0), Vector3(1,0,0), overhead), "Low overhead remains blocked")
	var steep := _ramp(deg_to_rad(46))
	check(Queries.floor_points(0, 0, [steep]).is_empty(), "Slopes above 45 degrees remain blocked")

func _check_closed_caps() -> void:
	var faces := Display.clip(Display.box_faces(AABB(Vector3(-1,-1,-1), Vector3(2,2,2))), Plane(Vector3(1, 2, 3).normalized(), 0.2))
	var edges := {}
	for face: PackedVector3Array in faces:
		for index: int in face.size():
			var a := Vector3i(roundi(face[index].x * 10000.0), roundi(face[index].y * 10000.0), roundi(face[index].z * 10000.0))
			var b := Vector3i(roundi(face[(index + 1) % face.size()].x * 10000.0), roundi(face[(index + 1) % face.size()].y * 10000.0), roundi(face[(index + 1) % face.size()].z * 10000.0))
			var key := str(a) + str(b) if str(a) < str(b) else str(b) + str(a)
			edges[key] = int(edges.get(key, 0)) + 1
	check(edges.values().all(func(count: int) -> bool: return count == 2), "Clipped fragment caps have paired edges")

func _split_ramp() -> Array[Dictionary]:
	var faces: Array = _ramp(deg_to_rad(30))["faces"]
	return [_solid(Display.clip(faces, Plane(Vector3.RIGHT, 0))), _solid(Display.clip(faces, Plane(Vector3.LEFT, 0)))]

func _ramp(angle: float) -> Dictionary:
	var faces := Display.box_faces(AABB(Vector3(-2,-1,-1), Vector3(4,1,2)))
	var rotation := Basis(Vector3.FORWARD, angle)
	for index: int in faces.size():
		var transformed := PackedVector3Array()
		for point: Vector3 in faces[index]:
			transformed.append(rotation * point)
		faces[index] = transformed
	return _solid(faces)

func _solid(faces: Array) -> Dictionary:
	var bounds := AABB((faces[0] as PackedVector3Array)[0], Vector3.ZERO)
	for face: PackedVector3Array in faces:
		for point: Vector3 in face:
			bounds = bounds.expand(point)
	return {"faces":faces, "bounds":bounds}

func _highest_floor(x: float, world: Array[Dictionary]) -> Vector3:
	var result := Vector3.ZERO
	for point: Vector3 in Queries.floor_points(x, 0.0, world):
		if point.y > result.y or result == Vector3.ZERO:
			result = point
	return result

func _floor_face(solid: Dictionary) -> PackedVector3Array:
	for face: PackedVector3Array in Queries.faces(solid):
		if Queries.plane(face).normal.y >= Queries.FLOOR_Y:
			return face
	return PackedVector3Array()
