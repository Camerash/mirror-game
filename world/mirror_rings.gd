class_name MirrorRings
extends Node3D
## World-space rotation controls. The game owns input dispatch and state changes.

signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const SAMPLES := 96
const PICK_RADIUS := 24.0
const KNOB_RADIUS_PIXELS := 16.0
const KNOB_OUTLINE_PIXELS := 2.5
const EDGE_GAP := 0.35
const QUARTER_TURN := PI * 0.5
const EPSILON := 0.0001

var is_obstructed: Callable

var _state: Dictionary = {}
var _editing := false
var _busy := false
var _camera: Camera3D
var _camera_transform := Transform3D.IDENTITY
var _camera_size := 0.0
var _pose := Transform3D.IDENTITY
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
	var previous_yaw_sign := int(_yaw.get("edge_sign", 0))
	var previous_pitch_sign := int(_pitch.get("edge_sign", 0))
	_state = state.duplicate(true)
	_editing = editing
	_busy = busy
	if not _available():
		cancel()
		visible = false
		return
	visible = true
	if not _active:
		_build_rings(previous_yaw_sign, previous_pitch_sign)
		if not _busy:
			_choose_inaccessible_edges()
		_refresh()

func set_pose(pose: Transform3D) -> void:
	if _pose.is_equal_approx(pose):
		return
	_pose = pose
	if _available():
		var yaw_sign := int(_yaw.get("edge_sign", 0))
		var pitch_sign := int(_pitch.get("edge_sign", 0))
		_build_rings(yaw_sign, pitch_sign)
		_refresh()

func update_view(camera: Camera3D) -> void:
	var changed := _camera != camera or not _camera_transform.is_equal_approx(camera.global_transform) or not is_equal_approx(_camera_size, camera.size)
	_camera = camera
	_camera_transform = camera.global_transform
	_camera_size = camera.size
	if _available() and not _active:
		if changed:
			_build_rings(int(_yaw.get("edge_sign", 0)), int(_pitch.get("edge_sign", 0)))
	_refresh()

func choose_edge_ends() -> void:
	if _active or not _available():
		return
	for ring: Dictionary in [_yaw, _pitch]:
		if bool(ring.get("visible", false)):
			ring["edge_sign"] = _choose_edge_sign(ring)
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
		var location := _orb_point(ring)
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
	action_requested.emit("rotation_begin", {"kind": _drag_ring["action"], "axis": _drag_ring["axis"]})
	_refresh()
	return true

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	if _read_angle(point, _drag_ring):
		var delta := wrapf(_last_angle - _drag_ring["previous_angle"], -PI, PI)
		_travel += delta
		_drag_ring["previous_angle"] = _last_angle
		action_requested.emit("rotation_angle", _travel)
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

func get_orb_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _camera == null or not _available():
		return points
	for ring: Dictionary in [_yaw, _pitch]:
		if bool(ring.get("visible", false)):
			points.append(_camera.unproject_position(_orb_point(ring)))
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
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 96
	instance.material_override = material

func _setup_orb(instance: MeshInstance3D, color: Color) -> void:
	instance.mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 97
	instance.material_override = material

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _state.has("pivot") and _state.has("axis")

func _build_rings(yaw_sign := 0, pitch_sign := 0) -> void:
	if not _available():
		return
	var pose := _resolved_pose()
	var width := float(_state.get("width", 3.0))
	var height := float(_state.get("height", 3.0))
	_yaw = _make_ring("turn", Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, width * 0.5, pose.basis.x, yaw_sign, not Rules.horizontal(_state))
	_pitch = _make_ring("tilt", pose.basis.x, pose.basis.y, pose.basis.z, height * 0.5, pose.basis.y, pitch_sign, true)

func _make_ring(action: String, axis: Vector3, vector_u: Vector3, vector_v: Vector3, radius: float, edge: Vector3, edge_sign: int, shown: bool) -> Dictionary:
	var gap := _edge_gap(_resolved_pose().origin, edge.normalized(), radius)
	return {"action": action, "center": _resolved_pose().origin, "axis": axis.normalized(), "u": vector_u.normalized(), "v": vector_v.normalized(), "radius": radius + gap, "edge": edge.normalized(), "edge_sign": edge_sign if edge_sign != 0 else 1, "visible": shown}

func _edge_gap(center: Vector3, edge: Vector3, half_extent: float) -> float:
	var gap := EDGE_GAP
	if _camera == null:
		return gap
	for sign: float in [-1.0, 1.0]:
		var anchor := center + edge * half_extent * sign
		if _camera.is_position_behind(anchor):
			continue
		while gap < 8.0:
			var knob := center + edge * (half_extent + gap) * sign
			if not _camera.is_position_behind(knob) and _camera.unproject_position(anchor).distance_to(_camera.unproject_position(knob)) >= PICK_RADIUS * 2.0:
				break
			gap += 0.1
	return gap

func _choose_inaccessible_edges() -> void:
	for ring: Dictionary in [_yaw, _pitch]:
		if bool(ring.get("visible", false)) and not _edge_accessible(ring, int(ring["edge_sign"])):
			ring["edge_sign"] = _choose_edge_sign(ring)

func _choose_edge_sign(ring: Dictionary) -> int:
	if _edge_accessible(ring, int(ring["edge_sign"])):
		return int(ring["edge_sign"])
	var opposite := -int(ring["edge_sign"])
	return opposite if _edge_accessible(ring, opposite) else int(ring["edge_sign"])

func _edge_accessible(ring: Dictionary, edge_sign: int) -> bool:
	if _camera == null:
		return true
	var location: Vector3 = ring["center"] + ring["edge"] * float(ring["radius"]) * edge_sign
	var point := _camera.unproject_position(location)
	return not _camera.is_position_behind(location) and _camera.get_viewport().get_visible_rect().has_point(point) and not _blocked(point, location)

func _resolved_pose() -> Transform3D:
	if _pose != Transform3D.IDENTITY or not _state.has("pivot"):
		return _pose
	return Transform3D(Rules.frame(_state), _state["pivot"])

func _refresh() -> void:
	if not _yaw_near.get_parent():
		return
	var yaw := _captured_radius(_yaw)
	var pitch := _captured_radius(_pitch)
	_draw_ring(yaw, _yaw_near, _yaw_far)
	_draw_ring(pitch, _pitch_near, _pitch_far)
	_update_orb(yaw, _yaw_orb)
	_update_orb(pitch, _pitch_orb)

func _captured_radius(ring: Dictionary) -> Dictionary:
	if _active and ring["action"] == _drag_ring.get("action", ""):
		var result := ring.duplicate(true)
		result["radius"] = _drag_ring["radius"]
		return result
	return ring

func _draw_ring(ring: Dictionary, near: MeshInstance3D, far: MeshInstance3D) -> void:
	var shown: bool = visible and bool(ring.get("visible", false)) and ((_active and ring["action"] == _drag_ring.get("action", "")) or (not _active and not _busy))
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
	orb.visible = visible and bool(ring.get("visible", false)) and ((_active and ring["action"] == _drag_ring.get("action", "")) or (not _active and not _busy))
	if not orb.visible:
		return
	var radius := 0.06
	var outline := 0.01
	if _camera:
		var viewport_height := maxf(1.0, _camera.get_viewport().get_visible_rect().size.y)
		radius = maxf(radius, _camera.size * KNOB_RADIUS_PIXELS / viewport_height)
		outline = _camera.size * KNOB_OUTLINE_PIXELS / viewport_height
		orb.global_transform = Transform3D(_camera.global_transform.basis, _orb_point(ring))
	else:
		orb.global_position = _orb_point(ring)
	var mesh := orb.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := maxf(0.001, radius - outline)
	for step: int in 16:
		var first := TAU * float(step) / 16.0
		var second := TAU * float(step + 1) / 16.0
		var outer_first := Vector3(cos(first) * radius, sin(first) * radius, 0.0)
		var outer_second := Vector3(cos(second) * radius, sin(second) * radius, 0.0)
		var inner_first := Vector3(cos(first) * inner, sin(first) * inner, 0.0)
		var inner_second := Vector3(cos(second) * inner, sin(second) * inner, 0.0)
		mesh.surface_add_vertex(outer_first)
		mesh.surface_add_vertex(outer_second)
		mesh.surface_add_vertex(inner_first)
		mesh.surface_add_vertex(inner_first)
		mesh.surface_add_vertex(outer_second)
		mesh.surface_add_vertex(inner_second)
	mesh.surface_end()

func _is_near(ring: Dictionary, location: Vector3) -> bool:
	return _camera == null or (location - ring["center"]).dot(_camera.global_position - ring["center"]) >= 0.0

func _ring_point(ring: Dictionary, angle: float) -> Vector3:
	return ring["center"] + (ring["u"] * cos(angle) + ring["v"] * sin(angle)) * float(ring["radius"])

func _orb_point(ring: Dictionary) -> Vector3:
	return ring["center"] + ring["edge"] * float(ring["radius"]) * int(ring["edge_sign"])

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
		_build_rings(int(_yaw.get("edge_sign", 0)), int(_pitch.get("edge_sign", 0)))
	_refresh()
