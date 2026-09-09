extends SceneTree
## One Mac review of bounded resizing, stable rotation arcs and edge-light material.
const Game := preload("res://game.gd")
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	game.load_level(Game.LEVEL_PATHS.size() - 1)
	await _settle()
	game.edit_mirror()
	await _settle()
	for view: int in 4:
		await _capture("bounded-view-%d" % view)
		game.turn_camera(1)
		await _settle()
	game.set_edit_mode("rotate")
	await _settle()
	# Exercise the visible turn arc controller.
	var turn_points := game.rings.get_arc_points("turn")
	var original: Dictionary = game.preview.duplicate(true)
	assert(not turn_points.is_empty(), "Visible turn arc has input points")
	var first: Vector2 = turn_points[12]
	assert(game.rings.pointer(first, true, 0), "Visible turn arc accepts input")
	game.rings.motion(turn_points[20], 0)
	game.rings.pointer(Vector2(-50, -50), false, 0)
	await _settle()
	assert(is_equal_approx(game.preview["yaw"] - original["yaw"], PI / 3.0) and game.preview["pivot"] == original["pivot"], "Turn arc selects 60 degrees and preserves the centre")
	game.set_edit_mode("resize")
	await _settle()
	var tab: Rect2 = game.resize_controls.get_control_rects()["height"]
	game._pointer(tab.get_center(), true, 0)
	game.resize_controls.motion(tab.get_center() + game.resize_screen_axis * 1.2, 0)
	game._pointer(Vector2(-50,-50), false, 0)
	await _settle()
	await _capture("bounded-resized")
	game.change_preview("offset", 1.5)
	await _settle()
	await _capture("extent-cut")
	game.tilt_mirror(1)
	await _settle()
	await _capture("extent-horizontal")
	root.size = Vector2i(390, 844)
	await _settle()
	await _capture("extent-portrait")
	game.load_level(0)
	await _settle()
	game.begin_preview()
	await _settle()
	await _capture("extent-level1-portrait")
	root.size = Vector2i(1152, 800)
	await _settle()
	game.change_preview("width", 1)
	await _settle()
	game.change_preview("height", 1)
	await _settle()
	await _capture("bounded-small")
	game.change_preview("width", 6)
	await _settle()
	game.change_preview("height", 6)
	await _settle()
	await _capture("bounded-large")
	game.cancel_preview()
	await _settle()
	game.walker.restore(Vector3(3.5,0,0),Vector3.ZERO)
	game.begin_preview()
	await _settle()
	game.remove_mirror()
	await _settle()
	await _capture("bounded-fall")
	print("Bounded native review: four views, turn arc, resize, small/large, horizontal, fall and portrait complete.")
	game.queue_free()
	await process_frame
	quit()

func _settle() -> void:
	for tick: int in 240:
		await physics_frame
		if tick > 30 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	assert(false, "Review action did not settle")

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/%s.png" % label)
