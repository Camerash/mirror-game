extends SceneTree
const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const Rules := preload("res://core/mirror_state.gd")
const Game := preload("res://game.gd")
var failures: Array[String] = []
var count := 0
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_geometry()
	_resize_rules()
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	game.load_level(Game.LEVEL_PATHS.size() - 1)
	await settle()
	game.edit_mirror()
	await settle()
	game.change_preview("width", 1.0)
	await settle()
	check(game.preview["width"] == 1.0 and game.mirror["width"] == 3.0, "Size editing leaves committed mirror unchanged")
	check(game.apply_preview(), "Bounded size proposal can be confirmed")
	await settle()
	check(game.undo(), "Undo accepts bounded size change")
	await settle()
	check(game.mirror["width"] == 3.0, "Undo restores panel dimensions")
	game.edit_mirror()
	await settle()
	game.change_preview("height", 2.0)
	game.cancel_preview()
	await settle()
	check(game.mirror["height"] == 3.0, "Cancel restores dimensions")
	game.edit_mirror()
	await settle()
	game.remove_mirror()
	await settle()
	check(game.apply_preview(), "Removal restores originals on absolute support")
	await settle()
	check(game.mirror == {"enabled": false}, "Removed panel has no retained transform or dimensions")
	game.begin_preview()
	await settle()
	check(game.preview["width"] == 3.0 and game.preview["height"] == 3.0, "Fresh creation uses default dimensions")
	var pivot: Vector3 = game.preview["pivot"]
	game.tilt_mirror(1)
	await settle()
	check(game.preview["axis"] == 1 and game.preview["pivot"] == pivot, "Bounded horizontal placement keeps pivot")
	game.change_preview("source", -int(game.preview["source"]))
	await settle()
	check(game.preview["pivot"] == pivot, "Source reversal leaves pivot unchanged")
	game.cancel_preview()
	await settle()
	await _resize_input()
	game.queue_free()
	await process_frame
	print("Bounded mirror checks: %d, failures: %d" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _geometry() -> void:
	var data := Levels.load_level("res://levels/10_extent.json")
	var state: Dictionary = data["mirror"].duplicate(true)
	state.merge({"width":3.0, "height":3.0}, true)
	var bounded := Geometry.generate(data, state)
	check(_contains(bounded, Vector3(4, 0.5, 2), "original"), "Original side obstacle stays outside bounded column")
	check(_contains(bounded, Vector3(3, -0.5, 0), "reflected") and not _contains(bounded, Vector3(3, -0.5, 2), "reflected"), "Panel selects centre source ledge only")
	state["width"] = 4.0
	var narrow_cut := Geometry.selected_source(Geometry.box(data["originals"][2]), state)
	check(is_equal_approx(narrow_cut.end.z, 2.0), "Aperture cuts a partially selected source box")
	state["height"] = 1.0
	check(not Geometry.has_volume(Geometry.selected_source(Geometry.box(data["originals"][0]), state)), "Panel height selects source geometry independently")
	state["width"] = 3.0
	state["height"] = 3.0
	state["offset"] = 1.25
	state["pivot"].x = 1.25
	var cut := Geometry.generate(data, state)
	for solid: Dictionary in cut:
		var mapping: Transform3D = solid["material_to_world"]
		check(solid.has("source_id") and solid.has("source_bounds"), "Pieces preserve source metadata")
		if solid["source_id"] == "ledge_0" and solid["kind"] == "original":
			check(mapping.origin == Vector3(1,-0.5,0), "Cut stone retains its uncut material origin")
		if solid["source_id"] == "ledge_0" and solid["kind"] == "reflected":
			var sample := Vector3(0.1,0.5,0.2)
			check((mapping.affine_inverse() * (mapping * sample)).is_equal_approx(sample), "Reflected material coordinates survive clipping")
		for absolute: Dictionary in data["absolutes"]:
			if solid["kind"] != "absolute":
				check(not Geometry.has_volume(solid["bounds"].intersection(Geometry.box(absolute))), "Absolutes keep priority in bounded mode")
	var reflection := Geometry.reflection_transform(state)
	check((reflection * reflection).is_equal_approx(Transform3D.IDENTITY), "Reflection material transforms compose reversibly")
	var crossing := {"originals":[{"id":"a","center":[0,-0.5,0],"size":[1,1,1]}, {"id":"b","center":[1,-0.5,1],"size":[1,1,1]}],"absolutes":[]}
	var panel := {"enabled":true,"axis":0,"source":1,"offset":0.5,"pivot":Vector3(0.5,0,0),"width":1.0,"height":2.0}
	check(Geometry.clear_segment(Vector3(1,0,0), Vector3(1,0,1), Geometry.generate(crossing,panel)), "Connected surfaces allow crossing the column side")

func _contains(solids: Array[Dictionary], point: Vector3, kind: String) -> bool:
	return solids.any(func(solid: Dictionary) -> bool: return solid["kind"] == kind and solid["bounds"].has_point(point))

func settle() -> void:
	for frame: int in 180:
		await physics_frame
		if frame > 4 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	check(false, "Interaction settles within three seconds")

func _resize_rules() -> void:
	var state := {"enabled":true,"axis":0,"source":1,"offset":2.5,"pivot":Vector3(2.5,0,0),"width":3.0,"height":3.0}
	for dimension: String in ["width", "height"]:
		var direction := Rules.frame(state).x if dimension == "width" else Rules.frame(state).y
		var fixed: Vector3 = state["pivot"] - direction * 1.5
		var grown := Rules.resized(state, dimension, 4)
		check((grown["pivot"] - direction * 2.0).is_equal_approx(fixed), "Opposite edge stays fixed on " + dimension)
		check(grown["pivot"] == state["pivot"] + direction * 0.5, "Whole resize moves centre by half unit")
		for cycle: int in 10:
			state = Rules.resized(Rules.resized(state, dimension, 6), dimension, 3)
		check(state["pivot"] == Vector3(2.5,0,0), "Repeated resize has no drift")
		var turned := Rules.turn(grown, 1)
		check(turned["pivot"] == grown["pivot"] and turned["offset"] == snappedf(turned["offset"], 0.5), "Rotation preserves resized centre and half-unit offset")
	var limited := {"min":[-5,-5,0],"max":[5,5,5]}
	check(Rules.resize_range(state,"width",limited).y == 3, "Resize limit cannot move centre beyond permitted area")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/10_extent.json"))
	raw["mirror"]["width"] = 1.5
	check(not Levels.validate(raw).is_empty(), "Fractional initial size is rejected")
	raw["mirror"]["width"] = 3
	raw["mirror"]["pivot"][2] = 0.25
	check(not Levels.validate(raw).is_empty(), "Quarter-unit initial centre is rejected")

func _resize_input() -> void:
	game.load_level(Game.LEVEL_PATHS.size() - 1)
	await settle()
	game.edit_mirror()
	await settle()
	game.set_edit_mode("resize")
	await settle()
	var tabs: Dictionary = game.resize_controls.get_control_rects()
	check(tabs.has("height"), "Top resize tab is accessible")
	if not tabs.has("height"):
		return
	var first: Vector2 = tabs["height"].get_center()
	var initial: Dictionary = game.preview.duplicate(true)
	var old_solids: Array = game.solids.duplicate(true)
	var old_camera: Transform3D = game.camera.transform
	var old_scale: float = game.camera.size
	game._pointer(first, true, 0)
	check(game.resizing and game.resize_controls.owns_pointer(0), "Resize starts on pointer down and keeps ownership")
	game.resize_controls.motion(first + game.resize_screen_axis * 1.4, 0)
	check(is_equal_approx(game.display_target.get("height",0),4.0) and game.preview == initial, "Resize selects a whole-unit display target without committing")
	await create_timer(0.12).timeout
	check(is_equal_approx(game.display_preview.get("height",0),4.0), "Resize display reaches the selected target")
	check(game.solids == old_solids and game.camera.transform == old_camera and game.camera.size == old_scale, "Resize freezes collision and camera")
	check(not game.apply_preview() and not game.preview_view.ghost.visible, "Resize blocks confirm and stale ghost")
	game._pointer(Vector2(-50,-50), false, 0)
	check(game.translating_settle and is_equal_approx(game.display_target.get("height",0),4.0) and not game.apply_preview(), "Outside release preserves the selected target without confirming")
	await settle()
	check(game.phase == "preview" and game.preview["height"] == 4 and game.preview["pivot"] == initial["pivot"] + Vector3.UP * 0.5, "Resize ends on whole size and half-unit centre")
	game.tilt_mirror(1)
	await settle()
	check(game.preview["pivot"] == initial["pivot"] + Vector3.UP * 0.5, "Tilt after resize does not shift centre")
	game.cancel_preview()
	await settle()
	check(game.mirror["height"] == 3 and game.mirror["pivot"] == initial["pivot"], "Cancel restores size and centre")
