extends "res://tests/level_solvability_tests.gd"
## Plays the whole tutorial through the App, from the title to the end card,
## with the player's own commands and the automatic mirror sweep between
## stages. Run it natively (without --headless): it saves one frame at the
## start of each stage, one during each sweep, and one of the end card, to
## test-output/playthrough-*.png.

const AppScene := preload("res://main.tscn")
const SAVE_PATH := "user://test_progress_playthrough.cfg"

var app: Node
var shots := 0


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/playthrough-%s.png" % name)
	shots += 1


func stage_file() -> String:
	return str(Game.LEVEL_PATHS[game.level_index]).get_file().get_basename()


## Waits through the sweep to the next stage, with one frame taken mid-sweep.
func next_stage(expected: String) -> void:
	for index: int in 600:
		if game.sweep.active:
			break
		await process_frame
	await frames(50)
	await shot("sweep-to-" + expected)
	for index: int in 900:
		if game.phase == "play" and not game.sweep.active and stage_file() == expected:
			break
		await process_frame
	await idle()
	check(stage_file() == expected, "Playthrough: the sweep arrives at %s" % expected)
	await shot(expected)


func run() -> void:
	root.size = Vector2i(1152, 800)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	app = AppScene.instantiate()
	app.progress_path = SAVE_PATH
	root.add_child(app)
	await frames(6)
	await shot("title")
	app._on_primary_pressed()
	game = app.game
	await frames(6)
	await idle()
	check(stage_file() == "13_first_steps", "Playthrough: Begin starts First steps")
	await shot("13_first_steps")

	# First steps: turn the view, then walk to the goal.
	game.turn_camera(1)
	await camera_idle()
	check(await walk_to(goal_point()), "Playthrough: First steps is walked")
	await next_stage("01_route")

	# A place to stand: a mirror at 2.5, rest, then the mirror at 4.0.
	await create_at(2.5, 0.0)
	await confirm()
	check(await walk_to(Vector3(5, 0, 0)), "Playthrough: the rest platform is reached")
	game.begin_preview()
	await idle()
	game.change_preview("offset", 4.0)
	await camera_idle()
	await confirm()
	check(await walk_to(goal_point()), "Playthrough: A place to stand is solved")
	await next_stage("08_reveal")

	# The path beneath: bridge, walk out, remove the mirror.
	await create_at(2.5, 0.0)
	await confirm()
	check(await walk_to(Vector3(5, 0, 0)), "Playthrough: the bridge is walked")
	await remove()
	await settle_fall()
	check(await walk_to(goal_point()), "Playthrough: The path beneath is solved")
	await next_stage("11_aperture")

	# Only the ground: a two-high mirror.
	await create_at(2.0, 0.0)
	await set_size("height", 2.0)
	await confirm()
	check(await walk_to(goal_point()), "Playthrough: Only the ground is solved")
	await next_stage("14_turn")

	# Another way round: a left turn at z 0.5.
	await create_at(0.0, 0.5)
	await turn(-1)
	await confirm()
	check(await walk_to(goal_point()), "Playthrough: Another way round is solved")
	await next_stage("15_together")

	# Together: turn, resize, walk out, remove, fall, walk.
	await create_at(0.0, 0.5)
	await turn(-1)
	await set_size("height", 2.0)
	await confirm()
	check(await walk_to(Vector3(0, 0, 4)), "Playthrough: the traveller stands above the low path")
	await remove()
	await settle_fall()
	check(await walk_to(goal_point()), "Playthrough: Together is solved")

	for index: int in 600:
		if app._end_layer.visible:
			break
		await process_frame
	check(app._end_layer.visible, "Playthrough: the end card shows after the last stage")
	await shot("end")
	app.queue_free()
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("Tutorial playthrough: %d checks, %d failures, %d frames" % [checks, failures, shots])
	quit(1 if failures else 0)
