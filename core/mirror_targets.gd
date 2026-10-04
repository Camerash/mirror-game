class_name MirrorTargets
extends RefCounted
const Rules := preload("res://core/mirror_state.gd")
const GUIDE_RADIUS := 2.0

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
	return Rules.sync(result)

static func resize_state(origin: Dictionary, key: String, length: float, limits: Dictionary) -> Dictionary:
	var target := Rules.resized(origin, key, length)
	target["pivot"] = Rules.snapped_pivot(target["pivot"], limits)
	return Rules.sync(target)

static func edge_position(state: Dictionary, key: String) -> Vector3:
	var axis := Rules.frame(state).x if key == "width" else Rules.frame(state).y
	return state["pivot"] + axis * float(state[key]) * 0.5

static func spatial_weight(distance: float) -> float:
	return 1.0 - smoothstep(0.0, GUIDE_RADIUS, distance)

static func position_dots(displayed: Vector3, origin: Vector3, limits: Dictionary, vertical: bool) -> Array[Dictionary]:
	var dots: Array[Dictionary] = []
	if vertical:
		for y: float in _steps(displayed.y, float(limits["min"][1]), float(limits["max"][1])):
			_append_dot(dots, Vector3(origin.x,y,origin.z), absf(y-displayed.y))
	else:
		for x: float in _steps(displayed.x, float(limits["min"][0]), float(limits["max"][0])):
			for z: float in _steps(displayed.z, float(limits["min"][2]), float(limits["max"][2])):
				var point := Vector3(x,origin.y,z)
				_append_dot(dots, point, point.distance_to(displayed))
	return dots

static func _steps(centre: float, low: float, high: float) -> Array[float]:
	var result: Array[float] = []
	var first := ceili(maxf(low, centre-GUIDE_RADIUS)*2.0)
	var last := floori(minf(high, centre+GUIDE_RADIUS)*2.0)
	for index: int in range(first,last+1): result.append(float(index)*0.5)
	return result

static func _append_dot(dots: Array[Dictionary], point: Vector3, distance: float) -> void:
	var weight := spatial_weight(distance)
	if weight > 0.0: dots.append({"position":point, "weight":weight})

static func resize_dots(origin: Dictionary, displayed: Dictionary, key: String, limits: Dictionary) -> Array[Dictionary]:
	var dots: Array[Dictionary] = []
	var allowed := Rules.resize_range(origin,key,limits)
	if not is_finite(allowed.x): return dots
	var reference := edge_position(displayed,key)
	for length: int in range(int(allowed.x),int(allowed.y)+1):
		var point := edge_position(resize_state(origin,key,float(length),limits),key)
		_append_dot(dots,point,point.distance_to(reference))
	return dots

## Direct controls. In the game's camera each world axis has its own screen
## direction (the ground axes are shallow diagonals, height is straight up,
## at least 53 degrees apart in every view), so the direction of a drag alone
## says which axis it means.

## The world axis (0 x, 1 y, 2 z) whose screen direction best matches `drag`.
## `screen_axes` holds the screen vector of one world unit along each axis.
static func pick_axis(drag: Vector2, screen_axes: Array[Vector2]) -> int:
	var best := -1
	var best_score := -1.0
	if drag.length_squared() < 0.0001:
		return best
	for axis: int in screen_axes.size():
		var direction := screen_axes[axis]
		if direction.length_squared() < 1.0:
			continue
		var score := absf(drag.normalized().dot(direction.normalized()))
		if score > best_score:
			best_score = score
			best = axis
	return best

## World units along one axis for a screen drag, given that axis's screen
## vector for one world unit.
static func along(drag: Vector2, direction: Vector2) -> float:
	return drag.dot(direction) / maxf(direction.length_squared(), 0.0001)

## The index of the screen direction closest to `offset`. A switch away from
## `current` needs a margin, so a finger near the halfway line does not flicker.
static func pick_direction(offset: Vector2, screen_directions: Array[Vector2], current := -1, margin := 0.05) -> int:
	if offset.length_squared() < 0.0001:
		return current
	var scores: Array[float] = []
	var best := -1
	for index: int in screen_directions.size():
		var direction := screen_directions[index]
		scores.append(offset.normalized().dot(direction.normalized()) if direction.length_squared() >= 1.0 else -INF)
		if best < 0 or scores[index] > scores[best]:
			best = index
	if current >= 0 and current < scores.size() and best != current and scores[best] < scores[current] + margin:
		return current
	return best

## Half-unit dots along one axis through `origin`, near the displayed pivot.
static func rail_dots(displayed: Vector3, origin: Vector3, limits: Dictionary, axis: int, strength := 1.0) -> Array[Dictionary]:
	var dots: Array[Dictionary] = []
	for value: float in _steps(displayed[axis], float(limits["min"][axis]), float(limits["max"][axis])):
		var point := origin
		point[axis] = value
		var weight := spatial_weight(absf(value - displayed[axis])) * strength
		if weight > 0.0:
			dots.append({"position": point, "weight": weight})
	return dots

static func rotation_angles(displayed_angle: float, increment: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if increment <= 0.0: return result
	# Use the current unwrapped revolution: debug steps need not divide 360 degrees.
	var first := ceili((displayed_angle-PI)/increment)
	var last := floori((displayed_angle+PI)/increment)
	for index: int in range(first,last+1):
		var angle := index*increment
		var weight := 1.0-smoothstep(0.0,PI,absf(angle-displayed_angle))
		if weight > 0.0: result.append({"angle":angle,"weight":weight})
	return result
