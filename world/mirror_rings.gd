class_name MirrorRings
extends Node3D
## World-space rotation controls. The game owns input dispatch and state changes.

signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const RADIUS := 1.8
const SAMPLES := 96
const PICK_RADIUS := 24.0
const QUARTER_TURN := PI * 0.5
const EPSILON := 0.0001

var is_obstructed: Callable

var _state: Dictionary = {}
var _editing := false
var _busy := false
var _camera: Camera3D
var _camera_transform := Transform3D.IDENTITY
var _camera_size := 0.0
var _yaw := {}
var _pitch := {}
var _active := false
var _pointer := -2
var _drag_ring := {}
var _last_angle := 0.0
var _travel := 0.0
var _has_angle := false

var _yaw_near := MeshInstance3D.new()
var _yaw_far := MeshInstance3D.new()
var _pitch_near := MeshInstance3D.new()
var _pitch_far := MeshInstance3D.new()
var _yaw_orb := MeshInstance3D.new()
var _pitch_orb := MeshInstance3D.new()

func _ready() -> void:
	_setup_visuals()
	_refresh()

func set_state(state: Dictionary, editing: bool, busy: bool) -> void:
	_state = state.duplicate(true)
	_editing = editing
	_busy = busy
	if not _available():
		cancel()
		visible = false
		return
	visible = true
	if not _active:
		_build_rings()
		_choose_orbs()
	_refresh()

func update_view(camera: Camera3D) -> void:
	var changed := _camera != camera or not _camera_transform.is_equal_approx(camera.global_transform) or not is_equal_approx(_camera_size, camera.size)
	_camera = camera
	_camera_transform = camera.global_transform
	_camera_size = camera.size
	if _available() and not _active:
		if changed:
			_build_rings()
			_choose_orbs()
	_refresh()

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			_finish()
			return true
		return false
	if _active or _busy or not _available() or _camera == null:
		return false
	var selected := {}
	var selected_distance := INF
	for ring: Dictionary in [_yaw, _pitch]:
		if not bool(ring.get("visible", false)):
			continue
		var location: Vector3 = _ring_point(ring, float(ring["orb_angle"]))
		var distance := _camera.unproject_position(location).distance_to(point)
		if distance <= PICK_RADIUS and distance < selected_distance and not _blocked(point, location):
			selected = ring
			selected_distance = distance
	if selected.is_empty():
		return false
	_active = true
	_pointer = index
	_drag_ring = selected.duplicate(true)
	_travel = 0.0
	_has_angle = _read_angle(point, _drag_ring)
	action_requested.emit("rotation_begin", null)
	_refresh()
	return true

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	if _read_angle(point, _drag_ring):
		var delta := wrapf(_last_angle - _drag_ring["previous_angle"], -PI, PI)
		_travel += delta
		_drag_ring["previous_angle"] = _last_angle
		_drag_ring["orb_angle"] = _last_angle
		if _drag_ring["action"] == "turn":
			_yaw["orb_angle"] = _last_angle
		else:
			_pitch["orb_angle"] = _last_angle
		while absf(_travel) >= QUARTER_TURN - EPSILON:
			var direction := 1 if _travel > 0.0 else -1
			action_requested.emit(str(_drag_ring["action"]), direction)
			_travel -= direction * QUARTER_TURN
		_refresh()
	return true

func is_active() -> bool:
	return _active

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func cancel() -> void:
	if _active:
		_finish()

func get_fit_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if not _available():
		return points
	for ring: Dictionary in [_yaw, _pitch]:
		if not bool(ring.get("visible", false)):
			continue
		for step: int in 8:
			points.append(_ring_point(ring, TAU * float(step) / 8.0))
	return points

static func angular_delta(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)

static func quarter_steps(travel: float) -> int:
	return int(floor(absf(travel) / (PI * 0.5) + EPSILON)) * signi(travel)

static func ring_axes(state: Dictionary) -> Dictionary:
	var frame := Rules.frame(state)
	return {"yaw": Vector3.UP, "pitch": frame.x, "pitch_u": frame.y, "pitch_v": frame.z}

func _setup_visuals() -> void:
	if _yaw_near.get_parent():
		return
	for instance: MeshInstance3D in [_yaw_near, _yaw_far, _pitch_near, _pitch_far, _yaw_orb, _pitch_orb]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_setup_line(_yaw_near, Color(0.92, 0.98, 1.0, 0.92))
	_setup_line(_yaw_far, Color(0.55, 0.76, 0.84, 0.30))
	_setup_line(_pitch_near, Color(1.0, 0.78, 0.48, 0.96))
	_setup_line(_pitch_far, Color(0.82, 0.50, 0.32, 0.32))
	_setup_orb(_yaw_orb, Color(0.92, 0.98, 1.0, 1.0))
	_setup_orb(_pitch_orb, Color(1.0, 0.78, 0.48, 1.0))

func _setup_line(instance: MeshInstance3D, color: Color) -> void:
	instance.mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.render_priority = 96
	instance.material_override = material

func _setup_orb(instance: MeshInstance3D, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.render_priority = 97
	instance.material_override = material

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _state.has("pivot") and _state.has("axis")

func _build_rings() -> void:
	if not _available():
		return
	var frame := Rules.frame(_state)
	_yaw = _make_ring("turn", Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, int(_state["axis"]) != 1)
	_pitch = _make_ring("tilt", frame.x, frame.y, frame.z, true)

func _make_ring(action: String, axis: Vector3, vector_u: Vector3, vector_v: Vector3, shown: bool) -> Dictionary:
	return {"action": action, "center": _state["pivot"], "axis": axis.normalized(), "u": vector_u.normalized(), "v": vector_v.normalized(), "radius": RADIUS, "orb_angle": 0.0, "visible": shown}

func _choose_orbs() -> void:
	if bool(_yaw.get("visible", false)):
		_yaw["orb_angle"] = _best_orb_angle(_yaw)
	if bool(_pitch.get("visible", false)):
		var yaw_point := _camera.unproject_position(_ring_point(_yaw, float(_yaw["orb_angle"]))) if _camera and bool(_yaw.get("visible", false)) else Vector2.INF
		_pitch["orb_angle"] = _best_orb_angle(_pitch, yaw_point)

func _best_orb_angle(ring: Dictionary, avoid := Vector2.INF) -> float:
	if _camera == null:
		return 0.0
	var best := 0.0
	var score := -INF
	var fallback := 0.0
	var fallback_score := -INF
	for sample: int in 24:
		var angle := TAU * float(sample) / 24.0
		var location := _ring_point(ring, angle)
		if _camera.is_position_behind(location):
			continue
		var point := _camera.unproject_position(location)
		if not _camera.get_viewport().get_visible_rect().has_point(point) or _blocked(point, location):
			continue
		var facing: float = (location - ring["center"]).normalized().dot((_camera.global_position - ring["center"]).normalized())
		if facing > fallback_score:
			fallback_score = facing
			fallback = angle
		if avoid != Vector2.INF and point.distance_to(avoid) < PICK_RADIUS * 2.0:
			continue
		if facing > score:
			score = facing
			best = angle
	return best if score > -INF else fallback

func _refresh() -> void:
	if not _yaw_near.get_parent():
		return
	_draw_ring(_yaw, _yaw_near, _yaw_far)
	_draw_ring(_pitch, _pitch_near, _pitch_far)
	_update_orb(_yaw, _yaw_orb)
	_update_orb(_pitch, _pitch_orb)

func _draw_ring(ring: Dictionary, near: MeshInstance3D, far: MeshInstance3D) -> void:
	var shown := visible and bool(ring.get("visible", false))
	near.visible = shown
	far.visible = shown
	if not shown:
		return
	var near_mesh := near.mesh as ImmediateMesh
	var far_mesh := far.mesh as ImmediateMesh
	near_mesh.clear_surfaces()
	far_mesh.clear_surfaces()
	var near_points := PackedVector3Array()
	var far_points := PackedVector3Array()
	for step: int in SAMPLES:
		var first := _ring_point(ring, TAU * float(step) / SAMPLES)
		var second := _ring_point(ring, TAU * float(step + 1) / SAMPLES)
		if _is_near(ring, first):
			near_points.append(first)
			near_points.append(second)
		else:
			far_points.append(first)
			far_points.append(second)
	if not near_points.is_empty():
		near_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for point: Vector3 in near_points:
			near_mesh.surface_add_vertex(point)
		near_mesh.surface_end()
	if not far_points.is_empty():
		far_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for point: Vector3 in far_points:
			far_mesh.surface_add_vertex(point)
		far_mesh.surface_end()

func _update_orb(ring: Dictionary, orb: MeshInstance3D) -> void:
	orb.visible = visible and bool(ring.get("visible", false))
	if not orb.visible:
		return
	orb.global_position = _ring_point(ring, float(ring["orb_angle"]))
	var radius := 0.06
	if _camera:
		var viewport_height := maxf(1.0, _camera.get_viewport().get_visible_rect().size.y)
		radius = maxf(radius, _camera.size * 6.0 / viewport_height)
	orb.scale = Vector3.ONE * radius * 2.0

func _is_near(ring: Dictionary, location: Vector3) -> bool:
	return _camera == null or (location - ring["center"]).dot(_camera.global_position - ring["center"]) >= 0.0

func _ring_point(ring: Dictionary, angle: float) -> Vector3:
	return ring["center"] + (ring["u"] * cos(angle) + ring["v"] * sin(angle)) * float(ring["radius"])

func _read_angle(point: Vector2, ring: Dictionary) -> bool:
	var ray := _camera.project_ray_normal(point)
	var denominator := ray.dot(ring["axis"])
	var angle := 0.0
	if absf(denominator) > EPSILON:
		var origin := _camera.project_ray_origin(point)
		var distance: float = (ring["center"] - origin).dot(ring["axis"]) / denominator
		if distance < 0.0:
			return false
		var offset: Vector3 = origin + ray * distance - ring["center"]
		if offset.length_squared() < pow(float(ring["radius"]) * 0.12, 2.0):
			return false
		angle = atan2(offset.dot(ring["v"]), offset.dot(ring["u"]))
	else:
		angle = _nearest_projected_angle(point, ring)
	if not _has_angle:
		_has_angle = true
		_drag_ring["previous_angle"] = angle
		_last_angle = angle
	else:
		_last_angle = angle
	return true

func _nearest_projected_angle(point: Vector2, ring: Dictionary) -> float:
	var result := 0.0
	var distance := INF
	for sample: int in SAMPLES:
		var angle := TAU * float(sample) / SAMPLES
		var candidate := _camera.unproject_position(_ring_point(ring, angle))
		var candidate_distance := candidate.distance_squared_to(point)
		if candidate_distance < distance:
			distance = candidate_distance
			result = angle
	return result

func _blocked(point: Vector2, location: Vector3) -> bool:
	return is_obstructed.is_valid() and bool(is_obstructed.call(point, location))

func _finish() -> void:
	_active = false
	_pointer = -2
	_drag_ring.clear()
	_travel = 0.0
	_has_angle = false
	action_requested.emit("rotation_end", null)
	if _available():
		_build_rings()
		_choose_orbs()
	_refresh()
