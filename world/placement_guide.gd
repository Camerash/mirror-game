class_name PlacementGuide
extends Node3D
## Passive screen-space marks for the current placement candidates.

const Queries := preload("res://core/solid_queries.gd")
const PEARL := Color("d9eff4")
const AMBER := Color("f1c57b")
const FADE_TIME := 0.2

class MarksCanvas extends Control:
	var guide: PlacementGuide

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if guide == null:
			return
		for mark: Dictionary in guide._visible_marks:
			var centre: Vector2 = mark["screen"]
			var alpha: float = float(mark["alpha"]) * guide._opacity
			match mark["kind"]:
				"dot":
					draw_circle(centre, 2.0, Color(PEARL, alpha * 0.14))
					draw_circle(centre, 1.0, Color(PEARL, alpha))
				"reference":
					draw_circle(centre, 3.2, Color(AMBER, alpha * 0.14))
					draw_circle(centre, 2.0, Color(AMBER, alpha))
				"target":
					draw_arc(centre, 3.5, 0.0, TAU, 24, Color(PEARL, alpha), 0.8, true)

var _canvas := MarksCanvas.new()
var _layer := CanvasLayer.new()
var _data: Dictionary = {}
var _visible_marks: Array[Dictionary] = []
var _opacity := 1.0
var _fade: Tween

func _ready() -> void:
	_layer.layer = 3
	_layer.add_child(_canvas)
	_canvas.guide = self
	add_child(_layer)

func show_guides(data: Dictionary) -> void:
	_cancel_fade()
	_opacity = 1.0
	_data = data.duplicate(true)

func update_view(camera: Camera3D, solids: Array[Dictionary], safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	_visible_marks.clear()
	if camera == null or _data.is_empty():
		_redraw()
		return
	for dot: Dictionary in _data.get("dots", []):
		if dot.get("position") is Vector3:
			_add_mark("dot", dot["position"], clampf(float(dot.get("weight", 0.0)), 0.0, 1.0) * 0.35, camera, solids, safe_rect, excluded)
	for reference: Vector3 in _data.get("references", PackedVector3Array()):
		_add_mark("reference", reference, 0.85, camera, solids, safe_rect, excluded)
	if _data.get("target") is Vector3:
		_add_mark("target", _data["target"], 1.0, camera, solids, safe_rect, excluded)
	_redraw()

func finish() -> void:
	if _data.is_empty() or _is_fading():
		return
	_fade = create_tween()
	_fade.tween_method(_set_opacity, _opacity, 0.0, FADE_TIME)
	_fade.tween_callback(clear)

func clear() -> void:
	_cancel_fade()
	_data.clear()
	_visible_marks.clear()
	_opacity = 1.0
	_redraw()

func get_visible_marks() -> Array[Dictionary]:
	return _visible_marks.duplicate(true)

func _add_mark(kind: String, world_position: Vector3, alpha: float, camera: Camera3D, solids: Array[Dictionary], safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	if alpha <= 0.0 or camera.is_position_behind(world_position):
		return
	var screen := camera.unproject_position(world_position)
	if not safe_rect.has_point(screen) or _excluded(screen, excluded) or _solid_occludes(camera, world_position, solids):
		return
	_visible_marks.append({"kind": kind, "position": world_position, "screen": screen, "alpha": alpha})

func _excluded(point: Vector2, excluded: Array[Rect2]) -> bool:
	for rect: Rect2 in excluded:
		if rect.has_point(point):
			return true
	return false

func _solid_occludes(camera: Camera3D, point: Vector3, solids: Array[Dictionary]) -> bool:
	var origin := camera.project_ray_origin(camera.unproject_position(point))
	var distance := origin.distance_to(point)
	if distance <= 0.01:
		return false
	var direction := origin.direction_to(point)
	for solid: Dictionary in solids:
		var hit := Queries.ray_hit(origin, direction, solid)
		if not hit.is_empty() and float(hit["distance"]) < distance - 0.01:
			return true
	return false

func _set_opacity(value: float) -> void:
	_opacity = value
	_redraw()

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _is_fading() -> bool:
	return _fade != null and _fade.is_valid() and _fade.is_running()

func _redraw() -> void:
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()
