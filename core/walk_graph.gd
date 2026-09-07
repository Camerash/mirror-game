class_name WalkGraph
extends RefCounted

const Geometry := preload("res://core/world_geometry.gd")
const STEP := 0.25
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
		for offset: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
			if ids.has(key + offset):
				var other: int = ids[key + offset]
				if Geometry.clear_segment(graph.get_point_position(id), graph.get_point_position(other), solids):
					graph.connect_points(id, other)

func route(start: Vector3, target: Vector3) -> PackedVector3Array:
	if graph.get_point_count() == 0 or not Geometry.walkable(target, solids):
		return PackedVector3Array()
	var from := graph.get_closest_point(start)
	var to := graph.get_closest_point(target)
	var from_point := graph.get_point_position(from)
	var to_point := graph.get_point_position(to)
	if not Geometry.clear_segment(start, from_point, solids) or not Geometry.clear_segment(to_point, target, solids):
		return PackedVector3Array()
	var path := graph.get_point_path(from, to)
	if not path.is_empty():
		path.append(target)
	return path

func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / STEP), roundi(point.y * 1000), roundi(point.z / STEP))
