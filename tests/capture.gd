extends SceneTree
## Run without --headless: captures actual rendered layouts to ignored test-output/.

const Game := preload("res://game.gd")

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var game := Game.new()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute("res://test-output")
	FileAccess.open("res://test-output/.gdignore", FileAccess.WRITE).close()
	for dimensions: Vector2i in [Vector2i(1152, 800), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024)]:
		root.size = dimensions
		for style: int in [0, 1]:
			game.load_level(0)
			game.style = style
			game.begin_preview()
			game.change_preview("enabled", true)
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			var path := "res://test-output/level1-%dx%d-style%d.png" % [dimensions.x, dimensions.y, style]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("Screenshot failed: " + path)
				quit(1)
				return
	root.size = Vector2i(1152, 800)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/07_horizontal.json"))
	game.style = 1
	game._refresh()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/horizontal.png")
	if not await _capture_reveal(game):
		quit(1)
		return
	print("Rendered layout captures saved to test-output/.")
	game.queue_free()
	await process_frame
	quit()

func _capture_reveal(game: Node3D) -> bool:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/08_reveal.json"))
	game.begin_preview()
	game.change_preview("enabled", true)
	game.apply_preview()
	for tick: int in range(5):
		await physics_frame
	if not game.request_walk(Vector3(5, 0, 0)):
		push_error("Level 2 capture could not start its route")
		return false
	for tick: int in range(600):
		await physics_frame
		if game.walker.route.is_empty():
			break
	if game.walker.position.distance_to(Vector3(5, 0, 0)) > 0.04:
		push_error("Level 2 capture did not reach its stopping point")
		return false
	for dimensions: Vector2i in [Vector2i(1152, 800), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024)]:
		root.size = dimensions
		for enabled: bool in [true, false]:
			game.begin_preview()
			game.change_preview("enabled", enabled)
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			var path := "res://test-output/level2-%dx%d-mirror-%s.png" % [dimensions.x, dimensions.y, str(enabled)]
			if root.get_texture().get_image().save_png(path) != OK:
				push_error("Screenshot failed: " + path)
				return false
	return true
