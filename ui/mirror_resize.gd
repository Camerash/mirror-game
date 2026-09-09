class_name MirrorResize
extends Control
## Passive screen-space resize targets. The game owns resize values and dispatch.

signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const TOUCH := 48.0
const PILL_SIZE := Vector2(36.0, 12.0)

var is_obstructed: Callable

var _state: Dictionary = {}
var _editing := false
var _busy := false
var _camera: Camera3D
var _safe_rect := Rect2()
var _excluded: Array[Rect2] = []
var _orbs := PackedVector2Array()
var _tabs := {}
var _active := false
var _pointer := -2
var _active_key := ""

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_state(state: Dictionary, editing: bool, busy: bool) -> void:
	_state = state.duplicate(true)
	_editing = editing
	_busy = busy
	if not _available():
		cancel()
		_tabs.clear()
		queue_redraw()
	elif _busy and not _active:
		_tabs.clear()
		queue_redraw()

func update_view(camera: Camera3D, safe_rect: Rect2, excluded: Array[Rect2], orbs: PackedVector2Array) -> void:
	_camera = camera
	_safe_rect = safe_rect
	_excluded = excluded.duplicate()
	_orbs = orbs
	if _available() and not _busy and not _active:
		_layout_tabs()
	queue_redraw()

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			var action := "move_height_end" if _active_key == "height_move" else "resize_end"
			_active = false
			_pointer = -2
			_active_key = ""
			action_requested.emit(action, null)
			queue_redraw()
			return true
		return false
	if _active or _busy or not _available():
		return false
	for key: String in _tabs:
		if (_tabs[key] as Dictionary)["rect"].has_point(point):
			_active = true
			_pointer = index
			_active_key = key
			if key == "height_move":
				action_requested.emit("move_height_begin", point)
			else:
				action_requested.emit("resize_begin", {"key": key, "point": point})
			queue_redraw()
			return true
	return false

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	action_requested.emit("move_height_move" if _active_key == "height_move" else "resize_move", point)
	return true

func is_active() -> bool:
	return _active

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func cancel() -> void:
	if _active:
		var action := "move_height_end" if _active_key == "height_move" else "resize_end"
		_active = false
		_pointer = -2
		_active_key = ""
		action_requested.emit(action, null)
		queue_redraw()

func get_control_rects() -> Dictionary:
	var result := {}
	for key: String in _tabs:
		if _active and key != _active_key:
			continue
		result[key] = (_tabs[key] as Dictionary)["rect"]
	return result

func blocks_point(point: Vector2) -> bool:
	for key: String in _tabs:
		if _active and key != _active_key:
			continue
		var tab: Dictionary = _tabs[key]
		if tab["rect"].has_point(point):
			return true
	return false

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _camera != null

func _layout_tabs() -> void:
	_tabs.clear()
	var frame := Rules.frame(_state)
	_add_tab("width", _anchor("width"), frame.y)
	_add_tab("height", _anchor("height"), frame.x)
	_add_height_move(frame)

func _anchor(key: String) -> Vector3:
	var frame := Rules.frame(_state)
	var length := float(_state.get("width" if key == "width" else "height", 3.0)) * 0.5
	return _state["pivot"] + (frame.x if key == "width" else frame.y) * length

func _add_tab(key: String, anchor: Vector3, edge_axis: Vector3) -> void:
	if _camera.is_position_behind(anchor):
		return
	var projected := _camera.unproject_position(anchor)
	if _blocked(projected, anchor):
		return
	var alignment := _camera.unproject_position(anchor + edge_axis) - projected
	if alignment.length_squared() < 1.0:
		return
	alignment = alignment.normalized()
	var drag_axis := Rules.frame(_state).x if key == "width" else Rules.frame(_state).y
	var center := _edge_center(projected, alignment, key, anchor, edge_axis)
	var rect := Rect2(center - Vector2.ONE * TOUCH * 0.5, Vector2.ONE * TOUCH)
	if not _fits(rect, false):
		return
	var pixels_per_unit := (_camera.unproject_position(anchor + edge_axis) - projected).length()
	var edge_offset := edge_axis * (center - projected).dot(alignment) / pixels_per_unit
	_tabs[key] = {"anchor": anchor, "point": projected, "center": center, "rect": rect, "alignment": alignment, "drag_axis": drag_axis, "edge_offset": edge_offset}

func _edge_center(midpoint: Vector2, alignment: Vector2, key: String, anchor: Vector3, edge_axis: Vector3) -> Vector2:
	var midpoint_rect := Rect2(midpoint - Vector2.ONE * TOUCH * 0.5, Vector2.ONE * TOUCH)
	if not _overlaps_tab(midpoint_rect):
		return midpoint
	var other_length := float(_state.get("height" if key == "width" else "width", 3.0)) * 0.5
	var span := midpoint.distance_to(_camera.unproject_position(anchor + edge_axis * other_length))
	for sign: float in [1.0, -1.0]:
		var center := midpoint + alignment * span * sign
		var rect := Rect2(center - Vector2.ONE * TOUCH * 0.5, Vector2.ONE * TOUCH)
		if not _overlaps_tab(rect) and _fits(rect, false):
			return center
	return midpoint

func _overlaps_tab(rect: Rect2) -> bool:
	for tab: Dictionary in _tabs.values():
		if rect.intersects(tab["rect"]):
			return true
	return false

func _add_height_move(frame: Basis) -> void:
	var pivot: Vector3 = _state["pivot"]
	if _camera.is_position_behind(pivot):
		return
	var center := _camera.unproject_position(pivot)
	var edge := _camera.unproject_position(pivot + frame.x) - center
	if edge.length_squared() < 1.0:
		return
	var side := edge.normalized().orthogonal()
	for sign: float in [1.0, -1.0]:
		for offset: float in [42.0, 72.0, 102.0]:
			var control_center := center + side * offset * sign
			var rect := Rect2(control_center - Vector2.ONE * TOUCH * 0.5, Vector2.ONE * TOUCH)
			if _fits(rect, true, true):
				_tabs["height_move"] = {"anchor": pivot, "point": control_center, "center": control_center, "rect": rect}
				return

func _fits(rect: Rect2, avoid_controls := true, avoid_orbs := false) -> bool:
	if not _safe_rect.encloses(rect):
		return false
	for excluded: Rect2 in _excluded:
		if rect.intersects(excluded):
			return false
	if avoid_controls:
		for tab: Dictionary in _tabs.values():
			if rect.intersects(tab["rect"]):
				return false
	if avoid_orbs:
		for orb: Vector2 in _orbs:
			if rect.get_center().distance_to(orb) < TOUCH:
				return false
	return true

func _blocked(point: Vector2, anchor: Vector3) -> bool:
	return is_obstructed.is_valid() and bool(is_obstructed.call(point, anchor))

func _draw() -> void:
	for key: String in _tabs:
		if _active and key != _active_key:
			continue
		var tab: Dictionary = _tabs[key]
		var center: Vector2 = _camera.unproject_position(_anchor(key) + tab["edge_offset"]) if _active and key != "height_move" and _camera else tab["center"]
		var world_anchor: Vector3 = _state["pivot"] if _active and key == "height_move" else tab["anchor"]
		var anchor: Vector2 = _camera.unproject_position(world_anchor) if _camera else tab["point"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.95, 0.92, 0.84, 0.92)
		style.border_color = Color(0.20, 0.25, 0.27, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		if key == "height_move":
			draw_line(anchor, center, Color(0.15, 0.18, 0.20, 0.76), 2.0, true)
			draw_circle(center, 16.0, style.bg_color)
			draw_arc(center, 16.0, 0.0, TAU, 20, style.border_color, 1.0, true)
			var ink := Color(0.20, 0.25, 0.27, 0.9)
			draw_line(center + Vector2.UP * 9.0, center + Vector2.DOWN * 9.0, ink, 2.0, true)
			for direction: float in [-1.0, 1.0]:
				draw_line(center + Vector2(0, 9.0 * direction), center + Vector2(4.0, 5.0 * direction), ink, 2.0, true)
				draw_line(center + Vector2(0, 9.0 * direction), center + Vector2(-4.0, 5.0 * direction), ink, 2.0, true)
			continue
		var alignment: Vector2 = tab["alignment"]
		draw_set_transform(center, alignment.angle())
		draw_style_box(style, Rect2(-PILL_SIZE * 0.5, PILL_SIZE))
		var ink := Color(0.20, 0.25, 0.27, 0.9)
		for x: float in [-3.0, 0.0, 3.0]:
			draw_line(Vector2(x, -2.0), Vector2(x, 2.0), ink, 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0)
