class_name MirrorState
extends RefCounted
## Axis-aligned geometry uses offset; pivot keeps rotations at one world point.

static func normal(state: Dictionary) -> Vector3:
	var result := Vector3.ZERO
	result[int(state["axis"])] = float(state["source"])
	return result

static func turn(state: Dictionary, direction: int) -> Dictionary:
	var result := state.duplicate(true)
	if int(state["axis"]) == 1:
		return result
	var turned := normal(state).rotated(Vector3.UP, direction * PI * 0.5).round()
	result["axis"] = 0 if absf(turned.x) > 0.5 else 2
	result["source"] = int(turned[int(result["axis"])])
	result["vertical_axis"] = result["axis"]
	result["vertical_source"] = result["source"]
	result["offset"] = result["pivot"][int(result["axis"])]
	return result

static func tilt(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if int(state["axis"]) == 1:
		result["axis"] = int(state.get("vertical_axis", 0))
		result["source"] = int(state.get("vertical_source", 1))
	else:
		result["vertical_axis"] = state["axis"]
		result["vertical_source"] = state["source"]
		result["axis"] = 1
	result["offset"] = result["pivot"][int(result["axis"])]
	return result
