class_name MirrorArrow
extends Node3D
## The facing handle of the direct controls: an arrow from the mirror's centre
## toward the side its copy appears on. Dragging the knob points the mirror
## along one grid direction. Drawn in screen space for a constant line width
## and touch size; the game owns the state change.
signal action_requested(action: String, value: Variant)

const Rules := preload("res://core/mirror_state.gd")
const Targets := preload("res://core/mirror_targets.gd")
const LENGTH := 1.9
const MIN_PIXELS := 72.0
const KNOB_RADIUS := 13.0
const HIT_RADIUS := 26.0
## Screen distance from the centre before the finger's direction counts.
const PICK_DISTANCE := 24.0
const PEARL := Color("d9f5ff")
const IVORY := Color(0.95, 0.92, 0.84, 0.94)
const INK := Color(0.20, 0.25, 0.27, 0.9)
const SHADOW := Color(0.12, 0.15, 0.17)
const HORIZONTAL: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
const VERTICAL: Array[Vector3] = [Vector3.UP, Vector3.DOWN]

class ArrowOverlay extends Control:
	var arrow: MirrorArrow
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if arrow != null:
			arrow._draw_overlay(self)

var _state: Dictionary = {}
var _available := false
var _busy := false
var _allow_vertical := false
var _camera: Camera3D
var _safe_rect := Rect2()
var _excluded: Array[Rect2] = []
var _active := false
var _pointer := -2
var _choice := -1
var _canvas := CanvasLayer.new()
var _overlay := ArrowOverlay.new()

func _ready() -> void:
	_canvas.layer = 2
	add_child(_canvas)
	_overlay.arrow = self
	_canvas.add_child(_overlay)

func set_state(state: Dictionary, available: bool, busy: bool, allow_vertical := false) -> void:
	_state = state
	_available = available and state.has("pivot") and bool(state.get("enabled", false))
	_busy = busy
	_allow_vertical = allow_vertical
	if not _available and _active:
		cancel()
	_overlay.queue_redraw()

func update_view(camera: Camera3D, safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	_camera = camera
	_safe_rect = safe_rect
	_excluded = excluded
	_overlay.queue_redraw()

## Hides the arrow's own 2D layer. `visible` on this Node3D would not do it:
## a CanvasLayer renders on its own, independent of a 3D ancestor.
func set_overlay_visible(value: bool) -> void:
	_canvas.visible = value

func candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	result.append_array(HORIZONTAL)
	if _allow_vertical:
		result.append_array(VERTICAL)
	return result

func is_active() -> bool:
	return _active

func owns_pointer(index: int) -> bool:
	return _active and _pointer == index

func knob_point() -> Vector2:
	return _tip_screen(Rules.normal(_state)) if _shown() else Vector2(-INF, -INF)

func blocks_point(point: Vector2) -> bool:
	return _usable() and point.distance_to(knob_point()) <= HIT_RADIUS

func pointer(point: Vector2, pressed: bool, index: int) -> bool:
	if not pressed:
		if owns_pointer(index):
			_finish()
			return true
		return false
	if _active or _busy or not blocks_point(point):
		return false
	_active = true
	_pointer = index
	_choice = _current_choice()
	action_requested.emit("point_begin", null)
	_overlay.queue_redraw()
	return true

func motion(point: Vector2, index: int) -> bool:
	if not owns_pointer(index):
		return false
	var offset := point - _centre()
	if offset.length() < PICK_DISTANCE:
		return true
	var directions: Array[Vector2] = []
	for candidate: Vector3 in candidates():
		directions.append(_camera.unproject_position(_pivot() + candidate) - _centre())
	var choice := Targets.pick_direction(offset, directions, _choice)
	if choice >= 0 and choice != _choice:
		_choice = choice
		action_requested.emit("point_direction", candidates()[choice])
	_overlay.queue_redraw()
	return true

func cancel() -> void:
	if _active:
		_finish()

func _finish() -> void:
	_active = false
	_pointer = -2
	_choice = -1
	action_requested.emit("point_end", null)
	_overlay.queue_redraw()

func _current_choice() -> int:
	var normal := Rules.normal(_state)
	var options := candidates()
	for index: int in options.size():
		if normal.dot(options[index]) > 0.99:
			return index
	return -1

func _pivot() -> Vector3:
	return _state["pivot"]

func _centre() -> Vector2:
	return _camera.unproject_position(_pivot())

func _tip_screen(direction: Vector3) -> Vector2:
	var centre := _centre()
	var pixels_per_unit := (_camera.unproject_position(_pivot() + direction) - centre).length()
	var length := maxf(LENGTH, MIN_PIXELS / maxf(pixels_per_unit, 1.0))
	return _camera.unproject_position(_pivot() + direction * length)

## Drawn whenever the mirror stands, busy or not, so it does not flicker
## through a drag; `pointer` alone refuses a press while busy.
func _shown() -> bool:
	return _available and _camera != null

## Shown, and the knob sits where a touch can reach it.
func _usable() -> bool:
	if not _shown():
		return false
	var knob := _tip_screen(Rules.normal(_state))
	var footprint := Rect2(knob - Vector2.ONE * KNOB_RADIUS, Vector2.ONE * KNOB_RADIUS * 2.0)
	if _safe_rect.size != Vector2.ZERO and not _safe_rect.encloses(footprint):
		return false
	for rect: Rect2 in _excluded:
		if rect.intersects(footprint):
			return false
	return true

func _draw_overlay(canvas: Control) -> void:
	if not _usable():
		return
	var centre := _centre()
	var knob := knob_point()
	if _active:
		var options := candidates()
		for index: int in options.size():
			if index == _choice:
				continue
			var tip := _tip_screen(options[index])
			canvas.draw_line(centre, tip, Color(PEARL, 0.3), 2.0, true)
			canvas.draw_circle(tip, 5.0, Color(PEARL, 0.4))
	canvas.draw_line(centre, knob, Color(SHADOW, 0.4), 5.0, true)
	canvas.draw_line(centre, knob, Color(PEARL, 0.95), 2.5, true)
	canvas.draw_circle(knob, KNOB_RADIUS + 1.0, INK)
	canvas.draw_circle(knob, KNOB_RADIUS, IVORY)
	var forward := (knob - centre).normalized() if knob.distance_to(centre) > 1.0 else Vector2.UP
	var side := forward.orthogonal()
	var head := knob + forward * 4.0
	canvas.draw_line(head, head - forward * 7.0 + side * 5.0, INK, 2.0, true)
	canvas.draw_line(head, head - forward * 7.0 - side * 5.0, INK, 2.0, true)
