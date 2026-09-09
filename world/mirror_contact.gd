class_name MirrorContact
extends Node3D
## Surface-local seams on the five boundaries of the replacement column.

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
	seam.mesh = _mesh(segments)

func _contours(solids: Array[Dictionary], state: Dictionary, frame: Basis) -> Array:
	var result: Array = []
	# Use the same half-spaces as replacement; omit only the active boundary
	# when clipping its contact band, so the glow can spread across that line.
	var boundaries := Display.column(state["pivot"], frame, state, true)
	var surface_faces: Array = []
	for solid: Dictionary in solids:
		if solid.get("kind") == "reflected":
			continue
		surface_faces.append_array(_faces(solid))
	for index: int in boundaries.size():
		var limits := boundaries.duplicate()
		limits.remove_at(index)
		for polygon: PackedVector3Array in surface_faces:
			_append_face_contacts(result, polygon, boundaries[index], limits)
	return _merge_collinear_segments(_unique_segments(_remove_internal_edges(result, surface_faces)))

func _faces(solid: Dictionary) -> Array:
	if solid.has("faces") and not (solid["faces"] as Array).is_empty():
		return solid["faces"]
	return Display.box_faces(solid["bounds"])

func _append_face_contacts(result: Array, polygon: PackedVector3Array, boundary: Plane, limits: Array) -> void:
	if polygon.size() < 3:
		return
	var normal := (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]).normalized()
	if normal.length_squared() <= EPS * EPS:
		return
	var distances: Array = []
	var largest := 0.0
	for point: Vector3 in polygon:
		var distance := boundary.distance_to(point)
		distances.append(distance)
		largest = maxf(largest, absf(distance))
	if largest <= EPS:
		var clipped: Array = Array(polygon)
		for limit: Plane in limits:
			clipped = _clip_points(clipped, -limit.normal, -limit.d)
		for index: int in clipped.size():
			_append_segment(result, clipped[index], clipped[(index + 1) % clipped.size()], normal, polygon, limits, true)
	else:
		_append_crossing(result, polygon, distances, normal, limits)

func _append_crossing(result: Array, polygon: PackedVector3Array, distances: Array, normal: Vector3, limits: Array) -> void:
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
	var clipped := _clip_segment(first, last, limits)
	if clipped.size() == 2:
		_append_segment(result, clipped[0], clipped[1], normal, polygon, limits, false)

func _append_segment(result: Array, start: Vector3, finish: Vector3, normal: Vector3, polygon: PackedVector3Array, limits: Array, coplanar: bool) -> void:
	if start.distance_squared_to(finish) > EPS * EPS:
		result.append({"a": start, "b": finish, "normal": normal, "face": polygon, "limits": limits, "coplanar": coplanar})

func _clip_segment(start: Vector3, finish: Vector3, limits: Array) -> Array:
	var low := 0.0
	var high := 1.0
	for limit: Plane in limits:
		var distance := limit.distance_to(start)
		var delta := limit.normal.dot(finish - start)
		if absf(delta) <= EPS:
			if distance > PANEL_EPS:
				return []
			continue
		var crossing := -distance / delta
		if delta > 0.0:
			high = minf(high, crossing)
		else:
			low = maxf(low, crossing)
		if low >= high - EPS:
			return []
	return [start.lerp(finish, low), start.lerp(finish, high)]

func _remove_internal_edges(segments: Array, faces: Array) -> Array:
	var result: Array = []
	for segment: Dictionary in segments:
		if not segment["coplanar"]:
			result.append(segment)
			continue
		var start: Vector3 = segment["a"]
		var edge: Vector3 = segment["b"] - start
		var normal: Vector3 = segment["normal"]
		var neighbours := _coplanar_faces(faces, start, normal)
		var cuts: Array[float] = [0.0, 1.0]
		for face: PackedVector3Array in neighbours:
			var limits: Array = []
			for index: int in face.size():
				var outward := (face[(index + 1) % face.size()] - face[index]).cross(normal).normalized()
				limits.append(Plane(outward, outward.dot(face[index])))
			for point: Vector3 in _clip_segment(start, segment["b"], limits):
				cuts.append(clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0))
		cuts.sort()
		var side := normal.cross(edge.normalized()) * PANEL_EPS * 4.0
		for index: int in cuts.size() - 1:
			if cuts[index + 1] - cuts[index] <= EPS:
				continue
			var midpoint := start + edge * (cuts[index] + cuts[index + 1]) * 0.5
			if _covered_surface(midpoint + side, normal, neighbours) and _covered_surface(midpoint - side, normal, neighbours):
				continue
			var exposed := segment.duplicate()
			exposed["a"] = start + edge * cuts[index]
			exposed["b"] = start + edge * cuts[index + 1]
			result.append(exposed)
	return result

func _coplanar_faces(faces: Array, point: Vector3, normal: Vector3) -> Array:
	var result: Array = []
	for face: PackedVector3Array in faces:
		if face.size() < 3 or absf(normal.dot(point - face[0])) > PANEL_EPS:
			continue
		var face_normal := (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		if _same_normal(normal, face_normal):
			result.append(face)
	return result

func _covered_surface(point: Vector3, normal: Vector3, faces: Array) -> bool:
	for face: PackedVector3Array in faces:
		if _face_contains(face, normal, point):
			return true
	return false

func _unique_segments(segments: Array) -> Array:
	var unique: Array = []
	for segment: Dictionary in segments:
		var duplicate := false
		for existing: Dictionary in unique:
			var same_direction := (segment["a"] as Vector3).distance_to(existing["a"]) <= PANEL_EPS and (segment["b"] as Vector3).distance_to(existing["b"]) <= PANEL_EPS
			var reverse_direction := (segment["a"] as Vector3).distance_to(existing["b"]) <= PANEL_EPS and (segment["b"] as Vector3).distance_to(existing["a"]) <= PANEL_EPS
			if (same_direction or reverse_direction) and _same_normal(segment["normal"], existing["normal"]) and segment["face"] == existing["face"]:
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
	if first["face"] != second["face"] or first["limits"] != second["limits"] or not _same_normal(first["normal"], second["normal"]):
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

func _mesh(segments: Array) -> Mesh:
	var bands: Array = []
	for segment: Dictionary in segments:
		var band := _band_polygon(segment, segments)
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

func _band_polygon(segment: Dictionary, segments: Array) -> Array:
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
	for limit: Plane in segment["limits"]:
		points = _clip_points(points, -limit.normal, -limit.d)
	return _clip_corner_overlaps(points, segment, segments)

func _clip_corner_overlaps(points: Array, segment: Dictionary, segments: Array) -> Array:
	# Divide a shared surface at the angle bisector instead of blending two halos.
	for other: Dictionary in segments:
		if not _same_normal(segment["normal"], other["normal"]):
			continue
		for key: String in ["a", "b"]:
			var joint: Vector3 = segment[key]
			var away: Vector3 = segment["b" if key == "a" else "a"] - joint
			for other_key: String in ["a", "b"]:
				if joint.distance_to(other[other_key]) > PANEL_EPS:
					continue
				var other_away: Vector3 = other["b" if other_key == "a" else "a"] - joint
				if absf(away.normalized().dot(other_away.normalized())) > 0.999:
					continue
				var divider := (away.normalized() - other_away.normalized()).normalized()
				points = _clip_points(points, divider, divider.dot(joint))
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
		keys.append(edge + ":" + _point_key(normal) + ":" + str(segment["face"]) + ":" + str(segment["limits"]))
	keys.sort()
	return ";".join(keys)

func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0)]

func _add_unique(points: Array, point: Vector3) -> void:
	for existing: Vector3 in points:
		if existing.distance_squared_to(point) <= EPS * EPS:
			return
	points.append(point)
