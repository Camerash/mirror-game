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
				var legacy := state.duplicate(true)
				for field: String in ["yaw", "pitch", "source_sign"]:
					legacy.erase(field)
				var discrete := Geometry.generate(level, legacy)
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
	_check_carried()
	print("Display geometry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _route_mirror(level: Dictionary, pivot: Vector3, degrees: float) -> Dictionary:
	var state: Dictionary = level["mirror"].duplicate(true)
	state.merge({"enabled": true, "pivot": pivot, "yaw": deg_to_rad(degrees), "pitch": 0.0, "source_sign": 1}, true)
	return Rules.sync(state)

func _check_carried() -> void:
	## The traveller goes with the copy she stands on (owner, 2026-11-18).
	## In `01_route` a mirror at x 2.5 copies the platforms (x -0.5 to 2.5) to
	## x 2.5 to 4.5; an absolute platform is at x 4.5 to 5.5.
	var level := Levels.load_level("res://levels/01_route.json")
	var before := _route_mirror(level, Vector3(2.5, 0, 0), 90)
	var solids := Geometry.generate(level, before)
	var on_copy := Vector3(3.5, 0, 0)
	var slid := _route_mirror(level, Vector3(4, 0, 0), 90)
	check(Geometry.carried(on_copy, before, solids, slid, Geometry.generate(level, slid)).is_equal_approx(Vector3(6.5, 0, 0)),
		"Carried: a slide of 1.5 takes her 3 along with her copy")
	var turned := _route_mirror(level, Vector3(2.5, 0, 0), 45)
	check(Geometry.carried(on_copy, before, solids, turned, Geometry.generate(level, turned)).distance_to(Vector3(2.5, 0, 1)) < 0.001,
		"Carried: a turn of 45 degrees takes her a quarter circle round the pivot")
	# At 3.25 her part of the copy would be in the absolute platform, which has
	# the same height. That platform is then her floor.
	var onto := _route_mirror(level, Vector3(3.25, 0, 0), 90)
	check(Geometry.carried(on_copy, before, solids, onto, Geometry.generate(level, onto)).is_equal_approx(Vector3(5, 0, 0)),
		"Carried: she rides onto a fixed block that stands where her copy would be")
	var far := _route_mirror(level, Vector3(5.5, 0, 0), 90)
	check(Geometry.carried(on_copy, before, solids, far, Geometry.generate(level, far)).is_equal_approx(on_copy),
		"Carried: she stays when the new mirror no longer copies her block")
	check(Geometry.carried(Vector3(1, 0, 0), before, solids, slid, Geometry.generate(level, slid)).is_equal_approx(Vector3(1, 0, 0)),
		"Carried: ground that does not move holds her")
	var lowered := slid.duplicate(true)
	lowered["enabled"] = false
	check(Geometry.carried(on_copy, before, solids, lowered, Geometry.generate(level, lowered)).is_equal_approx(on_copy),
		"Carried: she stays when the mirror is lowered")

func _volumes(solids: Array[Dictionary]) -> Dictionary:
	var result := {}
	for solid: Dictionary in solids:
		var key: String = str(solid["id"]) + ":" + str(solid["kind"])
		var value := Display.volume(solid["faces"]) if solid.has("faces") else (solid["bounds"] as AABB).get_volume()
		result[key] = float(result.get(key, 0)) + value
	return result
