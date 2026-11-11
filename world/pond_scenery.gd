class_name PondScenery
extends MeshInstance3D
## The pond round a place: stands of dry reed mace in the water, outside the
## ground the puzzle can use. Built by rule from the place's limits, the same
## every time for the same place. No two stands are alike: each has its own
## size, and some stems are broken.
##
## Things to look at, not to stand on: every piece is thin and none has a
## flat top. The water mirrors them (see `world/ice.gd`). Presentation only.

const Ice := preload("res://world/ice.gd")
const SceneryShader := preload("res://world/scenery.gdshader")
## Nothing stands closer than this to where a mirror, and so a copy, can be.
const CLEAR := 2.0
## The band of scenery round the place is this wide.
const REACH := 9.0
const SPACING := 2.4

const STEM := Color(0.50, 0.43, 0.36)
const FOOT := Color(0.24, 0.17, 0.18)
const HEAD := Color(0.30, 0.24, 0.27)
## A leaf bends over in this many straight parts.
const LEAF_PARTS := 5

var _tool := SurfaceTool.new()
var _random := RandomNumberGenerator.new()

## Builds the scenery round `limits` (a level's mirror limits) in the water at
## `water_height`. `place` names the place and seeds the layout; `haze` is the
## colour of the air there, which the scenery takes on.
static func build(limits: Dictionary, water_height: float, place: String, haze: Color) -> PondScenery:
	var scenery := PondScenery.new()
	scenery._build(limits, water_height, place)
	var material := ShaderMaterial.new()
	material.shader = SceneryShader
	material.set_shader_parameter("haze", haze)
	material.set_shader_parameter("water_level", water_height)
	scenery.material_override = material
	scenery.layers = 1 | Ice.MIRRORED_LAYER
	# Water shows no shadow of a thing this thin.
	scenery.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return scenery

func _build(limits: Dictionary, water_height: float, place: String) -> void:
	var low: Array = limits["min"]
	var high: Array = limits["max"]
	var keep_clear := Rect2(float(low[0]), float(low[2]), float(high[0]) - float(low[0]), float(high[2]) - float(low[2])).grow(CLEAR)
	var band := keep_clear.grow(REACH)
	_random.seed = hash(place)
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := ceili(band.size.x / SPACING)
	var rows := ceili(band.size.y / SPACING)
	for row: int in rows:
		for column: int in columns:
			var spot := band.position + (Vector2(column, row) + Vector2(_random.randf(), _random.randf())) * SPACING
			var pick := _random.randf()
			# The reeds stand in loose groups, with open water between them.
			var group := sin(spot.x * 0.23 + float(_random.seed % 7)) * cos(spot.y * 0.21 + 1.3)
			if keep_clear.has_point(spot) or group < 0.3 or pick > 0.38:
				continue
			_stand(Vector3(spot.x, water_height, spot.y))
	mesh = _tool.commit()

## A stand of reed mace: straight stems, a dark head on some, long leaves
## that bend over, and a broken stem here and there.
func _stand(at: Vector3) -> void:
	var size := _random.randf_range(0.4, 1.0)
	var spread := 0.2 + 0.4 * size
	for index: int in _random.randi_range(1, int(2.0 + 4.0 * size)):
		var foot := at + Vector3(_random.randfn(0.0, spread * 0.5), 0.0, _random.randfn(0.0, spread * 0.5))
		var height := _random.randf_range(0.7, 1.0) * (0.8 + 1.4 * size)
		var lean := Vector3(_random.randf_range(-0.16, 0.16), 1.0, _random.randf_range(-0.16, 0.16)).normalized()
		var top := foot + lean * height
		if _random.randf() < 0.25:
			# A broken stem: its upper part hangs toward the water.
			var knee := foot + lean * height * _random.randf_range(0.35, 0.6)
			var down := Vector3(_random.randf_range(-1.0, 1.0), -0.6, _random.randf_range(-1.0, 1.0)).normalized()
			var hang := minf(height * 0.5, (knee.y - at.y) / -down.y * 0.85)
			_prism(foot, knee, 0.028, 0.022, FOOT, STEM, 0.0, 0.5)
			_prism(knee, knee + down * hang, 0.022, 0.012, STEM, STEM, 0.5, 0.3)
		else:
			_prism(foot, top, 0.028, 0.014, FOOT, STEM, 0.0, 1.0)
			if _random.randf() < 0.5:
				var head := foot + lean * height * _random.randf_range(0.70, 0.80)
				var girth := _random.randf_range(0.045, 0.062)
				_prism(head, head + lean * _random.randf_range(0.18, 0.30), girth, girth * 0.9, HEAD, HEAD, 0.75, 0.95)
		if _random.randf() < 0.6:
			# A long leaf rises beside the stem and bends over in a curve.
			var out := Vector3(_random.randf_range(-1.0, 1.0), 0.0, _random.randf_range(-1.0, 1.0)).normalized()
			var reach := height * _random.randf_range(0.5, 0.9)
			var from := foot
			for part: int in LEAF_PARTS:
				var along := float(part + 1) / LEAF_PARTS
				var to := foot + lean * reach * along * (1.0 - 0.35 * along * along) + out * reach * 0.45 * along * along
				_blade(from, to, lerpf(0.06, 0.008, float(part) / LEAF_PARTS), lerpf(0.06, 0.008, along), FOOT.lerp(STEM, along), FOOT.lerp(STEM, along), float(part) / LEAF_PARTS, along)
				from = to

## A thin ribbon from `from` to `to`, crossed so it shows from every side.
func _blade(from: Vector3, to: Vector3, width_from: float, width_to: float, color_from: Color, color_to: Color, sway_from: float, sway_to: float) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
	for turn: int in 2:
		var normal := (along.cross(side) * 0.35 + Vector3.UP).normalized()
		var corners := [from - side * width_from * 0.5, from + side * width_from * 0.5, to + side * width_to * 0.5, to - side * width_to * 0.5]
		for index: int in [0, 1, 2, 0, 2, 3]:
			var low := index < 2
			_tool.set_normal(normal)
			_tool.set_color(color_from if low else color_to)
			_tool.set_uv(Vector2(0.0, sway_from if low else sway_to))
			_tool.add_vertex(corners[index])
		side = along.cross(side)

## A tapered round bar from `from` to `to`.
func _prism(from: Vector3, to: Vector3, radius_from: float, radius_to: float, color_from: Color, color_to: Color, sway_from: float, sway_to: float) -> void:
	const SIDES := 5
	var along := (to - from).normalized()
	var side := along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
	var other := along.cross(side)
	for index: int in SIDES:
		var ring: Array[Vector3] = []
		for corner: int in 2:
			var angle := TAU * float(index + corner) / SIDES
			ring.append(side * cos(angle) + other * sin(angle))
		var quad := [[from + ring[0] * radius_from, ring[0]], [from + ring[1] * radius_from, ring[1]],
			[to + ring[1] * radius_to, ring[1]], [to + ring[0] * radius_to, ring[0]]]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			var low := corner < 2
			_tool.set_normal(quad[corner][1])
			_tool.set_color(color_from if low else color_to)
			_tool.set_uv(Vector2(0.0, sway_from if low else sway_to))
			_tool.add_vertex(quad[corner][0])
