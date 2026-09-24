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


## The helpers below follow the same paths a player uses, instead of `place`'s
## direct calls into `change_preview`. Use them where the player's exact route
## to a placement matters (for example, where a mirror lands and starts).


func create_at(x: float, z: float) -> void:
	## The real hold-to-create path: press an empty point at the walker's feet
	## height. `create_mirror` projects the press onto that plane and snaps
	## the pivot to the half-unit grid; see game.gd.
	var point: Vector2 = game.camera.unproject_position(Vector3(x, game.walker.position.y, z))
	game.create_mirror(point)
	await camera_idle()


func set_size(key: String, value: float) -> void:
	## The real resize path: `place` already drives width/height this way.
	game.change_preview(key, value)
	await camera_idle()


func turn(direction: int) -> void:
	## The quarter-turn button path. `camera_idle` already waits for
	## `rotation_target` to empty, because `_manipulating` checks it.
	game.rotate_mirror(direction)
	await camera_idle()


func turn_to(degrees: float) -> void:
	## The ring drag path (see tests/block_gallery_review.gd).
	game._start_rotation({"kind": "turn", "axis": Vector3.UP})
	game._set_rotation_angle(deg_to_rad(degrees))
	game._finish_rotation_drag()
	await camera_idle()


func raise(steps: int) -> void:
	## The height arrow / PgUp path, one half-unit step at a time.
	for index: int in steps:
		game._step_height(0.5)
		await camera_idle()


func lower(steps: int) -> void:
	## The height arrow / PgDown path, one half-unit step at a time.
	for index: int in steps:
		game._step_height(-0.5)
		await camera_idle()


func confirm() -> String:
	## Applies the preview as the Confirm control does, and reports the
	## prediction status the game saw: "supported", "landing", "failure", or
	## "blocked". A blocked placement cannot be confirmed, so this cancels it
	## instead, matching what the player sees.
	var status := await prediction_settled()
	if status == "blocked":
		game.cancel_preview()
		await idle()
		return "blocked"
	game.apply_preview()
	await idle()
	return status


func settle_fall() -> void:
	## Waits, after a confirm, until the walker is grounded and not falling,
	## or the stage has failed.
	for index: int in 600:
		if game.phase == "failure":
			return
		if (game.walker.grounded or game.walker.is_on_floor()) and absf(game.walker.velocity.y) < 0.01:
			return
		await process_frame


func walk_to(target: Vector3) -> bool:
	## Requests a walk and waits for arrival, as run_tests.gd's
	## `_walk_finished` does. Returns whether the walker arrived.
	if not game.request_walk(target):
		return false
	for index: int in 600:
		await process_frame
		if game.walker.route.is_empty():
			await frames(3)
			break
	return game.walker.position.distance_to(target) < 0.22


func reaches_goal() -> bool:
	var goal: Vector3 = Vector3(game.level["goal"][0], game.level["goal"][1], game.level["goal"][2])
	return not game.navigation.route(game.walker.position, goal).is_empty()


func run() -> void:
	# create_at() projects a screen point through the camera, so the viewport
	# needs a real size; other checks here never needed one.
	root.size = Vector2i(1152, 800)
	game = Game.new()
	root.add_child(game)
	await frames(2)
	await check_aperture()
	await report_aperture_real_path("full-height", 3.0, 3.0)
	await report_aperture_real_path("one-high", 3.0, 1.0)
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


func report_aperture_real_path(label: String, width: float, height: float) -> void:
	## EXPECTED FINDING, not an assertion. 11_aperture's solution was tuned to
	## the default mirror's pivot height (0.5). The real hold-to-create path
	## instead plants the pivot at the walker's feet (y 0), so the resized
	## band lands half a unit away from the ledge. This case is only recorded,
	## not checked: the user will redesign this stage. See HANDOFF.md.
	await load_level("11_aperture")
	await create_at(2.0, 0.0)
	var created_pivot: Vector3 = game.preview.get("pivot", Vector3.INF)
	await set_size("width", width)
	await set_size("height", height)
	var sized_pivot: Vector3 = game.preview.get("pivot", Vector3.INF)
	var half_height: float = float(game.preview.get("height", 0.0)) * 0.5
	var status := await confirm()
	await settle_fall()
	var reflected_tops: Array[float] = []
	for solid: Dictionary in game.solids:
		if solid.get("kind") == "reflected":
			var bounds: AABB = solid["bounds"]
			reflected_tops.append(bounds.position.y + bounds.size.y)
	print("11_aperture real-path finding (%s): created pivot=%s, sized pivot=%s, panel y range=[%.2f, %.2f], reflected tops=%s, status=%s, route to goal=%s" %
		[label, created_pivot, sized_pivot, sized_pivot.y - half_height, sized_pivot.y + half_height, reflected_tops, status, reaches_goal()])
