extends SceneTree
## Reaching the goal: a walk that ends anywhere on the goal's tile finishes
## the stage, not only one that ends near the ring's centre. The agent
## playtest of 2026-10-29 stood on the goal tile, off centre, and nothing
## happened.

const Game := preload("res://game.gd")
const Geometry := preload("res://core/world_geometry.gd")

var game: Node3D
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for index: int in count:
		await process_frame


func run() -> void:
	root.size = Vector2i(1152, 800)
	for offset: Vector3 in [Vector3(0.3, 0, 0.25), Vector3(-0.3, 0, -0.28), Vector3(0.0, 0, 0.45)]:
		await check_tap_on_goal_tile(offset)
	print("Goal tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_tap_on_goal_tile(offset: Vector3) -> void:
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	await frames(2)
	check(game.load_level(Game.LEVEL_PATHS.find("res://levels/13_first_steps.json")), "Loads First steps")
	for index: int in 120:
		if game.settle_frames == 0 and game.phase == "play" and not game.camera.busy:
			break
		await process_frame
	var goal := Geometry.vector(game.level["goal"])
	check(game.request_walk(goal + offset), "A walk to the goal tile at offset %s starts" % offset)
	for index: int in 900:
		if game.phase == "complete" or (game.walker.route.is_empty() and index > 30):
			break
		await process_frame
	await frames(5)
	check(game.phase == "complete", "Standing on the goal tile at offset %s completes the stage (phase %s, %.2f from the goal)" % [offset, game.phase, game.walker.position.distance_to(goal)])
	game.queue_free()
	await frames(2)
