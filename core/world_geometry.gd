class_name WorldGeometry
extends RefCounted
## Pure axis-aligned world rules. Feet positions use the bottom of the capsule.

const MirrorRules := preload("res://core/mirror_state.gd")
const EPS := 0.0001
const RADIUS := 0.18
const HEIGHT := 0.8

static func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

static func box(data: Dictionary) -> AABB:
	var size := vector(data["size"])
	return AABB(vector(data["center"]) - size * 0.5, size)

static func generate(level: Dictionary, mirror: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var absolute_bounds: Array[AABB] = []
	for item: Dictionary in level["absolutes"]:
		var bounds := box(item)
		absolute_bounds.append(bounds)
		var metadata := _source_metadata(item)
		metadata.merge({"bounds": bounds, "kind": "absolute", "id": item["id"]})
		result.append(metadata)
	for item: Dictionary in level["originals"]:
		var original := box(item)
		var metadata := _source_metadata(item)
		if not mirror["enabled"]:
			_append_pieces(result, original, absolute_bounds, "original", item["id"], metadata)
			continue
		var clipped := selected_source(original, mirror)
		var opposite := mirror.duplicate()
		opposite["source"] = -int(mirror["source"])
		var replaced := selected_source(original, opposite)
		for piece: AABB in subtract(original, replaced):
			_append_pieces(result, piece, absolute_bounds, "original", item["id"], metadata)
		if has_volume(clipped):
			var reflected_metadata := metadata.duplicate()
			reflected_metadata["material_to_world"] = reflection_transform(mirror) * metadata["material_to_world"]
			_append_pieces(result, reflect(clipped, mirror), absolute_bounds, "reflected", item["id"], reflected_metadata)
	return result

static func _source_metadata(item: Dictionary) -> Dictionary:
	var bounds := box(item)
	return {"source_id": item["id"], "source_bounds": bounds,
		"material_to_world": Transform3D(Basis.IDENTITY, bounds.get_center())}

static func reflection_transform(mirror: Dictionary) -> Transform3D:
	var normal := MirrorRules.normal(mirror)
	var axes := Vector3.ONE - normal.abs() * 2.0
	var origin := normal.abs() * float(mirror["offset"]) * 2.0
	return Transform3D(Basis.from_scale(axes), origin)

static func selected_source(bounds: AABB, mirror: Dictionary) -> AABB:
	var clipped := source_part(bounds, mirror)
	var frame := MirrorRules.frame(mirror)
	var pivot: Vector3 = mirror["pivot"]
	var low := clipped.position
	var high := clipped.end
	var tangent_axes: Array[int] = [frame.x.abs().max_axis_index(), frame.y.abs().max_axis_index()]
	var lengths: Array[float] = [float(mirror.get("width", 3.0)), float(mirror.get("height", 3.0))]
	for index: int in 2:
		var axis := tangent_axes[index]
		low[axis] = maxf(low[axis], pivot[axis] - lengths[index] * 0.5)
		high[axis] = minf(high[axis], pivot[axis] + lengths[index] * 0.5)
	return AABB(low, (high - low).max(Vector3.ZERO))

static func source_part(bounds: AABB, mirror: Dictionary) -> AABB:
	var axis: int = mirror["axis"]
	var low := bounds.position
	var high := bounds.end
	if int(mirror["source"]) > 0:
		high[axis] = minf(high[axis], float(mirror["offset"]))
	else:
		low[axis] = maxf(low[axis], float(mirror["offset"]))
	return AABB(low, (high - low).max(Vector3.ZERO))

static func reflect(bounds: AABB, mirror: Dictionary) -> AABB:
	var axis: int = mirror["axis"]
	var origin := bounds.position
	origin[axis] = 2.0 * float(mirror["offset"]) - bounds.end[axis]
	return AABB(origin, bounds.size)

static func has_volume(bounds: AABB) -> bool:
	return bounds.size.x > EPS and bounds.size.y > EPS and bounds.size.z > EPS

static func subtract(bounds: AABB, obstacle: AABB) -> Array[AABB]:
	var overlap := bounds.intersection(obstacle)
	if not has_volume(overlap):
		return [bounds]
	var pieces: Array[AABB] = []
	var low := bounds.position
	var high := bounds.end
	for axis: int in range(3):
		if low[axis] < overlap.position[axis] - EPS:
			var cut_high := high
			cut_high[axis] = overlap.position[axis]
			pieces.append(AABB(low, cut_high - low))
			low[axis] = overlap.position[axis]
		if high[axis] > overlap.end[axis] + EPS:
			var cut_low := low
			cut_low[axis] = overlap.end[axis]
			pieces.append(AABB(cut_low, high - cut_low))
			high[axis] = overlap.end[axis]
	return pieces

static func _append_pieces(result: Array[Dictionary], bounds: AABB,
		absolutes: Array[AABB], kind: String, id: String, metadata: Dictionary = {}) -> void:
	var pieces: Array[AABB] = [bounds]
	for absolute: AABB in absolutes:
		var next: Array[AABB] = []
		for piece: AABB in pieces:
			next.append_array(subtract(piece, absolute))
		pieces = next
	for piece: AABB in pieces:
		if has_volume(piece):
			var generated := metadata.duplicate()
			generated.merge({"bounds": piece, "kind": kind, "id": id})
			result.append(generated)

static func embedded(feet: Vector3, solids: Array[Dictionary]) -> bool:
	# Capsule/box distance permits floor contact but rejects actual penetration.
	var bottom := feet.y + RADIUS
	var top := feet.y + HEIGHT - RADIUS
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		var dx := maxf(maxf(bounds.position.x - feet.x, feet.x - bounds.end.x), 0.0)
		var dz := maxf(maxf(bounds.position.z - feet.z, feet.z - bounds.end.z), 0.0)
		var dy := maxf(maxf(bounds.position.y - top, bottom - bounds.end.y), 0.0)
		if dx * dx + dy * dy + dz * dz < pow(RADIUS - 0.002, 2):
			return true
	return false

static func supported(feet: Vector3, solids: Array[Dictionary], inset := 0.0) -> bool:
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		if absf(bounds.end.y - feet.y) > 0.035:
			continue
		if feet.x >= bounds.position.x + inset - EPS and feet.x <= bounds.end.x - inset + EPS \
				and feet.z >= bounds.position.z + inset - EPS and feet.z <= bounds.end.z - inset + EPS:
			return true
	return false

static func walkable(feet: Vector3, solids: Array[Dictionary]) -> bool:
	if embedded(feet, solids):
		return false
	# Cover a conservative square footprint with the union of floor rectangles.
	# Unlike four probes, this rejects diagonal corner-only connections and holes.
	var remaining: Array[AABB] = [AABB(feet + Vector3(-RADIUS, -0.01, -RADIUS), Vector3(RADIUS * 2, 0.02, RADIUS * 2))]
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		if absf(bounds.end.y - feet.y) > 0.035:
			continue
		var floor_rect := AABB(Vector3(bounds.position.x, feet.y - 0.02, bounds.position.z), Vector3(bounds.size.x, 0.04, bounds.size.z))
		var next: Array[AABB] = []
		for piece: AABB in remaining:
			next.append_array(subtract(piece, floor_rect))
		remaining = next
		if remaining.is_empty():
			return true
	return false

static func clear_segment(start: Vector3, finish: Vector3, solids: Array[Dictionary]) -> bool:
	if absf(start.y - finish.y) > 0.035:
		return false
	var steps := maxi(1, ceili(start.distance_to(finish) / 0.08))
	for index: int in range(steps + 1):
		if not walkable(start.lerp(finish, float(index) / steps), solids):
			return false
	return true

static func total_bounds(solids: Array[Dictionary]) -> AABB:
	var bounds: AABB = solids[0]["bounds"] if not solids.is_empty() else AABB(Vector3.ZERO, Vector3.ONE)
	for solid: Dictionary in solids:
		bounds = bounds.merge(solid["bounds"])
	return bounds

static func reflection_contacts(level: Dictionary, mirror: Dictionary) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not mirror["enabled"]:
		return contacts
	for item: Dictionary in level["originals"]:
		var clipped := selected_source(box(item), mirror)
		if not has_volume(clipped):
			continue
		var reflected := reflect(clipped, mirror)
		for absolute: Dictionary in level["absolutes"]:
			var overlap := reflected.intersection(box(absolute))
			if has_volume(overlap):
				contacts.append({"bounds": overlap, "reflected": reflected, "absolute_id": absolute["id"]})
	return contacts
