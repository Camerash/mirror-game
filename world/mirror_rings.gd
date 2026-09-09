class_name MirrorRings
extends Node3D
## Screen-space rotation arcs. Input stays with the game controller.

signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const ARC_RADIUS := 64.0
const HIT_HALF_WIDTH := 24.0
const CENTRE_DEAD_ZONE := 12.0
const ARC_SEPARATION := 128.0

class ArcOverlay extends Control:
	var arcs: Array[Dictionary] = []
	var active_kind := ""
	var snap_radians := 0.0

	func _draw() -> void:
		for arc: Dictionary in arcs:
			if not bool(arc["visible"]):
				continue
			var color := Color("d9f5ff") if arc["kind"] == "turn" else Color("ffc77e")
			_draw_arc(arc, color)
			_draw_marker(arc, color)
			if active_kind == arc["kind"] and snap_radians > 0.0:
				_draw_ticks(arc, color)

	func _draw_arc(arc: Dictionary, color: Color) -> void:
		var points := PackedVector2Array()
		for step: int in 25:
			var angle := lerpf(float(arc["start"]), float(arc["end"]), float(step) / 24.0)
			points.append(arc["center"] + Vector2(cos(angle), sin(angle)) * ARC_RADIUS)
		draw_polyline(points, color, 3.0, true)

	func _draw_ticks(arc: Dictionary, color: Color) -> void:
		var first := ceilf(float(arc["start"]) / snap_radians) * snap_radians
		for angle: float in _angles(first, float(arc["end"])):
			var direction := Vector2(cos(angle), sin(angle))
			draw_line(arc["center"] + direction * (ARC_RADIUS - 5.0), arc["center"] + direction * (ARC_RADIUS + 5.0), color, 2.0, true)

	func _draw_marker(arc: Dictionary, color: Color) -> void:
		# A half arc represents each cyclic angle twice, one half turn apart.
		var angle: float = arc["marker_angle"]
		draw_circle(arc["center"] + Vector2(cos(angle), sin(angle)) * ARC_RADIUS, 4.0, color)

	func _angles(first: float, last: float) -> Array[float]:
		var result: Array[float] = []
		var angle := first
		while angle <= last + 0.001:
			result.append(angle)
			angle += snap_radians
		return result

var _state: Dictionary = {}
var _editing := false
var _busy := false
var _camera: Camera3D
var _pose := Transform3D.IDENTITY
var _safe_rect := Rect2()
var _excluded: Array[Rect2] = []
var _snap_radians := 0.0
var _arcs: Array[Dictionary] = []
var _active := false
var _pointer := -2
var _drag: Dictionary = {}
var _last_angle := 0.0
var _travel := 0.0
var _canvas := CanvasLayer.new()
var _overlay := ArcOverlay.new()

func _ready() -> void:
	_canvas.layer = 2
	add_child(_canvas)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_overlay)
	_refresh()

func set_state(state: Dictionary, editing: bool, busy: bool) -> void:
	_state = state.duplicate(true)
	_editing = editing
	_busy = busy
	if not _available():
		cancel()
	if not _active:
		_relayout()
	_refresh()

func set_pose(pose: Transform3D) -> void:
	_pose = pose
	if not _active:
		_relayout()
	_refresh()

func set_layout(safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	_safe_rect = safe_rect
	_excluded = excluded.duplicate()
	if not _active:
		_relayout()
	_refresh()

func set_snap(step_degrees: float) -> void:
	_snap_radians = deg_to_rad(maxf(0.0, step_degrees))
	_refresh()

func update_view(camera: Camera3D) -> void:
	_camera = camera
	if not _active:
		_relayout()
	_refresh()

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			_finish()
			return true
		return false
	if _active or _busy or not _available():
		return false
	for arc: Dictionary in _arcs:
		if bool(arc["visible"]) and _contains(arc, point):
			_active = true
			_pointer = index
			_drag = arc.duplicate(true)
			_last_angle = _pointer_angle(point, _drag)
			_travel = 0.0
			action_requested.emit("rotation_begin", {"kind": _drag["kind"], "axis": _drag["axis"]})
			_refresh()
			return true
	return false

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	if point.distance_to(_drag["center"]) < CENTRE_DEAD_ZONE:
		return true
	var angle := _pointer_angle(point, _drag)
	_travel += angular_delta(_last_angle, angle)
	_last_angle = angle
	action_requested.emit("rotation_angle", _travel)
	return true

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func is_active() -> bool:
	return _active

func cancel() -> void:
	if _active:
		_finish()

func blocks_point(point: Vector2) -> bool:
	for arc: Dictionary in _arcs:
		if bool(arc["visible"]) and _contains(arc, point):
			return true
	return false

func choose_edge_ends() -> void:
	pass

func get_fit_points() -> PackedVector3Array:
	return PackedVector3Array()

func get_orb_points() -> PackedVector2Array:
	return PackedVector2Array()

func get_arc_points(kind: String) -> PackedVector2Array:
	for arc: Dictionary in _arcs:
		if arc["kind"] == kind and bool(arc["visible"]):
			return get_arc_points_for(arc)
	return PackedVector2Array()

func get_control_rects() -> Dictionary:
	var result := {}
	for arc: Dictionary in _arcs:
		if not bool(arc["visible"]):
			continue
		var rect := Rect2()
		var first := true
		for point: Vector2 in get_arc_points(arc["kind"]):
			rect = Rect2(point, Vector2.ZERO) if first else rect.expand(point)
			first = false
		result[arc["kind"]] = rect.grow(HIT_HALF_WIDTH)
	return result

static func angular_delta(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _state.has("pivot") and _state.has("axis")

func _relayout() -> void:
	if not _available() or _camera == null:
		_arcs.clear()
		return
	var pivot: Vector3 = _pose.origin if _pose != Transform3D.IDENTITY else _state["pivot"]
	var desired := _camera.unproject_position(pivot)
	var safe := _safe_rect
	if safe.size == Vector2.ZERO:
		safe = _camera.get_viewport().get_visible_rect()
	var anchor := _best_anchor(desired, safe)
	var frame := Rules.frame(_state)
	_arcs = [
		{"kind": "turn", "axis": Vector3.UP, "center": anchor, "start": 0.0, "end": PI, "visible": not Rules.horizontal(_state)},
		{"kind": "tilt", "axis": frame.x, "center": anchor + Vector2(ARC_SEPARATION, 0.0), "start": -PI * 0.5, "end": PI * 0.5, "visible": true},
	]
	for arc: Dictionary in _arcs:
		arc["visible"] = bool(arc["visible"]) and _arc_allowed(arc, safe)

func _best_anchor(desired: Vector2, safe: Rect2) -> Vector2:
	var bounds := Rect2(Vector2(-ARC_RADIUS - HIT_HALF_WIDTH, -ARC_RADIUS - HIT_HALF_WIDTH), Vector2(ARC_SEPARATION + (ARC_RADIUS + HIT_HALF_WIDTH) * 2.0, (ARC_RADIUS + HIT_HALF_WIDTH) * 2.0))
	var base := Vector2(
		clampf(desired.x, safe.position.x - bounds.position.x, safe.end.x - bounds.end.x),
		clampf(desired.y, safe.position.y - bounds.position.y, safe.end.y - bounds.end.y))
	var best := base
	var best_score := INF
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT * 96.0, Vector2.RIGHT * 96.0, Vector2.UP * 96.0, Vector2.DOWN * 96.0]:
		var candidate := Vector2(
			clampf(base.x + offset.x, safe.position.x - bounds.position.x, safe.end.x - bounds.end.x),
			clampf(base.y + offset.y, safe.position.y - bounds.position.y, safe.end.y - bounds.end.y))
		var rect := Rect2(candidate + bounds.position, bounds.size)
		var score := candidate.distance_squared_to(desired)
		for excluded: Rect2 in _excluded:
			if rect.intersects(excluded):
				score += 1000000.0
		if score < best_score:
			best = candidate
			best_score = score
	return best

func _contains(arc: Dictionary, point: Vector2) -> bool:
	if not _point_allowed(point):
		return false
	var offset: Vector2 = point - arc["center"]
	if absf(offset.length() - ARC_RADIUS) > HIT_HALF_WIDTH:
		return false
	var angle := _pointer_angle(point, arc)
	return angle >= float(arc["start"]) - 0.001 and angle <= float(arc["end"]) + 0.001

func _pointer_angle(point: Vector2, arc: Dictionary) -> float:
	var offset: Vector2 = point - arc["center"]
	return atan2(offset.y, offset.x)

func _point_allowed(point: Vector2) -> bool:
	if _safe_rect.size != Vector2.ZERO and not _safe_rect.has_point(point):
		return false
	for excluded: Rect2 in _excluded:
		if excluded.has_point(point):
			return false
	return true

func _arc_allowed(arc: Dictionary, safe: Rect2) -> bool:
	var rect := _arc_rect(arc)
	if not safe.encloses(rect):
		return false
	for excluded: Rect2 in _excluded:
		if rect.intersects(excluded):
			return false
	return true

func _arc_rect(arc: Dictionary) -> Rect2:
	var points := get_arc_points_for(arc)
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect.grow(HIT_HALF_WIDTH)

func get_arc_points_for(arc: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in 25:
		var angle := lerpf(float(arc["start"]), float(arc["end"]), float(step) / 24.0)
		points.append(arc["center"] + Vector2(cos(angle), sin(angle)) * ARC_RADIUS)
	return points

func _refresh() -> void:
	if not is_instance_valid(_overlay):
		return
	for arc: Dictionary in _arcs:
		var target := float(_state.get("yaw" if arc["kind"] == "turn" else "pitch", 0.0))
		arc["marker_angle"] = float(arc["start"]) + fposmod(target - float(arc["start"]), PI)
		arc["visible"] = _available() and (not _busy or _active) and (not _active or arc["kind"] == _drag.get("kind", "")) and bool(arc["visible"])
	_overlay.arcs = _arcs
	_overlay.active_kind = str(_drag.get("kind", "")) if _active else ""
	_overlay.snap_radians = _snap_radians
	_overlay.queue_redraw()

func _finish() -> void:
	_active = false
	_pointer = -2
	_drag.clear()
	_travel = 0.0
	action_requested.emit("rotation_end", null)
	_relayout()
	_refresh()
