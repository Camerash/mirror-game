extends SceneTree
## One native desktop/portrait review session for the smooth art trial.
const Game := preload("res://game.gd")
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	await _settle()
	await _capture("smooth-play")
	game.begin_preview()
	await _settle()
	for view: int in range(4):
		await _capture("smooth-edit-%d" % view)
		game.turn_camera(1)
		await _settle()
	game.apply_preview()
	await _settle()
	await _capture("smooth-placed")
	game.walker.restore(Vector3(3.5, 0, 0), Vector3.ZERO)
	game.edit_mirror()
	game.remove_mirror()
	await _settle()
	game.preview_view.elapsed = game.preview_view.duration * 0.45
	await _capture("smooth-fall")
	game.cancel_preview()
	game.walker.restore(Vector3.ZERO, Vector3.ZERO)
	root.size = Vector2i(390, 844)
	game.edit_mirror()
	await _settle()
	await _capture("smooth-portrait")
	print("Smooth native review captured desktop, four views, fall and portrait.")
	game.queue_free()
	await process_frame
	quit()

func _settle() -> void:
	for tick: int in range(90):
		await physics_frame
		if tick > 30 and not game.camera.busy and not game.sheet.is_transitioning() and game.prediction["status"] != "pending":
			return

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/%s.png" % label)
