extends SceneTree
## Does a level's intended solution actually reach the goal, and do the near
## misses actually fail?
##
## A level is only a puzzle if the wrong answer is reachable and wrong. These
## checks drive the real preview path rather than writing geometry directly, so
## they exercise the same rules a player does.

const Game := preload("res://game.gd")

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


func idle() -> void:
	## Editing is refused while the level settles or the camera blends, and a
	## resize is silently dropped while the camera is busy, so every step waits.
	for index: int in 600:
		if game.pending.is_empty() and not game.camera.busy and game.settle_frames == 0:
			return
		await process_frame


func camera_idle() -> void:
	for index: int in 600:
		if not game.camera.busy and not game._manipulating():
			return
		await process_frame


func prediction_settled() -> String:
	for index: int in 600:
		var status := str(game.prediction.get("status", "idle"))
		if status not in ["pending", "idle", "unresolved"]:
			return status
		await process_frame
	return str(game.prediction.get("status", "idle"))


func load_level(file: String) -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/%s.json" % file))
	await idle()


func place(axis: int, source: int, offset: float, width: float, height: float) -> bool:
	game.begin_preview()
	game.change_preview("enabled", true)
	game.change_preview("axis", axis)
	game.change_preview("source", source)
	game.change_preview("offset", offset)
	await camera_idle()
	game.change_preview("width", width)
	await camera_idle()
	game.change_preview("height", height)
	await camera_idle()
	var status := await prediction_settled()
	if status == "blocked":
		game.cancel_preview()
		await idle()
		return false
	var applied: bool = game.apply_preview()
	await idle()
	return applied


func reaches_goal() -> bool:
	var goal: Vector3 = Vector3(game.level["goal"][0], game.level["goal"][1], game.level["goal"][2])
	return not game.navigation.route(game.walker.position, goal).is_empty()


func run() -> void:
	game = Game.new()
	root.add_child(game)
	await frames(2)
	await check_aperture()
	game.queue_free()
	await frames(1)
	print("Level solvability: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_aperture() -> void:
	## "Only the ground": the reflection carries the tower along with the ledge
	## unless the aperture is shortened to the ground band.
	await load_level("11_aperture")
	check(str(game.level["title"]) == "Only the ground", "The aperture level loads")
	check(not reaches_goal(), "Without a mirror the goal is out of reach")

	await load_level("11_aperture")
	check(await place(0, 1, 2.0, 3.0, 3.0), "A full-height mirror can be placed")
	check(not reaches_goal(), "A full-height mirror brings the tower across and blocks the way")

	await load_level("11_aperture")
	check(await place(0, 1, 2.0, 3.0, 1.0), "A one-high mirror can be placed")
	check(reaches_goal(), "A one-high mirror brings only the ground across and opens the way")
