class_name PondScenery
extends MeshInstance3D
## The pond round a place: reeds and bare shrubs that
## stand in the ice, outside the ground the puzzle can use. Built by
## rule from the place's limits, the same every time for the same place.
##
## Things to look at, not to stand on: every piece is round, thin or low, none
## has a flat top, and none shows in the ice (see `world/ice.gd`).
## Presentation only.

const SceneryShader := preload("res://world/scenery.gdshader")
## Nothing stands closer than this to where a mirror, and so a copy, can be.
const CLEAR := 2.0
## The band of scenery round the place is this wide.
const REACH := 9.0
const SPACING := 2.4
## No scenery stands within this cosine of the line from the place to the sun.
const SUN_GAP := 0.62

const REED := Color(0.50, 0.43, 0.36, 0.0)
const REED_FOOT := Color(0.24, 0.17, 0.18, 0.0)
const PLUME := Color(0.30, 0.24, 0.27, 0.0)
const TWIG := Color(0.17, 0.12, 0.16, 0.7)

var _tool := SurfaceTool.new()
var _random := RandomNumberGenerator.new()
var _toward_sun := Vector2.ZERO

## Builds the scenery round `limits` (a level's mirror limits) on the ice at
## `ice_height`. `place` names the place and seeds the layout; `haze` is the
## colour of the air there, which the scenery takes on. Nothing stands
## between the place and the sun (`sun_from` points to it): there the ice
## holds the light, and a reed against it would be the darkest mark in view.
static func build(limits: Dictionary, ice_height: float, place: String, haze: Color, sun_from: Vector3) -> PondScenery:
	var scenery := PondScenery.new()
	scenery._toward_sun = Vector2(sun_from.x, sun_from.z).normalized()
	scenery._build(limits, ice_height, place)
	(scenery.material_override as ShaderMaterial).set_shader_parameter("haze", haze)
	return scenery

func _build(limits: Dictionary, ice_height: float, place: String) -> void:
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
			# The scenery stands in loose groups, with open ice between them.
			var group := sin(spot.x * 0.23 + float(_random.seed % 7)) * cos(spot.y * 0.21 + 1.3)
			var into_sun := (spot - keep_clear.get_center()).normalized().dot(_toward_sun) > SUN_GAP
			if keep_clear.has_point(spot) or into_sun or group < -0.2 or pick > 0.9:
				continue
			var at := Vector3(spot.x, ice_height, spot.y)
			if pick < 0.6:
				_reeds(at)
			else:
				_shrub(at)
	mesh = _tool.commit()
	var material := ShaderMaterial.new()
	material.shader = SceneryShader
	material_override = material

## A stand of dry reeds.
func _reeds(at: Vector3) -> void:
	var spread := _random.randf_range(0.35, 0.8)
	for index: int in _random.randi_range(9, 18):
		var foot := at + Vector3(_random.randfn(0.0, spread * 0.45), 0.0, _random.randfn(0.0, spread * 0.45))
		var height := _random.randf_range(0.45, 1.35)
		var lean := Vector3(_random.randf_range(-0.22, 0.22), 1.0, _random.randf_range(-0.22, 0.22)).normalized()
		var knee := foot + lean * height * 0.55
		var tip := knee + (lean + Vector3(_random.randf_range(-0.2, 0.2), 0.0, _random.randf_range(-0.2, 0.2))).normalized() * height * 0.45
		_blade(foot, knee, 0.05, 0.04, REED_FOOT, REED.lerp(REED_FOOT, 0.4), 0.0, 0.45)
		_blade(knee, tip, 0.04, 0.02, REED.lerp(REED_FOOT, 0.4), REED, 0.45, 1.0)
		if _random.randf() < 0.5:
			var droop := (lean + Vector3(_random.randf_range(-0.5, 0.5), 0.0, _random.randf_range(-0.5, 0.5))).normalized()
			_blade(tip, tip + droop * _random.randf_range(0.12, 0.2), 0.045, 0.01, PLUME, PLUME, 1.0, 1.2)
		# A dry leaf hangs from the knee of some.
		if _random.randf() < 0.45:
			var hang := Vector3(_random.randf_range(-1.0, 1.0), -0.25, _random.randf_range(-1.0, 1.0)).normalized()
			_blade(knee, knee + hang * _random.randf_range(0.15, 0.3), 0.03, 0.004, REED, REED.lerp(REED_FOOT, 0.3), 0.45, 0.8)

## A bare shrub: a short stem that forks and forks again.
func _shrub(at: Vector3) -> void:
	for stem: int in _random.randi_range(2, 4):
		var lean := Vector3(_random.randf_range(-0.35, 0.35), 1.0, _random.randf_range(-0.35, 0.35)).normalized()
		_branch(at + Vector3(_random.randf_range(-0.12, 0.12), 0.0, _random.randf_range(-0.12, 0.12)), lean, _random.randf_range(0.36, 0.55), 0.045, 3)

func _branch(from: Vector3, heading: Vector3, length: float, radius: float, depth: int) -> void:
	var to := from + heading * length
	var sway := clampf((4 - depth) * 0.25, 0.0, 1.0)
	_prism(from, to, radius, radius * 0.72, 4, TWIG, sway, sway + 0.25)
	if depth <= 1:
		return
	for fork: int in _random.randi_range(2, 3):
		var turn := Vector3(_random.randf_range(-0.8, 0.8), _random.randf_range(0.15, 0.6), _random.randf_range(-0.8, 0.8))
		_branch(to, (heading * 0.9 + turn).normalized(), length * _random.randf_range(0.62, 0.85), radius * 0.72, depth - 1)

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

## A tapered bar from `from` to `to` with `sides` faces.
func _prism(from: Vector3, to: Vector3, radius_from: float, radius_to: float, sides: int, color: Color, sway_from: float, sway_to: float) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized()
	var other := along.cross(side)
	for index: int in sides:
		var ring: Array[Vector3] = []
		for corner: int in 2:
			var angle := TAU * float(index + corner) / sides
			ring.append(side * cos(angle) + other * sin(angle))
		var quad := [[from + ring[0] * radius_from, ring[0], sway_from], [from + ring[1] * radius_from, ring[1], sway_from],
			[to + ring[1] * radius_to, ring[1], sway_to], [to + ring[0] * radius_to, ring[0], sway_to]]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			_tool.set_normal(quad[corner][1])
			_tool.set_color(color)
			_tool.set_uv(Vector2(0.0, quad[corner][2]))
			_tool.add_vertex(quad[corner][0])
