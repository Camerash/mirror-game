class_name MirrorState
extends RefCounted
## Angles are radians. The panel frame and its selected source side are independent.

static func normal(state: Dictionary) -> Vector3:
	return frame(state).z * float(state.get("source_sign", 1))

static func frame(state: Dictionary) -> Basis:
	if state.has("yaw"):
		return Basis(Vector3.UP, float(state["yaw"])) * Basis(Vector3.RIGHT, float(state["pitch"]))
	var facing := Vector3.ZERO
	facing[int(state["axis"])] = float(state["source"])
	var up: Vector3 = state.get("frame_up", Vector3.UP if absf(facing.y) < 0.5 else Vector3.BACK)
	if absf(up.dot(facing)) > 0.5:
		up = Vector3.UP if absf(facing.y) < 0.5 else Vector3.BACK
	return Basis(up.cross(facing), up, facing)

static func normalized(state: Dictionary) -> Dictionary:
	return sync(state.duplicate(true)) if state.has("yaw") else oriented(state, frame(state))

static func oriented(state: Dictionary, orientation: Basis) -> Dictionary:
	var result := state.duplicate(true)
	result["yaw"] = atan2(-orientation.x.z, orientation.x.x)
	result["pitch"] = atan2(-orientation.z.y, orientation.y.y)
	result["source_sign"] = int(state.get("source_sign", 1))
	return sync(result)

static func sync(state: Dictionary) -> Dictionary:
	var facing := normal(state)
	state["axis"] = facing.abs().max_axis_index()
	state["source"] = 1 if facing[int(state["axis"])] >= 0 else -1
	state["frame_up"] = frame(state).y
	state["offset"] = state["pivot"][int(state["axis"])]
	if not horizontal(state):
		state["vertical_axis"] = state["axis"]
		state["vertical_source"] = state["source"]
	return state

static func horizontal(state: Dictionary) -> bool:
	return absf(frame(state).z.y) > 0.99999

static func rotated(state: Dictionary, kind: String, angle: float) -> Dictionary:
	var result := normalized(state)
	var key := "yaw" if kind == "turn" else "pitch"
	result[key] = float(result[key]) + angle
	return sync(result)

static func reversed(state: Dictionary) -> Dictionary:
	var result := normalized(state)
	result["source_sign"] = -int(result["source_sign"])
	return sync(result)

static func turn(state: Dictionary, direction: int) -> Dictionary:
	return state.duplicate(true) if horizontal(state) else rotated(state, "turn", signi(direction) * PI * 0.5)

static func tilt(state: Dictionary, direction := 1) -> Dictionary:
	return rotated(state, "tilt", signi(direction) * PI * 0.5)

static func snapped_pivot(pivot: Vector3, limits: Dictionary) -> Vector3:
	for axis: int in 3:
		pivot[axis] = clampf(snappedf(pivot[axis], 0.5), ceilf(float(limits["min"][axis]) * 2) * 0.5, floorf(float(limits["max"][axis]) * 2) * 0.5)
	return pivot

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
