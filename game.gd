extends Node3D
## Commands below are shared by HUD input, keyboard input, and replay tests.

const Queries := preload("res://core/solid_queries.gd")
const Contact := preload("res://world/mirror_contact.gd")
const PlacementGuide := preload("res://world/placement_guide.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const Navigation := preload("res://core/walk_graph.gd")
const View := preload("res://world/world_view.gd")
const Walker := preload("res://world/walker.gd")
const HUD := preload("res://ui/mirror_hud.gd")
const Predictor := preload("res://world/fall_predictor.gd")
const PreviewView := preload("res://world/preview_view.gd")
const Atmosphere := preload("res://world/atmosphere.gd")
const Resize := preload("res://ui/mirror_resize.gd")
const Rings := preload("res://world/mirror_rings.gd")
const Sheet := preload("res://world/mirror_sheet.gd")
const MirrorRules := preload("res://core/mirror_state.gd")
const WorldGesture := preload("res://ui/world_gesture.gd")
const StageCameraView := preload("res://world/stage_camera.gd")
const PUZZLE_PATHS: Array[String] = ["res://levels/01_route.json", "res://levels/08_reveal.json"]
const LEVEL_PATHS: Array[String] = PUZZLE_PATHS + ["res://levels/02_partial_cut.json",
	"res://levels/03_source.json", "res://levels/04_absolute.json", "res://levels/05_restore.json",
	"res://levels/06_wall.json", "res://levels/07_horizontal.json", "res://levels/09_movement.json", "res://levels/10_extent.json"]

var level: Dictionary = {}
var level_index := 0
var mirror: Dictionary = {}
var preview: Dictionary = {}
var preview_origin: Dictionary = {}
var sheet := Sheet.new()
var rings := Rings.new()
var resize_controls := Resize.new()
var resizing := false
var resize_origin: Dictionary = {}
var resize_key := ""
var resize_pointer_origin := Vector2.ZERO
var resize_screen_axis := Vector2.ZERO
var resize_limits := Vector2(1, 6)
var prediction: Dictionary = {"status": "idle"}
var prediction_revision := 0
var standing_only := false
var edit_available := false
var predictor := Predictor.new()
var preview_view := PreviewView.new()
var atmosphere := Atmosphere.new()
var solids: Array[Dictionary] = []
var history: Array[Dictionary] = []
var phase := "play"
var status := "Tap a platform to walk. Enable the mirror to explore."
var style := 0
var pending: Dictionary = {}
var settle_frames := 0
var envelope := AABB()
var navigation := Navigation.new()
var world := View.new()
var walker := Walker.new()
var camera := StageCameraView.new()
var goal_root := Node3D.new()
var hud := HUD.new()
var failure_veil := ColorRect.new()
var play_rect := Rect2()
var dragging := false
var drag_origin := Vector2.ZERO
var drag_axis := Vector2.ZERO
var drag_pivot := Vector3.ZERO
var drag_ground_origin := Vector3.ZERO
var height_drag := false
var drag_touch := -1
var gesture := WorldGesture.new()
var outline_accessible := false
var display_preview: Dictionary = {}
var translation_motion: Tween
var translating_settle := false
var rotation_active := false
var rotation_origin: Dictionary = {}
var rotation_axis := Vector3.UP
var rotation_angle := 0.0
var rotation_kind := "turn"
var angle_snap := 0.0
var placement_guide := PlacementGuide.new()
var contact := Contact.new()
var display_basis := Basis.IDENTITY
var rotation_display := false
var rotation_motion: Tween
var rotation_queue: Array[Dictionary] = []
var rotation_target: Dictionary = {}
var cancelling_gesture := false
var limit_hint_shown := false
var viewport_size := Vector2.ZERO

func _ready() -> void:
	if OS.get_name() in ["iOS", "Android"]:
		get_window().content_scale_factor = maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	# The official Intel Simulator template uses software OpenGL on this Mac.
	# Keep UI resolution intact; reduce only 3D cost for Simulator playtests.
	if OS.has_feature("simulator"):
		get_viewport().scaling_3d_scale = 0.35
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_setup_scene()
	var titles: Array[String] = []
	for path: String in LEVEL_PATHS:
		titles.append(str(Levels.load_level(path).get("title", "Invalid level")))
	hud.configure_levels(titles, 0)
	hud.action_requested.connect(_action)
	hud.play_rect_changed.connect(_fit_camera)
	gesture.action_requested.connect(_gesture_action)
	gesture.hold_progress.connect(hud.set_hold_progress)
	load_level(0)
	_fit_camera(hud.get_play_rect())
	hud.show_hint("Tap to walk. Hold empty space to create a mirror.")

func _setup_scene() -> void:
	add_child(world)
	add_child(predictor)
	add_child(preview_view)
	add_child(atmosphere)
	add_child(sheet)
	add_child(placement_guide)
	add_child(contact)
	add_child(rings)
	rings.action_requested.connect(_action)
	rings.is_obstructed = _ring_obstructed
	sheet.transition_finished.connect(_rotation_finished)
	sheet.pose_changed.connect(func() -> void: rings.set_pose(sheet.global_transform))
	camera.view_changed.connect(_camera_changed)
	camera.motion_finished.connect(_camera_motion_finished)
	predictor.ready_result.connect(_prediction_ready)
	walker.route_finished.connect(_route_finished)
	add_child(goal_root)
	add_child(walker)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.05
	camera.far = 100.0
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e9e5dc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d6e0df")
	environment.environment.ambient_light_energy = 0.4
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_color = Color("fff0d8")
	light.light_energy = 0.65
	light.shadow_enabled = not OS.has_feature("simulator")
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	canvas.add_child(resize_controls)
	resize_controls.action_requested.connect(_action)
	resize_controls.is_obstructed = _resize_obstructed
	canvas.add_child(failure_veil)
	failure_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	failure_veil.color = Color(0.8, 0.67, 0.57, 0)

func load_level(index: int) -> bool:
	if index < 0 or index >= LEVEL_PATHS.size():
		return false
	var loaded := Levels.load_level(LEVEL_PATHS[index])
	if loaded.is_empty():
		status = "This level could not be loaded."
		return false
	_cancel_manipulation()
	level = loaded
	level["mirror"] = MirrorRules.normalized(level["mirror"])
	var reference: Dictionary = level["mirror"].duplicate(true)
	reference["enabled"] = false
	placement_guide.configure(Geometry.total_bounds(Geometry.generate(level, reference)).position.y - 0.5)
	level_index = index
	world.set_art_trial(index == 0 or index == LEVEL_PATHS.size() - 1)
	atmosphere.set_art_trial(index == 0)
	walker.set_art_trial(index == 0)
	gesture.cancel()
	mirror = level["mirror"].duplicate(true) if level["mirror"]["enabled"] else {"enabled": false}
	preview.clear()
	preview_origin.clear()
	predictor.cancel()
	prediction = {"status": "idle"}
	preview_view.clear()
	history.clear()
	pending.clear()
	phase = "play"
	dragging = false
	walker.restore(Geometry.vector(level["start"]), Vector3.ZERO)
	_commit_world()
	envelope = Geometry.total_bounds(solids)
	atmosphere.set_bounds(Geometry.total_bounds(solids))
	for child: Node in goal_root.get_children():
		child.free()
	world.add_ring(goal_root, Geometry.vector(level["goal"]), Color("805534"))
	status = "Tap a platform to walk. Hold empty space to create a mirror."
	_refresh()
	_fit_camera(hud.get_play_rect(), true)
	return true

func _physics_process(_delta: float) -> void:
	if level.is_empty():
		return
	if not pending.is_empty():
		_execute_pending()
	if settle_frames > 0:
		settle_frames -= 1
		if settle_frames == 0:
			_refresh()
		walker.paused = true
		return
	walker.paused = phase != "play"
	if phase != "play":
		return
	if can_edit() != edit_available:
		_refresh()
	if walker.position.y < float(level["kill_y"]):
		_fail()
	elif not level.get("is_test", false) and walker.position.distance_to(Geometry.vector(level["goal"])) < 0.22:
		phase = "complete"
		walker.stop()
		status = "A new way through. You reached the goal."
		_refresh()

func request_walk(target: Vector3) -> bool:
	if phase != "play" or settle_frames > 0 or not pending.is_empty():
		return false
	var route := navigation.route(walker.position, target)
	if route.is_empty():
		status = "There is no connected path to that point."
		_refresh()
		return false
	history.append(_snapshot())
	walker.route = route
	world.draw_route(route)
	status = "Walking."
	_refresh()
	return true

func advance_level() -> bool:
	if not _can_advance():
		return false
	return load_level(level_index + 1)

func _can_advance() -> bool:
	return phase == "complete" and pending.is_empty() and level_index + 1 < PUZZLE_PATHS.size()

func can_edit() -> bool:
	if phase not in ["play", "complete"] or not pending.is_empty() or settle_frames > 0:
		return false
	return not standing_only or (walker.route.is_empty() and walker.is_on_floor() and walker.velocity.length() < 0.05)

func begin_preview() -> void:
	# Keyboard and debug entry use fresh level defaults when no mirror exists.
	if mirror.get("enabled", false):
		edit_mirror()
	else:
		_open_preview(_new_mirror(level["mirror"]["pivot"]))

func create_mirror(point: Vector2) -> void:
	if mirror.get("enabled", false) or not can_edit():
		return
	var ray := camera.project_ray_normal(point)
	var origin := camera.project_ray_origin(point)
	if absf(ray.y) < 0.0001:
		return
	var location := origin + ray * ((walker.position.y - origin.y) / ray.y)
	_open_preview(_new_mirror(location))

func _new_mirror(location: Vector3) -> Dictionary:
	var fresh: Dictionary = level["mirror"].duplicate(true)
	location = MirrorRules.snapped_pivot(location, level["limits"])
	fresh["width"] = 3.0
	fresh["height"] = 3.0
	fresh["enabled"] = true
	fresh["pivot"] = location
	fresh["offset"] = location[int(fresh["axis"])]
	return fresh

func edit_mirror() -> void:
	if mirror.get("enabled", false):
		_open_preview(mirror.duplicate(true))

func remove_mirror() -> void:
	change_preview("enabled", false)

func _open_preview(proposal: Dictionary) -> void:
	if not can_edit():
		return
	preview_origin = _snapshot()
	preview = MirrorRules.normalized(proposal)
	walker.paused = true
	phase = "preview"
	world.draw_route(PackedVector3Array())
	_update_preview()
	_fit_camera(hud.get_play_rect())
	rings.choose_edge_ends()
	hud.show_hint("Drag to move. Use the height arrow to lift. Tap to place.")

func change_preview(key: String, value: Variant) -> void:
	if phase != "preview" or not pending.is_empty() or _manipulating():
		return
	var previous := preview.duplicate(true)
	if key not in ["axis", "source", "offset", "enabled", "width", "height"]:
		return
	if key in ["width", "height"]:
		_resize_to(key, float(value))
		return
	if key == "axis":
		if int(value) not in [0, 1, 2]:
			return
		for field: String in ["yaw", "pitch", "frame_up", "source_sign"]:
			preview.erase(field)
		preview["axis"] = int(value)
		preview = MirrorRules.normalized(preview)
	elif key == "source":
		if int(value) != int(preview["source"]):
			preview = MirrorRules.reversed(preview)
	elif key == "offset":
		var axis: int = preview["axis"]
		var pivot: Vector3 = preview["pivot"]
		pivot[axis] = float(value)
		preview["pivot"] = MirrorRules.snapped_pivot(pivot, level["limits"])
		preview = MirrorRules.sync(preview)
	else:
		preview[key] = value
	if preview != previous:
		_update_preview()
		_fit_camera(hud.get_play_rect())

func _manipulating() -> bool:
	return dragging or resizing or translating_settle or rotation_active or not rotation_queue.is_empty() or not rotation_target.is_empty()

func _invalidate_prediction() -> void:
	predictor.cancel()
	prediction_revision = -1
	prediction = {"status": "pending"}
	preview_view.clear()

func rotate_mirror(direction: int) -> void:
	_queue_rotation("turn", direction)

func tilt_mirror(direction := 1) -> void:
	_queue_rotation("tilt", direction)

func _queue_rotation(kind: String, direction: int) -> void:
	if phase != "preview" or not pending.is_empty() or dragging or resizing or translating_settle or camera.busy or not preview["enabled"]:
		return
	if rotation_active:
		return
	rotation_queue.append({"kind": kind, "direction": signi(direction)})
	_invalidate_prediction()
	_advance_rotation()

func _advance_rotation() -> void:
	if not rotation_target.is_empty() or rotation_active:
		return
	while not rotation_queue.is_empty():
		var step: Dictionary = rotation_queue.pop_front()
		if step["kind"] == "turn" and MirrorRules.horizontal(preview):
			continue
		_start_rotation({"kind": step["kind"], "axis": Vector3.UP if step["kind"] == "turn" else MirrorRules.frame(preview).x})
		rotation_active = false
		_settle_rotation(float(step["direction"]) * PI * 0.5)
		return
	if phase == "preview":
		_update_preview()
		_fit_camera(hud.get_play_rect())

func _start_rotation(value: Dictionary) -> void:
	rotation_origin = MirrorRules.normalized(preview)
	rotation_axis = value["axis"]
	rotation_kind = str(value.get("kind", "turn" if rotation_axis.is_equal_approx(Vector3.UP) else "tilt"))
	rotation_angle = 0.0
	rotation_active = true
	rotation_display = true
	display_basis = MirrorRules.frame(preview)
	_invalidate_prediction()
	_refresh()

func _set_rotation_angle(angle: float) -> void:
	if rotation_origin.is_empty() or not is_finite(angle):
		return
	rotation_angle = angle
	display_preview = MirrorRules.rotated(rotation_origin, rotation_kind, angle)
	display_basis = MirrorRules.frame(display_preview)
	_update_preview()

func _finish_rotation_drag() -> void:
	rotation_active = false
	if not cancelling_gesture and not rotation_origin.is_empty():
		var key := "yaw" if rotation_kind == "turn" else "pitch"
		var origin_angle := float(rotation_origin[key])
		var target := origin_angle + rotation_angle
		if angle_snap > 0.0:
			target = snappedf(target, deg_to_rad(angle_snap))
		_settle_rotation(target - origin_angle)

func _settle_rotation(target_angle: float) -> void:
	rotation_target = MirrorRules.rotated(rotation_origin, rotation_kind, target_angle)
	rotation_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rotation_motion.tween_method(_set_rotation_angle, rotation_angle, target_angle, 0.15)
	rotation_motion.tween_callback(_rotation_finished)

func _rotation_finished() -> void:
	if rotation_target.is_empty() or phase != "preview":
		return
	preview = rotation_target
	display_preview.clear()
	rotation_target = {}
	rotation_origin.clear()
	rotation_display = false
	if not rotation_queue.is_empty():
		_advance_rotation()
	else:
		_update_preview()
		_fit_camera(hud.get_play_rect())

func _cancel_manipulation() -> void:
	cancelling_gesture = true
	gesture.cancel()
	if rings.is_inside_tree():
		rings.cancel()
	if resize_controls.is_inside_tree():
		resize_controls.cancel()
	resizing = false
	resize_origin.clear()
	if translation_motion and translation_motion.is_valid():
		translation_motion.kill()
	dragging = false
	height_drag = false
	translating_settle = false
	rotation_active = false
	rotation_display = false
	rotation_origin.clear()
	if rotation_motion and rotation_motion.is_valid():
		rotation_motion.kill()
	rotation_queue.clear()
	rotation_target.clear()
	display_preview.clear()
	if sheet.is_inside_tree():
		sheet.cancel_transition()
	cancelling_gesture = false

func apply_preview() -> bool:
	if phase != "preview" or not pending.is_empty() or _manipulating() or sheet.is_transitioning() or camera.busy:
		return false
	if prediction["status"] in ["pending", "idle", "unresolved"]:
		return false
	if prediction["status"] == "blocked":
		status = "A solid wall would occupy this position. Move the mirror or cancel."
		_refresh()
		return false
	pending = {"action": "apply", "mirror": preview.duplicate(true)}
	return true

func cancel_preview() -> void:
	if phase != "preview" or not pending.is_empty():
		return
	_cancel_manipulation()
	preview.clear()
	predictor.cancel()
	prediction = {"status": "idle"}
	preview_view.clear()
	phase = "complete" if preview_origin.get("complete", false) else "play"
	walker.restore(preview_origin["position"], preview_origin["velocity"])
	walker.route = preview_origin["route"].duplicate()
	walker.paused = phase != "play"
	world.draw_world(solids)
	atmosphere.set_bounds(Geometry.total_bounds(solids))
	world.draw_route(walker.route)
	status = "Walking." if not walker.route.is_empty() else "Preview cancelled."
	dragging = false
	_refresh()
	_fit_camera(hud.get_play_rect())

func undo() -> bool:
	if history.is_empty() or not pending.is_empty():
		return false
	pending = {"action": "undo", "snapshot": history.pop_back()}
	walker.paused = true
	return true

func _snapshot() -> Dictionary:
	return {"mirror": mirror.duplicate(true), "position": walker.position,
		"velocity": walker.velocity, "route": walker.route.duplicate(), "complete": phase == "complete"}

func _execute_pending() -> void:
	_cancel_manipulation()
	var command := pending
	pending = {}
	if command["action"] == "apply":
		history.append(preview_origin.duplicate(true))
		mirror = command["mirror"] if command["mirror"]["enabled"] else {"enabled": false}
		walker.restore(preview_origin["position"], preview_origin["velocity"])
		phase = "play"
		status = "Mirror changed. Find your next path."
	else:
		var snapshot: Dictionary = command["snapshot"]
		mirror = snapshot["mirror"]
		walker.restore(snapshot["position"], snapshot["velocity"])
		phase = "complete" if snapshot["complete"] else "play"
		status = "Last action undone."
	preview.clear()
	preview_origin.clear()
	predictor.cancel()
	prediction = {"status": "idle"}
	preview_view.clear()
	_commit_world()
	dragging = false
	_refresh()
	_fit_camera(hud.get_play_rect())

func _commit_world() -> void:
	walker.stop()
	walker.grounded = false
	walker.paused = true
	solids = Geometry.generate(level, mirror)
	world.commit(solids)
	atmosphere.set_bounds(Geometry.total_bounds(solids))
	navigation.rebuild(solids)
	world.draw_route(PackedVector3Array())
	settle_frames = 2

func _display_state() -> Dictionary:
	return display_preview if not display_preview.is_empty() else (preview if phase == "preview" else mirror)

func _update_preview() -> void:
	var proposed := Geometry.generate(level, _display_state())
	world.draw_world(proposed)
	atmosphere.set_bounds(Geometry.total_bounds(proposed))
	_invalidate_prediction()
	if not _manipulating():
		prediction_revision = predictor.predict(proposed, preview_origin["position"], preview_origin["velocity"], float(level["kill_y"]))
	status = "Checking the landing…"
	_refresh()

func _prediction_ready(result: Dictionary) -> void:
	if phase != "preview" or int(result["revision"]) != prediction_revision:
		return
	prediction = result
	match result["status"]:
		"blocked": status = "Blocked · A solid wall would occupy the character's position."
		"supported": status = "Supported · The character stays in place."
		"landing": status = "Will fall · The ghost shows a safe landing."
		"failure": status = "Will fall · No landing before the lower boundary."
		_: status = "This landing could not be checked. Move the mirror or cancel."
	preview_view.show_result(result, world)
	_refresh()

func _route_finished() -> void:
	if phase == "play":
		world.draw_route(PackedVector3Array())
		status = "Arrived. Choose the next path."
		_refresh()

func _fail() -> void:
	phase = "failure"
	walker.paused = true
	walker.stop()
	status = "The path fell away. Undo to try another idea."
	failure_veil.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(failure_veil, "color:a", 0.30, 0.15)
	tween.tween_property(failure_veil, "color:a", 0.0, 0.25)
	_refresh()

func _refresh() -> void:
	if level.is_empty():
		return
	var selected := _display_state()
	var axis: int = selected.get("axis", level["mirror"]["axis"])
	if not sheet.is_transitioning():
		sheet.set_state(selected, _sheet_bounds(), phase == "preview")
	if rotation_display:
		sheet.global_basis = display_basis
	edit_available = can_edit()
	rings.set_state(selected, phase == "preview", camera.busy or _manipulating() or not pending.is_empty())
	rings.set_pose(sheet.global_transform)
	rings.update_view(camera)
	resize_controls.set_state(selected, phase == "preview", camera.busy or _manipulating() or not pending.is_empty())
	hud.display_state({"title": level["title"], "objective": level["objective"], "phase": phase,
		"level_index": level_index, "art_trial": level_index == 0, "can_advance": _can_advance(),
		"can_edit": can_edit(), "standing_only": standing_only,
		"camera_busy": camera.busy or dragging or resizing or translating_settle, "mirror_busy": _manipulating(), "rotation_active": rotation_active or not rotation_target.is_empty(), "pending": not pending.is_empty(),
		"status": status, "editing": phase == "preview", "enabled": selected["enabled"],
		"angle_snap": angle_snap, "width": selected.get("width", 3.0), "height": selected.get("height", 3.0),
		"offset": selected.get("offset", 0.0), "axis": axis, "source": selected.get("source", 1),
		"outline_accessible": outline_accessible,
		"min_offset": level["limits"]["min"][axis], "max_offset": level["limits"]["max"][axis],
		"allowed_axes": level["limits"]["axes"], "can_undo": not history.is_empty(),
		"can_apply": phase == "preview" and pending.is_empty() and not _manipulating() and not sheet.is_transitioning() and not camera.busy and prediction["status"] in ["supported", "landing", "failure"],
		"is_test": level.get("is_test", false), "style": style, "collision": world.debug_collision})
	contact.set_contacts(world.drawn_solids, selected, MirrorRules.frame(selected) if selected.has("pivot") else Basis.IDENTITY, phase == "preview" and not selected["enabled"])
	atmosphere.set_mirror(selected, phase == "preview", style, MirrorRules.normal(selected) if selected.has("pivot") else Vector3.ZERO)
	placement_guide.show_position(selected.get("pivot", Vector3.ZERO), (dragging or translating_settle) and resize_origin.is_empty() and phase == "preview")
	_position_controls()

func _action(action: String, value: Variant) -> void:
	match action:
		"select_level": load_level(int(value))
		"angle_snap":
			if not _manipulating() and is_finite(float(value)):
				angle_snap = clampf(snappedf(float(value), 5.0), 0.0, 90.0)
				_refresh()
		"width", "height": change_preview(action, float(value))
		"height_step": _step_height(float(value))
		"resize_begin": _start_resize(value)
		"resize_move": _resize_drag(value)
		"resize_end":
			if not cancelling_gesture:
				_finish_resize()
		"next_level": advance_level()
		"edit": begin_preview()
		"create": create_mirror(value)
		"remove": remove_mirror()
		"standing_only":
			standing_only = bool(value)
			_refresh()
		"enabled": change_preview("enabled", bool(value))
		"step": change_preview("offset", float(preview.get("offset", 0)) + float(value))
		"axis": change_preview("axis", int(value))
		"turn": rotate_mirror(int(value))
		"tilt": tilt_mirror(1 if value == null else int(value))
		"rotation_begin": _start_rotation(value)
		"rotation_angle": _set_rotation_angle(float(value))
		"rotation_end": _finish_rotation_drag()
		"move_height_begin": _start_height_drag(value)
		"move_height_move": _drag(value)
		"move_height_end":
			if not cancelling_gesture:
				_finish_drag()
		"camera_turn": turn_camera(int(value))
		"flip": change_preview("source", -int(preview.get("source", 1)))
		"apply": apply_preview()
		"cancel": cancel_preview()
		"undo": undo()
		"reset": load_level(level_index)
		"style":
			style = int(value)
			_refresh()
		"collision":
			world.debug_collision = bool(value)
			world.update_debug()
			_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: turn_camera(-1)
			KEY_E: turn_camera(1)
			KEY_M: _action("edit", null)
			KEY_ENTER: apply_preview()
			KEY_ESCAPE: cancel_preview()
			KEY_D: change_preview("enabled", not bool(preview.get("enabled", true)))
			KEY_1: change_preview("axis", 0)
			KEY_2: change_preview("axis", 1)
			KEY_3: change_preview("axis", 2)
			KEY_LEFT: rotate_mirror(-1)
			KEY_RIGHT: rotate_mirror(1)
			KEY_UP: tilt_mirror(-1)
			KEY_DOWN: tilt_mirror(1)
			KEY_PAGEUP: _step_height(0.5)
			KEY_PAGEDOWN: _step_height(-0.5)
			KEY_Z: undo()
			KEY_R: load_level(level_index)
			KEY_BRACKETLEFT: _action("step", -0.5)
			KEY_BRACKETRIGHT: _action("step", 0.5)
			_: return
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	gesture.advance(delta)
	if sheet.has_geometry:
		rings.set_pose(sheet.global_transform)
		_position_resize_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_manipulation()
		if phase == "preview":
			_update_preview()
			_fit_camera(hud.get_play_rect())

func _input(event: InputEvent) -> void:
	if rings.is_active() or resize_controls.is_active():
		var pointer_index := -2
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			pointer_index = event.index
		elif event is InputEventMouse:
			pointer_index = -1
		if pointer_index != -2 and not rings.owns_pointer(pointer_index) and not resize_controls.owns_pointer(pointer_index):
			get_viewport().set_input_as_handled()
			return
	var owned := gesture.active or rings.is_active() or resize_controls.is_active()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_pointer(event.position, event.pressed, -1)
	elif event is InputEventScreenTouch:
		if event.canceled:
			if resize_controls.owns_pointer(event.index):
				resize_controls.cancel()
			if rings.owns_pointer(event.index):
				rings.cancel()
			if gesture.active and gesture.pointer == event.index:
				gesture.cancel()
		else:
			_pointer(event.position, event.pressed, event.index)
	elif event is InputEventMouseMotion:
		if not resize_controls.motion(event.position, -1) and not rings.motion(event.position, -1) and gesture.active and gesture.pointer == -1:
			gesture.move(event.position, -1)
	elif event is InputEventScreenDrag:
		if not resize_controls.motion(event.position, event.index) and not rings.motion(event.position, event.index):
			gesture.move(event.position, event.index)
	if owned and (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):
		get_viewport().set_input_as_handled()

func _pointer(point: Vector2, pressed: bool, touch: int) -> void:
	if not gesture.active and not rings.is_active() and resize_controls.pointer(point, pressed, touch):
		get_viewport().set_input_as_handled()
		return
	if not gesture.active and not resize_controls.is_active() and rings.pointer(point, pressed, touch):
		get_viewport().set_input_as_handled()
		return
	if not pressed:
		gesture.release(point, touch)
		return
	if gesture.active or rings.is_active() or resize_controls.is_active() or not play_rect.has_point(point) or hud.blocks_world_input(point):
		return
	if camera.busy or _manipulating() or sheet.is_transitioning() or not pending.is_empty() or phase == "failure":
		return
	var target := "surface" if _solid_hit(point) else "empty"
	if phase == "preview":
		if sheet_hit(point):
			target = "sheet"
	elif mirror.get("enabled", false) and sheet_hit(point):
		target = "sheet"
	elif target == "empty" and not mirror.get("enabled", false):
		target = "create"
	gesture.begin(point, touch, target, phase == "preview")

func _gesture_action(action: String, value: Variant) -> void:
	match action:
		"create": create_mirror(value)
		"edit": edit_mirror()
		"walk": _walk_at(value)
		"drag_begin": _start_drag(value)
		"drag_move":
			if dragging:
				_drag(value)
		"drag_end":
			if not cancelling_gesture:
				_finish_drag()
		"apply":
			if not apply_preview():
				hud.show_hint("Wait for the preview." if prediction["status"] == "pending" else "This placement is blocked. Move the mirror or cancel.")
		"camera_turn": turn_camera(int(value))

func _walk_at(point: Vector2) -> void:
	var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(point),
		camera.project_ray_origin(point) + camera.project_ray_normal(point) * 100, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["normal"] as Vector3).y >= Queries.FLOOR_Y - 0.0001:
		var target: Vector3 = hit["position"]
		target.y += Geometry.RADIUS * (1.0 / (hit["normal"] as Vector3).y - 1.0)
		if not request_walk(target):
			hud.show_hint("There is no connected path.")
	else:
		hud.show_hint("Tap a platform top to walk.")

func _ground_point(point: Vector2, height: float) -> Vector3:
	var ray := camera.project_ray_normal(point)
	var origin := camera.project_ray_origin(point)
	return origin + ray * ((height - origin.y) / ray.y)

func _start_drag(point: Vector2) -> void:
	if phase != "preview" or sheet.is_transitioning() or not preview["enabled"]:
		return
	dragging = true
	height_drag = false
	limit_hint_shown = false
	display_preview = preview.duplicate(true)
	_invalidate_prediction()
	drag_touch = gesture.pointer
	drag_origin = point
	drag_pivot = preview["pivot"]
	drag_axis = camera.unproject_position(drag_pivot + Vector3.RIGHT) - camera.unproject_position(drag_pivot)
	drag_ground_origin = _ground_point(point, drag_pivot.y)
	_refresh()

func _step_height(amount: float) -> void:
	if phase != "preview" or _manipulating() or camera.busy or not pending.is_empty() or not preview["enabled"]:
		return
	var pivot: Vector3 = preview["pivot"]
	pivot.y += amount
	pivot = MirrorRules.snapped_pivot(pivot, level["limits"])
	preview["pivot"] = pivot
	preview["offset"] = pivot[int(preview["axis"])]
	_update_preview()
	_fit_camera(hud.get_play_rect())

func _start_height_drag(point: Vector2) -> void:
	_start_drag(point)
	height_drag = true
	drag_axis = camera.unproject_position(drag_pivot + Vector3.UP) - camera.unproject_position(drag_pivot)

func _drag(point: Vector2) -> void:
	if not dragging:
		return
	var pivot := drag_pivot
	if height_drag:
		if drag_axis.length_squared() < 0.01:
			return
		pivot.y += (point - drag_origin).dot(drag_axis) / drag_axis.length_squared()
	else:
		pivot += _ground_point(point, drag_pivot.y) - drag_ground_origin
	var limited := pivot
	for axis: int in 3:
		limited[axis] = clampf(pivot[axis], level["limits"]["min"][axis], level["limits"]["max"][axis])
	if not limited.is_equal_approx(pivot) and not limit_hint_shown:
		hud.show_hint("Edge of the placement area.")
		limit_hint_shown = true
	_set_display_pivot(limited)

func _set_display_pivot(pivot: Vector3) -> void:
	display_preview["pivot"] = pivot
	display_preview["offset"] = pivot[int(display_preview["axis"])]
	_update_preview()

func _finish_drag() -> void:
	if not dragging:
		return
	dragging = false
	height_drag = false
	translating_settle = true
	var start: Vector3 = display_preview["pivot"]
	var target := MirrorRules.snapped_pivot(start, level["limits"])
	translation_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	translation_motion.tween_method(_set_display_pivot, start, target, 0.15)
	translation_motion.tween_callback(func() -> void:
		preview = display_preview.duplicate(true)
		display_preview.clear()
		translating_settle = false
		_update_preview()
		_fit_camera(hud.get_play_rect()))

func _sheet_bounds() -> AABB:
	return Geometry.total_bounds(world.drawn_solids).grow(0.5)

func _fit_camera(rect: Rect2, instant := false) -> void:
	var current_size := get_viewport().get_visible_rect().size
	var resized := viewport_size != Vector2.ZERO and not viewport_size.is_equal_approx(current_size)
	viewport_size = current_size
	play_rect = rect
	if level.is_empty() or rect.size.x < 10 or rect.size.y < 10:
		return
	if resized and _manipulating():
		_cancel_manipulation()
		_update_preview()
	if _manipulating():
		return
	var framing := Geometry.total_bounds(world.drawn_solids).grow(0.3)
	if phase == "preview" or mirror["enabled"]:
		for corner: Vector3 in sheet.get_corners():
			framing = framing.expand(corner)
	for point: Vector3 in rings.get_fit_points():
		framing = framing.expand(point)
	framing = framing.expand(Geometry.vector(level["goal"]) + Vector3.UP)
	framing = framing.expand(walker.position).expand(walker.position + Vector3.UP)
	camera.fit(framing, hud.get_camera_rect(), instant)
	failure_veil.position = rect.position
	failure_veil.size = rect.size

func turn_camera(direction: int) -> void:
	if _manipulating() or rings.is_active():
		return
	camera.turn(direction)
	_refresh()

func _camera_changed() -> void:
	if level.is_empty():
		return
	atmosphere.update_view(camera, envelope.get_center())
	preview_view.update_view(camera)
	rings.update_view(camera)
	_position_controls()

func _solid_hit(point: Vector2, before := INF) -> bool:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	for solid: Dictionary in world.drawn_solids:
		var hit := Queries.ray_hit(origin, direction, solid)
		if not hit.is_empty() and float(hit["distance"]) < before - 0.01:
			return true
	return false

func _ring_obstructed(point: Vector2, location: Vector3) -> bool:
	return resize_controls.blocks_point(point) or _resize_obstructed(point, location)

func _resize_obstructed(point: Vector2, location: Vector3) -> bool:
	return not play_rect.has_point(point) or hud.blocks_world_input(point) or _solid_hit(point, camera.project_ray_origin(point).distance_to(location))

func sheet_hit(point: Vector2, selected: Dictionary = {}) -> bool:
	if selected.is_empty():
		selected = _display_state()
	if not selected.has("axis") or hud.blocks_world_input(point) or resize_controls.blocks_point(point):
		return false
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var axis: int = selected["axis"]
	if absf(direction[axis]) < 0.0001:
		return false
	var distance := (float(selected["offset"]) - origin[axis]) / direction[axis]
	if distance < 0:
		return false
	var intersection := origin + direction * distance
	return sheet.contains_visible_point(intersection, selected) and not _solid_hit(point, distance)

func _position_controls() -> void:
	if level.is_empty() or play_rect.size.x < 64 or camera.busy:
		return
	hud.set_failure_marker(Vector2.ZERO, false)
	outline_accessible = false
	if phase == "preview" and preview.get("enabled", false):
		# Test whether a visible panel area is available for confirmation.
		for y: int in 9:
			for x: int in 9:
				var point := play_rect.position + play_rect.size * Vector2(float(x) / 8.0, float(y) / 8.0)
				if sheet_hit(point):
					outline_accessible = true
	hud.set_sheet_controls(PackedVector2Array(), outline_accessible)
	_position_resize_controls()

func _position_resize_controls() -> void:
	if resize_controls.is_inside_tree() and not level.is_empty():
		resize_controls.update_view(camera, play_rect, hud.get_blocking_rects(), rings.get_orb_points())

func _start_resize(value: Dictionary) -> void:
	if phase != "preview" or _manipulating() or camera.busy or not pending.is_empty() or not preview["enabled"]:
		return
	resize_key = str(value["key"])
	if resize_key not in ["width", "height"]:
		return
	resizing = true
	resize_origin = preview.duplicate(true)
	display_preview = preview.duplicate(true)
	resize_limits = MirrorRules.resize_range(resize_origin, resize_key, level["limits"])
	resize_pointer_origin = value["point"]
	var direction := MirrorRules.frame(preview).x if resize_key == "width" else MirrorRules.frame(preview).y
	var pivot: Vector3 = preview["pivot"]
	resize_screen_axis = camera.unproject_position(pivot + direction) - camera.unproject_position(pivot)
	limit_hint_shown = false
	_invalidate_prediction()
	_refresh()

func _resize_drag(point: Vector2) -> void:
	if not resizing or resize_screen_axis.length_squared() < 0.01:
		return
	var length := float(resize_origin[resize_key]) + (point - resize_pointer_origin).dot(resize_screen_axis) / resize_screen_axis.length_squared()
	var limited := clampf(length, resize_limits.x, resize_limits.y)
	if not is_equal_approx(length, limited) and not limit_hint_shown:
		hud.show_hint("Edge of the resize area.")
		limit_hint_shown = true
	_set_resize_length(limited)

func _set_resize_length(length: float) -> void:
	display_preview = MirrorRules.resized(resize_origin, resize_key, length)
	_update_preview()

func _finish_resize() -> void:
	if not resizing:
		return
	resizing = false
	translating_settle = true
	var initial := display_preview.duplicate(true)
	var length := clampf(roundf(float(initial[resize_key])), resize_limits.x, resize_limits.y)
	var target := MirrorRules.resized(resize_origin, resize_key, length)
	target["pivot"] = MirrorRules.snapped_pivot(target["pivot"], level["limits"])
	target = MirrorRules.sync(target)
	translation_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	translation_motion.tween_method(func(weight: float) -> void:
		display_preview = initial.duplicate(true)
		display_preview[resize_key] = lerpf(float(initial[resize_key]), length, weight)
		display_preview["pivot"] = (initial["pivot"] as Vector3).lerp(target["pivot"], weight)
		display_preview = MirrorRules.sync(display_preview)
		_update_preview(), 0.0, 1.0, 0.15)
	translation_motion.tween_callback(func() -> void:
		preview = display_preview.duplicate(true)
		display_preview.clear()
		resize_origin.clear()
		translating_settle = false
		_update_preview()
		_fit_camera(hud.get_play_rect()))

func _resize_to(key: String, length: float) -> void:
	if not is_finite(length) or camera.busy:
		return
	var allowed := MirrorRules.resize_range(preview, key, level["limits"])
	var limited := clampf(roundf(length), allowed.x, allowed.y)
	if not is_equal_approx(length, limited):
		hud.show_hint("Size is limited by the placement area.")
	resize_origin = preview.duplicate(true)
	resize_key = key
	resize_limits = allowed
	display_preview = MirrorRules.resized(preview, key, limited)
	resizing = true
	_finish_resize()

func _camera_motion_finished() -> void:
	_refresh()
	rings.choose_edge_ends()
	_position_resize_controls()
