extends SceneTree
## The mirror bar below the stage: the mirror button opens it into two knobs
## (turn, lift) and a remove button. Every check pushes real mouse events
## through the game's own input path, once for each window size.
##
## Run: godot --headless --path . --script tests/mirror_bar_tests.gd

const Game := preload("res://game.gd")
const MirrorRules := preload("res://core/mirror_state.gd")
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


## Waits until a value from `read` equals `target` exactly, for up to 4 s.
func until_exact(read: Callable, target: float) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while read.call() != target and Time.get_ticks_msec() < deadline:
		await process_frame
	return read.call() == target


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
	return game.bar.centre + Vector2(game.bar._knob_x(index, 1.0), 0.0)


## A finger presses at `from`, goes through each point in turn, rests, and
## lifts.
func path(from: Vector2, points: Array[Vector2]) -> void:
	button(from, true)
	await process_frame
	var last := from
	for target: Vector2 in points:
		for step: int in range(1, 9):
			move(last.lerp(target, step / 8.0))
			await process_frame
		last = target
	await frames(12)
	button(last, false)
	await settled()
	await frames(20)


## A quick push of a knob: out to `offset` and back to the press in a few
## frames, then a lift, with no wait.
func quick_push(point: Vector2, offset: Vector2) -> void:
	button(point, true)
	await process_frame
	for step: int in range(1, 4):
		move(point + offset * (step / 3.0))
		await process_frame
	for step: int in range(1, 4):
		move(point + offset * (1.0 - step / 3.0))
		await process_frame
	button(point, false)


## A press and a lift at once, with no travel.
func tap(point: Vector2) -> void:
	button(point, true)
	await process_frame
	button(point, false)


## The way the mirror faces, on the screen, from its pivot.
func facing_on_screen() -> Vector2:
	var pivot: Vector3 = game.mirror["pivot"]
	return game.camera.unproject_position(pivot + MirrorRules.normal(game.mirror)) - game.camera.unproject_position(pivot)


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
	# One unit is one point on a device, so each control takes a press at
	# least 44 points wide, Apple's least touch size.
	check(game.bar.KNOB * 2.0 >= 44.0 and (game.bar.REMOVE + 8.0) * 2.0 >= 44.0 and (game.bar.HALF_HEIGHT + 6.0) * 2.0 >= 44.0,
		"%s: each control takes a press at least 44 points wide" % label)

	# The mirror button opens into the bar.
	# A press grows the button smoothly: not full on the first frame.
	button(centre, true)
	await process_frame
	var first: float = game.bar._presses["mirror"]
	check(first < 1.0, "%s: a press does not give the full growth on the first frame" % label)
	check(await until_exact(func() -> float: return game.bar._presses["mirror"], 1.0), "%s: a held press comes to the full growth" % label)
	button(centre, false)
	# The spring passes 1 a little while the bar opens, then rests at 1.
	var peak := 0.0
	var deadline := Time.get_ticks_msec() + 4000
	while (game.bar._open != 1.0 or peak == 0.0) and Time.get_ticks_msec() < deadline:
		await process_frame
		peak = maxf(peak, game.bar._open)
	check(peak > 1.0 and peak <= 1.08, "%s: the opening passes 1 a little (peak %.4f)" % [label, peak])
	check(game.bar._open == 1.0, "%s: the opening rests at exactly 1" % label)
	check(await until_exact(func() -> float: return game.bar._presses["mirror"], 0.0), "%s: the press growth goes back after the release" % label)
	await settled()
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

	# A held knob fades the others and the glass, and they recover.
	button(knob(1), true)
	check(await until_exact(func() -> float: return game.bar._hold, 1.0), "%s: the hold amount comes to 1 while a knob is held" % label)
	button(knob(1), false)
	check(await until_exact(func() -> float: return game.bar._hold, 0.0), "%s: the hold amount goes back to 0 after the release" % label)
	await settled()
	await frames(20)
	game.walker.route.clear()

	# The bar has no move knob: a slide on the glass moves the mirror
	# (direct_controls_tests.gd checks it).
	check(game.bar.KNOBS == ["turn", "lift"] and game.bar._grip_at(knob(0)) == "turn" and game.bar._grip_at(knob(1)) == "lift",
		"%s: the bar has two knobs, turn to the left and lift to the right" % label)

	# The lift knob works as the turn knob (owner, 2026-11-25): out and back
	# to the press twice, up, is two steps of half a unit; a push to the side
	# gives none.
	pivot = game.mirror["pivot"]
	var from := knob(1)
	await path(from, [from + Vector2(0, -24), from, from + Vector2(0, -24), from])
	var moved: Vector3 = game.mirror["pivot"] - pivot
	check(is_equal_approx(moved.y, 1.0) and is_zero_approx(moved.x) and is_zero_approx(moved.z), "%s: two pushes up of the lift knob lift by 1 and nothing else" % label)
	await path(from, [from + Vector2(24, 0), from])
	check((game.mirror["pivot"] as Vector3).is_equal_approx(pivot + moved), "%s: a push to the side of the lift knob changes nothing" % label)

	# Quick pushes of the lift knob join the lift that still moves: one change.
	var lift_at: int = game.history.size()
	for count: int in 2:
		await quick_push(from, Vector2(0, 24))
		await frames(4)
	await settled()
	await frames(20)
	check((game.mirror["pivot"] as Vector3).is_equal_approx(pivot) and game.history.size() == lift_at + 1,
		"%s: two quick pushes down of the lift knob join into one change of -1" % label)
	# One Undo takes the joined lift back. The checks of the tilt below need
	# the mirror one unit up: lower, a pane that faces the sky cuts her ground.
	game.undo()
	await settled()
	await frames(20)
	check((game.mirror["pivot"] as Vector3).is_equal_approx(pivot + moved), "%s: one Undo takes back the joined lift" % label)

	# The turn knob nudges: each push of 16 points is one step of 45 degrees.
	# The pushes here come back before they hold long enough to add a step
	# (the held push is checked in direct_controls_tests.gd). One hold turns
	# and tilts: a push to the right, back 12, a push up, and back.
	var yaw := degrees("yaw")
	var pitch := degrees("pitch")
	var history_at: int = game.history.size()
	from = knob(0)
	await path(from, [from + Vector2(24, 0), from + Vector2(12, 0), from + Vector2(12, -20), from + Vector2(12, 0)])
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 45.0) and is_equal_approx(degrees("pitch") - pitch, -45.0),
		"%s: in one hold, a push to the right, back, and a push up turn and tilt" % label)
	game.undo()
	await settled()
	await frames(20)

	# A thumb that goes out and back to the press twice makes two steps: the
	# way back is never a push the other way (owner, 2026-11-24: "I cannot
	# trigger the second rotation").
	await path(from, [from + Vector2(24, 0), from, from + Vector2(24, 0), from])
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 90.0), "%s: out and back to the press twice in one hold is two steps" % label)
	game.undo()
	await settled()
	await frames(20)

	# A push to the right turns by +45 degrees, anticlockwise on the screen,
	# as the near edge of a turntable that the thumb pushes.
	var facing_before := facing_on_screen()
	await path(from, [from + Vector2(24, 7), from])
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 45.0), "%s: one push to the right turns by +45 degrees" % label)
	check(is_equal_approx(degrees("pitch"), pitch), "%s: a drift of 7 points down does not tilt" % label)
	check(facing_before.cross(facing_on_screen()) < 0.0, "%s: a push to the right turns the mirror anticlockwise on the screen" % label)

	# A push on a slant gives no step.
	await drag(from, from + Vector2(20, 20))
	check(is_equal_approx(wrapf(degrees("yaw") - yaw, -180.0, 180.0), 45.0) and is_equal_approx(degrees("pitch"), pitch),
		"%s: a push on a slant changes nothing" % label)

	# A push up tilts the mirror 45 degrees to the sky. The tilt goes all the
	# way round (owner, 2026-11-25): past the sky, a push tilts on, and the
	# mirror then faces back.
	await path(from, [from + Vector2(0, -24), from])
	check(is_equal_approx(degrees("pitch") - pitch, -45.0) and MirrorRules.normal(game.mirror).y > 0.5, "%s: a push up tilts the mirror to face the sky" % label)
	var facing := MirrorRules.normal(game.mirror)
	await path(from, [from + Vector2(0, -24), from])
	await path(from, [from + Vector2(0, -24), from])
	var behind := MirrorRules.normal(game.mirror)
	check(is_equal_approx(degrees("pitch") - pitch, -135.0) and behind.y > 0.5 and Vector2(behind.x, behind.z).dot(Vector2(facing.x, facing.z)) < 0.0,
		"%s: past the sky, a push tilts on, and the mirror faces back" % label)
	for change: int in 3:
		game.undo()
		await settled()
	await frames(20)

	# A tap changes nothing (owner, 2026-11-25: a tap shows no way), on
	# either knob, and Undo gets nothing. It still shows the knob's sign, which
	# stays a moment.
	for index: int in 2:
		var at := knob(index)
		var shown_before: Dictionary = game.mirror.duplicate(true)
		var taps_at: int = game.history.size()
		await tap(at)
		await frames(6)
		var sign_shown: bool = game.placement_guide._data.get("sign", false)
		await settled()
		await frames(20)
		check(MirrorRules.same(game.mirror, shown_before) and game.history.size() == taps_at and sign_shown,
			"%s: a tap on the %s knob changes nothing, and shows its sign" % [label, game.bar.KNOBS[index]])

	# Quick pushes join the turn that still moves (owner, 2026-11-24: "must be
	# smooth"): each push comes while the mirror still turns, so three pushes
	# are one change of -135 degrees, and one Undo takes all of it back.
	var quick_yaw := degrees("yaw")
	var quick_at: int = game.history.size()
	for count: int in 3:
		await quick_push(from, Vector2(-24, 0))
		await frames(4)
	await settled()
	await frames(20)
	check(is_equal_approx(wrapf(degrees("yaw") - quick_yaw, -180.0, 180.0), -135.0) and game.history.size() == quick_at + 1,
		"%s: three quick pushes join into one change of -135 degrees" % label)
	game.undo()
	await settled()
	await frames(20)
	check(is_equal_approx(wrapf(degrees("yaw") - quick_yaw, -180.0, 180.0), 0.0), "%s: one Undo takes back the joined turn" % label)

	# Fast changes are not lost: a push to the left, then three quick pushes
	# to the right, each while the mirror still turns or settles. Each lost
	# change would give a different end: -45 + 3 * 45 is +90 only with all four.
	var fast_yaw := degrees("yaw")
	await quick_push(from, Vector2(-24, 0))
	for push: int in 3:
		await quick_push(from, Vector2(24, 0))
	for wait: int in 8:
		await settled()
		await frames(20)
	check(is_equal_approx(wrapf(degrees("yaw") - fast_yaw, -180.0, 180.0), 90.0), "%s: fast changes (left, right, right, right) all count" % label)

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
	while game.history.size() > history_at:
		game.undo()
		await settled()
	await frames(20)
	check(is_equal_approx(degrees("yaw"), yaw) and is_equal_approx(degrees("pitch"), pitch), "%s: Undo takes the turns back" % label)

	# The Undo button rests at exactly 0 or 1.
	var undo_rest := await until_exact(func() -> float: return game.bar._undo_shown, 1.0 if game.bar.can_undo else 0.0)
	check(undo_rest, "%s: the Undo button amount rests at exactly 0 or 1" % label)

	# The remove button lowers the mirror, and the bar closes.
	var remove: Vector2 = game.bar._remove_point()
	button(remove, true)
	await frames(2)
	button(remove, false)
	await settled()
	await bar_at(0.0)
	check(not bool(game.mirror.get("enabled", false)), "%s: the remove button lowers the mirror" % label)
	check(is_zero_approx(game.bar._open), "%s: the bar is the mirror button again" % label)
	# `bar_at` can stop on the frame in which the spring goes through 0.
	check(await until_exact(func() -> float: return game.bar._open, 0.0), "%s: the closing rests at exactly 0" % label)
	game.queue_free()
	await frames(2)
