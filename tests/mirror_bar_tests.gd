extends SceneTree
## The mirror bar below the stage: the mirror button opens it into three
## knobs (move, turn, lift) and a remove button. Every check pushes real
## mouse events through the game's own input path, once for each window size.
##
## Run: godot --headless --path . --script tests/mirror_bar_tests.gd

const Game := preload("res://game.gd")
const SIZES: Array[Vector2i] = [Vector2i(884, 1472), Vector2i(1280, 720)]

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
	for index: int in 600:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy:
			return
		await process_frame


## Waits until the bar is open (1.0) or closed (0.0). It moves by real time.
func bar_at(open: float) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not is_equal_approx(game.bar._open, open) and Time.get_ticks_msec() < deadline:
		await process_frame


func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)


func move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


## A finger presses at `from`, moves to `to` in steps, rests, and lifts. With
## `wait` false the call returns at once after the release.
func drag(from: Vector2, to: Vector2, wait := true) -> void:
	button(from, true)
	await process_frame
	for step: int in range(1, 17):
		move(from.lerp(to, step / 16.0))
		await process_frame
	await frames(12)
	button(to, false)
	if wait:
		await settled()
		await frames(20)


func degrees(key: String) -> float:
	return rad_to_deg(float(game.mirror.get(key, 0.0)))


func knob(index: int) -> Vector2:
	return game.bar.centre + Vector2((index - 1) * game.bar.SPACING, 0.0)


## The finger travel that moves the mirror by `world`.
func travel(world: Vector3) -> Vector2:
	var pivot: Vector3 = game.mirror["pivot"]
	var origin: Vector2 = game.camera.unproject_position(pivot)
	var unit: Vector2 = game.camera.unproject_position(pivot + Vector3.RIGHT) - origin
	var gain: float = unit.length() / game._screen_axes(pivot)[0].length()
	if absf(world.y) > 0.0:
		unit = game.camera.unproject_position(pivot + Vector3.UP) - origin
		gain = unit.length() / game._screen_axes(pivot)[1].length()
	return (game.camera.unproject_position(pivot + world) - origin) / (gain * game.KNOB_GAIN)


func run() -> void:
	for size: Vector2i in SIZES:
		root.size = size
		await frames(3)
		check(root.size == size, "%s: the window has this size" % size)
		await check_bar(size)
	print("Mirror bar: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_bar(size: Vector2i) -> void:
	var label := str(size)
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	await frames(3)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/14_turn.json"))
	await settled()
	await frames(240)
	check(not game.mirror.get("enabled", false) and is_zero_approx(game.bar._open), "%s: the bar starts as the mirror button" % label)

	# The bar is below the stage and inside the play area, and it does not
	# follow the view.
	var centre: Vector2 = game.bar.centre
	var lowest := -INF
	for point: Vector3 in game.camera.points:
		lowest = maxf(lowest, game.camera.unproject_position(point).y)
	var half: float = game.bar.HALF_HEIGHT
	check(centre.is_equal_approx(game.hud.get_bar_centre()) and centre.y - half >= lowest - 0.5, "%s: the bar is in its row, below the stage" % label)
	check(centre.y + half <= game.play_rect.end.y, "%s: the bar is inside the play area" % label)
	if size.y > size.x:
		check(game.play_rect.end.y - centre.y - half >= size.y * 0.12, "%s: a slide from a knob has room below the bar" % label)
	check(game.bar._remove_point().x + game.bar.REMOVE <= game.play_rect.end.x, "%s: the remove button is inside the play area" % label)

	# The mirror button opens into the bar.
	button(centre, true)
	await frames(2)
	button(centre, false)
	await settled()
	await bar_at(1.0)
	await frames(2)
	check(bool(game.mirror.get("enabled", false)), "%s: the mirror button raises the mirror" % label)
	check(is_equal_approx(game.bar._open, 1.0), "%s: the bar is open" % label)

	# A press on the glass does not take the mirror.
	var pivot: Vector3 = game.mirror["pivot"]
	button(game.camera.unproject_position(pivot), true)
	await frames(2)
	check(not game.dragging, "%s: a press on the glass does not move the mirror" % label)
	button(game.camera.unproject_position(pivot), false)
	await settled()
	await frames(30)
	game.walker.route.clear()

	# The move knob: one drag that changes both ground axes.
	pivot = game.mirror["pivot"]
	var from := knob(0)
	await drag(from, from + travel(Vector3(1.0, 0.0, 0.5)))
	var moved: Vector3 = game.mirror["pivot"] - pivot
	check(is_equal_approx(moved.x, 1.0) and is_equal_approx(moved.z, 0.5) and is_zero_approx(moved.y), "%s: the move knob moves x by 1 and z by 0.5, height stays" % label)

	# The lift knob.
	pivot = game.mirror["pivot"]
	from = knob(2)
	await drag(from, from + travel(Vector3.UP))
	moved = game.mirror["pivot"] - pivot
	check(is_equal_approx(moved.y, 1.0) and is_zero_approx(moved.x) and is_zero_approx(moved.z), "%s: the lift knob lifts by 1 and nothing else" % label)

	# One hold that turns and tilts.
	var turns := [0]
	game.tutorial_event.connect(func(event: String) -> void:
		if event == "turn": turns[0] += 1)
	var yaw := degrees("yaw")
	var pitch := degrees("pitch")
	from = knob(1)
	await drag(from, from + Vector2(96.0, -96.0))
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 45.0) and absf(absf(degrees("pitch") - pitch) - 45.0) < 0.01, "%s: one diagonal slide turns and tilts" % label)
	game.undo()
	await settled()
	await frames(20)

	# The turn knob: a slide to the right turns counterclockwise.
	await drag(from, from + Vector2(96.0, 24.0))
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 45.0), "%s: a slide to the right turns by +45 degrees" % label)
	check(is_equal_approx(degrees("pitch"), pitch), "%s: a small vertical drift does not tilt" % label)

	# A vertical slide tilts.
	await drag(from, from + Vector2(0.0, -96.0))
	check(absf(absf(degrees("pitch") - pitch) - 45.0) < 0.01, "%s: a slide up tilts by 45 degrees" % label)
	game.undo()
	await settled()
	await frames(20)

	# A second drag at once after a release is not lost.
	turns[0] = 0
	await drag(from, from + Vector2(-96.0, 0.0), false)
	await frames(2)
	var waited := 2
	button(from, true)
	while not game.bar._started and waited < 600:
		waited += 1
		await process_frame
	button(from, false)
	await settled()
	await frames(20)
	await drag(from, from + Vector2(96.0, 0.0), false)
	await frames(2)
	await drag(from, from + Vector2(96.0, 0.0))
	await settled()
	await frames(40)
	await settled()
	check(turns[0] == 3 and is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 90.0), "%s: fast drags (left, right, right) are three turns" % label)

	# The Undo button is to the left of the bar. A press takes one change back.
	var undo: Vector2 = game.bar._undo_point()
	check(game.bar.can_undo and undo.x + game.bar.REMOVE < game.bar.centre.x - game.bar._half_width(1.0) and undo.x - game.bar.REMOVE >= game.play_rect.position.x,
		"%s: the Undo button is to the left of the bar and inside the play area" % label)
	var changes: int = game.history.size()
	button(undo, true)
	await frames(2)
	button(undo, false)
	await settled()
	check(game.history.size() == changes - 1 and not game.dragging, "%s: a press on the Undo button takes one change back" % label)
	# Undo takes each change back.
	for index: int in 4:
		game.undo()
		await settled()
	await frames(20)
	check(is_equal_approx(degrees("yaw"), yaw) and is_equal_approx(degrees("pitch"), pitch), "%s: Undo takes the turns back" % label)

	# The remove button lowers the mirror, and the bar closes.
	var remove: Vector2 = game.bar._remove_point()
	button(remove, true)
	await frames(2)
	button(remove, false)
	await settled()
	await bar_at(0.0)
	check(not bool(game.mirror.get("enabled", false)), "%s: the remove button lowers the mirror" % label)
	check(is_zero_approx(game.bar._open), "%s: the bar is the mirror button again" % label)
	game.queue_free()
	await frames(2)
