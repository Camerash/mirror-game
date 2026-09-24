class_name PlacementGuide
extends Node3D
## Passive screen-space marks for the current placement candidates.

const Queries := preload("res://core/solid_queries.gd")
const Style := preload("res://core/constellation_style.gd")
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
			var color: Color = AMBER if mark["kind"] == "reference" else PEARL
			var halo: float = mark["halo"]
			if halo > 0.0 and float(mark["glow"]) > 0.0:
				draw_texture_rect(guide._halo_texture, Rect2(centre-Vector2.ONE*halo,Vector2.ONE*halo*2), false, Color(color,float(mark["glow"])*guide._opacity))
			if mark["kind"] == "target":
				draw_arc(centre, 3.5, 0.0, TAU, 32, Color(color,alpha), 1.0, true)
			else:
				draw_circle(centre,mark["radius"],Color(color,alpha),true,-1.0,true)

var _canvas := MarksCanvas.new()
var _layer := CanvasLayer.new()
var _data: Dictionary = {}
var _visible_marks: Array[Dictionary] = []
var _opacity := 1.0
var _fade: Tween
var _style := Style.DEFAULTS.duplicate()
var _halo_texture := GradientTexture2D.new()

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.15,0.35,0.65,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.8),Color(1,1,1,0.4),Color(1,1,1,0.08),Color(1,1,1,0)])
	_halo_texture.gradient = gradient
	_halo_texture.width = 64
	_halo_texture.height = 64
	_halo_texture.fill = GradientTexture2D.FILL_RADIAL
	_halo_texture.fill_from = Vector2(0.5,0.5)
	_halo_texture.fill_to = Vector2(1,0.5)
	_layer.layer = 3
	_layer.add_child(_canvas)
	_canvas.guide = self
	add_child(_layer)

func set_style(settings: Dictionary) -> void:
	_style = Style.normalized(settings)
	_redraw()

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
			_add_mark("dot", dot["position"], clampf(float(dot.get("weight", 0.0)), 0.0, 1.0), camera, solids, safe_rect, excluded)
	for reference: Vector3 in _data.get("references", PackedVector3Array()):
		_add_mark("reference", reference, 1.0, camera, solids, safe_rect, excluded)
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

## Hides the guide's own 2D layer. `visible` on this Node3D would not do it:
## a CanvasLayer renders on its own, independent of a 3D ancestor.
func set_overlay_visible(value: bool) -> void:
	_layer.visible = value

func get_visible_marks() -> Array[Dictionary]:
	return _visible_marks.duplicate(true)

func _add_mark(kind: String, world_position: Vector3, weight: float, camera: Camera3D, solids: Array[Dictionary], safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	if weight <= 0.0 or camera.is_position_behind(world_position):
		return
	var screen := camera.unproject_position(world_position)
	var mark := _appearance(kind,weight)
	var radius: float = maxf(mark["radius"],mark["halo"] if float(mark["glow"]) > 0.0 else 0.0)
	var footprint := Rect2(screen-Vector2.ONE*radius,Vector2.ONE*radius*2)
	if not safe_rect.encloses(footprint) or _excluded(footprint, excluded) or _solid_occludes(camera, world_position, solids):
		return
	mark.merge({"kind":kind,"position":world_position,"screen":screen})
	_visible_marks.append(mark)

func _appearance(kind: String, weight: float) -> Dictionary:
	var reference := kind == "reference"
	return {"alpha":minf(1.0,float(_style["brightness"])*(1.25 if reference else 1.0))*weight,
		"glow":minf(1.0,float(_style["glow"])*(1.4 if reference else 1.0))*weight,
		"radius":3.5 if kind == "target" else float(_style["size"])*(1.0 if reference else 0.5),
		"halo":float(_style["halo"])*(1.6 if reference else 1.0)}

func _excluded(footprint: Rect2, excluded: Array[Rect2]) -> bool:
	for rect: Rect2 in excluded:
		if rect.intersects(footprint):
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
