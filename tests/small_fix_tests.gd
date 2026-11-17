extends SceneTree
## The small playtest fixes (fix 8): camera buttons drawn as a turning block,
## a forgiving mirror grab with a hover cue, no mirror on the first stage, a
## Restart stage button in the release settings, and a larger stage on a
## phone screen.

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


func settled() -> void:
	for index: int in 900:
		if game.phase == "play" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy \
				and not game.sweep.active and not game.sheet.is_transitioning():
			return
		await process_frame


func load_stage(file: String) -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/%s.json" % file))
	await settled()
	await frames(4)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(2)
	await settled()


func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event)
	await frames(2)


func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)


func drag(start: Vector2, finish: Vector2) -> void:
	mouse_button(start, true)
	await frames(2)
	for step: int in range(1, 11):
		var event := InputEventMouseMotion.new()
		event.position = start.lerp(finish, step / 10.0)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event)
		await frames(1)
	mouse_button(finish, false)
	await frames(3)
	await settled()


## A screen point whose ray meets the raised mirror's panel behind a block.
func occluded_sheet_point() -> Variant:
	var selected: Dictionary = game.mirror
	var normal := MirrorRules.normal(selected)
	var rect: Rect2 = game.play_rect
	for y: int in 60:
		for x: int in 60:
			var point := rect.position + rect.size * Vector2((x + 0.5) / 60.0, (y + 0.5) / 60.0)
			if game.hud.blocks_world_input(point) or game.bar.blocks_point(point):
				continue
			var origin: Vector3 = game.camera.project_ray_origin(point)
			var direction: Vector3 = game.camera.project_ray_normal(point)
			var distance: float = (selected["pivot"] - origin).dot(normal) / direction.dot(normal)
			if distance > 0 and game.sheet.contains_visible_point(origin + direction * distance, selected) \
					and game._solid_hit(point, distance):
				return point
	return null


## The screen point a little past the panel's right edge, at its centre height.
func past_edge(units: float) -> Vector2:
	var selected: Dictionary = game.mirror
	var frame: Basis = MirrorRules.frame(selected)
	var width := float(selected.get("width", 3.0))
	return game.camera.unproject_position(selected["pivot"] + frame.x * (width * 0.5 + units))


func run() -> void:
	game = Game.new()
	game.direct_controls = true
	game.release_mode = true
	game.auto_advance = false
	root.add_child(game)
	root.size = Vector2i(1152, 800)
	await frames(4)

	# First steps leaves the mirror out: no button, and M does nothing.
	await load_stage("13_first_steps")
	check(not game.bar.shown, "First steps: the mirror button is hidden")
	await key(KEY_M)
	check(not game.mirror.get("enabled", false) and not game.can_toggle_mirror(), "First steps: M raises no mirror")
	await load_stage("01_route")
	check(game.bar.shown, "A place to stand: the mirror button shows")
	var bad := {"title": "t", "objective": "o", "originals": [], "absolutes": [], "start": [0, 0, 0], "goal": [1, 0, 0],
		"mirror": {"enabled": false, "axis": 0, "source": 1, "offset": 0, "pivot": [0, 0, 0]},
		"limits": {"axes": [0], "min": [-1, -1, -1], "max": [1, 1, 1]}, "kill_y": -5, "mirror_available": "no"}
	check(not preload("res://core/level_loader.gd").validate(bad).is_empty(), "Loader: mirror_available must be true or false")

	# The grab: through a block that passes through the frame, and a little
	# past the glass, with a hover cue.
	await load_stage("11_aperture")
	game.toggle_mirror()
	await settled()
	check(game.mirror.get("enabled", false), "Grab: the mirror is up in Only the ground")
	var hidden: Variant = occluded_sheet_point()
	check(hidden != null, "Grab: a block passes in front of the panel somewhere")
	if hidden != null:
		check(game.sheet_hit(hidden), "Grab: a press on the panel behind a block takes the mirror")
		var before: Vector3 = game.mirror["pivot"]
		var axes: Array[Vector2] = game._screen_axes(before)
		await drag(hidden, hidden + axes[0] * 2.0)
		check((game.mirror["pivot"] as Vector3).is_equal_approx(before), "Grab: a drag that starts on the panel does not slide the mirror")
	check(game.sheet_hit(past_edge(0.15)), "Grab: a press just past the glass takes the mirror")
	check(not game.sheet_hit(past_edge(0.6)), "Grab: a press well past the glass does not")
	var empty: Vector2 = game.play_rect.position + Vector2(30, game.play_rect.size.y * 0.5)
	await hover(empty)
	check(game._cursor == Input.CURSOR_ARROW and not game.sheet.hovered and not game.sheet.edges.visible,
		"Hover: away from the mirror, the cursor and outline go back")
	await hover(game.bar.centre)
	check(game._cursor == Input.CURSOR_POINTING_HAND, "Hover: over the bar, the cursor is a hand")
	await hover(empty)

	# Restart stage: in the release settings, back to the stage's start.
	await load_stage("01_route")
	var start: Vector3 = game.walker.position
	game.toggle_mirror()
	await settled()
	check(not game.history.is_empty(), "Restart: the raise is one step")
	game.hud._toggle_debug()
	check(game.hud._settings_panel.visible and game.hud._restart_button.is_visible_in_tree(), "Restart: the settings panel shows Restart stage")
	game.hud._restart_button.pressed.emit()
	await settled()
	# The panel leaves with the dismiss motion.
	await create_timer(Motion.duration("dismiss") + 0.05).timeout
	check(not game.hud._settings_panel.visible, "Restart: the panel closes")
	check(game.history.is_empty() and not game.mirror.get("enabled", false) and game.walker.position.is_equal_approx(start),
		"Restart: the stage is back at its start")

	# Phone framing: on every size, the stage area stays clear of the controls
	# and of the mirror bar.
	for size: Vector2i in [Vector2i(844, 390), Vector2i(390, 844), Vector2i(1152, 800)]:
		root.size = size
		await frames(3)
		await load_stage("01_route")
		var camera_rect: Rect2 = game.hud.get_camera_rect()
		for bounds: Rect2 in game.hud.get_touch_control_bounds().values():
			check(not camera_rect.intersects(bounds), "%s: the stage area %s clears the control at %s" % [size, camera_rect, bounds])
		check(camera_rect.end.y <= game.hud.get_bar_centre().y - game.bar.HALF_HEIGHT + 0.5, "%s: the stage area ends above the mirror bar" % size)
		var undo_before: Rect2 = camera_rect
		game.toggle_mirror()
		await settled()
		check(game.hud.get_camera_rect().is_equal_approx(undo_before), "%s: the first action, which shows Undo, does not move the stage area (%s, %s)" % [size, undo_before, game.hud.get_camera_rect()])
		for bounds: Rect2 in game.hud.get_touch_control_bounds().values():
			check(not camera_rect.intersects(bounds), "%s: with Undo shown, the stage area clears the control at %s" % [size, bounds])

	print("Small fix tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
