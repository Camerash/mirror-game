extends SceneTree

const Display := preload("res://core/display_geometry.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Rules := preload("res://core/mirror_state.gd")
const Levels := preload("res://core/level_loader.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var box := AABB(Vector3(-1,-1,-1), Vector3(2,2,2))
	var faces := Display.box_faces(box)
	check(is_equal_approx(Display.volume(faces), 8), "Box has outward closed faces")
	check(is_equal_approx(Display.volume(Display.clip(faces, Plane(Vector3.RIGHT, 0))), 4), "Half-box cap closes the cut")
	for path: String in DirAccess.get_files_at("res://levels"):
		if not path.ends_with(".json"):
			continue
		var level := Levels.load_level("res://levels/" + path)
		var state: Dictionary = level["mirror"].duplicate(true)
		state["enabled"] = true
		for pitch: int in 4:
			for yaw: int in 4:
				var discrete := Geometry.generate(level, state)
				var continuous := Display.generate(level, state, Rules.frame(state))
				var a := _volumes(discrete)
				var b := _volumes(continuous)
				for key: String in a.keys() + b.keys():
					check(absf(float(a.get(key,0)) - float(b.get(key,0))) < 0.001, "Snapped volume agrees: " + path + " " + key)
				state = Rules.turn(state, 1)
			state = Rules.tilt(state, 1)
	var level := Levels.load_level("res://levels/10_extent.json")
	var state: Dictionary = level["mirror"]
	var frame := Basis(Vector3.UP, 0.37) * Rules.frame(state)
	var result := Display.generate(level, state, frame)
	check(not result.is_empty(), "Arbitrary angle returns fragments")
	for fragment: Dictionary in result:
		if not fragment.has("faces"):
			continue
		check(Display.volume(fragment["faces"]) > Display.EPS, "Arbitrary fragments have volume")
		for absolute: Dictionary in level["absolutes"]:
			check(Display.volume(Display.intersect(fragment["faces"], Display.box_planes(Geometry.box(absolute)))) < 0.001, "Arbitrary fragments respect absolute priority")
	print("Display geometry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _volumes(solids: Array[Dictionary]) -> Dictionary:
	var result := {}
	for solid: Dictionary in solids:
		var key: String = str(solid["id"]) + ":" + str(solid["kind"])
		var value := Display.volume(solid["faces"]) if solid.has("faces") else (solid["bounds"] as AABB).get_volume()
		result[key] = float(result.get(key, 0)) + value
	return result
