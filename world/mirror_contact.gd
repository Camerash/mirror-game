class_name MirrorContact
extends Node3D
## Surface-local seams where the finite mirror panel cuts visible solids.

const Display := preload("res://core/display_geometry.gd")
const ContactShader := preload("res://world/mirror_contact.gdshader")
const EPS := 0.0005
const PANEL_EPS := 0.002
const BAND_HALF_WIDTH := 0.18

var seam := MeshInstance3D.new()
var material := ShaderMaterial.new()
var contour_signature := ""

func _ready() -> void:
	material.shader = ContactShader
	material.render_priority = 76
	seam.material_override = material
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seam)

func set_contacts(solids: Array[Dictionary], state: Dictionary, frame: Basis, removal: bool = false) -> void:
	var active := state.has("axis") and float(state.get("width", 0.0)) > 0.0 and float(state.get("height", 0.0)) > 0.0
	seam.visible = active
	material.set_shader_parameter("removal", removal)
	if not active:
		return
	var segments := _contours(solids, state, frame.orthonormalized())
	var next_signature := _signature(segments)
	if next_signature == contour_signature:
		return
	contour_signature = next_signature
	seam.mesh = _mesh(segments, state["pivot"], frame.orthonormalized(), Vector2(float(state.get("width", 3.0)) * 0.5, float(state.get("height", 3.0)) * 0.5))

func _contours(solids: Array[Dictionary], state: Dictionary, frame: Basis) -> Array:
	var result: Array = []
	var pivot: Vector3 = state["pivot"]
	var half_size := Vector2(float(state.get("width", 3.0)) * 0.5, float(state.get("height", 3.0)) * 0.5)
	for solid: Dictionary in solids:
		for polygon: PackedVector3Array in _faces(solid):
			if polygon.size() < 3:
				continue
			var normal := (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]).normalized()
			if normal.length_squared() < EPS * EPS:
				continue
			var distances: Array = []
			for point: Vector3 in polygon:
				distances.append(frame.z.dot(point - pivot))
			var largest := 0.0
			for distance: float in distances:
				largest = maxf(largest, absf(distance))
			if largest <= EPS:
				_append_coplanar(result, polygon, normal, pivot, frame, half_size)
			else:
				_append_crossing(result, polygon, distances, normal, pivot, frame, half_size)
	return _merge_collinear_segments(_unique_segments(result))

func _faces(solid: Dictionary) -> Array:
	if solid.has("faces") and not (solid["faces"] as Array).is_empty():
		return solid["faces"]
	return Display.box_faces(solid["bounds"])

func _append_crossing(result: Array, polygon: PackedVector3Array, distances: Array, normal: Vector3, pivot: Vector3, frame: Basis, half_size: Vector2) -> void:
	var points: Array = []
	for index: int in polygon.size():
		var start := polygon[index]
		var finish := polygon[(index + 1) % polygon.size()]
		var start_distance: float = distances[index]
		var finish_distance: float = distances[(index + 1) % polygon.size()]
		if absf(start_distance) <= EPS:
			_add_unique(points, start)
		if (start_distance < -EPS and finish_distance > EPS) or (start_distance > EPS and finish_distance < -EPS):
			_add_unique(points, start.lerp(finish, start_distance / (start_distance - finish_distance)))
	if points.size() < 2:
		return
	var first: Vector3 = points[0]
	var last: Vector3 = points[1]
	for left: Vector3 in points:
		for right: Vector3 in points:
			if left.distance_squared_to(right) > first.distance_squared_to(last):
				first = left
				last = right
	var clipped := _clip_to_panel(first, last, pivot, frame, half_size)
	if clipped.size() == 2:
		result.append({"a": clipped[0], "b": clipped[1], "normal": normal, "face": polygon})

func _append_coplanar(result: Array, polygon: PackedVector3Array, normal: Vector3, pivot: Vector3, frame: Basis, half_size: Vector2) -> void:
	var local: Array = []
	for point: Vector3 in polygon:
		var value := frame.inverse() * (point - pivot)
		local.append(Vector2(value.x, value.y))
	local = _clip_polygon(local, 0, -half_size.x, half_size.x)
	local = _clip_polygon(local, 1, -half_size.y, half_size.y)
	if local.size() < 2:
		return
	for index: int in local.size():
		var start: Vector2 = local[index]
		var finish: Vector2 = local[(index + 1) % local.size()]
		if start.distance_squared_to(finish) > EPS * EPS:
			result.append({"a": pivot + frame.x * start.x + frame.y * start.y, "b": pivot + frame.x * finish.x + frame.y * finish.y, "normal": normal, "face": polygon})

func _clip_to_panel(start: Vector3, finish: Vector3, pivot: Vector3, frame: Basis, half_size: Vector2) -> Array:
	var local_start := frame.inverse() * (start - pivot)
	var local_finish := frame.inverse() * (finish - pivot)
	var direction := local_finish - local_start
	var low := 0.0
	var high := 1.0
	for axis: int in 2:
		var origin: float = local_start[axis]
		var delta: float = direction[axis]
		var limit: float = half_size[axis]
		if absf(delta) <= EPS:
			if absf(origin) > limit + PANEL_EPS:
				return []
			continue
		var first := (-limit - origin) / delta
		var last := (limit - origin) / delta
		if first > last:
			var swap := first
			first = last
			last = swap
		low = maxf(low, first)
		high = minf(high, last)
		if low > high - EPS:
			return []
	return [start.lerp(finish, low), start.lerp(finish, high)]

func _clip_polygon(points: Array, axis: int, lower: float, upper: float) -> Array:
	for bound: float in [lower, upper]:
		var keep_lower := is_equal_approx(bound, lower)
		var clipped: Array = []
		for index: int in points.size():
			var start: Vector2 = points[index]
			var finish: Vector2 = points[(index + 1) % points.size()]
			var start_inside := start[axis] >= bound - EPS if keep_lower else start[axis] <= bound + EPS
			var finish_inside := finish[axis] >= bound - EPS if keep_lower else finish[axis] <= bound + EPS
			if start_inside:
				clipped.append(start)
			if start_inside != finish_inside:
				var delta := finish[axis] - start[axis]
				if absf(delta) > EPS:
					clipped.append(start.lerp(finish, (bound - start[axis]) / delta))
		points = clipped
		if points.is_empty():
			break
	return points

func _unique_segments(segments: Array) -> Array:
	var unique: Array = []
	for segment: Dictionary in segments:
		var duplicate := false
		for existing: Dictionary in unique:
			var same_direction := (segment["a"] as Vector3).distance_to(existing["a"]) <= PANEL_EPS and (segment["b"] as Vector3).distance_to(existing["b"]) <= PANEL_EPS
			var reverse_direction := (segment["a"] as Vector3).distance_to(existing["b"]) <= PANEL_EPS and (segment["b"] as Vector3).distance_to(existing["a"]) <= PANEL_EPS
			if (same_direction or reverse_direction) and _same_normal(segment["normal"], existing["normal"]):
				duplicate = true
				break
		if not duplicate:
			unique.append(segment)
	return unique

func _merge_collinear_segments(segments: Array) -> Array:
	var merged: Array = []
	for segment: Dictionary in segments:
		var combined := false
		for index: int in merged.size():
			var candidate: Dictionary = merged[index]
			var endpoints := _merged_endpoints(candidate, segment)
			if endpoints.is_empty():
				continue
			var face: PackedVector3Array = candidate["face"]
			if not _face_contains(face, candidate["normal"], endpoints[0]) or not _face_contains(face, candidate["normal"], endpoints[1]):
				face = segment["face"]
			if not _face_contains(face, candidate["normal"], endpoints[0]) or not _face_contains(face, candidate["normal"], endpoints[1]):
				continue
			candidate["a"] = endpoints[0]
			candidate["b"] = endpoints[1]
			candidate["face"] = face
			merged[index] = candidate
			combined = true
			break
		if not combined:
			merged.append(segment)
	return merged

func _merged_endpoints(first: Dictionary, second: Dictionary) -> Array:
	if not _same_normal(first["normal"], second["normal"]):
		return []
	var start: Vector3 = first["a"]
	var finish: Vector3 = first["b"]
	var direction := finish - start
	if direction.length_squared() <= EPS * EPS:
		return []
	var axis := direction.normalized()
	var other_start: Vector3 = second["a"]
	var other_finish: Vector3 = second["b"]
	if axis.cross(other_finish - other_start).length() > PANEL_EPS or axis.cross(other_start - start).length() > PANEL_EPS:
		return []
	var length := direction.length()
	var second_low := (other_start - start).dot(axis)
	var second_high := (other_finish - start).dot(axis)
	if second_low > second_high:
		var swap := second_low
		second_low = second_high
		second_high = swap
	if second_high < -PANEL_EPS or second_low > length + PANEL_EPS:
		return []
	return [start + axis * minf(0.0, second_low), start + axis * maxf(length, second_high)]

func _same_normal(first: Vector3, second: Vector3) -> bool:
	return first.dot(second) > 0.999

func _face_contains(face: PackedVector3Array, normal: Vector3, point: Vector3) -> bool:
	for index: int in face.size():
		var edge := face[(index + 1) % face.size()] - face[index]
		if normal.cross(edge).dot(point - face[index]) < -PANEL_EPS:
			return false
	return true

func _mesh(segments: Array, pivot: Vector3, frame: Basis, half_size: Vector2) -> Mesh:
	var bands: Array = []
	for segment: Dictionary in segments:
		var band := _band_polygon(segment, pivot, frame, half_size)
		if band.size() >= 3:
			bands.append({"points": band, "normal": segment["normal"], "segment": segment})
	if bands.is_empty():
		return ArrayMesh.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: Dictionary in bands:
		var points: Array = band["points"]
		for index: int in range(1, points.size() - 1):
			_add_band_vertex(mesh, points[0], band["normal"], _band_uv(points[0], band["segment"]))
			_add_band_vertex(mesh, points[index], band["normal"], _band_uv(points[index], band["segment"]))
			_add_band_vertex(mesh, points[index + 1], band["normal"], _band_uv(points[index + 1], band["segment"]))
	mesh.surface_end()
	return mesh

func _band_uv(point: Vector3, segment: Dictionary) -> Vector2:
	var start: Vector3 = segment["a"]
	var edge: Vector3 = segment["b"] - start
	var tangent := edge.normalized()
	var width: Vector3 = segment["normal"].cross(tangent)
	return Vector2(0.5 + (point-start).dot(width) / (2.0 * BAND_HALF_WIDTH), (point-start).dot(tangent) / edge.length())

func _band_polygon(segment: Dictionary, pivot: Vector3, frame: Basis, half_size: Vector2) -> Array:
	var start: Vector3 = segment["a"]
	var finish: Vector3 = segment["b"]
	var normal: Vector3 = segment["normal"]
	var tangent := (finish - start).normalized()
	var side := normal.cross(tangent).normalized() * BAND_HALF_WIDTH
	if side.length_squared() < EPS * EPS:
		return []
	var offset := normal * 0.002
	var points: Array = [start - side + offset, finish - side + offset, finish + side + offset, start + side + offset]
	var face: PackedVector3Array = segment["face"]
	for index: int in face.size():
		var edge := face[(index + 1) % face.size()] - face[index]
		points = _clip_points(points, normal.cross(edge), normal.cross(edge).dot(face[index]))
		if points.is_empty():
			return []
	points = _clip_points(points, frame.x, frame.x.dot(pivot) - half_size.x)
	points = _clip_points(points, -frame.x, -frame.x.dot(pivot) - half_size.x)
	points = _clip_points(points, frame.y, frame.y.dot(pivot) - half_size.y)
	points = _clip_points(points, -frame.y, -frame.y.dot(pivot) - half_size.y)
	return points

func _clip_points(points: Array, normal: Vector3, distance: float) -> Array:
	var clipped: Array = []
	for index: int in points.size():
		var start: Vector3 = points[index]
		var finish: Vector3 = points[(index + 1) % points.size()]
		var start_distance := normal.dot(start) - distance
		var finish_distance := normal.dot(finish) - distance
		if start_distance >= -EPS:
			clipped.append(start)
		if (start_distance < -EPS and finish_distance > EPS) or (start_distance > EPS and finish_distance < -EPS):
			clipped.append(start.lerp(finish, start_distance / (start_distance - finish_distance)))
	return clipped

func _add_band_vertex(mesh: ImmediateMesh, point: Vector3, normal: Vector3, uv: Vector2) -> void:
	mesh.surface_set_normal(normal)
	mesh.surface_set_uv(uv)
	mesh.surface_add_vertex(point)

func _signature(segments: Array) -> String:
	var keys: Array[String] = []
	for segment: Dictionary in segments:
		var a: Vector3 = segment["a"]
		var b: Vector3 = segment["b"]
		var normal: Vector3 = segment["normal"]
		var first := _point_key(a)
		var last := _point_key(b)
		var edge := first + ":" + last if first < last else last + ":" + first
		keys.append(edge + ":" + _point_key(normal) + ":" + str(segment["face"]))
	keys.sort()
	return ";".join(keys)

func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0)]

func _add_unique(points: Array, point: Vector3) -> void:
	for existing: Vector3 in points:
		if existing.distance_squared_to(point) <= EPS * EPS:
			return
	points.append(point)
