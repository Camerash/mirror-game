class_name MirrorResize
extends Control
## Passive screen-space resize targets. The game owns resize values and dispatch.

signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const TOUCH := 48.0
const GAP := 10.0
const ORB_GAP := 64.0

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
			_active = false
			_pointer = -2
			action_requested.emit("resize_end", null)
			queue_redraw()
			return true
		return false
	if _active or _busy or not _available():
		return false
	for key: String in _tabs:
		if (_tabs[key] as Dictionary)["rect"].has_point(point):
			_active = true
			_pointer = index
			action_requested.emit("resize_begin", {"key": key, "point": point})
			queue_redraw()
			return true
	return false

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	action_requested.emit("resize_move", point)
	return true

func is_active() -> bool:
	return _active

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func cancel() -> void:
	if _active:
		_active = false
		_pointer = -2
		action_requested.emit("resize_end", null)
		queue_redraw()

func get_control_rects() -> Dictionary:
	var result := {}
	for key: String in _tabs:
		result[key] = (_tabs[key] as Dictionary)["rect"]
	return result

func blocks_point(point: Vector2) -> bool:
	for tab: Dictionary in _tabs.values():
		if tab["rect"].has_point(point):
			return true
	return false

func _available() -> bool:
	return _editing and bool(_state.get("enabled", false)) and _camera != null

func _layout_tabs() -> void:
	_tabs.clear()
	var frame := Rules.frame(_state)
	_add_tab("width", _anchor("width"), frame.x)
	_add_tab("height", _anchor("height"), frame.y)

func _anchor(key: String) -> Vector3:
	var frame := Rules.frame(_state)
	var length := float(_state.get("width" if key == "width" else "height", 3.0)) * 0.5
	return _state["pivot"] + (frame.x if key == "width" else frame.y) * length

func _add_tab(key: String, anchor: Vector3, axis: Vector3) -> void:
	if _camera.is_position_behind(anchor):
		return
	var projected := _camera.unproject_position(anchor)
	if _blocked(projected, anchor):
		return
	var direction := _camera.unproject_position(anchor + axis) - projected
	if direction.length_squared() < 1.0:
		return
	direction = direction.normalized()
	for sign: float in [1.0, -1.0]:
		for offset: float in [34.0, 64.0, 88.0, 112.0]:
			var center := projected + direction * offset * sign
			var rect := Rect2(center - Vector2.ONE * TOUCH * 0.5, Vector2.ONE * TOUCH)
			if _fits(rect) and not _near_orb(center):
				_tabs[key] = {"anchor": anchor, "point": projected, "center": center, "rect": rect, "direction": direction}
				return

func _fits(rect: Rect2) -> bool:
	if not _safe_rect.encloses(rect):
		return false
	for excluded: Rect2 in _excluded:
		if rect.intersects(excluded):
			return false
	for tab: Dictionary in _tabs.values():
		if rect.intersects(tab["rect"]):
			return false
	return true

func _near_orb(point: Vector2) -> bool:
	for orb: Vector2 in _orbs:
		if point.distance_to(orb) < ORB_GAP:
			return true
	return false

func _blocked(point: Vector2, anchor: Vector3) -> bool:
	return is_obstructed.is_valid() and bool(is_obstructed.call(point, anchor))

func _draw() -> void:
	for key: String in _tabs:
		var tab: Dictionary = _tabs[key]
		var center: Vector2 = tab["center"]
		var world_anchor: Vector3 = _anchor(key) if _active else tab["anchor"]
		var anchor: Vector2 = _camera.unproject_position(world_anchor) if _camera else tab["point"]
		draw_line(anchor, center, Color(0.15, 0.18, 0.20, 0.76), 2.0, true)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.95, 0.92, 0.84, 0.92)
		style.border_color = Color(0.20, 0.25, 0.27, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		draw_style_box(style, Rect2(center - Vector2.ONE * 15.0, Vector2.ONE * 30.0))
		var axis: Vector2 = tab["direction"]
		var cross_axis := axis.orthogonal()
		var ink := Color(0.20, 0.25, 0.27, 0.9)
		draw_line(center - axis * 8.0, center + axis * 8.0, ink, 2.0, true)
		for end: float in [-1.0, 1.0]:
			for wing: float in [-1.0, 1.0]:
				draw_line(center + axis * 8.0 * end, center + axis * 4.0 * end + cross_axis * 3.0 * wing, ink, 2.0, true)
