extends SceneTree
## Forgiving mirror steps (playtest fix 6): a half-unit step takes at least
## Game.MIN_HALF_STEP of drag at any window size, and the arrow and page keys
## nudge a raised mirror by half a unit, one Undo step each.

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


func settled() -> void:
	for index: int in 900:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy:
			return
		await process_frame


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(2)
	await settled()


func pivot() -> Vector3:
	return game.mirror["pivot"]


func run() -> void:
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	for size: Vector2i in [Vector2i(1152, 800), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = size
		await frames(2)
		check(game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json")), "Loads Route")
		await settled()
		await frames(10)
		game.toggle_mirror()
		await settled()
		var axes: Array[Vector2] = game._screen_axes(pivot())
		for axis: int in 3:
			check(axes[axis].length() * 0.5 >= Game.MIN_HALF_STEP - 0.01, "%s: a half step along axis %d takes at least %d px of drag (%.1f)" % [size, axis, Game.MIN_HALF_STEP, axes[axis].length() * 0.5])

	root.size = Vector2i(1152, 800)
	await frames(2)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await settled()
	await frames(10)
	var before: Vector3 = game.walker.position
	await key(KEY_RIGHT)
	check(game.mirror.get("enabled", false) == false and game.walker.position.is_equal_approx(before), "Keys: with no mirror up, an arrow key does nothing")
	game.toggle_mirror()
	await settled()
	var start := pivot()
	var history: int = game.history.size()
	await key(KEY_RIGHT)
	var moved := pivot() - start
	check(is_equal_approx(moved.length(), 0.5) and is_zero_approx(moved.y), "Keys: Right nudges the mirror half a unit along a ground axis (%s)" % moved)
	check(game.history.size() == history + 1, "Keys: a nudge is one Undo step")
	await key(KEY_LEFT)
	check(pivot().is_equal_approx(start), "Keys: Left nudges it back")
	await key(KEY_UP)
	var up := pivot() - start
	check(is_equal_approx(up.length(), 0.5) and is_zero_approx(up.y) and is_zero_approx(up.dot(moved)), "Keys: Up nudges along the other ground axis (%s)" % up)
	await key(KEY_DOWN)
	await key(KEY_PAGEUP)
	check(pivot().is_equal_approx(start + Vector3(0, 0.5, 0)), "Keys: Page Up lifts the mirror half a unit")
	await key(KEY_PAGEDOWN)
	check(pivot().is_equal_approx(start), "Keys: Page Down lowers it again")
	game.release_mode = true
	await key(KEY_PAGEUP)
	check(pivot().is_equal_approx(start + Vector3(0, 0.5, 0)), "Keys: Page Up still works in the release build")

	game.queue_free()
	await frames(2)
	print("Step tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
