class_name MirrorState
extends RefCounted
## Discrete frame orientation accompanies the axis-aligned collision plane.

static func normal(state: Dictionary) -> Vector3:
	var result := Vector3.ZERO
	result[int(state["axis"])] = float(state["source"])
	return result

static func frame(state: Dictionary) -> Basis:
	var facing := normal(state)
	var up: Vector3 = state.get("frame_up", Vector3.UP if absf(facing.y) < 0.5 else Vector3.BACK)
	if absf(up.dot(facing)) > 0.5:
		up = Vector3.UP if absf(facing.y) < 0.5 else Vector3.BACK
	return Basis(up.cross(facing), up, facing)

static func _rotate(state: Dictionary, axis: Vector3, direction: int) -> Dictionary:
	var result := state.duplicate(true)
	var rotation := Basis(axis, signi(direction) * PI * 0.5)
	var facing := (rotation * normal(state)).round()
	result["frame_up"] = (rotation * frame(state).y).round()
	result["axis"] = facing.abs().max_axis_index()
	result["source"] = int(facing[int(result["axis"])])
	result["offset"] = result["pivot"][int(result["axis"])]
	if result["axis"] != 1:
		result["vertical_axis"] = result["axis"]
		result["vertical_source"] = result["source"]
	return result

static func turn(state: Dictionary, direction: int) -> Dictionary:
	return state.duplicate(true) if int(state["axis"]) == 1 else _rotate(state, Vector3.UP, direction)

static func tilt(state: Dictionary, direction := 1) -> Dictionary:
	return _rotate(state, frame(state).x, direction)

static func resized(state: Dictionary, dimension: String, length: float) -> Dictionary:
	# Derive from the gesture's initial state: the negative edge stays fixed.
	var result := state.duplicate(true)
	var direction := frame(state).x if dimension == "width" else frame(state).y
	result["pivot"] = state["pivot"] + direction * (length - float(state.get(dimension, 3))) * 0.5
	result[dimension] = length
	result["offset"] = result["pivot"][int(result["axis"])]
	return result

static func resize_range(state: Dictionary, dimension: String, limits: Dictionary) -> Vector2:
	var low := INF
	var high := -INF
	for length: int in range(1, 7):
		var pivot: Vector3 = resized(state, dimension, length)["pivot"]
		var valid := true
		for axis: int in 3:
			valid = valid and pivot[axis] >= float(limits["min"][axis]) - 0.0001 and pivot[axis] <= float(limits["max"][axis]) + 0.0001
		if valid:
			low = minf(low, length)
			high = maxf(high, length)
	return Vector2(low, high)
