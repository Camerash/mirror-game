extends Node3D
## Commands below are shared by HUD input, keyboard input, and replay tests.

const Geometry := preload("res://core/world_geometry.gd")
const Levels := preload("res://core/level_loader.gd")
const Navigation := preload("res://core/walk_graph.gd")
const View := preload("res://world/world_view.gd")
const Walker := preload("res://world/walker.gd")
const HUD := preload("res://ui/mirror_hud.gd")
const Handle := preload("res://world/mirror_handle.gd")
const PUZZLE_PATHS: Array[String] = ["res://levels/01_route.json", "res://levels/08_reveal.json"]
const LEVEL_PATHS: Array[String] = PUZZLE_PATHS + ["res://levels/02_partial_cut.json",
	"res://levels/03_source.json", "res://levels/04_absolute.json", "res://levels/05_restore.json",
	"res://levels/06_wall.json", "res://levels/07_horizontal.json"]

var level: Dictionary = {}
var level_index := 0
var mirror: Dictionary = {}
var preview: Dictionary = {}
var preview_origin: Dictionary = {}
var solids: Array[Dictionary] = []
var history: Array[Dictionary] = []
var phase := "play"
var status := "Tap a platform to walk. Drag the mirror handle to explore."
var style := 0
var pending: Dictionary = {}
var settle_frames := 0
var envelope := AABB()
var navigation := Navigation.new()
var world := View.new()
var walker := Walker.new()
var camera := Camera3D.new()
var goal_root := Node3D.new()
var hud := HUD.new()
var handle := Handle.new()
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
	canvas.add_child(handle)
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
	history.clear()
	pending.clear()
	phase = "play"
	dragging = false
	walker.restore(Geometry.vector(level["start"]), Vector3.ZERO)
	_commit_world()
	envelope = _level_envelope()
	for child: Node in goal_root.get_children():
		child.free()
	world.add_ring(goal_root, Geometry.vector(level["goal"]), Color("805534"))
	status = "Tap a platform to walk. Select Edit mirror to explore."
	_refresh()
	_fit_camera(hud.get_play_rect())
	return true

func _physics_process(_delta: float) -> void:
	if level.is_empty():
		return
	if not pending.is_empty():
		_execute_pending()
	if settle_frames > 0:
		settle_frames -= 1
		walker.paused = true
		return
	walker.paused = phase != "play"
	if phase != "play":
		return
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

func begin_preview() -> void:
	if phase == "preview" or phase == "failure" or not pending.is_empty():
		return
	preview = mirror.duplicate(true)
	preview_origin = _snapshot()
	walker.stop()
	walker.paused = true
	phase = "preview"
	world.draw_route(PackedVector3Array())
	_update_preview()

func change_preview(key: String, value: Variant) -> void:
	if phase != "preview":
		return
	if key == "axis" and not int(value) in level["limits"]["axes"]:
		return
	if not key in ["axis", "source", "offset", "enabled"]:
		return
	preview[key] = value
	var axis: int = preview["axis"]
	preview["offset"] = clampf(snappedf(float(preview["offset"]), 0.5),
		float(level["limits"]["min"][axis]), float(level["limits"]["max"][axis]))
	_update_preview()

func apply_preview() -> bool:
	if phase != "preview" or not pending.is_empty():
		return false
	if Geometry.embedded(walker.position, Geometry.generate(level, preview)):
		status = "A solid wall would occupy this position. Move the mirror or cancel."
		_refresh()
		return false
	pending = {"action": "apply", "mirror": preview.duplicate(true)}
	return true

func cancel_preview() -> void:
	if phase != "preview" or not pending.is_empty():
		return
	preview.clear()
	phase = "complete" if preview_origin.get("complete", false) else "play"
	world.draw_world(solids)
	status = "Preview cancelled."
	_refresh()

func undo() -> bool:
	if history.is_empty() or not pending.is_empty():
		return false
	pending = {"action": "undo", "snapshot": history.pop_back()}
	walker.paused = true
	return true

func _snapshot() -> Dictionary:
	return {"mirror": mirror.duplicate(true), "position": walker.position,
		"velocity": walker.velocity, "complete": phase == "complete"}

func _execute_pending() -> void:
	var command := pending
	pending = {}
	if command["action"] == "apply":
		history.append(preview_origin.duplicate(true))
		mirror = command["mirror"]
		phase = "play"
		status = "Mirror changed. Find your next path."
	else:
		var snapshot: Dictionary = command["snapshot"]
		mirror = snapshot["mirror"]
		walker.restore(snapshot["position"], snapshot["velocity"])
		phase = "complete" if snapshot["complete"] else "play"
		status = "Last action undone."
	preview.clear()
	_commit_world()
	_refresh()

func _commit_world() -> void:
	walker.stop()
	walker.paused = true
	solids = Geometry.generate(level, mirror)
	world.commit(solids)
	navigation.rebuild(solids)
	world.draw_route(PackedVector3Array())
	settle_frames = 2

func _update_preview() -> void:
	var proposed := Geometry.generate(level, preview)
	world.draw_world(proposed)
	if Geometry.embedded(walker.position, proposed):
		status = "Blocked · A solid wall would occupy the character's position."
	elif Geometry.supported(walker.position, proposed):
		status = "Supported · The character stays in place."
	else:
		status = "Will fall · Look for a safe landing below."
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
	handle.movable = not is_equal_approx(float(level["limits"]["min"][axis]), float(level["limits"]["max"][axis]))
	hud.display_state({"title": level["title"], "objective": level["objective"], "phase": phase,
		"level_index": level_index, "can_advance": _can_advance(),
		"status": status, "editing": phase == "preview", "enabled": selected["enabled"],
		"offset": selected["offset"], "axis": axis, "source": selected["source"],
		"min_offset": level["limits"]["min"][axis], "max_offset": level["limits"]["max"][axis],
		"allowed_axes": level["limits"]["axes"], "can_undo": not history.is_empty(),
		"can_apply": phase == "preview" and not Geometry.embedded(walker.position, Geometry.generate(level, selected)),
		"is_test": level.get("is_test", false), "style": style, "collision": world.debug_collision})
	world.show_boundary(selected, envelope, style, phase == "preview")
	_position_handle()

func _action(action: String, value: Variant) -> void:
	match action:
		"select_level": load_level(int(value))
		"next_level": advance_level()
		"edit":
			if phase == "preview": cancel_preview()
			else: begin_preview()
		"enabled": change_preview("enabled", bool(value))
		"step": change_preview("offset", float(preview.get("offset", 0)) + float(value))
		"axis": change_preview("axis", int(value))
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
			KEY_M: _action("edit", null)
			KEY_ENTER: apply_preview()
			KEY_ESCAPE: cancel_preview()
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
	if point.distance_to(handle.position + Vector2(28, 28)) <= 30:
		begin_preview()
		if phase != "preview":
			return
		if not handle.movable:
			get_viewport().set_input_as_handled()
			return
		dragging = true
		drag_touch = touch
		drag_origin = point
		drag_offset = float(preview["offset"])
		var anchor := _handle_world_position()
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

func _level_envelope() -> AABB:
	var bounds := Geometry.total_bounds(solids)
	for axis: int in level["limits"]["axes"]:
		for offset: float in [float(level["limits"]["min"][axis]), float(level["limits"]["max"][axis])]:
			for source: int in [1, -1]:
				var configuration := {"enabled": true, "axis": axis, "offset": offset, "source": source}
				bounds = bounds.merge(Geometry.total_bounds(Geometry.generate(level, configuration)))
	bounds = bounds.expand(Geometry.vector(level["start"]) + Vector3.UP)
	return bounds.expand(Geometry.vector(level["goal"]) + Vector3.UP).grow(0.3)

func _fit_camera(rect: Rect2) -> void:
	play_rect = rect
	if level.is_empty() or rect.size.x < 10 or rect.size.y < 10:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var direction := Vector3(0.612372, 0.5, 0.612372)
	var centre := envelope.get_center()
	camera.position = centre + direction * 30
	camera.look_at(centre)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index: int in range(8):
		var corner := camera.global_basis.inverse() * (envelope.get_endpoint(index) - centre)
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var extent := high - low
	var pixels_per_unit := minf(maxf(10, rect.size.x - 70) / extent.x, maxf(10, rect.size.y - 70) / extent.y)
	camera.size = viewport_size.y / pixels_per_unit
	var offset := rect.get_center() - viewport_size * 0.5
	camera.position -= camera.global_basis.x * offset.x / pixels_per_unit
	camera.position += camera.global_basis.y * offset.y / pixels_per_unit
	failure_veil.position = rect.position
	failure_veil.size = rect.size
	_position_handle()

func _handle_world_position() -> Vector3:
	var selected := preview if phase == "preview" else mirror
	var anchor := envelope.get_center()
	anchor.y = maxf(0.6, envelope.end.y - 0.3)
	anchor[int(selected["axis"])] = float(selected["offset"])
	return anchor

func _position_handle() -> void:
	if mirror.is_empty() or play_rect.size.x < 64:
		return
	var projected := camera.unproject_position(_handle_world_position())
	projected = projected.clamp(play_rect.position + Vector2(32, 32), play_rect.end - Vector2(32, 32))
	handle.position = projected - Vector2(28, 28)
	handle.editing = phase == "preview"
	handle.visible = phase in ["play", "preview", "complete"]
	handle.queue_redraw()
