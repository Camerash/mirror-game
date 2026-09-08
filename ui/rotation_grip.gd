extends Control
class_name RotationGrip
signal action_requested(value: int)
enum Mode { TURN, TILT }
const DRAG_DISTANCE := 24.0
var mode := Mode.TURN
var disabled := false:
	set(value):
		disabled = value
		queue_redraw()
var _active := false
var _touch := -2
var _origin := Vector2.ZERO
var _fired := false
func _ready() -> void:
	custom_minimum_size = Vector2(84, 84); size = custom_minimum_size; mouse_filter = MOUSE_FILTER_STOP; focus_mode = FOCUS_ALL; queue_redraw()
func is_active() -> bool: return _active
func cancel() -> void:
	_active = false; _touch = -2; _fired = false; queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION: _pointer(event.position, event.pressed, -1); accept_event()
	elif event is InputEventScreenTouch: _pointer(event.position, event.pressed, event.index); accept_event()
	elif event is InputEventMouseMotion and _active and _touch == -1: _drag(event.position); accept_event()
	elif event is InputEventScreenDrag and _active and _touch == event.index: _drag(event.position); accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (mode == Mode.TURN and event.keycode in [KEY_LEFT, KEY_RIGHT]) or (mode == Mode.TILT and event.keycode in [KEY_UP, KEY_DOWN]): action_requested.emit(1 if event.keycode in [KEY_RIGHT, KEY_DOWN] else -1); accept_event()
func _input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and _touch == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _finish(event.position - global_position)
	elif event is InputEventScreenTouch and _touch == event.index and not event.pressed: _finish(event.position - global_position)
	elif event is InputEventMouseMotion and _touch == -1: _drag(event.position - global_position)
	elif event is InputEventScreenDrag and _touch == event.index: _drag(event.position - global_position)
func _pointer(point: Vector2, pressed: bool, touch: int) -> void:
	if pressed:
		if _active: return
		_active = true; _touch = touch; _origin = point; _fired = false; queue_redraw()
	else: _finish(point)
func _drag(point: Vector2) -> void:
	if _fired: return
	var amount := (point - _origin).x if mode == Mode.TURN else (point - _origin).y
	if absf(amount) >= DRAG_DISTANCE: _fired = true; action_requested.emit(1 if amount > 0 else -1)
func _finish(point: Vector2) -> void:
	if not _active: return
	if not _fired and point.distance_to(_origin) < 12.0:
		var amount := point.x - size.x * .5 if mode == Mode.TURN else point.y - size.y * .5
		if absf(amount) >= 12.0: action_requested.emit(1 if amount > 0 else -1)
	_active = false; _touch = -2; queue_redraw()
func _draw() -> void:
	var outer := Color("342b2a", .8) if not disabled else Color("342b2a", .35)
	var inner := Color("fff4df", .95) if not disabled else Color("fff4df", .4)
	var center := size * .5
	if mode == Mode.TURN:
		draw_arc(center, 27, PI*.15, PI*.85, 16, outer, 6); draw_arc(center, 27, PI*1.15, PI*1.85, 16, outer, 6); draw_arc(center, 27, PI*.15, PI*.85, 16, inner, 2); draw_arc(center, 27, PI*1.15, PI*1.85, 16, inner, 2); draw_string(ThemeDB.fallback_font, Vector2(14, 48), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, outer); draw_string(ThemeDB.fallback_font, Vector2(57, 48), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, outer); draw_string(ThemeDB.fallback_font, Vector2(14, 48), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, inner); draw_string(ThemeDB.fallback_font, Vector2(57, 48), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, inner)
	else:
		draw_arc(center, 27, -PI*.35, PI*.35, 16, outer, 6); draw_arc(center, 27, PI*.65, PI*1.35, 16, outer, 6); draw_arc(center, 27, -PI*.35, PI*.35, 16, inner, 2); draw_arc(center, 27, PI*.65, PI*1.35, 16, inner, 2); draw_string(ThemeDB.fallback_font, Vector2(34, 27), "⌃", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, outer); draw_string(ThemeDB.fallback_font, Vector2(34, 69), "⌄", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, outer); draw_string(ThemeDB.fallback_font, Vector2(34, 27), "⌃", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, inner); draw_string(ThemeDB.fallback_font, Vector2(34, 69), "⌄", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, inner)
