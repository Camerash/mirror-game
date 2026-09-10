class_name SolidQueries
extends RefCounted
## Queries use convex surfaces, not their enclosing boxes.

const Polygons := preload("res://core/display_geometry.gd")
const RADIUS := 0.18
const HEIGHT := 0.8
const FLOOR_Y := 0.70710678
const EPS := 0.0001

static func faces(solid: Dictionary) -> Array:
	return solid["faces"] if solid.has("faces") else Polygons.box_faces(solid["bounds"])

static func plane(face: PackedVector3Array) -> Plane:
	var normal := (face[1] - face[0]).cross(face[2] - face[0]).normalized()
	return Plane(normal, normal.dot(face[0]))

static func contains_face(point: Vector3, face: PackedVector3Array) -> bool:
	var normal := plane(face).normal
	for index: int in face.size():
		var a := face[index]
		var b := face[(index + 1) % face.size()]
		if (b - a).cross(point - a).dot(normal) < -EPS:
			return false
	return true

static func body(solid: Dictionary) -> StaticBody3D:
	var node := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var bounds: AABB = solid["bounds"]
	node.position = bounds.get_center()
	if solid.has("faces"):
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for face: PackedVector3Array in solid["faces"]:
			for point: Vector3 in face:
				points.append(point - node.position)
		shape.points = points
		collider.shape = shape
	else:
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collider.shape = shape
	node.add_child(collider)
	return node

static func ray_hit(origin: Vector3, direction: Vector3, solid: Dictionary) -> Dictionary:
	var entry := 0.0
	var leave := INF
	var normal := Vector3.ZERO
	for face: PackedVector3Array in faces(solid):
		var boundary := plane(face)
		var denominator := boundary.normal.dot(direction)
		var distance := boundary.distance_to(origin)
		if absf(denominator) < EPS:
			if distance > EPS:
				return {}
			continue
		var time := -distance / denominator
		if denominator < 0:
			if time > entry:
				entry = time
				normal = boundary.normal
		else:
			leave = minf(leave, time)
		if entry > leave + EPS:
			return {}
	return {"position": origin + direction * entry, "normal": normal, "distance": entry} if leave >= 0 else {}

static func embedded(feet: Vector3, solids: Array[Dictionary]) -> bool:
	var a := feet + Vector3.UP * RADIUS
	var b := feet + Vector3.UP * (HEIGHT - RADIUS)
	for solid: Dictionary in solids:
		if not (solid["bounds"] as AABB).grow(RADIUS).intersects_segment(a, b):
			continue
		var polygons := faces(solid)
		var inside := true
		for face: PackedVector3Array in polygons:
			if plane(face).distance_to(a) > 0:
				inside = false
			if _segment_face_distance(a, b, face) < RADIUS - 0.002:
				return true
		if inside:
			return true
	return false

static func _segment_face_distance(a: Vector3, b: Vector3, face: PackedVector3Array) -> float:
	var boundary := plane(face)
	var hit: Variant = boundary.intersects_segment(a, b)
	if hit != null and contains_face(hit, face):
		return 0.0
	var distance := INF
	for point: Vector3 in [a, b]:
		var projected := boundary.project(point)
		if contains_face(projected, face):
			distance = minf(distance, absf(boundary.distance_to(point)))
	for index: int in face.size():
		var closest := Geometry3D.get_closest_points_between_segments(a, b, face[index], face[(index + 1) % face.size()])
		distance = minf(distance, closest[0].distance_to(closest[1]))
	return distance

static func floor_points(x: float, z: float, solids: Array[Dictionary], support_world: Array[Dictionary] = []) -> Array[Vector3]:
	var supports := solids if support_world.is_empty() else support_world
	var points: Array[Vector3] = []
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		if x < bounds.position.x - EPS or x > bounds.end.x + EPS or z < bounds.position.z - EPS or z > bounds.end.z + EPS:
			continue
		for face: PackedVector3Array in faces(solid):
			var boundary := plane(face)
			if boundary.normal.y < FLOOR_Y - EPS:
				continue
			var y := (boundary.d - boundary.normal.x * x - boundary.normal.z * z) / boundary.normal.y
			var point := Vector3(x, y, z)
			if contains_face(point, face):
				# A vertical capsule's lowest tip sits above its contact on a slope.
				point.y = _floor_height(point, face, boundary.normal, supports)
				points.append(point)
	return points

static func _floor_height(surface: Vector3, face: PackedVector3Array, normal: Vector3, support_world: Array[Dictionary]) -> float:
	var high := surface.y + RADIUS * (1.0 / normal.y - 1.0)
	var centre := Vector3(surface.x, high + RADIUS, surface.z)
	var contact := centre - normal * RADIUS
	# The capsule contact can cross a fragment join on the same surface.
	if contains_face(contact, face) or _has_coplanar_support(contact, normal, support_world):
		return high
	# At a slope joint the bottom sphere contacts an edge before the face.
	var low := surface.y - RADIUS
	for iteration: int in 14:
		var middle := (low + high) * 0.5
		centre.y = middle + RADIUS
		if _segment_face_distance(centre, centre, face) < RADIUS:
			low = middle
		else:
			high = middle
	return high

static func _has_coplanar_support(contact: Vector3, normal: Vector3, support_world: Array[Dictionary]) -> bool:
	for solid: Dictionary in support_world:
		for face: PackedVector3Array in faces(solid):
			var boundary := plane(face)
			if boundary.normal.distance_to(normal) > EPS or absf(boundary.distance_to(contact)) > EPS:
				continue
			if contains_face(contact, face):
				return true
	return false

static func supported(feet: Vector3, solids: Array[Dictionary]) -> bool:
	for point: Vector3 in floor_points(feet.x, feet.z, solids):
		if absf(point.y - feet.y) < 0.04:
			return true
	return false

static func walkable(feet: Vector3, solids: Array[Dictionary]) -> bool:
	if not supported(feet, solids) or embedded(feet, solids):
		return false
	var r := RADIUS
	var remaining: Array[PackedVector2Array] = [PackedVector2Array([
		Vector2(feet.x-r, feet.z-r), Vector2(feet.x+r, feet.z-r),
		Vector2(feet.x+r, feet.z+r), Vector2(feet.x-r, feet.z+r)])]
	for solid: Dictionary in solids:
		for face: PackedVector3Array in faces(solid):
			var boundary := plane(face)
			if boundary.normal.y < FLOOR_Y - EPS:
				continue
			var projected_y := (boundary.d - boundary.normal.x * feet.x - boundary.normal.z * feet.z) / boundary.normal.y
			var tolerance := RADIUS + 0.04 # Adjacent slopes can cross the footprint at different heights.
			if absf(projected_y - feet.y) > tolerance:
				continue
			var footprint := PackedVector2Array()
			for point: Vector3 in face:
				footprint.append(Vector2(point.x, point.z))
			if Geometry2D.is_polygon_clockwise(footprint):
				footprint.reverse()
			var next: Array[PackedVector2Array] = []
			for polygon: PackedVector2Array in remaining:
				next.append_array(Geometry2D.clip_polygons(polygon, footprint))
			remaining = next
			if remaining.is_empty():
				return true
	return false

static func clear_segment(start: Vector3, finish: Vector3, solids: Array[Dictionary]) -> bool:
	return not surface_path(start, finish, solids).is_empty()

static func surface_path(start: Vector3, finish: Vector3, solids: Array[Dictionary]) -> PackedVector3Array:
	var horizontal := Vector2(finish.x-start.x, finish.z-start.z).length()
	if absf(finish.y-start.y) > horizontal + 0.04:
		return PackedVector3Array()
	var steps := maxi(1, ceili(horizontal / 0.06))
	var previous := start
	var result := PackedVector3Array([start])
	if not walkable(start, solids):
		return PackedVector3Array()
	for index: int in range(1, steps + 1):
		var location := start.lerp(finish, float(index) / steps)
		var nearest := INF
		var selected := Vector3.ZERO
		for candidate: Vector3 in floor_points(location.x, location.z, solids):
			var difference := absf(candidate.y - previous.y)
			if difference < nearest and difference <= horizontal / steps + 0.015 and walkable(candidate, solids):
				nearest = difference
				selected = candidate
		if nearest == INF:
			return PackedVector3Array()
		result.append(selected)
		previous = selected
	if absf(previous.y-finish.y) > 0.04:
		return PackedVector3Array()
	result[-1] = finish
	return result
