class_name MirrorDisplayGeometry
extends RefCounted
## Closed convex fragments for continuous visual previews. Never used for collision.

const Geometry := preload("res://core/world_geometry.gd")
const EPS := 0.00001

static func generate(level: Dictionary, state: Dictionary, frame: Basis) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var pivot: Vector3 = state["pivot"]
	var normal := frame.z.normalized()
	var reflection := Transform3D(Basis(Vector3.RIGHT - 2.0 * normal * normal.x,
		Vector3.UP - 2.0 * normal * normal.y, Vector3.BACK - 2.0 * normal * normal.z),
		2.0 * normal * normal.dot(pivot))
	var source := column(pivot, frame, state, false)
	var destination := column(pivot, frame, state, true)
	var absolutes: Array = []
	for item: Dictionary in level["absolutes"]:
		var bounds := Geometry.box(item)
		absolutes.append(box_planes(bounds))
		_append(output, box_faces(bounds), item, "absolute", Transform3D.IDENTITY, "0")
		output[-1].erase("faces")
	for item: Dictionary in level["originals"]:
		var faces := box_faces(Geometry.box(item))
		var retained := subtract(faces, destination)
		_emit_fragments(output, retained, item, "original", Transform3D.IDENTITY, absolutes)
		var selected := intersect(faces, source)
		if not selected.is_empty():
			var reflected: Array = []
			for face: PackedVector3Array in selected:
				var transformed := PackedVector3Array()
				for vertex: Vector3 in face:
					transformed.append(reflection * vertex)
				transformed.reverse()
				reflected.append(transformed)
			_emit_fragments(output, [reflected], item, "reflected", reflection, absolutes)
	return output

static func column(pivot: Vector3, frame: Basis, state: Dictionary, reverse: bool) -> Array[Plane]:
	var normal := -frame.z if reverse else frame.z
	var planes: Array[Plane] = [Plane(normal, normal.dot(pivot))]
	for pair: Array in [[frame.x, float(state.get("width", 3))], [frame.y, float(state.get("height", 3))]]:
		var axis: Vector3 = pair[0]
		for sign_value: float in [-1.0, 1.0]:
			planes.append(Plane(axis * sign_value, (axis * sign_value).dot(pivot) + float(pair[1]) * 0.5))
	return planes

static func box_planes(bounds: AABB) -> Array[Plane]:
	var planes: Array[Plane] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		planes.append(Plane(axis, axis.dot(bounds.end)))
		planes.append(Plane(-axis, (-axis).dot(bounds.position)))
	return planes

static func box_faces(bounds: AABB) -> Array:
	var faces: Array = []
	var centre := bounds.get_center()
	for axis_index: int in 3:
		var normal := Vector3.ZERO
		normal[axis_index] = 1.0
		var u := Vector3.ZERO
		u[(axis_index + 1) % 3] = 1.0
		var v := normal.cross(u)
		for sign_value: float in [-1.0, 1.0]:
			var face := PackedVector3Array()
			for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				face.append(centre + normal * sign_value * bounds.size[axis_index] * 0.5
					+ u * corner.x * bounds.size[(axis_index + 1) % 3] * 0.5
					+ v * corner.y * bounds.size[(axis_index + 2) % 3] * 0.5)
			if sign_value < 0:
				face.reverse()
			faces.append(face)
	return faces

static func intersect(faces: Array, planes: Array[Plane]) -> Array:
	var result := faces
	for plane: Plane in planes:
		result = clip(result, plane)
		if result.is_empty():
			break
	return result

static func subtract(faces: Array, planes: Array[Plane]) -> Array:
	var result: Array = []
	var remaining := faces
	for plane: Plane in planes:
		var outside := clip(remaining, Plane(-plane.normal, -plane.d))
		if volume(outside) > EPS:
			result.append(outside)
		remaining = clip(remaining, plane)
		if remaining.is_empty():
			break
	return result

static func clip(faces: Array, plane: Plane) -> Array:
	var result: Array = []
	var cut := PackedVector3Array()
	var has_inside := false
	var has_outside := false
	for face: PackedVector3Array in faces:
		for point: Vector3 in face:
			has_inside = has_inside or plane.distance_to(point) < -EPS
			has_outside = has_outside or plane.distance_to(point) > EPS
	if not has_outside:
		return faces
	if not has_inside:
		return []
	for face: PackedVector3Array in faces:
		var polygon := PackedVector3Array()
		for index: int in face.size():
			var a := face[index]
			var b := face[(index + 1) % face.size()]
			var da := plane.distance_to(a)
			var db := plane.distance_to(b)
			if da <= EPS:
				_unique(polygon, a)
				if absf(da) <= EPS:
					_unique(cut, a)
			if (da < -EPS and db > EPS) or (da > EPS and db < -EPS):
				var crossing := a.lerp(b, da / (da - db))
				_unique(polygon, crossing)
				_unique(cut, crossing)
		if polygon.size() >= 3:
			result.append(polygon)
	if cut.size() >= 3:
		result.append(_ordered_cap(cut, plane.normal))
	return result

static func _unique(points: PackedVector3Array, point: Vector3) -> void:
	for existing: Vector3 in points:
		if existing.distance_squared_to(point) < EPS * EPS:
			return
	points.append(point)

static func _ordered_cap(points: PackedVector3Array, normal: Vector3) -> PackedVector3Array:
	var centre := Vector3.ZERO
	for point: Vector3 in points:
		centre += point
	centre /= points.size()
	var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := normal.cross(u)
	var sorted: Array = Array(points)
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return atan2((a-centre).dot(v), (a-centre).dot(u)) < atan2((b-centre).dot(v), (b-centre).dot(u)))
	return PackedVector3Array(sorted)

static func volume(faces: Array) -> float:
	var result := 0.0
	for face: PackedVector3Array in faces:
		for index: int in range(1, face.size() - 1):
			result += face[0].dot(face[index].cross(face[index + 1])) / 6.0
	return absf(result)

static func _emit_fragments(output: Array[Dictionary], fragments: Array, item: Dictionary, kind: String, transform: Transform3D, absolutes: Array) -> void:
	var remaining := fragments
	for planes: Array[Plane] in absolutes:
		var next: Array = []
		for faces: Array in remaining:
			next.append_array(subtract(faces, planes))
		remaining = next
	for index: int in remaining.size():
		_append(output, remaining[index], item, kind, transform, str(index))

static func _append(output: Array[Dictionary], faces: Array, item: Dictionary, kind: String, transform: Transform3D, suffix: String) -> void:
	if volume(faces) <= EPS:
		return
	var bounds := AABB((faces[0] as PackedVector3Array)[0], Vector3.ZERO)
	for face: PackedVector3Array in faces:
		for point: Vector3 in face:
			bounds = bounds.expand(point)
	var source := Geometry.box(item)
	output.append({"bounds": bounds, "faces": faces, "id": item["id"], "source_id": item["id"],
		"source_bounds": source, "kind": kind, "fragment_key": str(item["id"]) + ":" + kind + ":" + suffix,
		"material_to_world": transform * Transform3D(Basis.IDENTITY, source.get_center())})
	# Keep untouched boxes on the same mesh and material path during rotation.
	if absf(volume(faces) - bounds.get_volume()) < EPS:
		output[-1].erase("faces")
