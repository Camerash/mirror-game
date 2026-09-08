extends Node3D
## Commands below are shared by HUD input, keyboard input, and replay tests.

const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const Navigation := preload("res://core/walk_graph.gd")
const View := preload("res://world/world_view.gd")
const Walker := preload("res://world/walker.gd")
const HUD := preload("res://ui/mirror_hud.gd")
const Predictor := preload("res://world/fall_predictor.gd")
const PreviewView := preload("res://world/preview_view.gd")
const Atmosphere := preload("res://world/atmosphere.gd")
const Sheet := preload("res://world/mirror_sheet.gd")
const MirrorRules := preload("res://core/mirror_state.gd")
const StageCameraView := preload("res://world/stage_camera.gd")
const PUZZLE_PATHS: Array[String] = ["res://levels/01_route.json", "res://levels/08_reveal.json"]
const LEVEL_PATHS: Array[String] = PUZZLE_PATHS + ["res://levels/02_partial_cut.json",
	"res://levels/03_source.json", "res://levels/04_absolute.json", "res://levels/05_restore.json",
	"res://levels/06_wall.json", "res://levels/07_horizontal.json", "res://levels/09_movement.json"]

var level: Dictionary = {}
var level_index := 0
var mirror: Dictionary = {}
var preview: Dictionary = {}
var preview_origin: Dictionary = {}
var sheet := Sheet.new()
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
var drag_offset := 0.0
var drag_axis := Vector2.ZERO
var drag_touch := -1

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
	load_level(0)
	_fit_camera(hud.get_play_rect())

func _setup_scene() -> void:
	add_child(world)
	add_child(predictor)
	add_child(preview_view)
	add_child(atmosphere)
	add_child(sheet)
	sheet.transition_finished.connect(_refresh)
	camera.view_changed.connect(_camera_changed)
	camera.motion_finished.connect(_refresh)
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
	level = loaded
	level_index = index
	mirror = level["mirror"].duplicate(true)
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
	envelope = _level_envelope()
	atmosphere.set_bounds(Geometry.total_bounds(solids))
	for child: Node in goal_root.get_children():
		child.free()
	world.add_ring(goal_root, Geometry.vector(level["goal"]), Color("805534"))
	status = "Tap a platform to walk. Enable the mirror to find another path."
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
	if not can_edit():
		return
	preview_origin = _snapshot()
	preview = mirror.duplicate(true)
	preview["enabled"] = true
	walker.paused = true
	phase = "preview"
	world.draw_route(PackedVector3Array())
	_update_preview()
	_fit_camera(hud.get_play_rect())

func change_preview(key: String, value: Variant) -> void:
	if phase != "preview" or not pending.is_empty():
		return
	var previous := preview.duplicate(true)
	if key not in ["axis", "source", "offset", "enabled"]:
		return
	if key == "axis":
		if int(value) not in [0, 1, 2] or int(value) == int(preview["axis"]):
			return
		preview["axis"] = int(value)
		preview["offset"] = preview["pivot"][int(value)]
	else:
		preview[key] = value
	var axis: int = preview["axis"]
	preview["offset"] = clampf(snappedf(float(preview["offset"]), 0.5),
		float(level["limits"]["min"][axis]), float(level["limits"]["max"][axis]))
	var pivot: Vector3 = preview["pivot"]
	pivot[axis] = float(preview["offset"])
	preview["pivot"] = pivot
	if axis != 1:
		preview["vertical_axis"] = axis
		preview["vertical_source"] = preview["source"]
	if preview != previous:
		_update_preview()
		if key == "axis":
			_fit_camera(hud.get_play_rect())

func rotate_mirror(direction: int) -> void:
	if phase != "preview" or sheet.is_transitioning() or not pending.is_empty():
		return
	preview = MirrorRules.turn(preview, direction)
	_update_preview()
	_fit_camera(hud.get_play_rect())

func tilt_mirror() -> void:
	if phase != "preview" or sheet.is_transitioning() or not pending.is_empty():
		return
	preview = MirrorRules.tilt(preview)
	_update_preview()
	_fit_camera(hud.get_play_rect())

func apply_preview() -> bool:
	if phase != "preview" or not pending.is_empty() or sheet.is_transitioning() or camera.busy:
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
	var command := pending
	pending = {}
	if command["action"] == "apply":
		history.append(preview_origin.duplicate(true))
		mirror = command["mirror"]
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

func _update_preview() -> void:
	var proposed := Geometry.generate(level, preview)
	world.draw_world(proposed)
	atmosphere.set_bounds(Geometry.total_bounds(proposed))
	preview_view.clear()
	prediction = {"status": "pending"}
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
	var selected := preview if phase == "preview" else mirror
	var axis: int = selected["axis"]
	sheet.set_state(selected, _sheet_bounds(), phase == "preview")
	edit_available = can_edit()
	hud.display_state({"title": level["title"], "objective": level["objective"], "phase": phase,
		"level_index": level_index, "can_advance": _can_advance(),
		"can_edit": can_edit(), "standing_only": standing_only,
		"camera_busy": camera.busy or dragging, "mirror_busy": sheet.is_transitioning(),
		"status": status, "editing": phase == "preview", "enabled": selected["enabled"],
		"offset": selected["offset"], "axis": axis, "source": selected["source"],
		"min_offset": level["limits"]["min"][axis], "max_offset": level["limits"]["max"][axis],
		"allowed_axes": level["limits"]["axes"], "can_undo": not history.is_empty(),
		"can_apply": phase == "preview" and pending.is_empty() and not sheet.is_transitioning() and not camera.busy and prediction["status"] in ["supported", "landing", "failure"],
		"is_test": level.get("is_test", false), "style": style, "collision": world.debug_collision})
	world.show_contacts(Geometry.reflection_contacts(level, selected) if phase == "preview" else [])
	atmosphere.set_mirror(selected, phase == "preview", style)
	_position_controls()

func _action(action: String, value: Variant) -> void:
	match action:
		"select_level": load_level(int(value))
		"next_level": advance_level()
		"edit": begin_preview()
		"standing_only":
			standing_only = bool(value)
			_refresh()
		"enabled": change_preview("enabled", bool(value))
		"step": change_preview("offset", float(preview.get("offset", 0)) + float(value))
		"axis": change_preview("axis", int(value))
		"turn": rotate_mirror(int(value))
		"tilt": tilt_mirror()
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
			KEY_Z: undo()
			KEY_R: load_level(level_index)
			KEY_BRACKETLEFT: _action("step", -0.5)
			KEY_BRACKETRIGHT: _action("step", 0.5)
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.position, event.pressed, -1)
	elif event is InputEventScreenTouch:
		_pointer(event.position, event.pressed, event.index)
	elif event is InputEventMouseMotion and dragging and drag_touch == -1:
		_drag(event.position)
	elif event is InputEventScreenDrag and dragging and event.index == drag_touch:
		_drag(event.position)

func _input(event: InputEvent) -> void:
	# Keep ownership of a drag until release, even when it crosses the HUD.
	if not dragging:
		return
	if event is InputEventMouseButton and drag_touch == -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == drag_touch:
		if not event.pressed:
			dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_touch == -1:
		_drag(event.position)
	elif event is InputEventScreenDrag and event.index == drag_touch:
		_drag(event.position)

func _pointer(point: Vector2, pressed: bool, touch: int) -> void:
	if not pressed:
		if drag_touch == touch:
			dragging = false
		return
	if dragging or not play_rect.has_point(point):
		return
	if hud.blocks_world_input(point) or camera.busy:
		return
	if phase == "preview":
		if sheet.is_transitioning() or not sheet_hit(point) or is_equal_approx(float(level["limits"]["min"][int(preview["axis"])]), float(level["limits"]["max"][int(preview["axis"])])):
			return
		dragging = true
		drag_touch = touch
		drag_origin = point
		drag_offset = float(preview["offset"])
		var anchor: Vector3 = preview["pivot"]
		var direction := Vector3.ZERO
		direction[int(preview["axis"])] = 1.0
		drag_axis = camera.unproject_position(anchor + direction) - camera.unproject_position(anchor)
		get_viewport().set_input_as_handled()
	elif phase == "play":
		var query := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(point),
			camera.project_ray_origin(point) + camera.project_ray_normal(point) * 100, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.9:
			request_walk(hit["position"])
		else:
			status = "Tap the top of a connected platform."
			_refresh()

func _drag(point: Vector2) -> void:
	if drag_axis.length_squared() > 0.01:
		change_preview("offset", drag_offset + (point - drag_origin).dot(drag_axis) / drag_axis.length_squared())
	get_viewport().set_input_as_handled()

func _level_envelope(axes: Array = [0, 1, 2]) -> AABB:
	var bounds := Geometry.total_bounds(Geometry.generate(level, level["mirror"]))
	for axis: int in axes:
		for offset: float in [float(level["limits"]["min"][axis]), float(level["limits"]["max"][axis])]:
			for source: int in [1, -1]:
				var configuration := {"enabled": true, "axis": axis, "offset": offset, "source": source}
				bounds = bounds.merge(Geometry.total_bounds(Geometry.generate(level, configuration)))
	bounds = bounds.expand(Geometry.vector(level["start"]) + Vector3.UP)
	return bounds.expand(Geometry.vector(level["goal"]) + Vector3.UP).grow(0.3)

func _sheet_bounds() -> AABB:
	var selected := preview if phase == "preview" else mirror
	var bounds := _level_envelope([int(selected["axis"])]).grow(0.5)
	if int(selected["axis"]) != 1:
		bounds.size.y += 1.0
	return bounds

func _fit_camera(rect: Rect2, instant := false) -> void:
	play_rect = rect
	if level.is_empty() or rect.size.x < 10 or rect.size.y < 10:
		return
	var framing := _sheet_bounds() if phase == "preview" or mirror["enabled"] else Geometry.total_bounds(solids).grow(0.3)
	framing = framing.expand(Geometry.vector(level["goal"]) + Vector3.UP)
	framing = framing.expand(walker.position).expand(walker.position + Vector3.UP)
	camera.fit(framing, hud.get_camera_rect(), instant)
	failure_veil.position = rect.position
	failure_veil.size = rect.size

func turn_camera(direction: int) -> void:
	if dragging:
		return
	camera.turn(direction)
	_refresh()

func _camera_changed() -> void:
	if level.is_empty():
		return
	atmosphere.update_view(camera, envelope.get_center())
	preview_view.update_view(camera)
	_position_controls()

func sheet_hit(point: Vector2) -> bool:
	if hud.blocks_world_input(point):
		return false
	var ray_origin := camera.project_ray_origin(point)
	var ray_direction := camera.project_ray_normal(point)
	var axis: int = preview["axis"]
	if absf(ray_direction[axis]) < 0.0001:
		return false
	var distance := (float(preview["offset"]) - ray_origin[axis]) / ray_direction[axis]
	if distance < 0:
		return false
	var intersection := ray_origin + ray_direction * distance
	var sheet_bounds: AABB = sheet.drawn_bounds
	for tangent: int in range(3):
		if tangent != axis and (intersection[tangent] < sheet_bounds.position[tangent] or intersection[tangent] > sheet_bounds.end[tangent]):
			return false
	# Preview meshes differ from committed collision. Test against drawn bounds.
	for solid: Dictionary in world.drawn_solids:
		var hit: Variant = (solid["bounds"] as AABB).intersects_ray(ray_origin, ray_direction)
		if hit != null and ray_origin.distance_to(hit) < distance - 0.01:
			return false
	return true

func _position_controls() -> void:
	if mirror.is_empty() or play_rect.size.x < 64:
		return
	var selected := preview if phase == "preview" else mirror
	var projected := camera.unproject_position(selected["pivot"])
	projected = projected.clamp(play_rect.position + Vector2(32, 32), play_rect.end - Vector2(32, 32))
	hud.set_failure_marker(camera.unproject_position(prediction.get("position", walker.position)), phase == "preview" and prediction["status"] == "failure")
	var avoid := PackedVector2Array([projected, camera.unproject_position(walker.position + Vector3.UP * 0.4), camera.unproject_position(Geometry.vector(level["goal"]))])
	for solid: Dictionary in world.drawn_solids:
		var bounds: AABB = solid["bounds"]
		avoid.append(camera.unproject_position(Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)))
	hud.set_mirror_anchor(projected, avoid)
