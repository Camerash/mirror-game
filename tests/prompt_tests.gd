extends SceneTree
## The one-time tutorial prompts: the queue for each stage, the events that
## close a prompt, the "?" replay, the progress-object interface, and the
## loader's validation of a bad `prompts` field.
##
## The stages' prompts teach the direct controls the game plays with, so the
## game here runs them too. Where driving the real command is cheap, these
## checks use it (request_walk, turn_camera, the mirror button, a drag on the
## mirror along one axis, the arrow, a real safe fall). A non-matching event
## is instead emitted directly on `tutorial_event`: it exercises the same
## `_on_tutorial_event` guard without needing a second, unrelated real action
## for every stage.

const Game := preload("res://game.gd")
const Levels := preload("res://core/level_loader.gd")

## Duck-typed save-progress stub matching the interface documented on
## `game.progress`.
class ProgressStub extends RefCounted:
	var done := {}
	func is_prompt_done(id: String) -> bool:
		return bool(done.get(id, false))
	func mark_prompt_done(id: String) -> void:
		done[id] = true

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
	for index: int in 600:
		if game.pending.is_empty() and not game.camera.busy and game.settle_frames == 0:
			return
		await process_frame


func camera_idle() -> void:
	for index: int in 600:
		if not game.camera.busy and not game._manipulating():
			return
		await process_frame


## The direct actions apply when the finger lifts; each helper waits for that.
func direct_settled() -> void:
	for index: int in 600:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy:
			return
		await process_frame


func press_mirror_button() -> void:
	game.toggle_mirror()
	await direct_settled()


## A finger on the mirror's centre drags along one axis (0 x, 1 y, 2 z).
func slide(axis: int, units: float) -> void:
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
	game.begin_point()
	game.point_toward(direction)
	await frames(8)
	game.end_point()
	await direct_settled()


func walk_to(target: Vector3) -> bool:
	if not game.request_walk(target):
		return false
	for index: int in 600:
		await process_frame
		if game.walker.route.is_empty():
			await frames(3)
			break
	return game.walker.position.distance_to(target) < 0.22


## Waits for a landing, counting only after two unpaused physics steps: a
## direct change applies without a camera blend, so a floor contact left over
## from before the change must not read as one.
func direct_fall() -> void:
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


func load_stage(path: String) -> void:
	game.auto_advance = false
	check(game.load_level(Game.LEVEL_PATHS.find(path)), "Loads " + path)
	await idle()
	await frames(2)


func active_prompt_id() -> String:
	return str(game._active_prompt.get("id", ""))


## `_track_fall` reads the traveller's grounded state one physics tick behind
## its own landing (see game.gd), so a caller waiting on the resulting "fall"
## event needs to poll rather than assume one or two frames is enough.
func wait_until_prompt_changes(previous_id: String) -> void:
	for index: int in 60:
		if active_prompt_id() != previous_id:
			return
		await process_frame


func queue_and_active_empty() -> bool:
	return game._active_prompt.is_empty() and game._prompt_queue.is_empty()


## An ivory card with no words in it is never a valid state, for the
## transient hint or for the tutorial prompt.
func check_no_empty_cards(label: String) -> void:
	check(not (game.hud._hint.visible and game.hud._hint.text.is_empty()), "%s: the hint is never visible with empty text" % label)
	check(not (game.hud._prompt.visible and game.hud._prompt.text.is_empty()), "%s: the prompt card is never visible with empty text" % label)


func run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	game.direct_controls = true
	root.add_child(game)
	await frames(2)
	await check_first_steps()
	await check_route()
	await check_reveal()
	await check_aperture()
	await check_turn()
	await check_together()
	await check_replay()
	await check_progress_stub()
	# Earlier checks marked 13_first_steps's prompts done for this run;
	# clear that memory so the next two checks see a fresh stage again.
	game._prompt_done_memory.clear()
	await check_transition_guard()
	await check_prompt_blocks_input()
	check_prompt_validation()
	game.queue_free()
	await frames(1)
	print("Prompt tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_first_steps() -> void:
	await load_stage("res://levels/13_first_steps.json")
	check(active_prompt_id() == "walk_tap", "First steps: the walk prompt is first")
	check(game.hud._prompt.visible and game.hud._prompt.text == "Tap a block to walk there.",
		"First steps: the walk prompt text shows on load")
	game.tutorial_event.emit("camera_turn")
	await frames(1)
	check(active_prompt_id() == "walk_tap", "First steps: a non-matching event does not advance the prompt")
	check(game.request_walk(Vector3(1, 0, 0)), "First steps: the walk to path_1 is accepted")
	await frames(1)
	check(active_prompt_id() == "turn_view", "First steps: walking advances to the turn prompt")
	game.turn_camera(1)
	await camera_idle()
	check(queue_and_active_empty() and not game.hud._prompt.visible, "First steps: turning the view closes the last prompt")
	check_no_empty_cards("First steps")


func check_route() -> void:
	await load_stage("res://levels/01_route.json")
	check(active_prompt_id() == "make_mirror", "Route: make_mirror prompt is first")
	game.tutorial_event.emit("move")
	await frames(1)
	check(active_prompt_id() == "make_mirror", "Route: a non-matching event does not advance make_mirror")
	await press_mirror_button()
	check(active_prompt_id() == "move_mirror", "Route: raising the mirror advances to move_mirror")
	await slide(0, 2.0)
	check(bool(game.mirror.get("enabled", false)), "Route: the slid mirror applies on release")
	check(queue_and_active_empty(), "Route: sliding the mirror closes the last prompt")
	check_no_empty_cards("Route")


func check_reveal() -> void:
	await load_stage("res://levels/08_reveal.json")
	check(active_prompt_id() == "remove_mirror", "Reveal: remove_mirror prompt is first")
	game.tutorial_event.emit("confirm")
	await frames(1)
	check(active_prompt_id() == "remove_mirror", "Reveal: a non-matching event does not advance remove_mirror")
	await press_mirror_button()
	await slide(0, 2.0)
	check(active_prompt_id() == "remove_mirror", "Reveal: raising and sliding the mirror do not close remove_mirror")
	await press_mirror_button()
	check(not bool(game.mirror.get("enabled", true)), "Reveal: the mirror button lowers the mirror")
	check(queue_and_active_empty(), "Reveal: lowering the mirror closes remove_mirror")
	check_no_empty_cards("Reveal")


func check_aperture() -> void:
	await load_stage("res://levels/11_aperture.json")
	check(active_prompt_id() == "lower_mirror", "Aperture: lower_mirror prompt is first")
	game.tutorial_event.emit("turn")
	await frames(1)
	check(active_prompt_id() == "lower_mirror", "Aperture: a non-matching event does not advance lower_mirror")
	await press_mirror_button()
	await slide(0, 1.5)
	check(active_prompt_id() == "lower_mirror", "Aperture: a drag along the ground does not close lower_mirror")
	await slide(1, -1.0)
	check(queue_and_active_empty(), "Aperture: dragging the mirror down closes lower_mirror")
	check_no_empty_cards("Aperture")


func check_turn() -> void:
	await load_stage("res://levels/14_turn.json")
	check(active_prompt_id() == "turn_mirror", "Turn: turn_mirror prompt is first")
	game.tutorial_event.emit("resize")
	await frames(1)
	check(active_prompt_id() == "turn_mirror", "Turn: a non-matching event does not advance turn_mirror")
	await press_mirror_button()
	await point(Vector3.BACK)
	check(queue_and_active_empty(), "Turn: pointing the arrow closes turn_mirror")
	check_no_empty_cards("Turn")


func check_together() -> void:
	await load_stage("res://levels/15_together.json")
	check(active_prompt_id() == "safe_fall", "Together: safe_fall prompt is first")
	game.tutorial_event.emit("goal")
	await frames(1)
	check(active_prompt_id() == "safe_fall", "Together: a non-matching event does not advance safe_fall")
	await press_mirror_button()
	await point(Vector3.BACK)
	await slide(2, 0.5)
	await slide(1, -1.0)
	check(await walk_to(Vector3(0, 0, 4)), "Together: the traveller reaches above the low path")
	await press_mirror_button()
	await direct_fall()
	check(game.phase == "play" and game.walker.position.y < -2.5, "Together: lowering the mirror above the low path is a safe fall")
	await wait_until_prompt_changes("safe_fall")
	check(queue_and_active_empty(), "Together: a safe fall of at least 0.3 s closes safe_fall")
	check_no_empty_cards("Together")


func check_replay() -> void:
	await load_stage("res://levels/01_route.json")
	await press_mirror_button()
	await slide(0, 2.0)
	check(bool(game.mirror.get("enabled", false)), "Replay: setting up the mirror applies")
	check(queue_and_active_empty(), "Replay: the stage's prompts are all done before the replay")
	game._action("help", null)
	await frames(1)
	check(active_prompt_id() == "make_mirror", "Replay: the help button restarts at the first prompt")
	game.tutorial_event.emit("create")
	await frames(1)
	check(active_prompt_id() == "move_mirror", "Replay: a replayed prompt still advances on its own event")
	game._action("help", null)
	await frames(1)
	check(queue_and_active_empty(), "Replay: a second help press closes the replay early")
	await load_stage("res://levels/01_route.json")
	check(queue_and_active_empty(), "Replay: completion made during the real run still persists after the replay")
	check_no_empty_cards("Replay")


func check_progress_stub() -> void:
	var progress := ProgressStub.new()
	game.progress = progress
	await load_stage("res://levels/01_route.json")
	check(active_prompt_id() == "make_mirror", "Progress stub: a fresh stage still starts at make_mirror")
	await press_mirror_button()
	check(bool(progress.done.get("make_mirror", false)), "Progress stub: raising the mirror marks make_mirror done on the stub")
	check(active_prompt_id() == "move_mirror", "Progress stub: the queue advances to move_mirror")
	await load_stage("res://levels/01_route.json")
	check(active_prompt_id() == "move_mirror", "Progress stub: a reloaded stage skips the done prompt")
	game.progress = null


func check_transition_guard() -> void:
	# 13_first_steps starts a fresh two-prompt queue. Clearing the active
	# prompt without its real event, the way `_on_tutorial_event` does just
	# before calling `_start_prompts` again, isolates the phase guard from
	# the cost and the fade timing of a full stage-sweep transition.
	await load_stage("res://levels/13_first_steps.json")
	check(active_prompt_id() == "walk_tap", "Transition guard: the prompt shows before the transition")
	game._active_prompt = {}
	game._prompt_shown_id = ""
	game.phase = "transition"
	game._start_prompts()
	check(active_prompt_id() == "", "Transition guard: the next prompt does not start while phase is transition")
	game.phase = "play"
	game._start_prompts()
	check(active_prompt_id() == "turn_view", "Transition guard: the next prompt starts once phase leaves transition")
	check_no_empty_cards("Transition guard")


func check_prompt_blocks_input() -> void:
	await load_stage("res://levels/13_first_steps.json")
	check(game.hud._prompt.visible, "Blocks input: a prompt shows for the check")
	var point: Vector2 = game.hud._prompt.get_global_rect().get_center()
	check(not game.hud.blocks_world_input(point), "Blocks input: the prompt card does not block a point under it")
	check_no_empty_cards("Blocks input")


func check_prompt_validation() -> void:
	var file := FileAccess.open("res://levels/01_route.json", FileAccess.READ)
	var raw: Dictionary = JSON.parse_string(file.get_as_text())
	check(Levels.validate(raw).is_empty(), "Validation: the baseline level, prompts included, still validates")
	var unknown_event := raw.duplicate(true)
	unknown_event["prompts"] = [{"id": "a", "text": "x", "until": "nonsense"}]
	check(not Levels.validate(unknown_event).is_empty(), "Validation: an unknown prompt event is rejected")
	var duplicate_id := raw.duplicate(true)
	duplicate_id["prompts"] = [{"id": "a", "text": "x", "until": "walk"}, {"id": "a", "text": "y", "until": "confirm"}]
	check(not Levels.validate(duplicate_id).is_empty(), "Validation: a duplicate prompt id is rejected")
	var empty_text := raw.duplicate(true)
	empty_text["prompts"] = [{"id": "a", "text": "", "until": "walk"}]
	check(not Levels.validate(empty_text).is_empty(), "Validation: empty prompt text is rejected")
	var good := raw.duplicate(true)
	good["prompts"] = [{"id": "a", "text": "x", "until": "walk"}]
	check(Levels.validate(good).is_empty(), "Validation: a well-formed prompts field is accepted")
