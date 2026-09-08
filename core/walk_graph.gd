class_name WalkGraph
extends RefCounted

const Geometry := preload("res://core/world_geometry.gd")
const STEP := 0.25
const EDGE_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, -1),
]
var graph := AStar3D.new()
var solids: Array[Dictionary] = []
var ids: Dictionary = {}

func rebuild(world: Array[Dictionary]) -> void:
	graph.clear()
	ids.clear()
	solids = world
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		for x: int in range(ceili(bounds.position.x / STEP), floori(bounds.end.x / STEP) + 1):
			for z: int in range(ceili(bounds.position.z / STEP), floori(bounds.end.z / STEP) + 1):
				var point := Vector3(x * STEP, bounds.end.y, z * STEP)
				var key := _key(point)
				if not ids.has(key) and Geometry.walkable(point, solids):
					var id := graph.get_available_point_id()
					ids[key] = id
					graph.add_point(id, point)
	for key: Vector3i in ids:
		var id: int = ids[key]
		for offset: Vector3i in EDGE_OFFSETS:
			if ids.has(key + offset):
				var other: int = ids[key + offset]
				if Geometry.clear_segment(graph.get_point_position(id), graph.get_point_position(other), solids):
					graph.connect_points(id, other)

func route(start: Vector3, target: Vector3) -> PackedVector3Array:
	if Geometry.clear_segment(start, target, solids):
		return PackedVector3Array([start, target])
	if graph.get_point_count() == 0:
		return PackedVector3Array()
	var from := _closest_visible(start)
	var to := _closest_visible(target)
	if from < 0 or to < 0:
		return PackedVector3Array()
	var path := graph.get_point_path(from, to)
	if path.is_empty():
		return PackedVector3Array()
	path.insert(0, start)
	path.append(target)
	return _simplify(path)

func _closest_visible(point: Vector3) -> int:
	var closest := -1
	var closest_distance := INF
	for id: int in graph.get_point_ids():
		var candidate := graph.get_point_position(id)
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance and Geometry.clear_segment(point, candidate, solids):
			closest = id
			closest_distance = distance
	return closest

func _simplify(path: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	var index := 0
	result.append(path[index])
	while index < path.size() - 1:
		var next := path.size() - 1
		while next > index + 1 and not Geometry.clear_segment(path[index], path[next], solids):
			next -= 1
		result.append(path[next])
		index = next
	return result

func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / STEP), roundi(point.y * 1000), roundi(point.z / STEP))
