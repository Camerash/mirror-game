class_name GardenBackdrop
extends Node3D
## The garden that stands round the pond, far behind a place. Each of its
## four sides has its own things: the house with one lit window; a wall with
## a gate and old bare trees; a wall with the roof of a glasshouse and a
## water tank behind it; a low wall with a large tree, a swing and a shed. Built by rule from
## the size of the place.
##
## Things to look at, not to stand on: all of it is pale with the mist, no
## top is light, and `CLEAR` units of open water lie between it and the
## place. A side that would stand between the view and the place leaves
## through a fine screen as the view turns, so the garden never covers the
## place. Presentation only.

const Ice := preload("res://world/ice.gd")
const GardenShader := preload("res://world/garden.gdshader")
## The open water between the stones of a place and the garden.
const CLEAR := 6.0
## The pond is never narrower than this from its middle to a side.
const MIN_REACH := 8.5
## A side shows in full while its outward direction makes less than `SHOWN`
## with the direction to the view (as dot products, on the water), and is
## gone at `GONE`. The four views of a place look at a corner: 0.71. The
## title's view sways about a corner, and no side changes in that sway.
const SHOWN := 0.05
const GONE := 0.25
## Where the next side is away, a wall runs on this far past its corner, so
## no view shows a wall that ends in the water.
const SPILL := 40.0

const WALL := Color(0.36, 0.38, 0.39)
const PALE := Color(0.44, 0.46, 0.47)
const DARK := Color(0.20, 0.22, 0.24)
const ROOF := Color(0.27, 0.29, 0.31)
const TREE := Color(0.17, 0.18, 0.20)
## The lit window, and the ground of the garden: the shader reads the alpha.
const LIT := Color(1.0, 1.0, 1.0, 0.0)
const GROUND := Color(1.0, 1.0, 1.0, 0.5)
## The ground of the garden starts this far behind the water's edge, behind
## the wall, and goes on this far: past the edge of every view.
const GROUND_FROM := 0.6
const GROUND_TO := 90.0

## Half the width of the pond.
var reach := MIN_REACH
## Where the lit window throws its light on the water.
var lamp_at := Vector3.ZERO
var _camera: Camera3D
var _water: Ice
## The four sides. The first is the house.
var _sides: Array[MeshInstance3D] = []
## The parts past the corners. Each is there when all of its `with` sides
## show and none of its `without` sides does.
var _past_corners: Array[Dictionary] = []
var _tool := SurfaceTool.new()

## Builds the garden round a place: `limits` are the level's mirror limits,
## `stones` the bounds of its stones, and `colors` its colour script
## (`world/trial_lighting.gd`). The garden follows `camera` and gives the
## light of its window to `water`.
static func build(limits: Dictionary, stones: AABB, water_height: float, colors: Dictionary, camera: Camera3D, water: Ice) -> GardenBackdrop:
	var garden := GardenBackdrop.new()
	var low: Array = limits["min"]
	var high: Array = limits["max"]
	var pond := Rect2(float(low[0]), float(low[2]), float(high[0]) - float(low[0]), float(high[2]) - float(low[2]))
	pond = pond.merge(Rect2(stones.position.x, stones.position.z, stones.size.x, stones.size.z))
	garden.position = Vector3(pond.get_center().x, water_height, pond.get_center().y)
	garden.reach = maxf(maxf(pond.size.x, pond.size.y) * 0.5 + CLEAR, MIN_REACH)
	garden._camera = camera
	garden._water = water
	var material := ShaderMaterial.new()
	material.shader = GardenShader
	material.set_shader_parameter("mist", colors["ice_far"])
	material.set_shader_parameter("lamp", colors["lamp"])
	material.set_shader_parameter("water_level", water_height)
	var high_wall := func(from: float, to: float) -> void: garden._wall(from, to, 3.2)
	var low_wall := func(from: float, to: float) -> void: garden._wall(from, to, 2.4)
	var runs: Array[Callable] = [high_wall, high_wall, high_wall, low_wall]
	garden._side(Vector3.FORWARD, garden._house, material)
	garden._side(Vector3.LEFT, garden._wall_and_trees, material)
	garden._side(Vector3.RIGHT, garden._greenhouse, material)
	garden._side(Vector3.BACK, garden._tree_and_swing, material)
	for pair: Array in [[0, 1], [0, 2], [3, 1], [3, 2]]:
		var a := garden._sides[pair[0]]
		var b := garden._sides[pair[1]]
		garden._corner(a, b, material)
		garden._run_on(a, b, runs[pair[0]], material)
		garden._run_on(b, a, runs[pair[1]], material)
	garden.lamp_at = garden.position + Vector3(-7.4, 0.0, 1.6 - garden.reach)
	if camera != null and camera.has_signal("view_changed"):
		camera.connect("view_changed", garden._face)
	garden._face()
	return garden

func _exit_tree() -> void:
	# The window's light on the water leaves with the garden.
	if _water != null:
		_water.lamp = Vector4()

## Shows each side by where it stands as seen from the camera.
func _face() -> void:
	if _camera == null:
		return
	var toward := _camera.global_transform.basis.z
	var flat := Vector2(toward.x, toward.z).normalized()
	for side: MeshInstance3D in _sides:
		var out := side.basis.z
		var shown := 1.0 - smoothstep(SHOWN, GONE, Vector2(out.x, out.z).dot(flat))
		_show(side, shown)
	for past: Dictionary in _past_corners:
		var shown := 1.0
		for side: MeshInstance3D in past["with"]:
			shown *= float(side.get_instance_shader_parameter("shown"))
		for side: MeshInstance3D in past["without"]:
			shown *= 1.0 - float(side.get_instance_shader_parameter("shown"))
		_show(past["part"], shown)
	if _water != null:
		_water.lamp = Vector4(lamp_at.x, lamp_at.y, lamp_at.z, float(_sides[0].get_instance_shader_parameter("shown")))

func _show(part: MeshInstance3D, shown: float) -> void:
	part.visible = shown > 0.0
	part.set_instance_shader_parameter("shown", shown)

## One side, `out` from the middle of the pond. `make` draws it in the
## side's own frame: x runs along the water's edge, y is up from the water,
## and z is outward from the water's edge. A post stands at each corner; the
## two sides that meet there draw the same post. Behind the wall lies the
## ground of the garden, lost in the mist.
func _side(out: Vector3, make: Callable, material: ShaderMaterial) -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	make.call()
	var end := reach + 0.85
	_quad(Vector3(-end, 0.05, GROUND_FROM), Vector3(end, 0.05, GROUND_FROM), Vector3(end, 0.05, GROUND_TO), Vector3(-end, 0.05, GROUND_TO), GROUND)
	for corner: float in [-reach - 0.3, reach + 0.3]:
		_box(Vector3(corner, 2.2, 0.3), Vector3(1.1, 4.4, 1.1), PALE)
		_roof(corner - 0.7, corner + 0.7, 4.4, 0.45, -0.4, 1.0)
	var side := _part(material)
	side.basis = Basis(Vector3.UP.cross(out), Vector3.UP, out)
	side.position = out * reach
	_sides.append(side)

## The ground of the garden past the corner where sides `a` and `b` meet.
## It is there when both sides are.
func _corner(a: MeshInstance3D, b: MeshInstance3D, material: ShaderMaterial) -> void:
	var out := a.basis.z + b.basis.z
	var near := out * (reach + 0.85)
	var far := out * (reach + GROUND_TO)
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(Vector3(minf(near.x, far.x), 0.05, minf(near.z, far.z)), Vector3(maxf(near.x, far.x), 0.05, minf(near.z, far.z)),
		Vector3(maxf(near.x, far.x), 0.05, maxf(near.z, far.z)), Vector3(minf(near.x, far.x), 0.05, maxf(near.z, far.z)), GROUND)
	_past_corners.append({"part": _part(material), "with": [a, b], "without": []})

## The wall of `side` and the ground behind it, as they run on past the
## corner with `next`. They are there when `side` is and `next` is not.
## `run` draws the wall between two places along the side.
func _run_on(side: MeshInstance3D, next: MeshInstance3D, run: Callable, material: ShaderMaterial) -> void:
	var way := signf(side.basis.x.dot(next.basis.z))
	var from := way * (reach + 0.85)
	var to := way * (reach + SPILL)
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	run.call(minf(from, to), maxf(from, to))
	_quad(Vector3(minf(from, to), 0.05, GROUND_FROM), Vector3(maxf(from, to), 0.05, GROUND_FROM), Vector3(maxf(from, to), 0.05, GROUND_TO), Vector3(minf(from, to), 0.05, GROUND_TO), GROUND)
	var part := _part(material)
	part.transform = side.transform
	_past_corners.append({"part": part, "with": [side], "without": [next]})

## Adds what `_tool` holds to the garden as one part. It casts no shadow.
func _part(material: ShaderMaterial) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _tool.commit()
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part

## The house: a tall front that rises from the water, with a lower wing. One
## window on the ground floor is lit.
func _house() -> void:
	_box(Vector3(3.0, 4.6, 3.0), Vector3(17.0, 9.2, 6.0), WALL)
	_roof(-5.7, 11.7, 9.2, 3.0, -0.25, 6.25)
	_box(Vector3(-8.6, 2.9, 2.5), Vector3(6.2, 5.8, 5.0), WALL.darkened(0.08))
	_roof(-11.9, -5.5, 5.8, 2.0, -0.2, 5.2)
	_box(Vector3(7.5, 11.6, 3.0), Vector3(1.0, 2.6, 1.0), WALL.darkened(0.1))
	_box(Vector3(7.5, 12.95, 3.0), Vector3(1.25, 0.14, 1.25), DARK)
	for row: float in [2.7, 6.0]:
		for column: int in 6:
			var along := 10.0 - 2.6 * column
			if row < 3.0 and column == 2:
				# The door, with a lintel and a sill at the water.
				_box(Vector3(along, 1.55, -0.03), Vector3(1.2, 2.5, 0.06), DARK)
				_box(Vector3(along, 2.9, -0.1), Vector3(1.6, 0.16, 0.2), PALE)
				_box(Vector3(along, 0.2, -0.12), Vector3(1.6, 0.2, 0.24), DARK)
				continue
			_window(Vector3(along, row, 0.0), Vector2(1.15, 1.7), row < 3.0 and column == 1)
	for column: int in 2:
		_window(Vector3(-7.4 - 2.4 * column, 2.9, 0.0), Vector2(1.05, 1.6), false)
	# The garden wall goes on from each end of the house to the corner.
	if reach > 11.7:
		_wall(-reach, -11.7, 3.2)
		_wall(11.5, reach, 3.2)

## A garden wall with piers and a gate, and old bare trees behind it.
func _wall_and_trees() -> void:
	var gate := -6.4
	_wall(-reach, gate - 1.1, 3.2)
	_wall(gate + 1.1, reach, 3.2)
	var pier := -1.6
	while pier < reach - 2.0:
		_pier(pier, 3.7)
		pier += 4.8
	for post: float in [gate - 1.35, gate + 1.35]:
		_pier(post, 4.6)
	# The gate's arch, and its bars.
	_box(Vector3(gate, 4.2, 0.3), Vector3(2.0, 0.3, 0.3), DARK)
	_box(Vector3(gate, 1.3, 0.3), Vector3(2.0, 0.08, 0.08), DARK)
	for bar: int in 5:
		_box(Vector3(gate - 0.72 + 0.36 * bar, 1.9, 0.3), Vector3(0.07, 3.8, 0.07), DARK)
	for tree: Array in [[-7.6, 3.2, 1.0], [-2.2, 4.6, 0.8], [2.6, 2.8, 1.1], [8.6, 4.0, 0.9]]:
		_tree(Vector3(tree[0], 0.0, tree[1]), tree[2], int(tree[0] * 7.0))

## A kitchen garden behind a wall: the roof of a glasshouse, and a water
## tank on legs. The wall hides its beds: a wide flat thing reads as ground.
func _greenhouse() -> void:
	var from := -9.0
	var to := 0.5
	var front := 1.0
	var back := 4.6
	var ridge := (front + back) * 0.5
	_wall(-reach, reach, 3.2)
	# Its frame: two posts and two rafters at each rib, and five rails.
	for rib: int in 10:
		var along := from + (to - from) * rib / 9.0
		for depth: float in [front, back]:
			_box(Vector3(along, 2.1, depth), Vector3(0.1, 4.2, 0.1), DARK)
			_bar(Vector3(along, 4.2, depth), Vector3(along, 5.6, ridge), 0.1, DARK)
	for rail: Array in [[4.2, front], [4.2, back], [5.6, ridge], [4.9, (front + ridge) * 0.5], [4.9, (back + ridge) * 0.5]]:
		_box(Vector3((from + to) * 0.5, rail[0], rail[1]), Vector3(to - from, 0.08, 0.08), DARK)
	# The tank.
	for leg: Array in [[5.2, 1.2], [7.4, 1.2], [5.2, 3.4], [7.4, 3.4]]:
		_box(Vector3(leg[0], 2.6, leg[1]), Vector3(0.22, 5.2, 0.22), DARK)
	_bar(Vector3(5.2, 0.6, 1.2), Vector3(7.4, 4.6, 1.2), 0.12, DARK)
	_bar(Vector3(7.4, 0.6, 1.2), Vector3(5.2, 4.6, 1.2), 0.12, DARK)
	_box(Vector3(6.3, 6.4, 2.3), Vector3(3.0, 2.4, 3.0), ROOF)
	_roof(4.7, 7.9, 7.6, 0.7, 0.7, 3.9)

## A low wall, one large old tree with a swing, and a shed.
func _tree_and_swing() -> void:
	_wall(-reach, reach, 2.4)
	_tree(Vector3(-7.4, 0.0, 2.6), 1.5, 5)
	# The swing hangs from a branch that reaches over the water.
	_bar(Vector3(-7.4, 5.2, 2.6), Vector3(-7.0, 5.6, -1.6), 0.26, TREE)
	for rope: float in [-0.35, 0.35]:
		_box(Vector3(-7.05 + rope, 3.45, -1.0), Vector3(0.05, 3.9, 0.05), DARK)
	_box(Vector3(-7.05, 1.5, -1.0), Vector3(0.95, 0.08, 0.34), DARK)
	# The shed.
	_box(Vector3(6.2, 1.9, 2.8), Vector3(4.4, 3.8, 3.6), WALL.darkened(0.1))
	_roof(3.7, 8.7, 3.8, 1.3, 0.7, 4.9)

## A length of garden wall at the water's edge, from `from` to `to` along
## it, with a coping that has no flat top.
func _wall(from: float, to: float, height: float) -> void:
	_box(Vector3((from + to) * 0.5, height * 0.5, 0.3), Vector3(to - from, height, 0.6), WALL)
	_roof(from, to, height, 0.32, -0.1, 0.7)

## A pier of the garden wall, with a cap.
func _pier(along: float, height: float) -> void:
	_box(Vector3(along, height * 0.5, 0.3), Vector3(0.8, height, 0.9), PALE)
	_roof(along - 0.55, along + 0.55, height, 0.3, -0.25, 0.85)

## A window in the house front at `middle`: a dark pane, a frame with a
## cross of glazing bars, and a sill. A lit window is the one warm light.
func _window(middle: Vector3, size: Vector2, lit: bool) -> void:
	_box(middle + Vector3(0.0, 0.0, -0.02), Vector3(size.x, size.y, 0.04), LIT if lit else DARK)
	var bar := DARK if lit else WALL
	_box(middle + Vector3(0.0, 0.0, -0.05), Vector3(0.07, size.y, 0.04), bar)
	_box(middle + Vector3(0.0, size.y * 0.12, -0.05), Vector3(size.x, 0.07, 0.04), bar)
	_box(middle + Vector3(0.0, -size.y * 0.5 - 0.09, -0.1), Vector3(size.x + 0.3, 0.14, 0.2), PALE)
	_box(middle + Vector3(0.0, size.y * 0.5 + 0.08, -0.05), Vector3(size.x + 0.2, 0.12, 0.1), PALE)

## An old bare tree: a trunk and a few large limbs, each with branches.
func _tree(foot: Vector3, size: float, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash(seed_value)
	var crown := foot + Vector3(random.randf_range(-0.3, 0.3), 4.2 * size, random.randf_range(-0.3, 0.3))
	_bar(foot, crown, 0.36 * size, TREE)
	for limb: int in 6:
		var turn := TAU * (limb + random.randf()) / 6.0
		var from := foot.lerp(crown, random.randf_range(0.62, 1.0))
		var to := from + Vector3(cos(turn) * 1.7, random.randf_range(1.4, 2.6), sin(turn) * 1.7) * size
		_bar(from, to, 0.15 * size, TREE)
		for twig: int in 3:
			var bend := turn + random.randf_range(-0.9, 0.9)
			var tip := to + Vector3(cos(bend) * 1.1, random.randf_range(0.9, 1.9), sin(bend) * 1.1) * size
			_bar(to, tip, 0.07 * size, TREE)
			for shoot: int in 2:
				var last := bend + random.randf_range(-1.1, 1.1)
				_bar(to.lerp(tip, random.randf_range(0.4, 1.0)), tip + Vector3(cos(last) * 0.7, random.randf_range(0.3, 1.0), sin(last) * 0.7) * size, 0.035 * size, TREE)

## A pitched roof from `from` to `to` along the side, with its eaves at
## `eaves` and its ridge `rise` above them, from depth `front` to depth
## `back`. A roof has no flat top.
func _roof(from: float, to: float, eaves: float, rise: float, front: float, back: float) -> void:
	var middle := (front + back) * 0.5
	var corners := [Vector3(from, eaves, front), Vector3(to, eaves, front), Vector3(to, eaves + rise, middle), Vector3(from, eaves + rise, middle),
		Vector3(from, eaves, back), Vector3(to, eaves, back)]
	_quad(corners[0], corners[1], corners[2], corners[3], ROOF)
	_quad(corners[5], corners[4], corners[3], corners[2], ROOF)
	for gable: Array in [[corners[4], corners[0], corners[3]], [corners[1], corners[5], corners[2]]]:
		var normal: Vector3 = ((gable[1] as Vector3) - gable[0]).cross((gable[2] as Vector3) - gable[0]).normalized()
		for corner: Vector3 in gable:
			_tool.set_normal(-normal)
			_tool.set_color(WALL)
			_tool.add_vertex(corner)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(d - a).normalized()
	for corner: Vector3 in [a, b, c, a, c, d]:
		_tool.set_normal(-normal)
		_tool.set_color(color)
		_tool.add_vertex(corner)

## A box with its middle at `middle`.
func _box(middle: Vector3, size: Vector3, color: Color) -> void:
	var half := size * 0.5
	for axis: int in 3:
		for sign_value: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var first := Vector3.ZERO
			first[(axis + 1) % 3] = 1.0
			var second := normal.cross(first)
			var at := middle + normal * half[axis]
			var u := first * half[(axis + 1) % 3]
			var v := second * absf(half.dot(second.abs()))
			for corner: Vector3 in [at - u - v, at + u + v, at + u - v, at - u - v, at - u + v, at + u + v]:
				_tool.set_normal(normal)
				_tool.set_color(color)
				_tool.add_vertex(corner)

## A square bar from `from` to `to`.
func _bar(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK).normalized() * width * 0.5
	var other := along.cross(side).normalized() * width * 0.5
	var rim := [side + other, other - side, -side - other, side - other]
	for index: int in 4:
		var a: Vector3 = rim[index]
		var b: Vector3 = rim[(index + 1) % 4]
		var normal := (a + b).normalized()
		for corner: Vector3 in [from + a, to + b, from + b, from + a, to + a, to + b]:
			_tool.set_normal(normal)
			_tool.set_color(color)
			_tool.add_vertex(corner)
