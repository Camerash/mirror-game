extends SceneTree
## The direct mirror controls: the mirror button, a drag on the mirror along
## one grid axis, the arrow, apply on release with Undo, and no editor.
## Pointer checks push real mouse events through the game's own input path.
##
## Run: godot --headless --path . --script tests/direct_controls_tests.gd

const Game := preload("res://game.gd")
const Targets := preload("res://core/mirror_targets.gd")
const MirrorRules := preload("res://core/mirror_state.gd")
const Queries := preload("res://core/solid_queries.gd")
const AXES: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

var game: Node3D
var checks := 0
var failures := 0
var events: Array[String] = []


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


func direct_settled() -> void:
	for index: int in 600:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy:
			return
		await process_frame


func load_stage(file: String) -> void:
	game.load_level(Game.LEVEL_PATHS.find("res://levels/%s.json" % file))
	await direct_settled()
	await frames(2)


func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)


func mouse_move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


## A finger presses at `from`, moves to `to` in steps, and lifts.
func drag(from: Vector2, to: Vector2, steps := 12) -> void:
	mouse_button(from, true)
	await process_frame
	for step: int in range(1, steps + 1):
		mouse_move(from.lerp(to, float(step) / steps))
		await process_frame
	await frames(6)
	mouse_button(to, false)
	await direct_settled()


func tap(point: Vector2) -> void:
	mouse_button(point, true)
	await process_frame
	mouse_button(point, false)
	await frames(2)


func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await direct_settled()


func press_mirror_button() -> void:
	game.hud._mirror_button.pressed.emit()
	await direct_settled()


## The command path a drag on the mirror takes, without hunting for glass.
func slide(axis: int, units: float) -> void:
	var start: Vector2 = game.camera.unproject_position(pivot())
	var finish: Vector2 = game.camera.unproject_position(pivot() + AXES[axis] * units)
	game.begin_slide(start)
	for step: int in range(1, 13):
		game.slide_to(start.lerp(finish, step / 12.0))
		await process_frame
	await frames(8)
	game.end_slide()
	await direct_settled()


func pivot() -> Vector3:
	return game.mirror["pivot"]


## A point on the mirror's glass, clear of the arrow's knob.
func glass_point() -> Vector2:
	var rect: Rect2 = game.hud.get_play_rect()
	var centre: Vector2 = game.camera.unproject_position(pivot())
	var best := Vector2(-1, -1)
	for y: int in range(int(rect.position.y + 10), int(rect.end.y - 10), 6):
		for x: int in range(int(rect.position.x + 10), int(rect.end.x - 10), 6):
			var point := Vector2(x, y)
			if game.sheet_hit(point) and (best.x < 0 or point.distance_to(centre) < best.distance_to(centre)):
				best = point
	check(best.x >= 0, "The raised mirror has a touchable point on its glass")
	return best


## A point on the glass with a walkable top behind it, as a walk tap would hit.
func glass_point_over_ground() -> Vector2:
	var rect: Rect2 = game.hud.get_play_rect()
	for y: int in range(int(rect.position.y + 10), int(rect.end.y - 10), 4):
		for x: int in range(int(rect.position.x + 10), int(rect.end.x - 10), 4):
			var point := Vector2(x, y)
			if not game.sheet_hit(point):
				continue
			var origin: Vector3 = game.camera.project_ray_origin(point)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + game.camera.project_ray_normal(point) * 100, 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and (hit["normal"] as Vector3).y >= Queries.FLOOR_Y and not game.navigation.route(game.walker.position, hit["position"]).is_empty() \
					and (hit["position"] as Vector3).distance_to(game.walker.position) > 0.6:
				return point
	check(false, "The glass covers a walkable top somewhere")
	return Vector2.ZERO


func run() -> void:
	root.size = Vector2i(1152, 800)
	check_faced()
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	game.tutorial_event.connect(func(name: String) -> void: events.append(name))
	await frames(3)
	await check_axes_in_every_view()
	await check_no_editor()
	await check_mirror_button()
	await check_slide_one_axis()
	await check_slide_up_lifts()
	await check_tap_through_glass()
	await check_arrow()
	await check_blocked_goes_back()
	await check_hover_ghost()
	await check_camera_stays()
	await check_keyboard()
	await check_classic_toggle()
	game.queue_free()
	await frames(1)
	print("Direct controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_faced() -> void:
	var state := MirrorRules.normalized({"enabled": true, "axis": 0, "source": 1, "offset": 2.5,
		"pivot": Vector3(2.5, 0, 0), "width": 3.0, "height": 3.0})
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		var faced := MirrorRules.faced(state, direction)
		check(MirrorRules.normal(faced).is_equal_approx(direction), "Faced: the copy side turns to %s" % direction)
		check((faced["pivot"] as Vector3).is_equal_approx(state["pivot"]), "Faced: turning keeps the pivot")
		check(int(faced["source_sign"]) == int(state["source_sign"]), "Faced: turning keeps the selected side")
	check(MirrorRules.same(state, state.duplicate(true)), "Same: a state equals its copy")
	check(not MirrorRules.same(state, MirrorRules.faced(state, Vector3.LEFT)), "Same: a half turn is a different mirror")
	var lowered := state.duplicate(true)
	lowered["enabled"] = false
	check(not MirrorRules.same(state, lowered), "Same: a lowered mirror differs from the raised one")


func check_axes_in_every_view() -> void:
	await load_stage("01_route")
	var point := Vector3(2.5, 0, 0)
	for view: int in 4:
		var axes: Array[Vector2] = game._screen_axes(point)
		var directions: Array[Vector2] = []
		for axis: int in 3:
			directions.append(axes[axis].normalized())
			directions.append(-axes[axis].normalized())
			for sign: float in [1.0, -1.0]:
				check(Targets.pick_axis(axes[axis] * sign * 30.0, axes) == axis, "View %d: a drag along axis %d's screen direction picks it" % [view, axis])
				var off := axes[axis].normalized().rotated(deg_to_rad(20.0)) * sign * 30.0
				check(Targets.pick_axis(off, axes) == axis, "View %d: a drag 20 degrees off axis %d still picks it" % [view, axis])
		check(Targets.pick_axis(Vector2(0, -40), axes) == 1, "View %d: a drag straight up the screen lifts" % view)
		var closest := 180.0
		for a: int in directions.size():
			for b: int in range(a + 1, directions.size()):
				closest = minf(closest, absf(rad_to_deg(directions[a].angle_to(directions[b]))))
		check(closest > 50.0, "View %d: the six grid directions are at least 50 degrees apart on screen (%.1f)" % [view, closest])
		var lengths: Array[float] = [axes[0].length(), axes[1].length(), axes[2].length()]
		check(lengths.max() / lengths.min() < 1.2, "View %d: a step costs about the same finger travel on every axis" % view)
		game.turn_camera(1)
		for index: int in 600:
			if not game.camera.busy:
				break
			await process_frame


func check_no_editor() -> void:
	await load_stage("01_route")
	var hud = game.hud
	check(hud._mirror_button.visible and not hud._mirror_button.disabled, "No editor: the mirror button shows and is ready")
	check(not hud._mode_cycle.visible and not hud._cancel.visible and not hud._apply.visible and not hud._flip.visible and not hud._enabled.visible,
		"No editor: no mode button and no edit row")
	var empty := Vector2(-1, -1)
	var rect: Rect2 = hud.get_play_rect().grow(-30)
	for y: int in range(int(rect.position.y), int(rect.end.y), 24):
		for x: int in range(int(rect.position.x), int(rect.end.x), 24):
			if empty.x < 0 and not game._solid_hit(Vector2(x, y)) and not hud.blocks_world_input(Vector2(x, y)):
				empty = Vector2(x, y)
	mouse_button(empty, true)
	game.gesture.advance(0.6)
	await frames(2)
	mouse_button(empty, false)
	await frames(4)
	check(game.phase == "play" and not bool(game.mirror.get("enabled", false)), "No editor: holding empty space makes no mirror")


func check_mirror_button() -> void:
	await load_stage("01_route")
	events.clear()
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and pivot().is_equal_approx(Vector3(0.5, 0, 0)), "Button: the first raise stands the mirror just in front of the traveller")
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.RIGHT), "Button: it faces the stage's starting direction")
	check(game.phase == "play" and game.history.size() == 1, "Button: the raise applies at once, as one Undo step")
	check("create" in events, "Button: raising reports create")
	await press_mirror_button()
	check(not bool(game.mirror.get("enabled", true)) and pivot().is_equal_approx(Vector3(0.5, 0, 0)), "Button: lowering keeps the mirror's place")
	check(game.sheet.lowered and game.sheet.visible, "Button: a lowered mirror shows a faint outline where it stood")
	check("remove" in events, "Button: lowering reports remove")
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and pivot().is_equal_approx(Vector3(0.5, 0, 0)), "Button: raising again puts it back")


func check_slide_one_axis() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	var start := glass_point()
	var axes: Array[Vector2] = game._screen_axes(pivot())
	var before := pivot()
	var history: int = game.history.size()
	events.clear()
	mouse_button(start, true)
	await process_frame
	for step: int in range(1, 13):
		mouse_move(start.lerp(start + axes[0] * 2.0, step / 12.0))
		await process_frame
	await frames(8)
	check(game.dragging and game.phase == "preview" and game.slide_axis == 0, "Slide: a drag on the glass along X slides the mirror along X")
	check(not game.hud._cancel.visible and not game.hud._apply.visible and not game.hud._mode_cycle.visible and not game.hud._edit_border.visible,
		"Slide: no edit buttons appear while dragging")
	check(game.rings.get_control_rects().is_empty() and game.resize_controls.get_control_rects().is_empty(), "Slide: no rings or resize handles appear")
	check(game.guide_kind == "rail_0", "Slide: the guide shows the one line the mirror moves along")
	mouse_button(start + axes[0] * 2.0, false)
	await direct_settled()
	check(pivot().is_equal_approx(before + Vector3(2, 0, 0)), "Slide: the release applies the mirror two units along X, and nothing else")
	check(game.phase == "play" and game.history.size() == history + 1, "Slide: one release is one Undo step")
	check("move" in events, "Slide: a slide reports move")
	game.undo()
	await direct_settled()
	check(pivot().is_equal_approx(before), "Slide: Undo puts the mirror back")


func check_slide_up_lifts() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	var start := glass_point()
	var axes: Array[Vector2] = game._screen_axes(pivot())
	var before := pivot()
	events.clear()
	await drag(start, start + Vector2(0, -axes[1].length() * 1.0))
	check(pivot().is_equal_approx(before + Vector3(0, 1, 0)), "Lift: a drag straight up the screen raises the mirror one unit, and nothing else")
	var risen := pivot()
	var again := glass_point()
	await drag(again, again + Vector2(0, axes[1].length() * 1.0))
	check(pivot().is_equal_approx(risen - Vector3(0, 1, 0)), "Lift: a drag straight down lowers it again")
	check("lower" in events, "Lift: lowering the mirror reports lower")


func check_tap_through_glass() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	await slide(0, 2.0)
	var before: Dictionary = game.mirror.duplicate(true)
	var point := glass_point_over_ground()
	await tap(point)
	await frames(4)
	check(MirrorRules.same(game.mirror, before), "Tap: a tap on the glass leaves the mirror as it is")
	check(not game.walker.route.is_empty() or game.walker.velocity.length() > 0.01, "Tap: a tap on the glass walks to the ground behind it")


func check_arrow() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	await frames(2)
	var knob: Vector2 = game.arrow.knob_point()
	check(game.arrow.blocks_point(knob), "Arrow: the knob is shown and touchable")
	var centre: Vector2 = game.camera.unproject_position(pivot())
	var toward: Vector2 = game.camera.unproject_position(pivot() + Vector3.BACK) - centre
	var before := pivot()
	events.clear()
	mouse_button(knob, true)
	await process_frame
	check(game.pointing and game.arrow.is_active(), "Arrow: pressing the knob holds the arrow")
	var target := centre + toward.normalized() * 90.0
	for step: int in range(1, 11):
		mouse_move(knob.lerp(target, step / 10.0))
		await process_frame
	await frames(8)
	mouse_button(target, false)
	await direct_settled()
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.BACK), "Arrow: pointing it toward +Z turns the mirror to copy toward +Z")
	check(pivot().is_equal_approx(before), "Arrow: turning keeps the mirror's centre")
	check("turn" in events, "Arrow: a turn reports turn")
	game.begin_point()
	game.point_toward(Vector3.FORWARD)
	await frames(8)
	game.end_point()
	await direct_settled()
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.FORWARD), "Arrow: pointing the opposite way is the half turn")
	game.begin_point()
	game.point_toward(Vector3.UP)
	await frames(8)
	game.end_point()
	await direct_settled()
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.FORWARD), "Arrow: the tutorial keeps the mirror upright")


func check_blocked_goes_back() -> void:
	## Standing beside the wall in "First steps", turning the mirror to copy
	## the wall onto the traveller is blocked, so the mirror stays as it was.
	await load_stage("13_first_steps")
	var walked: bool = game.request_walk(Vector3(4, 0, -1))
	for index: int in 900:
		if game.walker.route.is_empty():
			break
		await process_frame
	await frames(3)
	check(walked and game.walker.position.distance_to(Vector3(4, 0, -1)) < 0.25, "Blocked: the traveller stands beside the wall")
	await press_mirror_button()
	var before: Dictionary = game.mirror.duplicate(true)
	game.begin_point()
	game.point_toward(Vector3.LEFT)
	await frames(8)
	game.end_point()
	await direct_settled()
	check(MirrorRules.same(game.mirror, before) and game.phase == "play", "Blocked: a turn that would put the wall on the traveller goes back")


func check_hover_ghost() -> void:
	## A drag that would pull the ground from under the traveller shows the
	## fall ghost while the finger rests, before anything applies.
	await load_stage("01_route")
	await press_mirror_button()
	await slide(0, 2.0)
	var walked: bool = game.request_walk(Vector3(4, 0, 0))
	for index: int in 900:
		if game.walker.route.is_empty():
			break
		await process_frame
	await frames(3)
	check(walked, "Hover: the traveller walks out onto the copy")
	var start: Vector2 = game.camera.unproject_position(pivot())
	var finish: Vector2 = game.camera.unproject_position(pivot() + Vector3.RIGHT * 1.5)
	game.begin_slide(start)
	for step: int in range(1, 13):
		game.slide_to(start.lerp(finish, step / 12.0))
		await process_frame
	for index: int in 240:
		if game.preview_view.result_status != "":
			break
		await process_frame
	check(game.dragging and game.preview_view.result_status == "failure" and game.preview_view.ghost.visible, "Hover: mid-drag, the ghost shows the fall before anything applies")
	check(game.walker.position.distance_to(Vector3(4, 0, 0)) < 0.25, "Hover: the traveller holds still while the finger is down")
	game.slide_to(start)
	await frames(30)
	game.end_slide()
	await direct_settled()
	check(pivot().is_equal_approx(Vector3(2.5, 0, 0)) and game.phase == "play" and game.walker.position.distance_to(Vector3(4, 0, 0)) < 0.25,
		"Hover: dragging back and letting go changes nothing")


func check_camera_stays() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	await frames(30)
	var position: Vector3 = game.camera.position
	var size: float = game.camera.size
	var start := glass_point()
	var axes: Array[Vector2] = game._screen_axes(pivot())
	await drag(start, start + axes[0] * 0.5)
	await frames(30)
	check(game.camera.position.is_equal_approx(position) and is_equal_approx(game.camera.size, size), "Camera: a small slide does not reframe the stage")


func check_keyboard() -> void:
	await load_stage("01_route")
	await press_key(KEY_M)
	check(bool(game.mirror.get("enabled", false)), "Keys: M raises the mirror")
	await press_key(KEY_M)
	check(not bool(game.mirror.get("enabled", true)), "Keys: M lowers it again")
	await press_key(KEY_2)
	check(game.edit_mode == "move" and game.phase == "play", "Keys: the classic mode keys do nothing")


func check_classic_toggle() -> void:
	await load_stage("01_route")
	game._action("classic_controls", true)
	await frames(2)
	check(not game.direct_controls and not game.gesture.direct and not game.hud._mirror_button.visible, "Toggle: the debug switch brings back the classic editor")
	game.begin_preview()
	await direct_settled()
	check(game.hud._mode_cycle.visible and game.hud._cancel.visible, "Toggle: the classic editor shows its mode button and edit row")
	game.cancel_preview()
	await frames(2)
	game._action("classic_controls", false)
	await frames(2)
	check(game.direct_controls and game.gesture.direct and game.hud._mirror_button.visible, "Toggle: switching back restores the direct controls")
