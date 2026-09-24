extends SceneTree
## Native review of the block gallery: every look in the master block set,
## shown through the real game renderer, at desktop and phone sizes.
##
## Run without --headless:
##   godot --path . --script tests/block_gallery_review.gd
## Saves frames to the ignored test-output/ directory.
##
## Add -- --sweep to instead complete Level 1 through real commands and
## review the stage sweep to Level 2, at 0/25/50/75/100% of its own
## grow-sweep-shrink duration (the ADVANCE_PAUSE before it is not part of
## that span):
##   godot --path . --script tests/block_gallery_review.gd -- --sweep

const Game := preload("res://game.gd")
const Sweep := preload("res://world/stage_sweep.gd")

var game: Node3D
var shots := 0


func _initialize() -> void:
	if "--sweep" in OS.get_cmdline_user_args():
		_run_sweep.call_deferred()
	else:
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


func _run_sweep() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await _settle()
	# Solve Level 1 through the same real commands as run_tests.gd's
	# progression check, so the sweep starts exactly as a player would see it.
	game.begin_preview()
	await _settle()
	game.change_preview("enabled", true)
	await _settle()
	game.apply_preview()
	await _settle()
	game.request_walk(Vector3(5, 0, 0))
	await _walk_settle()
	game.begin_preview()
	await _settle()
	game.change_preview("offset", 4.0)
	await _settle()
	game.apply_preview()
	await _settle()
	game.request_walk(Vector3(8, 0, 0))
	await _walk_settle()
	await _wait_until(func() -> bool: return game.sweep.active)
	var total := Sweep.GROW_TIME + Sweep.SWEEP_TIME + Sweep.SHRINK_TIME
	await _capture("sweep-0")
	for fraction: float in [0.25, 0.5, 0.75, 0.995]:
		await _wait_sweep_fraction(total, fraction)
		await _capture("sweep-%d" % roundi(fraction * 100))
	print("Saved %d sweep frames to test-output/." % shots)
	game.queue_free()
	await process_frame
	quit()


func _walk_settle() -> void:
	for tick: int in 600:
		await physics_frame
		if game.walker.route.is_empty():
			await _settle()
			return
	assert(false, "Walk did not finish")


func _wait_until(predicate: Callable) -> void:
	for tick: int in 300:
		if predicate.call():
			return
		await physics_frame
	assert(false, "Review action did not settle")


func _wait_sweep_fraction(total: float, fraction: float) -> void:
	var target := total * fraction
	while game.sweep.active and game.sweep._elapsed < target:
		await physics_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-output")
	root.get_texture().get_image().save_png("res://test-output/%s.png" % label)
	shots += 1
