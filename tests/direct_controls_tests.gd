extends SceneTree
## The direct mirror controls: a slide on the glass moves the mirror; the
## mirror bar (the mirror button, the turn and lift knobs, the remove button);
## apply on release with Undo, and no editor.
## Pointer checks push real mouse events through the game's own input path.
##
## Run: godot --headless --path . --script tests/direct_controls_tests.gd

const Game := preload("res://game.gd")
const Targets := preload("res://core/mirror_targets.gd")
const MirrorRules := preload("res://core/mirror_state.gd")
const Queries := preload("res://core/solid_queries.gd")

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


func fall_and_return() -> bool:
	## Waits for a fall off the world to go dark and to come back at the move
	## before. False when the stage never failed, or never came back.
	var failed := false
	for index: int in 1200:
		if game.phase == "failure":
			failed = true
		elif failed and game.phase == "play" and game.pending.is_empty() and game.settle_frames == 0 and is_zero_approx(game.dark_veil.color.a):
			return true
		await process_frame
	return false


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


## Waits until the bar is open (1.0) or closed (0.0). It moves by real time.
func bar_at(open: float) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not is_equal_approx(game.bar._open, open) and Time.get_ticks_msec() < deadline:
		await process_frame


## A real press and release on the mirror button, then the bar opens. A bar
## that is still open from the last stage first closes.
func press_mirror_button() -> void:
	await bar_at(0.0)
	await tap(game.bar.centre)
	await direct_settled()
	await bar_at(1.0)


## A real press and release on the remove button, then the bar closes.
func press_remove_button() -> void:
	await tap(game.bar._remove_point())
	await direct_settled()
	await bar_at(0.0)


func knob(index: int) -> Vector2:
	return game.bar.centre + Vector2(game.bar._knob_x(index, 1.0), 0.0)


## The finger travel that moves the mirror by `world`.
func travel(world: Vector3) -> Vector2:
	var origin: Vector2 = game.camera.unproject_position(pivot())
	var unit: Vector2 = game.camera.unproject_position(pivot() + Vector3.RIGHT) - origin
	var gain: float = unit.length() / game._screen_axes(pivot())[0].length()
	if absf(world.y) > 0.0:
		unit = game.camera.unproject_position(pivot() + Vector3.UP) - origin
		gain = unit.length() / game._screen_axes(pivot())[1].length()
	return (game.camera.unproject_position(pivot() + world) - origin) / (gain * game.KNOB_GAIN)


## The command path of a glass slide (x or z) or the lift knob (y): the slide
## goes on until the mirror goes `units` along `axis`.
func slide(axis: int, units: float) -> void:
	var world: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis] * units
	var start: Vector2 = game.bar.centre
	var finish: Vector2 = start + travel(world)
	var kind := "lift" if axis == 1 else "move"
	game.begin_grip(kind, start)
	for step: int in range(1, 13):
		game.grip_to(start.lerp(finish, step / 12.0))
		await process_frame
	await frames(8)
	game.end_grip(kind)
	await direct_settled()


## The command path of the turn knob: it asks for a grid direction.
func point(direction: Vector3) -> void:
	var faced: Dictionary = MirrorRules.faced(game.mirror, direction)
	game.begin_grip("turn", game.bar.centre)
	game.aim_to(faced["yaw"], faced["pitch"])
	await frames(8)
	game.end_grip("turn")
	await direct_settled()


func pivot() -> Vector3:
	return game.mirror["pivot"]


## A point on the mirror's glass.
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
	await check_lift_knob()
	await check_glass_slide()
	await check_tap_through_glass()
	await check_turn_knob()
	await check_freedom_sign()
	await check_heavy_turn()
	await check_held_turn()
	await check_release_stop()
	await check_joined_turn()
	await check_level_ring()
	await check_full_tilt()
	await check_sign_fades()
	await check_buried_comes_back()
	await check_first_raise_follows_her_look()
	await check_stay_and_fall()
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
	check(game.bar.shown and game.bar.can_toggle, "No editor: the mirror button shows and is ready")
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
	check(is_equal_approx(game.bar._open, 1.0), "Button: the bar opens into its knobs")
	await press_remove_button()
	check(not bool(game.mirror.get("enabled", true)) and pivot().is_equal_approx(Vector3(0.5, 0, 0)), "Button: the remove button lowers the mirror and keeps its place")
	check(game.sheet.lowered and game.sheet.visible, "Button: a lowered mirror shows a faint outline where it stood")
	check("remove" in events, "Button: lowering reports remove")
	check(is_zero_approx(game.bar._open), "Button: the bar closes to the mirror button")
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and pivot().is_equal_approx(Vector3(0.5, 0, 0)), "Button: raising again puts it back")


## The finger travel on the screen that moves the mirror's glass by `world`
## on the ground: a slide on the glass goes under the finger.
func ground_travel(world: Vector3) -> Vector2:
	return game.camera.unproject_position(pivot() + world) - game.camera.unproject_position(pivot())


func check_lift_knob() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	var start := knob(1)
	var before := pivot()
	events.clear()
	var finish := start + travel(Vector3.UP)
	mouse_button(start, true)
	await process_frame
	for step: int in range(1, 13):
		mouse_move(start.lerp(finish, step / 12.0))
		await process_frame
	await frames(8)
	check(game.dragging and game.guide_kind == "height", "Lift: the guide shows the height")
	mouse_button(finish, false)
	await direct_settled()
	check(pivot().is_equal_approx(before + Vector3(0, 1, 0)), "Lift: the lift knob raises the mirror one unit, and nothing else")
	var risen := pivot()
	await drag(start, start - travel(Vector3.UP))
	check(pivot().is_equal_approx(risen - Vector3(0, 1, 0)), "Lift: a slide the other way lowers it again")
	check("lower" in events, "Lift: lowering the mirror reports lower")


func check_glass_slide() -> void:
	## A slide that starts on the glass moves the mirror on the ground, under
	## the finger, with the sign of the ground. It is the only way to move the
	## mirror on the ground with a finger (owner, 2026-11-18).
	await load_stage("01_route")
	await press_mirror_button()
	var start := glass_point()
	var before := pivot()
	var history: int = game.history.size()
	var finish: Vector2 = start + ground_travel(Vector3.RIGHT * 2.0)
	events.clear()
	mouse_button(start, true)
	await process_frame
	for step: int in range(1, 13):
		mouse_move(start.lerp(finish, step / 12.0))
		await process_frame
	check(game.dragging and game.phase == "preview" and game.placement_guide._data.get("sign", false), "Glass: a slide on the glass holds the mirror and shows the sign")
	check(not game.hud._cancel.visible and not game.hud._apply.visible and not game.hud._mode_cycle.visible and not game.hud._edit_border.visible,
		"Glass: no edit buttons appear while dragging")
	check(game.rings.get_control_rects().is_empty() and game.resize_controls.get_control_rects().is_empty(), "Glass: no rings or resize handles appear")
	check(game.guide_kind == "ground", "Glass: the guide shows the ground")
	await frames(6)
	mouse_button(finish, false)
	await direct_settled()
	check(pivot().is_equal_approx(before + Vector3.RIGHT * 2.0), "Glass: the mirror goes as far on the ground as the finger")
	check(game.history.size() == history + 1 and "move" in events, "Glass: the slide is one change, and it reports move")
	# One slide changes both ground axes.
	before = pivot()
	start = glass_point()
	await drag(start, start + ground_travel(Vector3(1.0, 0, 0.5)))
	check(pivot().is_equal_approx(before + Vector3(1, 0, 0.5)), "Glass: one slide moves along X and Z and keeps the height")
	game.undo()
	await direct_settled()
	game.undo()
	await direct_settled()
	check(pivot().is_equal_approx(before - Vector3(2, 0, 0)), "Glass: Undo puts the mirror back")


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


func check_turn_knob() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	var start := knob(0)
	var before := pivot()
	var yaw: float = game.mirror["yaw"]
	var pitch: float = game.mirror["pitch"]
	events.clear()
	await drag(start, start + Vector2(24, 0))
	check(is_equal_approx(wrapf(float(game.mirror["yaw"]) - yaw, -PI, PI), PI * 0.25), "Turn: one push of the turn knob to the right turns the mirror 45 degrees")
	check(pivot().is_equal_approx(before), "Turn: turning keeps the mirror's centre")
	check("turn" in events, "Turn: a turn reports turn")
	# Four pushes to the left in one hold, each with a way back, are a half
	# turn; the tilt stays.
	yaw = game.mirror["yaw"]
	await nudge(Vector2.LEFT, 4)
	check(is_equal_approx(absf(wrapf(float(game.mirror["yaw"]) - yaw, -PI, PI)), PI) and is_equal_approx(float(game.mirror["pitch"]), pitch), "Turn: four pushes in one hold are a half turn, and the tilt stays")
	game.undo()
	await direct_settled()
	await point(Vector3.BACK)
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.BACK), "Turn: asking for +Z turns the mirror to copy toward +Z")
	check(pivot().is_equal_approx(before), "Turn: a quarter turn keeps the mirror's centre")
	await point(Vector3.FORWARD)
	check(MirrorRules.normal(game.mirror).is_equal_approx(Vector3.FORWARD), "Turn: asking for the opposite way is the half turn")


## The thumb on the turn knob makes `pushes` pushes of 24 points along `way`
## in one hold, each followed by a way back of 12 points.
func nudge(way: Vector2, pushes: int) -> void:
	var at := knob(0)
	mouse_button(at, true)
	await process_frame
	for push: int in pushes:
		for target: Vector2 in [at + way * 24.0, at + way * 12.0]:
			var from := at
			for step: int in range(1, 9):
				mouse_move(from.lerp(target, step / 8.0))
				await process_frame
			at = target
	await frames(6)
	mouse_button(at, false)
	await direct_settled()


func check_freedom_sign() -> void:
	## While a knob is held, the guide shows its sign at the mirror: the lift
	## knob its upright line, the turn knob the ring of its eight facings with
	## the facing now and the facing at the start. Each goes when the knob is
	## let go. The turn knob is held longer than a tap, which would turn.
	await load_stage("01_route")
	await press_mirror_button()
	for index: int in game.bar.KNOBS.size():
		var kind: String = game.bar.KNOBS[index]
		mouse_button(knob(index), true)
		var held_until := Time.get_ticks_msec() + int(game.bar.TAP_SECONDS * 1000.0) + 50
		while Time.get_ticks_msec() < held_until:
			await process_frame
		var lines: bool = not game.placement_guide.get_visible_traces().is_empty()
		if kind == "turn":
			var dots := 0
			for mark: Dictionary in game.placement_guide.get_visible_marks():
				if mark["kind"] == "dot":
					dots += 1
			check(game.placement_guide._data.get("sign", false) and lines and (game.placement_guide._data.get("dots", []) as Array).size() == 8
				and dots > 0 and game.placement_guide._data.get("target") is Vector3,
				"Sign: holding the turn knob shows the ring of eight facings at the mirror")
		else:
			check(game.placement_guide._data.get("sign", false) and lines, "Sign: holding the %s knob shows its lines at the mirror" % kind)
		var facing: Vector3 = MirrorRules.normal(game.mirror)
		mouse_button(knob(index), false)
		await direct_settled()
		for wait: int in 120:
			if game.placement_guide._data.is_empty():
				break
			await process_frame
		check(game.placement_guide._data.is_empty() and game.placement_guide.get_visible_traces().is_empty() and MirrorRules.normal(game.mirror).is_equal_approx(facing),
			"Sign: letting go of the %s knob after a hold takes its sign away and changes nothing" % kind)


func check_heavy_turn() -> void:
	## A turn moves like a large, heavy structure. The motion is stepped here
	## by frames of 1/60 s, with no real frames between: from rest it starts
	## slowly, one step of 45 degrees comes to rest in 0.4 to 0.7 s, and a
	## step asked for while it moves keeps its speed, so two steps in a row
	## take less time than two single steps.
	await load_stage("01_route")
	await press_mirror_button()
	var start: Dictionary = MirrorRules.normalized(game.mirror)
	var yaw := float(start["yaw"])
	var pitch := float(start["pitch"])
	var tick := 1.0 / 60.0
	game.begin_grip("turn", knob(1))
	game.aim_to(yaw + PI * 0.25, pitch)
	var single := 0
	var early := 0.0
	while game.turning and single < 300:
		game._turn_display(tick)
		single += 1
		if single == 6:
			early = absf(float(game.display_preview["yaw"]) - yaw)
	check(game.pointing and early < deg_to_rad(5.0) and single >= 24 and single <= 42
		and is_equal_approx(float(game.display_preview["yaw"]), yaw + PI * 0.25),
		"Heavy turn: one step starts slowly and comes to rest in 0.4 to 0.7 s (%d frames)" % single)
	game.aim_to(yaw + PI * 0.5, pitch)
	for frame: int in 20:
		game._turn_display(tick)
	var speed: float = game.turn_speed.x
	game.aim_to(yaw + PI * 0.75, pitch)
	game._turn_display(tick)
	var kept: bool = speed > 0.5 and game.turn_speed.x >= speed - game.TURN_ACCELERATION * tick * 1.01
	var double := 21
	while game.turning and double < 300:
		game._turn_display(tick)
		double += 1
	check(kept and double < single * 2, "Heavy turn: a step asked for while it moves keeps its speed (%d frames for two steps)" % double)
	game.end_grip("turn")
	await direct_settled()
	check(is_zero_approx(wrapf(float(MirrorRules.normalized(game.mirror)["yaw"]) - yaw - PI * 0.75, -PI, PI)) and not game.turning,
		"Heavy turn: on release the change applies at the shown facing")


func check_held_turn() -> void:
	## A push of the turn knob that holds keeps the mirror turning at full
	## speed, one step after another (owner, 2026-11-24: a way to turn many
	## times). When the push ends, the mirror stops on the facing it turns to
	## then, and starts no step that the hold added (owner, 2026-11-25:
	## "Overshoot on release"); it brakes up to TURN_STOP. A held tilt goes on past
	## the sky (owner, 2026-11-25: full 360 degrees). Stepped by frames of
	## 1/60 s, as the heavy turn.
	await load_stage("01_route")
	await press_mirror_button()
	var yaw := float(MirrorRules.normalized(game.mirror)["yaw"])
	var tick := 1.0 / 60.0
	game.begin_grip("turn", knob(1))
	game.aim_by(Vector2i(1, 0), Vector2i(1, 0))
	var top := 0.0
	var slowed := false
	for frame: int in 90:
		game._turn_display(tick)
		top = maxf(top, game.turn_speed.x)
		slowed = slowed or (frame >= 20 and game.turn_speed.x < top - 0.001)
	var released := float(game.display_preview["yaw"])
	check(not slowed and is_equal_approx(top, game.TURN_SPEED) and released - yaw > PI * 0.75,
		"Held turn: the mirror keeps turning at full speed while the push holds (%.0f degrees in 1.5 s)" % rad_to_deg(released - yaw))
	game.aim_by(Vector2i.ZERO, Vector2i.ZERO)
	var rest := 0
	var firmest := 0.0
	var speed_was: float = game.turn_speed.x
	while game.turning and rest < 300:
		game._turn_display(tick)
		if game.turning:
			firmest = maxf(firmest, (speed_was - game.turn_speed.x) / tick)
		speed_was = game.turn_speed.x
		rest += 1
	var end := float(game.display_preview["yaw"])
	var next := yaw + ceilf((released - yaw) / (PI * 0.25) - 0.001) * PI * 0.25
	check(is_equal_approx(end, next) and firmest <= game.TURN_STOP + 0.01,
		"Held turn: when the push ends, the mirror stops on the facing it turns to (%.0f degrees on, braking at most %.1f)" % [rad_to_deg(end - released), firmest])
	game.aim_by(Vector2i(0, -1), Vector2i(0, -1))
	for frame: int in 180:
		game._turn_display(tick)
	check(float(game.display_preview["pitch"]) < -PI, "Held turn: a held tilt goes on past the sky (%.0f degrees)" % rad_to_deg(float(game.display_preview["pitch"])))
	game.end_grip("turn")
	await direct_settled()
	check(is_zero_approx(wrapf(float(MirrorRules.normalized(game.mirror)["yaw"]) - end, -PI, PI)) and not game.turning and game.turn_hold == Vector2i.ZERO,
		"Held turn: on release the change applies at the facing where it stopped")


func check_release_stop() -> void:
	## The owner's case (2026-11-25: "Overshoot on release"): a push held
	## about 0.4 s, and the thumb comes back with the mirror at 38 degrees.
	## The hold has already asked for 90; the mirror stops at 45.
	await load_stage("01_route")
	await press_mirror_button()
	var yaw := float(MirrorRules.normalized(game.mirror)["yaw"])
	var tick := 1.0 / 60.0
	game.begin_grip("turn", knob(1))
	game.aim_by(Vector2i(1, 0), Vector2i(1, 0))
	var frame := 0
	while float(game.display_preview["yaw"]) - yaw < deg_to_rad(38.0) and frame < 120:
		game._turn_display(tick)
		frame += 1
	var asked := float(game.aim_selected["yaw"]) - yaw
	game.aim_by(Vector2i.ZERO, Vector2i.ZERO)
	var rest := 0
	var farthest := 0.0
	while game.turning and rest < 300:
		game._turn_display(tick)
		farthest = maxf(farthest, float(game.display_preview["yaw"]) - yaw)
		rest += 1
	check(is_equal_approx(asked, PI * 0.5) and is_equal_approx(float(game.display_preview["yaw"]) - yaw, PI * 0.25) and farthest <= PI * 0.25 + 0.0001,
		"Release stop: let go at 38 degrees after the hold asked for 90, the mirror stops at 45 and does not pass it (asked %.0f, stopped %.0f, farthest %.1f)" % [rad_to_deg(asked), rad_to_deg(float(game.display_preview["yaw"]) - yaw), rad_to_deg(farthest)])
	game.end_grip("turn")
	await direct_settled()
	check(is_zero_approx(wrapf(float(MirrorRules.normalized(game.mirror)["yaw"]) - yaw - PI * 0.25, -PI, PI)), "Release stop: the change applies at 45 degrees")


func check_joined_turn() -> void:
	## A press of the turn knob while the last turn still moves joins it
	## (owner, 2026-11-24: "must be smooth"): the speed stays, and the steps
	## apply as one change when the mirror is at rest.
	await load_stage("01_route")
	await press_mirror_button()
	var yaw := float(MirrorRules.normalized(game.mirror)["yaw"])
	var history_at: int = game.history.size()
	var tick := 1.0 / 60.0
	game.begin_grip("turn", knob(1))
	game.aim_by(Vector2i(1, 0), Vector2i.ZERO)
	game.end_grip("turn")
	for frame: int in 12:
		game._turn_display(tick)
	var joinable: bool = game.turn_joinable()
	var speed: float = game.turn_speed.x
	game.begin_grip("turn", knob(1))
	game.aim_by(Vector2i(1, 0), Vector2i.ZERO)
	game._turn_display(tick)
	check(joinable and game.pointing and not game.translating_settle and speed > 0.5 and game.turn_speed.x >= speed,
		"Joined turn: a press while the turn still moves joins it and keeps its speed")
	game.end_grip("turn")
	await direct_settled()
	check(game.history.size() == history_at + 1 and is_zero_approx(wrapf(float(MirrorRules.normalized(game.mirror)["yaw"]) - yaw - PI * 0.5, -PI, PI)),
		"Joined turn: the two steps apply as one change")


func check_level_ring() -> void:
	## The ring of the turn knob keeps its centre at the mirror's centre when
	## the mirror is tilted (owner, 2026-11-24): the eight dots and the dark
	## dot lie on a level ring through the centre.
	await load_stage("01_route")
	await press_mirror_button()
	var tilted: Dictionary = MirrorRules.normalized(game.mirror)
	tilted["pitch"] = -PI * 0.25
	tilted = MirrorRules.sync(tilted)
	var sign: Dictionary = game._aim_sign(tilted, tilted, tilted)
	var pivot: Vector3 = tilted["pivot"]
	var centre := Vector3.ZERO
	var level := true
	for dot: Dictionary in sign["dots"]:
		var point: Vector3 = dot["position"]
		centre += point
		level = level and is_equal_approx(point.y, pivot.y)
	centre /= maxf(1.0, sign["dots"].size())
	var orb: Vector3 = sign["references"][0]
	check(sign["dots"].size() == 8 and level and centre.is_equal_approx(pivot) and is_equal_approx(orb.y, pivot.y),
		"Level ring: on a tilted mirror the ring and the dark dot are level, round the mirror's centre")


func check_full_tilt() -> void:
	## The tilt goes all the way round, as the turn does (owner, 2026-11-25).
	## The last push of a hold chooses the ring of the sign: a tilt that comes
	## back to where it began keeps the upright ring. A pane past the sky faces
	## back, and the level ring shows it there. One whole roll is no change.
	await load_stage("01_route")
	await press_mirror_button()
	var start: Dictionary = MirrorRules.normalized(game.mirror)
	var history_at: int = game.history.size()
	game.begin_grip("turn", knob(1))
	game.aim_by(Vector2i(0, -1), Vector2i.ZERO)
	game.aim_by(Vector2i(0, 1), Vector2i.ZERO)
	var sign: Dictionary = game._aim_sign(game._display_state(), start, start)
	var pivot: Vector3 = start["pivot"]
	var upright := false
	for dot: Dictionary in sign["dots"]:
		upright = upright or absf((dot["position"] as Vector3).y - pivot.y) > 1.0
	check(game.aim_ring == "tilt" and sign["dots"].size() == 8 and upright,
		"Full tilt: a tilt back to where it began keeps the upright ring of eight tilts")
	game.aim_by(Vector2i(1, 0), Vector2i.ZERO)
	check(game.aim_ring == "turn", "Full tilt: a push to the side shows the level ring")
	game.aim_by(Vector2i(-1, 0), Vector2i.ZERO)
	for step: int in 8:
		game.aim_by(Vector2i(0, -1), Vector2i.ZERO)
	check(is_equal_approx(float(game.aim_selected["pitch"]), float(start["pitch"]) - TAU), "Full tilt: eight pushes up roll the mirror once round")
	game.end_grip("turn")
	await direct_settled()
	check(game.history.size() == history_at and MirrorRules.same(game.mirror, start), "Full tilt: one whole roll is no change")
	var back: Dictionary = start.duplicate(true)
	back["pitch"] = PI
	back = MirrorRules.sync(back)
	game.aim_ring = "turn"
	sign = game._aim_sign(back, back, back)
	var normal := MirrorRules.normal(back)
	var orb: Vector3 = sign["references"][0] - pivot
	check(Vector2(orb.x, orb.z).dot(Vector2(normal.x, normal.z)) > 0.5, "Full tilt: on the level ring, a pane past the sky shows the way it faces")


func check_sign_fades() -> void:
	## The sign of a held knob fades in when the knob is held, and fades out
	## after the change applies; the apply does not cut the fade (owner,
	## 2026-11-25).
	await load_stage("01_route")
	await press_mirror_button()
	game.begin_grip("turn", knob(1))
	var first: float = game.placement_guide._opacity
	await create_timer(0.5).timeout
	check(first < 0.01 and is_equal_approx(game.placement_guide._opacity, 1.0),
		"Sign fades: it starts unseen and fades in (%.2f, then %.2f)" % [first, game.placement_guide._opacity])
	game.aim_by(Vector2i(1, 0), Vector2i.ZERO)
	game.end_grip("turn")
	var last := 1.0
	var applied := false
	for index: int in 1200:
		if game.placement_guide._data.is_empty():
			break
		last = game.placement_guide._opacity
		applied = applied or game.phase != "preview"
		await process_frame
	check(applied and game.placement_guide._data.is_empty() and last < 0.3,
		"Sign fades: after the change applies it fades out, and is not cut (last seen at %.2f)" % last)


func check_first_raise_follows_her_look() -> void:
	## The first raise of a stage stands the mirror half a unit in front of
	## her, with its copy side the way she looks. With no walk, she looks the
	## stage's starting way.
	await load_stage("01_route")
	await press_mirror_button()
	check(bool(game.mirror.get("enabled", false)) and MirrorRules.normal(game.mirror).is_equal_approx(Vector3.RIGHT),
		"First raise: with no walk, the mirror is across the stage's starting way")
	await load_stage("01_route")
	var walked: bool = game.request_walk(game.walker.position + Vector3.BACK * 0.25)
	for index: int in 900:
		if game.walker.route.is_empty():
			break
		await process_frame
	await frames(20)
	var feet: Vector3 = game.walker.position
	await press_mirror_button()
	var ahead: float = (game.mirror["pivot"] as Vector3).z - feet.z if game.mirror.has("pivot") else -1.0
	check(walked and bool(game.mirror.get("enabled", false)) and MirrorRules.normal(game.mirror).is_equal_approx(Vector3.BACK) and ahead > 0.0 and ahead <= 0.75,
		"First raise: after a walk, the mirror is in front of her, across the way she looks")


func check_buried_comes_back() -> void:
	## Standing beside the wall in "First steps", turning the mirror copies the
	## wall onto the traveller. No move is refused (owner, 2026-11-18): the
	## turn applies, the stage goes dark, and it comes back at the move before.
	await load_stage("13_first_steps")
	var walked: bool = game.request_walk(Vector3(4, 0, -1))
	for index: int in 900:
		if game.walker.route.is_empty():
			break
		await process_frame
	await frames(3)
	check(walked and game.walker.position.distance_to(Vector3(4, 0, -1)) < 0.25, "Blocked: the traveller stands beside the wall")
	# The first raise stands the mirror across the way she looks. This check
	# needs it across the stage's starting way, so she looks that way.
	game.walker.character_visual.rotation.y = PI * 0.5
	# The stage itself leaves the mirror out; this rule check puts it back.
	game.level["mirror_available"] = true
	game._refresh()
	await press_mirror_button()
	var before: Dictionary = game.mirror.duplicate(true)
	var steps: int = game.history.size()
	await point(Vector3.LEFT)
	check(game.phase == "failure" and not MirrorRules.same(game.mirror, before), "Buried: a turn that puts the wall on the traveller is applied, not refused")
	check(await fall_and_return() and MirrorRules.same(game.mirror, before) and game.history.size() == steps
		and game.walker.position.distance_to(Vector3(4, 0, -1)) < 0.25, "Buried: the stage goes dark and comes back at the move before")


func check_stay_and_fall() -> void:
	## She stands on a copy. A drag of the mirror shows no fall ghost, and she
	## keeps her place in the world (owner, 2026-11-19: no riding). When the
	## change takes the copy from under her, she falls for real: the stage goes
	## dark and comes back at the move before (owner, 2026-11-18).
	await load_stage("01_route")
	await press_mirror_button()
	await slide(0, 2.0)
	var walked: bool = game.request_walk(Vector3(3.5, 0, 0))
	for index: int in 900:
		if game.walker.route.is_empty():
			break
		await process_frame
	await frames(3)
	check(walked, "Stay: the traveller walks out onto the copy")
	var place: Vector3 = game.walker.position
	var start: Vector2 = game.bar.centre
	var finish: Vector2 = start + travel(Vector3(1.5, 0, 0))
	game.begin_grip("move", start)
	for step: int in range(1, 13):
		game.grip_to(start.lerp(finish, step / 12.0))
		await process_frame
	await frames(40)
	check(game.dragging and not game.preview_view.ghost.visible and game.prediction["status"] == "pending", "Stay: mid-drag, nothing predicts or shows a fall")
	check(game.walker.position.is_equal_approx(place), "Stay: she keeps her place while the copy moves under the finger")
	game.grip_to(start)
	await frames(30)
	game.end_grip("move")
	await direct_settled()
	check(pivot().is_equal_approx(Vector3(2.5, 0, 0)) and game.phase == "play" and game.walker.position.distance_to(place) < 0.05,
		"Stay: dragging back and letting go changes nothing")
	var steps: int = game.history.size()
	await slide(0, 1.5)
	check(await fall_and_return() and pivot().is_equal_approx(Vector3(2.5, 0, 0)) and game.history.size() == steps
		and game.walker.position.distance_to(place) < 0.25, "Fall: a slide that takes the copy from under her drops her; the stage goes dark and comes back at the move before")
	game.toggle_mirror()
	# The copy is cut away from the top down with the pane's edge. It holds her
	# until the edge is at her feet, which are at the pane's middle here.
	var waits: bool = absf(game._direct_wait + float(game.APPLY_STEPS) / Engine.physics_ticks_per_second - Motion.time_at("reveal", 0.5)) < 0.001
	var still := true
	for index: int in 600:
		if game.phase != "preview":
			break
		still = still and absf(game.walker.position.y) < 0.01
		await process_frame
	check(waits and still, "Fall: the sinking copy holds her until the pane's edge is at her feet")
	check(await fall_and_return() and bool(game.mirror.get("enabled", false)) and game.history.size() == steps
		and game.walker.position.distance_to(place) < 0.25, "Fall: lowering the mirror under her drops her; the stage goes dark and comes back at the move before")
	check(game.dark_veil.size.is_equal_approx(root.get_visible_rect().size), "Fall: the dark covers the whole screen")
	await load_stage("01_route")
	game.toggle_mirror()
	check(game.phase == "preview" and game._direct_wait == 0.0, "Raise: a raise that leaves her ground as it is does not wait for the pane")
	await direct_settled()
	# The curve is flat at its ends, so the end has a tolerance.
	check(is_equal_approx(Motion.time_at("reveal", 0.5), Motion.duration("reveal") * 0.5) and Motion.time_at("reveal", 0.0) < 0.001
		and absf(Motion.time_at("reveal", 1.0) - Motion.duration("reveal")) < 0.001, "Motion: time_at gives the time of a weight on the reveal curve")


func check_camera_stays() -> void:
	await load_stage("01_route")
	await press_mirror_button()
	await frames(30)
	var position: Vector3 = game.camera.position
	var size: float = game.camera.size
	var start := glass_point()
	await drag(start, start + ground_travel(Vector3(0.5, 0, 0)))
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
	check(not game.direct_controls and not game.gesture.direct and not game.bar.shown, "Toggle: the debug switch brings back the classic editor")
	game.begin_preview()
	await direct_settled()
	check(game.hud._mode_cycle.visible and game.hud._cancel.visible, "Toggle: the classic editor shows its mode button and edit row")
	game.cancel_preview()
	await frames(2)
	game._action("classic_controls", false)
	await frames(2)
	check(game.direct_controls and game.gesture.direct and game.bar.shown, "Toggle: switching back restores the direct controls")
