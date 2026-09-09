class_name MirrorRings
extends Node3D
## World-aligned rings projected for constant line width and touch size.
signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const GAP := 0.35
const MIN_PIXEL_RADIUS := 48.0
const HIT_HALF_WIDTH := 24.0
const SAMPLES := 48
const EDGE_ON_RATIO := 0.15

class RingOverlay extends Control:
	var strokes: Array[Dictionary] = []
	func _draw() -> void:
		for stroke: Dictionary in strokes:
			draw_line(stroke["a"], stroke["b"], stroke["color"], stroke["width"], true)

var _state: Dictionary = {}
var _editing := false
var _busy := false
var _camera: Camera3D
var _pose := Transform3D.IDENTITY
var _has_pose := false
var _safe_rect := Rect2()
var _excluded: Array[Rect2] = []
var _arcs: Array[Dictionary] = []
var _active := false
var _pointer := -2
var _drag: Dictionary = {}
var _last_angle := 0.0
var _travel := 0.0
var _press := Vector2.ZERO
var _canvas := CanvasLayer.new()
var _overlay := RingOverlay.new()

func _ready() -> void:
	_canvas.layer = 2
	add_child(_canvas)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)

func set_state(state: Dictionary, editing: bool, busy: bool) -> void:
	_state = state.duplicate(true)
	_editing = editing
	_busy = busy
	if not _available(): cancel()
	_update()

func set_pose(pose: Transform3D) -> void:
	_pose = pose
	_has_pose = true
	_update()

func set_layout(safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	_safe_rect = safe_rect
	_excluded = excluded.duplicate()
	_update()

func update_view(camera: Camera3D) -> void:
	_camera = camera
	_update()

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _state.has("pivot")

func _update() -> void:
	if not _active:
		_arcs.clear()
		if _available() and _camera:
			var frame := _pose.basis if _has_pose else Rules.frame(_state)
			if not Rules.horizontal(_state):
				_arcs.append(_ring("turn", Vector3.UP, Vector3.RIGHT, float(_state.get("width", 3))))
			_arcs.append(_ring("tilt", frame.x, Vector3.UP, float(_state.get("height", 3))))
	_draw_rings()

func _ring(kind: String, axis: Vector3, u: Vector3, dimension: float) -> Dictionary:
	var pivot: Vector3 = _pose.origin if _has_pose else _state["pivot"]
	var pixels_per_unit := _camera.get_viewport().get_visible_rect().size.y / _camera.size
	var radius := maxf(dimension * 0.5 + GAP, MIN_PIXEL_RADIUS / pixels_per_unit)
	var v := axis.cross(u).normalized()
	var center := _camera.unproject_position(pivot)
	var x := _camera.unproject_position(pivot + u * radius) - center
	var y := _camera.unproject_position(pivot + v * radius) - center
	return {"kind":kind, "axis":axis, "u":u, "v":v, "pivot":pivot, "radius":radius,
		"center":center, "x":x, "y":y, "pixel_radius":radius * pixels_per_unit,
		"edge_on":absf(axis.dot(_camera.global_basis.z)) < EDGE_ON_RATIO}

func _visible(arc: Dictionary) -> bool:
	return _available() and (not _busy or _active) and (not _active or arc["kind"] == _drag["kind"])

static func world_point(arc: Dictionary, angle: float) -> Vector3:
	return arc["pivot"] + (arc["u"] * cos(angle) + arc["v"] * sin(angle)) * arc["radius"]

static func screen_point(arc: Dictionary, angle: float) -> Vector2:
	return arc["center"] + arc["x"] * cos(angle) + arc["y"] * sin(angle)

func _point_allowed(point: Vector2) -> bool:
	if _safe_rect.size != Vector2.ZERO and not _safe_rect.has_point(point): return false
	for excluded: Rect2 in _excluded:
		if excluded.has_point(point): return false
	return true

func _draw_rings() -> void:
	if not is_instance_valid(_overlay): return
	_overlay.strokes.clear()
	for arc: Dictionary in _arcs:
		if not _visible(arc): continue
		var color := Color("d9f5ff") if arc["kind"] == "turn" else Color("ffc77e")
		for index: int in SAMPLES:
			var a := TAU * index / SAMPLES
			var b := TAU * (index + 1) / SAMPLES
			var near: bool = (world_point(arc, (a+b)*0.5) - arc["pivot"]).dot(_camera.global_basis.z) >= 0.0
			_stroke(screen_point(arc,a), screen_point(arc,b), Color(color, 0.95 if near else 0.22), 2.5)
	_overlay.queue_redraw()

func _stroke(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if _point_allowed(a) and _point_allowed(b) and _point_allowed((a+b)*0.5):
		_overlay.strokes.append({"a":a, "b":b, "color":color, "width":width})

func _hit(point: Vector2) -> Dictionary:
	if not _point_allowed(point): return {}
	var best := {}
	var best_distance := HIT_HALF_WIDTH
	var best_depth := -INF
	for arc: Dictionary in _arcs:
		if not _visible(arc): continue
		for index: int in SAMPLES:
			var angle := TAU * index / SAMPLES
			var a := screen_point(arc,angle)
			var b := screen_point(arc,angle + TAU/SAMPLES)
			if not _point_allowed(a) or not _point_allowed(b) or not _point_allowed((a+b)*0.5): continue
			var nearest := Geometry2D.get_closest_point_to_segment(point,a,b)
			var distance := point.distance_to(nearest)
			var weight := a.distance_to(nearest) / maxf(a.distance_to(b),0.001)
			var selected_angle := angle + weight * TAU/SAMPLES
			var depth := world_point(arc,selected_angle).dot(_camera.global_basis.z)
			if distance < best_distance - 0.01 or (absf(distance-best_distance) <= 0.01 and depth > best_depth):
				best = {"arc":arc, "angle":selected_angle}
				best_distance = distance
				best_depth = depth
	return best

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			_finish()
			return true
		return false
	if _active or _busy or not _available(): return false
	var hit := _hit(point)
	if hit.is_empty(): return false
	_drag = hit["arc"].duplicate(true)
	_active = true
	_pointer = index
	_press = point
	_travel = 0.0
	_last_angle = float(hit["angle"]) if _drag["edge_on"] else _pointer_angle(point,_drag)
	var tangent: Vector2 = -_drag["x"] * sin(_last_angle) + _drag["y"] * cos(_last_angle)
	# At an ellipse endpoint the tangent can vanish. Its major axis is the usable drag direction.
	if tangent.length() < 1.0:
		tangent = _drag["x"] if (_drag["x"] as Vector2).length() >= (_drag["y"] as Vector2).length() else _drag["y"]
	_drag["tangent"] = tangent.normalized()
	action_requested.emit("rotation_begin", {"kind":_drag["kind"], "axis":_drag["axis"]})
	_draw_rings()
	return true

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index): return false
	if _drag["edge_on"]:
		_travel = (point-_press).dot(_drag["tangent"]) / float(_drag["pixel_radius"])
	else:
		if point.distance_to(_drag["center"]) < 12.0: return true
		var angle := _pointer_angle(point,_drag)
		_travel += angular_delta(_last_angle,angle)
		_last_angle = angle
	action_requested.emit("rotation_angle",_travel)
	return true

static func _pointer_angle(point: Vector2, arc: Dictionary) -> float:
	var local := Transform2D(arc["x"], arc["y"], arc["center"]).affine_inverse() * point
	return atan2(local.y,local.x)

static func angular_delta(from: float, to: float) -> float:
	return wrapf(to-from,-PI,PI)

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func is_active() -> bool:
	return _active

func cancel() -> void:
	if _active: _finish()

func _finish() -> void:
	_active = false
	_pointer = -2
	_drag.clear()
	action_requested.emit("rotation_end",null)
	_update()

func blocks_point(point: Vector2) -> bool:
	return not _hit(point).is_empty()

func choose_edge_ends() -> void:
	pass

func get_orb_points() -> PackedVector2Array:
	return PackedVector2Array()

func get_fit_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	if _available():
		for arc: Dictionary in _arcs:
			for index: int in SAMPLES:
				points.append(world_point(arc,TAU*index/SAMPLES))
	return points

func get_arc_points(kind: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for arc: Dictionary in _arcs:
		if arc["kind"] == kind and _visible(arc):
			for index: int in SAMPLES+1:
				points.append(screen_point(arc,TAU*index/SAMPLES))
	return points

func get_control_rects() -> Dictionary:
	var result := {}
	for arc: Dictionary in _arcs:
		if not _visible(arc): continue
		var points := get_arc_points(arc["kind"])
		var rect := Rect2(points[0],Vector2.ZERO)
		for point: Vector2 in points: rect = rect.expand(point)
		result[arc["kind"]] = rect.grow(HIT_HALF_WIDTH)
	return result

func get_ring_frame(kind: String) -> Dictionary:
	if _active and _drag["kind"] == kind: return _drag.duplicate(true)
	for arc: Dictionary in _arcs:
		if arc["kind"] == kind: return arc.duplicate(true)
	return {}
