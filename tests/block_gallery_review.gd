extends SceneTree
## Native review of the block gallery: every look in the master block set,
## shown through the real game renderer, at desktop and phone sizes.
##
## Run without --headless:
##   godot --path . --script tests/block_gallery_review.gd
## Saves frames to the ignored test-output/ directory.

const Game := preload("res://game.gd")

var game: Node3D
var shots := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/12_block_gallery.json"))
	await _settle()
	for view: int in 4:
		await _capture("block-gallery-wide-%d" % view)
		game.turn_camera(1)
		await _settle()
	root.size = Vector2i(390, 844)
	await _settle()
	await _capture("block-gallery-portrait")
	root.size = Vector2i(1152, 800)
	await _settle()
	# A close view. There is no dedicated zoom command; the camera's own
	# orthogonal "size" property, set directly, is the only zoom control.
	var wide_size: float = game.camera.size
	game.camera.size = wide_size * 0.35
	await _capture("block-gallery-close")
	game.camera.size = wide_size
	await _settle()
	# The committed mirror is axis-aligned, so every fragment is a box. Turn
	# it 30 degrees in preview, through the same drag path as the turn ring,
	# to show the polygon cut path. A tilt step is 90 degrees, so it stays
	# axis-aligned and shows no angled cut.
	game.begin_preview()
	await _settle()
	game._start_rotation({"kind": "turn", "axis": Vector3.UP})
	game._set_rotation_angle(deg_to_rad(30.0))
	game._finish_rotation_drag()
	await _settle()
	await _capture("block-gallery-turned")
	print("Saved %d frames to test-output/." % shots)
	game.queue_free()
	await process_frame
	quit()


func _settle() -> void:
	for tick: int in 240:
		await physics_frame
		if tick > 30 and game.pending.is_empty() and not game.camera.busy \
				and game.settle_frames == 0 and not game._manipulating():
			return
	assert(false, "Review action did not settle")


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/%s.png" % label)
	shots += 1
