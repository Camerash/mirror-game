extends SceneTree
## Does a level's intended solution actually reach the goal, and do the near
## misses actually fail?
##
## A level is only a puzzle if the wrong answer is reachable and wrong. These
## checks drive the real preview path rather than writing geometry directly, so
## they exercise the same rules a player does.

const Game := preload("res://game.gd")
const MirrorRules := preload("res://core/mirror_state.gd")

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


func goal_point() -> Vector3:
	return Vector3(game.level["goal"][0], game.level["goal"][1], game.level["goal"][2])


func goal_visible() -> bool:
	## True when a ray from the camera to the goal ring hits nothing first.
	var target := goal_point() + Vector3.UP * 0.05
	var screen: Vector2 = game.camera.unproject_position(target)
	var origin: Vector3 = game.camera.project_ray_origin(screen)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + game.camera.project_ray_normal(screen) * 200.0)
	ray.collision_mask = 1
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 0.6


func remove() -> String:
	game.begin_preview()
	await idle()
	game.remove_mirror()
	await camera_idle()
	return await confirm()


## --- Direct controls ----------------------------------------------------
## The same stages through the direct controls the game plays with: the
## mirror button, a drag on the mirror along one axis, and the arrow. Each
## action applies on release, so every helper waits for that.


func direct_settled() -> void:
	## Waits until a direct action has applied (or gone back) and the stage
	## has settled again.
	for index: int in 600:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy:
			return
		await process_frame


func press_mirror_button() -> void:
	game.toggle_mirror()
	await direct_settled()


func slide(axis: int, units: float) -> void:
	## A finger on the mirror's centre drags along one axis's screen direction
	## (0 x, 1 y, 2 z) by `units`, then lifts.
	var pivot: Vector3 = game.mirror["pivot"]
	var direction: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]
	var start: Vector2 = game.camera.unproject_position(pivot)
	var finish: Vector2 = game.camera.unproject_position(pivot + direction * units)
	game.begin_slide(start)
	for step: int in range(1, 13):
		game.slide_to(start.lerp(finish, step / 12.0))
		await process_frame
	await frames(8)
	game.end_slide()
	await direct_settled()


func point(direction: Vector3) -> void:
	## The arrow is held, pointed along a grid direction, and let go.
	game.begin_point()
	game.point_toward(direction)
	await frames(8)
	game.end_point()
	await direct_settled()


func direct_fall() -> void:
	## Like `settle_fall`, but counts only after two unpaused physics steps: a
	## direct change applies without a camera blend, so a floor contact left
	## over from before the change must not read as a landing.
	var unpaused_at := -1
	for index: int in 900:
		if game.phase in ["failure", "complete", "transition"]:
			return
		if game.walker.paused or game.settle_frames > 0:
			unpaused_at = -1
		elif unpaused_at < 0:
			unpaused_at = Engine.get_physics_frames()
		elif Engine.get_physics_frames() - unpaused_at >= 2 and (game.walker.grounded or game.walker.is_on_floor()) and absf(game.walker.velocity.y) < 0.01:
			return
		await process_frame


func pivot_is(expected: Vector3) -> bool:
	return game.mirror.has("pivot") and (game.mirror["pivot"] as Vector3).is_equal_approx(expected)


func run_direct() -> void:
	game = Game.new()
	game.direct_controls = true
	# A reached goal must not sweep the game on to the next stage mid-check.
	game.auto_advance = false
	root.add_child(game)
	await frames(2)
	await check_direct_route()
	await check_direct_reveal()
	await check_direct_aperture()
	await check_direct_turn()
	await check_direct_together()
	game.queue_free()
	await frames(1)


func check_direct_route() -> void:
	## "A place to stand": raise, slide to 2.5, rest on jade, slide on to 4.0.
	await load_level("01_route")
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and pivot_is(Vector3(0.5, 0, 0)), "Direct route: the first raise stands the mirror just in front of the traveller")
	await slide(0, 2.0)
	check(pivot_is(Vector3(2.5, 0, 0)), "Direct route: a drag along X slides the mirror to 2.5")
	check(await walk_to(Vector3(5, 0, 0)), "Direct route: the copy reaches the rest platform")
	await slide(0, 1.5)
	check(pivot_is(Vector3(4, 0, 0)), "Direct route: a second drag slides the mirror on to 4.0")
	check(await walk_to(goal_point()), "Direct route: the mirror at 4.0 opens the way to the goal")
	await load_level("01_route")
	await press_mirror_button()
	await slide(0, 2.0)
	check(await walk_to(Vector3(4, 0, 0)), "Direct route: the traveller stands on the copy")
	await slide(0, 1.5)
	await direct_fall()
	check(game.phase == "failure", "Direct route: moving the mirror from under the traveller is a fall")
	check(game.undo(), "Direct route: Undo is offered after the fall")
	await direct_settled()
	check(game.phase == "play" and pivot_is(Vector3(2.5, 0, 0)), "Direct route: Undo puts the mirror and the traveller back")


func check_direct_reveal() -> void:
	## "The path beneath": bridge, walk out, lower, and the ground returns.
	await load_level("08_reveal")
	await press_mirror_button()
	await slide(0, 2.0)
	check(await walk_to(Vector3(5, 0, 0)), "Direct reveal: the copy reaches x 5")
	check(not reaches_goal(), "Direct reveal: the goal is cut off while the mirror stands")
	await press_mirror_button()
	await direct_fall()
	check(not bool(game.mirror.get("enabled", true)) and pivot_is(Vector3(2.5, 0, 0)), "Direct reveal: lowering keeps the mirror's place")
	check(game.phase == "play" and reaches_goal(), "Direct reveal: lowering the mirror returns the ground to the goal")
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and pivot_is(Vector3(2.5, 0, 0)), "Direct reveal: raising again puts the mirror back where it stood")
	await press_mirror_button()
	await direct_fall()
	check(game.phase == "play" and await walk_to(goal_point()), "Direct reveal: the returned ground leads to the goal")
	await load_level("08_reveal")
	await press_mirror_button()
	await slide(0, 2.0)
	check(await walk_to(Vector3(4, 0, 0)), "Direct reveal: the traveller stands on the copy")
	await press_mirror_button()
	await direct_fall()
	check(game.phase == "failure", "Direct reveal: lowering the mirror under the traveller is a fall")


func direct_aperture_case(lower_units: float) -> bool:
	await load_level("11_aperture")
	await press_mirror_button()
	await slide(0, 1.5)
	if lower_units > 0.0:
		await slide(1, -lower_units)
	await direct_fall()
	return reaches_goal()


func check_direct_aperture() -> void:
	## "Only the ground": the same frame the classic path uses catches the
	## tower's foot; dragging the mirror down one unit leaves it out.
	check(not await direct_aperture_case(0.0), "Direct aperture: the full frame copies the tower's foot into the way")
	check(pivot_is(Vector3(2, 0, 0)), "Direct aperture: the drag along X stops at the ledge's end")
	check(await direct_aperture_case(1.0), "Direct aperture: one unit lower, the mirror copies only the ground")
	check(pivot_is(Vector3(2, -1, 0)), "Direct aperture: a drag straight down lowers the mirror")
	check(not await direct_aperture_case(2.0), "Direct aperture: two units lower, the copy is too low to reach")


func check_direct_turn() -> void:
	## "Another way round": point the arrow at the ring, then slide half a unit.
	await load_level("14_turn")
	await press_mirror_button()
	await point(Vector3.BACK)
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.BACK), "Direct turn: the arrow points the mirror toward the ring")
	check(not reaches_goal(), "Direct turn: turned in place, the copy leaves a gap")
	await slide(2, 0.5)
	check(reaches_goal(), "Direct turn: turned and slid half a unit, the copy is a bridge to the ring")
	await load_level("14_turn")
	await press_mirror_button()
	await point(Vector3.FORWARD)
	await direct_fall()
	check(not reaches_goal(), "Direct turn: pointing away from the ring does not reach it")
	await load_level("14_turn")
	await press_mirror_button()
	await point(Vector3.BACK)
	await slide(2, 1.0)
	await direct_fall()
	check(not reaches_goal(), "Direct turn: a step too far leaves a gap")


func direct_together_bridge(lower_units: float) -> void:
	await load_level("15_together")
	await press_mirror_button()
	await point(Vector3.BACK)
	await slide(2, 0.5)
	if lower_units > 0.0:
		await slide(1, -lower_units)


func check_direct_together() -> void:
	## "Together": point, slide, lower past the floating block, walk out, then
	## lower the mirror and fall onto the low path.
	var above_low := Vector3(0, 0, 4)
	await direct_together_bridge(0.0)
	check(not await walk_to(above_low), "Direct together: the full frame copies the floating block into the way")
	await direct_together_bridge(1.0)
	check(await walk_to(Vector3(0, 0, 1.5)), "Direct together: one unit lower, the bridge carries the traveller out")
	await press_mirror_button()
	await direct_fall()
	check(game.phase == "failure", "Direct together: lowering the mirror above empty space is a fatal fall")
	await direct_together_bridge(1.0)
	check(await walk_to(above_low), "Direct together: the traveller stands above the low path")
	await press_mirror_button()
	await direct_fall()
	check(game.phase == "play" and game.walker.position.y < -2.5, "Direct together: lowering the mirror above the low path is a safe fall")
	check(await walk_to(goal_point()), "Direct together: the low path leads to the goal")


func run() -> void:
	# create_at() projects a screen point through the camera, so the viewport
	# needs a real size.
	root.size = Vector2i(1152, 800)
	# `-- --direct-only` checks only the direct controls' path.
	if not "--direct-only" in OS.get_cmdline_user_args():
		game = Game.new()
		root.add_child(game)
		await frames(2)
		await check_first_steps()
		await check_route()
		await check_reveal()
		await check_aperture()
		await check_turn()
		await check_together()
		game.queue_free()
		await frames(1)
	await run_direct()
	print("Level solvability: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_first_steps() -> void:
	## "First steps": the way is connected, but the goal is out of sight until
	## the view turns.
	await load_level("13_first_steps")
	check(reaches_goal(), "First steps: the walk to the goal is connected")
	check(not goal_visible(), "First steps: the goal is hidden in the first view")
	var revealed := false
	for direction: int in [1, -1]:
		await load_level("13_first_steps")
		game.turn_camera(direction)
		await camera_idle()
		revealed = revealed or goal_visible()
	check(revealed, "First steps: one quarter turn of the view shows the goal")
	await load_level("13_first_steps")
	check(await walk_to(goal_point()), "First steps: the traveller walks to the goal")


func check_route() -> void:
	## "A place to stand": the real create path at 2.5, then a move to 4.0.
	await load_level("01_route")
	await create_at(2.5, 0.0)
	check(await confirm() == "supported", "Route: a mirror at 2.5 is supported")
	check(await walk_to(Vector3(5, 0, 0)), "Route: the traveller reaches the rest platform")
	game.begin_preview()
	await idle()
	game.change_preview("offset", 4.0)
	await camera_idle()
	await confirm()
	check(await walk_to(goal_point()), "Route: a mirror at 4.0 opens the way to the goal")


func check_reveal() -> void:
	## "The path beneath": bridge, walk out, remove, and the ground returns.
	await load_level("08_reveal")
	await create_at(2.5, 0.0)
	await confirm()
	check(await walk_to(Vector3(5, 0, 0)), "Reveal: the bridge reaches x 5")
	check(not reaches_goal(), "Reveal: the goal is cut off while the mirror stands")
	await remove()
	await settle_fall()
	check(game.phase == "play" and await walk_to(goal_point()), "Reveal: removing the mirror returns the ground to the goal")


func aperture_case(height: float) -> bool:
	await load_level("11_aperture")
	await create_at(2.0, 0.0)
	if not is_equal_approx(height, 3.0):
		await set_size("height", height)
	await confirm()
	await settle_fall()
	return reaches_goal()


func check_aperture() -> void:
	## "Only the ground": the real create path puts the panel at y -1.5..1.5,
	## which copies the floating tower into the bridge. Pulling the top edge
	## down to 2 high (y -1.5..0.5) copies only the ledge.
	await load_level("11_aperture")
	check(not reaches_goal(), "Aperture: without a mirror the goal is out of reach")
	check(not await aperture_case(3.0), "Aperture: a full-height mirror brings the tower across and blocks the way")
	check(await aperture_case(2.0), "Aperture: a two-high mirror brings only the ground across")
	check(not await aperture_case(1.0), "Aperture: a one-high mirror makes a bridge too low to reach")


func check_turn() -> void:
	## "Another way round": only a left quarter turn copies the spur forward.
	await load_level("14_turn")
	check(not reaches_goal(), "Turn: without a mirror the goal is out of reach")
	for x: float in [0.5, 1.0, 1.5, 2.0]:
		await load_level("14_turn")
		await create_at(x, 0.0)
		await confirm()
		await settle_fall()
		check(not reaches_goal(), "Turn: an unturned mirror at x %.1f copies along X only" % x)
	await load_level("14_turn")
	await create_at(0.0, 0.5)
	await turn(-1)
	check(await confirm() == "supported", "Turn: a left turn at z 0.5 is supported")
	check(reaches_goal(), "Turn: a left turn copies the spur into a bridge")
	await load_level("14_turn")
	await create_at(0.0, 0.5)
	await turn(1)
	check(await confirm() == "failure", "Turn: a right turn copies the empty side and removes the ground")
	for degrees: float in [-15.0, -30.0, -45.0]:
		await load_level("14_turn")
		await create_at(0.0, 0.5)
		await turn_to(degrees)
		await confirm()
		await settle_fall()
		check(not reaches_goal(), "Turn: a %d degree turn does not reach the goal" % int(degrees))


func together_bridge(height: float) -> void:
	await load_level("15_together")
	await create_at(0.0, 0.5)
	await turn(-1)
	if not is_equal_approx(height, 3.0):
		await set_size("height", height)
	await confirm()


func check_together() -> void:
	## "Together": turn, resize past the floating block, walk out above the
	## low path, then remove the mirror and fall onto it.
	var above_low := Vector3(0, 0, 4)
	await load_level("15_together")
	check(not reaches_goal(), "Together: without a mirror the goal is out of reach")
	await load_level("15_together")
	await create_at(1.5, 0.0)
	await confirm()
	check(not await walk_to(above_low), "Together: an unturned mirror makes no bridge")
	await together_bridge(3.0)
	check(not await walk_to(above_low), "Together: a full-height mirror copies the floating block into the way")
	await together_bridge(2.0)
	check(await walk_to(Vector3(0, 0, 1.5)), "Together: the resized bridge carries the traveller out")
	check(await remove() == "failure", "Together: a removal above empty space is a fatal fall")
	await together_bridge(2.0)
	check(await walk_to(above_low), "Together: the traveller stands above the low path")
	check(await remove() == "landing", "Together: a removal above the low path is a safe fall")
	await settle_fall()
	check(game.phase == "play" and game.walker.position.y < -2.5, "Together: the traveller lands on the low path")
	check(await walk_to(goal_point()), "Together: the low path leads to the goal")
