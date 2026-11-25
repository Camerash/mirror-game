class_name PlacementGuide
extends Node3D
## Passive screen-space marks for the current placement candidates.

const Queries := preload("res://core/solid_queries.gd")
const Style := preload("res://core/constellation_style.gd")
const PEARL := Color("d9eff4")
const AMBER := Color("f1c57b")
## The sign of a held knob of the bar has the colours of the knob's own mark
## (`_draw_mark` in `world/mirror_bar.gd`): the mirror is a dark dot, and
## where it can go is pale. The pale is mid grey, so it shows on snow and on
## the water.
const SIGN_INK := Color(0.20, 0.25, 0.27)
const SIGN_PALE := Color(0.69, 0.70, 0.70)
const SIGN_WIDTH := 2.0

class MarksCanvas extends Control:
	var guide: PlacementGuide

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if guide == null:
			return
		if guide._data.get("sign", false):
			_draw_sign()
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

	## The sign of a held knob: its pale lines, a small dot at each step, the
	## mirror as a dark dot with a pale rim, and a pale ring on the step under
	## the slide.
	func _draw_sign() -> void:
		var opacity := guide._opacity
		for run: Array in guide._visible_traces:
			var points := PackedVector2Array()
			var colours := PackedColorArray()
			for point: Dictionary in run:
				points.append(point["screen"])
				colours.append(Color(SIGN_PALE, float(point["alpha"]) * opacity))
			draw_polyline_colors(points, colours, SIGN_WIDTH, true)
		for mark: Dictionary in guide._visible_marks:
			var centre: Vector2 = mark["screen"]
			match mark["kind"]:
				"dot":
					draw_circle(centre, 2.4, Color(SIGN_PALE, float(mark["alpha"]) * opacity), true, -1.0, true)
				"reference":
					draw_circle(centre, 5.6, Color(SIGN_PALE, opacity), true, -1.0, true)
					draw_circle(centre, 4.0, Color(SIGN_INK, opacity), true, -1.0, true)
				"target":
					draw_arc(centre, 8.0, 0.0, TAU, 40, Color(SIGN_PALE, opacity), SIGN_WIDTH, true)

var _canvas := MarksCanvas.new()
var _layer := CanvasLayer.new()
var _data: Dictionary = {}
var _visible_marks: Array[Dictionary] = []
## The seen parts of the sign's lines: each is a run of {screen, alpha}.
var _visible_traces: Array[Array] = []
var _opacity := 1.0
## The sign fades in when it comes ("appear") and out when it goes
## ("dismiss"), so no part of it shows or goes at once (owner, 2026-11-25).
var _fade: Tween
## True while the sign fades out.
var _leaving := false
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
	var arriving := _data.is_empty() or _leaving
	if _data.is_empty():
		_opacity = 0.0
	_data = data.duplicate(true)
	if arriving:
		_fade_to(1.0, "appear")

func update_view(camera: Camera3D, solids: Array[Dictionary], safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	_visible_marks.clear()
	_visible_traces.clear()
	if camera == null or _data.is_empty():
		_redraw()
		return
	for trace: Dictionary in _data.get("traces", []):
		_add_trace(trace.get("points", PackedVector3Array()), trace.get("weights", PackedFloat32Array()), camera, solids, safe_rect, excluded)
	for dot: Dictionary in _data.get("dots", []):
		if dot.get("position") is Vector3:
			_add_mark("dot", dot["position"], clampf(float(dot.get("weight", 0.0)), 0.0, 1.0), camera, solids, safe_rect, excluded)
	for reference: Vector3 in _data.get("references", PackedVector3Array()):
		_add_mark("reference", reference, 1.0, camera, solids, safe_rect, excluded)
	if _data.get("target") is Vector3:
		_add_mark("target", _data["target"], 1.0, camera, solids, safe_rect, excluded)
	_redraw()

func finish() -> void:
	if _data.is_empty() or _leaving:
		return
	_fade_to(0.0, "dismiss")
	_leaving = true
	_fade.tween_callback(clear)

func clear() -> void:
	_cancel_fade()
	_leaving = false
	_data.clear()
	_visible_marks.clear()
	_visible_traces.clear()
	_opacity = 1.0
	_redraw()

## Hides the guide's own 2D layer. `visible` on this Node3D would not do it:
## a CanvasLayer renders on its own, independent of a 3D ancestor.
func set_overlay_visible(value: bool) -> void:
	_layer.visible = value

func get_visible_marks() -> Array[Dictionary]:
	return _visible_marks.duplicate(true)

func get_visible_traces() -> Array[Array]:
	return _visible_traces.duplicate(true)

## One line of the sign, drawn where it is seen. A point that has no weight,
## is behind a stone, or is out of the play area or under the controls breaks
## the line.
# ponytail: one ray test for each point of a line (about 70 for each sign);
# draw the lines in 3D with the depth test if this costs too much on a phone.
func _add_trace(points: PackedVector3Array, weights: PackedFloat32Array, camera: Camera3D, solids: Array[Dictionary], safe_rect: Rect2, excluded: Array[Rect2]) -> void:
	var run: Array[Dictionary] = []
	for index: int in points.size():
		var point := points[index]
		var weight := weights[index] if index < weights.size() else 0.0
		var screen := camera.unproject_position(point) if not camera.is_position_behind(point) else Vector2.INF
		var footprint := Rect2(screen - Vector2.ONE * SIGN_WIDTH, Vector2.ONE * SIGN_WIDTH * 2.0)
		if weight > 0.0 and screen.is_finite() and safe_rect.encloses(footprint) and not _excluded(footprint, excluded) and not _solid_occludes(camera, point, solids):
			run.append({"screen": screen, "alpha": weight})
			continue
		if run.size() > 1:
			_visible_traces.append(run)
		run = []
	if run.size() > 1:
		_visible_traces.append(run)

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

## Fades the whole sign from where it is now to `opacity`, by the motion of
## `verb`.
func _fade_to(opacity: float, verb: String) -> void:
	_cancel_fade()
	_leaving = false
	_fade = create_tween()
	_fade.tween_method(_set_opacity, _opacity, opacity, Motion.duration(verb)) \
		.set_trans(Motion.VERBS[verb][1]).set_ease(Motion.VERBS[verb][2])

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _redraw() -> void:
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()
