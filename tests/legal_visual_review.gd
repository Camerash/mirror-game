extends SceneTree
## One focused desktop/portrait art review; no export or puzzle replay matrix.

const Game := preload("res://game.gd")
const Rules := preload("res://core/mirror_state.gd")
var game: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1152,800)
	game = Game.new()
	root.add_child(game)
	await settle()
	game.begin_preview()
	await settle()
	game.change_preview("offset", 5.0)
	await settle()
	for view: int in 4:
		await shot("contact-view-%d" % view)
		game.turn_camera(1)
		await settle()
	game._action("flip", null)
	await settle()
	await shot("source-reversed")
	game._action("flip", null)
	await settle()
	game._start_rotation({"kind":"tilt", "axis":Rules.frame(game.preview).x})
	game._set_rotation_angle(deg_to_rad(17))
	await shot("pitch-17")
	game._finish_rotation_drag()
	await settle()
	var centre: Vector3 = game.preview["pivot"]
	var pointer: Vector2 = game.camera.unproject_position(centre)
	game._start_drag(pointer)
	game._drag(game.camera.unproject_position(centre + Vector3(0.25,0,0.5)))
	await shot("movement-grid")
	game._finish_drag()
	await settle()
	root.size = Vector2i(390,844)
	await settle()
	await shot("portrait")
	game.cancel_preview()
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await settle()
	game.walker.restore(Vector3(3.5,0,0), Vector3.ZERO)
	game.begin_preview()
	game.change_preview("enabled", false)
	await settle()
	for tick: int in 12:
		await process_frame
	await shot("fall-portrait")
	game.queue_free()
	await process_frame
	print("Legal angle art review completed: desktop four views, reversal, pitch, grid, portrait, fall.")
	quit()

func settle() -> void:
	for tick: int in 300:
		await physics_frame
		if tick > 6 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	push_error("Visual review did not settle")

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://test-output/legal-%s.png" % label)
	if result != OK:
		push_error("Capture failed: " + label)
