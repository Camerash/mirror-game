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
	game.load_level(6)
	game.style = 1
	game._refresh()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/horizontal.png")
	print("Rendered layout captures saved to test-output/.")
	game.queue_free()
	await process_frame
	quit()
