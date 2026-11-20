extends Node3D
## A soft shadow straight below each stone and each copy, on the water. The
## shadows are drawn as one mask picture from above, then laid on a plane just
## over the water. A stone that floats higher has a wider and softer rim.
## Overlapping shadows do not add up, because the picture holds the darkest
## value of each point.

const MaskShader := preload("res://world/water_shadow.gdshader")
const SHADE := Color(0.07, 0.10, 0.16)
const STRENGTH := 0.4
## Steps of the soft rim, from the footprint to the full reach.
const LAYERS := 12
const PIXELS_PER_UNIT := 32.0
const MAX_PIXELS := 1024
## The plane is a hair over the water, so that the water does not hide it.
const LIFT := 0.01
const MARGIN := 0.05

## 0 to 1. Fades the shadows in with the stones.
var shown := 1.0:
	set(value):
		shown = value
		_material.set_shader_parameter("shown", value)

var _material := ShaderMaterial.new()
var _viewport := SubViewport.new()
var _canvas := Node2D.new()
var _plane := MeshInstance3D.new()
var _drawn: Array[Dictionary] = []
var _origin := Vector2.ZERO
var _pixels_per_unit := PIXELS_PER_UNIT


func _ready() -> void:
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.add_child(_canvas)
	_canvas.draw.connect(_paint)
	add_child(_viewport)
	_material.shader = MaskShader
	_material.set_shader_parameter("mask", _viewport.get_texture())
	_material.set_shader_parameter("shade", SHADE)
	_material.set_shader_parameter("strength", STRENGTH)
	_material.set_shader_parameter("shown", shown)
	_plane.mesh = PlaneMesh.new()
	_plane.material_override = _material
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.visible = false
	add_child(_plane)


## How far the soft rim reaches around a thing `height` units over the water.
static func reach(height: float) -> float:
	return clampf(0.15 * height, 0.05, 0.45)


## The outlines to draw, lightest first. Each shape in `shapes` has an
## `outline` (convex, in x and z) and a `height` over the water. Each result
## has an `outline` and a `shade` from 0 to 1. The darker outlines come last,
## so shapes that overlap do not add up and shapes that touch show no seam.
# ponytail: each change grows every outline again (11 offsets for each
# solid). If the phone shows a cost, keep the grown outlines of a solid that
# did not change.
static func layers(shapes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shape: Dictionary in shapes:
		var outline: PackedVector2Array = shape["outline"]
		var height: float = shape["height"]
		if height <= 0.0 or outline.size() < 3:
			continue
		# `offset_polygon` grows a counter-clockwise outline only.
		if Geometry2D.is_polygon_clockwise(outline):
			outline = outline.duplicate()
			outline.reverse()
		result.append({"outline": outline, "shade": 1.0})
		var width := reach(height)
		for step: int in range(1, LAYERS):
			var part := float(step) / LAYERS
			var grown := Geometry2D.offset_polygon(outline, width * part, Geometry2D.JOIN_ROUND)
			if grown.is_empty():
				continue
			result.append({"outline": grown[0], "shade": 1.0 - smoothstep(0.0, 1.0, part)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["shade"] < b["shade"])
	return result


## Lays the shadows. `water` is the height of the water. With no shape, the
## shadow is hidden.
func show_shapes(shapes: Array[Dictionary], water: float) -> void:
	_drawn = layers(shapes)
	_plane.visible = not _drawn.is_empty()
	if _drawn.is_empty():
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for layer: Dictionary in _drawn:
		for point: Vector2 in layer["outline"]:
			low = low.min(point)
			high = high.max(point)
	low -= Vector2.ONE * MARGIN
	high += Vector2.ONE * MARGIN
	_origin = low
	var span := high - low
	_pixels_per_unit = minf(PIXELS_PER_UNIT, MAX_PIXELS / maxf(span.x, span.y))
	var pixels := Vector2i((span * _pixels_per_unit).ceil()).maxi(1)
	_viewport.size = pixels
	# The plane covers exactly the pixels, so that UV (0, 0) is the corner
	# with the least x and z.
	var size := Vector2(pixels) / _pixels_per_unit
	(_plane.mesh as PlaneMesh).size = size
	_plane.position = Vector3(low.x + size.x * 0.5, water + LIFT, low.y + size.y * 0.5)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_canvas.queue_redraw()


func _paint() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(_viewport.size)), Color.BLACK)
	_canvas.draw_set_transform(-_origin * _pixels_per_unit, 0.0, Vector2.ONE * _pixels_per_unit)
	for layer: Dictionary in _drawn:
		var shade: float = layer["shade"]
		_canvas.draw_colored_polygon(layer["outline"], Color(shade, shade, shade))
