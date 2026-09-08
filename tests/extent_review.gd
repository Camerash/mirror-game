extends SceneTree
## One Mac review of the two candidate mirror extents and world-space rings.
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
	await _capture("extent-full")
	game._action("extent", "bounded")
	await _settle()
	game.edit_mirror()
	await _settle()
	for view: int in 4:
		await _capture("extent-bounded-%d" % view)
		game.turn_camera(1)
		await _settle()
	# Exercise the real ring/controller contract with one held revolution.
	var ring: Dictionary = game.rings._yaw.duplicate(true)
	var start: float = ring["orb_angle"]
	var original: Dictionary = game.preview.duplicate(true)
	var first: Vector2 = game.camera.unproject_position(game.rings._ring_point(ring, start))
	assert(game.rings.pointer(first, true, 0), "Visible yaw orb accepts input")
	for step: int in range(1, 25):
		var point: Vector2 = game.camera.unproject_position(game.rings._ring_point(ring, start + TAU * step / 24.0))
		game.rings.motion(point, 0)
	game.rings.pointer(Vector2(-50, -50), false, 0)
	await _settle()
	assert(game.preview["axis"] == original["axis"] and game.preview["source"] == original["source"], "Held revolution completes four turns")
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
	game._action("extent", "full")
	await _settle()
	game.begin_preview()
	await _settle()
	await _capture("extent-level1-full")
	print("Extent native review: both modes, four views, held ring cycle, cut, horizontal and portrait complete.")
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
