class_name LevelLoader
extends RefCounted

const Rules := preload("res://core/mirror_state.gd")

static func load_level(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open level: " + path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("Invalid level JSON: " + path)
		return {}
	var data: Dictionary = parser.data
	var error := validate(data)
	if not error.is_empty():
		push_error(path + ": " + error)
		return {}
	# JSON numbers are floats. Normalize discrete fields once at the boundary.
	for dimension: String in ["width", "height"]:
		data["mirror"][dimension] = int(data["mirror"].get(dimension, 3))
	data["mirror"]["axis"] = int(data["mirror"]["axis"])
	data["mirror"]["source"] = int(data["mirror"]["source"])
	data["mirror"]["pivot"] = Vector3(data["mirror"]["pivot"][0], data["mirror"]["pivot"][1], data["mirror"]["pivot"][2])
	data["mirror"]["vertical_axis"] = data["mirror"]["axis"] if data["mirror"]["axis"] != 1 else 0
	data["mirror"]["vertical_source"] = data["mirror"]["source"]
	var axes: Array[int] = []
	for axis: float in data["limits"]["axes"]:
		axes.append(int(axis))
	data["limits"]["axes"] = axes
	if data["mirror"].has("yaw"):
		data["mirror"] = Rules.normalized(data["mirror"])
	return data

static func validate(data: Dictionary) -> String:
	for key: String in ["title", "objective", "originals", "absolutes", "start", "goal", "mirror", "limits", "kill_y"]:
		if not data.has(key):
			return "Missing field: " + key
	if not data["title"] is String or not data["objective"] is String:
		return "Title and objective must be text."
	if not _vector_valid(data["start"]) or not _vector_valid(data["goal"]):
		return "Start and goal must contain three finite numbers."
	for group: String in ["originals", "absolutes"]:
		if not data[group] is Array:
			return group + " must be an array."
		for item: Variant in data[group]:
			if not item is Dictionary or not item.get("id") is String \
					or not _vector_valid(item.get("center")) or not _vector_valid(item.get("size")):
				return "Each box needs an id, centre, and size."
			for length: float in item["size"]:
				if length <= 0.0:
					return "Box dimensions must be positive."
	if not data["mirror"] is Dictionary or not data["limits"] is Dictionary:
		return "Mirror and limits must be objects."
	var mirror: Dictionary = data["mirror"]
	if mirror.has("yaw") or mirror.has("pitch"):
		if not _number(mirror.get("yaw")) or not _number(mirror.get("pitch")) or not _integer_in(mirror.get("source_sign", 1), [-1, 1]):
			return "Angles must be finite radians with source sign +1 or -1."
	if not mirror.get("enabled") is bool or not _integer_in(mirror.get("axis"), [0, 1, 2]) \
			or not _integer_in(mirror.get("source"), [-1, 1]) or not _number(mirror.get("offset")):
		return "Invalid mirror state."
	if not _vector_valid(mirror.get("pivot")) or not is_equal_approx(float(mirror["pivot"][int(mirror["axis"])]), float(mirror["offset"])):
		return "Mirror pivot must lie on the initial plane."
	for dimension: String in ["width", "height"]:
		if not _integer_in(mirror.get(dimension, 3), [1, 2, 3, 4, 5, 6]):
			return "Mirror dimensions must be whole units from 1 to 6."
	for coordinate: float in mirror["pivot"]:
		if not is_equal_approx(coordinate, snappedf(coordinate, 0.5)):
			return "Mirror pivot must use the half-unit grid."
	var limits: Dictionary = data["limits"]
	if not limits.get("axes") is Array or limits["axes"].is_empty() \
			or not _vector_valid(limits.get("min")) or not _vector_valid(limits.get("max")):
		return "Invalid mirror limits."
	for axis: Variant in limits["axes"]:
		if not _integer_in(axis, [0, 1, 2]):
			return "Invalid allowed axis."
	for axis: int in range(3):
		if limits["min"][axis] > limits["max"][axis]:
			return "Minimum offset exceeds maximum."
		if mirror["pivot"][axis] < limits["min"][axis] or mirror["pivot"][axis] > limits["max"][axis]:
			return "Mirror pivot is outside the permitted area."
	if not limits["axes"].any(func(axis: Variant) -> bool: return int(axis) == int(mirror["axis"])) or not _number(data["kill_y"]):
		return "Invalid initial axis or fall boundary."
	var axis := int(mirror["axis"])
	if float(mirror["offset"]) < float(limits["min"][axis]) or float(mirror["offset"]) > float(limits["max"][axis]):
		return "Initial offset is outside the permitted area."
	return ""

static func _integer_in(value: Variant, allowed: Array) -> bool:
	return _number(value) and float(value) == float(int(value)) and allowed.has(int(value))

static func _vector_valid(value: Variant) -> bool:
	return value is Array and value.size() == 3 and _number(value[0]) and _number(value[1]) and _number(value[2])

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
