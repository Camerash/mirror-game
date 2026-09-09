class_name MirrorTargets
extends RefCounted
## Pure target selection. Display interpolation never changes committed physics.

static func step(value: float, current: float, increment: float) -> float:
	if increment <= 0.0:
		return value
	if absf(value - current) <= increment * 0.6:
		return current
	return snappedf(value, increment)

static func interpolate(start: Dictionary, finish: Dictionary, weight: float) -> Dictionary:
	var result := finish.duplicate(true)
	result["pivot"] = (start["pivot"] as Vector3).lerp(finish["pivot"], weight)
	for key: String in ["yaw", "pitch", "width", "height"]:
		result[key] = lerpf(float(start[key]), float(finish[key]), weight)
	return preload("res://core/mirror_state.gd").sync(result)
